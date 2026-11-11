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
    @StateObject private var ask = AIAsk()
    @State private var other: PeopleFinder.Outcome?
    @State private var showingWords = false
    @State private var guessing = false
    @State private var guessNote: String?
    @State private var guessTask: Task<Void, Never>?
    @State private var showingAIOff = false

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
        .aiAsk(ask)
        .aiOffAlert(isPresented: $showingAIOff)
        .onDisappear { task?.cancel(); guessTask?.cancel() }
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
        if outcome.hasWords, !outcome.words.isEmpty {
            wordsSection(outcome)
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

    /// Guessing who is speaking from the words alone (Patch VN4c2). Only here, only behind the AI switch, and only
    /// through `AIAsk`, which shows the exact text and asks before anything is sent. The guess is shown beside the
    /// first answer and changes nothing until the person chooses it.
    @ViewBuilder
    private func wordsSection(_ outcome: PeopleFinder.Outcome) -> some View {
        Anchor.SettingsSection(
            title: "From the words",
            footer: "This reads only the words, not the sound: a question and its reply, a change between I and you. It cannot hear anyone, so it can be wrong. Nothing changes until you choose Use this instead, and you can go back."
        ) {
            if let other {
                let count = other.personCount
                Text(showingWords
                     ? "You are looking at the guess from the words."
                     : (count == 1 ? "The words read as 1 person." : "The words read as \(count) people."))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                Button {
                    let current = outcome
                    self.outcome = other
                    self.other = current
                    showingWords.toggle()
                    names = [:]
                } label: {
                    Text(showingWords ? "Go back to the first" : "Use this instead")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                }
            } else if AIGate.isEnabled {
                if guessing {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Reading the words…").font(.system(.subheadline, design: .rounded))
                    }
                    Button {
                        guessTask?.cancel()
                    } label: {
                        Text("Stop").font(.system(.subheadline, design: .rounded))
                    }
                } else {
                    Button {
                        guess(outcome)
                    } label: {
                        Text(AIFeature.findSpeakerChanges.title).font(.system(.subheadline, design: .rounded))
                    }
                }
            } else if AIGate.showsOffButtons {
                AIOffButton { showingAIOff = true } content: {
                    Text(AIFeature.findSpeakerChanges.title).font(.system(.subheadline, design: .rounded))
                }
            }
            if let guessNote {
                Text(guessNote).font(.system(.footnote, design: .rounded)).foregroundStyle(.secondary)
            }
        }
    }

    private func guess(_ base: PeopleFinder.Outcome) {
        guard AIGate.isEnabled, !guessing else { return }
        let provider = AIProviders.make(AIProviders.chosen)
        let prompt = SpeakerWords.prompt(for: base.pieces, limit: provider.maxCharacters)
        guard !prompt.pieces.isEmpty else {
            guessNote = AIError.nothingToSend.plainText
            return
        }
        guessing = true
        guessNote = nil
        guessTask = Task {
            do {
                let answer = try await ask.run(.findSpeakerChanges, on: prompt.text, using: provider)
                let turns = SpeakerWords.turns(from: answer, pieces: prompt.pieces)
                if !AIGate.isEnabled {
                    // Turned off while it worked: nothing is shown.
                } else if turns.isEmpty {
                    guessNote = "No change of speaker could be read from the answer. Nothing was kept."
                } else {
                    other = PeopleFinder.relined(base, turns: turns)
                    if !prompt.coversAll { guessNote = "The recording is long, so only the first part of the words was read." }
                }
            } catch let error as AIError {
                if error != .cancelled { guessNote = error.plainText }
            } catch {
                guessNote = AIError.failed.plainText
            }
            guessing = false
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
