//
//  ReplayPlayer.swift
//  Anchor
//
//  Plays a kept recording back so the person can tap who is speaking (Patch VN4b, E2, D38, D63). The recording is
//  opened into memory and played from there, so no file is made, and nothing is kept: no storage, no database,
//  no network, no model and no recogniser. It only plays and says how far along it is.
//

import Foundation
import AVFoundation

@MainActor
final class ReplayPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var time: TimeInterval = 0
    @Published private(set) var failed = false
    private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    init(_ folder: StoredFiles.Folder, _ name: String) {
        super.init()
        guard let data = StoredFiles.read(folder, name), let made = try? AVAudioPlayer(data: data) else {
            failed = true
            return
        }
        made.delegate = self
        made.prepareToPlay()
        player = made
        duration = made.duration
    }

    func toggle() {
        guard let player else { return }
        if isPlaying { pause(); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            failed = true
            return
        }
        if player.currentTime >= player.duration - 0.05 { player.currentTime = 0 }
        guard player.play() else { failed = true; return }
        isPlaying = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.time = self?.player?.currentTime ?? 0 }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
        timer = nil
        time = player?.currentTime ?? time
    }

    /// Back a few seconds, to tap again where it was missed.
    func back(_ seconds: TimeInterval = 5) {
        guard let player else { return }
        player.currentTime = max(0, player.currentTime - seconds)
        time = player.currentTime
    }

    /// Lets go of the sound and the audio session.
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.timer?.invalidate()
            self.timer = nil
            self.time = self.duration
        }
    }
}
