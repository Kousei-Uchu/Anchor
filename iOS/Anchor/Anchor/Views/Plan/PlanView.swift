//
//  PlanView.swift
//  Anchor
//

import SwiftUI
import SwiftData

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
            scheduler.removeTriggerWindowNotifications(for: window)
            scheduler.scheduleTriggerWindow(
                window,
                reasonsPool: reasons,
                escalationContacts: escalationContacts,
                primaryContact: contacts.first
            )
        }
    }

    private func refreshWidgetSnapshot() {
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
        guard let soonest = TimeWindowHelper.soonestUpcoming(among: triggerWindows) else { return nil }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE h:mm a")
        let timeLabel = formatter.string(from: soonest.date)
        let name = soonest.window.label.isEmpty ? "Trigger window" : soonest.window.label
        return "\(name) · \(timeLabel)"
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
        Set(filter { !$0.isBlank }.map { Calendar.current.startOfDay(for: $0.nightDate) })
    }
}

struct SleepWidget: View {
    @Query(sort: \SleepEntry.nightDate, order: .reverse) private var entries: [SleepEntry]

    private var caption: String {
        if let latest = entries.first(where: { $0.shownMinutes != nil }), let minutes = latest.shownMinutes {
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
    @Query(sort: \SleepEntry.nightDate, order: .reverse) private var entries: [SleepEntry]
    @AppStorage(SleepFeelWords.storageKey) private var wordsRaw = ""

    @State private var editing: SleepEntry?
    @State private var lastOpened: SleepEntry?
    @State private var toDelete: SleepEntry?
    @State private var confirmingDelete: SleepEntry?
    @State private var renamingWords = false

    private var words: [String] { SleepFeelWords.words(from: wordsRaw) }

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    /// Time asleep for the last 30 nights that have it, smallest first.
    private var recentMinutes: [Int] {
        let cal = Calendar.current
        guard let from = cal.date(byAdding: .day, value: -29, to: today) else { return [] }
        return entries
            .filter { cal.startOfDay(for: $0.nightDate) >= from }
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
                Anchor.Card(accentColor: Anchor.Theme.accent) {
                    VStack(alignment: .leading, spacing: 10) {
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
                .anchorCardRow()

                ForEach(entries) { entry in
                    SleepRow(entry: entry, words: words) { open(entry) }
                        .anchorDeletable { confirmingDelete = entry }
                        .anchorCardRow()
                }
            }
        }
        .listStyle(.plain)
        .anchorBackground()
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("Rename the three words") { renamingWords = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
                Anchor.AddToolbarButton(label: "Log sleep") { logNight() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { entry in
            SleepEntrySheet(entry: entry, words: words) { toDelete = entry }
        }
        .sheet(isPresented: $renamingWords) {
            SleepWordsSheet()
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
        lastOpened = entry
        editing = entry
    }

    /// Opens last night, which is the one you woke up from today. If today
    /// already has one, that one opens instead of a second being made.
    private func logNight() {
        if let existing = entries.first(where: { Calendar.current.startOfDay(for: $0.nightDate) == today }) {
            open(existing)
            return
        }
        let new = SleepEntry(nightDate: today)
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
            if opened.isBlank {
                modelContext.delete(opened)
            } else {
                opened.lastEditedAt = .now
            }
        }
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
                        Text(entry.nightDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
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
    @Query private var allEntries: [SleepEntry]

    private var cal: Calendar { .current }

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
                entry.bedTime = on ? SleepEntry.bedMoment(clock: clock(23, 0), night: entry.nightDate, wake: entry.wakeTime) : nil
            }
        )
    }

    private var knowsWake: Binding<Bool> {
        Binding(
            get: { entry.wakeTime != nil },
            set: { on in
                entry.wakeTime = on ? SleepEntry.wakeMoment(clock: clock(7, 0), night: entry.nightDate) : nil
                if let bed = entry.bedTime {
                    entry.bedTime = SleepEntry.bedMoment(clock: bed, night: entry.nightDate, wake: entry.wakeTime)
                }
            }
        )
    }

    private var bedPicker: Binding<Date> {
        Binding(
            get: { entry.bedTime ?? clock(23, 0) },
            set: { entry.bedTime = SleepEntry.bedMoment(clock: $0, night: entry.nightDate, wake: entry.wakeTime) }
        )
    }

    private var wakePicker: Binding<Date> {
        Binding(
            get: { entry.wakeTime ?? clock(7, 0) },
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Woke up on", selection: nightBinding, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    if nightTaken {
                        Text("There is already an entry for this night. You can open it from the list.")
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
                let saved = wordsRaw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                return index < saved.count ? saved[index] : ""
            },
            set: { newValue in
                var saved = wordsRaw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
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
