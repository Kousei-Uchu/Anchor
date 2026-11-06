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
                    guard let reached = calendar.date(byAdding: .day, value: day, to: run.start),
                          let fire = calendar.nextDate(after: reached.addingTimeInterval(-1), matching: DateComponents(hour: 9, minute: 0),
                                                       matchingPolicy: .nextTime),
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
        let urges = (try? context.fetch(FetchDescriptor<RecoveryUrge>(predicate: #Predicate { $0.counterID == id }))) ?? []
        for urge in urges { context.delete(urge) }
        context.delete(counter)
        RecoveryNotifications.refresh(using: context)
    }
}

// MARK: - Plain-language summary

/// Counts only: days, urges logged and fresh starts over a window. Used by session prep
/// and the optional psych export. It never includes urge notes, pledges, reviews or savings.
enum RecoverySummary {
    static func lines(for counter: RecoveryCounter, urges allUrges: [RecoveryUrge],
                      range: ClosedRange<Date>, now: Date = .now) -> [String] {
        let days = counter.currentRunDays(now: now)
        let total = counter.totalDays(now: now)
        var result: [String] = []

        var headline = "\(RecoveryText.days(days)) in the current run"
        if counter.mode == .runAndTotal, total != days {
            headline += ", \(RecoveryText.days(total)) in total"
        }
        result.append(headline)

        let urges = allUrges.filter { $0.counterID == counter.id && range.contains($0.date) }
        if urges.isEmpty {
            result.append("No urges logged")
        } else {
            let order = UrgeStrength.allCases
            let strongest = urges.map(\.strength).max { (order.firstIndex(of: $0) ?? 0) < (order.firstIndex(of: $1) ?? 0) }
            var text = "\(urges.count) \(urges.count == 1 ? "urge" : "urges") logged"
            if let strongest { text += ", strongest felt \(strongest.title.lowercased())" }
            result.append(text)
        }

        let freshStarts = counter.runs.dropFirst().filter { range.contains($0.start) }.count
        if freshStarts > 0 {
            result.append("\(freshStarts) fresh \(freshStarts == 1 ? "start" : "starts")")
        }
        return result
    }
}

// MARK: - Urge pattern (trigger window suggestion)

/// Looks for a two-hour stretch of the day where most of a counter's logged urges fall,
/// and only suggests a trigger window if no active one already covers it. It only ever
/// offers: the user decides, and can switch the suggestion off.
enum RecoveryUrgePattern {
    struct Suggestion {
        let startHour: Int
        let rangeLabel: String
    }

    static func suggestion(urgeDates: [Date], windows: [TriggerWindow], calendar: Calendar = .current) -> Suggestion? {
        guard urgeDates.count >= 4 else { return nil }
        let hours = urgeDates.map { calendar.component(.hour, from: $0) }

        var bestStart = 0
        var bestCount = 0
        for start in 0..<24 {
            let count = hours.filter { $0 == start || $0 == (start + 1) % 24 }.count
            if count > bestCount { bestStart = start; bestCount = count }
        }
        guard bestCount >= 3, Double(bestCount) / Double(hours.count) >= 0.5 else { return nil }

        let covered = windows.filter(\.isActive).contains {
            covers($0, hour: bestStart) || covers($0, hour: (bestStart + 1) % 24)
        }
        guard !covered else { return nil }

        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j")
        func text(_ hour: Int) -> String {
            formatter.string(from: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now)
        }
        return Suggestion(startHour: bestStart, rangeLabel: "\(text(bestStart)) and \(text((bestStart + 2) % 24))")
    }

    private static func covers(_ window: TriggerWindow, hour: Int) -> Bool {
        let start = window.startHour * 60 + window.startMinute
        let end = window.endHour * 60 + window.endMinute
        let middle = hour * 60 + 30
        return start <= end ? (middle >= start && middle < end) : (middle >= start || middle < end)
    }
}

// MARK: - Journal tags

/// Which day of a counter's current run a journal entry was written on, worked out from the
/// entry's date and the counter's runs. Nothing is stored on the entry, so it also works for
/// older entries and nothing needs migrating.
enum RecoveryJournalTag {
    static func chips(for date: Date, counters: [RecoveryCounter]) -> [String] {
        counters.compactMap { counter in
            guard let run = counter.runs.first(where: { $0.start <= date && ($0.end ?? .distantFuture) > date }) else { return nil }
            let days = RecoveryCounter.wholeDays(from: run.start, to: date)
            return "\(counter.name) \u{00B7} " + (days == 0 ? "first day" : RecoveryText.days(days))
        }
    }
}
