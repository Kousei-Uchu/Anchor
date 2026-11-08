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
import ActivityKit
import CryptoKit

/// How long the current run has lasted, in the largest sensible unit, never
/// as "0 days". Lives here because this file is compiled into both the app
/// and the widget extension.
enum ElapsedFormat {
    struct Reading: Equatable {
        /// What goes in the big number slot, e.g. "12", "3" or "<1".
        let number: String
        /// The unit under it, e.g. "days", "hour", "minute".
        let label: String
    }

    private static func parts(from start: Date, to end: Date) -> (days: Int, hours: Int, minutes: Int) {
        let c = Calendar.current.dateComponents([.day, .hour, .minute], from: start, to: max(end, start))
        return (c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
    }

    static func reading(from start: Date, to end: Date) -> Reading {
        let p = parts(from: start, to: end)
        if p.days >= 1 { return Reading(number: "\(p.days)", label: p.days == 1 ? "day" : "days") }
        if p.hours >= 1 { return Reading(number: "\(p.hours)", label: p.hours == 1 ? "hour" : "hours") }
        if p.minutes >= 1 { return Reading(number: "\(p.minutes)", label: p.minutes == 1 ? "minute" : "minutes") }
        return Reading(number: "<1", label: "minute")
    }

    /// "12 days", "3 hours", "just started".
    static func phrase(from start: Date, to end: Date) -> String {
        let p = parts(from: start, to: end)
        if p.days < 1, p.hours < 1, p.minutes < 1 { return "just started" }
        let r = reading(from: start, to: end)
        return "\(r.number) \(r.label)"
    }

    /// "12 days in", "3 hours in", "just getting started".
    static func phraseIn(from start: Date, to end: Date) -> String {
        let p = parts(from: start, to: end)
        if p.days < 1, p.hours < 1, p.minutes < 1 { return "just getting started" }
        return phrase(from: start, to: end) + " in"
    }

    /// Early on the number changes every few minutes, so refresh often. After
    /// the first day it only changes at midnight.
    static func nextRefresh(runStarts: [Date], now: Date = .now) -> Date {
        let youngest = runStarts.map { now.timeIntervalSince($0) }.min() ?? .infinity
        if youngest < 3600 { return now.addingTimeInterval(15 * 60) }
        if youngest < 86_400 { return now.addingTimeInterval(3600) }
        return Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 5),
                                         matchingPolicy: .nextTime) ?? now.addingTimeInterval(6 * 3600)
    }
}

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

    static func write(_ snapshot: AnchorWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        WidgetSealing.store(data, in: .snapshot)
    }

    static func read() -> AnchorWidgetSnapshot? {
        guard let data = WidgetSealing.load(from: .snapshot) else { return nil }
        return try? JSONDecoder().decode(AnchorWidgetSnapshot.self, from: data)
    }

    /// True when a sealed snapshot is there but could not be opened just now, which is
    /// what happens before the phone's first unlock after a restart. The widget asks
    /// again soon instead of waiting for its usual long interval.
    static var isWaitingForUnlock: Bool {
        WidgetSealing.hasSealed(.snapshot) && read() == nil
    }

    /// Takes the summary off the device (Clear everything).
    static func clear() {
        WidgetSealing.clear(.snapshot)
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

    func reading(now: Date) -> ElapsedFormat.Reading { ElapsedFormat.reading(from: runStart, to: now) }
}

enum CounterWidgetStore {
    static func write(_ items: [CounterWidgetItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        WidgetSealing.store(data, in: .counters)
    }

    static func read() -> [CounterWidgetItem] {
        guard let data = WidgetSealing.load(from: .counters) else { return [] }
        return (try? JSONDecoder().decode([CounterWidgetItem].self, from: data)) ?? []
    }

    static func clear() {
        WidgetSealing.clear(.counters)
    }
}

// MARK: - Sealing what the widgets are shown
//
// The two summaries above sit in the App Group's defaults, which a phone backup
// carries. They are sealed with a key that is kept in the same App Group container
// but marked as not to be backed up, so a backup (or a copy of the defaults file)
// on its own cannot be read. The widget only ever reads the key; only the app makes
// it. Format and reasoning are in docs/ENCRYPTION.md, and scripts/anchorkey.py has
// the same format in running form.

enum WidgetSealing {
    static let prefix = "anchor.widget.v1:"

    /// One thing the widgets read: where the old plain copy lived, where the sealed
    /// copy lives, and the label that is authenticated with it.
    struct Slot {
        let legacyKey: String
        let sealedKey: String
        let context: String

        static let snapshot = Slot(legacyKey: "AnchorWidgetSnapshot",
                                   sealedKey: "AnchorWidgetSnapshot.sealed",
                                   context: "WidgetSnapshot")
        static let counters = Slot(legacyKey: "AnchorCounterWidgetItems",
                                   sealedKey: "AnchorCounterWidgetItems.sealed",
                                   context: "CounterItems")
    }

    enum KeyResult {
        case ready(SymmetricKey)
        /// The key file is there but cannot be read right now.
        case unreadable
        /// There is no key and one could not be made.
        case failed
    }

    private enum FileState {
        case missing
        case unreadable
        case invalid
        case valid(Data)
    }

    private static var folderURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetDataStore.appGroupID)?
            .appendingPathComponent("Keys", isDirectory: true)
    }

    private static var keyURL: URL? {
        folderURL?.appendingPathComponent("widget.key")
    }

    private static func state(of url: URL) -> FileState {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        guard let data = try? Data(contentsOf: url) else { return .unreadable }
        return data.count == 32 ? .valid(data) : .invalid
    }

    /// For the widget: the key if it can be read, and never a new one.
    static func readKey() -> SymmetricKey? {
        guard let url = keyURL, case .valid(let data) = state(of: url) else { return nil }
        return SymmetricKey(data: data)
    }

    /// For the app. Makes the key the first time. A key that is there but cannot be read
    /// yet is never replaced, so a locked phone cannot lead to a second key.
    static func keyForWriting() -> KeyResult {
        guard let folder = folderURL, let url = keyURL else { return .failed }
        switch state(of: url) {
        case .valid(let data):
            return .ready(SymmetricKey(data: data))
        case .unreadable:
            return .unreadable
        case .missing, .invalid:
            let fresh = SymmetricKey(size: .bits256)
            let data = fresh.withUnsafeBytes { Data($0) }
            do {
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                var excluded = URLResourceValues()
                excluded.isExcludedFromBackup = true
                var folderCopy = folder
                var fileCopy = url
                try folderCopy.setResourceValues(excluded)
                try fileCopy.setResourceValues(excluded)
            } catch {
                // A key that could not be kept out of backups is worth nothing, so it is not kept.
                try? FileManager.default.removeItem(at: url)
                return .failed
            }
            return .ready(fresh)
        }
    }

    static func seal(_ data: Data, context: String, key: SymmetricKey) -> String? {
        guard let box = try? AES.GCM.seal(data, using: key, authenticating: Data(context.utf8)),
              let combined = box.combined else { return nil }
        return prefix + combined.base64EncodedString()
    }

    static func open(_ stored: String, context: String, key: SymmetricKey) -> Data? {
        guard stored.hasPrefix(prefix),
              let combined = Data(base64Encoded: String(stored.dropFirst(prefix.count))),
              combined.count >= 28,
              let box = try? AES.GCM.SealedBox(combined: combined) else { return nil }
        return try? AES.GCM.open(box, using: key, authenticating: Data(context.utf8))
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: WidgetDataStore.appGroupID)
    }

    /// App only. Seals the data and removes any plain copy. If the key is there but cannot
    /// be read yet, what is already stored is kept as it is. If no key can be made at all,
    /// the plain copy is written as it always was, so the widget still works.
    static func store(_ data: Data, in slot: Slot) {
        guard let defaults else { return }
        switch keyForWriting() {
        case .ready(let key):
            guard let sealed = seal(data, context: slot.context, key: key) else { return }
            defaults.set(sealed, forKey: slot.sealedKey)
            defaults.removeObject(forKey: slot.legacyKey)
        case .unreadable:
            return
        case .failed:
            defaults.set(data, forKey: slot.legacyKey)
            defaults.removeObject(forKey: slot.sealedKey)
        }
    }

    /// The data, from the sealed copy if there is one, otherwise from an old plain copy
    /// that the app has not moved yet. A sealed copy that cannot be opened gives nothing,
    /// and never falls back to anything older.
    static func load(from slot: Slot) -> Data? {
        guard let defaults else { return nil }
        if let stored = defaults.string(forKey: slot.sealedKey) {
            guard let key = readKey() else { return nil }
            return open(stored, context: slot.context, key: key)
        }
        return defaults.data(forKey: slot.legacyKey)
    }

    static func hasSealed(_ slot: Slot) -> Bool {
        defaults?.string(forKey: slot.sealedKey) != nil
    }

    static func clear(_ slot: Slot) {
        defaults?.removeObject(forKey: slot.sealedKey)
        defaults?.removeObject(forKey: slot.legacyKey)
    }

    /// App only, once at launch: seals a plain copy left by an earlier version.
    static func sealLeftovers() {
        guard let defaults else { return }
        for slot in [Slot.snapshot, Slot.counters] {
            guard let old = defaults.data(forKey: slot.legacyKey) else { continue }
            if defaults.string(forKey: slot.sealedKey) != nil {
                defaults.removeObject(forKey: slot.legacyKey)
            } else {
                store(old, in: slot)
            }
        }
    }

    /// App only: Clear everything. Takes both summaries and the key off the device.
    static func removeEverything() {
        clear(.snapshot)
        clear(.counters)
        if let url = keyURL { try? FileManager.default.removeItem(at: url) }
    }
}

#if DEBUG
/// Checks the widget sealing against the vector printed by
/// `python3 scripts/anchorkey.py vectors`, so a debug build proves the Swift and the
/// reference agree. It stops the app with a message if they do not.
enum WidgetSealSelfTest {
    private static let keyBytes = Data(0..<32)
    private static let context = "WidgetSnapshot"
    private static let json = "{\"topContacts\":[{\"name\":\"Sam\",\"phoneNumber\":\"0400 000 001\"}],\"hasSafetyPlan\":true,\"deEscalationScriptLine\":\"I need 10 minutes.\"}"
    private static let sealed = "anchor.widget.v1:QEFCQ0RFRkdISUpLmZvaTFZ/6G25pXRC6EYpAALkPD3aUC0ZVRQviLU/z6vwZ53JkMyyNkSGKVWzPevq+1GaAQPn0jmwOKlZC8hAoZdAtMxhqlL6O6ANp6wMjh0rVHCvTi9n7Ba6REtyb0oG1IETmvxMDq4tMK+Z/uucae3bfd+bvx8UucvBgRuGYL5ldfdFoZilAK+k/Wum+KaS"
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Widget seal self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let key = SymmetricKey(data: keyBytes)
        let opened = WidgetSealing.open(sealed, context: context, key: key)
        check(opened == Data(json.utf8), "the sealed reference value did not open.")
        check(WidgetSealing.open(sealed, context: "CounterItems", key: key) == nil, "a value opened in another context.")
        check(WidgetSealing.open(sealed, context: context, key: SymmetricKey(data: Data(count: 32))) == nil,
              "a value opened with another key.")
        check(WidgetSealing.open(String(sealed.dropLast(4)), context: context, key: key) == nil, "a cut-off value opened.")
        check(WidgetSealing.open(json, context: context, key: key) == nil, "plain text was read as sealed.")
        check(WidgetSealing.open(sealed.replacingOccurrences(of: WidgetSealing.prefix, with: "anchor.sealed.v1:"),
                                 context: context, key: key) == nil, "a sealed text value was read as a widget value.")
        for sample in [Data(), Data("[]".utf8), Data("caf\u{e9}".utf8), Data((0..<300).map { UInt8($0 % 256) })] {
            guard let first = WidgetSealing.seal(sample, context: context, key: key),
                  let second = WidgetSealing.seal(sample, context: context, key: key) else {
                fatalError("Widget seal self-test: sealing failed.")
            }
            check(first != second, "two seals of the same data were identical.")
            check(WidgetSealing.open(first, context: context, key: key) == sample, "a sealed value did not read back.")
        }
    }
}
#endif

/// The focus timer on the lock screen. Compiled into the app and the widget
/// extension. It shows only the phase and the time, never the task, for the
/// same reason the lock-screen widget never shows plan content.
struct PomodoroActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phaseTitle: String
        var isBreak: Bool
        var startDate: Date
        var endDate: Date
        var isPaused: Bool
        var pausedRemaining: TimeInterval
    }
}
