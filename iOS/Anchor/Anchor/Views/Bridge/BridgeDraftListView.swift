//
//  BridgeDraftListView.swift
//  Anchor
//
//  Built up between sessions. "Resolved" just means "already brought this
//  up" — a checkbox, not a score, and resolved items stay visible (toggled,
//  not hidden) so the running history is still there to export.
//
//  Browse/edit split: the list is something you read (ticking an item off
//  is a quick action, so it stays here). Adding is its own small compose
//  sheet; rewording and deleting live behind Edit.
//

import SwiftUI
import SwiftData

struct BridgeDraftListView: View {
    @Query(sort: \BridgeDraftItem.createdAt, order: .reverse) private var items: [BridgeDraftItem]
    @State private var showingComposer = false
    @State private var showingEditor = false
    @State private var showingExport = false

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if items.isEmpty {
                    Anchor.EmptyState(
                        icon: "doc.text.fill",
                        title: "Nothing to bring up yet",
                        message: "Add things here as they come up, whenever they come up. They'll be waiting for your next session.",
                        actionTitle: "Add something",
                        tint: Anchor.Theme.accent
                    ) { showingComposer = true }
                } else {
                    ForEach(items) { item in
                        BridgeDraftItemCard(item: item)
                    }
                    Button {
                        showingComposer = true
                    } label: {
                        Label("Add something", systemImage: "plus")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle())
                }
            }
            .padding()
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
                if !items.isEmpty {
                    Anchor.EditToolbarButton { showingEditor = true }
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            BridgeExportView(items: items)
        }
        .sheet(isPresented: $showingComposer) {
            BridgeDraftComposer()
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit draft") {
                BridgeDraftManageView()
            }
        }
    }
}

private struct BridgeDraftItemCard: View {
    @Bindable var item: BridgeDraftItem

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

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.text)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(item.isResolved ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// A small compose sheet for adding one item.
private struct BridgeDraftComposer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Something to bring up next session", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Add to draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !trimmed.isEmpty else { return }
                        modelContext.insert(BridgeDraftItem(text: trimmed))
                        dismiss()
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
        }
    }
}

/// Reword or delete items. Presented from Edit.
private struct BridgeDraftManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BridgeDraftItem.createdAt, order: .reverse) private var items: [BridgeDraftItem]

    var body: some View {
        List {
            ForEach(items) { item in
                BridgeDraftEditRow(item: item)
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(items[index]) }
            }
        }
        .toolbar { EditButton() }
    }
}

private struct BridgeDraftEditRow: View {
    @Bindable var item: BridgeDraftItem

    var body: some View {
        TextField("Item", text: $item.text, axis: .vertical)
            .font(.system(.subheadline, design: .rounded))
    }
}
