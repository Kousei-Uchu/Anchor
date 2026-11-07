//
//  DeEscalationAndQuietRoomView.swift
//  Anchor
//
//  Quiet Room removed: it was a local toggle with no actual downstream
//  effect anywhere in the app (nothing ever read or displayed it — the
//  "visible to your chosen people" copy described a feature that was never
//  actually wired up), which matches it "appearing to do nothing." Rather
//  than half-build a real shared-presence feature nobody asked to keep,
//  it's gone, and this file is just the de-escalation script now.
//
//  The script itself is no longer a single hardcoded line — it's a real,
//  user-editable, reorderable list (DeEscalationScript model, edited in
//  Plan), with a "try another" button to cycle through them here, since a
//  script that actually helps is the user's own words, not one line picked
//  by a first draft.
//

import SwiftUI
import SwiftData

struct DeEscalationCardView: View {
    @Query(sort: \DeEscalationScript.sortOrder) private var scripts: [DeEscalationScript]
    @State private var currentIndex = 0

    private var currentScript: String {
        guard !scripts.isEmpty else {
            return "Add your own script in Plan. Nothing here is fixed."
        }
        return scripts[currentIndex % scripts.count].text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Anchor.SectionHeader(icon: "wind", title: "De-escalation script", tint: Anchor.Theme.sage)
            Text("\u{201C}\(currentScript)\u{201D}")
                .font(.system(.title3, design: .rounded))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Anchor.Theme.sageSoft, in: RoundedRectangle(cornerRadius: 12))

            if scripts.count > 1 {
                Button("Try another") {
                    withAnimation { currentIndex += 1 }
                }
                .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
            }
        }
    }
}

/// The de-escalation scripts as something to read: a quoted card per script.
/// Rewriting, reordering and deleting live behind Edit
/// (`DeEscalationScriptsEditorView`). Seeded with a few varied starting
/// points only when there are none, as before.
struct DeEscalationScriptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DeEscalationScript.sortOrder) private var scripts: [DeEscalationScript]
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if scripts.isEmpty {
                    Anchor.EmptyState(
                        icon: "wind",
                        title: "No scripts yet",
                        message: "What actually gets you 10 minutes of space, in words that sound like you?",
                        actionTitle: "Write one",
                        tint: Anchor.Theme.sage
                    ) { showingEditor = true }
                } else {
                    ForEach(scripts) { script in
                        Anchor.Card(accentColor: Anchor.Theme.sage) {
                            Text("\u{201C}\(script.text)\u{201D}")
                                .font(.system(.title3, design: .rounded))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("De-escalation scripts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit scripts") {
                DeEscalationScriptsEditorView()
            }
        }
        .onAppear { seedDeEscalationDefaultsIfNeeded(scripts: scripts, context: modelContext) }
    }
}

private func seedDeEscalationDefaultsIfNeeded(scripts: [DeEscalationScript], context: ModelContext) {
    guard scripts.isEmpty else { return }
    let starters = [
        "I need 10 minutes, then we can talk.",
        "I'm not okay right now. I need space, not a conversation.",
        "Can we pause this? I'll come find you when I've calmed down."
    ]
    for (index, text) in starters.enumerated() {
        context.insert(DeEscalationScript(text: text, sortOrder: index))
    }
}

/// The scripts editor. Presented from `DeEscalationScriptsView` via Edit,
/// never browsed to directly. Whatever the user has is authoritative,
/// including if they delete everything.
struct DeEscalationScriptsEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DeEscalationScript.sortOrder) private var scripts: [DeEscalationScript]
    @State private var newScriptText = ""

    var body: some View {
        List {
            Section {
                Text("These are yours to rewrite. What actually gets you 10 minutes of space, in words that sound like you?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            Section {
                ForEach(scripts) { script in
                    TextField("Script", text: Binding(
                        get: { script.text },
                        set: { script.text = $0 }
                    ), axis: .vertical)
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(scripts[index]) }
                }
                .onMove { source, destination in
                    var reordered = scripts
                    reordered.move(fromOffsets: source, toOffset: destination)
                    for (index, script) in reordered.enumerated() { script.sortOrder = index }
                }

                HStack {
                    TextField("Add a script", text: $newScriptText, axis: .vertical)
                    Button("Add") {
                        let trimmed = newScriptText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        modelContext.insert(DeEscalationScript(text: trimmed, sortOrder: scripts.count))
                        newScriptText = ""
                    }
                }
            }
        }
        .toolbar { EditButton() }
    }
}
