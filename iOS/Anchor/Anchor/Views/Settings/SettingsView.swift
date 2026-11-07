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

    /// Recovery is optional and discreet: its settings only appear once the
    /// user has a counter (or already has a recovery reminder switched on, so
    /// it can always be turned back off).
    private var showsRecovery: Bool {
        allCounters.contains { !$0.isArchived } || pledgeEnabled || reviewEnabled || milestonesEnabled
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
