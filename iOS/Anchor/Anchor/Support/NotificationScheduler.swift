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
        guard !DemoMode.isOn else { return }
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
                scheduleEscalation(weekday: weekday, hour: startHour, minute: startMinute,
                                    minutesAfter: minutes, windowID: window.id, contact: contact)
            }
        }
    }

    /// The escalation reminder itself — fires `minutesAfter` past the
    /// trigger window's start, only if not cancelled by an "I'm okay"/open
    /// response to the original notification.
    ///
    /// A window that starts late in the evening can have its escalation fall after
    /// midnight, which is the next weekday, so the weekday moves on with the clock.
    /// The identifier keeps the window's own weekday, because that is what the
    /// trigger-window notification lists for cancelling.
    ///
    /// The words on the lock screen are the same fixed line for everyone. They do not
    /// name the window or the person, and they do not say the check-in was missed. Who the
    /// reminder is about is only shown once the app is open.
    private func scheduleEscalation(weekday: Int, hour: Int, minute: Int,
                                     minutesAfter: Int, windowID: UUID, contact: TrustedContact) {
        let totalMinutes = hour * 60 + minute + minutesAfter
        let daysLater = totalMinutes / (24 * 60)

        var dateComponents = DateComponents()
        dateComponents.weekday = (weekday - 1 + daysLater) % 7 + 1
        dateComponents.hour = (totalMinutes / 60) % 24
        dateComponents.minute = totalMinutes % 60

        let content = UNMutableNotificationContent()
        content.title = "Anchor"
        content.body = "Would you like to let someone know you're okay?"
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

    /// A daily, non-crisis-specific check-in — separate from trigger
    /// windows, which are about specific known risk periods. This is just
    /// "want to check in today?" at a time the user picks in Plan, so
    /// Anchor is proactive even on days nothing's scheduled to fire.
    func scheduleDailyCheckIn(hour: Int, minute: Int) {
        guard !DemoMode.isOn else { return }
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
        let sections = (try? context.fetch(FetchDescriptor<SafetyPlanSection>())) ?? []
        let reasons = SafetyPlanSections.reasonLines(from: sections)
        let escalationContacts = contacts.filter { $0.escalationEnabled }

        for window in windows {
            scheduler.removeTriggerWindowNotifications(for: window)
            scheduler.scheduleTriggerWindow(window, reasonsPool: reasons,
                                            escalationContacts: escalationContacts,
                                            primaryContact: contacts.first)
        }
    }
}


// MARK: - Routine reminders

/// An optional reminder for a routine, set by the person, off unless they
/// switch it on. The words on the lock screen are fixed and never name the
/// routine or any of its steps. Like the recovery reminders, every call
/// clears the routine notifications and adds the current set again, so what is
/// scheduled always matches what is saved.
enum RoutineReminders {
    static let prefix = "routine-"
    static let body = "Your routine is ready when you are."

    /// A plain value describing one notification, so no SwiftData objects are
    /// captured by the notification centre's background callbacks.
    struct Planned {
        let id: String
        let components: DateComponents
    }

    static func refresh(using context: ModelContext) {
        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        refresh(routines: routines)
    }

    static func refresh(routines: [Routine]) {
        guard !DemoMode.isOn else { return }
        apply(plan(routines: routines))
    }

    /// One repeating weekly notification per chosen day. A routine with no
    /// written steps, a reminder that is off, or no days chosen schedules nothing.
    static func plan(routines: [Routine]) -> [Planned] {
        var planned: [Planned] = []
        for routine in routines where routine.reminderEnabled && !routine.writtenSteps.isEmpty {
            for weekday in Set(routine.reminderDays).filter({ (1...7).contains($0) }).sorted() {
                planned.append(Planned(
                    id: prefix + routine.id.uuidString + "-\(weekday)",
                    components: DateComponents(hour: routine.reminderHour, minute: routine.reminderMinute, weekday: weekday)))
            }
        }
        return planned
    }

    private static func apply(_ planned: [Planned]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for item in planned {
                let content = UNMutableNotificationContent()
                content.title = "Anchor"
                content.body = body
                let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: true)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }
}

/// The optional morning reminder for the sleep journal. Off until it is
/// switched on in Settings. It is one repeating notification at the time the
/// person picks, and its wording never says what it is about, so nobody
/// reading the lock screen learns anything. Like the other reminders, every
/// call clears it and adds the current one again, so what is scheduled always
/// matches what is saved.
enum SleepReminder {
    static let identifier = "sleep-morning"
    static let body = "A quiet note for yourself this morning, if you would like."

    /// The time as saved, or nil when the reminder is off.
    static func components(defaults: UserDefaults = .standard) -> DateComponents? {
        guard defaults.bool(forKey: SleepSettings.reminderEnabledKey) else { return nil }
        let hour = defaults.object(forKey: SleepSettings.reminderHourKey) as? Int ?? 8
        let minute = defaults.object(forKey: SleepSettings.reminderMinuteKey) as? Int ?? 0
        return DateComponents(hour: hour, minute: minute)
    }

    static func refresh() {
        guard !DemoMode.isOn else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard let time = components() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Anchor"
        content.body = body
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}

/// Optional reminders before a session, set by the person and off unless
/// they switch them on. There are two: one the evening before and one a couple
/// of hours ahead. The lock screen never says who the session is with, or even
/// that it is a session. Like the other reminders, every call clears what was
/// scheduled and adds the current set again, so what is scheduled always
/// matches the sessions as they are now.
enum AppointmentReminders {
    static let prefix = "appointment-"
    static let dayBeforeKey = "reminders.appointment.dayBefore"
    static let sameDayKey = "reminders.appointment.sameDay"
    static let dayBeforeBody = "Something you planned is coming up tomorrow."
    static let sameDayBody = "Something you planned is coming up in a couple of hours."

    /// The evening before is always at 6 in the evening, whatever time the
    /// session is, so a late session never gets a reminder that says tomorrow
    /// on the day itself.
    static let eveningHour = 18
    static let hoursAhead = 2
    /// iOS keeps only 64 waiting notifications for the whole app, so only the
    /// soonest few are scheduled; the rest are added as they come near.
    static let limit = 20

    struct Planned {
        let id: String
        let date: Date
        let body: String
    }

    static func refresh(using context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<AppointmentOccurrence>())) ?? []
        refresh(sessions: all.map { (id: $0.id, date: $0.scheduledDate) })
    }

    static func refresh(sessions: [(id: UUID, date: Date)], defaults: UserDefaults = .standard) {
        guard !DemoMode.isOn else { return }
        let planned = plan(
            sessions: sessions,
            dayBefore: defaults.bool(forKey: dayBeforeKey),
            sameDay: defaults.bool(forKey: sameDayKey),
            now: .now,
            calendar: .current
        )
        apply(planned)
    }

    static func plan(sessions: [(id: UUID, date: Date)], dayBefore: Bool, sameDay: Bool,
                     now: Date, calendar: Calendar) -> [Planned] {
        var planned: [Planned] = []
        for session in sessions where session.date > now {
            if dayBefore,
               let previous = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: session.date)),
               let evening = calendar.date(bySettingHour: eveningHour, minute: 0, second: 0, of: previous),
               evening > now {
                planned.append(Planned(id: "\(prefix)\(session.id.uuidString)-day-before", date: evening, body: dayBeforeBody))
            }
            if sameDay,
               let ahead = calendar.date(byAdding: .hour, value: -hoursAhead, to: session.date),
               ahead > now {
                planned.append(Planned(id: "\(prefix)\(session.id.uuidString)-same-day", date: ahead, body: sameDayBody))
            }
        }
        return Array(planned.sorted { $0.date < $1.date }.prefix(limit))
    }

    private static func apply(_ planned: [Planned]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for item in planned {
                let content = UNMutableNotificationContent()
                content.title = "Anchor"
                content.body = item.body
                content.categoryIdentifier = NotificationCategory.appointmentReminder.rawValue
                content.sound = .default
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }
}
