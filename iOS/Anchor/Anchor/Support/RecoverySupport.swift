//
//  RecoverySupport.swift
//  Anchor
//
//  Reminders, widget sync and deletion for the optional Recovery area.
//
//  Privacy rule: anything that can appear on a lock screen (notifications and
//  widgets) uses the counter's discreet label ("Your counter") unless the user
//  turned on "Show this name outside the app" for that counter.
//

import Foundation
import SwiftData
import UserNotifications
import WidgetKit

enum RecoverySettings {
    static let pledgeEnabled = "recovery.pledgeReminder.enabled"
    static let pledgeHour = "recovery.pledgeReminder.hour"
    static let pledgeMinute = "recovery.pledgeReminder.minute"
    static let reviewEnabled = "recovery.reviewReminder.enabled"
    static let reviewHour = "recovery.reviewReminder.hour"
    static let reviewMinute = "recovery.reviewReminder.minute"
    static let milestonesEnabled = "recovery.milestoneReminders.enabled"
}

// MARK: - Reminders

enum RecoveryNotifications {
    static let prefix = "recovery-"

    /// A plain value describing one notification, so no SwiftData objects are
    /// captured by the notification centre's background callbacks.
    struct Planned {
        let id: String
        let title: String
        let body: String
        let components: DateComponents
        let repeats: Bool
    }

    static func refresh(using context: ModelContext) {
        let counters = (try? context.fetch(FetchDescriptor<RecoveryCounter>())) ?? []
        refresh(counters: counters)
        RecoveryWidgetSync.refresh(counters: counters)
    }

    static func refresh(counters: [RecoveryCounter]) {
        guard !DemoMode.isOn else { return }
        apply(plan(counters: counters))
    }

    static func plan(counters: [RecoveryCounter], defaults: UserDefaults = .standard, now: Date = .now) -> [Planned] {
        var planned: [Planned] = []
        let calendar = Calendar.current

        if defaults.bool(forKey: RecoverySettings.pledgeEnabled) {
            planned.append(Planned(
                id: prefix + "pledge", title: "Anchor", body: "A quiet moment for yourself?",
                components: time(defaults, RecoverySettings.pledgeHour, RecoverySettings.pledgeMinute, 8, 0), repeats: true))
        }
        if defaults.bool(forKey: RecoverySettings.reviewEnabled) {
            planned.append(Planned(
                id: prefix + "review", title: "Anchor", body: "How did today go? Only if you feel like it.",
                components: time(defaults, RecoverySettings.reviewHour, RecoverySettings.reviewMinute, 20, 30), repeats: true))
        }
        if defaults.bool(forKey: RecoverySettings.milestonesEnabled) {
            for counter in counters where !counter.isArchived {
                guard let run = counter.currentRun else { continue }
                var day = max(counter.currentRunDays(now: now) - 1, 0)
                var added = 0
                var attempts = 0
                while added < 3 && attempts < 8 {
                    day = RecoveryMilestones.next(after: day)
                    attempts += 1
                    guard let dayStart = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: run.start)),
                          let fire = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart),
                          fire > now else { continue }
                    let body = counter.showNameOutsideApp
                        ? "\(counter.name): \(RecoveryMilestones.label(day))"
                        : "A milestone you set is today."
                    planned.append(Planned(
                        id: prefix + "milestone-\(counter.id.uuidString)-\(day)", title: "Anchor", body: body,
                        components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false))
                    added += 1
                }
            }
        }
        return planned
    }

    private static func time(_ defaults: UserDefaults, _ hourKey: String, _ minuteKey: String,
                             _ defaultHour: Int, _ defaultMinute: Int) -> DateComponents {
        let hour = (defaults.object(forKey: hourKey) as? Int) ?? defaultHour
        let minute = (defaults.object(forKey: minuteKey) as? Int) ?? defaultMinute
        return DateComponents(hour: hour, minute: minute)
    }

    private static func apply(_ planned: [Planned]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for item in planned {
                let content = UNMutableNotificationContent()
                content.title = item.title
                content.body = item.body
                let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: item.repeats)
                center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
            }
        }
    }
}

// MARK: - Widget

enum RecoveryWidgetSync {
    static func refresh(counters: [RecoveryCounter]) {
        let items: [CounterWidgetItem] = counters
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(2)
            .compactMap { counter in
                guard let run = counter.currentRun else { return nil }
                return CounterWidgetItem(
                    label: counter.showNameOutsideApp ? counter.name : counter.discreetLabel,
                    runStart: run.start,
                    priorDays: counter.completedRunsDays,
                    mode: counter.mode.rawValue)
            }
        CounterWidgetStore.write(items)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Deleting

enum RecoveryStore {
    /// Deletes a counter and its daily entries, then refreshes reminders and the widget.
    static func delete(_ counter: RecoveryCounter, in context: ModelContext) {
        let id = counter.id
        let entries = (try? context.fetch(FetchDescriptor<RecoveryDayEntry>(predicate: #Predicate { $0.counterID == id }))) ?? []
        for entry in entries { context.delete(entry) }
        context.delete(counter)
        RecoveryNotifications.refresh(using: context)
    }
}
