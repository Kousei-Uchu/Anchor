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
//  One screen, no Edit button. Tap an empty day to schedule a session, tap a
//  day with a session (or its row in the list) to move or cancel it, and the
//  plus schedules one for any date. The typical cadence is a stepper right on
//  the screen.
//

import SwiftUI
import SwiftData

/// Asks for the schedule sheet for one date.
private struct ScheduleRequest: Identifiable {
    let id = UUID()
    let date: Date
}

/// Sessions: the next one, a month calendar you can tap, the list of
/// sessions, and the typical cadence.
struct AppointmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var series: AppointmentSeries

    @State private var displayedMonth: Date = .now
    @State private var scheduling: ScheduleRequest?
    @State private var editingOccurrence: AppointmentOccurrence?
    @State private var occurrenceToDelete: AppointmentOccurrence?
    @State private var showRemoveAllConfirm = false

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
                            Button("Schedule a session") { scheduling = ScheduleRequest(date: .now) }
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
                            onSelectDay: selectDay
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
                            HStack {
                                Anchor.SectionHeader(icon: "list.bullet", title: "All sessions")
                                Spacer()
                                Button("Remove all", role: .destructive) {
                                    showRemoveAllConfirm = true
                                }
                                .font(.caption)
                            }
                            ForEach(sortedOccurrences) { occurrence in
                                Button {
                                    editingOccurrence = occurrence
                                } label: {
                                    HStack {
                                        Text(occurrence.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                        if occurrence.wasMoved {
                                            Text("moved").font(.caption2).foregroundStyle(Anchor.Theme.sage)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .foregroundStyle(occurrence.scheduledDate < .now ? .secondary : .primary)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Opens the session")
                                .anchorDeletable("Cancel session") { modelContext.delete(occurrence) }
                            }
                        }
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
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle(series.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.AddToolbarButton(label: "Schedule a session") {
                    scheduling = ScheduleRequest(date: .now)
                }
            }
        }
        .sheet(item: $scheduling) { request in
            ScheduleSessionSheet(series: series, date: request.date)
        }
        .sheet(item: $editingOccurrence, onDismiss: finishEditing) { occurrence in
            OccurrenceEditorSheet(occurrence: occurrence) { occurrenceToDelete = occurrence }
        }
        .confirmationDialog("Remove all sessions?", isPresented: $showRemoveAllConfirm, titleVisibility: .visible) {
            Button("Remove all", role: .destructive) {
                for occurrence in series.occurrences { modelContext.delete(occurrence) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// A day with a session opens that session. An empty day opens the
    /// schedule sheet for that date.
    private func selectDay(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        if let existing = occurrencesByDay[day]?.first {
            editingOccurrence = existing
        } else {
            scheduling = ScheduleRequest(date: date)
        }
    }

    /// Runs once the session sheet has closed. Cancelling here, not while the
    /// sheet is still on screen, keeps the sheet from reading a session that
    /// is already gone.
    private func finishEditing() {
        if let occurrence = occurrenceToDelete {
            occurrenceToDelete = nil
            modelContext.delete(occurrence)
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

/// Schedule either just one date, or a repeating run of sessions starting
/// there (spaced by the series' cadence, since that's the exact "typical
/// cadence" the user already set). The date can be changed here, so the plus
/// in the bar and a tap on an empty calendar day open the same sheet.
private struct ScheduleSessionSheet: View {
    let series: AppointmentSeries
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var time = Date()
    @State private var repeats = false
    @State private var numberOfSessions = 4

    init(series: AppointmentSeries, date: Date) {
        self.series = series
        _date = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
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

/// One session in one sheet: move it (which marks it moved, keeping history
/// honest) or cancel it outright.
private struct OccurrenceEditorSheet: View {
    @Bindable var occurrence: AppointmentOccurrence
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: "Session",
            onDelete: onDelete,
            deleteTitle: "Cancel this session",
            deleteQuestion: "Cancel this session?"
        ) {
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
            }
        }
    }
}


// MARK: - Providers

/// Which of a provider's pages the host is showing.
enum ProviderPage {
    case sessions, prep, afterSession

    var title: String {
        switch self {
        case .sessions: return "Appointments"
        case .prep: return "Session prep"
        case .afterSession: return "Post-session notes"
        }
    }
}

/// The screen behind every appointments, session prep and after-session
/// link. It shows one provider's page at a time. With two or more providers a
/// row of names at the top switches between them, and the menu in the bar has
/// Details for the one shown and a way to add another. With none, it says so
/// and offers to add one, rather than making one up.
struct ProviderPageHost: View {
    let page: ProviderPage
    /// The provider to open first, usually the one with the next session.
    var startingWith: UUID? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppointmentSeries.sortOrder) private var providers: [AppointmentSeries]
    @State private var selectedID: UUID?
    @State private var editing: AppointmentSeries?
    @State private var toDelete: AppointmentSeries?

    private var current: AppointmentSeries? {
        providers.first { $0.id == selectedID }
            ?? providers.first { $0.id == startingWith }
            ?? providers.first
    }

    var body: some View {
        Group {
            if let provider = current {
                pageView(for: provider)
                    .id(provider.id)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if providers.count > 1 { nameRow(selected: provider) }
                    }
            } else {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "person.2.fill",
                        title: "No one added yet",
                        message: "Add the people you see. Each one gets their own sessions and notes.",
                        actionTitle: "Add someone",
                        tint: Anchor.Theme.sage
                    ) { addProvider() }
                    .padding()
                }
                .anchorBackground()
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let provider = current {
                    Menu {
                        Button { editing = provider } label: {
                            Label("Details for \(provider.displayName)", systemImage: "person.text.rectangle")
                        }
                        Button { addProvider() } label: {
                            Label("Add someone", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Providers")
                }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { provider in
            ProviderEditorSheet(provider: provider) { toDelete = provider }
        }
    }

    @ViewBuilder private func pageView(for provider: AppointmentSeries) -> some View {
        switch page {
        case .sessions: AppointmentView(series: provider)
        case .prep: AppointmentPrepView(series: provider)
        case .afterSession: PostSessionNotesView(series: provider)
        }
    }

    /// One button per provider, so a person with two or more can move between them.
    private func nameRow(selected: AppointmentSeries) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(providers) { provider in
                    let isSelected = provider.id == selected.id
                    Button {
                        selectedID = provider.id
                    } label: {
                        Text(provider.displayName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(isSelected ? Anchor.Theme.accent : Color.primary)
                            .background(isSelected ? Anchor.Theme.accentSoft : Color.clear, in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(isSelected ? Anchor.Theme.accent : Color.secondary.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
    }

    private func addProvider() {
        let new = AppointmentSeries(
            clinicianLabel: "",
            sortOrder: (providers.map(\.sortOrder).max() ?? -1) + 1
        )
        modelContext.insert(new)
        selectedID = new.id
        editing = new
    }

    /// Runs once the sheet has closed, so it never reads a provider that is
    /// already gone. A provider added and left with no name, role, notes or
    /// sessions is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for provider in providers where provider !== deleting && provider.isBlankProvider {
            modelContext.delete(provider)
        }
    }
}

private extension AppointmentSeries {
    var isBlankProvider: Bool {
        clinicianLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && occurrences.isEmpty
    }
}

private struct ProviderEditorSheet: View {
    @Bindable var provider: AppointmentSeries
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: provider.clinicianLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New provider" : "Provider",
            onDelete: onDelete,
            deleteTitle: "Remove this provider",
            deleteQuestion: "Remove this provider and their sessions? Notes you wrote stay in your Journal."
        ) {
            Form {
                Section {
                    TextField("Name", text: $provider.clinicianLabel)
                        .textInputAutocapitalization(.words)
                    TextField("What they do, if you like", text: $provider.role)
                }
                Section("Name on exports") {
                    TextField("Same as the name above", text: $provider.exportLabel)
                }
                Section("Notes") {
                    TextField("Anything you want to remember about them", text: $provider.notes, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
        }
    }
}
