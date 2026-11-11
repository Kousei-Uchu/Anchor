//
//  SpeakerTryIt.swift
//  Anchor
//
//  A way to try finding who is speaking on a real voice note (Patch VN4a2, test builds only). It lists the voice
//  notes on this phone, runs `SpeakerSeparation` on the one you tap and shows who spoke when. It keeps nothing, and
//  it is not part of a release build: the people screen that people use is `PeopleScreen`, opened from here for now.
//

#if DEBUG
import SwiftUI

struct SpeakerTryItView: View {
    @State private var names: [String] = []
    @State private var working = false
    @State private var lines: [String] = []
    @State private var task: Task<Void, Never>?
    @State private var added = ""

    var body: some View {
        Form {
            Anchor.SettingsSection(
                title: "Voice notes on this phone",
                footer: SpeakerSeparation.isAvailable
                    ? "Tap one to listen for who is speaking. Nothing is saved."
                    : "The speaker model is not in this build."
            ) {
                if names.isEmpty {
                    Text("No voice notes yet.").font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
                }
                ForEach(names, id: \.self) { name in
                    Button {
                        run(name)
                    } label: {
                        Text(label(name)).font(.system(.subheadline, design: .rounded))
                    }
                    .disabled(working || !SpeakerSeparation.isAvailable)
                }
            }
            Anchor.SettingsSection(
                title: "People screen",
                footer: "Opens the screen people will use, with the words beside each person. Add to this page only shows the text here; nothing is saved."
            ) {
                ForEach(names, id: \.self) { name in
                    NavigationLink {
                        PeopleScreen(folder: .voiceNotes, fileName: name) { added = $0 }
                    } label: {
                        Text(label(name)).font(.system(.subheadline, design: .rounded))
                    }
                    .disabled(working || !SpeakerSeparation.isAvailable)
                }
                ForEach(names, id: \.self) { name in
                    NavigationLink {
                        PeopleTapScreen(folder: .voiceNotes, fileName: name) { added = $0 }
                    } label: {
                        Text("Replay and tap: " + label(name)).font(.system(.subheadline, design: .rounded))
                    }
                }
                if !added.isEmpty {
                    Text(added).font(.system(.footnote, design: .rounded))
                }
            }
            if working {
                Anchor.SettingsSection(title: nil) {
                    ProgressView()
                    Button {
                        task?.cancel()
                    } label: {
                        Text("Stop").font(.system(.subheadline, design: .rounded))
                    }
                }
            }
            if !lines.isEmpty {
                Anchor.SettingsSection(title: "Result") {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.footnote, design: .rounded))
                    }
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Who is speaking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { names = StoredFiles.names(in: .voiceNotes).sorted() }
        .onDisappear { task?.cancel() }
    }

    private func label(_ name: String) -> String {
        VoiceNoteStore.clock(VoiceNoteStore.duration(of: name)) + "  " + String(name.prefix(8))
    }

    private func run(_ name: String) {
        working = true
        lines = []
        task = Task {
            let started = Date()
            do {
                let turns = try await SpeakerSeparation.separate(.voiceNotes, name)
                var out = ["\(SpeakerSeparation.personCount(in: turns)) people heard, \(turns.count) turns, took \(String(format: "%.1f", Date().timeIntervalSince(started))) s."]
                for person in Set(turns.map(\.person)).sorted() {
                    let total = turns.filter { $0.person == person }.reduce(0) { $0 + ($1.end - $1.start) }
                    out.append("Person \(person) spoke for \(String(format: "%.0f", total)) s.")
                }
                for turn in turns.prefix(15) {
                    out.append("Person \(turn.person): \(VoiceNoteStore.clock(turn.start)) to \(VoiceNoteStore.clock(turn.end))")
                }
                if turns.count > 15 { out.append("... and \(turns.count - 15) more turns.") }
                lines = out
            } catch is CancellationError {
                lines = ["Stopped."]
            } catch let failure as SpeakerSeparation.Failure {
                lines = [failure.plainText]
            } catch {
                lines = [SpeakerSeparation.Failure.failed.plainText]
            }
            working = false
        }
    }
}
#endif
