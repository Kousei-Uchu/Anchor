//
//  UnsentDraftsView.swift
//  Anchor
//
//  Write now, share when ready. wasSent is a self-reported toggle the user
//  sets after they've actually sent it some other way — this view never
//  sends anything itself, so "never forced to send" is a real property of
//  the code, not just a UI framing choice.
//
//  Editing follows the app-wide pattern: tap a draft to edit it, a plus
//  starts a new one, and Delete is in the long-press menu and in the editor.
//

import SwiftUI
import SwiftData

struct UnsentDraftsView: View {
    @Query private var draftsStored: [UnsentDraft]
    /// Sorted after the items are opened, because a locked createdAt cannot be sorted by the database (Patch 35g2).
    private var drafts: [UnsentDraft] { draftsStored.sortedByKey(descending: true) { $0.createdAt } }
    @Environment(\.modelContext) private var modelContext
    @State private var editingDraft: UnsentDraft?
    @State private var draftToDelete: UnsentDraft?

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if drafts.isEmpty {
                    Anchor.EmptyState(
                        icon: "square.and.pencil",
                        title: "Nothing here yet",
                        message: "A place for the big things you might never send, to anyone. Write now, share only if and when you're ready.",
                        actionTitle: "Start a draft",
                        tint: Anchor.Theme.sage
                    ) { startNewDraft() }
                } else {
                    ForEach(drafts) { draft in
                        Button {
                            editingDraft = draft
                        } label: {
                            Anchor.Card(accentColor: Anchor.Theme.sage) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(draft.recipientLabel.isEmpty ? "Untitled" : draft.recipientLabel)
                                                .font(.system(.headline, design: .rounded))
                                                .foregroundStyle(.primary)
                                            if draft.wasSent {
                                                Label("Sent", systemImage: "checkmark")
                                                    .font(.caption)
                                                    .foregroundStyle(Anchor.Theme.sage)
                                            }
                                        }
                                        Text(draft.text)
                                            .lineLimit(2)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .anchorDeletable { modelContext.delete(draft) }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Things I haven't said")
        .guideButton("thread.unsent", tab: .thread)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.AddToolbarButton(label: "New draft") { startNewDraft() }
            }
        }
        .sheet(item: $editingDraft, onDismiss: finishEditing) { draft in
            UnsentDraftEditor(draft: draft) { draftToDelete = draft }
        }
    }

    /// Starting a draft is writing something new, so it opens the editor
    /// straight away.
    private func startNewDraft() {
        let new = UnsentDraft(recipientLabel: "", text: "")
        modelContext.insert(new)
        editingDraft = new
    }

    /// Runs once the editor has closed. Deleting here, not while the editor
    /// is still on screen, keeps the editor from reading a draft that is
    /// already gone. A draft with nothing in it is dropped too.
    private func finishEditing() {
        if let draft = draftToDelete {
            modelContext.delete(draft)
            draftToDelete = nil
        }
        for draft in drafts where draft.recipientLabel.isEmpty
            && draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(draft)
        }
    }
}

private struct UnsentDraftEditor: View {
    @Bindable var draft: UnsentDraft
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(title: "Draft", onDelete: onDelete, deleteQuestion: "Delete this draft?") {
            Form {
                TextField("Who this is for (e.g. \"partner\")", text: $draft.recipientLabel)
                Section {
                    TextEditor(text: $draft.text).frame(minHeight: 200)
                }
                Toggle("I've actually sent this", isOn: $draft.wasSent)
            }
        }
    }
}
