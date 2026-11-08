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

/// The de-escalation scripts, one quoted card each. Tap a card to rewrite it,
/// the plus adds one, and Delete is in the editor and in the card's long-press
/// menu. Order is the order "Try another" steps through on Now, so there is a
/// labelled Reorder. Seeded with a few varied starting points only when there
/// are none, as before.
struct DeEscalationScriptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DeEscalationScript.sortOrder) private var scripts: [DeEscalationScript]
    @State private var editing: DeEscalationScript?
    @State private var toDelete: DeEscalationScript?

    var body: some View {
        Group {
            if scripts.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "wind",
                        title: "No scripts yet",
                        message: "What actually gets you 10 minutes of space, in words that sound like you?",
                        actionTitle: "Write one",
                        tint: Anchor.Theme.sage
                    ) { startNew() }
                    .padding()
                }
            } else {
                List {
                    ForEach(scripts) { script in
                        Anchor.Card(accentColor: Anchor.Theme.sage) {
                            Button { editing = script } label: {
                                Text("\u{201C}\(script.text)\u{201D}")
                                    .font(.system(.title3, design: .rounded))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the editor")
                        }
                        .anchorDeletable { modelContext.delete(script) }
                        .anchorCardRow()
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("De-escalation scripts")
        .guideButton("now.de-escalation", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if scripts.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Anchor.AddToolbarButton(label: "Write a script") { startNew() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { script in
            DeEscalationScriptEditorSheet(script: script) { toDelete = script }
        }
        .onAppear { seedDeEscalationDefaultsIfNeeded(scripts: scripts, context: modelContext) }
    }

    private func startNew() {
        let new = DeEscalationScript(text: "", sortOrder: scripts.count)
        modelContext.insert(new)
        editing = new
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = scripts
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, script) in reordered.enumerated() { script.sortOrder = index }
    }

    /// Runs once the editor has closed, so the editor never reads a script that
    /// is already gone. One added and left blank is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for script in scripts where script !== deleting
            && script.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(script)
        }
    }
}

private struct DeEscalationScriptEditorSheet: View {
    @Bindable var script: DeEscalationScript
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: script.text.isEmpty ? "New script" : "Script",
            onDelete: onDelete,
            deleteQuestion: "Delete this script?"
        ) {
            Form {
                Section {
                    TextField("What would you say?", text: $script.text, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
        }
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
