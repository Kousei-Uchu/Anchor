//
//  RecoveryMotivationsView.swift
//  Anchor
//
//  "Who I'm doing this for" and "why it matters", written by the user. These
//  appear on the daily pledge and the craving tool. Nothing is pre-filled.
//

import SwiftUI
import SwiftData

struct RecoveryMotivationsView: View {
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
        .navigationTitle("Who I'm doing this for")
        .navigationBarTitleDisplayMode(.inline)
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
