//
//  NotificationScheduler.swift
//  Anchor
//
//  All notification bodies come from one of two places: a fixed template
//  string written in this file (reviewed, shipped with the app) with a
//  stored SafetyPlan/Journal/Thread quote slotted into it, or the raw
//  stored text itself. Nothing here ever asks a model to write a sentence.
//  "Context-aware" means the *selection* of which stored quote to surface
//  can be smart — the words themselves are always the user's own.
//

import Foundation
import UserNotifications
import SwiftData

enum NotificationCategory: String {
    case triggerWindow = "ANCHOR_TRIGGER_WINDOW"
    case appointmentReminder = "ANCHOR_APPOINTMENT_REMINDER"
    case escalationCheckIn = "ANCHOR_ESCALATION_CHECKIN"
    case dailyCheckIn = "ANCHOR_DAILY_CHECKIN"
}

@MainActor
struct NotificationScheduler {
    let context: ModelContext

    /// Registers the actionable categories (one-tap contact / "I'm okay" /
    /// open app) so notifications can be acted on without opening the app.
    static func registerCategories() {
        let contactAction = UNNotificationAction(identifier: "CONTACT", title: "Message a contact", options: [.foreground])
        let okAction = UNNotificationAction(identifier: "IM_OKAY", title: "I'm okay", options: [])
        let openAction = UNNotificationAction(identifier: "OPEN", title: "Open Anchor", options: [.foreground])
        let checkInNowAction = UNNotificationAction(identifier: "CHECKIN_NOW", title: "Check in now", options: [.foreground])

        let triggerCategory = UNNotificationCategory(
            identifier: NotificationCategory.triggerWindow.rawValue,
            actions: [contactAction, okAction, openAction],
            intentIdentifiers: []
        )
        let appointmentCategory = UNNotificationCategory(
            identifier: NotificationCategory.appointmentReminder.rawValue,
            actions: [openAction],
            intentIdentifiers: []
        )
        let escalationCategory = UNNotificationCategory(
            identifier: NotificationCategory.escalationCheckIn.rawValue,
            actions: [okAction, contactAction],
            intentIdentifiers: []
        )
        let dailyCheckInCategory = UNNotificationCategory(
            identifier: NotificationCategory.dailyCheckIn.rawValue,
            actions: [checkInNowAction, okAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories(
            [triggerCategory, appointmentCategory, escalationCategory, dailyCheckInCategory]
        )
    }

    /// Schedules a repeating local notification for a trigger window, plus
    /// (for any contact with escalationEnabled) a follow-up "escalation"
    /// reminder offset by that contact's window in minutes.
    ///
    /// IMPORTANT LIMIT, stated plainly rather than papered over: iOS does
    /// not allow an app to silently send an SMS in the background. The
    /// escalation notification cannot auto-message a contact by itself —
    /// what it *can* do, and what this does, is remind the user at the
    /// escalation deadline and put "Message a contact" one tap away. If the
    /// user taps "I'm okay" (or opens the app) before the escalation fires,
    /// it's cancelled and the contact is never notified at all — matching
    /// "opt-in per contact, not automatic."
    func scheduleTriggerWindow(_ window: TriggerWindow, reasonsPool: [String],
                                escalationContacts: [TrustedContact], primaryContact: TrustedContact?) {
        guard window.isActive, let startHour = window.startTime.hour, let startMinute = window.startTime.minute else { return }
        // Safety net: scheduling means the user has a reminder set up, so make sure we've asked.
        Self.askForPermissionIfNeeded()

        let body = templatedBody(reasonsPool: reasonsPool)

        for weekday in window.daysOfWeek {
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = startHour
            dateComponents.minute = startMinute

            let escalationIDs = escalationContacts.compactMap { contact -> String? in
                guard let minutes = contact.escalationWindowMinutes else { return nil }
                return escalationIdentifier(windowID: window.id, weekday: weekday, contactID: contact.id, minutes: minutes)
            }

            let content = UNMutableNotificationContent()
            content.title = window.label
            content.body = body
            content.categoryIdentifier = NotificationCategory.triggerWindow.rawValue
            content.sound = .default
            content.userInfo = [
                "escalationIdentifiers": escalationIDs,
                "contactName": primaryContact?.name ?? "",
                "contactPhone": primaryContact?.phoneNumber ?? ""
            ]

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "trigger-\(window.id.uuidString)-\(weekday)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)

            for contact in escalationContacts {
                guard let minutes = contact.escalationWindowMinutes else { continue }
                scheduleEscalation(windowLabel: window.label, weekday: weekday, hour: startHour, minute: startMinute,
                                    minutesAfter: minutes, windowID: window.id, contact: contact)
            }
        }
    }

    /// The escalation reminder itself — fires `minutesAfter` past the
    /// trigger window's start, only if not cancelled by an "I'm okay"/open
    /// response to the original notification.
    private func scheduleEscalation(windowLabel: String, weekday: Int, hour: Int, minute: Int,
                                     minutesAfter: Int, windowID: UUID, contact: TrustedContact) {
        var dateComponents = DateComponents()
        dateComponents.weekday = weekday

        let totalMinutes = hour * 60 + minute + minutesAfter
        dateComponents.hour = (totalMinutes / 60) % 24
        dateComponents.minute = totalMinutes % 60

        let content = UNMutableNotificationContent()
        content.title = "Still there?"
        content.body = "You didn't respond to the \(windowLabel) check-in. Want to let \(contact.name) know you're okay?"
        content.categoryIdentifier = NotificationCategory.escalationCheckIn.rawValue
        content.sound = .default
        content.userInfo = ["contactName": contact.name, "contactPhone": contact.phoneNumber]

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: escalationIdentifier(windowID: windowID, weekday: weekday, contactID: contact.id, minutes: minutesAfter),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func escalationIdentifier(windowID: UUID, weekday: Int, contactID: UUID, minutes: Int) -> String {
        "escalation-\(windowID.uuidString)-\(weekday)-\(contactID.uuidString)-\(minutes)"
    }

    /// Cancels any pending escalation reminders tied to a delivered trigger-
    /// window notification — called from NotificationDelegate when the user
    /// taps "I'm okay" or opens the app from that notification.
    static func cancelEscalations(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Fixed, reviewed templates. The only variable slotted in is the
    /// user's own previously-written text — nothing about sentence
    /// structure is generated per-notification. Several phrasings exist
    /// so a daily/weekly repeating notification doesn't read identically
    /// every single time; the *set* of possible sentences is fixed and
    /// reviewed, only which one gets picked (and which stored quote fills
    /// the blank) varies.
    private func templatedBody(reasonsPool: [String]) -> String {
        guard let quote = reasonsPool.filter({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }).randomElement() else {
            return "Checking in. No pressure to respond."
        }
        let templates: [(String) -> String] = [
            { quote in "You wrote: \u{201C}\(quote)\u{201D}" },
            { quote in "From your safety plan: \u{201C}\(quote)\u{201D}" },
            { quote in "A reminder, in your own words: \u{201C}\(quote)\u{201D}" },
            { quote in "Something you told yourself: \u{201C}\(quote)\u{201D}" }
        ]
        return templates.randomElement()!(quote)
    }

    func removeTriggerWindowNotifications(for window: TriggerWindow) {
        let triggerIdentifiers = window.daysOfWeek.map { "trigger-\(window.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: triggerIdentifiers)

        let escalationPrefix = "escalation-\(window.id.uuidString)-"
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let escalationIdentifiers = requests.map(\.identifier).filter { $0.hasPrefix(escalationPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: escalationIdentifiers)
        }
    }

    /// Two reminders per appointment now, not one: the existing day-before
    /// nudge to prep in Bridge, plus a same-day reminder a couple of hours
    /// out — appointments getting missed or arrived at unprepared were
    /// both real risks a single 20-hours-out reminder didn't cover well.
    func scheduleAppointmentReminder(for occurrence: AppointmentOccurrence, clinicianLabel: String) {
        Self.askForPermissionIfNeeded()
        scheduleSingleAppointmentReminder(
            for: occurrence, clinicianLabel: clinicianLabel,
            hoursBefore: 20, identifierSuffix: "day-before",
            body: "Your session is tomorrow. Want to jot anything down for it in Bridge?"
        )
        scheduleSingleAppointmentReminder(
            for: occurrence, clinicianLabel: clinicianLabel,
            hoursBefore: 2, identifierSuffix: "same-day",
            body: "Your session is in a couple of hours."
        )
    }

    private func scheduleSingleAppointmentReminder(for occurrence: AppointmentOccurrence, clinicianLabel: String,
                                                    hoursBefore: Int, identifierSuffix: String, body: String) {
        guard let reminderDate = Calendar.current.date(byAdding: .hour, value: -hoursBefore, to: occurrence.scheduledDate),
              reminderDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming: \(clinicianLabel)"
        content.body = body
        content.categoryIdentifier = NotificationCategory.appointmentReminder.rawValue
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(
            identifier: "appointment-\(occurrence.id.uuidString)-\(identifierSuffix)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// A daily, non-crisis-specific check-in — separate from trigger
    /// windows, which are about specific known risk periods. This is just
    /// "want to check in today?" at a time the user picks in Plan, so
    /// Anchor is proactive even on days nothing's scheduled to fire.
    func scheduleDailyCheckIn(hour: Int, minute: Int) {
        Self.askForPermissionIfNeeded()   // the user just turned the daily check-in on
        cancelDailyCheckIn()
        let content = UNMutableNotificationContent()
        content.title = "Anchor"
        content.body = "Want to check in today? Totally fine to skip."
        content.categoryIdentifier = NotificationCategory.dailyCheckIn.rawValue
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-checkin", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelDailyCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-checkin"])
    }

    /// Asks for notification permission. Call this at the moment the user first
    /// turns on something that needs notifications (an active trigger window,
    /// the daily check-in, or contact escalation), never on launch or when a
    /// tab merely appears. iOS only shows the prompt once; later calls are no-ops.
    static func askForPermissionIfNeeded() {
        // Demo mode (screenshots and the website video) never asks, so the
        // system permission alert can't appear in the footage.
        guard !DemoMode.isOn else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func requestAuthorizationIfNeeded() { Self.askForPermissionIfNeeded() }
}

extension NotificationScheduler {
    /// Re-syncs every trigger window's notification (clear and re-add), the same way Plan does
    /// when it appears. Used when a window is created somewhere other than Plan, so it takes
    /// effect straight away instead of the next time Plan opens.
    static func resyncTriggerWindows(using context: ModelContext) {
        let scheduler = NotificationScheduler(context: context)
        let windows = (try? context.fetch(FetchDescriptor<TriggerWindow>())) ?? []
        let contacts = (try? context.fetch(FetchDescriptor<TrustedContact>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let plan = (try? context.fetch(FetchDescriptor<SafetyPlan>()))?.first
        let reasons = (plan?.reasonsToKeepGoingText ?? "")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let escalationContacts = contacts.filter { $0.escalationEnabled }

        for window in windows {
            scheduler.removeTriggerWindowNotifications(for: window)
            scheduler.scheduleTriggerWindow(window, reasonsPool: reasons,
                                            escalationContacts: escalationContacts,
                                            primaryContact: contacts.first)
        }
    }
}
