//
//  AffirmationsView.swift
//  Anchor
//
//  A user's own rotation of affirmations/quotes, shown on Now (and a
//  widget). Nothing here is generated or chosen for the user automatically
//  — write your own, or browse a curated suggestion pool and add whichever
//  ones actually land, including the exact kind of thing requested:
//  something like "and the universe said I love you because you are love."
//  The suggestion pool is fixed and reviewed, same as every other
//  pre-written content pool in this app (mascot lines, de-escalation
//  scripts) — nothing here is generated at runtime.
//

import SwiftUI
import SwiftData

struct AffirmationsCardView: View {
    @Query(sort: \Affirmation.sortOrder) private var affirmations: [Affirmation]
    @State private var currentIndex = 0

    private var current: String {
        guard !affirmations.isEmpty else {
            return "Add your own, or browse suggestions in Plan. Nothing here is fixed."
        }
        return affirmations[currentIndex % affirmations.count].text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Anchor.SectionHeader(icon: "sparkles", title: "Something to hold onto", tint: Anchor.Theme.accent)
            Text(current)
                .font(.system(.title3, design: .rounded))
                .italic()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Anchor.Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12))

            if affirmations.count > 1 {
                Button("Another") {
                    withAnimation { currentIndex += 1 }
                }
                .buttonStyle(Anchor.SecondaryButtonStyle())
            }
        }
    }
}

/// The affirmation rotation. Tap a card to rewrite it, the plus adds one, and
/// Delete is in the editor and in the card's long-press menu. Order is the
/// order "Another" steps through on Now, so there is a labelled Reorder.
struct AffirmationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Affirmation.sortOrder) private var affirmations: [Affirmation]
    @State private var editing: Affirmation?
    @State private var toDelete: Affirmation?
    @State private var showSuggestions = false

    var body: some View {
        Group {
            if affirmations.isEmpty {
                ScrollView {
                    VStack(spacing: Anchor.Theme.spacing) {
                        Anchor.EmptyState(
                            icon: "sparkles",
                            title: "Nothing here yet",
                            message: "Write your own, or browse a pool of suggestions and keep whichever ones land. Nothing here is fixed.",
                            actionTitle: "Write one",
                            tint: Anchor.Theme.accent
                        ) { startNew() }
                        suggestionsButton
                    }
                    .padding()
                }
            } else {
                List {
                    ForEach(affirmations) { affirmation in
                        Anchor.Card {
                            Button { editing = affirmation } label: {
                                Text(affirmation.text.isEmpty ? "Untitled" : affirmation.text)
                                    .font(.system(.title3, design: .rounded))
                                    .italic()
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the editor")
                        }
                        .anchorDeletable { modelContext.delete(affirmation) }
                        .anchorCardRow()
                    }
                    .onMove(perform: move)

                    suggestionsButton
                        .anchorCardRow()
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Affirmations")
        .guideButton("now.affirmations", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if affirmations.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Anchor.AddToolbarButton(label: "Write an affirmation") { startNew() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { affirmation in
            AffirmationEditorSheet(affirmation: affirmation) { toDelete = affirmation }
        }
        .sheet(isPresented: $showSuggestions) {
            AffirmationSuggestionsView(alreadyAdded: Set(affirmations.map(\.text))) { text in
                modelContext.insert(Affirmation(text: text, sortOrder: affirmations.count))
            }
        }
    }

    private var suggestionsButton: some View {
        HStack {
            Spacer()
            Button {
                showSuggestions = true
            } label: {
                Label("Browse suggestions", systemImage: "text.book.closed.fill")
            }
            .buttonStyle(Anchor.SecondaryButtonStyle())
            Spacer()
        }
    }

    private func startNew() {
        let new = Affirmation(text: "", sortOrder: affirmations.count)
        modelContext.insert(new)
        editing = new
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = affirmations
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in reordered.enumerated() { item.sortOrder = index }
    }

    /// Runs once the editor has closed, so the editor never reads an item that
    /// is already gone. One added and left blank is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for item in affirmations where item !== deleting
            && item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(item)
        }
    }
}

private struct AffirmationEditorSheet: View {
    @Bindable var affirmation: Affirmation
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: affirmation.text.isEmpty ? "New affirmation" : "Affirmation",
            onDelete: onDelete,
            deleteQuestion: "Delete this affirmation?"
        ) {
            Form {
                Section {
                    TextField("Something to hold onto", text: $affirmation.text, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
        }
    }
}

private struct AffirmationSuggestionsView: View {
    let alreadyAdded: Set<String>
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var added: Set<String> = []

    /// Fixed, reviewed pool — spans a few different flavors (cosmic/warm,
    /// grounding, self-worth, resilience) since one tone doesn't fit
    /// everyone or every day. Never generated, never auto-added.
    private static let suggestions = [
        "And the universe said I love you, because you are love.",
        "You are allowed to take up space, exactly as you are right now.",
        "This feeling is real, and it is not permanent.",
        "You don't have to earn the right to rest.",
        "Something in you already knows how to survive hard days. It's gotten you through every one so far.",
        "You are not a burden. You are a person having a hard time.",
        "Small and slow is still moving.",
        "You are allowed to change your mind about what you can handle today.",
        "The people who love you are not keeping score.",
        "You don't have to be useful to be worth keeping around.",
        "It's okay to not be okay and still be trying.",
        "You are made of the same stardust as everything else that gets to exist.",
        "Whatever you're carrying right now, you don't have to carry it perfectly.",
        "You are allowed to need things.",
        "This moment is not the whole story.",
        "You're doing better than your brain is telling you right now.",
        "Rest is not something you have to justify.",
        "You are worth showing up for, including by yourself.",
        "The version of you who gets through today doesn't have to have it all figured out.",
        "You are not behind. There is no schedule you're failing to keep.",
        "Someone, somewhere, is glad you exist, even on the days you can't feel it.",
        "You get to be a whole person, not just the hard parts.",
        "It's okay to take up the space you need to heal.",
        "You are allowed to be a work in progress."
    ]

    var body: some View {
        NavigationStack {
            List(Self.suggestions, id: \.self) { text in
                HStack {
                    Text(text)
                    Spacer()
                    if alreadyAdded.contains(text) || added.contains(text) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Anchor.Theme.accent)
                    } else {
                        Button("Add") {
                            onAdd(text)
                            added.insert(text)
                        }
                        .buttonStyle(Anchor.SecondaryButtonStyle())
                    }
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
