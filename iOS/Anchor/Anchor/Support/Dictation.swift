import Foundation
import AVFoundation
import Speech

/// Dictation in the Journal (Patch VN1, docs/OPTIONAL_FEATURES.md, E2).
///
/// It is off to begin with and stays off until the person turns it on in Settings, Journal. While it is off
/// there is no Dictate button and neither the microphone nor speech recognition is ever asked for.
///
/// What is said is turned into text on the phone and goes nowhere. The recogniser is told to work on the
/// device only (`requiresOnDeviceRecognition`), and when the phone cannot do that for the person's language
/// Dictate says so and does not start, instead of letting the words go to Apple's servers.
/// `scripts/check-dictation.mjs` fails if anything weakens that. The sound is passed to the recogniser
/// in memory. It is only kept as a voice note (Patch VN2) when the person has also switched on Keep a voice
/// note while dictating, and the file itself is written by `DictationAudioSink`, never in this file.
enum DictationSettings {
    static let enabledKey = "dictationEnabled"
    static let keepVoiceNoteKey = "dictationKeepsVoiceNote"
    static let labelSpeakersKey = "dictationLabelsSpeakers"

    /// Whether the person asked for Speaker 1 and Speaker 2 buttons while dictating. Off unless they turned it on.
    static var labelsSpeakers: Bool { isEnabled && UserDefaults.standard.bool(forKey: labelSpeakersKey) }

    /// Whether the person asked for a voice note to be kept while dictating. Off unless they turned it on.
    static var keepsVoiceNote: Bool { isEnabled && UserDefaults.standard.bool(forKey: keepVoiceNoteKey) }

    /// What the person chose. Off unless they turned it on.
    static var isChosen: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// Whether Dictate may show and run right now. Showcase mode and the demo store keep it off, so a
    /// made-up page never listens.
    static var isEnabled: Bool {
        if DemoMode.isOn { return false }
        return isChosen
    }
}

/// One go at dictating. The Journal editor owns one, starts it with a function that is handed every
/// version of the words heard so far, and stops it when the person taps the microphone again.
@MainActor
final class DictationSession: ObservableObject {
    enum Phase: Equatable {
        case idle
        /// Asking for permission and getting ready.
        case starting
        case listening
        /// The sound has stopped and the last words are being worked out.
        case finishing
    }

    /// Dictation stops by itself after this long, as voice notes do.
    static let maxSeconds: TimeInterval = 300

    @Published private(set) var phase: Phase = .idle
    /// A plain line to show when something did not start or stopped. Never an error code.
    @Published var message: String?
    /// The voice note kept by the go that just ended, if the person asked for one and it worked. The editor
    /// takes it with `takeVoiceNote()`. A go that is cancelled keeps nothing.
    @Published private(set) var keptVoiceNote: KeptVoiceNote?

    struct KeptVoiceNote: Equatable {
        let fileName: String
        let seconds: TimeInterval
    }

    private var sink: DictationAudioSink?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var limitTimer: Timer?
    private var finishTimer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private var onHeard: ((String) -> Void)?
    /// Bumped whenever a go ends, so a late answer from an earlier go is ignored.
    private var generation = 0

    var isActive: Bool { phase != .idle }

    // MARK: Start and stop

    /// Starts listening. `onHeard` is called with the whole of what has been heard in this go each time it
    /// changes, including the last words after the person stops. Nothing starts if the phone cannot turn
    /// the person's language into text by itself.
    func start(onHeard: @escaping (String) -> Void) async {
        guard phase == .idle, DictationSettings.isEnabled else { return }
        message = nil

        let locale = Locale.current
        guard let recogniser = SFSpeechRecognizer(locale: locale),
              recogniser.isAvailable,
              recogniser.supportsOnDeviceRecognition else {
            message = Self.languageMessage(for: locale)
            return
        }

        phase = .starting
        let speech = await Self.speechStatus()
        guard speech == .authorized else {
            phase = .idle
            message = speech == .restricted ? Self.restrictedMessage : Self.speechDeniedMessage
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            phase = .idle
            message = Self.micDeniedMessage
            return
        }
        // The page may have gone away, or Dictate been switched off, while the phone was asking.
        guard phase == .starting, DictationSettings.isEnabled else {
            phase = .idle
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        request.taskHint = .dictation

        do {
            let keeping = DictationSettings.keepsVoiceNote
            let audio = AVAudioSession.sharedInstance()
            // Measurement mode turns off the phone's own voice processing, which is right for the
            // recogniser but makes a recording quiet, so a kept voice note uses the ordinary mode.
            try audio.setCategory(.record, mode: keeping ? .default : .measurement, options: [.duckOthers])
            try audio.setActive(true)
            let engine = AVAudioEngine()
            self.engine = engine
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            if keeping {
                let name = VoiceNoteStore.newFileName()
                sink = DictationAudioSink(url: VoiceNoteStore.url(for: name), fileName: name, format: format)
                if sink == nil { message = Self.noteFailedMessage }
            }
            input.installTap(onBus: 0, bufferSize: 1024, format: format,
                             block: Self.tap(feeding: request, sink: sink))
            engine.prepare()
            try engine.start()
        } catch {
            stopAudio()
            closeSound(keeping: false)
            phase = .idle
            message = Self.failedMessage
            return
        }

        generation += 1
        let mine = generation
        self.request = request
        self.onHeard = onHeard
        task = recogniser.recognitionTask(with: request, resultHandler: Self.handler { [weak self] text, isFinal, didFail in
            self?.heard(text, isFinal: isFinal, didFail: didFail, generation: mine)
        })
        phase = .listening

        limitTimer = Timer.scheduledTimer(withTimeInterval: Self.maxSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stopAtLimit() }
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor in
                if raw == AVAudioSession.InterruptionType.began.rawValue { self?.stop() }
            }
        }
    }

    /// Stops listening and lets the last words arrive. What was heard stays where it was put.
    func stop() {
        guard phase == .listening else { return }
        phase = .finishing
        limitTimer?.invalidate()
        limitTimer = nil
        stopAudio()
        request?.endAudio()
        // The last words normally arrive within a moment. If they do not, stop waiting.
        finishTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finish() }
        }
    }

    /// Ends the go at once, dropping any words still being worked out. Used when the page goes away.
    func cancel() {
        guard phase != .idle else { return }
        finish(keepingSound: false)
    }

    /// The editor takes the kept voice note once, when it has dealt with it.
    func takeVoiceNote() -> KeptVoiceNote? {
        let note = keptVoiceNote
        keptVoiceNote = nil
        return note
    }

    private func stopAtLimit() {
        guard phase == .listening else { return }
        message = "Dictate stopped after 5 minutes. Tap the microphone to carry on."
        stop()
    }

    private func heard(_ text: String?, isFinal: Bool, didFail: Bool, generation g: Int) {
        guard g == generation, phase == .listening || phase == .finishing else { return }
        if let text { onHeard?(text) }
        if isFinal || didFail { finish() }
    }

    private func finish(keepingSound: Bool = true) {
        finishTimer?.invalidate()
        finishTimer = nil
        limitTimer?.invalidate()
        limitTimer = nil
        stopAudio()
        closeSound(keeping: keepingSound)
        task?.cancel()
        task = nil
        request = nil
        onHeard = nil
        generation += 1
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        phase = .idle
    }

    /// Closes the file for a kept voice note. A note under half a second, one that went wrong, or one the
    /// person walked away from is removed, so no stray file is left behind.
    private func closeSound(keeping: Bool) {
        guard let sink else { return }
        self.sink = nil
        let seconds = sink.finish()
        if keeping, let seconds, seconds >= 0.5 {
            StoredFiles.sealIfOn(.voiceNotes, sink.fileName)
            keptVoiceNote = KeptVoiceNote(fileName: sink.fileName, seconds: seconds)
        } else {
            sink.discard()
            if keeping { message = Self.noteFailedMessage }
        }
    }

    private func stopAudio() {
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        engine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Off the main actor

    // These two are built here, outside the main actor, because the sound and the recogniser call them
    // from other threads. Everything they hand over is a plain value.

    private nonisolated static func tap(feeding request: SFSpeechAudioBufferRecognitionRequest,
                                        sink: DictationAudioSink?) -> AVAudioNodeTapBlock {
        return { buffer, _ in
            request.append(buffer)
            sink?.append(buffer)
        }
    }

    private nonisolated static func handler(
        _ deliver: @escaping @MainActor (String?, Bool, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        return { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let didFail = error != nil
            Task { @MainActor in deliver(text, isFinal, didFail) }
        }
    }

    private nonisolated static func speechStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: Words

    private static func languageMessage(for locale: Locale) -> String {
        let name = locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        return "This phone cannot turn \(name) speech into text on its own, so Dictate has not started. Anchor never sends your voice to Apple for this. Nothing was recorded."
    }

    private static let micDeniedMessage = "Anchor does not have the microphone, so Dictate has not started. You can allow it in the phone's Settings, under Anchor."
    private static let speechDeniedMessage = "Anchor does not have speech recognition, so Dictate has not started. You can allow it in the phone's Settings, under Anchor."
    private static let restrictedMessage = "Speech recognition is switched off for this phone, so Dictate has not started."
    private static let failedMessage = "Dictate could not start. Nothing was recorded."
    private static let noteFailedMessage = "The words are still being turned into text, but the voice note could not be kept this time."
}

/// Where the words of one go are being put: one paragraph of the page. Each new version of what was heard
/// replaces the last, after the words that were already there.
struct DictationTarget {
    let blockID: UUID
    /// What the paragraph held before dictating began, exactly.
    let base: String
    /// What dictation last wrote. If the paragraph differs from this, the person has typed, and typing wins.
    var lastWritten: String
    /// Everything heard so far in this go, as last handed over.
    var lastHeard: String = ""
    /// Where each speaker's words begin in what was heard, set when the person taps a speaker (Patch VN3).
    var turns: [Turn] = []

    struct Turn: Equatable {
        let label: String
        /// How many characters had been heard when the person tapped.
        let from: Int
    }

    /// The person says the speaker has changed. Words heard from now on go on a new line with this label.
    mutating func startTurn(_ label: String) {
        if turns.last?.label == label { return }
        let from = lastHeard.count
        // Tapping again before anything was said replaces the label rather than leaving an empty one.
        if let last = turns.last, last.from == from { turns.removeLast() }
        if turns.last?.label == label { return }
        turns.append(Turn(label: label, from: from))
    }

    /// The paragraph's text for the words heard so far.
    func text(for heard: String) -> String {
        guard !turns.isEmpty else {
            let spaced = !base.isEmpty && !heard.isEmpty && !(base.last?.isWhitespace ?? true)
            return base + (spaced ? " " : "") + heard
        }
        let characters = Array(heard)
        func words(_ start: Int, _ end: Int) -> String {
            let from = min(start, characters.count)
            let to = max(from, min(end, characters.count))
            return String(characters[from..<to]).trimmingCharacters(in: .whitespaces)
        }
        var lines: [String] = []
        if let first = turns.first, first.from > 0 {
            let before = words(0, first.from)
            if !before.isEmpty { lines.append(before) }
        }
        for (index, turn) in turns.enumerated() {
            let end = index + 1 < turns.count ? turns[index + 1].from : characters.count
            lines.append(turn.label + ": " + words(turn.from, end))
        }
        let joiner = base.isEmpty || base.last == "\n" ? "" : "\n"
        return base + joiner + lines.joined(separator: "\n")
    }
}
