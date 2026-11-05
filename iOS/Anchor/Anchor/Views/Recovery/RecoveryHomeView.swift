//
//  RecoveryHomeView.swift
//  Anchor
//
//  Entry point for the optional Recovery area: counters, the craving tool,
//  motivations and reminders. Nothing here is shown anywhere else in the app
//  unless the user adds a counter.
//

import SwiftUI
import SwiftData

struct RecoveryHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryCounter.sortOrder) private var allCounters: [RecoveryCounter]
    @State private var showingNewCounter = false

    @AppStorage(RecoverySettings.pledgeEnabled) private var pledgeEnabled = false
    @AppStorage(RecoverySettings.pledgeHour) private var pledgeHour = 8
    @AppStorage(RecoverySettings.pledgeMinute) private var pledgeMinute = 0
    @AppStorage(RecoverySettings.reviewEnabled) private var reviewEnabled = false
    @AppStorage(RecoverySettings.reviewHour) private var reviewHour = 20
    @AppStorage(RecoverySettings.reviewMinute) private var reviewMinute = 30
    @AppStorage(RecoverySettings.milestonesEnabled) private var milestonesEnabled = false

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

                remindersCard
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewCounter) {
            NavigationStack { RecoveryCounterEditorView(counter: nil) }
        }
        .onAppear { RecoveryNotifications.refresh(using: modelContext) }
        .onChange(of: allCounters.count) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
    }

    private var remindersCard: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 12) {
                Anchor.SectionHeader(icon: "bell.fill", title: "Reminders", tint: Anchor.Theme.sage)

                Toggle("Daily pledge", isOn: $pledgeEnabled)
                if pledgeEnabled {
                    DatePicker("Time", selection: timeBinding($pledgeHour, $pledgeMinute), displayedComponents: .hourAndMinute)
                }
                Toggle("Evening review", isOn: $reviewEnabled)
                if reviewEnabled {
                    DatePicker("Time", selection: timeBinding($reviewHour, $reviewMinute), displayedComponents: .hourAndMinute)
                }
                Toggle("Milestones", isOn: $milestonesEnabled)

                Text("Reminders and widgets use generic wording, like \"A quiet moment for yourself?\", so nobody reading your lock screen learns what you're tracking. You can show a counter's name outside the app by turning that on for the counter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tint(Anchor.Theme.accent)
        }
        .onChange(of: pledgeEnabled) { _, isOn in remindersChanged(isOn) }
        .onChange(of: reviewEnabled) { _, isOn in remindersChanged(isOn) }
        .onChange(of: milestonesEnabled) { _, isOn in remindersChanged(isOn) }
        .onChange(of: pledgeHour) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
        .onChange(of: pledgeMinute) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
        .onChange(of: reviewHour) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
        .onChange(of: reviewMinute) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
    }

    private func remindersChanged(_ isOn: Bool) {
        if isOn { NotificationScheduler.askForPermissionIfNeeded() }
        RecoveryNotifications.refresh(using: modelContext)
    }

    private func timeBinding(_ hour: Binding<Int>, _ minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: hour.wrappedValue, minute: minute.wrappedValue, second: 0, of: .now) ?? .now },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                hour.wrappedValue = parts.hour ?? 8
                minute.wrappedValue = parts.minute ?? 0
            }
        )
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
                    Text("\(days)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(Anchor.Theme.accent)
                    Text(days == 1 ? "day" : "days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
