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

/// The affirmation rotation as something to read: one calm card per line.
/// Writing, reordering, deleting and browsing suggestions live behind Edit
/// (`AffirmationsEditorView`).
struct AffirmationsView: View {
    @Query(sort: \Affirmation.sortOrder) private var affirmations: [Affirmation]
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if affirmations.isEmpty {
                    Anchor.EmptyState(
                        icon: "sparkles",
                        title: "Nothing here yet",
                        message: "Write your own, or browse a pool of suggestions and keep whichever ones land. Nothing here is fixed.",
                        actionTitle: "Add some",
                        tint: Anchor.Theme.accent
                    ) { showingEditor = true }
                } else {
                    ForEach(affirmations) { affirmation in
                        Anchor.Card {
                            Text(affirmation.text)
                                .font(.system(.title3, design: .rounded))
                                .italic()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Affirmations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit affirmations") {
                AffirmationsEditorView()
            }
        }
    }
}

/// The affirmations editor. Presented from `AffirmationsView` via Edit,
/// never browsed to directly.
struct AffirmationsEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Affirmation.sortOrder) private var affirmations: [Affirmation]
    @State private var newText = ""
    @State private var showSuggestions = false

    var body: some View {
        List {
            Section {
                Text("Your own rotation. Write something, or browse suggestions below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            Section {
                ForEach(affirmations) { affirmation in
                    TextField("Affirmation", text: Binding(
                        get: { affirmation.text },
                        set: { affirmation.text = $0 }
                    ), axis: .vertical)
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(affirmations[index]) }
                }
                .onMove { source, destination in
                    var reordered = affirmations
                    reordered.move(fromOffsets: source, toOffset: destination)
                    for (index, item) in reordered.enumerated() { item.sortOrder = index }
                }

                HStack {
                    TextField("Write your own", text: $newText, axis: .vertical)
                    Button("Add") {
                        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        modelContext.insert(Affirmation(text: trimmed, sortOrder: affirmations.count))
                        newText = ""
                    }
                }
            }

            Section {
                Button {
                    showSuggestions = true
                } label: {
                    Label("Browse suggestions", systemImage: "text.book.closed.fill")
                }
            }
        }
        .toolbar { EditButton() }
        .sheet(isPresented: $showSuggestions) {
            AffirmationSuggestionsView(alreadyAdded: Set(affirmations.map(\.text))) { text in
                modelContext.insert(Affirmation(text: text, sortOrder: affirmations.count))
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
