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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UnsentDraft.createdAt, order: .reverse) private var drafts: [UnsentDraft]
    @State private var editingDraft: UnsentDraft?

    var body: some View {
        List {
            ForEach(drafts) { draft in
                Button {
                    editingDraft = draft
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(draft.recipientLabel.isEmpty ? "Untitled" : draft.recipientLabel)
                                .font(.headline)
                            if draft.wasSent {
                                Text("Sent").font(.caption2).foregroundStyle(.green)
                            }
                        }
                        Text(draft.text)
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(drafts[index]) }
            }

            Button("New draft") {
                let new = UnsentDraft(recipientLabel: "", text: "")
                modelContext.insert(new)
                editingDraft = new
            }
        }
        .navigationTitle("Things I haven't said")
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
            .navigationTitle("Draft")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
