//
//  RecoveryCounterDetailView.swift
//  Anchor
//
//  One counter, in tabs: Summary, Savings, Calendar, Urges, Reasons and Today.
//

import SwiftUI
import SwiftData

enum RecoveryTab: String, CaseIterable, Identifiable {
    case summary, savings, calendar, urges, reasons, today

    var id: String { rawValue }
    var title: String {
        switch self {
        case .summary: return "Summary"
        case .savings: return "Savings"
        case .calendar: return "Calendar"
        case .urges: return "Urges"
        case .reasons: return "Reasons"
        case .today: return "Today"
        }
    }
}

struct RecoveryCounterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecoveryMotivation.sortOrder) private var motivations: [RecoveryMotivation]

    let counter: RecoveryCounter

    @State private var tab: RecoveryTab = .summary
    @State private var showingEditor = false
    @State private var showingSlip = false
    @State private var showingUrge = false
    @State private var pendingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            tabStrip
            ScrollView {
                VStack(spacing: Anchor.Theme.spacing) {
                    if tab == .summary, let milestone = counter.unacknowledgedMilestone() {
                        milestoneCard(milestone)
                    }
                    tabContent
                }
                .padding()
            }
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
        .sheet(isPresented: $showingUrge) {
            NavigationStack { RecoveryLogUrgeView(counter: counter) }
        }
    }

    // MARK: Tabs

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecoveryTab.allCases) { item in
                    Button { tab = item } label: {
                        Text(item.title)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(tab == item ? Anchor.Theme.sage.opacity(0.35) : Color.clear))
                            .foregroundStyle(tab == item ? Color.primary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .summary:
            RecoverySummaryTab(counter: counter,
                               onShowCalendar: { tab = .calendar },
                               onLogUrge: { showingUrge = true },
                               onStartAgain: { showingSlip = true })
        case .savings:
            RecoverySavingsTab(counter: counter, onEdit: { showingEditor = true })
        case .calendar:
            RecoveryCalendarTab(counter: counter)
        case .urges:
            RecoveryUrgesTab(counter: counter, onLog: { showingUrge = true })
        case .reasons:
            reasonsContent
        case .today:
            todayContent
        }
    }

    private func milestoneCard(_ milestone: Int) -> some View {
        Anchor.Card(accentColor: Anchor.Theme.sage) {
            VStack(alignment: .leading, spacing: 10) {
                Anchor.SectionHeader(icon: "sparkles", title: RecoveryMilestones.label(milestone), tint: Anchor.Theme.sage)
                Text("You've reached \(RecoveryMilestones.label(milestone)). That's real, and it's yours.")
                    .font(.subheadline)
                Button("Noted") { counter.acknowledgeMilestones() }
                    .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
            }
        }
    }

    // MARK: Reasons

    private var reasonsContent: some View {
        VStack(spacing: Anchor.Theme.spacing) {
            if motivations.isEmpty {
                Anchor.Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Anchor.SectionHeader(icon: "heart.fill", title: "Your reasons")
                        Text("Add the people and reasons that matter to you. They'll appear here, on your daily pledge, and when you're riding out an urge.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(MotivationKind.allCases) { kind in
                    let items = motivations.filter { $0.kind == kind }
                    if !items.isEmpty {
                        Anchor.Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Anchor.SectionHeader(icon: kind == .person ? "heart.fill" : "star.fill", title: kind.sectionTitle)
                                ForEach(items) { item in Text(item.text).font(.body) }
                            }
                        }
                    }
                }
            }
            NavigationLink { RecoveryMotivationsView() } label: {
                Label(motivations.isEmpty ? "Add some" : "Edit your reasons", systemImage: "pencil")
            }
            .buttonStyle(Anchor.SecondaryButtonStyle())
        }
    }

    // MARK: Today

    private var todayContent: some View {
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

// MARK: - Savings tab

private struct RecoverySavingsTab: View {
    let counter: RecoveryCounter
    let onEdit: () -> Void

    var body: some View {
        if counter.savingsAmount > 0 {
            let perDay = counter.savingsAmount / counter.savingsPeriod.lengthInDays
            VStack(spacing: Anchor.Theme.spacing) {
                Anchor.Card {
                    VStack(spacing: 6) {
                        Text("Money not spent")
                            .font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
                        Text(counter.savedAmount().formatted(.currency(code: counter.currencyCode)))
                            .font(.system(size: 48, weight: .semibold, design: .rounded))
                        Text("Over \(RecoveryText.days(counter.daysCountedForSavings()))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                Anchor.Card {
                    VStack(spacing: 8) {
                        row("Each day", perDay)
                        Divider()
                        row("Each week", perDay * 7)
                        Divider()
                        row("Each month", perDay * 30.4375)
                        Divider()
                        row("Each year", perDay * 365)
                    }
                }
                Button("Change the amount", action: onEdit)
                    .buttonStyle(Anchor.SecondaryButtonStyle())
            }
        } else {
            Anchor.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Anchor.SectionHeader(icon: "banknote.fill", title: "Money not spent", tint: Anchor.Theme.sage)
                    Text("If this costs money, add a rough amount and Anchor will keep a running estimate of what you haven't spent. It never leaves your phone.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Add an amount", action: onEdit)
                        .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
                }
            }
        }
    }

    private func row(_ title: String, _ value: Double) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(value.formatted(.currency(code: counter.currencyCode))).font(.subheadline.weight(.semibold))
        }
    }
}
