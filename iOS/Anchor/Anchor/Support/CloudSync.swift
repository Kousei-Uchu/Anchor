import Foundation
import SwiftData

/// Optional iCloud sync between a person's own devices (Patch SY1b, E1).
///
/// Off until the person switches it on. It uses their private CloudKit database only, and only once every field that
/// holds their own words is locked (35b, 35g), so what reaches iCloud is ciphertext. The data key never travels: a
/// second device gets the small recovery file through iCloud's key-value store (the file is sealed under the recovery
/// key, so it is no use without it) and the person types the recovery key there (D40, answer a).
///
/// Nights that Apple Health already holds are not synced (D39). While sync is on, Anchor does not bring nights in from
/// Health, and the nights it had brought in are removed when sync is switched on. Nothing in Health changes.
///
/// The setting is read once, when the store is opened, so a change takes effect the next time Anchor starts.
enum CloudSync {
    static let enabledKey = "anchor.sync.icloud"
    static var containerID: String { AnchorSchema.cloudContainerID }
    private static let recoveryFileKey = "anchor.sync.recoveryfile"
    private static let lockLevelKey = "anchor.sync.locklevel"

    /// True once the person has switched sync on, whether or not it has started yet.
    static var isOn: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    /// What the store was opened with this time. Set by `AnchorSchema.makeContainer`.
    static var openedWithSync: Bool { AnchorSchema.openedWithSync }
    /// True when the store could not be opened with sync and was opened without it, so nothing was lost.
    static var syncFailedToStart: Bool { AnchorSchema.syncFailedToStart }

    /// Sync starts only when it is switched on, the data key is on this device and the words are fully locked.
    static var shouldSyncAtLaunch: Bool {
        guard isOn else { return false }
        guard case .found = DataKeyStore.lookup() else { return false }
        return LockMyData.isOn && !LockMyData.needsMore
    }

    /// Hands the decision to the schema, which the widget also builds and so cannot name this file. Called once, at launch,
    /// before any store is opened.
    static func install() {
        AnchorSchema.syncWanted = { shouldSyncAtLaunch }
    }

    // MARK: What is needed before it can be switched on

    /// Why sync cannot be switched on from this device yet, or nil when it can.
    @MainActor
    static func reasonCannotTurnOn() -> String? {
        let keys = DataKeyManager.shared
        keys.refresh()
        guard keys.status == .ready else {
            return "Set up Encryption first (Settings, Encryption), so there is a key to lock your words with."
        }
        guard LockMyData.isOn, !LockMyData.needsMore else {
            return "Lock my data first, all the way (Settings, Lock my data), so only locked text reaches iCloud."
        }
        if let other = recoveryFileKeyID(), other != RecoveryFile.read().flatMap({ RecoveryBlob.keyID(inBlob: $0) }) {
            return "iCloud already holds a different Anchor key from another device. Use this as a second device instead, or clear everything there first."
        }
        return nil
    }

    // MARK: The recovery file and the locked state, through iCloud's key-value store

    private static var cloud: NSUbiquitousKeyValueStore { NSUbiquitousKeyValueStore.default }

    private static func recoveryFileKeyID() -> Data? {
        cloud.synchronize()
        return cloud.data(forKey: recoveryFileKey).flatMap { RecoveryBlob.keyID(inBlob: $0) }
    }

    /// True when iCloud holds a recovery file from another device.
    static var cloudHasRecoveryFile: Bool {
        cloud.synchronize()
        return cloud.data(forKey: recoveryFileKey)?.count == RecoveryBlob.length
    }

    /// Puts the recovery file and how much is locked where another device can find them. The file is sealed under
    /// the recovery key. Does nothing while sync is off.
    static func publishForOtherDevices() {
        guard isOn, let blob = RecoveryFile.read(), blob.count == RecoveryBlob.length else { return }
        cloud.set(blob, forKey: recoveryFileKey)
        cloud.set(Int64(LockMyData.level), forKey: lockLevelKey)
        cloud.synchronize()
    }

    /// On a device with no key, copies the recovery file from iCloud so the recovery key can be typed. Never replaces
    /// a key that is already here. Returns true when a file was copied.
    @discardableResult
    static func pullRecoveryFile() -> Bool {
        guard isOn else { return false }
        cloud.synchronize()
        guard let blob = cloud.data(forKey: recoveryFileKey), blob.count == RecoveryBlob.length else { return false }
        if RecoveryFile.read() == blob { return true }
        return (try? RecoveryFile.write(blob)) != nil
    }

    /// On a device whose key was just typed in, takes over the locked state from the first device, so what this
    /// device writes is locked too. Only when the key is the same one, and takes effect at the next start.
    @discardableResult
    static func adoptLockedState() -> Bool {
        guard isOn, !LockMyData.isOn, case .found(let key) = DataKeyStore.lookup() else { return false }
        cloud.synchronize()
        guard let blob = cloud.data(forKey: recoveryFileKey),
              RecoveryBlob.keyID(inBlob: blob) == RecoveryBlob.keyID(of: key) else { return false }
        let level = Int(cloud.longLong(forKey: lockLevelKey))
        guard level > 0 else { return false }
        LockMyData.adoptFromOtherDevice(level: level)
        return true
    }

    /// Takes what Anchor put in iCloud's key-value store away (Clear everything).
    static func removeCloudCopies() {
        cloud.removeObject(forKey: recoveryFileKey)
        cloud.removeObject(forKey: lockLevelKey)
        cloud.synchronize()
    }
}
