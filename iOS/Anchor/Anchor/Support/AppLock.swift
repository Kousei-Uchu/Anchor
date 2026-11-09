//
//  AppLock.swift
//  Anchor
//
//  Gates the whole app behind Face ID/passcode, independent of whether the
//  phone itself is currently unlocked — per spec: "app has its own Face
//  ID/passcode lock independent of phone lock state." Re-locks whenever
//  the app goes to the background, so leaving Anchor open on a desk still
//  protects the safety plan/journal from a passing glance.
//
//  Deliberately does NOT lock someone out of their own safety plan if the
//  device has no biometrics or passcode configured at all (a real
//  possibility, and the worst possible failure mode for a safety app would
//  be "can't reach my own crisis numbers because of a security feature") —
//  in that one case it unlocks automatically rather than showing a dead end.
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security
import SwiftUI

@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()

    @Published private(set) var isUnlocked = false
    @Published private(set) var lastAuthError: String?

    /// Guards against a real bug: `.onAppear` and `.onChange(of: scenePhase)`
    /// going to `.active` can both fire `attemptUnlock()` within the same
    /// runloop at cold launch — two concurrent `LAContext` evaluations
    /// stepping on each other is exactly the kind of thing that shows up as
    /// "janky, doesn't quite work, hard to explain why." This flag makes a
    /// second call while one's already in flight a no-op instead of a race.
    private var isAuthenticating = false

    /// Kept so a mid-prompt backgrounding can cleanly cancel the evaluation
    /// (`LAContext.invalidate()`) rather than leaving it dangling.
    private var activeContext: LAContext?

    private static let enabledDefaultsKey = "anchor.appLockEnabled"

    /// Whether the app should even ask for Face ID/passcode. Defaults to
    /// on, but user-toggleable in Settings for cases like: shared device
    /// during onboarding, or Face ID being awkward for someone's setup.
    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledDefaultsKey) }
    }

    private init() {}

    /// Whether this device has Face ID, Touch ID, or even just a passcode
    /// set up at all. Used both to decide whether to show the "Require
    /// Face ID" toggle as meaningful, and to avoid locking someone out
    /// with no way back in.
    ///
    /// Touches no state of the lock, only a fresh `LAContext`, so it can be asked from anywhere,
    /// including the non-isolated `ShowcaseMode`.
    nonisolated func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Called once at launch and whenever the app returns to foreground.
    func lock() {
        guard isEnabled, !ShowcaseMode.isOn else { return }
        // If a Face ID prompt was mid-flight when this fired (e.g. the app
        // was backgrounded while the system sheet was up), cancel it
        // cleanly instead of leaving a stale evaluation dangling.
        activeContext?.invalidate()
        activeContext = nil
        isAuthenticating = false
        isUnlocked = false
    }

    /// If the lock is turned off, or the device genuinely has no
    /// authentication configured, don't block access at all.
    func bypassIfNotApplicable() {
        if !isEnabled || ShowcaseMode.isOn || !canAuthenticate() {
            isUnlocked = true
        }
    }

    /// Asks for Face ID or the passcode again, for the few screens that hold
    /// more than the rest of the app. Returns true straight away when the lock
    /// is switched off or the phone has nothing to ask with, so nobody is shut out.
    func confirmPresence(reason: String) async -> Bool {
        guard isEnabled, !ShowcaseMode.isOn, canAuthenticate() else { return true }
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    func attemptUnlock() async {
        bypassIfNotApplicable()
        guard !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        activeContext = context
        defer { activeContext = nil }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Anchor to see your safety plan and journal."
            )
            isUnlocked = success
            lastAuthError = success ? nil : "Authentication didn't succeed."
        } catch {
            isUnlocked = false
            // Don't show a scary error for a cancellation Anchor itself
            // triggered (e.g. backgrounded mid-prompt via lock()) — only
            // surface errors the user would actually recognize as theirs.
            if let laError = error as? LAError, laError.code == .appCancel {
                lastAuthError = nil
            } else {
                lastAuthError = error.localizedDescription
            }
        }
    }
}

/// Wraps the whole app: shows a lock screen until Face ID/passcode
/// succeeds (or the lock is disabled/unavailable), and re-locks whenever
/// the app leaves the foreground.
struct AppLockGateView<Content: View>: View {
    @StateObject private var lock = AppLock.shared
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
                .opacity(lock.isUnlocked ? 1 : 0)
                .allowsHitTesting(lock.isUnlocked)

            if !lock.isUnlocked {
                AppLockScreenView(lock: lock)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lock.isUnlocked)
        .onAppear {
            lock.bypassIfNotApplicable()
            if !lock.isUnlocked {
                Task { await lock.attemptUnlock() }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lock.lock()
            case .active:
                if !lock.isUnlocked {
                    Task { await lock.attemptUnlock() }
                }
            default:
                break
            }
        }
    }
}

private struct AppLockScreenView: View {
    @ObservedObject var lock: AppLock

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            MascotCharacterView(mood: .neutral)
                .frame(width: 84, height: 84)

            Text("Anchor is locked")
                .font(.system(.title3, design: .rounded).weight(.semibold))

            Text("Face ID keeps this private, independent of your phone's own lock.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let error = lock.lastAuthError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 40)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await lock.attemptUnlock() }
            } label: {
                Label("Unlock", systemImage: "faceid")
            }
            .buttonStyle(Anchor.PrimaryButtonStyle())
            .padding(.horizontal, 60)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .anchorBackground()
    }
}

// MARK: - Showcase mode
//
// Patch 39 is the machinery: while showcase mode is on the app runs on the made-up demo
// store, the real store is not opened on that launch, and the app lock is not asked for
// (the setting itself is left as it was and applies again afterwards). Patch 40a clears what
// could still show real data outside the store (see ShowcaseSweep in AnchorApp.swift) and
// leaves out the share and export controls. Patch 40b adds a passcode of its own (see
// ShowcasePasscode below), the exit flow, and opens it to everyone in Settings, Your data and
// help, Showcase mode.

enum ShowcaseMode {
    private static let defaultsKey = "anchor.showcaseOn"

    /// Kept in the standard defaults, so it survives closing the app: a showcase that
    /// started stays one until it is turned off with the phone's own authentication.
    static var isOn: Bool { UserDefaults.standard.bool(forKey: defaultsKey) }

    static func setOn(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: defaultsKey)
    }

    /// Showcase mode can only be turned on where there is a way back out: Face ID, Touch ID or a
    /// phone passcode.
    static var canTurnOn: Bool { AppLock.shared.canAuthenticate() }

    /// The phone's own Face ID or passcode, asked directly. It does not depend on Anchor's lock
    /// setting, which is not asked for while showcase mode is on, so it cannot be turned off by that.
    static func confirmOwner(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

enum ShowcasePasscodeError: Error, Equatable {
    case tooShort
    /// Anything other than digits.
    case notDigits
    case storage
}

/// A passcode of its own for showing the app (Patch 40b). It is only one more way to turn showcase
/// mode off. The phone's own Face ID or passcode always works as well, so forgetting this one never
/// leaves anyone stuck. Only a salted PBKDF2 hash is kept, never the passcode itself, in this
/// device's Keychain (after first unlock, this device only), so it stays out of backups.
///
/// Wrong tries are slowed down: after four wrong ones in a row the fifth starts a wait of 30 seconds,
/// and each wrong try after that doubles it, up to 15 minutes. The wait never applies to the phone's
/// own Face ID or passcode.
enum ShowcasePasscode {
    enum Check: Equatable {
        case correct
        case wrong
        /// Too many wrong tries for now.
        case wait(seconds: Int)
        /// The Keychain cannot be read or holds something unexpected. The phone's own Face ID or
        /// passcode is still there.
        case unavailable
    }

    static let minimumLength = 4
    static let maximumLength = 6

    /// Only the digits of what was typed, at most six, so the number pad and a paste both come out right.
    static func digits(_ text: String) -> String {
        String(text.filter { $0.isASCII && $0.isNumber }.prefix(maximumLength))
    }

    private static let service = "page.aspens.anchor.showcasepasscode"
    private static let account = "passcode"
    private static let formatVersion: UInt8 = 1
    private static let iterations: UInt32 = 200_000
    private static let blobLength = 1 + 4 + 16 + 32
    private static let freeTries = 4
    private static let failsKey = "anchor.showcasePasscodeFails"
    private static let waitUntilKey = "anchor.showcasePasscodeWaitUntil"

    private static func query() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func stored() -> Data? {
        var request = query()
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static var isSet: Bool { stored() != nil }

    /// Seconds left of a wait after too many wrong tries, or 0.
    static var waitRemaining: Int {
        let until = UserDefaults.standard.double(forKey: waitUntilKey)
        let left = until - Date().timeIntervalSince1970
        return left > 0 ? Int(left.rounded(.up)) : 0
    }

    /// Sets the passcode, or replaces the one there.
    static func set(_ passcode: String) throws {
        guard passcode.allSatisfy({ $0.isASCII && $0.isNumber }), passcode.count <= maximumLength else {
            throw ShowcasePasscodeError.notDigits
        }
        guard passcode.count >= minimumLength else { throw ShowcasePasscodeError.tooShort }
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        guard let key = BackupFormat.deriveKey(password: passcode, salt: salt, iterations: iterations) else {
            throw ShowcasePasscodeError.storage
        }
        var blob = Data([formatVersion])
        blob.append(BackupFormat.bigEndian(UInt64(iterations), bytes: 4))
        blob.append(salt)
        blob.append(key.withUnsafeBytes { Data($0) })

        var attributes = query()
        attributes[kSecValueData as String] = blob
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        var status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let change: [String: Any] = [kSecValueData as String: blob]
            status = SecItemUpdate(query() as CFDictionary, change as CFDictionary)
        }
        guard status == errSecSuccess else { throw ShowcasePasscodeError.storage }
        clearFailures()
    }

    static func remove() {
        SecItemDelete(query() as CFDictionary)
        clearFailures()
    }

    static func check(_ attempt: String) -> Check {
        let waiting = waitRemaining
        if waiting > 0 { return .wait(seconds: waiting) }
        guard let blob = stored(), blob.count == blobLength, blob[0] == formatVersion else { return .unavailable }
        let rounds = UInt32(truncatingIfNeeded: BackupFormat.number(blob.subdata(in: 1..<5)))
        guard rounds >= 10_000, rounds <= 5_000_000 else { return .unavailable }
        let salt = blob.subdata(in: 5..<21)
        let expected = blob.subdata(in: 21..<53)
        guard let key = BackupFormat.deriveKey(password: attempt, salt: salt, iterations: rounds) else {
            return .wrong
        }
        let actual = key.withUnsafeBytes { Data($0) }
        if sameBytes(actual, expected) {
            clearFailures()
            return .correct
        }
        registerFailure()
        let nowWaiting = waitRemaining
        return nowWaiting > 0 ? .wait(seconds: nowWaiting) : .wrong
    }

    private static func sameBytes(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for (x, y) in zip(a, b) { difference |= x ^ y }
        return difference == 0
    }

    private static func registerFailure() {
        let defaults = UserDefaults.standard
        let fails = defaults.integer(forKey: failsKey) + 1
        defaults.set(fails, forKey: failsKey)
        if fails > freeTries {
            let doublings = min(fails - freeTries - 1, 5)
            let seconds = min(30 * (1 << doublings), 900)
            defaults.set(Date().timeIntervalSince1970 + Double(seconds), forKey: waitUntilKey)
        }
    }

    private static func clearFailures() {
        UserDefaults.standard.removeObject(forKey: failsKey)
        UserDefaults.standard.removeObject(forKey: waitUntilKey)
    }
}

extension View {
    /// Leaves out a control for sharing or exporting while showcase mode is on. The system share sheet
    /// lists the phone's own people and recent contacts, and a file made from made-up content is of
    /// no use to anyone.
    @ViewBuilder
    func hiddenInShowcase() -> some View {
        if ShowcaseMode.isOn {
            EmptyView()
        } else {
            self
        }
    }
}

// MARK: - The data key
//
// Patch 34 makes the key that Patch 35 will use to lock what Anchor stores. The
// formats are written out in docs/ENCRYPTION.md, and scripts/anchorkey.py is the
// same thing in running form; a debug build checks this code against it
// (DataKeySelfTest). Nothing here encrypts any stored text yet.

enum DataKeyError: Error, Equatable {
    /// Typed wrongly: not 28 usable characters, or the check characters do not fit.
    case notARecoveryKey
    /// Typed correctly in form, but it does not open the recovery file.
    case wrongRecoveryKey
    case damagedFile
    case noRecoveryFile
    /// The recovery file was made for a different key than the one on this device.
    case otherKey
    case noKey
    case alreadySetUp
    /// The Keychain or the file could not be written.
    case storage
}

/// The recovery key as people read and type it: 16 random bytes as 26 characters of
/// Crockford base32, then two check characters, in seven groups of four.
enum RecoveryKeyText {
    private static let alphabet: [Character] = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    private static func checkCharacters(for bytes: [UInt8]) -> [Character] {
        let digest = Array(SHA256.hash(data: bytes))
        let first = Int(digest[0] >> 3)
        let second = Int(((digest[0] & 0x07) << 2) | (digest[1] >> 6))
        return [alphabet[first], alphabet[second]]
    }

    static func text(for raw: Data) -> String {
        let bytes = [UInt8](raw)
        guard bytes.count == 16 else { return "" }
        var characters: [Character] = []
        var index = 0
        while index < 130 {
            var value = 0
            for offset in 0..<5 {
                let bit = index + offset
                let isSet = bit < 128 && ((bytes[bit / 8] >> UInt8(7 - bit % 8)) & 1) == 1
                value = (value << 1) | (isSet ? 1 : 0)
            }
            characters.append(alphabet[value])
            index += 5
        }
        characters.append(contentsOf: checkCharacters(for: bytes))
        var groups: [String] = []
        var start = 0
        while start < characters.count {
            groups.append(String(characters[start..<(start + 4)]))
            start += 4
        }
        return groups.joined(separator: "-")
    }

    /// Upper case, without spaces or hyphens, with O read as 0 and I or L read as 1.
    static func canonical(_ text: String) -> String {
        var result = ""
        for character in text.uppercased() {
            if character.isWhitespace || character == "-" { continue }
            if character == "O" {
                result.append("0")
            } else if character == "I" || character == "L" {
                result.append("1")
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// The 16 bytes, or nil when the text is not a whole recovery key.
    static func raw(from text: String) -> Data? {
        let cleaned = Array(canonical(text))
        guard cleaned.count == 28 else { return nil }
        var values: [Int] = []
        for character in cleaned {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            values.append(value)
        }
        var bits: [UInt8] = []
        for value in values[0..<26] {
            for shift in stride(from: 4, through: 0, by: -1) {
                bits.append(UInt8((value >> shift) & 1))
            }
        }
        guard bits[128] == 0, bits[129] == 0 else { return nil }
        var bytes: [UInt8] = []
        var index = 0
        while index < 128 {
            var byte: UInt8 = 0
            for offset in 0..<8 {
                byte = (byte << 1) | bits[index + offset]
            }
            bytes.append(byte)
            index += 8
        }
        let given = values[26..<28].map { alphabet[$0] }
        guard given == checkCharacters(for: bytes) else { return nil }
        return Data(bytes)
    }
}

/// The small file kept beside the store that holds the data key, sealed under the
/// recovery key. It goes with the phone's own backups, so a restored phone still has
/// it, while the data key itself stays in this device's Keychain.
enum RecoveryBlob {
    static let magic = Data("ANCHORKY".utf8)
    static let version: UInt8 = 1
    static let length = 93

    static func keyID(of master: SymmetricKey) -> Data {
        var input = Data("anchor key id".utf8)
        input.append(master.withUnsafeBytes { Data($0) })
        return Data(SHA256.hash(data: input).prefix(8))
    }

    private static func wrappingKey(recovery: Data, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: recovery),
            salt: salt,
            info: Data("anchor recovery key v1".utf8),
            outputByteCount: 32
        )
    }

    static func make(master: SymmetricKey, recovery: Data) throws -> Data {
        guard recovery.count == 16 else { throw DataKeyError.notARecoveryKey }
        let salt = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
        var header = magic
        header.append(version)
        header.append(keyID(of: master))
        let masterBytes = master.withUnsafeBytes { Data($0) }
        guard let box = try? AES.GCM.seal(
            masterBytes,
            using: wrappingKey(recovery: recovery, salt: salt),
            authenticating: header
        ) else { throw DataKeyError.storage }
        var blob = header
        blob.append(salt)
        blob.append(Data(box.nonce))
        blob.append(box.ciphertext)
        blob.append(box.tag)
        return blob
    }

    static func open(_ blob: Data, recovery: Data) throws -> SymmetricKey {
        guard blob.count == length, recovery.count == 16 else { throw DataKeyError.damagedFile }
        let bytes = [UInt8](blob)
        guard Data(bytes[0..<8]) == magic, bytes[8] == version else { throw DataKeyError.damagedFile }
        let header = Data(bytes[0..<17])
        let salt = Data(bytes[17..<33])
        guard let nonce = try? AES.GCM.Nonce(data: Data(bytes[33..<45])),
              let box = try? AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: Data(bytes[45..<77]),
                tag: Data(bytes[77..<93])
              ) else { throw DataKeyError.damagedFile }
        guard let plain = try? AES.GCM.open(
            box,
            using: wrappingKey(recovery: recovery, salt: salt),
            authenticating: header
        ) else { throw DataKeyError.wrongRecoveryKey }
        let master = SymmetricKey(data: plain)
        guard plain.count == 32, keyID(of: master) == Data(bytes[9..<17]) else { throw DataKeyError.damagedFile }
        return master
    }

    static func keyID(inBlob blob: Data) -> Data? {
        guard blob.count == length else { return nil }
        return Data([UInt8](blob)[9..<17])
    }
}

/// Seals and opens one piece of text with the data key. A sealed value is
/// "anchor.sealed.v1:" and then base64 of nonce, ciphertext and tag. The context
/// (such as "JournalEntry.text") is authenticated, so a sealed value cannot be moved
/// into another field. A value counts as sealed only if it has the prefix AND opens,
/// so ordinary text that happens to start with the prefix is still read as text.
enum FieldCipher {
    static let prefix = "anchor.sealed.v1:"

    static func looksSealed(_ stored: String) -> Bool {
        stored.hasPrefix(prefix)
    }

    static func seal(_ text: String, context: String, key: SymmetricKey) throws -> String {
        guard let box = try? AES.GCM.seal(Data(text.utf8), using: key, authenticating: Data(context.utf8)),
              let combined = box.combined else { throw DataKeyError.storage }
        return prefix + combined.base64EncodedString()
    }

    /// The text, or nil when the value is not sealed or does not open with this key and context.
    static func open(_ stored: String, context: String, key: SymmetricKey) -> String? {
        guard stored.hasPrefix(prefix),
              let combined = Data(base64Encoded: String(stored.dropFirst(prefix.count))),
              combined.count >= 28,
              let box = try? AES.GCM.SealedBox(combined: combined),
              let plain = try? AES.GCM.open(box, using: key, authenticating: Data(context.utf8))
        else { return nil }
        return String(data: plain, encoding: .utf8)
    }
}

enum KeyLookup {
    case found(SymmetricKey)
    case missing
    /// The Keychain cannot be read right now, such as before the first unlock after a restart.
    /// This is not the same as missing, and must never lead to a new key being made.
    case unavailable
}

/// Keeps the data key in this device's Keychain. After first unlock and this device
/// only, which matches the store's own file protection, so a notification action that
/// starts the app while the phone is locked can still read it, and the key does not
/// travel in a backup or to another device.
enum DataKeyStore {
    private static let service = "page.aspens.anchor.datakey"
    private static let account = "master"

    private static func query() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func lookup() -> KeyLookup {
        var request = query()
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return .missing }
        guard status == errSecSuccess, let data = result as? Data, data.count == 32 else { return .unavailable }
        return .found(SymmetricKey(data: data))
    }

    static func save(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        var attributes = query()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        var status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let change: [String: Any] = [kSecValueData as String: data]
            status = SecItemUpdate(query() as CFDictionary, change as CFDictionary)
        }
        guard status == errSecSuccess else { throw DataKeyError.storage }
    }

    static func remove() {
        SecItemDelete(query() as CFDictionary)
    }
}

enum RecoveryFile {
    static var url: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Keys", isDirectory: true)
            .appendingPathComponent("recovery.anchorkey")
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    static func read() -> Data? {
        try? Data(contentsOf: url)
    }

    /// Written in one step, so the old file stays until the new one is complete.
    static func write(_ blob: Data) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        try blob.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// What the screens read and change. The recovery key is returned once by `setUp` and
/// `makeNewRecoveryKey` and is never kept: only the recovery file is, and it cannot be
/// opened without the key.
@MainActor
final class DataKeyManager: ObservableObject {
    static let shared = DataKeyManager()

    enum Status: Equatable {
        case notSetUp
        case ready
        /// The recovery file is here but the key is not on this device.
        case needsRecovery
        /// The Keychain cannot be read right now.
        case unavailable
    }

    @Published private(set) var status: Status = .notSetUp
    @Published private(set) var hasRecoveryFile = false

    private init() {
        refresh()
    }

    func refresh() {
        hasRecoveryFile = RecoveryFile.exists
        switch DataKeyStore.lookup() {
        case .found:
            status = .ready
        case .missing:
            status = hasRecoveryFile ? .needsRecovery : .notSetUp
        case .unavailable:
            status = .unavailable
        }
    }

    /// Makes the data key and the recovery file together and returns the recovery key,
    /// to show once. If either part cannot be saved, neither is kept.
    func setUp() throws -> String {
        refresh()
        guard status == .notSetUp else { throw DataKeyError.alreadySetUp }
        let master = SymmetricKey(size: .bits256)
        let recovery = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
        let blob = try RecoveryBlob.make(master: master, recovery: recovery)
        do {
            try RecoveryFile.write(blob)
        } catch {
            throw DataKeyError.storage
        }
        do {
            try DataKeyStore.save(master)
        } catch {
            RecoveryFile.remove()
            throw DataKeyError.storage
        }
        refresh()
        return RecoveryKeyText.text(for: recovery)
    }

    /// A new recovery key for the same data key. The old recovery key stops working
    /// once the new file is in place.
    func makeNewRecoveryKey() throws -> String {
        guard case .found(let master) = DataKeyStore.lookup() else { throw DataKeyError.noKey }
        let recovery = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
        let blob = try RecoveryBlob.make(master: master, recovery: recovery)
        do {
            try RecoveryFile.write(blob)
        } catch {
            throw DataKeyError.storage
        }
        refresh()
        return RecoveryKeyText.text(for: recovery)
    }

    /// Checks a typed recovery key against the file, changing nothing.
    func checkRecoveryKey(_ text: String) throws {
        guard let recovery = RecoveryKeyText.raw(from: text) else { throw DataKeyError.notARecoveryKey }
        guard let blob = RecoveryFile.read() else { throw DataKeyError.noRecoveryFile }
        let master = try RecoveryBlob.open(blob, recovery: recovery)
        if case .found(let current) = DataKeyStore.lookup(),
           RecoveryBlob.keyID(of: current) != RecoveryBlob.keyID(of: master) {
            throw DataKeyError.otherKey
        }
    }

    /// Puts the data key back on this device from the recovery file and the recovery key.
    /// Only when the key is missing: a key that is already here is never replaced.
    func restore(with text: String) throws {
        refresh()
        guard status == .needsRecovery else { throw DataKeyError.alreadySetUp }
        guard let recovery = RecoveryKeyText.raw(from: text) else { throw DataKeyError.notARecoveryKey }
        guard let blob = RecoveryFile.read() else { throw DataKeyError.noRecoveryFile }
        let master = try RecoveryBlob.open(blob, recovery: recovery)
        try DataKeyStore.save(master)
        refresh()
    }

    #if DEBUG
    /// For test builds only. With nothing locked yet this loses nothing.
    func removeEverything() {
        DataKeyStore.remove()
        RecoveryFile.remove()
        refresh()
    }
    #endif
}

#if DEBUG
/// Checks this code against the vectors printed by `python3 scripts/anchorkey.py vectors`,
/// so a debug build proves the Swift and the reference agree. It stops the app with a
/// message if they do not. Only compiled into debug builds.
enum DataKeySelfTest {
    private static let masterHex = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    private static let recoveryHex = "101112131415161718191a1b1c1d1e1f"
    private static let recoveryText = "208H-44RM-2MB1-E60S-38DH-R78Y-3WZG"
    private static let blobHex = "414e43484f524b590106b8de366163df2a202122232425262728292a2b2c2d2e2f303132333435363738393a3b72ac23a63424f2381959c97ef381ed0152b076c7a30d22e44fc12bb2705fe25490f11f945722796b37c4b37110bfa535"
    private static let keyIDHex = "06b8de366163df2a"
    private static let context = "JournalEntry.text"
    private static let sealed = "anchor.sealed.v1:QEFCQ0RFRkdISUpLpNzCVwZI4m2+oTdU/gJ8KRzmJjTSFWxCGytuBxeHzbLsKITJsM3/NkSAfwrjLauyqh+KeBOimnnkeaBhQ8QIIniAt4LISi47Nj7A/FG3uTNbsw=="
    private static let text = "Felt tense before the call \u{2014} it went better than I expected. \u{2713}"

    private static var hasRun = false

    private static func bytes(_ hex: String) -> Data {
        let characters = Array(hex)
        var result = Data()
        var index = 0
        while index + 1 < characters.count {
            if let value = UInt8(String(characters[index...(index + 1)]), radix: 16) {
                result.append(value)
            }
            index += 2
        }
        return result
    }

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Data key self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let master = SymmetricKey(data: bytes(masterHex))
        let recovery = bytes(recoveryHex)

        check(RecoveryKeyText.text(for: recovery) == recoveryText, "the recovery key text differs from the reference.")
        check(RecoveryKeyText.raw(from: recoveryText) == recovery, "the recovery key text did not read back.")
        check(RecoveryKeyText.raw(from: recoveryText.lowercased().replacingOccurrences(of: "-", with: " ")) == recovery,
              "a lower case recovery key with spaces was not accepted.")
        check(RecoveryKeyText.raw(from: "3" + String(recoveryText.dropFirst())) == nil, "a changed character was accepted.")
        check(RecoveryKeyText.raw(from: String(recoveryText.dropLast())) == nil, "a short recovery key was accepted.")
        check(RecoveryKeyText.raw(from: "") == nil, "an empty recovery key was accepted.")

        let blob = bytes(blobHex)
        check(RecoveryBlob.keyID(of: master) == bytes(keyIDHex), "the key id differs from the reference.")
        check(RecoveryBlob.keyID(inBlob: blob) == bytes(keyIDHex), "the key id in the file differs from the reference.")
        do {
            let opened = try RecoveryBlob.open(blob, recovery: recovery)
            check(opened.withUnsafeBytes { Data($0) } == bytes(masterHex), "the recovery file opened to the wrong key.")
        } catch {
            fatalError("Data key self-test: the reference recovery file did not open: \(error)")
        }
        do {
            _ = try RecoveryBlob.open(blob, recovery: Data(count: 16))
            fatalError("Data key self-test: the wrong recovery key opened the file.")
        } catch DataKeyError.wrongRecoveryKey {
        } catch {
            fatalError("Data key self-test: the wrong recovery key gave the wrong error: \(error)")
        }
        var damaged = blob
        damaged[damaged.count - 1] ^= 1
        do {
            _ = try RecoveryBlob.open(damaged, recovery: recovery)
            fatalError("Data key self-test: a changed file opened.")
        } catch {
        }
        do {
            let fresh = SymmetricKey(size: .bits256)
            let freshRecovery = SymmetricKey(size: .bits128).withUnsafeBytes { Data($0) }
            let made = try RecoveryBlob.make(master: fresh, recovery: freshRecovery)
            let back = try RecoveryBlob.open(made, recovery: freshRecovery)
            check(back.withUnsafeBytes { Data($0) } == fresh.withUnsafeBytes { Data($0) }, "a new recovery file did not open.")
            check(RecoveryKeyText.raw(from: RecoveryKeyText.text(for: freshRecovery)) == freshRecovery,
                  "a new recovery key did not read back.")
        } catch {
            fatalError("Data key self-test: a new recovery file could not be made or opened: \(error)")
        }

        check(FieldCipher.open(sealed, context: context, key: master) == text, "the sealed reference text did not open.")
        check(FieldCipher.open(sealed, context: "JournalEntry.title", key: master) == nil, "a sealed value opened in another context.")
        check(FieldCipher.open(sealed, context: context, key: SymmetricKey(data: Data(count: 32))) == nil,
              "a sealed value opened with another key.")
        check(FieldCipher.open(text, context: context, key: master) == nil, "plain text was read as sealed.")
        check(FieldCipher.looksSealed(sealed) && !FieldCipher.looksSealed(text), "looksSealed is wrong.")
        do {
            for sample in ["", "a", "caf\u{e9}", "line one\nline two", FieldCipher.prefix + "abc"] {
                let first = try FieldCipher.seal(sample, context: "Field.x", key: master)
                let second = try FieldCipher.seal(sample, context: "Field.x", key: master)
                check(first != second, "two seals of the same text were identical.")
                check(FieldCipher.open(first, context: "Field.x", key: master) == sample, "a sealed value did not read back.")
            }
        } catch {
            fatalError("Data key self-test: sealing failed: \(error)")
        }
    }
}
#endif
