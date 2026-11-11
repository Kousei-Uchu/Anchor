//
//  PeopleScreen.swift
//  Anchor
//
//  The people screen (Patches VN4a3b and VN4b, docs/OPTIONAL_FEATURES.md, E2, D38, D63, D74): how many people were heard in one
//  recording, a name for each beside the start of what they said, and a button that hands the labelled lines to
//  whoever opened it, to add to the page. It goes through `PeopleFinder` only; it never reaches the model or the
//  recogniser itself, and it keeps nothing: the names you type live on this screen until it closes, and what is
//  added to a page is plain text like any other words. Nothing in a release build opens it yet (VN4a4).
//

import SwiftUI

struct PeopleScreen: View {
    let folder: StoredFiles.Folder
    let fileName: String
    /// Called with the labelled lines when the person taps Add to this page. The caller decides where they go.
    /// Turns the person tapped (VN4b). Nil means the speaker model finds them.
    var tapped: [PeopleFinder.Turn]?
    let onUse: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .working
    @State private var outcome: PeopleFinder.Outcome?
    @State private var names: [Int: String] = [:]
    @State private var task: Task<Void, Never>?

    private enum Phase: Equatable {
        case working, done, failed(String)
    }

    var body: some View {
        Form {
            switch phase {
            case .working:
                Anchor.SettingsSection(title: nil, footer: "This listens to the recording on this phone only. Nothing is sent anywhere or saved.") {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(tapped == nil ? "Finding who is speaking…" : "Making out the words…").font(.system(.subheadline, design: .rounded))
                    }
                    Button {
                        task?.cancel()
                        dismiss()
                    } label: {
                        Text("Stop").font(.system(.subheadline, design: .rounded))
                    }
                }
            case .failed(let message):
                Anchor.SettingsSection(title: nil) {
                    Text(message).font(.system(.subheadline, design: .rounded))
                    Button {
                        start()
                    } label: {
                        Text("Try again").font(.system(.subheadline, design: .rounded))
                    }
                }
            case .done:
                if let outcome { result(outcome) }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Who is speaking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if outcome == nil, task == nil { start() } }
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder
    private func result(_ outcome: PeopleFinder.Outcome) -> some View {
        let count = outcome.personCount
        Anchor.SettingsSection(
            title: count == 1 ? "1 person was heard" : "\(count) people were heard",
            footer: outcome.hasWords
                ? "The names are for this page only. The words are listened to afresh, so they can differ a little from what you dictated. Your own text is never replaced."
                : "The phone could not turn this recording into words, so only who spoke and for how long is shown, and there is nothing to add to the page."
        ) {
            ForEach(outcome.people, id: \.self) { person in
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Person \(person)", text: binding(for: person))
                        .font(.system(.subheadline, design: .rounded))
                        .textInputAutocapitalization(.words)
                    Text(detail(person, outcome))
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        if outcome.hasWords {
            Anchor.SettingsSection(title: "How it will read") {
                Text(PeopleFinder.text(of: outcome.lines, names: names))
                    .font(.system(.footnote, design: .rounded))
                    .lineLimit(12)
            }
            Anchor.SettingsSection(title: nil) {
                Button {
                    onUse(PeopleFinder.text(of: outcome.lines, names: names))
                    dismiss()
                } label: {
                    Text("Add to this page").font(.system(.subheadline, design: .rounded))
                }
            }
        }
    }

    private func detail(_ person: Int, _ outcome: PeopleFinder.Outcome) -> String {
        let spoke = "Spoke for " + VoiceNoteStore.clock(outcome.seconds(of: person))
        guard let preview = PeopleFinder.preview(of: outcome.lines, person: person) else { return spoke }
        return spoke + ". “" + preview + "”"
    }

    private func binding(for person: Int) -> Binding<String> {
        Binding(get: { names[person] ?? "" }, set: { names[person] = $0 })
    }

    private func start() {
        guard tapped != nil || PeopleFinder.isAvailable else {
            phase = .failed("The speaker model is not in this build.")
            return
        }
        phase = .working
        task = Task {
            do {
                if let tapped {
                    outcome = try await PeopleFinder.find(folder, fileName, tapped: tapped)
                } else {
                    outcome = try await PeopleFinder.find(folder, fileName)
                }
                phase = .done
            } catch is CancellationError {
                // The screen was closed; nothing to show.
            } catch {
                phase = .failed(PeopleFinder.plainText(for: error))
            }
        }
    }
}

/// Which voice note the people screen was opened for, and whether it is the model's or the tapped one (Patch VN4a4).
struct PeopleSheet: Identifiable {
    let id = UUID()
    let blockID: UUID
    let file: String
    let taps: Bool
}
