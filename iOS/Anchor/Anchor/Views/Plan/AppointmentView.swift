//
//  AppointmentView.swift
//  Anchor
//
//  Was a stack of steppers, DatePicker rows, and add/delete buttons —
//  feedback asked for a calendar month view instead, where tapping a date
//  is how you schedule, move, or cancel a session. A typical cadence is
//  still just a default for *suggesting* dates when scheduling a
//  repeating run — every individual occurrence is still its own row
//  underneath, because real sessions get moved and this needs to survive
//  that without losing history.
//

import SwiftUI
import SwiftData

/// Sessions as something to look at: the next one, a read-only month, and
/// the list of sessions. Scheduling, moving, cancelling and the typical
/// cadence all live behind Edit (`AppointmentEditorView`).
struct AppointmentView: View {
    let series: AppointmentSeries

    @State private var displayedMonth: Date = .now
    @State private var showingEditor = false

    private var calendar: Calendar { Calendar.current }

    private var occurrencesByDay: [Date: [AppointmentOccurrence]] {
        Dictionary(grouping: series.occurrences) { calendar.startOfDay(for: $0.scheduledDate) }
    }

    private var sortedOccurrences: [AppointmentOccurrence] {
        series.occurrences.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var nextOccurrence: AppointmentOccurrence? {
        sortedOccurrences.first { $0.scheduledDate > .now }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Anchor.Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Anchor.SectionHeader(icon: "calendar.badge.clock", title: "Next session")
                        if let next = nextOccurrence {
                            Text(next.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(.title3, design: .rounded))
                            Text(daysUntil(next.scheduledDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Nothing scheduled yet.")
                                .foregroundStyle(.secondary)
                            Button("Schedule a session") { showingEditor = true }
                                .buttonStyle(Anchor.SecondaryButtonStyle())
                                .padding(.top, 4)
                        }
                    }
                }

                Anchor.Card {
                    VStack(alignment: .leading, spacing: 12) {
                        monthHeader

                        MonthCalendarGrid(
                            displayedMonth: displayedMonth,
                            occurrencesByDay: occurrencesByDay,
                            onSelectDay: nil
                        )

                        HStack(spacing: 16) {
                            Label("Scheduled", systemImage: "circle.fill")
                                .foregroundStyle(Anchor.Theme.accent)
                            Label("Moved", systemImage: "circle.fill")
                                .foregroundStyle(Anchor.Theme.sage)
                        }
                        .font(.caption2)
                        .labelStyle(.titleAndIcon)
                    }
                }

                if !sortedOccurrences.isEmpty {
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Anchor.SectionHeader(icon: "list.bullet", title: "All sessions")
                            ForEach(sortedOccurrences) { occurrence in
                                HStack {
                                    Text(occurrence.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                    if occurrence.wasMoved {
                                        Text("moved").font(.caption2).foregroundStyle(Anchor.Theme.sage)
                                    }
                                    Spacer()
                                }
                                .foregroundStyle(occurrence.scheduledDate < .now ? .secondary : .primary)
                            }
                        }
                    }
                }

                Text("Usually about every \(series.typicalCadenceDays) days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle(series.clinicianLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit sessions") {
                AppointmentEditorView(series: series)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth }
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(.headline, design: .rounded))
            Spacer()
            Button {
                withAnimation { displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .tint(Anchor.Theme.accent)
    }

    private func daysUntil(_ date: Date) -> String {
        let days = calendar.dateComponents([.day], from: .now, to: date).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }
}

/// The scheduling editor: tap a date to schedule or move a session, set the
/// typical cadence, delete sessions. Presented from `AppointmentView` via
/// Edit, never browsed to directly.
struct AppointmentEditorView: View {
    @Bindable var series: AppointmentSeries
    @Environment(\.modelContext) private var modelContext

    @State private var displayedMonth: Date = .now
    @State private var selectedDate: Date?
    @State private var occurrenceForSelectedDate: AppointmentOccurrence?
    @State private var showScheduleSheet = false
    @State private var showOccurrenceSheet = false
    @State private var showRemoveAllConfirm = false

    private var calendar: Calendar { Calendar.current }

    private var occurrencesByDay: [Date: [AppointmentOccurrence]] {
        Dictionary(grouping: series.occurrences) { calendar.startOfDay(for: $0.scheduledDate) }
    }

    private var nextOccurrence: AppointmentOccurrence? {
        series.occurrences
            .filter { $0.scheduledDate > .now }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Anchor.Card {
                    VStack(alignment: .leading, spacing: 4) {
                        Anchor.SectionHeader(icon: "calendar.badge.clock", title: "Next session")
                        if let next = nextOccurrence {
                            Text(next.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(.title3, design: .rounded))
                            Text(daysUntil(next.scheduledDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Nothing scheduled. Tap a date below.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Anchor.Card {
                    VStack(alignment: .leading, spacing: 12) {
                        monthHeader

                        MonthCalendarGrid(
                            displayedMonth: displayedMonth,
                            occurrencesByDay: occurrencesByDay
                        ) { date in
                            selectedDate = date
                            let day = calendar.startOfDay(for: date)
                            if let existing = occurrencesByDay[day]?.first {
                                occurrenceForSelectedDate = existing
                                showOccurrenceSheet = true
                            } else {
                                showScheduleSheet = true
                            }
                        }

                        HStack(spacing: 16) {
                            Label("Scheduled", systemImage: "circle.fill")
                                .foregroundStyle(Anchor.Theme.accent)
                            Label("Moved", systemImage: "circle.fill")
                                .foregroundStyle(Anchor.Theme.sage)
                        }
                        .font(.caption2)
                        .labelStyle(.titleAndIcon)
                    }
                }

                Anchor.Card(accentColor: Anchor.Theme.sage) {
                    VStack(alignment: .leading, spacing: 8) {
                        Anchor.SectionHeader(icon: "arrow.triangle.2.circlepath", title: "Typical cadence", tint: Anchor.Theme.sage)
                        Stepper("Every \(series.typicalCadenceDays) days", value: $series.typicalCadenceDays, in: 1...60)
                        Text("Just a starting point for suggesting dates when you schedule a repeating run. The actual gap can always be longer or shorter.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !series.occurrences.isEmpty {
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Anchor.SectionHeader(icon: "list.bullet", title: "All sessions")
                                Spacer()
                                Button("Remove all", role: .destructive) {
                                    showRemoveAllConfirm = true
                                }
                                .font(.caption)
                            }
                            ForEach(series.occurrences.sorted { $0.scheduledDate < $1.scheduledDate }) { occurrence in
                                HStack {
                                    Button {
                                        selectedDate = occurrence.scheduledDate
                                        occurrenceForSelectedDate = occurrence
                                        showOccurrenceSheet = true
                                    } label: {
                                        HStack {
                                            Text(occurrence.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                            if occurrence.wasMoved {
                                                Text("moved").font(.caption2).foregroundStyle(Anchor.Theme.sage)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.primary)

                                    Button {
                                        modelContext.delete(occurrence)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .confirmationDialog("Remove all sessions?", isPresented: $showRemoveAllConfirm, titleVisibility: .visible) {
                        Button("Remove all", role: .destructive) {
                            for occurrence in series.occurrences { modelContext.delete(occurrence) }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showScheduleSheet) {
            if let selectedDate {
                ScheduleSessionSheet(series: series, date: selectedDate)
            }
        }
        .sheet(isPresented: $showOccurrenceSheet) {
            if let occurrenceForSelectedDate {
                OccurrenceEditorSheet(occurrence: occurrenceForSelectedDate)
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth }
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(.headline, design: .rounded))
            Spacer()
            Button {
                withAnimation { displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .tint(Anchor.Theme.accent)
    }

    private func daysUntil(_ date: Date) -> String {
        let days = calendar.dateComponents([.day], from: .now, to: date).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }
}

/// A plain month grid — no event-kit dependency, just Calendar math. Marks
/// days that have a scheduled occurrence; tapping any day (marked or not)
/// hands the date back to the caller to decide what to show.
private struct MonthCalendarGrid: View {
    let displayedMonth: Date
    let occurrencesByDay: [Date: [AppointmentOccurrence]]
    let onSelectDay: ((Date) -> Void)?

    private var calendar: Calendar { Calendar.current }

    private var daysInGrid: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        var days: [Date?] = []
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        days.append(contentsOf: Array(repeating: nil, count: leadingBlanks))

        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let occurrence = occurrencesByDay[dayStart]?.first
        let isToday = calendar.isDateInToday(date)

        let content = VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? Anchor.Theme.accent : .primary)

            Circle()
                .fill(occurrence == nil ? Color.clear : (occurrence!.wasMoved ? Anchor.Theme.sage : Anchor.Theme.accent))
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(isToday ? Anchor.Theme.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 8))

        return Group {
            if let onSelectDay {
                Button {
                    onSelectDay(date)
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }
}

/// Shown when tapping an empty date: schedule either just this one date,
/// or a repeating run of sessions starting here (spaced by the series'
/// cadence, since that's the exact "typical cadence" the user already set).
private struct ScheduleSessionSheet: View {
    @Bindable var series: AppointmentSeries
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var time = Date()
    @State private var repeats = false
    @State private var numberOfSessions = 4

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    Text(date.formatted(date: .complete, time: .omitted))
                        .foregroundStyle(.secondary)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section {
                    Toggle("Repeat", isOn: $repeats)
                        .tint(Anchor.Theme.accent)
                    if repeats {
                        Stepper("\(numberOfSessions) sessions, every \(series.typicalCadenceDays) days", value: $numberOfSessions, in: 2...26)
                    }
                } footer: {
                    Text(repeats
                         ? "Creates \(numberOfSessions) sessions starting here, \(series.typicalCadenceDays) days apart. Any of them can still be moved or cancelled individually afterward."
                         : "Just this one session.")
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") { schedule() }
                }
            }
        }
    }

    private func schedule() {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        guard let firstDate = Calendar.current.date(from: dateComponents) else { dismiss(); return }

        let count = repeats ? numberOfSessions : 1
        for index in 0..<count {
            let sessionDate = Calendar.current.date(byAdding: .day, value: index * series.typicalCadenceDays, to: firstDate) ?? firstDate
            series.occurrences.append(AppointmentOccurrence(scheduledDate: sessionDate))
        }
        dismiss()
    }
}

/// Shown when tapping a date that already has a session: move it (which
/// marks it moved, keeping history honest) or cancel it outright.
private struct OccurrenceEditorSheet: View {
    @Bindable var occurrence: AppointmentOccurrence
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showCancelConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Date & time") {
                    DatePicker("Scheduled", selection: Binding(
                        get: { occurrence.scheduledDate },
                        set: { newDate in
                            if newDate != occurrence.scheduledDate { occurrence.wasMoved = true }
                            occurrence.scheduledDate = newDate
                        }
                    ))
                    if occurrence.wasMoved {
                        Text("This session has been moved from its original time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Cancel this session", role: .destructive) {
                        showCancelConfirm = true
                    }
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Cancel this session?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                Button("Cancel session", role: .destructive) {
                    modelContext.delete(occurrence)
                    dismiss()
                }
                Button("Keep it", role: .cancel) {}
            }
        }
    }
}
