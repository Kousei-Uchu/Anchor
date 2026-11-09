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
                    if entry.sourceRaw == SleepHealthSettings.sourceHealth {
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
            entry.note
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

// MARK: - Apple Health (sleep, read only)

enum SleepHealthSettings {
    /// On while Anchor is bringing in new nights from Apple Health.
    static let connectedKey = "anchor.sleep.health.read"
    /// When Apple Health was last checked, as seconds since 1970.
    static let lastSyncKey = "anchor.sleep.health.lastSync"
    /// The `sourceRaw` of a night that came from Apple Health.
    static let sourceHealth = "health"
    /// On while typed nights are saved to Apple Health.
    static let writeKey = "anchor.sleep.health.write"
    /// Nights typed since this moment are eligible to be saved, as seconds since 1970.
    static let writeSinceKey = "anchor.sleep.health.writeSince"
    /// What Anchor has saved: the night's id, and the version saved (negative when
    /// the night was left alone because Health already held it).
    static let writtenKey = "anchor.sleep.health.written"
}

/// Reads sleep from Apple Health and keeps one summary per night in Anchor's
/// own store. Nothing is read until the person taps Connect, and a night they
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

    @ObservationIgnored private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() && !ShowcaseMode.isOn }

    private var sleepType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sleepAnalysis) }

    /// Asks for read access to sleep, which is when iOS shows its own
    /// question, then brings in the last 30 days.
    func connect(context: ModelContext) async {
        guard isAvailable, !DemoMode.isOn, let type = sleepType else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: [type])
        } catch {
            return
        }
        UserDefaults.standard.set(true, forKey: SleepHealthSettings.connectedKey)
        await sync(context: context, full: true)
    }

    func disconnect() {
        UserDefaults.standard.set(false, forKey: SleepHealthSettings.connectedKey)
    }

    /// Removes only the nights that came from Apple Health and were not
    /// changed since, and stops bringing in more. Nothing in Health changes.
    @discardableResult
    func removeImported(context: ModelContext) -> Int {
        disconnect()
        let all = (try? context.fetch(FetchDescriptor<SleepEntry>())) ?? []
        var removed = 0
        for entry in all where entry.sourceRaw == SleepHealthSettings.sourceHealth {
            context.delete(entry)
            removed += 1
        }
        try? context.save()
        foundNights = nil
        UserDefaults.standard.removeObject(forKey: SleepHealthSettings.lastSyncKey)
        return removed
    }

    private struct Piece {
        var start: Date
        var end: Date
        var asleep: Bool
    }

    private struct Night {
        var day: Date
        var bed: Date
        var wake: Date
        var minutesAsleep: Int?
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
        guard defaults.bool(forKey: SleepHealthSettings.connectedKey),
              isAvailable, !DemoMode.isOn, !isWorking, let type = sleepType else { return }
        isWorking = true
        defer { isWorking = false }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let floor = cal.date(byAdding: .day, value: -30, to: today) else { return }
        var from = floor
        let last = defaults.double(forKey: SleepHealthSettings.lastSyncKey)
        if !full, last > 0,
           let back = cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: Date(timeIntervalSince1970: last))) {
            from = max(floor, back)
        }
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
        for sample in samples {
            // Never read back anything Anchor wrote itself.
            if sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier { continue }
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            if value == .awake { continue }
            let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.contains(value)
            pieces.append(Piece(start: sample.startDate, end: sample.endDate, asleep: asleep))
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
        var longestByDay: [Date: Night] = [:]
        for session in sessions {
            guard let bed = session.map(\.start).min(), let wake = session.map(\.end).max() else { continue }
            let span = wake.timeIntervalSince(bed)
            guard span > 0, span <= 20 * 3600 else { continue }
            let day = cal.startOfDay(for: wake)
            guard day >= from, day <= today else { continue }
            let asleepPieces = session.filter(\.asleep)
            let minutes = asleepPieces.isEmpty ? nil : Self.unionMinutes(asleepPieces)
            let night = Night(day: day, bed: bed, wake: wake, minutesAsleep: minutes.flatMap { $0 > 0 ? $0 : nil })
            if let existing = longestByDay[day], existing.wake.timeIntervalSince(existing.bed) >= span { continue }
            longestByDay[day] = night
        }

        let existing = (try? context.fetch(FetchDescriptor<SleepEntry>())) ?? []
        var typedDays = Set<Date>()
        var healthByKey: [String: SleepEntry] = [:]
        for entry in existing {
            if entry.sourceRaw == SleepHealthSettings.sourceHealth, let key = entry.externalID {
                healthByKey[key] = entry
            } else {
                typedDays.insert(cal.startOfDay(for: entry.nightDate))
            }
        }
        for night in longestByDay.values {
            // A night you wrote down is yours, so Apple Health never replaces it.
            if typedDays.contains(night.day) { continue }
            let parts = cal.dateComponents([.year, .month, .day], from: night.day)
            let key = String(format: "health:%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            if let entry = healthByKey[key] {
                if entry.bedTime != night.bed { entry.bedTime = night.bed }
                if entry.wakeTime != night.wake { entry.wakeTime = night.wake }
                if entry.minutesAsleep != night.minutesAsleep { entry.minutesAsleep = night.minutesAsleep }
            } else {
                context.insert(SleepEntry(
                    nightDate: night.day, bedTime: night.bed, wakeTime: night.wake,
                    minutesAsleep: night.minutesAsleep, sourceRaw: SleepHealthSettings.sourceHealth, externalID: key
                ))
            }
        }
        try? context.save()
        foundNights = longestByDay.count
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

    @ObservationIgnored private let store = HKHealthStore()

    private var available: Bool { HKHealthStore.isHealthDataAvailable() && !DemoMode.isOn }
    private var sleepType: HKCategoryType? { HKObjectType.categoryType(forIdentifier: .sleepAnalysis) }

    private var tracked: [String: Int] {
        get { (UserDefaults.standard.dictionary(forKey: SleepHealthSettings.writtenKey) as? [String: Int]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: SleepHealthSettings.writtenKey) }
    }

    /// How many nights Anchor has samples saved for.
    var savedCount: Int { tracked.values.filter { $0 > 0 }.count }

    private func sampleIDs(_ id: String) -> [String] {
        ["anchor.sleep.\(id).bed", "anchor.sleep.\(id).asleep"]
    }

    /// Asks for permission to save sleep (and to look at what Health already
    /// holds for the night), which is when iOS shows its own question.
    func enable(context: ModelContext) async {
        guard available, let type = sleepType else { return }
        do {
            try await store.requestAuthorization(toShare: [type], read: [type])
        } catch {
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
        message = added == 0 ? "Nothing new to save." : (added == 1 ? "Saved 1 night." : "Saved \(added) nights.")
    }

    /// Removes everything Anchor has saved to Health and switches saving off.
    /// Only samples Anchor itself saved can be removed, never anyone else's.
    func removeAllSaved() async {
        disable()
        guard available, let type = sleepType else { return }
        do {
            _ = try await store.deleteObjects(of: type, predicate: HKQuery.predicateForObjects(from: HKSource.default()))
            tracked = [:]
        } catch {
            return
        }
    }

    /// Brings Health in line with the journal: saves typed nights that have both
    /// times, saves them again when they change, and removes the samples for
    /// a night that is gone. Safe to run often.
    func reconcile(context: ModelContext) async {
        guard available, let type = sleepType, !isWorking else { return }
        let defaults = UserDefaults.standard
        let writing = defaults.bool(forKey: SleepHealthSettings.writeKey)
        var written = tracked
        if !writing && written.isEmpty { return }
        isWorking = true
        defer { isWorking = false }

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
                if found.contains(where: { $0.sourceRevision.source.bundleIdentifier != Bundle.main.bundleIdentifier }) {
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
    @Query private var entries: [SleepEntry]
    @State private var connecting = false
    @State private var enablingWrite = false
    @State private var confirmingRemove = false
    @State private var confirmingRemoveSaved = false

    private let reader = SleepHealthReader.shared
    private let writer = SleepHealthWriter.shared

    private var importedCount: Int {
        entries.filter { $0.sourceRaw == SleepHealthSettings.sourceHealth }.count
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
            "Remove imported sleep?",
            isPresented: $confirmingRemove,
            titleVisibility: .visible
        ) {
            Button("Remove and stop bringing in nights", role: .destructive) {
                reader.removeImported(context: modelContext)
            }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("This takes out the nights that came from Apple Health. Nights you typed or changed yourself stay, and nothing in Apple Health is touched.")
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
            Text("Reads sleep only, and keeps a copy on this phone.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if connected {
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
                Button("Remove imported sleep", role: .destructive) { confirmingRemove = true }
                    .padding(.top, 2)
                Text(importedCount == 1 ? "1 night here came from Apple Health." : "\(importedCount) nights here came from Apple Health.")
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
    @Query(sort: \SleepEntry.nightDate, order: .reverse) private var entries: [SleepEntry]
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
    @Query(sort: \SleepEntry.nightDate, order: .reverse) private var entries: [SleepEntry]
    @State private var logging = false

    init() {}

    private var loggedToday: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return entries.contains { Calendar.current.startOfDay(for: $0.nightDate) == today && !$0.isBlank }
    }

    /// A review run shows it at any hour, so it can be looked at in the afternoon.
    private var isMorning: Bool { ReviewMode.isOn || Calendar.current.component(.hour, from: .now) < 12 }

    var body: some View {
        if enabled && isMorning && !loggedToday && dismissedDay != SleepSettings.dayKey() {
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
