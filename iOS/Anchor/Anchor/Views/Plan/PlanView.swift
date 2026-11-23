//
//  PlanView.swift
//  Anchor
//

import SwiftUI
import SwiftData
import HealthKit

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SafetyPlanSection.sortOrder) private var planSections: [SafetyPlanSection]
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]
    @Query private var triggerWindows: [TriggerWindow]
    @Query(sort: \DeEscalationScript.sortOrder) private var deEscalationScripts: [DeEscalationScript]
    @Query(sort: \Affirmation.sortOrder) private var affirmations: [Affirmation]

    @Query(sort: \GroundingTool.sortOrder) private var groundingTools: [GroundingTool]
    @AppStorage(TabLayoutStyle.storageKey) private var layoutRaw = TabLayoutStyle.widgets.rawValue

    @State private var showSettings = false

    private var usesWidgets: Bool { layoutRaw != TabLayoutStyle.icons.rawValue }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if usesWidgets {
                        widgetLayout
                    } else {
                        tileLayout
                    }
                }
                .padding(.vertical, 8)
            }
            .anchorBackground()
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Anchor.GearButton { showSettings = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HelpToolbarButton(topic: .plan)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                NotificationScheduler.registerCategories()
                // No permission prompt here: Anchor asks the first time the user turns on
                // something that needs notifications (see NotificationScheduler.askForPermissionIfNeeded).
                RecoveryNotifications.refresh(using: modelContext)
                RoutineReminders.refresh(using: modelContext)
                HelloReminders.refresh(using: modelContext)
                AppointmentReminders.refresh(using: modelContext)
                SleepReminder.refresh()
                let scheduler = NotificationScheduler(context: modelContext)
                refreshWidgetSnapshot()
                rescheduleTriggerWindowNotifications(using: scheduler)
                // Keeps the daily check-in notification alive; the toggle itself lives in Settings.
                DailyCheckInSettings.reapplyIfEnabled(using: modelContext)
            }
        }
    }

    // Widgets (default): live content you can use in place; tap a widget to open its screen.
    // Order and visibility come from the saved layout (Settings > Layout > Customise widgets).
    private var widgetLayout: some View {
        Anchor.WidgetStack(tab: .plan) { id in
            planWidget(id)
        } more: { id in
            planMoreTile(id)
        }
        .padding(.horizontal)
    }

    @ViewBuilder private func planWidget(_ id: WidgetID) -> some View {
        switch id {
        case .safetyPlan: SafetyPlanWidget()
        case .triggerWindows: TriggerWindowsWidget()
        case .appointments: AppointmentsWidget()
        case .contacts: ContactsWidget(contacts: contacts)
        case .deEscalation: DeEscalationWidget()
        case .grounding: GroundingWidget(tools: groundingTools)
        case .decisionPresets: DecisionPresetsQuickView()
        case .affirmations: AffirmationsWidget()
        case .recovery: RecoveryWidget()
        case .motivations: MotivationsWidget()
        case .tasks: TasksWidget()
        case .sleep: SleepWidget()
        default: EmptyView()
        }
    }

    /// Where a hidden widget still lives, in the "More" row.
    @ViewBuilder private func planMoreTile(_ id: WidgetID) -> some View {
        switch id {
        case .safetyPlan: Anchor.MoreTile(id: id) { SafetyPlanView() }
        case .triggerWindows: Anchor.MoreTile(id: id) { TriggerWindowListView() }
        case .appointments: Anchor.MoreTile(id: id) { ProviderPageHost(page: .sessions) }
        case .contacts: Anchor.MoreTile(id: id) { ContactsView() }
        case .deEscalation: Anchor.MoreTile(id: id) { DeEscalationScriptsView() }
        case .grounding: Anchor.MoreTile(id: id) { GroundingToolsListView() }
        case .decisionPresets: Anchor.MoreTile(id: id) { PresetsView() }
        case .affirmations: Anchor.MoreTile(id: id) { AffirmationsView() }
        case .recovery: Anchor.MoreTile(id: id) { RecoveryHomeView() }
        case .motivations: Anchor.MoreTile(id: id) { RecoveryMotivationsView() }
        case .tasks: Anchor.MoreTile(id: id) { TasksView() }
        case .sleep: Anchor.MoreTile(id: id) { SleepView() }
        default: EmptyView()
        }
    }

    // Icons (classic): the original tile rows.
    private var tileLayout: some View {
        VStack(alignment: .leading, spacing: 26) {
                    Anchor.TileRow(title: "Safety & people") {
                        NavigationLink { ContactsView() } label: {
                            Anchor.TileButtonLabel(icon: "person.2.fill", title: "Contacts", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { SafetyPlanView() } label: {
                            Anchor.TileButtonLabel(icon: "shield.fill", title: "Safety plan", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { TriggerWindowListView() } label: {
                            Anchor.TileButtonLabel(icon: "clock.fill", title: "Trigger windows", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { ProviderPageHost(page: .sessions) } label: {
                            Anchor.TileButtonLabel(icon: "calendar", title: "Appointments", tint: Anchor.Theme.sage)
                        }
                    }

                    Anchor.TileRow(title: "Presets & tools") {
                        NavigationLink { GroundingToolsListView() } label: {
                            Anchor.TileButtonLabel(icon: "leaf.fill", title: "Grounding tools", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { TasksView() } label: {
                            Anchor.TileButtonLabel(icon: "checkmark.circle.fill", title: "Tasks", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { PresetsView() } label: {
                            Anchor.TileButtonLabel(icon: "checklist", title: "Presets", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { DeEscalationScriptsView() } label: {
                            Anchor.TileButtonLabel(icon: "wind", title: "De-escalation", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { AffirmationsView() } label: {
                            Anchor.TileButtonLabel(icon: "sparkles", title: "Affirmations", tint: Anchor.Theme.accent)
                        }
                    }

                    Anchor.TileRow(title: "Recovery") {
                        NavigationLink { RecoveryHomeView() } label: {
                            Anchor.TileButtonLabel(icon: "calendar.badge.checkmark", title: "Counters", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { CravingToolView() } label: {
                            Anchor.TileButtonLabel(icon: "wind", title: "Riding out an urge", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { RecoveryMotivationsView() } label: {
                            Anchor.TileButtonLabel(icon: "heart.fill", title: "Who I'm doing this for", tint: Anchor.Theme.accent)
                        }
                    }
                }
    }

    /// Re-syncs every active trigger window's local notification, including
    /// escalation reminders for opted-in contacts. Simple "clear and
    /// re-add" rather than diffing — cheap enough at this scale, and
    /// guarantees the schedule always matches what's currently in Plan.
    private func rescheduleTriggerWindowNotifications(using scheduler: NotificationScheduler) {
        let reasons = SafetyPlanSections.reasonLines(from: planSections)
        let escalationContacts = contacts.filter { $0.escalationEnabled }

        for window in triggerWindows {
            scheduler.scheduleTriggerWindow(
                window,
                reasonsPool: reasons,
                escalationContacts: escalationContacts,
                primaryContact: contacts.first
            )
        }
    }

    private func refreshWidgetSnapshot() {
        guard !DemoMode.isOn else { return }
        WidgetDataStore.refresh(
            contacts: contacts,
            hasSafetyPlan: SafetyPlanSections.hasContent(planSections),
            deEscalationScriptLine: deEscalationScripts.first?.text ?? "I need 10 minutes, then we can talk.",
            nextTriggerWindowLabel: nextTriggerWindowLabel,
            currentAffirmation: affirmations.first?.text
        )
    }

    /// A short glance-friendly label like "Weekday mornings · Mon 7:30 AM"
    /// for the soonest upcoming active window — never the full window
    /// detail, just enough for a widget.
    private var nextTriggerWindowLabel: String? {
        TimeWindowHelper.nextWindowLabel(among: triggerWindows)
    }
}

// MARK: - Sleep

/// Nights as plain dots, oldest first. A filled dot is a night with something
/// written down. No colour changes with how long anyone slept.
private struct SleepDots: View {
    let nights: Int
    let logged: Set<Date>
    var size: CGFloat = 9

    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<nights).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        HStack(spacing: size * 0.6) {
            ForEach(days, id: \.self) { day in
                Circle()
                    .fill(logged.contains(day) ? Anchor.Theme.sage : Color.clear)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: logged.contains(day) ? 0 : 1))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The last \(nights) nights. Filled dots have an entry.")
    }
}

private extension Collection where Element == SleepEntry {
    /// The nights that have something in them, as start-of-day dates.
    var loggedNights: Set<Date> {
        Set(filter { !$0.isBlank && !$0.isNap }.map { Calendar.current.startOfDay(for: $0.nightDate) })
    }
}

struct SleepWidget: View {
    @Query private var entriesStored: [SleepEntry]
    /// Sorted after the items are opened, because a locked nightDate cannot be sorted by the database (Patch 35g1b).
    private var entries: [SleepEntry] { entriesStored.withHealthNights.sortedByKey(descending: true) { $0.nightDate } }
    private var caption: String {
        if let latest = entries.first(where: { $0.shownMinutes != nil && !$0.isNap }), let minutes = latest.shownMinutes {
            return "Last logged: " + SleepEntry.describe(minutes: minutes)
        }
        return "A quiet place to note how you slept."
    }

    var body: some View {
        Anchor.Widget(icon: "moon.zzz.fill", title: "Sleep", tint: Anchor.Theme.accent, fillsHeight: true) {
            SleepView()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                SleepDots(nights: 7, logged: entries.loggedNights, size: 8)
                Anchor.WidgetCaption(text: caption, lines: 2)
            }
        }
    }
}

/// The sleep journal: one quiet entry per night. No score, no target hours,
/// no streak and no word for a bad night. It is a record to look back over
/// or to show someone, not something to be graded on.
struct SleepView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entriesStored: [SleepEntry]
    /// Sorted after the items are opened, because a locked nightDate cannot be sorted by the database (Patch 35g1b).
    private var entries: [SleepEntry] { entriesStored.withHealthNights.sortedByKey(descending: true) { $0.nightDate } }
    @AppStorage(SleepFeelWords.storageKey) private var wordsRaw = ""

    @State private var editing: SleepEntry?
    @State private var lastOpened: SleepEntry?
    @State private var toDelete: SleepEntry?
    @State private var confirmingDelete: SleepEntry?
    @State private var healthNightNotice = false
    @State private var renamingWords = false

    private var words: [String] { SleepFeelWords.words(from: wordsRaw) }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    /// Time asleep for the last 30 nights that have it, smallest first.
    private var recentMinutes: [Int] {
        let cal = Calendar.current
        guard let from = cal.date(byAdding: .day, value: -29, to: today) else { return [] }
        return entries
            .filter { cal.startOfDay(for: $0.nightDate) >= from && !$0.isNap }
            .compactMap(\.shownMinutes)
            .sorted()
    }

    /// One plain line on the usual range, from the middle of the nights. It
    /// says nothing about whether that is enough.
    private var usualLine: String {
        let m = recentMinutes
        guard m.count >= 3 else { return "Log a few nights and the usual range shows here." }
        func rounded(_ value: Int) -> Int { ((value + 7) / 15) * 15 }
        let low = rounded(m[Int((Double(m.count - 1) * 0.2).rounded())])
        let high = rounded(m[Int((Double(m.count - 1) * 0.8).rounded())])
        let span = low == high
            ? "about " + SleepEntry.describe(minutes: low)
            : "about " + SleepEntry.describe(minutes: low) + " to " + SleepEntry.describe(minutes: high)
        return "Most of the last 30 nights logged were \(span)."
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)

    private var monthDays: [Date] {
        let cal = Calendar.current
        return (0..<30).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        List {
            if entries.isEmpty {
                Anchor.EmptyState(
                    icon: "moon.zzz.fill",
                    title: "Nothing logged yet",
                    message: "Note when you went to bed and woke, how long you slept, how it felt, or just a line about it. All of it is optional.",
                    actionTitle: "Log last night",
                    tint: Anchor.Theme.accent
                ) { logNight() }
                .anchorCardRow()
            } else {
                NavigationLink {
                    SleepHistoryView()
                } label: {
                    Anchor.Card(accentColor: Anchor.Theme.accent) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Sleep calendar and entries", systemImage: "calendar")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        let logged = entries.loggedNights
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(monthDays, id: \.self) { day in
                                Circle()
                                    .fill(logged.contains(day) ? Anchor.Theme.sage : Color.clear)
                                    .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: logged.contains(day) ? 0 : 1))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("The last 30 nights. Filled dots have an entry.")
                        Text(usualLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    }
                }
                .buttonStyle(.plain)
                .anchorCardRow()
            }

            if SleepHealthReader.shared.isAvailable {
                SleepHealthCard()
                    .anchorCardRow()
            }
        }
        .listStyle(.plain)
        .anchorBackground()
        .task {
            await SleepHealthReader.shared.sync(context: modelContext)
            await SleepHealthWriter.shared.reconcile(context: modelContext)
        }
        .navigationTitle("Sleep")
        .guideButton("plan.sleep", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("Rename the three words") { renamingWords = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
                Menu {
                    Button("Last night") { logNight() }
                    Button("A nap or other sleep") { logNap() }
                    Button("Sleep on an earlier day") { logEarlier() }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Log sleep")
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { entry in
            SleepEntrySheet(entry: entry, words: words) { toDelete = entry }
        }
        .sheet(isPresented: $renamingWords) {
            SleepWordsSheet()
        }
        .alert("This night is read from Apple Health", isPresented: $healthNightNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Anchor does not keep it, so there is nothing to delete here. Change or remove it in the Health app, or open it and write your own version, which then takes its place.")
        }
        .confirmationDialog(
            "Delete this night?",
            isPresented: Binding(get: { confirmingDelete != nil }, set: { if !$0 { confirmingDelete = nil } }),
            titleVisibility: .visible,
            presenting: confirmingDelete
        ) { entry in
            Button("Delete night", role: .destructive) { modelContext.delete(entry) }
            Button("Keep it", role: .cancel) {}
        } message: { _ in
            Text("What is written in it goes too.")
        }
    }

    private func open(_ entry: SleepEntry) {
        // A night read from Apple Health is not in the store. It opens as a copy that is put in the store only to be
        // looked at or changed: if nothing is changed, the copy is dropped again when the sheet closes, and if
        // something is, the sheet turns it into the person's own night.
        var target = entry
        if entry.modelContext == nil {
            target = SleepEntry(nightDate: entry.nightDate, bedTime: entry.bedTime, wakeTime: entry.wakeTime,
                                minutesAsleep: entry.minutesAsleep, feel: entry.feel, note: entry.note,
                                sourceRaw: SleepHealthSettings.sourceHealth, externalID: entry.externalID)
            modelContext.insert(target)
        }
        lastOpened = target
        editing = target
    }

    /// Opens last night, which is the one you woke up from today. If today
    /// already has one, that one opens instead of a second being made.
    private func logNight() {
        if let existing = entries.first(where: { Calendar.current.startOfDay(for: $0.nightDate) == today && !$0.isNap }) {
            open(existing)
            return
        }
        let new = SleepEntry(nightDate: today)
        modelContext.insert(new)
        open(new)
    }

    /// A nap or other sleep in the day. There can be as many as you like on a day, so one is always made new.
    private func logNap() {
        let new = SleepEntry(nightDate: today, kind: .nap)
        modelContext.insert(new)
        open(new)
    }

    /// Sleep for a day that has passed: starts on yesterday, and the sheet's "Woke up on" date picks any earlier day.
    private func logEarlier() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        let new = SleepEntry(nightDate: yesterday)
        modelContext.insert(new)
        open(new)
    }

    /// Runs once the sheet has closed, so it never reads an entry that is
    /// already gone. A night left with nothing in it is dropped again.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        let opened = lastOpened
        lastOpened = nil
        if let deleting {
            modelContext.delete(deleting)
        } else if let opened {
            if opened.isBlank || opened.sourceRaw == SleepHealthSettings.sourceHealth {
                // Blank, or a copy of a Health night that was not changed (a changed one has become typed).
                modelContext.delete(opened)
            } else {
                opened.lastEditedAt = .now
            }
        }
    }
}

// MARK: - The sleep calendar

private struct SleepDay: Identifiable {
    let date: Date
    var id: Date { date }
}

/// A short length for a calendar cell: "7h30" or "45m".
private func shortSleep(_ minutes: Int) -> String {
    let hours = minutes / 60, mins = minutes % 60
    if hours == 0 { return "\(mins)m" }
    return mins == 0 ? "\(hours)h" : "\(hours)h" + String(format: "%02d", mins)
}

private extension Collection where Element == SleepEntry {
    /// Time asleep across the night's sleeps in this group.
    var nightMinutes: Int { filter { !$0.isNap }.compactMap(\.shownMinutes).reduce(0, +) }
    /// Time asleep across the naps and other daytime sleeps in this group.
    var napMinutes: Int { filter { $0.isNap }.compactMap(\.shownMinutes).reduce(0, +) }
}

/// Every month, newest first, as a calendar. Each day shows the night's sleep that ended on it and, under that, any
/// daytime sleep. Tap a day for all of it, and to add sleep for it. Scrolling down goes further back; older months
/// are read from Apple Health as they come into view. No score, no target, no streak.
struct SleepHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entriesStored: [SleepEntry]
    @State private var monthsShown = 6
    @State private var openDay: SleepDay?

    private var cal: Calendar { .current }
    private var today: Date { cal.startOfDay(for: .now) }

    private func monthStart(_ offset: Int) -> Date {
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
        return cal.date(byAdding: .month, value: -offset, to: thisMonth) ?? thisMonth
    }

    var body: some View {
        let byDay = Dictionary(grouping: entriesStored.withHealthNights.filter { !$0.isBlank }) {
            Calendar.current.startOfDay(for: $0.nightDate)
        }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(0..<monthsShown, id: \.self) { offset in
                    SleepMonthView(monthStart: monthStart(offset), today: today, byDay: byDay) { openDay = SleepDay(date: $0) }
                        .onAppear {
                            if offset == monthsShown - 1 && monthsShown < 240 {
                                monthsShown += 6
                                let earliest = monthStart(monthsShown - 1)
                                Task { await SleepHealthReader.shared.extend(to: earliest, context: modelContext) }
                            }
                        }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Sleep calendar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await SleepHealthReader.shared.extend(to: monthStart(monthsShown - 1), context: modelContext) }
        .sheet(item: $openDay) { day in
            SleepDaySheet(day: day.date)
        }
    }
}

private struct SleepMonthView: View {
    let monthStart: Date
    let today: Date
    let byDay: [Date: [SleepEntry]]
    let onOpen: (Date) -> Void

    private var cal: Calendar { .current }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var cells: [Date?] {
        let days = cal.range(of: .day, in: .month, for: monthStart) ?? 1..<31
        let leading = (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in days {
            result.append(cal.date(byAdding: .day, value: day - 1, to: monthStart))
        }
        return result
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthStart.formatted(.dateTime.month(.wide).year()))
                .font(.system(.headline, design: .rounded))
            HStack(spacing: 4) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(cells.indices, id: \.self) { index in
                    if let day = cells[index] {
                        cell(day)
                    } else {
                        Color.clear.frame(height: 54)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: Date) -> some View {
        let entries = byDay[day] ?? []
        let night = entries.nightMinutes
        let nap = entries.napMinutes
        Button { onOpen(day) } label: {
            VStack(spacing: 1) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                if night > 0 {
                    Text(shortSleep(night))
                        .font(.system(size: 9, design: .rounded))
                }
                if nap > 0 {
                    Text("+" + shortSleep(nap))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 8).fill(entries.isEmpty ? Color.clear : Anchor.Theme.sage.opacity(0.3)))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(day == today ? Anchor.Theme.accent : Color.secondary.opacity(0.25), lineWidth: day == today ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(day > today)
        .accessibilityLabel(accessibilityText(day, night: night, nap: nap, count: entries.count))
    }

    private func accessibilityText(_ day: Date, night: Int, nap: Int, count: Int) -> String {
        var text = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if count == 0 { return text + ", nothing logged" }
        if night > 0 { text += ", night " + SleepEntry.describe(minutes: night) }
        if nap > 0 { text += ", daytime " + SleepEntry.describe(minutes: nap) }
        return text
    }
}

/// One day, in full: the night's sleep that ended on it and every other sleep that day, with the totals, and a way
/// to add sleep for it.
private struct SleepDaySheet: View {
    let day: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var entriesStored: [SleepEntry]
    @AppStorage(SleepFeelWords.storageKey) private var wordsRaw = ""
    @State private var editing: SleepEntry?
    @State private var lastOpened: SleepEntry?
    @State private var toDelete: SleepEntry?
    @State private var confirmingDelete: SleepEntry?
    @State private var healthNightNotice = false

    private var words: [String] { SleepFeelWords.words(from: wordsRaw) }

    /// The night first, then the rest in the order they happened.
    private var entries: [SleepEntry] {
        let cal = Calendar.current
        let sameDay = entriesStored.withHealthNights.filter { !$0.isBlank && cal.startOfDay(for: $0.nightDate) == day }
        return sameDay.sorted { a, b in
            if a.isNap != b.isNap { return !a.isNap }
            return (a.wakeTime ?? a.bedTime ?? a.nightDate) < (b.wakeTime ?? b.bedTime ?? b.nightDate)
        }
    }

    private var totalsLine: String {
        let night = entries.nightMinutes, nap = entries.napMinutes
        var parts: [String] = []
        if night > 0 { parts.append("Night " + SleepEntry.describe(minutes: night)) }
        if nap > 0 { parts.append("Daytime " + SleepEntry.describe(minutes: nap)) }
        if night > 0 && nap > 0 { parts.append("Total " + SleepEntry.describe(minutes: night + nap)) }
        return parts.isEmpty ? "Nothing logged for this day." : parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(entries) { entry in
                        SleepRow(entry: entry, words: words) { open(entry) }
                            .anchorDeletable {
                                // A night read from Apple Health is not in Anchor's store, so there is nothing here to delete.
                                if entry.modelContext == nil { healthNightNotice = true } else { confirmingDelete = entry }
                            }
                            .anchorCardRow()
                    }
                } header: {
                    Text(totalsLine)
                }

                Section {
                    Button { add(.night) } label: {
                        Label("Add a night's sleep", systemImage: "moon.zzz.fill")
                    }
                    Button { add(.nap) } label: {
                        Label("Add a nap or other sleep", systemImage: "sun.max.fill")
                    }
                }
            }
            .listStyle(.plain)
            .anchorBackground()
            .navigationTitle(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing, onDismiss: finishEditing) { entry in
                SleepEntrySheet(entry: entry, words: words) { toDelete = entry }
            }
            .alert("This night is read from Apple Health", isPresented: $healthNightNotice) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Anchor does not keep it, so there is nothing to delete here. Change or remove it in the Health app, or open it and write your own version, which then takes its place.")
            }
            .confirmationDialog(
                "Delete this sleep?",
                isPresented: Binding(get: { confirmingDelete != nil }, set: { if !$0 { confirmingDelete = nil } }),
                titleVisibility: .visible,
                presenting: confirmingDelete
            ) { entry in
                Button("Delete", role: .destructive) { modelContext.delete(entry) }
                Button("Keep it", role: .cancel) {}
            } message: { _ in
                Text("What is written in it goes too.")
            }
        }
    }

    private func add(_ kind: SleepKind) {
        let new = SleepEntry(nightDate: day, kind: kind)
        modelContext.insert(new)
        open(new)
    }

    private func open(_ entry: SleepEntry) {
        // A night read from Apple Health opens as a copy, dropped again if nothing is changed (see SleepView).
        var target = entry
        if entry.modelContext == nil {
            target = SleepEntry(nightDate: entry.nightDate, bedTime: entry.bedTime, wakeTime: entry.wakeTime,
                                minutesAsleep: entry.minutesAsleep, feel: entry.feel, note: entry.note,
                                sourceRaw: SleepHealthSettings.sourceHealth, externalID: entry.externalID, kind: entry.kind)
            modelContext.insert(target)
        }
        lastOpened = target
        editing = target
    }

    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        let opened = lastOpened
        lastOpened = nil
        if let deleting {
            modelContext.delete(deleting)
        } else if let opened {
            if opened.isBlank || opened.sourceRaw == SleepHealthSettings.sourceHealth {
                modelContext.delete(opened)
            } else {
                opened.lastEditedAt = .now
            }
        }
    }
}

/// A thin bar and one line of words for the time in each sleep stage. The words carry the meaning, not the colours,
/// and there is nothing to aim for: no "good" amount of any stage.
private struct SleepStagesView: View {
    let stages: SleepStages

    private var parts: [(label: String, minutes: Int, opacity: Double)] {
        [("Deep", stages.deep, 1.0), ("Core", stages.core, 0.6), ("REM", stages.rem, 0.35), ("Awake", stages.awake, 0.15)]
            .filter { $0.1 > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let total = max(1, parts.map { $0.minutes }.reduce(0, +))
                HStack(spacing: 1) {
                    ForEach(parts.indices, id: \.self) { index in
                        Rectangle()
                            .fill(Anchor.Theme.accent.opacity(parts[index].opacity))
                            .frame(width: max(2, geo.size.width * CGFloat(parts[index].minutes) / CGFloat(total)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 6)
            Text(parts.map { "\($0.label) \(shortSleep($0.minutes))" }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sleep stages. " + parts.map { "\($0.label) \(SleepEntry.describe(minutes: $0.minutes))" }.joined(separator: ", "))
    }
}

private struct SleepRow: View {
    let entry: SleepEntry
    let words: [String]
    let onEdit: () -> Void

    private var timesLine: String? {
        let style = Date.FormatStyle(date: .omitted, time: .shortened)
        switch (entry.bedTime, entry.wakeTime) {
        case let (bed?, wake?): return "Bed \(bed.formatted(style)) · Up \(wake.formatted(style))"
        case let (bed?, nil): return "Bed \(bed.formatted(style))"
        case let (nil, wake?): return "Up \(wake.formatted(style))"
        default: return nil
        }
    }

    var body: some View {
        Anchor.Card {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.nightDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) + (entry.isNap ? " · Nap" : ""))
                            .font(.system(.headline, design: .rounded))
                        Spacer()
                        if let minutes = entry.shownMinutes {
                            Text(SleepEntry.describe(minutes: minutes))
                                .font(.system(.headline, design: .rounded))
                        }
                    }
                    if let timesLine {
                        Text(timesLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let feel = entry.feel, words.indices.contains(feel) {
                        Text(words[feel])
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let line = SafetyPlanSections.firstLine(entry.note) {
                        Text(line)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    if entry.sourceRaw == SleepHealthSettings.sourceHealth {
                        if let stages = SleepHealthNights.shared.stages[entry.externalID ?? ""], stages.hasDetail {
                            SleepStagesView(stages: stages)
                                .padding(.top, 2)
                        }
                        Text("From Apple Health")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the night")
        }
    }
}

private struct SleepEntrySheet: View {
    @Bindable var entry: SleepEntry
    let words: [String]
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [SleepEntry]
    @State private var addedToJournal = false
    @State private var openedAs: String?

    private var cal: Calendar { .current }

    /// Everything the sheet can change, as one string, so it can tell whether
    /// anything was changed while it was open.
    private var fingerprint: String {
        [
            String(entry.nightDate.timeIntervalSince1970),
            entry.bedTime.map { String($0.timeIntervalSince1970) } ?? "-",
            entry.wakeTime.map { String($0.timeIntervalSince1970) } ?? "-",
            entry.minutesAsleep.map(String.init) ?? "-",
            entry.feel.map(String.init) ?? "-",
            entry.note,
            entry.kindRaw
        ].joined(separator: "|")
    }

    /// True when a different entry already holds this night.
    private var nightTaken: Bool {
        allEntries.contains { $0.id != entry.id && cal.startOfDay(for: $0.nightDate) == cal.startOfDay(for: entry.nightDate) }
    }

    private func clock(_ hour: Int, _ minute: Int) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: entry.nightDate) ?? entry.nightDate
    }

    private var nightBinding: Binding<Date> {
        Binding(
            get: { entry.nightDate },
            set: { newValue in
                entry.nightDate = cal.startOfDay(for: newValue)
                if let wake = entry.wakeTime { entry.wakeTime = SleepEntry.wakeMoment(clock: wake, night: entry.nightDate) }
                if let bed = entry.bedTime {
                    entry.bedTime = SleepEntry.bedMoment(clock: bed, night: entry.nightDate, wake: entry.wakeTime)
                }
            }
        )
    }

    private var knowsBed: Binding<Bool> {
        Binding(
            get: { entry.bedTime != nil },
            set: { on in
                entry.bedTime = on ? SleepEntry.bedMoment(clock: entry.isNap ? clock(14, 0) : clock(23, 0), night: entry.nightDate, wake: entry.wakeTime) : nil
            }
        )
    }

    private var knowsWake: Binding<Bool> {
        Binding(
            get: { entry.wakeTime != nil },
            set: { on in
                entry.wakeTime = on ? SleepEntry.wakeMoment(clock: entry.isNap ? clock(15, 0) : clock(7, 0), night: entry.nightDate) : nil
                if let bed = entry.bedTime {
                    entry.bedTime = SleepEntry.bedMoment(clock: bed, night: entry.nightDate, wake: entry.wakeTime)
                }
            }
        )
    }

    private var bedPicker: Binding<Date> {
        Binding(
            get: { entry.bedTime ?? (entry.isNap ? clock(14, 0) : clock(23, 0)) },
            set: { entry.bedTime = SleepEntry.bedMoment(clock: $0, night: entry.nightDate, wake: entry.wakeTime) }
        )
    }

    private var wakePicker: Binding<Date> {
        Binding(
            get: { entry.wakeTime ?? (entry.isNap ? clock(15, 0) : clock(7, 0)) },
            set: { newValue in
                entry.wakeTime = SleepEntry.wakeMoment(clock: newValue, night: entry.nightDate)
                if let bed = entry.bedTime {
                    entry.bedTime = SleepEntry.bedMoment(clock: bed, night: entry.nightDate, wake: entry.wakeTime)
                }
            }
        )
    }

    /// With both times there, "set it myself" turns the worked-out time into a
    /// typed one. With fewer, it is "I know about how long".
    private var ownTime: Binding<Bool> {
        Binding(
            get: { entry.minutesAsleep != nil },
            set: { on in entry.minutesAsleep = on ? (entry.minutesInBed ?? 420) : nil }
        )
    }

    private var hours: Binding<Int> {
        Binding(
            get: { (entry.minutesAsleep ?? 0) / 60 },
            set: { entry.minutesAsleep = $0 * 60 + (entry.minutesAsleep ?? 0) % 60 }
        )
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { (entry.minutesAsleep ?? 0) % 60 },
            set: { entry.minutesAsleep = ((entry.minutesAsleep ?? 0) / 60) * 60 + $0 }
        )
    }

    private var feel: Binding<Int> {
        Binding(get: { entry.feel ?? -1 }, set: { entry.feel = $0 < 0 ? nil : $0 })
    }

    /// Adds the note as an ordinary journal entry, dated when you woke. The
    /// note stays here as well, and nothing links the two afterwards.
    private func putNoteInJournal() {
        let text = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let morning = entry.wakeTime ?? (cal.date(byAdding: .hour, value: 8, to: entry.nightDate) ?? entry.nightDate)
        modelContext.insert(JournalEntry(createdAt: min(morning, .now), text: text, linkedContext: .manualOpen))
        addedToJournal = true
    }

    var body: some View {
        NavigationStack {
            Form {
                if entry.sourceRaw == SleepHealthSettings.sourceHealth {
                    Section {
                        Label("From Apple Health", systemImage: "heart.text.square")
                    } footer: {
                        Text("If you change anything here, this night becomes yours and Apple Health will not change it again.")
                    }
                }

                Section {
                    Picker("Kind of sleep", selection: Binding(get: { entry.kind }, set: { entry.kind = $0 })) {
                        ForEach(SleepKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    DatePicker(entry.isNap ? "Slept on" : "Woke up on", selection: nightBinding, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    if nightTaken {
                        Text("There is another sleep on this day as well. You can have more than one.")
                    } else {
                        Text("Pick any earlier day to add sleep you missed.")
                    }
                }

                Section("Times") {
                    Toggle("I know when I went to bed", isOn: knowsBed)
                    if entry.bedTime != nil {
                        DatePicker("Went to bed", selection: bedPicker, displayedComponents: .hourAndMinute)
                    }
                    Toggle("I know when I woke up", isOn: knowsWake)
                    if entry.wakeTime != nil {
                        DatePicker("Woke up", selection: wakePicker, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Time asleep") {
                    if let inBed = entry.minutesInBed {
                        Text("About \(SleepEntry.describe(minutes: inBed)) between bed and waking.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Toggle("Set it myself", isOn: ownTime)
                    } else {
                        Toggle("I know about how long I slept", isOn: ownTime)
                    }
                    if entry.minutesAsleep != nil {
                        Stepper("\(hours.wrappedValue) hours", value: hours, in: 0...16)
                        Stepper("\(minutes.wrappedValue) minutes", value: minutes, in: 0...55, step: 5)
                    }
                }

                Section("How it felt") {
                    Picker("How it felt", selection: feel) {
                        Text("Skip").tag(-1)
                        ForEach(words.indices, id: \.self) { index in
                            Text(words[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("A note") {
                    TextField("Anything you want to remember", text: $entry.note, axis: .vertical)
                        .lineLimit(3...8)
                    if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(addedToJournal ? "Added to your journal" : "Put this note in my journal") {
                            putNoteInJournal()
                        }
                        .disabled(addedToJournal)
                    }
                }

                Section {
                    Button("Delete this night", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { if openedAs == nil { openedAs = fingerprint } }
        .onDisappear {
            // Once the screen that opened this has finished with the night, bring Health in line.
            let context = modelContext
            Task {
                try? await Task.sleep(for: .seconds(1))
                await SleepHealthWriter.shared.reconcile(context: context)
            }
            // A night from Apple Health that was changed here is now the
            // person's own, so a later import never touches it.
            if entry.sourceRaw == SleepHealthSettings.sourceHealth, let openedAs, openedAs != fingerprint {
                entry.sourceRaw = "typed"
                entry.externalID = nil
                entry.lastEditedAt = .now
            }
        }
    }
}

/// Where the three words for how a night felt can be renamed. An empty one
/// goes back to its usual word.
private struct SleepWordsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SleepFeelWords.storageKey) private var wordsRaw = ""

    private func binding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                let saved = SleepFeelWords.saved(from: wordsRaw)
                return index < saved.count ? saved[index] : ""
            },
            set: { newValue in
                var saved = SleepFeelWords.saved(from: wordsRaw)
                while saved.count < 3 { saved.append("") }
                saved[index] = newValue
                wordsRaw = SleepFeelWords.encode(Array(saved.prefix(3)))
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(0..<3, id: \.self) { index in
                        TextField(SleepFeelWords.defaults[index], text: binding(index))
                    }
                } footer: {
                    Text("These are the three words you can pick from for how a night felt. Leave one empty to use its usual word.")
                }
            }
            .navigationTitle("Three words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Apple Health (sleep, read only)

enum SleepHealthSettings {
    /// On while Anchor is bringing in new nights from Apple Health.
    static let connectedKey = "anchor.sleep.health.read"
    /// When Apple Health was last checked, as seconds since 1970.
    static let lastSyncKey = "anchor.sleep.health.lastSync"
    /// The `sourceRaw` of a night that came from Apple Health.
    static let sourceHealth = "health"
    /// On while sleep stages (core, deep, REM, awake) are read along with the nights, from a watch that records them.
    static let stagesKey = "anchor.sleep.health.stages"
    /// On while typed nights are saved to Apple Health.
    static let writeKey = "anchor.sleep.health.write"
    /// Nights typed since this moment are eligible to be saved, as seconds since 1970.
    static let writeSinceKey = "anchor.sleep.health.writeSince"
    /// What Anchor has saved: the night's id, and the version saved (negative when
    /// the night was left alone because Health already held it).
    static let writtenKey = "anchor.sleep.health.written"
}

/// Nights read from Apple Health, held in memory only. They are never put in Anchor's store, so they are never synced
/// to iCloud, never in a backup or an export of the store, and they come back from Health each time. Each is a
/// `SleepEntry` that belongs to no store, so the screens that show nights can show it like any other.
/// Minutes in each sleep stage for one sleep, as an Apple Watch (or another device that records stages) reports them.
struct SleepStages: Equatable {
    var core = 0
    var deep = 0
    var rem = 0
    var awake = 0

    /// True when the device recorded actual stages, not only "asleep".
    var hasDetail: Bool { core + deep + rem > 0 }
}

@MainActor
@Observable
final class SleepHealthNights {
    static let shared = SleepHealthNights()
    var nights: [SleepEntry] = []
    /// The stages for a night in `nights`, by its external id. Only filled while stages are switched on, and held in memory
    /// like the nights.
    var stages: [String: SleepStages] = [:]

    /// The nights you wrote or changed, and the nights Apple Health holds for days you have no night of your own.
    /// A night you wrote down is yours, so Apple Health never takes its place.
    func merged(with stored: [SleepEntry]) -> [SleepEntry] {
        guard !nights.isEmpty else { return stored }
        let cal = Calendar.current
        // A copy of a Health night that an older version stored is left out while the live nights are there.
        // Your own night hides the Health night for that day, and your own nap hides the Health naps for that day.
        let own = stored.filter { $0.sourceRaw != SleepHealthSettings.sourceHealth }
        func key(_ entry: SleepEntry) -> String { "\(cal.startOfDay(for: entry.nightDate).timeIntervalSince1970)-\(entry.isNap)" }
        let ownKeys = Set(own.map(key))
        return own + nights.filter { !ownKeys.contains(key($0)) }
    }
}

extension Collection where Element == SleepEntry {
    /// These nights with the ones Apple Health holds added (see `SleepHealthNights`).
    @MainActor var withHealthNights: [SleepEntry] { SleepHealthNights.shared.merged(with: Array(self)) }
}

/// Reads sleep from Apple Health and keeps one summary per night in memory, never in
/// Anchor's own store. Nothing is read until the person taps Connect, and a night they
/// typed is never replaced. HealthKit does not say whether read access was
/// refused, so a refusal looks the same as no sleep being there.
@MainActor
@Observable
final class SleepHealthReader {
    static let shared = SleepHealthReader()

    /// True while a check is running.
    var isWorking = false
    /// How many nights the last check found in Apple Health. Nil until one has run.
    var foundNights: Int?
    /// Why the last Connect did not work, in plain words, or nil. Shown under the switch, so a refusal is never silent.
    var problem: String?
    /// How far back the sleep calendar has asked to see, when that is further than the usual 90 days.
    private var earliestWanted: Date?

    @ObservationIgnored private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() && !ShowcaseMode.isOn }

    private var sleepType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sleepAnalysis) }

    /// Asks for read access to sleep, which is when iOS shows its own
    /// question, then brings in the last 30 days.
    func connect(context: ModelContext) async {
        problem = nil
        if DemoMode.isOn || ShowcaseMode.isOn {
            problem = "Apple Health is not used in demo or showcase mode."
            return
        }
        guard HKHealthStore.isHealthDataAvailable(), let type = sleepType else {
            problem = "Apple Health isn't available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [type])
        } catch {
            problem = "Apple Health did not open its question: \(error.localizedDescription)"
            return
        }
        UserDefaults.standard.set(true, forKey: SleepHealthSettings.connectedKey)
        await sync(context: context, full: true)
    }

    func disconnect() {
        UserDefaults.standard.set(false, forKey: SleepHealthSettings.connectedKey)
        SleepHealthNights.shared.nights = []
        SleepHealthNights.shared.stages = [:]
    }

    /// Reads further back, for the sleep calendar's older months. Nothing is stored.
    func extend(to date: Date, context: ModelContext) async {
        guard UserDefaults.standard.bool(forKey: SleepHealthSettings.connectedKey) else { return }
        if let current = earliestWanted, current <= date { return }
        earliestWanted = date
        await sync(context: context)
    }

    /// Stops reading from Apple Health and clears the nights held from it. Nothing in Health changes. Any copy of
    /// a Health night that an older version stored is removed too. Nights you wrote or changed stay.
    @discardableResult
    func removeImported(context: ModelContext) -> Int {
        disconnect()
        SleepHealthNights.shared.nights = []
        let removed = purgeStoredCopies(context: context)
        foundNights = nil
        UserDefaults.standard.removeObject(forKey: SleepHealthSettings.lastSyncKey)
        return removed
    }

    /// Older versions kept a copy of each Health night in the store, which would reach iCloud. Nights are now held
    /// in memory only, so any copy still in the store is deleted. A night that was changed became the person's own
    /// (its source is typed) and is not touched.
    @discardableResult
    func purgeStoredCopies(context: ModelContext) -> Int {
        let all = (try? context.fetch(FetchDescriptor<SleepEntry>())) ?? []
        var removed = 0
        for entry in all where entry.sourceRaw == SleepHealthSettings.sourceHealth {
            context.delete(entry)
            removed += 1
        }
        if removed > 0 { try? context.save() }
        return removed
    }

    private struct Piece {
        var start: Date
        var end: Date
        var asleep: Bool
        /// The Health sleep value (core, deep, REM, asleep, awake), as its raw number.
        var value: Int = 0
    }

    private struct Night {
        var day: Date
        var bed: Date
        var wake: Date
        var minutesAsleep: Int?
        var stages: SleepStages?
        /// True for a sleep that began after 8 am and ended before 8 pm.
        var isDaytime: Bool
    }

    private static func unionMinutes(_ pieces: [Piece]) -> Int {
        let sorted = pieces.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var runStart: Date?
        var runEnd: Date?
        for piece in sorted {
            if let start = runStart, let end = runEnd {
                if piece.start <= end {
                    runEnd = max(end, piece.end)
                } else {
                    total += end.timeIntervalSince(start)
                    runStart = piece.start
                    runEnd = piece.end
                }
            } else {
                runStart = piece.start
                runEnd = piece.end
            }
        }
        if let start = runStart, let end = runEnd { total += end.timeIntervalSince(start) }
        return Int(total / 60)
    }

    /// Brings in nights from Apple Health: the last 30 days the first time,
    /// then what is new. It does nothing unless the person has connected.
    func sync(context: ModelContext, full: Bool = false) async {
        let defaults = UserDefaults.standard
        // Nights from Apple Health are held in memory and never stored, so they are never in iCloud (D39, Patch HK2),
        // and reading them is fine whether sync is on or off.
        guard defaults.bool(forKey: SleepHealthSettings.connectedKey),
              isAvailable, !DemoMode.isOn, !isWorking, let type = sleepType else { return }
        isWorking = true
        defer { isWorking = false }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // The last 90 days are read each time, since nothing is stored, and further back when the calendar has asked.
        guard let usualFrom = cal.date(byAdding: .day, value: -90, to: today) else { return }
        let from = min(usualFrom, earliestWanted.map { cal.startOfDay(for: $0) } ?? usualFrom)
        // Start earlier than the first day, so a night that began the evening before is whole.
        let predicate = HKQuery.predicateForSamples(withStart: from.addingTimeInterval(-18 * 3600), end: .now, options: [])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples: [HKCategorySample]
        do {
            samples = try await descriptor.result(for: store)
        } catch {
            return
        }

        var pieces: [Piece] = []
        var awakePieces: [Piece] = []
        for sample in samples {
            // Never read back anything Anchor wrote itself.
            if sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier { continue }
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            if value == .awake {
                // Not part of when a sleep began or ended, but kept for the awake time within a sleep.
                awakePieces.append(Piece(start: sample.startDate, end: sample.endDate, asleep: false, value: sample.value))
                continue
            }
            let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
            pieces.append(Piece(start: sample.startDate, end: sample.endDate, asleep: asleep, value: sample.value))
        }
        pieces.sort { $0.start < $1.start }

        // Pieces less than three hours apart are one sleep. Each is a night
        // for the day it ended on, and the longest one that day is kept.
        var sessions: [[Piece]] = []
        var runEnd = Date.distantPast
        for piece in pieces {
            if piece.start.timeIntervalSince(runEnd) > 3 * 3600 || sessions.isEmpty {
                sessions.append([piece])
            } else {
                sessions[sessions.count - 1].append(piece)
            }
            runEnd = max(runEnd, piece.end)
        }
        let wantStages = defaults.bool(forKey: SleepHealthSettings.stagesKey)
        let coreValue = HKCategoryValueSleepAnalysis.asleepCore.rawValue
        let deepValue = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        let remValue = HKCategoryValueSleepAnalysis.asleepREM.rawValue
        var found: [Night] = []
        for session in sessions {
            guard let bed = session.map(\.start).min(), let wake = session.map(\.end).max() else { continue }
            let span = wake.timeIntervalSince(bed)
            guard span > 0, span <= 20 * 3600 else { continue }
            let day = cal.startOfDay(for: wake)
            guard day >= from, day <= today else { continue }
            let asleepPieces = session.filter(\.asleep)
            let minutes = asleepPieces.isEmpty ? nil : Self.unionMinutes(asleepPieces)
            var stages: SleepStages?
            if wantStages {
                var detail = SleepStages()
                detail.core = Self.unionMinutes(session.filter { $0.value == coreValue })
                detail.deep = Self.unionMinutes(session.filter { $0.value == deepValue })
                detail.rem = Self.unionMinutes(session.filter { $0.value == remValue })
                detail.awake = Self.unionMinutes(awakePieces.filter { $0.start >= bed && $0.end <= wake })
                if detail.hasDetail { stages = detail }
            }
            let startHour = cal.component(.hour, from: bed)
            let endHour = cal.component(.hour, from: wake)
            let sameDay = cal.startOfDay(for: bed) == day
            found.append(Night(day: day, bed: bed, wake: wake, minutesAsleep: minutes.flatMap { $0 > 0 ? $0 : nil },
                               stages: stages, isDaytime: sameDay && startHour >= 8 && endHour < 20))
        }

        // For each day, the longest sleep that was not in the daytime is the night. Every other sleep that day with at
        // least 15 minutes asleep is a nap or other sleep.
        var entries: [SleepEntry] = []
        var stagesByID: [String: SleepStages] = [:]
        for (day, group) in Dictionary(grouping: found, by: \.day) {
            let night = group.filter { !$0.isDaytime }.max { $0.wake.timeIntervalSince($0.bed) < $1.wake.timeIntervalSince($1.bed) }
            let parts = cal.dateComponents([.year, .month, .day], from: day)
            let dayKey = String(format: "health:%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            for sleep in group {
                let isNight = night.map { $0.bed == sleep.bed && $0.wake == sleep.wake } ?? false
                if !isNight && (sleep.minutesAsleep ?? 0) < 15 { continue }
                let clock = cal.dateComponents([.hour, .minute], from: sleep.bed)
                let key = isNight ? dayKey : dayKey + String(format: "-%02d%02d", clock.hour ?? 0, clock.minute ?? 0)
                // Not inserted into any store.
                entries.append(SleepEntry(nightDate: day, bedTime: sleep.bed, wakeTime: sleep.wake,
                                          minutesAsleep: sleep.minutesAsleep, sourceRaw: SleepHealthSettings.sourceHealth,
                                          externalID: key, kind: isNight ? .night : .nap))
                if let stages = sleep.stages { stagesByID[key] = stages }
            }
        }
        entries.sort { ($0.wakeTime ?? $0.nightDate) > ($1.wakeTime ?? $1.nightDate) }

        // A copy that an older version stored would reach iCloud, so it goes.
        purgeStoredCopies(context: context)
        SleepHealthNights.shared.nights = entries
        SleepHealthNights.shared.stages = stagesByID
        foundNights = entries.count
        defaults.set(Date.now.timeIntervalSince1970, forKey: SleepHealthSettings.lastSyncKey)
    }
}

/// Saves typed nights to Apple Health, as Anchor's own samples. Off until the
/// person turns it on. A night Health already holds from another source is
/// left alone, nothing Anchor saved is ever read back as an imported night,
/// and removing a night here removes the samples Anchor saved for it.
@MainActor
@Observable
final class SleepHealthWriter {
    static let shared = SleepHealthWriter()

    var isWorking = false
    /// One quiet line after saving the recent nights.
    var message: String?
    /// Why turning saving on, or a save, did not work, in plain words, or nil. Shown under the switch.
    var problem: String?

    @ObservationIgnored private let store = HKHealthStore()

    private var available: Bool { HKHealthStore.isHealthDataAvailable() && !DemoMode.isOn }
    private var sleepType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sleepAnalysis) }

    /// What has been saved, kept sealed while locking is on (Patch 35g4). If the record is sealed and does not open, it
    /// reads as empty here, and `canKeepRecord` is false so nothing is saved to Health while that is so (a night would
    /// be saved twice). A write that cannot be sealed is not made.
    private var tracked: [String: Int] {
        get {
            guard let text = LockedSetting.text(UserDefaults.standard.object(forKey: SleepHealthSettings.writtenKey), key: SleepHealthSettings.writtenKey),
                  let list = try? JSONDecoder().decode([String: Int].self, from: Data(text.utf8)) else { return [:] }
            return list
        }
        set {
            let key = SleepHealthSettings.writtenKey
            if FieldLock.isOn {
                guard let data = try? JSONEncoder().encode(newValue), let text = String(data: data, encoding: .utf8),
                      let sealed = LockedSetting.kept(text, key: key) else { return }
                UserDefaults.standard.set(sealed, forKey: key)
            } else {
                UserDefaults.standard.set(newValue, forKey: key)
            }
        }
    }

    /// True when the record of saved nights can be read and a new one can be kept.
    private var canKeepRecord: Bool {
        !LockedSetting.isUnreadable(UserDefaults.standard.object(forKey: SleepHealthSettings.writtenKey), key: SleepHealthSettings.writtenKey)
            && LockedSetting.canKeep
    }

    /// How many nights Anchor has samples saved for.
    var savedCount: Int { tracked.values.filter { $0 > 0 }.count }

    /// How many nights were left alone because Apple Health already holds sleep for them from another source.
    var leftAloneCount: Int { tracked.values.filter { $0 < 0 }.count }

    private func sampleIDs(_ id: String) -> [String] {
        ["anchor.sleep.\(id).bed", "anchor.sleep.\(id).asleep"]
    }

    /// Asks for permission to save sleep (and to look at what Health already
    /// holds for the night), which is when iOS shows its own question.
    func enable(context: ModelContext) async {
        problem = nil
        guard available, let type = sleepType else {
            problem = "Apple Health isn't available here."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [type], read: [type])
        } catch {
            problem = "Apple Health did not open its question: \(error.localizedDescription)"
            return
        }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: SleepHealthSettings.writeKey)
        defaults.set(Date.now.timeIntervalSince1970, forKey: SleepHealthSettings.writeSinceKey)
        message = nil
        await reconcile(context: context)
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: SleepHealthSettings.writeKey)
        message = nil
    }

    /// Makes the nights typed in the last 30 days eligible, then saves them.
    func saveRecent(context: ModelContext) async {
        guard let from = Calendar.current.date(byAdding: .day, value: -30, to: .now) else { return }
        let defaults = UserDefaults.standard
        let current = defaults.double(forKey: SleepHealthSettings.writeSinceKey)
        defaults.set(min(current > 0 ? current : from.timeIntervalSince1970, from.timeIntervalSince1970),
                     forKey: SleepHealthSettings.writeSinceKey)
        let before = savedCount
        await reconcile(context: context)
        let added = max(0, savedCount - before)
        if problem == nil {
            message = added == 0 ? "Nothing new to save." : (added == 1 ? "Saved 1 night." : "Saved \(added) nights.")
        }
    }

    /// Removes everything Anchor has saved to Health and switches saving off.
    /// Only samples Anchor itself saved can be removed, never anyone else's.
    func removeAllSaved() async {
        disable()
        guard available, let type = sleepType else { return }
        do {
            _ = try await store.deleteObjects(of: type, predicate: HKQuery.predicateForObjects(from: HKSource.default()))
            UserDefaults.standard.removeObject(forKey: SleepHealthSettings.writtenKey)
        } catch {
            return
        }
    }

    /// Brings Health in line with the journal: saves typed nights that have both
    /// times, saves them again when they change, and removes the samples for
    /// a night that is gone. Safe to run often.
    func reconcile(context: ModelContext) async {
        guard available, let type = sleepType, !isWorking, canKeepRecord else { return }
        let defaults = UserDefaults.standard
        let writing = defaults.bool(forKey: SleepHealthSettings.writeKey)
        var written = tracked
        if !writing && written.isEmpty { return }
        isWorking = true
        defer { isWorking = false }
        problem = nil

        let since = Date(timeIntervalSince1970: defaults.double(forKey: SleepHealthSettings.writeSinceKey))
        let entries = (try? context.fetch(FetchDescriptor<SleepEntry>())) ?? []
        var wanted: [String: (entry: SleepEntry, bed: Date, wake: Date, version: Int)] = [:]
        for entry in entries where entry.sourceRaw == "typed" && !entry.isBlank {
            guard let bed = entry.bedTime, let wake = entry.wakeTime, wake > bed,
                  wake.timeIntervalSince(bed) <= 24 * 3600 else { continue }
            let id = entry.id.uuidString
            if written[id] != nil || (writing && entry.lastEditedAt >= since) {
                wanted[id] = (entry, bed, wake, Int(entry.lastEditedAt.timeIntervalSince1970))
            }
        }

        // Nights that are gone, or no longer have both times: take back what was saved.
        for id in written.keys where wanted[id] == nil {
            if (written[id] ?? 0) > 0 {
                let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: sampleIDs(id))
                do { _ = try await store.deleteObjects(of: type, predicate: predicate) } catch { continue }
            }
            written[id] = nil
        }
        guard writing else {
            tracked = written
            return
        }

        for (id, night) in wanted {
            if let done = written[id], abs(done) >= night.version { continue }
            // Health is the source of truth: leave a night it already holds from elsewhere.
            if (written[id] ?? 0) <= 0 {
                let predicate = HKQuery.predicateForSamples(withStart: night.bed, end: night.wake, options: [])
                let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: type, predicate: predicate)], sortDescriptors: [])
                let found = (try? await descriptor.result(for: store)) ?? []
                // Only another source's time ASLEEP counts as Health already holding the night. Time in bed, which an iPhone
                // records on its own, or time awake, does not: it would otherwise stop most nights from being saved.
                let inBed = HKCategoryValueSleepAnalysis.inBed.rawValue
                let awake = HKCategoryValueSleepAnalysis.awake.rawValue
                if found.contains(where: {
                    $0.sourceRevision.source.bundleIdentifier != Bundle.main.bundleIdentifier && $0.value != inBed && $0.value != awake
                }) {
                    written[id] = -night.version
                    continue
                }
            }
            let span = Int(night.wake.timeIntervalSince(night.bed) / 60)
            let minutes = min(night.entry.shownMinutes ?? span, span)
            let ids = sampleIDs(id)
            func metadata(_ key: String) -> [String: Any] {
                [HKMetadataKeySyncIdentifier: key, HKMetadataKeySyncVersion: night.version]
            }
            var samples = [HKCategorySample(
                type: type, value: HKCategoryValueSleepAnalysis.inBed.rawValue,
                start: night.bed, end: night.wake, metadata: metadata(ids[0])
            )]
            if minutes > 0 {
                // The time asleep is placed so it ends when you got up.
                let asleepStart = max(night.bed, night.wake.addingTimeInterval(-Double(minutes) * 60))
                samples.append(HKCategorySample(
                    type: type, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    start: asleepStart, end: night.wake, metadata: metadata(ids[1])
                ))
            }
            do {
                try await store.save(samples)
                written[id] = night.version
            } catch {
                problem = "Apple Health would not save a night: \(error.localizedDescription) Check that Anchor is allowed to write sleep in the Health app, under Sharing, Apps, Anchor."
                continue
            }
        }
        tracked = written
    }
}

/// The Apple Health section at the bottom of the Sleep screen. Nothing is
/// asked of Apple Health until Connect is tapped.
private struct SleepHealthCard: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SleepHealthSettings.connectedKey) private var connected = false
    @AppStorage(SleepHealthSettings.lastSyncKey) private var lastSync = 0.0
    @AppStorage(SleepHealthSettings.writeKey) private var writing = false
    @AppStorage(SleepHealthSettings.stagesKey) private var showStages = false
    @State private var connecting = false
    @State private var enablingWrite = false
    @State private var confirmingRemove = false
    @State private var confirmingRemoveSaved = false

    private let reader = SleepHealthReader.shared
    private let writer = SleepHealthWriter.shared

    private var importedCount: Int {
        SleepHealthNights.shared.nights.count
    }

    private var statusLine: String? {
        guard connected else { return nil }
        if reader.foundNights == 0 { return "No sleep found in Apple Health yet." }
        guard lastSync > 0 else { return nil }
        return "Last checked " + Date(timeIntervalSince1970: lastSync).formatted(.relative(presentation: .named)) + "."
    }

    var body: some View {
        Anchor.Card(accentColor: Anchor.Theme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Apple Health", systemImage: "heart.text.square")
                    .font(.system(.headline, design: .rounded))

                bringInSection

                Divider()

                saveSection
            }
            .buttonStyle(.borderless)
        }
        .confirmationDialog(
            "Remove what Anchor saved to Apple Health?",
            isPresented: $confirmingRemoveSaved,
            titleVisibility: .visible
        ) {
            Button("Remove and stop saving", role: .destructive) {
                Task { await writer.removeAllSaved() }
            }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("This takes out only the sleep Anchor saved. Your nights here stay, and nothing from any other source in Apple Health is touched.")
        }
        .confirmationDialog(
            "Stop reading sleep from Apple Health?",
            isPresented: $confirmingRemove,
            titleVisibility: .visible
        ) {
            Button("Stop and clear these nights", role: .destructive) {
                reader.removeImported(context: modelContext)
            }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("The nights read from Apple Health disappear from here. Nights you typed or changed yourself stay, and nothing in Apple Health is touched.")
        }
    }
}

private extension SleepHealthCard {
    /// Reading: one switch, and what belongs to it under it.
    var bringInSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Bring in nights from Apple Health", isOn: Binding(
                get: { connected || connecting },
                set: { on in
                    if on {
                        connecting = true
                        Task {
                            await reader.connect(context: modelContext)
                            connecting = false
                        }
                    } else {
                        reader.disconnect()
                    }
                }
            ))
            .tint(Anchor.Theme.accent)
            .disabled(connecting)
            Text("Reads sleep only. The nights are read from Apple Health each time and are never saved in Anchor, so they never go to iCloud.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let problem = reader.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if connected {
                Toggle("Show sleep stages", isOn: Binding(
                    get: { showStages },
                    set: { on in
                        showStages = on
                        Task { await reader.sync(context: modelContext, full: true) }
                    }
                ))
                .tint(Anchor.Theme.accent)
                Text("Core, deep, REM and awake time, when a watch or another device records them. Read from Health when needed and never saved in Anchor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let statusLine {
                    Text(statusLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button("Check now") {
                    Task { await reader.sync(context: modelContext, full: true) }
                }
                .disabled(reader.isWorking)
            }

            if importedCount > 0 {
                Button("Stop reading sleep from Apple Health", role: .destructive) { confirmingRemove = true }
                    .padding(.top, 2)
                Text(importedCount == 1 ? "1 night shown here is read from Apple Health." : "\(importedCount) nights shown here are read from Apple Health.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Writing: one switch, and what belongs to it under it.
    var saveSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Save nights I type to Apple Health", isOn: Binding(
                get: { writing || enablingWrite },
                set: { on in
                    if on {
                        enablingWrite = true
                        Task {
                            await writer.enable(context: modelContext)
                            enablingWrite = false
                        }
                    } else {
                        writer.disable()
                    }
                }
            ))
            .tint(Anchor.Theme.accent)
            .disabled(enablingWrite)
            Text("Only nights with a bed time and a wake time.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let problem = writer.problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if writing {
                Button("Save the last 30 nights I typed") {
                    Task { await writer.saveRecent(context: modelContext) }
                }
                .disabled(writer.isWorking)
                if let message = writer.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if writer.leftAloneCount > 0 {
                    Text(writer.leftAloneCount == 1
                         ? "1 night was left alone because Apple Health already holds sleep for it from another source, such as a watch."
                         : "\(writer.leftAloneCount) nights were left alone because Apple Health already holds sleep for them from another source, such as a watch.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if writing || writer.savedCount > 0 {
                Button("Remove what Anchor saved", role: .destructive) { confirmingRemoveSaved = true }
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Sleep on Now

/// The sleep journal's own switches. Everything here is off until the person
/// turns it on.
enum SleepSettings {
    /// Show a small "Last night" card on Now in the morning.
    static let nowCardKey = "anchor.sleep.nowCard"
    /// Show a small row for each night in the Journal, and a mark on its month view.
    static let journalKey = "anchor.sleep.journal"
    /// Ask "How did you sleep?" as an extra optional question in a check-in.
    static let checkInKey = "anchor.sleep.checkIn"
    /// An optional morning reminder, its time, with wording that never says what it is about.
    static let reminderEnabledKey = "anchor.sleep.reminder.enabled"
    static let reminderHourKey = "anchor.sleep.reminder.hour"
    static let reminderMinuteKey = "anchor.sleep.reminder.minute"
    /// The day, as year-month-day text, that the card was put away with Not now.
    static let nowDismissedKey = "anchor.sleep.nowDismissedDay"

    static func dayKey(_ date: Date = .now) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}

/// Opens last night's entry in its sheet, finding today's if it is there and
/// making one if not. One left with nothing in it is dropped again, so
/// opening it and closing it leaves nothing behind.
struct SleepLogSheetHost: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entriesStored: [SleepEntry]
    /// Sorted after the items are opened, because a locked nightDate cannot be sorted by the database (Patch 35g1b).
    private var entries: [SleepEntry] { entriesStored.sortedByKey(descending: true) { $0.nightDate } }
    @AppStorage(SleepFeelWords.storageKey) private var wordsRaw = ""
    @State private var entry: SleepEntry?
    @State private var deleting = false

    init() {}

    var body: some View {
        Group {
            if let entry {
                SleepEntrySheet(entry: entry, words: SleepFeelWords.words(from: wordsRaw)) { deleting = true }
            }
        }
        .onAppear {
            guard entry == nil else { return }
            let today = Calendar.current.startOfDay(for: .now)
            if let existing = entries.first(where: { Calendar.current.startOfDay(for: $0.nightDate) == today }) {
                entry = existing
            } else {
                let new = SleepEntry(nightDate: today)
                modelContext.insert(new)
                entry = new
            }
        }
        .onDisappear {
            guard let entry else { return }
            if deleting || entry.isBlank {
                modelContext.delete(entry)
            } else {
                entry.lastEditedAt = .now
            }
        }
    }
}

/// A morning card on Now: "Last night". Only with the switch on in Settings,
/// only before midday, and gone once last night has something written down
/// or Not now is tapped. Not now is remembered for the day and nothing else.
struct SleepMorningCard: View {
    @AppStorage(SleepSettings.nowCardKey) private var enabled = false
    @AppStorage(SleepSettings.nowDismissedKey) private var dismissedDay = ""
    @Query private var entriesStored: [SleepEntry]
    /// Sorted after the items are opened, because a locked nightDate cannot be sorted by the database (Patch 35g1b).
    private var entries: [SleepEntry] { entriesStored.withHealthNights.sortedByKey(descending: true) { $0.nightDate } }
    @State private var logging = false

    init() {}

    private var loggedToday: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return entries.contains { Calendar.current.startOfDay(for: $0.nightDate) == today && !$0.isBlank && !$0.isNap }
    }

    /// A review run shows it at any hour, so it can be looked at in the afternoon.
    private var isMorning: Bool { ReviewMode.isOn || Calendar.current.component(.hour, from: .now) < 12 }

    var body: some View {
        // The card stays while its sheet is open. Putting a start time in makes last night count as written
        // down, which used to take the card away and its sheet with it (Patch R5).
        if logging || (enabled && isMorning && !loggedToday && dismissedDay != SleepSettings.dayKey()) {
            Anchor.Card(accentColor: Anchor.Theme.accent) {
                VStack(alignment: .leading, spacing: 10) {
                    Anchor.SectionHeader(icon: "moon.zzz.fill", title: "Last night")
                    Text("Jot down how you slept, if you would like to.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button { logging = true } label: {
                            Text("Log it").lineLimit(1).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(Anchor.PrimaryButtonStyle())
                        Button { dismissedDay = SleepSettings.dayKey() } label: {
                            Text("Not now").lineLimit(1).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.accent))
                    }
                }
            }
            .sheet(isPresented: $logging) {
                SleepLogSheetHost()
            }
        }
    }
}

/// Opens one night that already exists, from the Journal. A night left with
/// nothing in it, or deleted from inside the sheet, is removed once it closes.
struct SleepEntryEditor: View {
    let entry: SleepEntry
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SleepFeelWords.storageKey) private var wordsRaw = ""
    @State private var deleting = false

    init(entry: SleepEntry) { self.entry = entry }

    var body: some View {
        SleepEntrySheet(entry: entry, words: SleepFeelWords.words(from: wordsRaw)) { deleting = true }
            .onDisappear {
                if deleting || entry.isBlank {
                    modelContext.delete(entry)
                } else {
                    entry.lastEditedAt = .now
                }
            }
    }
}
