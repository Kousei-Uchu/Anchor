//
//  TimeWindowHelper.swift
//  Anchor
//

import Foundation

enum TimeWindowHelper {
    /// Coarse time-of-day bucket used to filter GroundingTool suggestions
    /// so "what's near/available right now" actually means right now.
    static func currentTag(calendar: Calendar = .current, now: Date = .now) -> TimeWindowTag {
        let hour = calendar.component(.hour, from: now)
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .lateNight
        }
    }

    /// Whether `now` falls inside a user-defined TriggerWindow, checked by
    /// day-of-week + time-of-day only — never by location.
    static func isActive(_ window: TriggerWindow, calendar: Calendar = .current, now: Date = .now) -> Bool {
        guard window.isActive else { return false }
        let weekday = calendar.component(.weekday, from: now)
        guard window.daysOfWeek.contains(weekday) else { return false }

        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        guard let nowHour = nowComponents.hour, let nowMinute = nowComponents.minute,
              let startHour = window.startTime.hour, let startMinute = window.startTime.minute,
              let endHour = window.endTime.hour, let endMinute = window.endTime.minute else {
            return false
        }

        let nowMinutes = nowHour * 60 + nowMinute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        if startMinutes <= endMinutes {
            return (startMinutes...endMinutes).contains(nowMinutes)
        } else {
            // window spans midnight
            return nowMinutes >= startMinutes || nowMinutes <= endMinutes
        }
    }

    /// The next calendar Date at which `window` starts, searching up to 7
    /// days ahead. Used to surface "your next risk window" on widgets
    /// without showing every window at once.
    static func nextOccurrence(of window: TriggerWindow, after now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard window.isActive, !window.daysOfWeek.isEmpty else { return nil }
        for dayOffset in 0...7 {
            guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: candidateDay)
            guard window.daysOfWeek.contains(weekday) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: candidateDay)
            components.hour = window.startHour
            components.minute = window.startMinute
            guard let candidateDate = calendar.date(from: components), candidateDate > now else { continue }
            return candidateDate
        }
        return nil
    }

    /// Across every active window, the single soonest upcoming start —
    /// this is what a widget should show, rather than the whole list.
    static func soonestUpcoming(among windows: [TriggerWindow], after now: Date = .now, calendar: Calendar = .current) -> (window: TriggerWindow, date: Date)? {
        windows
            .compactMap { window in nextOccurrence(of: window, after: now, calendar: calendar).map { (window, $0) } }
            .min { $0.1 < $1.1 }
    }
}
