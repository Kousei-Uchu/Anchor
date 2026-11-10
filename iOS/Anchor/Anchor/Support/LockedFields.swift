import Foundation
import SwiftData

/// How a stored field reads and writes once it can be locked (Patch 35b2, D15).
///
/// Every locked field on a model is two stored properties: the plain one (`textPlain`) and its sealed twin
/// (`textSealed`). The old name (`text`) is a computed property that goes through here. While locking is off,
/// which is the case until Patch 35b3, `store` keeps the text in the plain property and clears the sealed
/// one, and `read` returns the plain property, so everything behaves as it did before.
///
/// Compiled into the app and the widget extension (the extension builds the model files too), so it holds no
/// key code. The app hands it two small functions at launch (`FieldLockWiring.install`, in AppLock.swift); the
/// extension never does, so a sealed value is simply not opened there.
enum FieldLock {
    /// Whether new writes are sealed. False in 35b2, so nothing is locked. 35b3 turns this on only at the
    /// end of the Lock my data flow, once every item has been checked.
    nonisolated(unsafe) static var isOn = false

    /// Seals a piece of text for a context such as `JournalEntry.text`. Nil when there is no key.
    nonisolated(unsafe) static var sealer: ((_ text: String, _ context: String) -> String?)?

    /// Opens a sealed value for its context. Nil when the value does not open or there is no key.
    nonisolated(unsafe) static var opener: ((_ stored: String, _ context: String) -> String?)?

    // MARK: Text

    static func read(plain: String, sealed: String?, context: String) -> String {
        guard let sealed, !sealed.isEmpty else { return plain }
        return opener?(sealed, context) ?? plain
    }

    /// What to keep for a new value: the text in the plain property, or an empty plain property and the
    /// sealed text. If sealing is wanted but fails, the text stays plain, so a write is never lost.
    static func store(_ text: String, context: String) -> (plain: String, sealed: String?) {
        if isOn, let sealed = sealer?(text, context) { return ("", sealed) }
        return (text, nil)
    }

    // MARK: Optional text

    static func readOptional(plain: String?, sealed: String?, context: String) -> String? {
        guard let sealed, !sealed.isEmpty else { return plain }
        return opener?(sealed, context) ?? plain
    }

    static func storeOptional(_ text: String?, context: String) -> (plain: String?, sealed: String?) {
        guard let text else { return (nil, nil) }
        if isOn, let sealed = sealer?(text, context) { return (nil, sealed) }
        return (text, nil)
    }

    // MARK: Lists of small records

    static func readCoded<T: Codable>(_ plain: [T], sealed: String?, context: String) -> [T] {
        guard let sealed, !sealed.isEmpty,
              let json = opener?(sealed, context),
              let list = try? JSONDecoder().decode([T].self, from: Data(json.utf8)) else { return plain }
        return list
    }

    static func storeCoded<T: Codable>(_ list: [T], empty: [T], context: String) -> (plain: [T], sealed: String?) {
        guard isOn, let data = try? JSONEncoder().encode(list),
              let json = String(data: data, encoding: .utf8),
              let sealed = sealer?(json, context) else { return (list, nil) }
        return (empty, sealed)
    }

    // MARK: Data

    static func readData(_ plain: Data, sealed: String?, context: String) -> Data {
        guard let sealed, !sealed.isEmpty,
              let encoded = opener?(sealed, context),
              let data = Data(base64Encoded: encoded) else { return plain }
        return data
    }

    static func storeData(_ data: Data, context: String) -> (plain: Data, sealed: String?) {
        if isOn, let sealed = sealer?(data.base64EncodedString(), context) { return (Data(), sealed) }
        return (data, nil)
    }
}

// MARK: - Dates, numbers, marks and choices (Patch 35g1a, D44)

/// A single value that is sealed as a short piece of text: a date, a whole number, a decimal number or a mark.
/// The text must give back exactly the same value, so a locked date is the same moment when it is opened.
protocol LockedScalar {
    /// The value written as text.
    var lockedText: String { get }
    /// The value from that text, or nil if the text is not one.
    static func fromLockedText(_ text: String) -> Self?
    /// What the plain property holds while the real value is sealed. It is the same for every item, so the stored
    /// file says nothing about any of them.
    static var lockedPlaceholder: Self { get }
}

extension Date: LockedScalar {
    var lockedText: String { String(timeIntervalSinceReferenceDate) }
    static func fromLockedText(_ text: String) -> Date? {
        Double(text).map { Date(timeIntervalSinceReferenceDate: $0) }
    }
    static var lockedPlaceholder: Date { Date(timeIntervalSinceReferenceDate: 0) }
}

extension Int: LockedScalar {
    var lockedText: String { String(self) }
    static func fromLockedText(_ text: String) -> Int? { Int(text) }
    static var lockedPlaceholder: Int { 0 }
}

extension Double: LockedScalar {
    var lockedText: String { String(self) }
    static func fromLockedText(_ text: String) -> Double? { Double(text) }
    static var lockedPlaceholder: Double { 0 }
}

extension Bool: LockedScalar {
    var lockedText: String { self ? "1" : "0" }
    static func fromLockedText(_ text: String) -> Bool? {
        switch text {
        case "1": return true
        case "0": return false
        default: return nil
        }
    }
    static var lockedPlaceholder: Bool { false }
}

/// One choice from a fixed list, such as how strong an urge was, sealed as its raw text. A model that locks one
/// says which case the plain property holds while the real choice is sealed.
protocol LockedChoice: RawRepresentable where RawValue == String {
    static var lockedPlaceholder: Self { get }
}

extension FieldLock {
    // MARK: Dates, whole numbers, decimal numbers and marks

    static func readScalar<T: LockedScalar>(plain: T, sealed: String?, context: String) -> T {
        guard let sealed, !sealed.isEmpty,
              let opened = opener?(sealed, context),
              let value = T.fromLockedText(opened) else { return plain }
        return value
    }

    /// What to keep for a new value: the value in the plain property, or the placeholder and the sealed text. If
    /// sealing is wanted but fails, the value stays plain, so a write is never lost.
    static func storeScalar<T: LockedScalar>(_ value: T, context: String) -> (plain: T, sealed: String?) {
        if isOn, let sealed = sealer?(value.lockedText, context) { return (T.lockedPlaceholder, sealed) }
        return (value, nil)
    }

    // MARK: The same, when there may be no value

    /// A sealed value that is nothing is kept as "-" and one that is something as "=" and its text, so the sealed
    /// twin is there either way and "nothing" does not look like "not locked yet".
    static func readOptionalScalar<T: LockedScalar>(plain: T?, sealed: String?, context: String) -> T? {
        guard let sealed, !sealed.isEmpty, let opened = opener?(sealed, context) else { return plain }
        if opened == "-" { return nil }
        guard opened.hasPrefix("="), let value = T.fromLockedText(String(opened.dropFirst())) else { return plain }
        return value
    }

    static func storeOptionalScalar<T: LockedScalar>(_ value: T?, context: String) -> (plain: T?, sealed: String?) {
        let text = value.map { "=" + $0.lockedText } ?? "-"
        if isOn, let sealed = sealer?(text, context) { return (nil, sealed) }
        return (value, nil)
    }

    // MARK: One choice from a fixed list

    static func readChoice<T: LockedChoice>(plain: T, sealed: String?, context: String) -> T {
        guard let sealed, !sealed.isEmpty,
              let opened = opener?(sealed, context),
              let value = T(rawValue: opened) else { return plain }
        return value
    }

    static func storeChoice<T: LockedChoice>(_ value: T, context: String) -> (plain: T, sealed: String?) {
        if isOn, let sealed = sealer?(value.rawValue, context) { return (T.lockedPlaceholder, sealed) }
        return (value, nil)
    }

    // MARK: Describing a value for the Lock my data check

    static func describe(_ value: Date) -> String { "t:" + value.lockedText }
    static func describe(_ value: Date?) -> String { value.map { "t:" + $0.lockedText } ?? "nil" }
    static func describe(_ value: Int) -> String { "i:" + value.lockedText }
    static func describe(_ value: Int?) -> String { value.map { "i:" + $0.lockedText } ?? "nil" }
    static func describe(_ value: Double) -> String { "n:" + value.lockedText }
    static func describe(_ value: Bool) -> String { "b:" + value.lockedText }
    static func describe<T: LockedChoice>(_ value: T) -> String { "c:" + value.rawValue }
}

extension Sequence {
    /// Sorts by a key that is worked out once for each item, not at every comparison, and keeps items with the same
    /// key in the order they came. A locked date or number is opened every time it is read, so a screen that sorts
    /// on one uses this and not a comparison that reads it again and again (Patch 35g1a).
    func sortedByKey<K: Comparable>(descending: Bool = false, _ key: (Element) -> K) -> [Element] {
        let keyed = enumerated().map { (index: $0.offset, key: key($0.element), element: $0.element) }
        return keyed.sorted { a, b in
            if a.key == b.key { return a.index < b.index }
            return descending ? a.key > b.key : a.key < b.key
        }.map { $0.element }
    }
}

// MARK: - Locking what is already stored (Patch 35b3)

/// A model with locked fields, as Lock my data sees it (`Support/LockMyData.swift`). The three methods are written
/// next to each model's `lockNewValues()`, and `scripts/check-locked-fields.mjs` keeps the list of models in
/// `LockMyData.kinds` complete.
protocol LockableModel: PersistentModel {
    /// Seals what is stored plain, leaves anything sealed alone, and does nothing while locking is off.
    func lockExistingValues()
    /// What every locked field reads as, through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String
    /// True when every locked field is held sealed with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool
}

extension FieldLock {
    static func describe(_ value: String) -> String { "s:" + value }
    static func describe(_ value: String?) -> String { value.map { "s:" + $0 } ?? "nil" }
    static func describe<T>(_ list: [T]) -> String { "l:" + String(describing: list) }
    static func describe(_ data: Data) -> String { "d:" + data.base64EncodedString() }

    /// One piece of text for a whole item. The separator cannot be typed into a text field by accident, and a
    /// change in any one field changes the result.
    static func join(_ parts: [String]) -> String {
        parts.joined(separator: "\u{1F}")
    }
}
