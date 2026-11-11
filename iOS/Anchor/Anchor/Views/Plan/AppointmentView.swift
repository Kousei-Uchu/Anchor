//
//  AppointmentView.swift
//  Anchor
//
//  One calm screen for a person's sessions. The ones coming up are at the top,
//  with how far away each is. Under them is a month calendar: tap an empty day
//  to schedule a session, tap a day with one to move or cancel it, and the plus
//  schedules one for any date. Earlier sessions are folded away until asked
//  for. Removing every session is in the menu, not on the page. The usual gap
//  between sessions lives in the person's details, and in the schedule sheet
//  when a run of sessions is made.
//  Every individual session is still its own row, because real sessions get
//  moved and this has to survive that without losing history.
//

import SwiftUI
import SwiftData

/// Asks for the schedule sheet for one date.
private struct ScheduleRequest: Identifiable {
    let id = UUID()
    let date: Date
}

/// Sessions: the ones coming up, a month calendar you can tap, and the
/// earlier ones folded underneath.
struct AppointmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var series: AppointmentSeries

    @AppStorage(AppointmentReminders.dayBeforeKey) private var remindDayBefore = false
    @AppStorage(AppointmentReminders.sameDayKey) private var remindSameDay = false

    @State private var displayedMonth: Date = .now
    @State private var scheduling: ScheduleRequest?
    @State private var editingOccurrence: AppointmentOccurrence?
    @State private var occurrenceToDelete: AppointmentOccurrence?
    @State private var showRemoveAllConfirm = false
    @State private var showAllUpcoming = false
    @State private var showEarlier = false

    /// How many coming-up sessions show before "Show all".
    private let upcomingLimit = 4

    private var calendar: Calendar { Calendar.current }

    private var occurrencesByDay: [Date: [AppointmentOccurrence]] {
        Dictionary(grouping: series.occurrenceList) { calendar.startOfDay(for: $0.scheduledDate) }
    }

    private var sortedOccurrences: [AppointmentOccurrence] {
        series.occurrenceList.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// Today's sessions and every later one, soonest first.
    private var upcomingOccurrences: [AppointmentOccurrence] {
        let todayStart = calendar.startOfDay(for: .now)
        return sortedOccurrences.filter { $0.scheduledDate >= todayStart }
    }

    /// Sessions from before today, most recent first.
    private var earlierOccurrences: [AppointmentOccurrence] {
        let todayStart = calendar.startOfDay(for: .now)
        return Array(sortedOccurrences.filter { $0.scheduledDate < todayStart }.reversed())
    }

    private var hasMovedSession: Bool {
        series.occurrenceList.contains { $0.wasMoved }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sessionsCard
                calendarCard
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle(series.displayName)
        .guideButton("plan.appointments", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !series.occurrenceList.isEmpty {
                    Menu {
                        Button("Remove all sessions", role: .destructive) {
                            showRemoveAllConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
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
                for occurrence in series.occurrenceList { modelContext.delete(occurrence) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Sessions

    private var sessionsCard: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 10) {
                Anchor.SectionHeader(icon: "calendar.badge.clock", title: "Coming up")

                if upcomingOccurrences.isEmpty {
                    Text("Nothing scheduled yet.")
                        .foregroundStyle(.secondary)
                    Button("Schedule a session") { scheduling = ScheduleRequest(date: .now) }
                        .buttonStyle(Anchor.SecondaryButtonStyle())
                        .padding(.top, 4)
                } else {
                    let shown = showAllUpcoming ? upcomingOccurrences : Array(upcomingOccurrences.prefix(upcomingLimit))
                    ForEach(shown) { occurrence in
                        sessionRow(occurrence, showsDistance: true)
                    }
                    if upcomingOccurrences.count > upcomingLimit {
                        Button(showAllUpcoming ? "Show fewer" : "Show all \(upcomingOccurrences.count)") {
                            withAnimation { showAllUpcoming.toggle() }
                        }
                        .font(.footnote)
                    }
                    if !remindDayBefore && !remindSameDay {
                        HStack(spacing: 4) {
                            Text("Reminders for sessions are off.")
                            Button("Turn on") {
                                remindDayBefore = true
                                NotificationScheduler.askForPermissionIfNeeded()
                                AppointmentReminders.refresh(using: modelContext)
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }
                }

                if !earlierOccurrences.isEmpty {
                    Divider()
                    Button {
                        withAnimation { showEarlier.toggle() }
                    } label: {
                        HStack {
                            Text("Earlier sessions (\(earlierOccurrences.count))")
                            Spacer()
                            Image(systemName: showEarlier ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityHint(showEarlier ? "Hides earlier sessions" : "Shows earlier sessions")
                    if showEarlier {
                        ForEach(earlierOccurrences) { occurrence in
                            sessionRow(occurrence, showsDistance: false)
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ occurrence: AppointmentOccurrence, showsDistance: Bool) -> some View {
        Button {
            editingOccurrence = occurrence
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(occurrence.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                    if showsDistance || occurrence.wasMoved {
                        HStack(spacing: 6) {
                            if showsDistance {
                                Text(daysUntil(occurrence.scheduledDate))
                            }
                            if occurrence.wasMoved {
                                Text("Moved").foregroundStyle(Anchor.Theme.sage)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(showsDistance ? .primary : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the session")
        .anchorDeletable("Cancel session") { modelContext.delete(occurrence) }
    }

    // MARK: Calendar

    private var calendarCard: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 12) {
                monthHeader

                MonthCalendarGrid(
                    displayedMonth: displayedMonth,
                    occurrencesByDay: occurrencesByDay,
                    onSelectDay: selectDay
                )

                if hasMovedSession {
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
            .accessibilityLabel("Previous month")
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(.headline, design: .rounded))
            Spacer()
            Button {
                withAnimation { displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth }
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next month")
        }
        .tint(Anchor.Theme.accent)
    }

    private func daysUntil(_ date: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: date)).day ?? 0
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
/// there. The gap between them starts at the person's usual gap and can be
/// changed here, which also becomes their usual gap. The time starts at the
/// time of their latest session, so a regular slot does not have to be set
/// again. The date can be changed here, so the plus in the bar and a tap on an
/// empty calendar day open the same sheet.
private struct ScheduleSessionSheet: View {
    let series: AppointmentSeries
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var time: Date
    @State private var repeats = false
    @State private var numberOfSessions = 4
    @State private var gapDays: Int

    init(series: AppointmentSeries, date: Date) {
        self.series = series
        _date = State(initialValue: date)
        _time = State(initialValue: Self.startingTime(for: series, on: date))
        _gapDays = State(initialValue: series.typicalCadenceDays)
    }

    /// The time of the person's latest session, or their usual time if they
    /// have one, or the current time.
    private static func startingTime(for series: AppointmentSeries, on date: Date) -> Date {
        let calendar = Calendar.current
        if let latest = series.occurrenceList.max(by: { $0.scheduledDate < $1.scheduledDate }) {
            let parts = calendar.dateComponents([.hour, .minute], from: latest.scheduledDate)
            return calendar.date(bySettingHour: parts.hour ?? 9, minute: parts.minute ?? 0, second: 0, of: date) ?? Date()
        }
        if let hour = series.typicalHour {
            return calendar.date(bySettingHour: hour, minute: series.typicalMinute ?? 0, second: 0, of: date) ?? Date()
        }
        return Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section {
                    Toggle("Repeat", isOn: $repeats)
                        .tint(Anchor.Theme.accent)
                    if repeats {
                        Stepper("\(numberOfSessions) sessions", value: $numberOfSessions, in: 2...26)
                        Stepper("Every \(gapDays) days", value: $gapDays, in: 1...60)
                    }
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
            let sessionDate = Calendar.current.date(byAdding: .day, value: index * gapDays, to: firstDate) ?? firstDate
            series.occurrenceList.append(AppointmentOccurrence(scheduledDate: sessionDate))
        }
        if repeats { series.typicalCadenceDays = gapDays }
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
        // Reminders follow the sessions: any session added, moved or removed, here or in a
        // sheet, changes this and the waiting reminders are made to match.
        .onChange(of: sessionSignature) { _, _ in
            AppointmentReminders.refresh(using: modelContext)
            HelloReminders.refresh(using: modelContext)
        }
        .onDisappear {
            AppointmentReminders.refresh(using: modelContext)
            HelloReminders.refresh(using: modelContext)
        }
    }

    private var sessionSignature: String {
        providers.flatMap { $0.occurrenceList }
            .map { "\($0.id.uuidString)\($0.scheduledDate.timeIntervalSince1970)" }
            .sorted()
            .joined(separator: ",")
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
        var removedIDs: [UUID] = []
        if let deleting {
            removedIDs.append(deleting.id)
            modelContext.delete(deleting)
        }
        for provider in providers where provider !== deleting && provider.isBlankProvider {
            removedIDs.append(provider.id)
            modelContext.delete(provider)
        }
        releaseItems(for: removedIDs)
    }

    /// Things to raise that were for a provider who has been removed become
    /// for anyone. They are never deleted along with the provider.
    private func releaseItems(for removedIDs: [UUID]) {
        guard !removedIDs.isEmpty,
              let items = try? modelContext.fetch(FetchDescriptor<BridgeDraftItem>()) else { return }
        for item in items {
            if let id = item.providerID, removedIDs.contains(id) { item.providerID = nil }
        }
    }
}

private extension AppointmentSeries {
    var isBlankProvider: Bool {
        clinicianLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && occurrenceList.isEmpty
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
                Section("Usual gap between sessions") {
                    Stepper("\(provider.typicalCadenceDays) days", value: $provider.typicalCadenceDays, in: 1...60)
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
