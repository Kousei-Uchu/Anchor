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

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Anchor.TileRow(title: "Safety & people") {
                        NavigationLink { ContactsView() } label: {
                            Anchor.TileButtonLabel(icon: "person.2.fill", title: "Contacts", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { SafetyPlanView(plan: currentPlan) } label: {
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
                        NavigationLink { GroundingToolsListView() } label: {
                            Anchor.TileButtonLabel(icon: "leaf.fill", title: "Grounding tools", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { DecisionFatigueView() } label: {
                            Anchor.TileButtonLabel(icon: "checklist", title: "Decision presets", tint: Anchor.Theme.accent)
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
                let scheduler = NotificationScheduler(context: modelContext)
                refreshWidgetSnapshot()
                rescheduleTriggerWindowNotifications(using: scheduler)
                // Keeps the daily check-in notification alive; the toggle itself lives in Settings.
                DailyCheckInSettings.reapplyIfEnabled(using: modelContext)
            }
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
