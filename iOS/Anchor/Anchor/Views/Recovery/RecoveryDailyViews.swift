//
//  RecoveryDailyViews.swift
//  Anchor
//
//  The daily pledge and the evening review. Both are free text and gentle:
//  no rating, no score, and skipping a day leaves no mark.
//

import SwiftUI
import SwiftData

// MARK: - Pledge

struct RecoveryPledgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryMotivation.sortOrder) private var motivations: [RecoveryMotivation]
    @Query private var entries: [RecoveryDayEntry]

    let counter: RecoveryCounter

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var todaysEntry: RecoveryDayEntry? {
        entries.first(where: { $0.counterID == counter.id && $0.day == today })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if motivations.isEmpty {
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Anchor.SectionHeader(icon: "heart.fill", title: "Who I'm doing this for")
                            Text("Add the people and reasons that matter to you, and they'll show up here each day.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            NavigationLink { RecoveryMotivationsView() } label: {
                                Label("Add some", systemImage: "plus")
                            }
                            .buttonStyle(Anchor.SecondaryButtonStyle())
                        }
                    }
                } else {
                    ForEach(MotivationKind.allCases) { kind in
                        let items = motivations.filter { $0.kind == kind }
                        if !items.isEmpty {
                            Anchor.Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    Anchor.SectionHeader(icon: kind == .person ? "heart.fill" : "star.fill", title: kind.sectionTitle)
                                    ForEach(items) { item in
                                        Text(item.text).font(.body)
                                    }
                                }
                            }
                        }
                    }
                }

                Anchor.Card(accentColor: Anchor.Theme.sage) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Just for today, I'm sticking with my choice about \(counter.name).")
                            .font(.system(.title3, design: .rounded))
                        if let pledgedAt = todaysEntry?.pledgedAt {
                            Label("Pledged at \(pledgedAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Anchor.Theme.sage)
                        } else {
                            Button("I'm in for today") { pledge() }
                                .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
                        }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Today's pledge")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pledge() {
        let entry = todaysEntry ?? {
            let created = RecoveryDayEntry(counterID: counter.id, day: today)
            modelContext.insert(created)
            return created
        }()
        entry.pledgedAt = .now
    }
}

// MARK: - Evening review

struct RecoveryReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [RecoveryDayEntry]

    let counter: RecoveryCounter

    @State private var helped = ""
    @State private var hard = ""
    @State private var tomorrow = ""
    @State private var loaded = false

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var todaysEntry: RecoveryDayEntry? {
        entries.first(where: { $0.counterID == counter.id && $0.day == today })
    }

    var body: some View {
        Form {
            Section {
                Text("All of this is optional, and none of it is scored. Write as much or as little as you like.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            Section("What helped today") {
                TextField("Anything, even something small", text: $helped, axis: .vertical)
            }
            Section("What was hard") {
                TextField("You don't have to explain it", text: $hard, axis: .vertical)
            }
            Section("One thing for tomorrow") {
                TextField("Something kind to your future self", text: $tomorrow, axis: .vertical)
            }
        }
        .navigationTitle("Evening review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let entry = todaysEntry {
                helped = entry.helped
                hard = entry.hard
                tomorrow = entry.tomorrow
            }
        }
    }

    private func save() {
        let entry = todaysEntry ?? {
            let created = RecoveryDayEntry(counterID: counter.id, day: today)
            modelContext.insert(created)
            return created
        }()
        entry.helped = helped
        entry.hard = hard
        entry.tomorrow = tomorrow
        entry.reviewedAt = .now
        dismiss()
    }
}
