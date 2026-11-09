//
//  AIBraindumpSheet.swift
//  Anchor
//
//  Tidy a braindump (Patch AI4, docs/OPTIONAL_FEATURES.md, E4). Words the person wrote or pasted go to an AI
//  tool only when they tap one of the buttons here, through `AIAsk`, so the switch, the checks and the consent
//  sheet all apply. What comes back is a list of lines to tick. Nothing becomes a task or a thing to raise until
//  the ticked lines are added, the app never picks which of the two it should be, and the words it started from
//  are never changed. A task or item made from a Journal entry remembers which entry, and nothing else.
//

import SwiftUI
import SwiftData

/// Where a tidied braindump can go. The person picks; the app never guesses.
enum BraindumpDestination: String, CaseIterable, Identifiable {
    case tasks
    case thingsToRaise

    var id: String { rawValue }

    /// The tool that makes this kind of list.
    var feature: AIFeature {
        switch self {
        case .tasks: return .turnIntoTasks
        case .thingsToRaise: return .turnIntoThingsToRaise
        }
    }

    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .thingsToRaise: return "doc.text"
        }
    }

    /// The button that adds the ticked lines.
    func addTitle(_ count: Int) -> String {
        switch self {
        case .tasks: return count == 1 ? "Add 1 task" : "Add \(count) tasks"
        case .thingsToRaise: return count == 1 ? "Add 1 thing to raise" : "Add \(count) things to raise"
        }
    }

    /// What is said once they have been added.
    func addedText(_ count: Int) -> String {
        switch self {
        case .tasks: return count == 1 ? "Added 1 task." : "Added \(count) tasks."
        case .thingsToRaise: return count == 1 ? "Added 1 thing to raise." : "Added \(count) things to raise."
        }
    }
}

/// Words picked for the sheet, so a screen can hold them with `.sheet(item:)`.
struct BraindumpDraft: Identifiable {
    let id = UUID()
    let text: String
}

/// The quiet line saying which Journal entry something was made from, when it was made from one.
enum JournalSourceLine {
    static func text(for id: UUID?, in context: ModelContext) -> String? {
        guard let id else { return nil }
        let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate<JournalEntry> { $0.id == id })
        if let entry = try? context.fetch(descriptor).first {
            return "From your Journal, " + entry.createdAt.formatted(date: .abbreviated, time: .omitted)
        }
        return "From a Journal entry that is no longer here"
    }
}

/// The sheet. It is opened with the words to work on and the lists this screen offers: the Journal offers both,
/// the Tasks screen offers tasks and the Things to raise screen offers things to raise. A Journal entry is shown
/// as it is and is never changed here; pasted words can be edited in the box.
struct AIBraindumpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @StateObject private var ask = AIAsk()
    @State private var text: String
    @State private var suggestions: [Suggestion] = []
    @State private var shownFor: BraindumpDestination?
    @State private var message: String?

    /// Which lists this sheet offers.
    let destinations: [BraindumpDestination]
    /// True when the words can be changed here (pasted text). False for a Journal entry.
    let canEdit: Bool
    /// The Journal entry the words came from, when they came from one.
    let sourceEntryID: UUID?
    /// The person a thing to raise is for, when Things to raise is showing one person's. Nil is for anyone.
    let providerID: UUID?
    /// Called after something was added, so the screen that opened this can clear what it was holding.
    let onAdded: (() -> Void)?

    private struct Suggestion: Identifiable {
        let id = UUID()
        let text: String
        var ticked = false
    }

    init(text: String, canEdit: Bool, destinations: [BraindumpDestination],
         sourceEntryID: UUID? = nil, providerID: UUID? = nil, onAdded: (() -> Void)? = nil) {
        _text = State(initialValue: text)
        self.canEdit = canEdit
        self.destinations = destinations
        self.sourceEntryID = sourceEntryID
        self.providerID = providerID
        self.onAdded = onAdded
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if canEdit {
                        TextEditor(text: $text)
                            .frame(minHeight: 160)
                    } else {
                        Text(text)
                            .font(.system(.body, design: .rounded))
                            .textSelection(.enabled)
                    }
                } header: {
                    Text(canEdit ? "Paste or write it here" : "Your words")
                }
                if AIGate.isEnabled {
                    Section {
                        ForEach(destinations) { destination in
                            Button {
                                suggest(destination)
                            } label: {
                                Label(destination.feature.title, systemImage: destination.icon)
                            }
                            .disabled(ask.isWorking || trimmedText.isEmpty)
                        }
                        if ask.isWorking && ask.pending == nil {
                            ProgressView()
                        }
                        if let message {
                            Text(message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let destination = shownFor, !suggestions.isEmpty {
                    Section {
                        ForEach($suggestions) { $suggestion in
                            Button {
                                suggestion.ticked.toggle()
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Image(systemName: suggestion.ticked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(suggestion.ticked ? Anchor.Theme.sage : Anchor.Theme.accent)
                                    Text(suggestion.text)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(suggestion.ticked ? .isSelected : [])
                        }
                        let count = suggestions.filter(\.ticked).count
                        HStack(spacing: 16) {
                            Button(destination.addTitle(count)) { addTicked(to: destination) }
                                .font(.subheadline.weight(.semibold))
                                .disabled(count == 0)
                            Button("Discard", role: .destructive) { dropSuggestions() }
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderless)
                    } header: {
                        Text(destination.feature.title)
                    } footer: {
                        Text("These are suggestions. Nothing is added until you tap.")
                    }
                }
            }
            .navigationTitle("Tidy a braindump")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .aiAsk(ask)
        .onReceive(NotificationCenter.default.publisher(for: .aiToolsTurnedOff)) { _ in
            // Anything half done is dropped, and so is this sheet. What was already added stays.
            suggestions = []
            shownFor = nil
            message = nil
            dismiss()
        }
    }

    /// Asks for a list from the words. It goes through `AIAsk`, so the switch is checked and the person sees
    /// exactly what is sent first. The answer is a list to tick and is not saved anywhere yet.
    private func suggest(_ destination: BraindumpDestination) {
        guard AIGate.isEnabled, !ask.isWorking else { return }
        let words = trimmedText
        message = nil
        suggestions = []
        shownFor = nil
        Task {
            do {
                let answer = try await ask.run(destination.feature, on: words)
                let lines = AIAnswerReader.items(from: answer)
                await MainActor.run {
                    guard AIGate.isEnabled else { return }
                    if lines.isEmpty {
                        message = AIError.failed.plainText
                    } else {
                        suggestions = lines.map { Suggestion(text: $0) }
                        shownFor = destination
                    }
                }
            } catch let error as AIError {
                await MainActor.run { message = error.plainText }
            } catch {
                await MainActor.run { message = AIError.failed.plainText }
            }
        }
    }

    /// Adds only the lines that were ticked. A task has no day, energy or estimate, and nothing is set that the
    /// person did not choose; what is added carries the Journal entry it came from, when there was one.
    private func addTicked(to destination: BraindumpDestination) {
        let chosen = suggestions.filter(\.ticked).map(\.text)
        guard !chosen.isEmpty else { return }
        switch destination {
        case .tasks:
            var order = (tasks.map(\.sortOrder).max() ?? -1) + 1
            for line in chosen {
                modelContext.insert(TaskItem(title: line, sortOrder: order, sourceEntryID: sourceEntryID))
                order += 1
            }
        case .thingsToRaise:
            for line in chosen {
                modelContext.insert(BridgeDraftItem(text: line, providerID: providerID, sourceEntryID: sourceEntryID))
            }
        }
        suggestions = []
        shownFor = nil
        message = destination.addedText(chosen.count)
        onAdded?()
    }

    private func dropSuggestions() {
        suggestions = []
        shownFor = nil
    }
}
