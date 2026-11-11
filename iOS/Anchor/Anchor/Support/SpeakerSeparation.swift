//
//  SpeakerSeparation.swift
//  Anchor
//
//  Finds who is speaking inside one recording (Patch VN4a2, docs/OPTIONAL_FEATURES.md, E2, D38, D63, D64, D73).
//
//  What it does: opens a plain copy of a recording, listens to it once with a speaker-separation model that ships
//  inside the app, and hands back who spoke when as Person 1, Person 2 and so on, numbered in the order they first
//  speak. Then it lets go of everything.
//
//  What it never does, and `scripts/check-speaker-separation.mjs` fails if this file ever does:
//  - It never goes online. The library could fetch models from the internet; none of its download calls are made,
//    the models are loaded here from the app's own files, and `forbidDownloads()` switches the library's own
//    network off at launch so a later mistake fails instead of connecting.
//  - It keeps nothing about a voice. The library's answer carries a sound print for each stretch of speech and a
//    speaker list; only the person number and the start and end are copied out, and the answer is dropped when
//    this returns. Nothing here writes to storage, the Keychain or the database, and nothing compares one recording
//    with another, so there is no profile and no way to know a voice from an earlier recording.
//  - It never works from the recording's own file. A locked recording is opened into a plain copy in the phone's
//    temporary folder (`StoredFiles.workingCopy`), which is removed when the run ends, however it ends, and at
//    every start.
//
//  This is the only file that imports FluidAudio.
//

import Foundation
import AVFoundation
import CoreML
import FluidAudio

enum SpeakerSeparation {
    /// One stretch of one person talking, in seconds from the start of the recording.
    struct Turn: Equatable, Sendable {
        let person: Int
        let start: TimeInterval
        let end: TimeInterval
    }

    enum Failure: Error {
        case modelsMissing, cannotOpen, tooLong, noSpeech, failed

        var plainText: String {
            switch self {
            case .modelsMissing: return "The speaker model is not in this build."
            case .cannotOpen: return "That recording could not be opened."
            case .tooLong: return "That recording is longer than half an hour, which is more than this can look at."
            case .noSpeech: return "No one could be heard in that recording."
            case .failed: return "Finding who is speaking did not work this time."
            }
        }
    }

    /// The whole recording is held in memory as sound (about 4 MB a minute), so a very long one is refused.
    static let longestSeconds: TimeInterval = 30 * 60

    /// Stretches by the same person with less than this between them are joined into one turn.
    static let joinGap: TimeInterval = 0.75

    /// Stretches shorter than this are dropped as noise.
    static let shortestTurn: TimeInterval = 0.3

    // MARK: Staying offline

    /// Called once at launch. From then on any path in the library that would touch the network throws instead.
    static func forbidDownloads() {
        ModelHub.offlineMode = true
    }

    // MARK: The model files

    /// The folder the models were copied into when the app was built (`scripts/fetch-diarizer-models.sh`).
    private static var modelsFolder: URL? {
        Bundle.main.url(forResource: "DiarizerModels", withExtension: nil)
    }

    /// Whether this build carries the model files.
    static var isAvailable: Bool {
        guard let folder = modelsFolder else { return false }
        return FileManager.default.fileExists(atPath: folder.appendingPathComponent("Segmentation.mlmodelc").path)
    }

    private static func model(_ name: String, in folder: URL, units: MLComputeUnits) throws -> MLModel {
        let url = folder.appendingPathComponent(name + ".mlmodelc", isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.path) else { throw Failure.modelsMissing }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = units
        configuration.allowLowPrecisionAccumulationOnGPU = true
        return try MLModel(contentsOf: url, configuration: configuration)
    }

    /// The scoring step's fixed numbers, which are part of the model and say nothing about any voice.
    private static func scoringNumbers(in folder: URL) throws -> [Double] {
        let url = folder.appendingPathComponent("plda-parameters.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tensors = root["tensors"] as? [String: Any],
              let psi = tensors["psi"] as? [String: Any],
              let encoded = psi["data_base64"] as? String,
              let decoded = Data(base64Encoded: encoded, options: [.ignoreUnknownCharacters]) else {
            throw Failure.modelsMissing
        }
        let count = decoded.count / MemoryLayout<Float>.size
        guard count > 0 else { throw Failure.modelsMissing }
        var numbers = [Float](repeating: 0, count: count)
        _ = numbers.withUnsafeMutableBytes { decoded.copyBytes(to: $0) }
        return numbers.map { Double($0) }
    }

    private static func loadModels() throws -> OfflineDiarizerModels {
        guard let folder = modelsFolder else { throw Failure.modelsMissing }
        let started = Date()
        let segmentation = try model("Segmentation", in: folder, units: .all)
        let embedding = try model("Embedding", in: folder, units: .all)
        let scoring = try model("PldaRho", in: folder, units: .all)
        // The filter-bank step is quickest on the processor alone.
        let filterBank = try model("FBank", in: folder, units: .cpuOnly)
        return OfflineDiarizerModels(
            segmentationModel: segmentation,
            fbankModel: filterBank,
            embeddingModel: embedding,
            pldaRhoModel: scoring,
            pldaPsi: try scoringNumbers(in: folder),
            compilationDuration: Date().timeIntervalSince(started)
        )
    }

    // MARK: Running it

    /// Who spoke when in one recording. The models are loaded for this run and let go of when it ends. The plain
    /// copy of the recording is removed however this ends: finished, failed or cancelled.
    static func separate(_ folder: StoredFiles.Folder, _ name: String) async throws -> [Turn] {
        guard isAvailable else { throw Failure.modelsMissing }
        guard let copy = StoredFiles.workingCopy(folder, name) else { throw Failure.cannotOpen }
        defer { StoredFiles.removeWorkingCopy(copy) }

        guard let file = try? AVAudioFile(forReading: copy) else { throw Failure.cannotOpen }
        let seconds = Double(file.length) / max(file.processingFormat.sampleRate, 1)
        guard seconds <= longestSeconds else { throw Failure.tooLong }
        try Task.checkCancellation()

        let samples: [Float]
        do {
            samples = try AudioConverter().resampleAudioFile(copy)
        } catch {
            throw Failure.cannotOpen
        }
        try Task.checkCancellation()

        let raw: [(speaker: String, start: Double, end: Double)]
        do {
            let models = try loadModels()
            // No sound prints are written out or handed back, whatever the library's own settings say.
            let configuration = OfflineDiarizerConfig(export: .none, exposeChunkEmbeddings: false)
            let manager = OfflineDiarizerManager(config: configuration)
            manager.initialize(models: models)
            let result = try await manager.process(audio: samples)
            // Only who and when leave this block. The sound prints and the speaker list in `result` go with it.
            raw = result.segments.map {
                (speaker: $0.speakerId, start: Double($0.startTimeSeconds), end: Double($0.endTimeSeconds))
            }
        } catch let failure as Failure {
            throw failure
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Failure.failed
        }
        try Task.checkCancellation()

        let turns = turns(from: raw)
        guard !turns.isEmpty else { throw Failure.noSpeech }
        return turns
    }

    // MARK: Tidying the answer

    /// Numbers the speakers in the order they first speak, drops stretches too short to be speech, and joins
    /// stretches by the same person that are close together. Pure: it only works on the numbers it is given.
    static func turns(from raw: [(speaker: String, start: Double, end: Double)]) -> [Turn] {
        let usable = raw
            .filter { $0.end - $0.start >= shortestTurn && $0.start >= 0 }
            .sorted { $0.start < $1.start }
        var numbers: [String: Int] = [:]
        var out: [Turn] = []
        for item in usable {
            let person: Int
            if let known = numbers[item.speaker] {
                person = known
            } else {
                person = numbers.count + 1
                numbers[item.speaker] = person
            }
            // Joined only to the turn just before it, and only if that was the same person, so someone else
            // speaking in between always keeps the two apart.
            if let last = out.last, last.person == person, item.start - last.end < joinGap {
                out[out.count - 1] = Turn(person: person, start: last.start, end: max(last.end, item.end))
                continue
            }
            out.append(Turn(person: person, start: item.start, end: item.end))
        }
        return out
    }

    /// How many different people were heard.
    static func personCount(in turns: [Turn]) -> Int {
        Set(turns.map(\.person)).count
    }
}

#if DEBUG
/// Checks, in a test build, that the answer is tidied as it should be: people are numbered by who speaks first,
/// very short stretches are dropped, a person's own neighbouring stretches are joined, and a different person
/// speaking in between stops the join.
enum SpeakerSeparationSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Speaker separation self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let raw: [(speaker: String, start: Double, end: Double)] = [
            (speaker: "B", start: 5.0, end: 9.0),
            (speaker: "A", start: 0.0, end: 4.0),
            (speaker: "A", start: 4.3, end: 4.9),
            (speaker: "C", start: 4.95, end: 5.0),
            (speaker: "A", start: 9.2, end: 12.0),
            (speaker: "B", start: 14.0, end: 15.0)
        ]
        let turns = SpeakerSeparation.turns(from: raw)
        check(turns.map(\.person) == [1, 2, 1, 2], "numbered by first speaking, short noise dropped, joined: \(turns)")
        check(turns[0] == SpeakerSeparation.Turn(person: 1, start: 0.0, end: 4.9), "a person's near stretches are one turn")
        check(SpeakerSeparation.personCount(in: turns) == 2, "two people counted")
        check(SpeakerSeparation.turns(from: []).isEmpty, "nothing in, nothing out")
        let overlapping = SpeakerSeparation.turns(from: [
            (speaker: "A", start: 0.0, end: 3.0),
            (speaker: "B", start: 2.0, end: 4.0),
            (speaker: "A", start: 3.2, end: 5.0)
        ])
        check(overlapping.map(\.person) == [1, 2, 1], "someone else speaking in between stops the join: \(overlapping)")
    }
}
#endif
