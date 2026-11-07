//
//  RecoveryHomeView.swift
//  Anchor
//
//  Entry point for the optional Recovery area: counters, the craving tool and
//  motivations. A read screen: reminders and other toggles live in Settings
//  (gear), not here. Nothing here is shown anywhere else in the app unless the
//  user adds a counter.
//

import SwiftUI
import SwiftData

struct RecoveryHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryCounter.sortOrder) private var allCounters: [RecoveryCounter]
    @State private var showingNewCounter = false
    @State private var showingSettings = false

    private var counters: [RecoveryCounter] { allCounters.filter { !$0.isArchived } }

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                Text("Your own counters, kept on this phone. Nothing here is scored, shared or compared.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink { CravingToolView() } label: {
                    Anchor.Card(accentColor: Anchor.Theme.sage) {
                        Anchor.MenuRow(icon: "wind", title: "Riding out an urge",
                                       subtitle: "A timer, your reasons, and your grounding tools",
                                       tint: Anchor.Theme.sage)
                    }
                }
                .buttonStyle(.plain)

                if counters.isEmpty {
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Anchor.SectionHeader(icon: "calendar", title: "Counters")
                            Text("Add a counter for something you're stepping away from, or a habit you're building. You choose the name, the start date and how the days are counted.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ForEach(counters) { counter in
                        NavigationLink { RecoveryCounterDetailView(counter: counter) } label: {
                            RecoveryCounterCard(counter: counter)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    showingNewCounter = true
                } label: {
                    Label("Add a counter", systemImage: "plus")
                }
                .buttonStyle(Anchor.SecondaryButtonStyle())

                NavigationLink { RecoveryMotivationsView() } label: {
                    Anchor.Card {
                        Anchor.MenuRow(icon: "heart.fill", title: "Who I'm doing this for",
                                       subtitle: "People and reasons, in your own words")
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Anchor.GearButton(label: "Recovery settings") { showingSettings = true }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingNewCounter) {
            NavigationStack { RecoveryCounterEditorView(counter: nil) }
        }
        .onAppear { RecoveryNotifications.refresh(using: modelContext) }
        .onChange(of: allCounters.count) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
    }
}

private struct RecoveryCounterCard: View {
    let counter: RecoveryCounter

    var body: some View {
        let days = counter.currentRunDays()
        Anchor.Card {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(counter.name)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                    if counter.mode == .runAndTotal, counter.totalDays() != days {
                        Text("\(RecoveryText.days(counter.totalDays())) in total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Next: \(RecoveryMilestones.label(RecoveryMilestones.next(after: days)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text(counter.currentRunReading().number)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(Anchor.Theme.accent)
                    Text(counter.currentRunReading().label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Now tab presence

/// A quiet Recovery card for the Now tab. It only appears once the user has
/// added a counter, so people who never use Recovery never see it. Nothing here
/// scores or nags: it shows where each counter is, offers today's pledge only if
/// the user turned that reminder on, and keeps "Ride out an urge" one tap away.
struct RecoveryNowCard: View {
    @Query(sort: \RecoveryCounter.sortOrder) private var allCounters: [RecoveryCounter]
    @Query private var entries: [RecoveryDayEntry]
    @AppStorage(RecoverySettings.pledgeEnabled) private var pledgeEnabled = false

    private var counters: [RecoveryCounter] { allCounters.filter { !$0.isArchived } }
    private var today: Date { Calendar.current.startOfDay(for: .now) }

    /// The first counter without a pledge today, and only if daily pledge is switched on.
    private var counterNeedingPledge: RecoveryCounter? {
        guard pledgeEnabled else { return nil }
        return counters.first { counter in
            !entries.contains { $0.counterID == counter.id && $0.day == today && $0.pledgedAt != nil }
        }
    }

    var body: some View {
        if !counters.isEmpty {
            Anchor.Card(accentColor: Anchor.Theme.sage) {
                VStack(alignment: .leading, spacing: 12) {
                    Anchor.SectionHeader(icon: "calendar.badge.checkmark", title: "Recovery", tint: Anchor.Theme.sage)

                    ForEach(Array(counters.prefix(3).enumerated()), id: \.element.id) { index, counter in
                        if index > 0 { Divider() }
                        NavigationLink { RecoveryCounterDetailView(counter: counter) } label: {
                            counterRow(counter)
                        }
                        .buttonStyle(.plain)
                    }

                    if let counter = counterNeedingPledge {
                        NavigationLink { RecoveryPledgeView(counter: counter) } label: {
                            Label("Today's pledge", systemImage: "hand.raised.fill")
                        }
                        .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
                    }

                    NavigationLink { CravingToolView() } label: {
                        Label("Ride out an urge", systemImage: "wind")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle())
                }
            }
        }
    }

    private func counterRow(_ counter: RecoveryCounter) -> some View {
        let days = counter.currentRunDays()
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(counter.name)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                if let milestone = counter.unacknowledgedMilestone() {
                    Text("You've reached \(RecoveryMilestones.label(milestone)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Next: \(RecoveryMilestones.label(RecoveryMilestones.next(after: days)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(spacing: 0) {
                Text(counter.currentRunReading().number)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(Anchor.Theme.accent)
                Text(counter.currentRunReading().label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
