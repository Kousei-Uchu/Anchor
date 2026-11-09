//
//  DictationAudio.swift
//  Anchor
//
//  Keeping a voice note while dictating (Patch VN2, docs/OPTIONAL_FEATURES.md, E2). The one microphone feed
//  that goes to the recogniser in Dictation.swift can also be handed to this, which writes the same sound
//  to a voice note file in the same folder, and in the same kind of file, as the voice notes on a message.
//
//  It is only made when the person has switched on Keep a voice note while dictating in Settings, and it
//  stays on the phone like everything else here. Dictation.swift never writes a file itself; it only passes
//  the sound along, and `scripts/check-dictation.mjs` enforces that.
//

import Foundation
import AVFoundation

/// Writes the sound of one Dictate go to a file as it arrives. Made on the main actor, fed from the audio
/// thread, finished on the main actor.
final class DictationAudioSink: @unchecked Sendable {
    let fileName: String
    private let url: URL
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var frames: AVAudioFramePosition = 0
    private var sampleRate: Double
    private var broken = false

    /// Nil when the file cannot be made. Dictate then carries on without keeping the sound.
    init?(url: URL, fileName: String, format: AVAudioFormat) {
        // Same kind of file as a voice note on a message (AAC in an .m4a), at the rate and channel count the
        // microphone is already giving, so the sound is written as it is and never converted on the way.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        guard let file = try? AVAudioFile(forWriting: url, settings: settings,
                                          commonFormat: format.commonFormat, interleaved: format.isInterleaved) else {
            return nil
        }
        self.url = url
        self.fileName = fileName
        self.file = file
        self.sampleRate = format.sampleRate
    }

    /// Called from the audio thread for every piece of sound. A piece that does not fit the file is not
    /// written and the whole note is given up on, because half a note with a gap in it is worse than none.
    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !broken, let file else { return }
        guard buffer.format == file.processingFormat else {
            broken = true
            return
        }
        do {
            try file.write(from: buffer)
            frames += AVAudioFramePosition(buffer.frameLength)
        } catch {
            broken = true
        }
    }

    /// Closes the file. Returns how many seconds were kept, or nil when nothing usable was written.
    func finish() -> TimeInterval? {
        lock.lock()
        defer { lock.unlock() }
        // Letting go of the file is what finishes the write.
        file = nil
        guard !broken, frames > 0, sampleRate > 0 else { return nil }
        return Double(frames) / sampleRate
    }

    /// Removes the file, whatever state it is in.
    func discard() {
        lock.lock()
        file = nil
        lock.unlock()
        try? FileManager.default.removeItem(at: url)
    }
}
