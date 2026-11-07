//
//  RecoveryMotivationsView.swift
//  Anchor
//
//  "Who I'm doing this for" and "why it matters", written by the user. These
//  appear on the daily pledge and the craving tool. Nothing is pre-filled.
//

import SwiftUI
import SwiftData

/// Motivations: who you're doing this for, and why it matters. Tap a card to
/// rewrite it, the plus (or the button under each heading) adds one, and
/// Delete is in the editor and in the card's long-press menu. There is no
/// Reorder because the order of these doesn't mean anything.
struct RecoveryMotivationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryMotivation.sortOrder) private var motivations: [RecoveryMotivation]
    @State private var editing: RecoveryMotivation?
    @State private var toDelete: RecoveryMotivation?

    var body: some View {
        Group {
            if motivations.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "heart.fill",
                        title: "Who are you doing this for?",
                        message: "Add the people, pets or future you that matter. They're only for you, and they show up when you take today's pledge and when you're riding out an urge.",
                        actionTitle: "Add someone",
                        tint: Anchor.Theme.accent
                    ) { startNew(.person) }
                    .padding()
                }
            } else {
                List {
                    ForEach(MotivationKind.allCases) { kind in
                        Anchor.SectionHeader(icon: icon(for: kind), title: kind.sectionTitle, tint: tint(for: kind))
                            .anchorCardRow()

                        ForEach(items(kind)) { item in
                            Anchor.Card(accentColor: tint(for: kind)) {
                                Button { editing = item } label: {
                                    Text(item.text.isEmpty ? "Untitled" : item.text)
                                        .font(.system(.body, design: .rounded))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens the editor")
                            }
                            .anchorDeletable { modelContext.delete(item) }
                            .anchorCardRow()
                        }

                        HStack {
                            Button { startNew(kind) } label: {
                                Label(addTitle(for: kind), systemImage: "plus")
                            }
                            .buttonStyle(Anchor.SecondaryButtonStyle(tint: tint(for: kind)))
                            Spacer()
                        }
                        .anchorCardRow()
                    }
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Who I'm doing this for")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { startNew(.person) } label: {
                        Label("Someone I'm doing this for", systemImage: "heart.fill")
                    }
                    Button { startNew(.reason) } label: {
                        Label("Why it matters to me", systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add")
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { item in
            MotivationEditorSheet(motivation: item) { toDelete = item }
        }
    }

    private func items(_ kind: MotivationKind) -> [RecoveryMotivation] {
        motivations.filter { $0.kind == kind }
    }

    private func icon(for kind: MotivationKind) -> String {
        kind == .person ? "heart.fill" : "sparkles"
    }

    private func tint(for kind: MotivationKind) -> Color {
        kind == .person ? Anchor.Theme.accent : Anchor.Theme.sage
    }

    private func addTitle(for kind: MotivationKind) -> String {
        kind == .person ? "Add someone" : "Add a reason"
    }

    private func startNew(_ kind: MotivationKind) {
        let new = RecoveryMotivation(kind: kind, text: "", sortOrder: motivations.count)
        modelContext.insert(new)
        editing = new
    }

    /// Runs once the editor has closed, so the editor never reads an item that
    /// is already gone. One added and left blank is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for item in motivations where item !== deleting
            && item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(item)
        }
    }
}

private struct MotivationEditorSheet: View {
    @Bindable var motivation: RecoveryMotivation
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: motivation.kind == .person ? "Who I'm doing this for" : "Why it matters",
            onDelete: onDelete,
            deleteQuestion: "Delete this?"
        ) {
            Form {
                Section {
                    TextField(
                        motivation.kind == .person ? "A person, a pet, a future you" : "Something that matters to you",
                        text: $motivation.text,
                        axis: .vertical
                    )
                    .lineLimit(2...8)
                }
            }
        }
    }
}
