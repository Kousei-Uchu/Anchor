//
//  WidgetDataStore.swift
//  Anchor (shared with AnchorWidgetExtension)
//
//  The lock-screen widget must only ever show non-sensitive summary info —
//  per spec, that means contact names + a way to reach them, and whether a
//  safety plan exists, never the plan's actual content, journal text, or
//  anything crisis-specific that could be read over someone's shoulder on
//  a lock screen. This file is the only bridge between the app's real
//  SwiftData store and the widget; keep it that narrow on purpose.
//

import Foundation

struct ContactWidgetSummary: Codable, Identifiable {
    var id: String { name + phoneNumber }
    let name: String
    let phoneNumber: String

    /// `URL(string: "tel:0412 345 678")` returns nil because of the spaces —
    /// this is why the widget's Call link previously failed to appear at
    /// all (falling through to just opening the app instead). Phone numbers
    /// are stored exactly as the user typed them (so they still look right
    /// everywhere else), but the widget must dial from a stripped version:
    /// digits and a single leading "+" only.
    var dialableNumber: String {
        var result = ""
        for (index, character) in phoneNumber.enumerated() {
            if character.isNumber {
                result.append(character)
            } else if character == "+" && index == 0 {
                result.append(character)
            }
        }
        return result
    }
}

struct AnchorWidgetSnapshot: Codable {
    var topContacts: [ContactWidgetSummary]
    var hasSafetyPlan: Bool
    var deEscalationScriptLine: String
    /// A short human label like "Weekday mornings · Mon 7:30 AM" for the
    /// soonest upcoming active trigger window — never the window's full
    /// detail, just enough to glance at. Nil if there are no active windows.
    var nextTriggerWindowLabel: String?
    /// The user's own current affirmation, cycled the same way as on Now.
    var currentAffirmation: String?
}

enum WidgetDataStore {
    /// Must match the App Group configured in both targets' entitlements.
    static let appGroupID = "group.page.aspens.anchor"
    private static let snapshotKey = "AnchorWidgetSnapshot"

    static func write(_ snapshot: AnchorWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func read() -> AnchorWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(AnchorWidgetSnapshot.self, from: data)
    }

    /// Called from the app whenever contacts, the safety plan, or trigger
    /// windows change, so the widget stays current. Deliberately builds the
    /// snapshot from just name + phone number + booleans/short labels —
    /// nothing from SafetyPlan's or TriggerWindow's full text fields is
    /// ever passed in here.
    static func refresh(contacts: [TrustedContact], hasSafetyPlan: Bool, deEscalationScriptLine: String,
                        nextTriggerWindowLabel: String? = nil, currentAffirmation: String? = nil) {
        let summaries = contacts.prefix(2).map { ContactWidgetSummary(name: $0.name, phoneNumber: $0.phoneNumber) }
        write(AnchorWidgetSnapshot(
            topContacts: Array(summaries),
            hasSafetyPlan: hasSafetyPlan,
            deEscalationScriptLine: deEscalationScriptLine,
            nextTriggerWindowLabel: nextTriggerWindowLabel,
            currentAffirmation: currentAffirmation
        ))
    }
}

// MARK: - Recovery counter widget

/// What the counter widget may know: a label (the discreet one unless the user
/// opted in), when the current run began, and the days from earlier runs.
/// The day count is worked out inside the widget so it moves on at midnight
/// without the app needing to run.
struct CounterWidgetItem: Codable, Identifiable {
    var id: String { label + String(runStart.timeIntervalSince1970) }
    let label: String
    let runStart: Date
    let priorDays: Int
    let mode: String

    func runDays(now: Date) -> Int {
        // Whole elapsed days, matching the app.
        max(0, Calendar.current.dateComponents([.day], from: runStart, to: now).day ?? 0)
    }

    func totalDays(now: Date) -> Int { priorDays + runDays(now: now) }
}

enum CounterWidgetStore {
    private static let key = "AnchorCounterWidgetItems"

    static func write(_ items: [CounterWidgetItem]) {
        guard let defaults = UserDefaults(suiteName: WidgetDataStore.appGroupID),
              let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    static func read() -> [CounterWidgetItem] {
        guard let defaults = UserDefaults(suiteName: WidgetDataStore.appGroupID),
              let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CounterWidgetItem].self, from: data)) ?? []
    }
}
