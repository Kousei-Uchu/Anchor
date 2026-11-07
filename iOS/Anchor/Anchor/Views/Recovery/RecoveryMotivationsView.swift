//
//  RecoveryMotivationsView.swift
//  Anchor
//
//  "Who I'm doing this for" and "why it matters", written by the user. These
//  appear on the daily pledge and the craving tool. Nothing is pre-filled.
//

import SwiftUI
import SwiftData

/// Motivations as something to read: who you're doing this for, and why it
/// matters. Writing and deleting live behind Edit
/// (`RecoveryMotivationsEditorView`).
struct RecoveryMotivationsView: View {
    @Query(sort: \RecoveryMotivation.sortOrder) private var motivations: [RecoveryMotivation]
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if motivations.isEmpty {
                    Anchor.EmptyState(
                        icon: "heart.fill",
                        title: "Who are you doing this for?",
                        message: "Add the people, pets or future you that matter. They're only for you, and they show up when you take today's pledge and when you're riding out an urge.",
                        actionTitle: "Add some",
                        tint: Anchor.Theme.accent
                    ) { showingEditor = true }
                } else {
                    card(for: .person, icon: "heart.fill", tint: Anchor.Theme.accent)
                    card(for: .reason, icon: "sparkles", tint: Anchor.Theme.sage)
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Who I'm doing this for")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit") {
                RecoveryMotivationsEditorView()
            }
        }
    }

    private func card(for kind: MotivationKind, icon: String, tint: Color) -> some View {
        let lines = motivations.filter { $0.kind == kind }.map(\.text)
        return Anchor.TextCard(
            icon: icon,
            title: kind.sectionTitle,
            text: lines.joined(separator: "\n\n"),
            tint: tint
        )
    }
}

/// The motivations editor. Presented from `RecoveryMotivationsView` via
/// Edit, never browsed to directly.
struct RecoveryMotivationsEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryMotivation.sortOrder) private var motivations: [RecoveryMotivation]
    @State private var newPerson = ""
    @State private var newReason = ""

    var body: some View {
        List {
            Section {
                Text("These are only for you. They show up when you take today's pledge, and when you're riding out an urge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            section(for: .person, text: $newPerson, placeholder: "A person, a pet, a future you")
            section(for: .reason, text: $newReason, placeholder: "Something that matters to you")
        }
        .toolbar { EditButton() }
    }

    private func items(_ kind: MotivationKind) -> [RecoveryMotivation] {
        motivations.filter { $0.kind == kind }
    }

    @ViewBuilder
    private func section(for kind: MotivationKind, text: Binding<String>, placeholder: String) -> some View {
        Section(kind.sectionTitle) {
            ForEach(items(kind)) { item in
                TextField("", text: Binding(get: { item.text }, set: { item.text = $0 }), axis: .vertical)
            }
            .onDelete { offsets in
                let current = items(kind)
                for index in offsets { modelContext.delete(current[index]) }
            }

            HStack {
                TextField(placeholder, text: text, axis: .vertical)
                Button("Add") {
                    let trimmed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    modelContext.insert(RecoveryMotivation(kind: kind, text: trimmed, sortOrder: motivations.count))
                    text.wrappedValue = ""
                }
            }
        }
    }
}
