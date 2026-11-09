//
//  SettingsView.swift
//  Anchor
//
//  The one place app-wide settings live. Plan (and every other read screen)
//  is for things to reach; anything you switch on or off, or set a time for,
//  is configured here, behind the gear. Deliberately plainer than the card
//  screens: flat grouped rows on the quieter settings background.
//

import SwiftUI
import SwiftData
import UIKit

/// Daily check-in preferences, shared by Settings (which edits them) and Plan
/// (which re-applies the schedule when it appears, so the notification never
/// silently lapses just because Settings wasn't opened).
enum DailyCheckInSettings {
    static let enabledKey = "anchor.dailyCheckIn.enabled"
    static let hourKey = "anchor.dailyCheckIn.hour"
    static let minuteKey = "anchor.dailyCheckIn.minute"

    @MainActor
    static func reapplyIfEnabled(using context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }
        let hour = defaults.object(forKey: hourKey) as? Int ?? 20
        let minute = defaults.object(forKey: minuteKey) as? Int ?? 0
        NotificationScheduler(context: context).scheduleDailyCheckIn(hour: hour, minute: minute)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryCounter.sortOrder) private var allCounters: [RecoveryCounter]
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query(sort: \TrustedContact.sortOrder) private var helloContacts: [TrustedContact]

    @StateObject private var appLock = AppLock.shared
    @State private var faceIDEnabled = AppLock.shared.isEnabled
    @State private var showTour = false

    @AppStorage(TabLayoutStyle.storageKey) private var layoutRaw = TabLayoutStyle.widgets.rawValue
    @AppStorage(DailyCheckInSettings.enabledKey) private var dailyCheckInEnabled = false
    @AppStorage(DailyCheckInSettings.hourKey) private var dailyCheckInHour = 20
    @AppStorage(DailyCheckInSettings.minuteKey) private var dailyCheckInMinute = 0

    @AppStorage(PomodoroSettings.alertsKey) private var focusAlertsEnabled = false
    @AppStorage(PomodoroSettings.lockScreenKey) private var focusLockScreenEnabled = false

    @AppStorage(RecoverySettings.pledgeEnabled) private var pledgeEnabled = false
    @AppStorage(RecoverySettings.pledgeHour) private var pledgeHour = 8
    @AppStorage(RecoverySettings.pledgeMinute) private var pledgeMinute = 0
    @AppStorage(RecoverySettings.reviewEnabled) private var reviewEnabled = false
    @AppStorage(RecoverySettings.reviewHour) private var reviewHour = 20
    @AppStorage(RecoverySettings.reviewMinute) private var reviewMinute = 30
    @AppStorage(RecoverySettings.milestonesEnabled) private var milestonesEnabled = false
    @AppStorage(RecoverySettings.showLongest) private var showLongest = false
    @AppStorage(AppointmentReminders.dayBeforeKey) private var remindDayBefore = false
    @AppStorage(AppointmentReminders.sameDayKey) private var remindSameDay = false
    @AppStorage(AppointmentReminders.eveningHourKey) private var eveningHour = AppointmentReminders.defaultEveningHour
    @AppStorage(AppointmentReminders.eveningMinuteKey) private var eveningMinute = 0
    @AppStorage(SleepSettings.nowCardKey) private var sleepNowCard = false
    @AppStorage(SleepSettings.journalKey) private var sleepInJournal = false
    @AppStorage(SleepSettings.checkInKey) private var sleepInCheckIn = false
    @AppStorage(SleepSettings.reminderEnabledKey) private var sleepReminderOn = false
    @AppStorage(SleepSettings.reminderHourKey) private var sleepReminderHour = 8
    @AppStorage(SleepSettings.reminderMinuteKey) private var sleepReminderMinute = 0
    @AppStorage(WidgetTab.plan.hiddenKey) private var planHiddenRaw = WidgetTab.plan.defaultHiddenRaw
    @Query private var sleepEntries: [SleepEntry]

    /// Recovery is optional and discreet: its settings only appear once the
    /// user has a counter (or already has a recovery reminder switched on, so
    /// it can always be turned back off).
    private var showsRecovery: Bool {
        allCounters.contains { !$0.isArchived } || pledgeEnabled || reviewEnabled || milestonesEnabled
    }

    /// Sleep is invisible until it is used: its setting only appears once the
    /// Sleep widget has been turned on or a night has been written down (or
    /// the card is already on, so it can always be turned back off).
    private var showsSleep: Bool {
        !sleepEntries.isEmpty || sleepNowCard || sleepInJournal || sleepInCheckIn || sleepReminderOn || !WidgetLayoutStore.decode(planHiddenRaw).contains(.sleep)
    }

    var body: some View {
        NavigationStack {
            Form {
                Anchor.SettingsSection(
                    title: "Privacy",
                    footer: appLock.canAuthenticate()
                        ? "Locks Anchor independently of your phone's own lock."
                        : "This device doesn't have Face ID, Touch ID, or a passcode set up."
                ) {
                    Anchor.SettingsToggle(title: "Require Face ID", isOn: $faceIDEnabled)
                }

                Anchor.SettingsSection(
                    title: "Reminders",
                    footer: "Gentle and optional. Totally fine to skip when one comes."
                ) {
                    Anchor.SettingsToggle(title: "Daily check-in", isOn: $dailyCheckInEnabled)
                    if dailyCheckInEnabled {
                        Anchor.SettingsTimeRow(time: timeBinding($dailyCheckInHour, $dailyCheckInMinute))
                    }
                    Anchor.SettingsToggle(title: "Focus timer alerts", isOn: $focusAlertsEnabled)
                    Anchor.SettingsToggle(title: "Focus timer on the lock screen", isOn: $focusLockScreenEnabled)
                }

                if routines.contains(where: { !$0.isBlank }) {
                    Anchor.SettingsSection(
                        title: "Routine reminders",
                        footer: "Off until you switch one on. The days are set in the routine itself, and the lock screen never shows its name."
                    ) {
                        ForEach(routines.filter { !$0.isBlank }) { routine in
                            RoutineReminderSettingsRow(routine: routine)
                        }
                    }
                }

                Anchor.SettingsSection(
                    title: "Session reminders",
                    footer: "Off until you switch one on. The evening before comes at the time you choose, from 4 pm to 10:59 pm. The lock screen only says something you planned is coming up, never who it is with. Tap a reminder and Anchor opens Session prep for that person."
                ) {
                    Anchor.SettingsToggle(title: "The evening before", isOn: $remindDayBefore)
                    if remindDayBefore {
                        Anchor.SettingsTimeRow(title: "Evening time", time: eveningBinding)
                    }
                    Anchor.SettingsToggle(title: "A couple of hours before", isOn: $remindSameDay)
                }

                if helloContacts.contains(where: { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    Anchor.SettingsSection(
                        title: "Hello reminders",
                        footer: "Off until you switch one on. At most one comes on any day, and the lock screen never shows a name."
                    ) {
                        ForEach(helloContacts.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { contact in
                            HelloReminderSettingsRow(contact: contact, all: helloContacts)
                        }
                    }
                }

                if helloContacts.contains(where: { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    Anchor.SettingsSection(
                        title: "Support day reminders",
                        footer: "Off until you switch one on. For a person who can see a day on your Support calendar, a reminder at 9 am the morning of that day or the day before. It takes the place of a hello that day, and at most one comes on any day. The lock screen never shows a name."
                    ) {
                        ForEach(helloContacts.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { contact in
                            SupportDayReminderSettingsRow(contact: contact, all: helloContacts)
                        }
                    }
                }

                if helloContacts.contains(where: { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    Anchor.SettingsSection(
                        title: "Follow-up reminders",
                        footer: "Off unless you choose one when you write to someone. It comes a few days later at 10 am. It takes the place of a hello that day, and at most one comes on any day. The lock screen never shows a name."
                    ) {
                        FollowUpSettingsRow()
                    }
                }

                if showsRecovery {
                    Anchor.SettingsSection(
                        title: "Recovery",
                        footer: "Reminders and widgets use generic wording, like \"A quiet moment for yourself?\", so nobody reading your lock screen learns what you're tracking. You can show a counter's name outside the app by turning that on for the counter. Your longest run stays hidden until you switch on Show my longest run."
                    ) {
                        Anchor.SettingsToggle(title: "Daily pledge", isOn: $pledgeEnabled)
                        if pledgeEnabled {
                            Anchor.SettingsTimeRow(time: timeBinding($pledgeHour, $pledgeMinute))
                        }
                        Anchor.SettingsToggle(title: "Evening review", isOn: $reviewEnabled)
                        if reviewEnabled {
                            Anchor.SettingsTimeRow(time: timeBinding($reviewHour, $reviewMinute))
                        }
                        Anchor.SettingsToggle(title: "Milestones", isOn: $milestonesEnabled)
                        Anchor.SettingsToggle(title: "Show my longest run", isOn: $showLongest)
                    }
                }

                if showsSleep {
                    Anchor.SettingsSection(
                        title: "Sleep",
                        footer: "These are off until you switch them on. Last night is a card on Now in the morning, until you write down last night or tap Not now. The Journal gets a small row for each night and a mark on the month. A check-in gets one more optional question, unless last night is already written down. The reminder never says on the lock screen what it is about."
                    ) {
                        Anchor.SettingsToggle(title: "Show Last night on Now", isOn: $sleepNowCard)
                        Anchor.SettingsToggle(title: "Show sleep in the Journal", isOn: $sleepInJournal)
                        Anchor.SettingsToggle(title: "Ask about sleep in check-ins", isOn: $sleepInCheckIn)
                        Anchor.SettingsToggle(title: "Morning reminder", isOn: $sleepReminderOn)
                        if sleepReminderOn {
                            Anchor.SettingsTimeRow(time: timeBinding($sleepReminderHour, $sleepReminderMinute))
                        }
                    }
                }

                Anchor.SettingsSection(
                    title: "Layout",
                    footer: "Widgets show live content you can use directly. Icons is the classic grid of buttons."
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plan, Bridge & Thread")
                            .font(.system(.subheadline, design: .rounded))
                        Picker("Plan, Bridge & Thread", selection: $layoutRaw) {
                            Text("Widgets").tag(TabLayoutStyle.widgets.rawValue)
                            Text("Icons").tag(TabLayoutStyle.icons.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)

                    if layoutRaw != TabLayoutStyle.icons.rawValue {
                        NavigationLink {
                            CustomiseWidgetsView()
                        } label: {
                            Text("Customise widgets")
                                .font(.system(.subheadline, design: .rounded))
                        }
                    }
                }

                Anchor.SettingsSection(title: "Your data and help") {
                    NavigationLink {
                        DataControlView()
                    } label: {
                        Text("Your data").font(.system(.subheadline, design: .rounded))
                    }
                    Button {
                        showTour = true
                    } label: {
                        Text("Take the tour")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("About Anchor").font(.system(.subheadline, design: .rounded))
                    }
                    NavigationLink {
                        ShowcaseSettingsView()
                    } label: {
                        Text("Showcase mode").font(.system(.subheadline, design: .rounded))
                    }
                    #if DEBUG
                    NavigationLink {
                        EncryptionSettingsView()
                    } label: {
                        Text("Encryption (test build)").font(.system(.subheadline, design: .rounded))
                    }
                    NavigationLink {
                        AIToolsSettingsView()
                    } label: {
                        Text("AI tools (test build)").font(.system(.subheadline, design: .rounded))
                    }
                    #endif
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .guideButton("settings", placement: .topBarLeading)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showTour) {
                OnboardingTourView()
            }
            .onChange(of: faceIDEnabled) { _, isOn in appLock.isEnabled = isOn }
            .onChange(of: dailyCheckInEnabled) { _, _ in applyDailyCheckIn() }
            .onChange(of: sleepReminderOn) { _, isOn in
                if isOn { NotificationScheduler.askForPermissionIfNeeded() }
                SleepReminder.refresh()
            }
            .onChange(of: remindDayBefore) { _, isOn in
                if isOn { NotificationScheduler.askForPermissionIfNeeded() }
                AppointmentReminders.refresh(using: modelContext)
            }
            .onChange(of: remindSameDay) { _, isOn in
                if isOn { NotificationScheduler.askForPermissionIfNeeded() }
                AppointmentReminders.refresh(using: modelContext)
            }
            .onChange(of: eveningHour) { _, _ in AppointmentReminders.refresh(using: modelContext) }
            .onChange(of: eveningMinute) { _, _ in AppointmentReminders.refresh(using: modelContext) }
            .onChange(of: sleepReminderHour) { _, _ in SleepReminder.refresh() }
            .onChange(of: sleepReminderMinute) { _, _ in SleepReminder.refresh() }
            .onChange(of: focusAlertsEnabled) { _, isOn in PomodoroSettings.alertsChanged(isOn) }
            .onChange(of: focusLockScreenEnabled) { _, isOn in PomodoroSettings.lockScreenChanged(isOn) }
            .onChange(of: dailyCheckInHour) { _, _ in applyDailyCheckIn() }
            .onChange(of: dailyCheckInMinute) { _, _ in applyDailyCheckIn() }
            .onChange(of: pledgeEnabled) { _, isOn in recoveryRemindersChanged(isOn) }
            .onChange(of: reviewEnabled) { _, isOn in recoveryRemindersChanged(isOn) }
            .onChange(of: milestonesEnabled) { _, isOn in recoveryRemindersChanged(isOn) }
            .onChange(of: pledgeHour) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
            .onChange(of: pledgeMinute) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
            .onChange(of: reviewHour) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
            .onChange(of: reviewMinute) { _, _ in RecoveryNotifications.refresh(using: modelContext) }
        }
    }

    private func applyDailyCheckIn() {
        let scheduler = NotificationScheduler(context: modelContext)
        if dailyCheckInEnabled {
            scheduler.scheduleDailyCheckIn(hour: dailyCheckInHour, minute: dailyCheckInMinute)
        } else {
            scheduler.cancelDailyCheckIn()
        }
    }

    private func recoveryRemindersChanged(_ isOn: Bool) {
        if isOn { NotificationScheduler.askForPermissionIfNeeded() }
        RecoveryNotifications.refresh(using: modelContext)
    }

    /// The evening time, kept between 4 pm and 10:59 pm so it is always the evening of the day before.
    private var eveningBinding: Binding<Date> {
        Binding(
            get: {
                let time = AppointmentReminders.clampedEvening(hour: eveningHour, minute: eveningMinute)
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let time = AppointmentReminders.clampedEvening(hour: parts.hour ?? eveningHour, minute: parts.minute ?? eveningMinute)
                eveningHour = time.hour
                eveningMinute = time.minute
            }
        )
    }

    private func timeBinding(_ hour: Binding<Int>, _ minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: hour.wrappedValue, minute: minute.wrappedValue, second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                hour.wrappedValue = parts.hour ?? hour.wrappedValue
                minute.wrappedValue = parts.minute ?? minute.wrappedValue
            }
        )
    }
}

/// One person's hello reminder in Settings: the switch, then the time and the days once it is on.
private struct HelloReminderSettingsRow: View {
    @Bindable var contact: TrustedContact
    let all: [TrustedContact]
    @Environment(\.modelContext) private var modelContext

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: contact.helloHour, minute: contact.helloMinute,
                                      second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                contact.helloHour = parts.hour ?? contact.helloHour
                contact.helloMinute = parts.minute ?? contact.helloMinute
            }
        )
    }

    private var sharedNote: String? {
        let days = HelloReminders.sharedDays(for: contact.id, in: HelloReminders.entries(of: all))
        guard !days.isEmpty else { return nil }
        let names = days.map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
        return "Not on \(names): another person's hello is set for that day."
    }

    var body: some View {
        Group {
            Anchor.SettingsToggle(title: contact.name, isOn: $contact.helloEnabled)
            if contact.helloEnabled {
                Anchor.SettingsTimeRow(time: timeBinding)
                RoutineWeekdayRow(days: $contact.helloDays)
                if let summary = contact.helloSummary {
                    Text(summary).font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("No days picked yet.").font(.footnote).foregroundStyle(.secondary)
                }
                if let note = sharedNote {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: contact.helloEnabled) { _, isOn in
            if isOn {
                if contact.helloDays.isEmpty { contact.helloDays = [1] }
                NotificationScheduler.askForPermissionIfNeeded()
            }
            HelloReminders.refresh(using: modelContext)
        }
        .onChange(of: contact.helloHour) { _, _ in HelloReminders.refresh(using: modelContext) }
        .onChange(of: contact.helloMinute) { _, _ in HelloReminders.refresh(using: modelContext) }
        .onChange(of: contact.helloDays) { _, _ in HelloReminders.refresh(using: modelContext) }
    }
}

/// One person's support day reminder in Settings: the switch, then when it comes once it is on.
private struct SupportDayReminderSettingsRow: View {
    @Bindable var contact: TrustedContact
    let all: [TrustedContact]
    @Query(sort: \SupportCalendarEntry.date) private var entries: [SupportCalendarEntry]
    @Environment(\.modelContext) private var modelContext

    private var skippedNote: String? {
        let days = HelloReminders.skippedSupportDays(for: contact.id, contacts: all, entries: entries)
        guard !days.isEmpty else { return nil }
        let names = days.map { $0.formatted(.dateTime.day().month(.abbreviated)) }.joined(separator: ", ")
        return "No reminder for \(names): another person's comes that day."
    }

    var body: some View {
        Group {
            Anchor.SettingsToggle(title: contact.name, isOn: $contact.supportDaysEnabled)
            if contact.supportDaysEnabled {
                Picker("When it comes", selection: $contact.supportDaysDayBefore) {
                    Text("The morning of").tag(false)
                    Text("The day before").tag(true)
                }
                .pickerStyle(.segmented)
                if let note = skippedNote {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: contact.supportDaysEnabled) { _, isOn in
            if isOn { NotificationScheduler.askForPermissionIfNeeded() }
            HelloReminders.refresh(using: modelContext)
        }
        .onChange(of: contact.supportDaysDayBefore) { _, _ in HelloReminders.refresh(using: modelContext) }
    }
}

/// Follow-ups are chosen when a message is written, so this only shows how many are waiting and
/// removes them all.
private struct FollowUpSettingsRow: View {
    @Query(sort: \ThreadMessage.timestamp) private var messages: [ThreadMessage]
    @Environment(\.modelContext) private var modelContext
    @State private var confirming = false

    private var waiting: [ThreadMessage] {
        messages.filter { message in
            guard let day = message.followUpAt, let at = HelloReminders.followUpTime(on: day) else { return false }
            return at > .now
        }
    }

    var body: some View {
        Group {
            if waiting.isEmpty {
                Text("None waiting.").foregroundStyle(.secondary)
            } else {
                Text(waiting.count == 1 ? "1 waiting." : "\(waiting.count) waiting.")
                Button("Remove all follow-ups", role: .destructive) { confirming = true }
            }
        }
        .confirmationDialog("Remove every follow-up?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Remove all", role: .destructive) {
                for message in waiting { message.followUpAt = nil }
                try? modelContext.save()
                HelloReminders.refresh(using: modelContext)
            }
            Button("Keep them", role: .cancel) {}
        }
    }
}

/// One routine's reminder in Settings: the switch, and the time once it is on.
/// The days are chosen in the routine itself.
private struct RoutineReminderSettingsRow: View {
    @Bindable var routine: Routine
    @Environment(\.modelContext) private var modelContext

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: routine.reminderHour, minute: routine.reminderMinute,
                                      second: 0, of: .now) ?? .now
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                routine.reminderHour = parts.hour ?? routine.reminderHour
                routine.reminderMinute = parts.minute ?? routine.reminderMinute
            }
        )
    }

    var body: some View {
        Group {
            Anchor.SettingsToggle(title: routine.displayName, isOn: $routine.reminderEnabled)
            if routine.reminderEnabled {
                Anchor.SettingsTimeRow(time: timeBinding)
                if let summary = routine.reminderSummary {
                    Text(summary).font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text("No days picked yet. Choose them in the routine.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: routine.reminderEnabled) { _, isOn in
            if isOn {
                if routine.reminderDays.isEmpty { routine.reminderDays = Array(1...7) }
                NotificationScheduler.askForPermissionIfNeeded()
            }
            RoutineReminders.refresh(using: modelContext)
        }
        .onChange(of: routine.reminderHour) { _, _ in RoutineReminders.refresh(using: modelContext) }
        .onChange(of: routine.reminderMinute) { _, _ in RoutineReminders.refresh(using: modelContext) }
    }
}

// MARK: - About

/// One entry in What's new.
struct AboutNote: Identifiable {
    let title: String
    let body: String
    var id: String { title }
}

/// What one version of the app added, changed and removed. A group with nothing in it is not shown.
struct AboutVersion: Identifiable {
    let version: String
    var added: [AboutNote] = []
    var changed: [AboutNote] = []
    var removed: [AboutNote] = []
    var id: String { version }
}

/// The words on the About screen. The same copy is in
/// website/src/content/about.ts, and scripts/check-about-content.mjs fails if
/// the two stop matching, so the app and the website say the same thing.
/// Keep the string literals here in the same order as in that file.
enum AboutContent {
    static let websiteURL = "https://anchor.aspens.page"
    static let privacyURL = "https://anchor.aspens.page/privacy"
    static let sourceURL = "https://github.com/Kousei-Uchu/Anchor"
    static let supportEmail = "anchor@aspens.page"

    static let purpose = "Anchor is a private place for your safety plan, your people and your journal, for the hard days and the ordinary ones. It is an early build and parts of it will change."

    static let principles: [String] = [
        "No scores and no streak pressure. Anchor does not grade how you are doing.",
        "Local first. What you write stays on your phone, with no account, no ads and no tracking.",
        "Nothing is shared unless you share it. Messages and exports go only where you send them.",
    ]

    static let licences = "Anchor is built with Apple's own frameworks. It contains no third-party code or fonts."

    static let contactNote = "I can't reply in real time. If you are in danger right now, call your local emergency number or a crisis line."

    /// Newest version first. The first one is open in What's new and the others are folded.
    /// To add a version, put it at the top with what it added, changed and removed.
    static let versions: [AboutVersion] = [
        AboutVersion(version: "1.0", added: [
            AboutNote(title: "Sleep journal", body: "An optional sleep journal under Plan, with Apple Health if you want it. Nothing is scored."),
            AboutNote(title: "Export for someone", body: "Choose who it is for and what goes in, then make a PDF or a web page to share."),
            AboutNote(title: "Look at what's stored", body: "See everything Anchor holds, behind Face ID or your passcode, in plain language."),
            AboutNote(title: "Tasks and routines", body: "Tasks with steps, a focus timer, Plan my day, quick lists, routines and checklists."),
            AboutNote(title: "People and providers", body: "A page for each person in Thread, and more than one provider in Bridge."),
            AboutNote(title: "Sections of your own", body: "The safety plan and the Boundaries list are sections you rename, reorder and hide."),
            AboutNote(title: "A new Journal page", body: "The page works like Apple's Journal, with bookmarks and a month and year view."),
            AboutNote(title: "Feedback loops", body: "Draw a loop or a free map from a template, and share it as a picture or a PDF."),
        ]),
    ]

    /// For example "Version 1.0 (1)". Falls back to the version alone.
    static var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        if version.isEmpty { return "Version not available" }
        return build.isEmpty ? "Version \(version)" : "Version \(version) (\(build))"
    }

    /// The device model as the system names it, such as iPhone15,2.
    static var deviceModel: String {
        var system = utsname()
        uname(&system)
        return Mirror(reflecting: system.machine).children.reduce("") { text, element in
            guard let value = element.value as? Int8, value != 0 else { return text }
            return text + String(UnicodeScalar(UInt8(truncatingIfNeeded: value)))
        }
    }

    /// A mail link that starts with the app version, the iOS version and the
    /// device model, and nothing else about the person.
    static var supportMailURL: URL? {
        let body = "\n\n\nAnchor \(versionLine.replacingOccurrences(of: "Version ", with: ""))\n"
            + "iOS \(UIDevice.current.systemVersion)\n"
            + "\(deviceModel)\n"
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = supportEmail
        parts.queryItems = [
            URLQueryItem(name: "subject", value: "Anchor support"),
            URLQueryItem(name: "body", value: body),
        ]
        return parts.url
    }
}

struct AboutView: View {
    @State private var copiedEmail = false

    var body: some View {
        Form {
            Anchor.SettingsSection(title: nil) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Anchor").font(.system(.title2, design: .rounded).weight(.semibold))
                    Text(AboutContent.versionLine).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Anchor.SettingsSection(title: "About Anchor") {
                Text(AboutContent.purpose).font(.system(.subheadline, design: .rounded))
                ForEach(AboutContent.principles, id: \.self) { line in
                    Text(line).font(.system(.subheadline, design: .rounded))
                }
            }

            Anchor.SettingsSection(title: "Get in touch", footer: AboutContent.contactNote) {
                if let url = AboutContent.supportMailURL {
                    Link(destination: url) {
                        aboutRowLabel("Email support", systemImage: "envelope")
                    }
                }
                Button {
                    UIPasteboard.general.string = AboutContent.supportEmail
                    copiedEmail = true
                } label: {
                    aboutRowLabel(copiedEmail ? "Copied" : "Copy \(AboutContent.supportEmail)", systemImage: "doc.on.doc")
                }
                .foregroundStyle(.primary)
            }

            Anchor.SettingsSection(title: "Links") {
                aboutLink("Website", AboutContent.websiteURL)
                aboutLink("Privacy policy", AboutContent.privacyURL)
                aboutLink("Source code on GitHub", AboutContent.sourceURL)
            }

            Anchor.SettingsSection(title: "Licences") {
                Text(AboutContent.licences).font(.system(.subheadline, design: .rounded))
            }

            Anchor.SettingsSection(title: nil) {
                NavigationLink {
                    WhatsNewView()
                } label: {
                    Text("What's new").font(.system(.subheadline, design: .rounded))
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .guideButton("settings.about")
    }

    @ViewBuilder
    private func aboutLink(_ title: String, _ address: String) -> some View {
        if let url = URL(string: address) {
            Link(destination: url) {
                aboutRowLabel(title, systemImage: "arrow.up.right")
            }
        }
    }

    private func aboutRowLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Text(title).font(.system(.subheadline, design: .rounded))
            Spacer(minLength: 12)
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
}

struct WhatsNewView: View {
    /// The newest version starts open, the rest folded.
    @State private var open: Set<String> = Set(AboutContent.versions.prefix(1).map(\.id))

    var body: some View {
        Form {
            ForEach(AboutContent.versions) { version in
                Anchor.SettingsSection(title: nil) {
                    DisclosureGroup(isExpanded: expanded(version.id)) {
                        group("Added", version.added)
                        group("Changed", version.changed)
                        group("Removed", version.removed)
                    } label: {
                        Text("Version \(version.version)")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                    }
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("What's new")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func expanded(_ id: String) -> Binding<Bool> {
        Binding(
            get: { open.contains(id) },
            set: { isOpen in
                if isOpen { open.insert(id) } else { open.remove(id) }
            }
        )
    }

    @ViewBuilder
    private func group(_ title: String, _ notes: [AboutNote]) -> some View {
        if !notes.isEmpty {
            Text(title)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(notes) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.system(.subheadline, design: .rounded).weight(.medium))
                    Text(item.body).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Encryption: the data key and the recovery key
//
// Patch 34. Reached only from test builds for now; Patch 35 locks the stored text
// with this key and opens the screen to everyone.

private struct ShownRecoveryKey: Identifiable {
    let id = UUID()
    let text: String
}

private enum KeyEntryKind: Identifiable {
    case check
    case restore

    var id: Self { self }
}

private func keyMessage(for error: Error) -> String {
    switch (error as? DataKeyError) ?? .storage {
    case .notARecoveryKey: return "That is not a whole recovery key. Check it against what you wrote down."
    case .wrongRecoveryKey: return "That recovery key does not match."
    case .damagedFile: return "The recovery file is damaged."
    case .noRecoveryFile: return "The recovery file is not on this device."
    case .otherKey: return "The recovery file was made for a different key."
    case .noKey: return "There is no key on this device."
    case .alreadySetUp: return "A key is already here."
    case .storage: return "That could not be saved. Try again."
    }
}

struct EncryptionSettingsView: View {
    @StateObject private var keys = DataKeyManager.shared
    @State private var shownKey: ShownRecoveryKey?
    @State private var entryKind: KeyEntryKind?
    @State private var resultLine: String?
    @State private var confirmRemove = false

    private var statusText: String {
        switch keys.status {
        case .notSetUp: return "Not made yet"
        case .ready: return "On this device"
        case .needsRecovery: return "Not on this device"
        case .unavailable: return "Cannot be read right now"
        }
    }

    var body: some View {
        Form {
            Anchor.SettingsSection(title: "Data key", footer: "Stored text is not locked with this key yet.") {
                keyRow("Data key", statusText)
                if keys.status == .notSetUp {
                    Button {
                        makeKey()
                    } label: {
                        rowText("Make a key and a recovery key")
                    }
                }
                if keys.status == .needsRecovery {
                    Button {
                        entryKind = .restore
                    } label: {
                        rowText("Restore with your recovery key")
                    }
                }
            }

            if keys.status == .ready || keys.hasRecoveryFile {
                Anchor.SettingsSection(title: "Recovery key") {
                    keyRow("Recovery file", keys.hasRecoveryFile ? "Kept with your data" : "Missing")
                    if keys.hasRecoveryFile {
                        Button {
                            entryKind = .check
                        } label: {
                            rowText("Check my recovery key")
                        }
                    }
                    if keys.status == .ready {
                        Button {
                            makeNewRecoveryKey()
                        } label: {
                            rowText("Make a new recovery key")
                        }
                    }
                }
            }

            if let resultLine {
                Anchor.SettingsSection(title: nil) {
                    Text(resultLine).font(.system(.subheadline, design: .rounded))
                }
            }

            #if DEBUG
            Anchor.SettingsSection(title: "Test build only") {
                Button(role: .destructive) {
                    confirmRemove = true
                } label: {
                    rowText("Remove the key and the recovery file")
                }
            }
            #endif
        }
        .anchorSettingsStyle()
        .navigationTitle("Encryption")
        .navigationBarTitleDisplayMode(.inline)
        .guideButton("settings.encryption")
        .onAppear {
            keys.refresh()
            #if DEBUG
            DataKeySelfTest.run()
            #endif
        }
        .sheet(item: $shownKey) { shown in
            RecoveryKeyShownSheet(text: shown.text)
        }
        .sheet(item: $entryKind) { kind in
            switch kind {
            case .check:
                RecoveryKeyEntrySheet(title: "Check recovery key", buttonTitle: "Check") { typed in
                    do {
                        try keys.checkRecoveryKey(typed)
                        resultLine = "That recovery key opens your recovery file."
                        return nil
                    } catch {
                        return keyMessage(for: error)
                    }
                }
            case .restore:
                RecoveryKeyEntrySheet(title: "Restore the key", buttonTitle: "Restore") { typed in
                    do {
                        try keys.restore(with: typed)
                        resultLine = "The key is back on this device."
                        return nil
                    } catch {
                        return keyMessage(for: error)
                    }
                }
            }
        }
        .confirmationDialog("Remove the key and the recovery file?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                #if DEBUG
                keys.removeEverything()
                resultLine = nil
                #endif
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func keyRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(.subheadline, design: .rounded))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func rowText(_ title: String) -> some View {
        Text(title).font(.system(.subheadline, design: .rounded))
    }

    @MainActor
    private func makeKey() {
        resultLine = nil
        do {
            let text = try keys.setUp()
            shownKey = ShownRecoveryKey(text: text)
        } catch {
            resultLine = keyMessage(for: error)
        }
    }

    @MainActor
    private func makeNewRecoveryKey() {
        resultLine = nil
        Task {
            let present = await AppLock.shared.confirmPresence(reason: "Make a new recovery key for Anchor.")
            guard present else { return }
            do {
                let text = try keys.makeNewRecoveryKey()
                shownKey = ShownRecoveryKey(text: text)
            } catch {
                resultLine = keyMessage(for: error)
            }
        }
    }
}

/// The recovery key, once. It cannot be closed until the last four characters are typed
/// back, so a key is not lost to a stray swipe.
private struct RecoveryKeyShownSheet: View {
    let text: String

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var copied = false

    private var lastGroup: String { String(text.suffix(4)) }

    private var isConfirmed: Bool {
        RecoveryKeyText.canonical(typed) == RecoveryKeyText.canonical(lastGroup)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("This is the only time your recovery key is shown. Write it down, or keep it somewhere safe that is not on this phone.")
                        .font(.system(.subheadline, design: .rounded))

                    Text(text)
                        .font(.system(.title3, design: .monospaced).weight(.medium))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )

                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.setItems(
                                [["public.utf8-plain-text": text]],
                                options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]
                            )
                            copied = true
                        } label: {
                            Label(copied ? "Copied for 2 minutes" : "Copy", systemImage: "doc.on.doc")
                        }
                        ShareLink(item: text) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("To check you have it, type the last four characters.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextField("Last four characters", text: $typed)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }
                .padding(20)
            }
            .navigationTitle("Your recovery key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(!isConfirmed)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}

/// Asks for a recovery key. The action returns text to show when it fails, or nil when it
/// worked and the sheet can close.
private struct RecoveryKeyEntrySheet: View {
    let title: String
    let buttonTitle: String
    let action: (String) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Recovery key", text: $typed, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    if let errorText {
                        Text(errorText).font(.footnote).foregroundStyle(.red)
                    }
                }
                Section {
                    Button(buttonTitle) {
                        if let failure = action(typed) {
                            errorText = failure
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(typed.isEmpty)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// AI tools in Settings (Patch AI0): the one switch for every AI feature. Off to begin with. Nothing sits
/// behind it yet, so the row is in test builds only until the first AI tool is built; the rules it
/// carries are in docs/OPTIONAL_FEATURES.md.
struct AIToolsSettingsView: View {
    @State private var isOn = AIGate.isChosen

    var body: some View {
        Form {
            Anchor.SettingsSection(
                title: "AI tools",
                footer: DemoMode.isOn
                    ? "Off while showcase mode is on."
                    : "Off to begin with. While it is off, nothing in Anchor uses AI and no AI buttons show anywhere."
            ) {
                Toggle(isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        isOn = newValue
                        AIGate.setChosen(newValue)
                    }
                )) {
                    Text("Use AI tools")
                        .font(.system(.subheadline, design: .rounded))
                }
                .disabled(DemoMode.isOn)
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("AI tools")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HelpNoteToolbarButton(icon: "slider.horizontal.3", title: "About AI tools", paragraphs: AIToolsHelp.paragraphs)
            }
        }
    }
}

/// Showcase mode in Settings (Patch 40b). Turning it on swaps the app to made-up content and makes the
/// window again, which closes this screen. While it is on, the same screen only offers to turn it off,
/// with the showcase passcode if one is set or with the phone's own Face ID or passcode, which always
/// works. What it does is explained in the help sheet and in docs/SHOWCASE.md.
struct ShowcaseSettingsView: View {
    @ObservedObject private var holder = ContainerHolder.shared
    @State private var confirmOn = false
    @State private var showExit = false
    @State private var showSetPasscode = false
    @State private var passcodeIsSet = ShowcasePasscode.isSet
    @State private var message: String?

    var body: some View {
        Form {
            if ShowcaseMode.isOn {
                Anchor.SettingsSection(title: "Showcase mode") {
                    Text("On. You are looking at made-up content.")
                        .font(.system(.subheadline, design: .rounded))
                    Button {
                        showExit = true
                    } label: {
                        Text("Turn off showcase mode")
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
            } else {
                Anchor.SettingsSection(
                    title: "Showcase mode",
                    footer: "Shows made-up content in place of yours, so you can show someone the app."
                ) {
                    Text("Off.")
                        .font(.system(.subheadline, design: .rounded))
                    Button {
                        if ShowcaseMode.canTurnOn {
                            confirmOn = true
                        } else {
                            message = "This phone has no passcode or Face ID, so there would be no way back out. Set one first."
                        }
                    } label: {
                        Text("Turn on showcase mode")
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
                Anchor.SettingsSection(
                    title: "Showcase passcode",
                    footer: "A passcode only for showing the app. Your phone's Face ID or passcode turns showcase mode off as well."
                ) {
                    if passcodeIsSet {
                        Text("Set")
                            .font(.system(.subheadline, design: .rounded))
                        Button {
                            changePasscode()
                        } label: {
                            Text("Change passcode")
                                .font(.system(.subheadline, design: .rounded))
                        }
                        Button(role: .destructive) {
                            removePasscode()
                        } label: {
                            Text("Remove passcode")
                                .font(.system(.subheadline, design: .rounded))
                        }
                    } else {
                        Text("Not set")
                            .font(.system(.subheadline, design: .rounded))
                        Button {
                            showSetPasscode = true
                        } label: {
                            Text("Set a passcode")
                                .font(.system(.subheadline, design: .rounded))
                        }
                    }
                }
            }
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Showcase mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HelpNoteToolbarButton(icon: "rectangle.on.rectangle", title: "About showcase mode", paragraphs: ShowcaseHelp.paragraphs)
            }
        }
        .confirmationDialog("Turn on showcase mode?", isPresented: $confirmOn, titleVisibility: .visible) {
            Button("Turn on") {
                if !holder.enterShowcase() {
                    message = "Showcase mode could not start, so nothing was changed."
                }
            }
            if !passcodeIsSet {
                Button("Set a passcode first") { showSetPasscode = true }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(passcodeIsSet
                 ? "Anchor will show made-up content until you turn this off with your showcase passcode or your phone's Face ID or passcode."
                 : "Anchor will show made-up content until you turn this off with your phone's Face ID or passcode. You can set a showcase passcode first.")
        }
        .sheet(isPresented: $showSetPasscode) {
            ShowcasePasscodeSetView {
                passcodeIsSet = ShowcasePasscode.isSet
            }
        }
        .sheet(isPresented: $showExit) {
            ShowcaseExitView()
        }
    }

    /// Changing or removing the passcode asks for the phone's own Face ID or passcode first, so
    /// someone holding the phone in a showcase cannot swap it.
    private func changePasscode() {
        message = nil
        Task {
            let confirmed = await ShowcaseMode.confirmOwner(reason: "Change the passcode for showcase mode.")
            if confirmed {
                showSetPasscode = true
            } else {
                message = "Nothing was changed."
            }
        }
    }

    private func removePasscode() {
        message = nil
        Task {
            let confirmed = await ShowcaseMode.confirmOwner(reason: "Remove the passcode for showcase mode.")
            if confirmed {
                ShowcasePasscode.remove()
                passcodeIsSet = ShowcasePasscode.isSet
            } else {
                message = "Nothing was changed."
            }
        }
    }
}

/// Setting or changing the showcase passcode: 4 to 6 digits on the number pad, typed twice.
struct ShowcasePasscodeSetView: View {
    @Environment(\.dismiss) private var dismiss
    let onSaved: () -> Void
    @State private var first = ""
    @State private var second = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Anchor.SettingsSection(title: "New passcode", footer: "4 to 6 digits.") {
                    SecureField("Passcode", text: $first)
                        .keyboardType(.numberPad)
                        .onChange(of: first) { _, new in
                            let kept = ShowcasePasscode.digits(new)
                            if kept != new { first = kept }
                        }
                    SecureField("Type it again", text: $second)
                        .keyboardType(.numberPad)
                        .onChange(of: second) { _, new in
                            let kept = ShowcasePasscode.digits(new)
                            if kept != new { second = kept }
                        }
                }
                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Showcase passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(first.isEmpty || second.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard first.count >= ShowcasePasscode.minimumLength else {
            error = "Use 4 to 6 digits."
            return
        }
        guard first == second else {
            error = "The two did not match."
            return
        }
        do {
            try ShowcasePasscode.set(first)
            onSaved()
            dismiss()
        } catch {
            self.error = "The passcode could not be saved."
        }
    }
}

/// The way out of showcase mode: the showcase passcode if one is set, or always the phone's own
/// Face ID or passcode. The phone's one is asked directly, not through Anchor's own lock, which is
/// not asked for while showcase mode is on.
struct ShowcaseExitView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var holder = ContainerHolder.shared
    @State private var attempt = ""
    @State private var message: String?
    @State private var isWorking = false
    private let hasPasscode = ShowcasePasscode.isSet

    var body: some View {
        NavigationStack {
            Form {
                if hasPasscode {
                    Anchor.SettingsSection(title: "Showcase passcode") {
                        SecureField("Passcode", text: $attempt)
                            .keyboardType(.numberPad)
                        Button {
                            tryPasscode()
                        } label: {
                            Text("Turn off showcase mode")
                                .font(.system(.subheadline, design: .rounded))
                        }
                        .disabled(attempt.isEmpty || isWorking)
                    }
                }
                Anchor.SettingsSection(title: hasPasscode ? "Or use your phone" : "Turn off showcase mode") {
                    Button {
                        useDevice()
                    } label: {
                        Text("Use Face ID or the phone's passcode")
                            .font(.system(.subheadline, design: .rounded))
                    }
                    .disabled(isWorking)
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Turn off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func tryPasscode() {
        guard !attempt.isEmpty, !isWorking else { return }
        switch ShowcasePasscode.check(attempt) {
        case .correct:
            holder.leaveShowcase()
        case .wrong:
            attempt = ""
            message = "That is not the passcode."
        case .wait(let seconds):
            attempt = ""
            message = "Too many tries. Wait \(Self.waitText(seconds)), or use Face ID or the phone's passcode."
        case .unavailable:
            attempt = ""
            message = "The passcode could not be read. Use Face ID or the phone's passcode."
        }
    }

    private func useDevice() {
        isWorking = true
        message = nil
        Task {
            let confirmed = await ShowcaseMode.confirmOwner(reason: "Turn off showcase mode and go back to your own content.")
            isWorking = false
            if confirmed {
                holder.leaveShowcase()
            } else {
                message = "Showcase mode is still on."
            }
        }
    }

    private static func waitText(_ seconds: Int) -> String {
        seconds < 90 ? "\(seconds) seconds" : "\((seconds + 59) / 60) minutes"
    }
}
