//
//  PlanView.swift
//  Anchor
//

import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [SafetyPlan]
    @Query private var appointmentSeries: [AppointmentSeries]
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]
    @Query private var triggerWindows: [TriggerWindow]
    @Query(sort: \DeEscalationScript.sortOrder) private var deEscalationScripts: [DeEscalationScript]
    @Query(sort: \Affirmation.sortOrder) private var affirmations: [Affirmation]

    @StateObject private var appLock = AppLock.shared
    @State private var showTourAgain = false
    @State private var dailyCheckInEnabled = UserDefaults.standard.bool(forKey: "anchor.dailyCheckIn.enabled")
    @State private var dailyCheckInTime: Date = {
        let defaults = UserDefaults.standard
        let hour = defaults.object(forKey: "anchor.dailyCheckIn.hour") as? Int ?? 20
        let minute = defaults.object(forKey: "anchor.dailyCheckIn.minute") as? Int ?? 0
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Anchor.TileRow(title: "Safety & people") {
                        NavigationLink { ContactsEditorView() } label: {
                            Anchor.TileButtonLabel(icon: "person.2.fill", title: "Contacts", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { SafetyPlanEditorView(plan: currentPlan) } label: {
                            Anchor.TileButtonLabel(icon: "shield.fill", title: "Safety plan", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { TriggerWindowListView() } label: {
                            Anchor.TileButtonLabel(icon: "clock.fill", title: "Trigger windows", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { AppointmentView(series: currentAppointmentSeries) } label: {
                            Anchor.TileButtonLabel(icon: "calendar", title: "Appointments", tint: Anchor.Theme.sage)
                        }
                    }

                    Anchor.TileRow(title: "Presets & tools") {
                        NavigationLink { GroundingToolsEditorView() } label: {
                            Anchor.TileButtonLabel(icon: "leaf.fill", title: "Grounding tools", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { DecisionFatigueView() } label: {
                            Anchor.TileButtonLabel(icon: "checklist", title: "Decision presets", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { DeEscalationScriptsEditorView() } label: {
                            Anchor.TileButtonLabel(icon: "wind", title: "De-escalation", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { AffirmationsEditorView() } label: {
                            Anchor.TileButtonLabel(icon: "sparkles", title: "Affirmations", tint: Anchor.Theme.accent)
                        }
                    }

                    Anchor.TileRow(title: "Data") {
                        NavigationLink { DataControlView() } label: {
                            Anchor.TileButtonLabel(icon: "externaldrive.fill", title: "Your data", tint: Anchor.Theme.accent)
                        }
                    }

                    // Genuine on/off settings stay as compact inline
                    // controls rather than their own tiles — these are
                    // toggles to flip, not features to "go to," so turning
                    // them into tap-a-tile-then-toggle would just add a
                    // step. Kept as one small card, not a Settings-style
                    // list or a separate menu.
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 14) {
                            Anchor.SectionHeader(icon: "gearshape.fill", title: "Preferences", tint: Anchor.Theme.sage)

                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: Binding(
                                    get: { appLock.isEnabled },
                                    set: { appLock.isEnabled = $0 }
                                )) {
                                    Text("Require Face ID").font(.system(.subheadline, design: .rounded))
                                }
                                .tint(Anchor.Theme.accent)
                                Text(appLock.canAuthenticate()
                                     ? "Locks Anchor independently of your phone's own lock."
                                     : "This device doesn't have Face ID, Touch ID, or a passcode set up.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: $dailyCheckInEnabled) {
                                    Text("Daily check-in").font(.system(.subheadline, design: .rounded))
                                }
                                .tint(Anchor.Theme.accent)
                                .onChange(of: dailyCheckInEnabled) { _, _ in applyDailyCheckInSchedule() }

                                if dailyCheckInEnabled {
                                    DatePicker("Time", selection: $dailyCheckInTime, displayedComponents: .hourAndMinute)
                                        .onChange(of: dailyCheckInTime) { _, _ in applyDailyCheckInSchedule() }
                                }
                                Text("A gentle, optional nudge once a day. Totally fine to skip when it comes.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            Button {
                                showTourAgain = true
                            } label: {
                                Text("Replay the tour")
                                    .font(.system(.subheadline, design: .rounded))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }
            .anchorBackground()
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HelpToolbarButton(topic: .plan)
                }
            }
            .sheet(isPresented: $showTourAgain) {
                OnboardingTourView()
            }
            .onAppear {
                NotificationScheduler.registerCategories()
                // No permission prompt here: Anchor asks the first time the user turns on
                // something that needs notifications (see NotificationScheduler.askForPermissionIfNeeded).
                let scheduler = NotificationScheduler(context: modelContext)
                refreshWidgetSnapshot()
                rescheduleTriggerWindowNotifications(using: scheduler)
                if dailyCheckInEnabled {
                    applyDailyCheckInSchedule()
                }
            }
        }
    }

    private func applyDailyCheckInSchedule() {
        UserDefaults.standard.set(dailyCheckInEnabled, forKey: "anchor.dailyCheckIn.enabled")
        let components = Calendar.current.dateComponents([.hour, .minute], from: dailyCheckInTime)
        let hour = components.hour ?? 20
        let minute = components.minute ?? 0
        UserDefaults.standard.set(hour, forKey: "anchor.dailyCheckIn.hour")
        UserDefaults.standard.set(minute, forKey: "anchor.dailyCheckIn.minute")

        let scheduler = NotificationScheduler(context: modelContext)
        if dailyCheckInEnabled {
            scheduler.scheduleDailyCheckIn(hour: hour, minute: minute)
        } else {
            scheduler.cancelDailyCheckIn()
        }
    }

    /// Re-syncs every active trigger window's local notification, including
    /// escalation reminders for opted-in contacts. Simple "clear and
    /// re-add" rather than diffing — cheap enough at this scale, and
    /// guarantees the schedule always matches what's currently in Plan.
    private func rescheduleTriggerWindowNotifications(using scheduler: NotificationScheduler) {
        let reasons = currentPlan.reasonsToKeepGoingText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
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
            hasSafetyPlan: !plans.isEmpty,
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

    private var currentPlan: SafetyPlan {
        if let existing = plans.first { return existing }
        let new = SafetyPlan()
        modelContext.insert(new)
        return new
    }

    private var currentAppointmentSeries: AppointmentSeries {
        if let existing = appointmentSeries.first { return existing }
        let new = AppointmentSeries(clinicianLabel: "Psych")
        modelContext.insert(new)
        return new
    }
}
