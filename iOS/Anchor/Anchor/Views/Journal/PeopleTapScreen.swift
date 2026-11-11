//
//  PeopleTapScreen.swift
//  Anchor
//
//  Replay and tap (Patch VN4b, docs/OPTIONAL_FEATURES.md, E2, D38, D63, D74). For the more privacy-minded: play the
//  recording back and tap who is speaking each time it changes. No model reads the recording and nothing about a
//  voice is worked out; the only numbers kept are the times you tapped, and only until this screen closes. Then the
//  same people screen as the model's opens, with your taps as who spoke when.
//

import SwiftUI

struct PeopleTapScreen: View {
    let folder: StoredFiles.Folder
    let fileName: String
    let onUse: (String) -> Void

    @StateObject private var player: ReplayPlayer
    @State private var taps: [TapTurns.Tap] = []
    @State private var people = 2

    init(folder: StoredFiles.Folder, fileName: String, onUse: @escaping (String) -> Void) {
        self.folder = folder
        self.fileName = fileName
        self.onUse = onUse
        _player = StateObject(wrappedValue: ReplayPlayer(folder, fileName))
    }

    private var turns: [PeopleFinder.Turn] { TapTurns.turns(from: taps, duration: player.duration) }

    var body: some View {
        Form {
            if player.failed {
                Anchor.SettingsSection(title: nil) {
                    Text("That recording could not be played.").font(.system(.subheadline, design: .rounded))
                }
            } else {
                Anchor.SettingsSection(
                    title: "Play it and tap who is speaking",
                    footer: "Tap a person each time the speaker changes, starting with whoever speaks first. Nothing listens to the voices; only the times you tap are used, and only until you close this screen."
                ) {
                    HStack {
                        Button {
                            player.toggle()
                        } label: {
                            Label(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                        }
                        Spacer()
                        Text(VoiceNoteStore.clock(player.time) + " / " + VoiceNoteStore.clock(player.duration))
                            .font(.system(.footnote, design: .rounded)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Button {
                        player.back()
                    } label: {
                        Text("Back 5 seconds").font(.system(.subheadline, design: .rounded))
                    }
                }
                Anchor.SettingsSection(title: "Who is speaking now") {
                    ForEach(1...people, id: \.self) { person in
                        Button {
                            taps.append(TapTurns.Tap(person: person, time: player.time))
                        } label: {
                            Text("Person \(person)").font(.system(.subheadline, design: .rounded).weight(.medium))
                        }
                    }
                    if people < TapTurns.mostPeople {
                        Button {
                            people += 1
                        } label: {
                            Text("Add another person").font(.system(.subheadline, design: .rounded))
                        }
                    }
                    if !taps.isEmpty {
                        Button {
                            taps.removeLast()
                        } label: {
                            Text("Undo the last tap").font(.system(.subheadline, design: .rounded))
                        }
                    }
                }
                Anchor.SettingsSection(title: nil, footer: summary) {
                    NavigationLink {
                        PeopleScreen(folder: folder, fileName: fileName, tapped: turns, onUse: onUse)
                    } label: {
                        Text("Done tapping").font(.system(.subheadline, design: .rounded).weight(.medium))
                    }
                    .disabled(turns.isEmpty)
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Replay and tap")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }

    private var summary: String {
        turns.isEmpty ? "Tap a person at least once." : "\(turns.count) turns so far."
    }
}
