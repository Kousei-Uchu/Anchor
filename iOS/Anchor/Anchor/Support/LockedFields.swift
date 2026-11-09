import Foundation

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
