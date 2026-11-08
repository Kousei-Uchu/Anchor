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

                if showsRecovery {
                    Anchor.SettingsSection(
                        title: "Recovery",
                        footer: "Reminders and widgets use generic wording, like \"A quiet moment for yourself?\", so nobody reading your lock screen learns what you're tracking. You can show a counter's name outside the app by turning that on for the counter."
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
                        Text("Replay the tour")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("About Anchor").font(.system(.subheadline, design: .rounded))
                    }
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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

    static let whatsNew: [AboutNote] = [
        AboutNote(title: "Sleep journal", body: "An optional sleep journal under Plan, with Apple Health if you want it. Nothing is scored."),
        AboutNote(title: "Export for someone", body: "Choose who it is for and what goes in, then make a PDF or a web page to share."),
        AboutNote(title: "Look at what's stored", body: "See everything Anchor holds, behind Face ID or your passcode, in plain language."),
        AboutNote(title: "Tasks and routines", body: "Tasks with steps, a focus timer, Plan my day, quick lists, routines and checklists."),
        AboutNote(title: "People and providers", body: "A page for each person in Thread, and more than one provider in Bridge."),
        AboutNote(title: "Sections of your own", body: "The safety plan and the Boundaries list are sections you rename, reorder and hide."),
        AboutNote(title: "A new Journal page", body: "The page works like Apple's Journal, with bookmarks and a month and year view."),
        AboutNote(title: "Feedback loops", body: "Draw a loop or a free map from a template, and share it as a picture or a PDF."),
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
    var body: some View {
        Form {
            Anchor.SettingsSection(title: nil) {
                ForEach(AboutContent.whatsNew) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.system(.subheadline, design: .rounded).weight(.medium))
                        Text(item.body).font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("What's new")
        .navigationBarTitleDisplayMode(.inline)
    }
}
