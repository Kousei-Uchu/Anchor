//
//  RecoveryUrgesTab.swift
//  Anchor
//
//  Logging urges and looking back at them. How strong an urge felt is the
//  user's own description, never a score, and logging one can lead straight
//  into the "riding out an urge" tool.
//

import SwiftUI
import SwiftData

struct RecoveryUrgesTab: View {
    let counter: RecoveryCounter
    let onLog: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryUrge.date, order: .reverse) private var allUrges: [RecoveryUrge]
    @Query private var triggerWindows: [TriggerWindow]
    @State private var newWindow: TriggerWindow?
    /// "Not now" switches the suggestion off for good. Trigger windows can still be added from Plan.
    @AppStorage("recovery.triggerSuggestion.dismissed") private var suggestionDismissed = false

    private var urges: [RecoveryUrge] { allUrges.filter { $0.counterID == counter.id } }

    private var windowSuggestion: RecoveryUrgePattern.Suggestion? {
        guard !suggestionDismissed else { return nil }
        return RecoveryUrgePattern.suggestion(urgeDates: urges.map(\.date), windows: triggerWindows)
    }
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 18) {
            Anchor.Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        stat("This week", count(since: calendar.dateInterval(of: .weekOfYear, for: .now)?.start))
                        Spacer()
                        stat("This month", count(since: calendar.dateInterval(of: .month, for: .now)?.start))
                        Spacer()
                        stat("All time", urges.count)
                    }
                    miniBars
                }
            }

            Button(action: onLog) { Label("Log an urge", systemImage: "plus") }
                .buttonStyle(Anchor.SecondaryButtonStyle())

            NavigationLink { CravingToolView() } label: {
                Anchor.Card(accentColor: Anchor.Theme.sage) {
                    Anchor.MenuRow(icon: "wind", title: "Ride one out now", subtitle: "A timer, your reasons and your grounding tools",
                                   tint: Anchor.Theme.sage)
                }
            }
            .buttonStyle(.plain)

            if let suggestion = windowSuggestion {
                Anchor.Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Anchor.SectionHeader(icon: "clock.fill", title: "A pattern", tint: Anchor.Theme.sage)
                        Text("A lot of the urges you've logged have come between \(suggestion.rangeLabel). Want a trigger window for that time, so Anchor can send a gentle reminder then?")
                            .font(.subheadline)
                        HStack(spacing: 14) {
                            Button("Add a trigger window") { addWindow(suggestion) }
                                .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
                            Button("Not now") { suggestionDismissed = true }
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if urges.isEmpty {
                Text("Urges you log will show up here. Noticing them is not failing at anything.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                ForEach(groupedDays, id: \.self) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(urges.filter { calendar.startOfDay(for: $0.date) == day }) { urge in
                            row(urge)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .sheet(item: $newWindow, onDismiss: {
            NotificationScheduler.resyncTriggerWindows(using: modelContext)
        }) { window in
            TriggerWindowEditorView(window: window)
        }
    }

    /// Opens the normal trigger window editor with the time filled in. The user can change
    /// the label, days and times before tapping Done.
    private func addWindow(_ suggestion: RecoveryUrgePattern.Suggestion) {
        let window = TriggerWindow(
            label: "Urge window",
            daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
            startTime: DateComponents(hour: suggestion.startHour, minute: 0),
            endTime: DateComponents(hour: (suggestion.startHour + 2) % 24, minute: 0)
        )
        modelContext.insert(window)
        newWindow = window
    }

    private var groupedDays: [Date] {
        Array(Set(urges.map { calendar.startOfDay(for: $0.date) })).sorted(by: >)
    }

    private func count(since start: Date?) -> Int {
        guard let start else { return 0 }
        return urges.filter { $0.date >= start }.count
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(.title2, design: .rounded).weight(.semibold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    /// The last 14 days, one small bar per day.
    private var miniBars: some View {
        let today = calendar.startOfDay(for: .now)
        let days: [Date] = (0..<14).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let counts = days.map { day in urges.filter { calendar.startOfDay(for: $0.date) == day }.count }
        let top = max(counts.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(counts.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(value == 0 ? Color.secondary.opacity(0.18) : Anchor.Theme.accent.opacity(0.75))
                    .frame(height: value == 0 ? 6 : 8 + 34 * CGFloat(value) / CGFloat(top))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 46, alignment: .bottom)
    }

    private func row(_ urge: RecoveryUrge) -> some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(urge.date.formatted(date: .omitted, time: .shortened)).font(.subheadline)
                    Spacer()
                    Text(urge.strength.title)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Anchor.Theme.sage.opacity(0.28)))
                }
                if !urge.note.isEmpty {
                    Text(urge.note).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button("Delete", role: .destructive) { modelContext.delete(urge) }
        }
    }
}

struct RecoveryLogUrgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let counter: RecoveryCounter

    @State private var when = Date.now
    @State private var strength: UrgeStrength = .strong
    @State private var note = ""
    @State private var rideItOut = false

    var body: some View {
        Form {
            Section("When") {
                DatePicker("When", selection: $when, in: ...Date.now)
            }
            Section {
                Picker("How strong was it?", selection: $strength) {
                    ForEach(UrgeStrength.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("How strong was it?")
            } footer: {
                Text("However it felt to you. Nothing is scored.")
            }
            Section("Anything you want to remember?") {
                TextField("Optional", text: $note, axis: .vertical)
            }
            Section {
                Button("Save") { save(); dismiss() }
                Button("Save, then ride it out") { save(); rideItOut = true }
            }
        }
        .navigationTitle("Log an urge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .navigationDestination(isPresented: $rideItOut) { CravingToolView() }
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(RecoveryUrge(counterID: counter.id, date: when, strength: strength, note: trimmed))
    }
}
