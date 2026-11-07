//
//  UnsentDraftsView.swift
//  Anchor
//
//  Write now, share when ready. wasSent is a self-reported toggle the user
//  sets after they've actually sent it some other way — this view never
//  sends anything itself, so "never forced to send" is a real property of
//  the code, not just a UI framing choice.
//

import SwiftUI
import SwiftData

struct UnsentDraftsView: View {
    @Query(sort: \UnsentDraft.createdAt, order: .reverse) private var drafts: [UnsentDraft]
    @Environment(\.modelContext) private var modelContext
    @State private var editingDraft: UnsentDraft?
    @State private var showingEditor = false

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
                        NavigationLink {
                            UnsentDraftView(draft: draft)
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
                    }
                    Button {
                        startNewDraft()
                    } label: {
                        Label("New draft", systemImage: "plus")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle())
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Things I haven't said")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !drafts.isEmpty {
                    Anchor.EditToolbarButton { showingEditor = true }
                }
            }
        }
        .sheet(item: $editingDraft) { draft in
            UnsentDraftEditor(draft: draft)
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit drafts") {
                UnsentDraftsManageView()
            }
        }
    }

    /// Starting a draft is writing something new, so it opens the writing
    /// sheet straight away.
    private func startNewDraft() {
        let new = UnsentDraft(recipientLabel: "", text: "")
        modelContext.insert(new)
        editingDraft = new
    }
}

/// One draft as something to read. Edit opens the writing sheet; "I've
/// actually sent this" is a quick self-report, so it stays here.
private struct UnsentDraftView: View {
    @Bindable var draft: UnsentDraft
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                Anchor.TextCard(
                    icon: "square.and.pencil",
                    title: draft.recipientLabel.isEmpty ? "Untitled" : "For \(draft.recipientLabel)",
                    text: draft.text,
                    placeholder: "Nothing written yet. Tap Edit to start.",
                    tint: Anchor.Theme.sage
                )
                Button {
                    draft.wasSent.toggle()
                } label: {
                    Label(draft.wasSent ? "Marked as sent" : "I've actually sent this",
                          systemImage: draft.wasSent ? "checkmark.circle.fill" : "paperplane")
                }
                .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle(draft.recipientLabel.isEmpty ? "Draft" : draft.recipientLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            UnsentDraftEditor(draft: draft)
        }
    }
}

/// Delete drafts, or tap one to rewrite it. Presented from Edit.
private struct UnsentDraftsManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UnsentDraft.createdAt, order: .reverse) private var drafts: [UnsentDraft]
    @State private var editingDraft: UnsentDraft?

    var body: some View {
        List {
            ForEach(drafts) { draft in
                Button {
                    editingDraft = draft
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.recipientLabel.isEmpty ? "Untitled" : draft.recipientLabel)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(draft.text)
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(drafts[index]) }
            }
        }
        .toolbar { EditButton() }
        .sheet(item: $editingDraft) { draft in
            UnsentDraftEditor(draft: draft)
        }
    }
}

private struct UnsentDraftEditor: View {
    @Bindable var draft: UnsentDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Who this is for (e.g. \"partner\")", text: $draft.recipientLabel)
                Section {
                    TextEditor(text: $draft.text).frame(minHeight: 200)
                }
                Toggle("I've actually sent this", isOn: $draft.wasSent)
            }
            .anchorSettingsStyle()
            .navigationTitle("Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
