//
//  BridgeDraftListView.swift
//  Anchor
//
//  Built up between sessions. "Resolved" just means "already brought this
//  up" — a checkbox, not a score, and resolved items stay visible (toggled,
//  not hidden) so the running history is still there to export.
//

import SwiftUI
import SwiftData

struct BridgeDraftListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BridgeDraftItem.createdAt, order: .reverse) private var items: [BridgeDraftItem]
    @State private var newItemText = ""
    @State private var showingExport = false

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Something to bring up next session", text: $newItemText, axis: .vertical)
                    Button("Add") {
                        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        modelContext.insert(BridgeDraftItem(text: trimmed))
                        newItemText = ""
                    }
                }
            }

            Section("Draft") {
                if items.isEmpty {
                    Text("Nothing yet. Add things here as they come up, whenever they come up.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    HStack(alignment: .top) {
                        Button {
                            item.isResolved.toggle()
                        } label: {
                            Image(systemName: item.isResolved ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading) {
                            Text(item.text)
                                .foregroundStyle(item.isResolved ? .secondary : .primary)
                            Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(items[index]) }
                }
            }
        }
        .navigationTitle("Bridge draft")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            BridgeExportView(items: items)
        }
    }
}
