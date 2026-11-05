//
//  RecoveryCounterDetailView.swift
//  Anchor
//
//  One counter: the day count in the mode the user chose, the next milestone,
//  money saved, today's pledge and review, and a gentle way to start again.
//

import SwiftUI
import SwiftData

struct RecoveryCounterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecoveryMotivation.sortOrder) private var motivations: [RecoveryMotivation]

    let counter: RecoveryCounter

    @State private var showingEditor = false
    @State private var showingSlip = false
    @State private var pendingDelete = false

    var body: some View {
        let days = counter.currentRunDays()
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                heroCard(days: days)

                if let milestone = counter.unacknowledgedMilestone() {
                    Anchor.Card(accentColor: Anchor.Theme.sage) {
                        VStack(alignment: .leading, spacing: 10) {
                            Anchor.SectionHeader(icon: "sparkles", title: RecoveryMilestones.label(milestone), tint: Anchor.Theme.sage)
                            Text("You've reached \(RecoveryMilestones.label(milestone)). That's real, and it's yours.")
                                .font(.subheadline)
                            Button("Noted") {
                                counter.acknowledgeMilestones()
                            }
                            .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
                        }
                    }
                }

                if counter.savingsAmount > 0 {
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 4) {
                            Anchor.SectionHeader(icon: "banknote.fill", title: "Money not spent", tint: Anchor.Theme.sage)
                            Text(counter.savedAmount().formatted(.currency(code: counter.currencyCode)))
                                .font(.system(.title, design: .rounded).weight(.semibold))
                            Text("About \(counter.savingsAmount.formatted(.currency(code: counter.currencyCode))) \(counter.savingsPeriod.title), over \(RecoveryText.days(counter.daysCountedForSavings())).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Anchor.Card {
                    VStack(alignment: .leading, spacing: 4) {
                        NavigationLink { RecoveryPledgeView(counter: counter) } label: {
                            Anchor.MenuRow(icon: "hand.raised.fill", title: "Today's pledge",
                                           subtitle: "Who you're doing this for, and a moment to choose today")
                        }
                        .buttonStyle(.plain)
                        Divider()
                        NavigationLink { RecoveryReviewView(counter: counter) } label: {
                            Anchor.MenuRow(icon: "moon.stars.fill", title: "Evening review",
                                           subtitle: "A few optional words about today", tint: Anchor.Theme.sage)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !motivations.isEmpty {
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Anchor.SectionHeader(icon: "heart.fill", title: "Who I'm doing this for")
                            ForEach(motivations.prefix(3)) { item in
                                Text(item.kind == .person ? "For \(item.text)" : item.text)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                Button("I slipped, and I want to start again") { showingSlip = true }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle(counter.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { Button("Edit") { showingEditor = true } }
        }
        .sheet(isPresented: $showingEditor, onDismiss: handleEditorDismiss) {
            NavigationStack {
                RecoveryCounterEditorView(counter: counter, onDelete: {
                    pendingDelete = true
                    showingEditor = false
                })
            }
        }
        .sheet(isPresented: $showingSlip) {
            NavigationStack { RecoverySlipView(counter: counter) }
        }
    }

    private func heroCard(days: Int) -> some View {
        Anchor.Card {
            VStack(spacing: 6) {
                Text("\(days)")
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .foregroundStyle(Anchor.Theme.accent)
                Text(days == 1 ? "day" : "days")
                    .font(.system(.title3, design: .rounded))
                if counter.mode == .runAndTotal {
                    Text("\(RecoveryText.days(counter.totalDays())) in total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Next: \(RecoveryMilestones.label(RecoveryMilestones.next(after: days)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func handleEditorDismiss() {
        guard pendingDelete else {
            RecoveryNotifications.refresh(using: modelContext)
            return
        }
        pendingDelete = false
        let target = counter
        let context = modelContext
        dismiss()
        // Wait for this screen to be gone before deleting, so nothing reads a deleted counter.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            RecoveryStore.delete(target, in: context)
        }
    }
}
