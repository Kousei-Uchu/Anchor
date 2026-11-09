import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What an AI tool is asked to do (Patch AI1, docs/OPTIONAL_FEATURES.md). Each tool is one action on text the
/// person chose, with a fixed instruction that is shown in full on the consent sheet before anything is sent.
/// A later patch adds its own case, and its own instruction, here.
enum AIFeature: String, CaseIterable {
    case makeShorter
    case breakIntoSteps
    case estimateTime

    /// The plain name of the button, and of the tool in the list of ones that no longer ask.
    var title: String {
        switch self {
        case .makeShorter: return "Make shorter"
        case .breakIntoSteps: return "Break into steps"
        case .estimateTime: return "Estimate time"
        }
    }

    /// The fixed instruction that goes with the text. It says what to keep and what never to add.
    var instruction: String {
        switch self {
        case .makeShorter:
            return "Make this text shorter. Keep every concrete detail, name, number and date, and keep who said what. Add nothing: no advice, no comment on feelings, no new facts. Use the same voice and the same language as the text. Reply with the shorter text only."
        case .breakIntoSteps:
            return "Break this task into a short list of small steps, in the order they would be done. Use only what the text says or plainly needs. Add no dates, no priorities, no advice and no comment on feelings. Write one step per line, with no numbers, bullets or other words, and at most 8 lines. Use the same language as the text."
        case .estimateTime:
            return "Guess how many minutes this task takes to do. Reply with one whole number of minutes and nothing else."
        }
    }
}

/// Where a tool can run. Apple's model on the phone is the only one so far. Ollama (AI5) and a provider the
/// person adds themselves (AI6) are added here when they are built.
enum AIProviderKind: String, CaseIterable {
    case apple

    var name: String {
        switch self {
        case .apple: return "Apple's on-device model"
        }
    }

    /// Where the text goes, in the words the consent sheet uses.
    var whereItRuns: String {
        switch self {
        case .apple: return "On this phone. The text does not leave it."
        }
    }

    /// What the provider does with the text, as far as Anchor can say.
    var keeping: String {
        switch self {
        case .apple: return "It is held in memory on this phone until you keep or discard the answer. Anchor keeps no log of it."
        }
    }

    /// Whether the consent sheet offers Don't ask again. Never for a provider the person added themselves (D42).
    var offersDontAskAgain: Bool {
        switch self {
        case .apple: return true
        }
    }
}

/// Whether a provider can be used right now, in words the person can act on.
enum AIProviderStatus: Equatable {
    case ready
    case notOnThisPhone
    case appleIntelligenceOff
    case notReady
    case unavailable
    case aiToolsOff

    var plainText: String {
        switch self {
        case .ready: return "Ready"
        case .notOnThisPhone: return "This phone cannot run it"
        case .appleIntelligenceOff: return "Turn on Apple Intelligence in the phone's Settings"
        case .notReady: return "Not ready yet, try again later"
        case .unavailable: return "Not available"
        case .aiToolsOff: return "AI tools are off"
        }
    }
}

enum AIError: Error, Equatable {
    case off
    case busy
    case nothingToSend
    case tooLong(limit: Int)
    case unavailable(AIProviderStatus)
    case cancelled
    case failed

    var plainText: String {
        switch self {
        case .off: return "AI tools are off."
        case .busy: return "Another request is still going."
        case .nothingToSend: return "There is no text to send."
        case .tooLong(let limit): return "That is too long for this tool. Pick up to \(limit) characters. Nothing was sent."
        case .unavailable(let status): return status.plainText + ". Nothing was sent."
        case .cancelled: return "Cancelled. Nothing was sent."
        case .failed: return "It could not make an answer. Nothing was kept."
        }
    }
}

/// One place a tool can run. It is only ever called by `AIAsk`, after the gate and after the person has been
/// shown the consent sheet (or has said not to be asked again), and `scripts/check-ai-gate.mjs` checks that.
protocol AIProviding: Sendable {
    var kind: AIProviderKind { get }
    /// The most characters this provider takes in one go. Longer text is refused before anything is sent.
    var maxCharacters: Int { get }
    func status() -> AIProviderStatus
    func generate(instruction: String, text: String) async throws -> String
}

enum AIProviders {
    /// The provider in use. One for now; a choice is added with the second provider.
    static var chosen: AIProviderKind { .apple }

    static func make(_ kind: AIProviderKind) -> AIProviding {
        switch kind {
        case .apple: return AppleOnDeviceProvider()
        }
    }
}

/// Apple's on-device model, through the FoundationModels framework. It runs on the phone, with no network.
/// It needs a phone that supports Apple Intelligence with it turned on in the phone's Settings.
struct AppleOnDeviceProvider: AIProviding {
    let kind = AIProviderKind.apple

    /// A guess to be checked on a real phone: the on-device model has a small context window, and the answer
    /// shares it with the text and the instruction, so the text is held well below it.
    let maxCharacters = 4000

    func status() -> AIProviderStatus {
        guard AIGate.isEnabled else { return .aiToolsOff }
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .notOnThisPhone
            case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
            case .modelNotReady: return .notReady
            @unknown default: return .unavailable
            }
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    func generate(instruction: String, text: String) async throws -> String {
        guard AIGate.isEnabled else { throw AIError.off }
        #if canImport(FoundationModels)
        let session = LanguageModelSession(instructions: instruction)
        let response = try await session.respond(to: text)
        return response.content
        #else
        throw AIError.unavailable(.unavailable)
        #endif
    }
}

/// Reads what a model answered into the small pieces a tool shows as suggestions (Patch AI3). Nothing here sends
/// anything or keeps anything; the caller shows the pieces and the person decides.
enum AIAnswerReader {
    /// One step per line, with any bullet or number the model added taken off, blank and repeated lines dropped,
    /// and at most `limit` of them. Nothing is cut short or reworded.
    static func steps(from answer: String, limit: Int = 8) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in answer.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            while let first = line.first, "-*\u{2022}\u{2013}\u{2014}".contains(first) {
                line.removeFirst()
                line = line.trimmingCharacters(in: .whitespaces)
            }
            if let marker = line.range(of: #"^\d{1,2}[.)]\s+"#, options: .regularExpression) {
                line.removeSubrange(marker)
            }
            line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, seen.insert(line.lowercased()).inserted else { continue }
            result.append(line)
            if result.count == limit { break }
        }
        return result
    }

    /// A guess in minutes, rounded to the nearest 5 and held between 5 and 480, or nil when the answer is not
    /// plainly a number of minutes (for instance, when it talks about hours).
    static func minutes(from answer: String) -> Int? {
        let lower = answer.lowercased()
        guard !lower.contains("hour"), !lower.contains("hr") else { return nil }
        guard let range = lower.range(of: #"\d+"#, options: .regularExpression), let value = Int(lower[range]), value > 0 else { return nil }
        let rounded = Int((Double(value) / 5).rounded()) * 5
        return min(480, max(5, rounded))
    }
}

#if DEBUG
/// Checks, in a test build, how a model's answer is read into suggestions: bullets, numbers and repeats come off,
/// the count is held, and a number of minutes is rounded and bounded or refused. Patch AI3.
enum AIAnswerReaderSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("AI answer reader self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let steps = AIAnswerReader.steps(from: "1. Find the form\n- Fill it in\n\u{2022} Fill it in\n\n  2) Post it\n")
        check(steps == ["Find the form", "Fill it in", "Post it"], "marks, blanks and repeats come off")
        check(AIAnswerReader.steps(from: (1...12).map { "Step \($0)" }.joined(separator: "\n")).count == 8, "at most eight")
        check(AIAnswerReader.steps(from: "  \n ").isEmpty, "nothing in, nothing out")
        check(AIAnswerReader.minutes(from: "17") == 15 && AIAnswerReader.minutes(from: "About 20 minutes") == 20, "rounded to five")
        check(AIAnswerReader.minutes(from: "1") == 5 && AIAnswerReader.minutes(from: "9000") == 480, "held between 5 and 480")
        check(AIAnswerReader.minutes(from: "2 hours") == nil && AIAnswerReader.minutes(from: "no idea") == nil && AIAnswerReader.minutes(from: "0") == nil, "not plainly minutes is refused")
    }
}
#endif
