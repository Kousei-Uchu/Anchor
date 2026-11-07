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

    @StateObject private var appLock = AppLock.shared
    @State private var faceIDEnabled = AppLock.shared.isEnabled
    @State private var showTour = false

    @AppStorage(DailyCheckInSettings.enabledKey) private var dailyCheckInEnabled = false
    @AppStorage(DailyCheckInSettings.hourKey) private var dailyCheckInHour = 20
    @AppStorage(DailyCheckInSettings.minuteKey) private var dailyCheckInMinute = 0

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
                    footer: "A gentle, optional nudge once a day. Totally fine to skip when it comes."
                ) {
                    Anchor.SettingsToggle(title: "Daily check-in", isOn: $dailyCheckInEnabled)
                    if dailyCheckInEnabled {
                        Anchor.SettingsTimeRow(time: timeBinding($dailyCheckInHour, $dailyCheckInMinute))
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
