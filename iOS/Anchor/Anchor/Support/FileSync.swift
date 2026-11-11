import Foundation
import CloudKit

/// Voice notes and Journal photos in iCloud sync (Patch SY2, E1).
///
/// Off until the person switches it on, inside Settings, iCloud sync, and only while sync itself is running and Lock my
/// files is complete. Only a file that is already sealed (`FileCipher`) is ever sent, so iCloud holds ciphertext and
/// nothing else. The key stays on the devices (CloudSync). Files travel as CloudKit assets in one zone of the person's
/// private database, apart from the rows, which SwiftData syncs by itself.
///
/// What it does, and does not do:
/// - It sends a sealed file that iCloud does not hold yet, and brings in a file that was sent from another device and is
///   missing here. A file that is already here is never replaced.
/// - A voice note deleted in Anchor is deleted from iCloud, and then from the other devices. A file that is only missing
///   from this phone (a safety copy put back, say) is not taken as a delete.
/// - A file that came from iCloud is kept only if it is sealed and opens with the key on this phone, and its name must stay
///   inside its folder.
/// - It never stops anything else: an error leaves the files where they are and the next start tries again.
enum FileSync {
    static let enabledKey = "anchor.sync.files"
    private static let tokenKey = "anchor.sync.files.token"
    private static let knownKey = "anchor.sync.files.known"
    private static let deletedKey = "anchor.sync.files.deleted"
    static let lastKey = "anchor.sync.files.last"
    private static let recordType = "StoredFile"
    private static let zoneName = "AnchorFiles"
    private static let perRun = 25
    private static let defaults = UserDefaults.standard

    private static var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName) }
    private static var database: CKDatabase { CKContainer(identifier: CloudSync.containerID).privateCloudDatabase }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var running = false
    nonisolated(unsafe) private static var lastStarted = Date.distantPast

    // MARK: Whether it is on

    /// True when the person switched it on, and sync is running this time.
    static var isOn: Bool {
        defaults.bool(forKey: enabledKey) && CloudSync.isOn && CloudSync.openedWithSync
    }

    /// Why it cannot be switched on yet, or nil when it can. Read-only, because a screen asks this while it is drawn.
    static func reasonCannotTurnOn() -> String? {
        guard CloudSync.isOn, CloudSync.openedWithSync else {
            return "Turn on iCloud sync above and start it first (close Anchor and open it again)."
        }
        guard LockMyFiles.isOn else {
            return "Lock my files first (Settings, Lock my data), so only locked files reach iCloud."
        }
        return nil
    }

    // MARK: Names

    private static func recordName(_ folder: StoredFiles.Folder, _ name: String) -> String { folder.label + "." + name }

    private static func parse(_ recordName: String) -> (StoredFiles.Folder, String)? {
        guard let dot = recordName.firstIndex(of: ".") else { return nil }
        let label = String(recordName[..<dot]), name = String(recordName[recordName.index(after: dot)...])
        guard let folder = StoredFiles.Folder.allCases.first(where: { $0.label == label }),
              StoredFiles.isPlainName(name) else { return nil }
        return (folder, name)
    }

    /// CloudKit record names are plain ASCII and cannot start with an underscore.
    private static func usable(_ name: String) -> Bool {
        StoredFiles.isPlainName(name) && !name.hasPrefix("_") && name.utf8.allSatisfy { $0 < 128 && $0 > 32 }
    }

    private static func list(_ key: String) -> Set<String> { Set(defaults.stringArray(forKey: key) ?? []) }
    private static func keep(_ set: Set<String>, _ key: String) {
        if set.isEmpty { defaults.removeObject(forKey: key) } else { defaults.set(Array(set).sorted(), forKey: key) }
    }

    // MARK: A voice note was deleted

    /// Called when a voice note is deleted in Anchor, so iCloud and the other devices let it go too. Does nothing while
    /// this is off.
    static func noteDeleted(_ folder: StoredFiles.Folder, _ name: String) {
        guard isOn, usable(name) else { return }
        var pending = list(deletedKey)
        pending.insert(recordName(folder, name))
        keep(pending, deletedKey)
    }

    // MARK: Running

    /// Starts a pass in the background, at most once a minute and never two at once. Safe to call at every foreground.
    static func startIfDue(force: Bool = false) {
        guard isOn, !DemoMode.isOn, FileLock.isOn, LockMyFiles.isOn else { return }
        lock.lock()
        if running || (!force && Date().timeIntervalSince(lastStarted) < 60) {
            lock.unlock()
            return
        }
        running = true
        lastStarted = Date()
        lock.unlock()
        Task.detached(priority: .utility) {
            let result = await run()
            defaults.set(result, forKey: lastKey)
            lock.lock()
            running = false
            lock.unlock()
        }
    }

    /// One pass: bring in what is new, send what is sealed and not there, then let go of deleted notes.
    private static func run() async -> String {
        do {
            try await ensureZone()
            let received = try await pull()
            let sent = try await push()
            try await pushDeletes()
            return "Sent \(sent), received \(received)."
        } catch {
            return "Could not finish this time. It will try again the next time Anchor opens."
        }
    }

    private static func ensureZone() async throws {
        _ = try await database.save(CKRecordZone(zoneID: zoneID))
    }

    // MARK: Bringing in

    private static func loadToken() -> CKServerChangeToken? {
        guard let data = defaults.data(forKey: tokenKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private static func saveToken(_ token: CKServerChangeToken?) {
        guard let token, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            defaults.removeObject(forKey: tokenKey)
            return
        }
        defaults.set(data, forKey: tokenKey)
    }

    private static func pull() async throws -> Int {
        var received = 0
        var known = list(knownKey)
        let pendingDeletes = list(deletedKey)
        var token = loadToken()
        var more = true
        while more {
            let changes: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                          deletions: [CKDatabase.RecordZoneChange.Deletion],
                          changeToken: CKServerChangeToken, moreComing: Bool)
            do {
                changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
            } catch let error as CKError where error.code == .changeTokenExpired {
                saveToken(nil)
                token = nil
                continue
            }
            for (_, result) in changes.modificationResultsByID {
                guard case .success(let modification) = result,
                      let (folder, name) = parse(modification.record.recordID.recordName),
                      let asset = modification.record["file"] as? CKAsset, let url = asset.fileURL,
                      !pendingDeletes.contains(modification.record.recordID.recordName),
                      let data = try? Data(contentsOf: url) else { continue }
                let had = FileManager.default.fileExists(atPath: StoredFiles.fileURL(folder, name).path)
                if StoredFiles.installSealed(data, folder, name) {
                    known.insert(recordName(folder, name))
                    if !had { received += 1 }
                }
            }
            for deletion in changes.deletions {
                guard let (folder, name) = parse(deletion.recordID.recordName) else { continue }
                StoredFiles.removeFromSync(folder, name)
                known.remove(deletion.recordID.recordName)
            }
            token = changes.changeToken
            more = changes.moreComing
            keep(known, knownKey)
            saveToken(token)
        }
        return received
    }

    // MARK: Sending

    private static func push() async throws -> Int {
        var known = list(knownKey)
        var records: [CKRecord] = []
        var sources: [CKRecord.ID: String] = [:]
        for folder in StoredFiles.Folder.allCases {
            for name in StoredFiles.names(in: folder) where usable(name) {
                let id = recordName(folder, name)
                let url = StoredFiles.fileURL(folder, name)
                guard !known.contains(id), StoredFiles.isSealed(at: url), !StoredFiles.isRecent(url) else { continue }
                let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: id, zoneID: zoneID))
                record["folder"] = folder.label as CKRecordValue
                record["name"] = name as CKRecordValue
                record["file"] = CKAsset(fileURL: url)
                records.append(record)
                sources[record.recordID] = id
                if records.count >= perRun { break }
            }
            if records.count >= perRun { break }
        }
        guard !records.isEmpty else { return 0 }
        let outcome = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: false)
        var sent = 0
        for (recordID, result) in outcome.saveResults {
            guard let id = sources[recordID] else { continue }
            switch result {
            case .success:
                known.insert(id)
                sent += 1
            case .failure(let error):
                // Already in iCloud, from this phone before or from another device: it counts as there.
                if (error as? CKError)?.code == .serverRecordChanged { known.insert(id) }
            }
        }
        keep(known, knownKey)
        return sent
    }

    private static func pushDeletes() async throws {
        let pending = list(deletedKey)
        guard !pending.isEmpty else { return }
        let ids = pending.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
        let outcome = try await database.modifyRecords(saving: [], deleting: ids, savePolicy: .ifServerRecordUnchanged, atomically: false)
        var left = pending
        var known = list(knownKey)
        for (recordID, result) in outcome.deleteResults {
            var finished = false
            switch result {
            case .success: finished = true
            case .failure(let error): finished = (error as? CKError)?.code == .unknownItem
            }
            if finished {
                left.remove(recordID.recordName)
                known.remove(recordID.recordName)
            }
        }
        keep(left, deletedKey)
        keep(known, knownKey)
    }

    // MARK: Clear everything

    /// Forgets what this phone knows about the files in iCloud. Called by Clear everything.
    static func forgetLocalState() {
        for key in [enabledKey, tokenKey, knownKey, deletedKey, lastKey] { defaults.removeObject(forKey: key) }
    }

    /// Removes the zone, which removes every file Anchor sent to iCloud. Called by Clear everything while sync is on.
    static func removeEverythingFromICloud() {
        guard CloudSync.isOn else { return }
        Task.detached(priority: .utility) {
            _ = try? await database.deleteRecordZone(withID: zoneID)
        }
    }
}
