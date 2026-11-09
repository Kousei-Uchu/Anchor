//
//  NotificationScheduler.swift
//  Anchor
//
//  Every lock screen line comes from a fixed string written in this file
//  (reviewed, shipped with the app). Nothing here ever asks a model to write
//  a sentence, and nothing the person wrote is shown on the lock screen: their
//  own words travel inside a reminder and are shown once the app is open.
//

import Foundation
import UserNotifications
import SwiftData

enum NotificationCategory: String {
    case triggerWindow = "ANCHOR_TRIGGER_WINDOW"
    case appointmentReminder = "ANCHOR_APPOINTMENT_REMINDER"
    case escalationCheckIn = "ANCHOR_ESCALATION_CHECKIN"
    case dailyCheckIn = "ANCHOR_DAILY_CHECKIN"
    case helloReminder = "ANCHOR_HELLO_REMINDER"
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

        let helloCategory = UNNotificationCategory(
            identifier: NotificationCategory.helloReminder.rawValue,
            actions: [openAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories(
            [triggerCategory, appointmentCategory, escalationCategory, dailyCheckInCategory, helloCategory]
        )
    }

    /// Replaces everything pending for one trigger window: its weekly reminder on each of its
    /// days and, for each contact who has Escalate if I don't respond switched on, a reminder
    /// that many minutes after the start. Anything the window had before is removed and the new
    /// set added in the same step, so a re-sync can never remove what it has just added.
    ///
    /// What the lock screen shows is the same for every window and every person: the title
    /// Anchor and one plain line that names nothing. The window's label and a line from the
    /// person's own safety plan travel inside the notification, out of sight, and are shown once
    /// the app is open (see WindowReminderPrompt).
    ///
    /// Escalations are dated, one request for each of the next few weeks, and not one repeating
    /// request, because iOS cannot skip a single occurrence of a repeating one. Answering one
    /// reminder removes only that day's escalation and records it in EscalationSkips so the next
    /// re-sync does not put it back; the weeks after it keep theirs. The cost is that they use
    /// some of the 64 pending reminders iOS allows the whole app, and they are only topped up when
    /// Anchor is opened.
    ///
    /// iOS cannot send a message for the person in the background. The escalation reminder only
    /// puts "Message a contact" one tap away.
    func scheduleTriggerWindow(_ window: TriggerWindow, reasonsPool: [String],
                                escalationContacts: [TrustedContact], primaryContact: TrustedContact?) {
        guard !DemoMode.isOn else { return }
        let windowID = window.id
        var planned: [PlannedReminder] = []
        if window.isActive, let hour = window.startTime.hour, let minute = window.startTime.minute {
            let escalations = escalationContacts.compactMap { contact -> TriggerReminderPlan.Escalation? in
                guard let minutes = contact.escalationWindowMinutes else { return nil }
                return TriggerReminderPlan.Escalation(contactID: contact.id, name: contact.name,
                                                      phone: contact.phoneNumber, minutes: minutes)
            }
            EscalationSkips.prune()
            planned = TriggerReminderPlan.make(
                windowID: windowID, label: window.label, days: window.daysOfWeek,
                hour: hour, minute: minute,
                quote: TriggerReminderPlan.pickQuote(from: reasonsPool),
                primaryName: primaryContact?.name ?? "", primaryPhone: primaryContact?.phoneNumber ?? "",
                escalations: escalations, now: Date(), skipped: EscalationSkips.all())
            // Safety net: scheduling means the user has a reminder set up, so make sure we've asked.
            if !planned.isEmpty { Self.askForPermissionIfNeeded() }
        }
        Self.replacePending(for: windowID, with: planned)
    }

    /// Removes what is pending for the window and adds the plan in one callback. Only plain values
    /// are captured, so no stored objects reach the notification centre's own queue.
    private static func replacePending(for windowID: UUID, with planned: [PlannedReminder]) {
        let center = UNUserNotificationCenter.current()
        let prefixes = Self.pendingPrefixes(for: windowID)
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { id in prefixes.contains { id.hasPrefix($0) } }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for item in planned {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                content.categoryIdentifier = item.category
                content.sound = .default
                var userInfo: [AnyHashable: Any] = item.info
                if !item.escalationKeys.isEmpty { userInfo["escalationKeys"] = item.escalationKeys }
                content.userInfo = userInfo
                let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: item.repeats)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }

    private static func pendingPrefixes(for windowID: UUID) -> [String] {
        ["trigger-\(windowID.uuidString)-", "escalation-\(windowID.uuidString)-"]
    }

    /// Called when the person answers a trigger window reminder (I'm okay, Open Anchor or a tap on
    /// it): takes away that day's escalation reminders and nothing after them.
    static func cancelEscalations(keys: [String], firedAt: Date) {
        guard !keys.isEmpty else { return }
        let stamp = EscalationKeys.dayStamp(firedAt, calendar: .current)
        let ids = keys.map { EscalationKeys.identifier(key: $0, dayStamp: stamp) }
        EscalationSkips.add(ids)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// For reminders scheduled before this change, which carried the whole list of repeating
    /// escalation identifiers. The next re-sync replaces them with dated ones.
    static func cancelEscalations(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Takes a window's reminders away, for a window that is being deleted.
    func removeTriggerWindowNotifications(for window: TriggerWindow) {
        Self.replacePending(for: window.id, with: [])
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
        #if DEBUG
        TriggerReminderSelfTest.run()
        #endif
        let scheduler = NotificationScheduler(context: context)
        let windows = (try? context.fetch(FetchDescriptor<TriggerWindow>())) ?? []
        let contacts = (try? context.fetch(FetchDescriptor<TrustedContact>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let sections = (try? context.fetch(FetchDescriptor<SafetyPlanSection>())) ?? []
        let reasons = SafetyPlanSections.reasonLines(from: sections)
        let escalationContacts = contacts.filter { $0.escalationEnabled }

        for window in windows {
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
/// matches the sessions as they are now. The provider travels inside the
/// reminder, out of sight, so opening one goes to that provider's Session prep.
enum AppointmentReminders {
    static let prefix = "appointment-"
    static let dayBeforeKey = "reminders.appointment.dayBefore"
    static let sameDayKey = "reminders.appointment.sameDay"
    static let eveningHourKey = "reminders.appointment.eveningHour"
    static let eveningMinuteKey = "reminders.appointment.eveningMinute"
    static let dayBeforeBody = "Something you planned is coming up tomorrow."
    static let sameDayBody = "Something you planned is coming up in a couple of hours."

    /// The evening before comes at a time the person picks, 6 pm to begin with, whatever
    /// time the session is. It is kept between 4 pm and 10:59 pm, so it is always the
    /// evening of the day before and a late session never gets a reminder that says
    /// tomorrow on the day itself.
    static let defaultEveningHour = 18
    static let earliestEveningHour = 16
    static let latestEveningHour = 22

    static func clampedEvening(hour: Int, minute: Int) -> (hour: Int, minute: Int) {
        if hour < earliestEveningHour { return (earliestEveningHour, 0) }
        if hour > latestEveningHour { return (latestEveningHour, 59) }
        return (hour, min(max(minute, 0), 59))
    }

    static func eveningTime(defaults: UserDefaults = .standard) -> (hour: Int, minute: Int) {
        clampedEvening(hour: defaults.object(forKey: eveningHourKey) as? Int ?? defaultEveningHour,
                       minute: defaults.object(forKey: eveningMinuteKey) as? Int ?? 0)
    }
    static let hoursAhead = 2
    /// iOS keeps only 64 waiting notifications for the whole app, so only the
    /// soonest few are scheduled; the rest are added as they come near.
    static let limit = 20

    struct Planned {
        let id: String
        let date: Date
        let body: String
        /// The provider the session is with, empty if it is not known.
        let providerID: String
    }

    static func refresh(using context: ModelContext) {
        #if DEBUG
        AppointmentReminderSelfTest.run()
        #endif
        let providers = (try? context.fetch(FetchDescriptor<AppointmentSeries>())) ?? []
        refresh(sessions: providers.flatMap { provider in
            provider.occurrences.map { (id: $0.id, date: $0.scheduledDate, providerID: Optional(provider.id)) }
        })
    }

    static func refresh(sessions: [(id: UUID, date: Date, providerID: UUID?)], defaults: UserDefaults = .standard) {
        guard !DemoMode.isOn else { return }
        let evening = eveningTime(defaults: defaults)
        let planned = plan(
            sessions: sessions,
            dayBefore: defaults.bool(forKey: dayBeforeKey),
            sameDay: defaults.bool(forKey: sameDayKey),
            now: .now,
            calendar: .current,
            eveningHour: evening.hour,
            eveningMinute: evening.minute
        )
        apply(planned)
    }

    static func plan(sessions: [(id: UUID, date: Date, providerID: UUID?)], dayBefore: Bool, sameDay: Bool,
                     now: Date, calendar: Calendar,
                     eveningHour: Int = defaultEveningHour, eveningMinute: Int = 0) -> [Planned] {
        var planned: [Planned] = []
        for session in sessions where session.date > now {
            if dayBefore,
               let previous = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: session.date)),
               let evening = calendar.date(bySettingHour: eveningHour, minute: eveningMinute, second: 0, of: previous),
               evening > now {
                planned.append(Planned(id: "\(prefix)\(session.id.uuidString)-day-before", date: evening, body: dayBeforeBody,
                                       providerID: session.providerID?.uuidString ?? ""))
            }
            if sameDay,
               let ahead = calendar.date(byAdding: .hour, value: -hoursAhead, to: session.date),
               ahead > now {
                planned.append(Planned(id: "\(prefix)\(session.id.uuidString)-same-day", date: ahead, body: sameDayBody,
                                       providerID: session.providerID?.uuidString ?? ""))
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
                if !item.providerID.isEmpty { content.userInfo = ["providerID": item.providerID] }
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }
}


// MARK: - Trigger window reminders: the plan, the keys and the skipped days

/// One notification, described as plain values so nothing stored is captured by a callback.
struct PlannedReminder {
    let id: String
    let title: String
    let body: String
    let category: String
    let components: DateComponents
    let repeats: Bool
    let info: [String: String]
    let escalationKeys: [String]
}

/// Works out what a trigger window should have pending. Pure: the same input always gives the
/// same plan, so it can be checked without a notification centre.
enum TriggerReminderPlan {
    /// Shown on the lock screen for every trigger window. It names nothing.
    static let plainBody = "Checking in. No pressure to respond."
    static let escalationBody = "Would you like to let someone know you're okay?"
    /// How many weeks of dated escalation reminders are kept ahead.
    static let weeksAhead = 3
    /// The most escalation reminders one window keeps pending, soonest first, so a few windows
    /// and contacts cannot use up the 64 reminders iOS allows the whole app.
    static let escalationCap = 10

    struct Escalation {
        let contactID: UUID
        let name: String
        let phone: String
        let minutes: Int
    }

    static func pickQuote(from pool: [String]) -> String? {
        pool.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .randomElement()
    }

    static func make(windowID: UUID, label: String, days: [Int], hour: Int, minute: Int,
                     quote: String?, primaryName: String, primaryPhone: String,
                     escalations: [Escalation], now: Date, skipped: Set<String>,
                     calendar: Calendar = .current) -> [PlannedReminder] {
        var weekly: [PlannedReminder] = []
        var dated: [(fire: Date, item: PlannedReminder)] = []

        for weekday in days {
            let keys = escalations.map {
                EscalationKeys.key(windowID: windowID, weekday: weekday, contactID: $0.contactID, minutes: $0.minutes)
            }
            var info = ["windowLabel": label, "contactName": primaryName, "contactPhone": primaryPhone]
            if let quote { info["line"] = quote }
            weekly.append(PlannedReminder(
                id: "trigger-\(windowID.uuidString)-\(weekday)",
                title: "Anchor", body: plainBody,
                category: NotificationCategory.triggerWindow.rawValue,
                components: DateComponents(hour: hour, minute: minute, weekday: weekday),
                repeats: true, info: info, escalationKeys: keys))

            for (escalation, key) in zip(escalations, keys) {
                for occurrence in EscalationKeys.dates(weekday: weekday, hour: hour, minute: minute,
                                                       minutesAfter: escalation.minutes, now: now, calendar: calendar) {
                    let id = EscalationKeys.identifier(key: key, dayStamp: occurrence.day)
                    if skipped.contains(id) { continue }
                    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: occurrence.fire)
                    dated.append((occurrence.fire, PlannedReminder(
                        id: id, title: "Anchor", body: escalationBody,
                        category: NotificationCategory.escalationCheckIn.rawValue,
                        components: parts, repeats: false,
                        info: ["contactName": escalation.name, "contactPhone": escalation.phone],
                        escalationKeys: [])))
                }
            }
        }
        let kept = dated.sorted { $0.fire < $1.fire }.prefix(escalationCap).map { $0.item }
        return weekly + kept
    }
}

/// The names given to dated escalation reminders. An escalation is named for its window, the
/// weekday, the contact, the minutes after the start and the day the window starts on.
enum EscalationKeys {
    static func key(windowID: UUID, weekday: Int, contactID: UUID, minutes: Int) -> String {
        "\(windowID.uuidString)-\(weekday)-\(contactID.uuidString)-\(minutes)"
    }

    static func identifier(key: String, dayStamp: String) -> String {
        "escalation-\(key)-\(dayStamp)"
    }

    /// The day as eight digits, year first, so stamps sort in date order.
    static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// The coming days that are the given weekday, within the weeks ahead, with the moment the
    /// escalation would fire. A day whose escalation has already passed is left out.
    static func dates(weekday: Int, hour: Int, minute: Int, minutesAfter: Int,
                      now: Date, calendar: Calendar) -> [(day: String, fire: Date)] {
        let today = calendar.startOfDay(for: now)
        var result: [(day: String, fire: Date)] = []
        for offset in 0..<(7 * TriggerReminderPlan.weeksAhead) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  calendar.component(.weekday, from: day) == weekday,
                  let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
            let fire = start.addingTimeInterval(TimeInterval(minutesAfter * 60))
            if fire > now { result.append((dayStamp(day, calendar: calendar), fire)) }
        }
        return result
    }
}

/// The escalation reminders the person has answered, so a re-sync does not put them back.
/// Only the day is kept with each, and a day that has gone by is dropped.
enum EscalationSkips {
    private static let storeKey = "anchor.escalationSkipped"

    static func all(defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: storeKey) ?? [])
    }

    static func add(_ ids: [String], defaults: UserDefaults = .standard) {
        var set = all(defaults: defaults)
        ids.forEach { set.insert($0) }
        defaults.set(Array(set).sorted(), forKey: storeKey)
    }

    static func prune(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = Date()) {
        let today = EscalationKeys.dayStamp(now, calendar: calendar)
        let kept = all(defaults: defaults).filter { String($0.suffix(8)) >= today }
        defaults.set(Array(kept).sorted(), forKey: storeKey)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storeKey)
    }
}

#if DEBUG
/// Checks the plan for a trigger window against known answers the first time reminders are
/// re-synced in a debug build, and stops the app with a message if it is wrong.
enum TriggerReminderSelfTest {
    private static var hasRun = false

    static func run() {
        if hasRun { return }
        hasRun = true
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Wednesday 11 Nov 2026, 9 pm. A window on Mondays and Wednesdays at 8 pm, one contact, 30 minutes.
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 21))!
        let window = UUID()
        let contact = TriggerReminderPlan.Escalation(contactID: UUID(), name: "Sam", phone: "0400000000", minutes: 30)
        func make(skipped: Set<String>) -> [PlannedReminder] {
            TriggerReminderPlan.make(windowID: window, label: "Sunday evening", days: [2, 4], hour: 20, minute: 0,
                                     quote: "I have people who care", primaryName: "Sam", primaryPhone: "0400000000",
                                     escalations: [contact], now: now, skipped: skipped, calendar: calendar)
        }
        let plan = make(skipped: [])
        let weekly = plan.filter { $0.repeats }
        let escalations = plan.filter { !$0.repeats }
        // Mondays: 16, 23 and 30 Nov. Wednesdays: today has passed, so 18 and 25 Nov.
        guard weekly.count == 2, escalations.count == 5 else {
            fatalError("Trigger reminder self-test: expected 2 weekly and 5 dated reminders, got \(weekly.count) and \(escalations.count).")
        }
        guard weekly.allSatisfy({ $0.title == "Anchor" && $0.body == TriggerReminderPlan.plainBody }) else {
            fatalError("Trigger reminder self-test: the lock screen wording is not the plain wording.")
        }
        let shown = plan.map { $0.title + " " + $0.body }.joined(separator: " ")
        guard !shown.contains("Sunday evening"), !shown.contains("people who care"), !shown.contains("Sam") else {
            fatalError("Trigger reminder self-test: the lock screen carries the person's words.")
        }
        guard weekly.allSatisfy({ $0.info["windowLabel"] == "Sunday evening" && $0.info["line"] == "I have people who care" }) else {
            fatalError("Trigger reminder self-test: the label and the line did not travel inside the reminder.")
        }
        let monday16 = EscalationKeys.identifier(
            key: EscalationKeys.key(windowID: window, weekday: 2, contactID: contact.contactID, minutes: 30), dayStamp: "20261116")
        guard escalations.contains(where: { $0.id == monday16 }) else {
            fatalError("Trigger reminder self-test: the dated reminder for Monday 16 Nov is missing.")
        }
        let after = make(skipped: [monday16])
        guard after.filter({ !$0.repeats }).count == 4, !after.contains(where: { $0.id == monday16 }) else {
            fatalError("Trigger reminder self-test: skipping one day did not leave the other days alone.")
        }
        guard escalations.allSatisfy({ $0.components.hour != nil && $0.components.day != nil }) else {
            fatalError("Trigger reminder self-test: a dated reminder has no date.")
        }
    }
}
#endif

#if DEBUG
/// Checks the session reminder plan against known answers the first time reminders are
/// refreshed in a debug build, and stops the app with a message if it is wrong.
enum AppointmentReminderSelfTest {
    private static var hasRun = false

    static func run() {
        if hasRun { return }
        hasRun = true
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 12))!
        let session = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 10))!
        let provider = UUID()
        let plan = AppointmentReminders.plan(
            sessions: [(id: UUID(), date: session, providerID: provider)],
            dayBefore: true, sameDay: true, now: now, calendar: calendar,
            eveningHour: 19, eveningMinute: 30)
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 19, minute: 30))!
        let ahead = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 8))!
        guard plan.count == 2, plan[0].date == evening, plan[1].date == ahead else {
            fatalError("Session reminder self-test: the evening before or the hours ahead is at the wrong time.")
        }
        guard plan.allSatisfy({ $0.providerID == provider.uuidString }) else {
            fatalError("Session reminder self-test: the provider did not travel with the reminder.")
        }
        guard !plan.contains(where: { $0.body.contains("session") }) else {
            fatalError("Session reminder self-test: the lock screen says it is a session.")
        }
        let early = AppointmentReminders.clampedEvening(hour: 2, minute: 30)
        let late = AppointmentReminders.clampedEvening(hour: 23, minute: 10)
        let odd = AppointmentReminders.clampedEvening(hour: 20, minute: 75)
        guard early.hour == 16, early.minute == 0, late.hour == 22, late.minute == 59, odd.hour == 20, odd.minute == 59 else {
            fatalError("Session reminder self-test: the evening time is not kept between 4 pm and 10:59 pm.")
        }
    }
}
#endif


// MARK: - Hello reminders

/// Optional reminders to reach out to one person, set by the person using the app, off unless they
/// switch them on. There are two kinds: a regular hello on days and a time they pick, and a reminder
/// about a day on the Support calendar that the person can see, at 9 am the morning of that day or
/// the day before. The lock screen never names anyone and never says what the reminder is about
/// beyond something to remember; who it is for travels inside the reminder and is read when it is
/// opened. At most one comes on any day, whoever it is for. A support day takes the place of a
/// hello that day, and when two support days come on the same day the person higher in the
/// contacts list keeps it. Every call clears the hello notifications and adds the current set again.
enum HelloReminders {
    static let prefix = "hello-"
    static let body = "A quiet moment to reach out?"
    static let dayBody = "Something to remember today."
    static let dayBeforeBody = "Something to remember tomorrow."
    static let contactKey = "helloContactID"
    static let kindKey = "helloKind"
    static let supportDayKind = "supportDay"
    static let dayKey = "helloEventDay"
    static let dayBeforeKey = "helloDayBefore"
    /// A support day is planned this far ahead. A hello on a weekday that has a support day in this
    /// time is planned as separate dated reminders for the same time, so one day can be skipped.
    static let weeksAhead = 3
    static let supportDayHour = 9

    /// The plain values the plan needs, so nothing from SwiftData is held by the notification centre.
    typealias Entry = (id: UUID, order: Int, enabled: Bool, days: [Int], hour: Int, minute: Int)

    /// One day on the Support calendar that one person can see, for a person who has these on.
    struct SupportDay {
        let contactID: UUID
        let order: Int
        /// The start of the day on the calendar.
        let eventDay: Date
        let dayBefore: Bool
    }

    struct Planned {
        let id: String
        let components: DateComponents
        let contactID: String
        let repeats: Bool
        let supportDay: SupportDay?
    }

    struct Plan {
        var reminders: [Planned]
        /// Support days that got no reminder because another person's comes the same day.
        var skipped: [SupportDay]
    }

    static func entries(of contacts: [TrustedContact]) -> [Entry] {
        contacts.map { (id: $0.id, order: $0.sortOrder, enabled: $0.helloEnabled,
                        days: $0.helloDays, hour: $0.helloHour, minute: $0.helloMinute) }
    }

    static func supportDays(of contacts: [TrustedContact], entries: [SupportCalendarEntry],
                            calendar: Calendar = .current) -> [SupportDay] {
        var found: [SupportDay] = []
        for contact in contacts where contact.supportDaysEnabled {
            for entry in entries where entry.visibleToContactIDs.contains(contact.id) {
                found.append(SupportDay(contactID: contact.id, order: contact.sortOrder,
                                        eventDay: calendar.startOfDay(for: entry.date),
                                        dayBefore: contact.supportDaysDayBefore))
            }
        }
        return found
    }

    static func refresh(using context: ModelContext) {
        #if DEBUG
        HelloReminderSelfTest.run()
        #endif
        let contacts = (try? context.fetch(FetchDescriptor<TrustedContact>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        refresh(contacts: contacts, using: context)
    }

    /// For a caller that has its own list of contacts, such as one that has just deleted someone.
    static func refresh(contacts: [TrustedContact], using context: ModelContext) {
        let days = (try? context.fetch(FetchDescriptor<SupportCalendarEntry>())) ?? []
        refresh(contacts: contacts, entries: days)
    }

    static func refresh(contacts: [TrustedContact], entries: [SupportCalendarEntry] = []) {
        guard !DemoMode.isOn else { return }
        let days = supportDays(of: contacts, entries: entries)
        apply(plan(entries: HelloReminders.entries(of: contacts), supportDays: days).reminders)
    }

    /// The time a support day's reminder comes, or nil if it is in the past or beyond the weeks planned.
    private static func fireTime(of day: SupportDay, now: Date, last: Date, calendar: Calendar) -> Date? {
        let fireDay = day.dayBefore ? calendar.date(byAdding: .day, value: -1, to: day.eventDay) : day.eventDay
        guard let fireDay,
              let at = calendar.date(bySettingHour: supportDayHour, minute: 0, second: 0, of: fireDay),
              at > now, calendar.startOfDay(for: at) <= last else { return nil }
        return at
    }

    private static func stamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Support days first, one for each day. Then one hello for each weekday that someone has chosen,
    /// owned by the first person (by position in the contacts list) who chose it: one repeating
    /// weekly reminder, unless a support day falls on that weekday in the next few weeks, when it is
    /// separate dated reminders for those weeks that leave out the day the support day takes.
    static func plan(entries: [Entry], supportDays: [SupportDay] = [], now: Date = .now,
                     calendar: Calendar = .current) -> Plan {
        let today = calendar.startOfDay(for: now)
        let last = calendar.date(byAdding: .day, value: 7 * weeksAhead, to: today) ?? today

        var kept: [Date: (day: SupportDay, at: Date)] = [:]
        var skipped: [SupportDay] = []
        for day in supportDays {
            guard let at = fireTime(of: day, now: now, last: last, calendar: calendar) else { continue }
            let key = calendar.startOfDay(for: at)
            guard let current = kept[key] else { kept[key] = (day, at); continue }
            if current.day.contactID == day.contactID && current.day.eventDay == day.eventDay { continue }
            if (day.order, day.eventDay) < (current.day.order, current.day.eventDay) {
                skipped.append(current.day)
                kept[key] = (day, at)
            } else {
                skipped.append(day)
            }
        }

        var planned: [Planned] = []
        let busyWeekdays = Set(kept.keys.map { calendar.component(.weekday, from: $0) })
        for weekday in 1...7 {
            let wanting = entries.filter { $0.enabled && $0.days.contains(weekday) }
            guard let owner = wanting.min(by: { $0.order < $1.order }) else { continue }
            let hour = min(max(owner.hour, 0), 23)
            let minute = min(max(owner.minute, 0), 59)
            if !busyWeekdays.contains(weekday) {
                planned.append(Planned(
                    id: prefix + owner.id.uuidString + "-\(weekday)",
                    components: DateComponents(hour: hour, minute: minute, weekday: weekday),
                    contactID: owner.id.uuidString, repeats: true, supportDay: nil))
                continue
            }
            for offset in 0...(7 * weeksAhead) {
                guard let raw = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
                let day = calendar.startOfDay(for: raw)
                guard calendar.component(.weekday, from: day) == weekday, kept[day] == nil,
                      let at = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                      at > now else { continue }
                planned.append(Planned(
                    id: prefix + owner.id.uuidString + "-" + stamp(day, calendar: calendar),
                    components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at),
                    contactID: owner.id.uuidString, repeats: false, supportDay: nil))
            }
        }

        for (key, item) in kept.sorted(by: { $0.key < $1.key }) {
            planned.append(Planned(
                id: prefix + "day-" + item.day.contactID.uuidString + "-" + stamp(key, calendar: calendar),
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.at),
                contactID: item.day.contactID.uuidString, repeats: false, supportDay: item.day))
        }
        return Plan(reminders: planned, skipped: skipped)
    }

    /// The days this person chose that someone higher in the list already has, so Settings can say so.
    static func sharedDays(for id: UUID, in entries: [Entry]) -> [Int] {
        guard let mine = entries.first(where: { $0.id == id }), mine.enabled else { return [] }
        return Set(mine.days).filter { (1...7).contains($0) }.sorted().filter { weekday in
            entries.contains { $0.id != id && $0.enabled && $0.days.contains(weekday) && $0.order < mine.order }
        }
    }

    /// The support days of this person that got no reminder, for Settings to say so.
    static func skippedSupportDays(for id: UUID, contacts: [TrustedContact],
                                   entries: [SupportCalendarEntry]) -> [Date] {
        plan(entries: HelloReminders.entries(of: contacts),
             supportDays: supportDays(of: contacts, entries: entries))
            .skipped.filter { $0.contactID == id }.map(\.eventDay).sorted()
    }

    private static func apply(_ planned: [Planned]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for item in planned {
                let content = UNMutableNotificationContent()
                content.title = "Anchor"
                content.sound = .default
                content.categoryIdentifier = NotificationCategory.helloReminder.rawValue
                var info: [String: Any] = [contactKey: item.contactID]
                if let day = item.supportDay {
                    content.body = day.dayBefore ? dayBeforeBody : dayBody
                    info[kindKey] = supportDayKind
                    info[dayKey] = day.eventDay.timeIntervalSince1970
                    info[dayBeforeKey] = day.dayBefore
                } else {
                    content.body = body
                }
                content.userInfo = info
                let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: item.repeats)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }
}


#if DEBUG
/// Checks the one-a-day rule and that the lock screen wording names no one. A wrong answer stops a
/// test build at once, so a broken rule is seen before it reaches a phone.
enum HelloReminderSelfTest {
    private static var hasRun = false

    static func run() {
        if hasRun { return }
        hasRun = true
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        // Monday 9 November 2026, 8 am: the three weeks run to Monday 30 November.
        guard let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 8)) else { return }
        func day(_ d: Int) -> Date {
            calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 12)) ?? now)
        }

        let first = UUID(), second = UUID(), off = UUID()
        let entries: [HelloReminders.Entry] = [
            (id: second, order: 1, enabled: true, days: [1, 3], hour: 9, minute: 0),
            (id: first, order: 0, enabled: true, days: [1, 5], hour: 17, minute: 30),
            (id: off, order: 2, enabled: false, days: [1, 2], hour: 8, minute: 0)
        ]
        let plain = HelloReminders.plan(entries: entries, now: now, calendar: calendar).reminders
        guard plain.count == 3, plain.allSatisfy({ $0.repeats && $0.supportDay == nil }) else {
            fatalError("Hello reminder self-test: expected one repeating reminder for each of three days.")
        }
        guard let sunday = plain.first(where: { $0.components.weekday == 1 }),
              sunday.contactID == first.uuidString, sunday.components.hour == 17, sunday.components.minute == 30 else {
            fatalError("Hello reminder self-test: a shared day did not go to the person higher in the list.")
        }
        guard !plain.contains(where: { $0.contactID == off.uuidString }) else {
            fatalError("Hello reminder self-test: a switched off hello was scheduled.")
        }
        guard HelloReminders.sharedDays(for: second, in: entries) == [1],
              HelloReminders.sharedDays(for: first, in: entries).isEmpty else {
            fatalError("Hello reminder self-test: the shared days were not found.")
        }

        // A support day on Wednesday 18 November takes the day from the Wednesday hello.
        let helloOnWednesdays: [HelloReminders.Entry] = [
            (id: first, order: 0, enabled: true, days: [4], hour: 17, minute: 0)
        ]
        let aSupportDay = HelloReminders.SupportDay(contactID: second, order: 1, eventDay: day(18), dayBefore: false)
        let withDay = HelloReminders.plan(entries: helloOnWednesdays, supportDays: [aSupportDay],
                                          now: now, calendar: calendar)
        let hellos = withDay.reminders.filter { $0.supportDay == nil }
        let days = withDay.reminders.filter { $0.supportDay != nil }
        guard hellos.count == 2, hellos.allSatisfy({ !$0.repeats }),
              !hellos.contains(where: { $0.components.day == 18 }),
              hellos.contains(where: { $0.components.day == 11 }), hellos.contains(where: { $0.components.day == 25 }),
              days.count == 1, days[0].components.day == 18, days[0].components.hour == 9, !days[0].repeats else {
            fatalError("Hello reminder self-test: a support day did not take the place of that day's hello.")
        }

        // The day before comes the day before, and the person higher in the list keeps a shared day.
        let dayBeforeOne = HelloReminders.SupportDay(contactID: second, order: 1, eventDay: day(20), dayBefore: true)
        let sameDayOne = HelloReminders.SupportDay(contactID: first, order: 0, eventDay: day(19), dayBefore: false)
        let clash = HelloReminders.plan(entries: [], supportDays: [dayBeforeOne, sameDayOne], now: now, calendar: calendar)
        guard clash.reminders.count == 1, clash.reminders[0].contactID == first.uuidString,
              clash.skipped.count == 1, clash.skipped[0].contactID == second else {
            fatalError("Hello reminder self-test: two support days on one day did not go to the first person.")
        }
        let early = HelloReminders.plan(entries: [], supportDays: [dayBeforeOne], now: now, calendar: calendar)
        guard early.reminders.count == 1, early.reminders[0].components.day == 19 else {
            fatalError("Hello reminder self-test: a day before reminder did not come the day before.")
        }

        // Past days and days beyond the weeks planned get nothing.
        let past = HelloReminders.SupportDay(contactID: first, order: 0, eventDay: day(2), dayBefore: false)
        let farOff = HelloReminders.SupportDay(contactID: first, order: 0, eventDay: day(30).addingTimeInterval(86_400 * 5), dayBefore: false)
        guard HelloReminders.plan(entries: [], supportDays: [past, farOff], now: now, calendar: calendar).reminders.isEmpty else {
            fatalError("Hello reminder self-test: a past or far off support day was scheduled.")
        }

        for line in [HelloReminders.body, HelloReminders.dayBody, HelloReminders.dayBeforeBody] {
            let lower = line.lowercased()
            guard !lower.contains("hello"), !lower.contains("support"), !lower.contains("extra") else {
                fatalError("Hello reminder self-test: the lock screen says what the reminder is about.")
            }
        }
    }
}
#endif
