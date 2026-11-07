//
//  BridgeDraftListView.swift
//  Anchor
//
//  Built up between sessions. "Resolved" just means "already brought this
//  up" — a checkbox, not a score, and resolved items stay visible (toggled,
//  not hidden) so the running history is still there to export.
//
//  Tap an item to reword it, the plus adds one, and Delete is inside the item
//  and in its long-press menu. Ticking an item off stays on the card, because
//  it is a quick action, not editing.
//

import SwiftUI
import SwiftData

struct BridgeDraftListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BridgeDraftItem.createdAt, order: .reverse) private var items: [BridgeDraftItem]
    @State private var editing: BridgeDraftItem?
    @State private var toDelete: BridgeDraftItem?
    @State private var showingExport = false

    var body: some View {
        Group {
            if items.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "doc.text.fill",
                        title: "Nothing to bring up yet",
                        message: "Add things here as they come up, whenever they come up. They'll be waiting for your next session.",
                        actionTitle: "Add something",
                        tint: Anchor.Theme.accent
                    ) { startNew() }
                    .padding()
                }
            } else {
                List {
                    ForEach(items) { item in
                        BridgeDraftItemCard(item: item) { editing = item }
                            .anchorDeletable { modelContext.delete(item) }
                            .anchorCardRow()
                    }
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Bridge draft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export")
                Anchor.AddToolbarButton(label: "Add something") { startNew() }
            }
        }
        .sheet(isPresented: $showingExport) {
            BridgeExportView(items: items)
        }
        .sheet(item: $editing, onDismiss: finishEditing) { item in
            BridgeDraftItemEditorSheet(item: item) { toDelete = item }
        }
    }

    private func startNew() {
        let new = BridgeDraftItem(text: "")
        modelContext.insert(new)
        editing = new
    }

    /// Runs once the editor has closed, so the editor never reads an item that
    /// is already gone. One added and left blank is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for item in items where item !== deleting
            && item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(item)
        }
    }
}

private struct BridgeDraftItemCard: View {
    @Bindable var item: BridgeDraftItem
    let onEdit: () -> Void

    var body: some View {
        Anchor.Card {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    item.isResolved.toggle()
                } label: {
                    Image(systemName: item.isResolved ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isResolved ? Anchor.Theme.sage : Anchor.Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isResolved ? "Mark as not brought up" : "Mark as brought up")

                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.text.isEmpty ? "Untitled" : item.text)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(item.isResolved ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the editor")
            }
        }
    }
}

private struct BridgeDraftItemEditorSheet: View {
    @Bindable var item: BridgeDraftItem
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: item.text.isEmpty ? "New item" : "Item",
            onDelete: onDelete,
            deleteQuestion: "Delete this item?"
        ) {
            Form {
                Section {
                    TextField("Something to bring up next session", text: $item.text, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Toggle("Already brought up", isOn: $item.isResolved)
                }
            }
        }
    }
}
