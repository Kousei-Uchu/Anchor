import Foundation
import CryptoKit
import SQLite3
import SwiftData

/// Lock my data (Patch 35b3, D15 option B): one flow that locks every field that holds your own words, in
/// every model, after the way back exists.
///
/// The order, and why:
/// 1. The person checks the recovery key and says an encrypted backup is kept off the phone (the screen).
/// 2. Choosing Lock my data records a job and asks for a safety copy (35b1). Nothing else happens now.
/// 3. On the next start, `SafetyCopy.runAtLaunch` makes the copy first, before the database is opened.
/// 4. Once the database is open, `runIfWaiting` refuses to go on unless that copy is fresh and checks out, and
///    the data key opens what it seals. Then it notes what every item reads as, locks every item, saves,
///    and reads everything again in a fresh context: the same items, each reading exactly as before, each
///    held sealed with nothing left in plain.
/// 5. If anything is off, it asks for the safety copy to be put back on the next start and says so.
/// 6. If the app is closed in the middle, the next start sees the run was never finished and does the same.
/// 7. After a good run, the next start tidies the database file (`scrubAtLaunch`), because the old plain
///    text can stay in unused space in the file until it is rebuilt.
///
/// Nothing here runs while the app is in use except step 4, which runs once at the start, before any screen.
///
/// Levels (Patch 35g1a, D44): what there is to lock grows in steps. A run records the level it locked (`currentLevel`).
/// When the words are locked at an earlier level, `needsMore` is true and the same flow can be run again to lock the
/// rest, with a new safety copy first. Locking an item seals only what is still plain, so running it again changes
/// nothing that is sealed already. If that second run fails, the safety copy is put back on the next start, and the
/// words stay locked all the while.
enum LockMyData {
    // MARK: State

    private enum Stored: String {
        case off, running, on
    }

    private static let stateKey = "lockMyData.state"
    private static let requestedKey = "lockMyData.requested"
    private static let scrubKey = "lockMyData.scrubWaiting"
    private static let resultKey = "lockMyData.lastResult"
    private static let lockedAtKey = "lockMyData.lockedAt"
    private static let itemsKey = "lockMyData.items"
    private static let levelKey = "lockMyData.level"
    private static let upgradeRunningKey = "lockMyData.upgradeRunning"
    private static let defaults = UserDefaults.standard

    private static var stored: Stored {
        defaults.string(forKey: stateKey).flatMap(Stored.init(rawValue:)) ?? .off
    }

    /// True once a run has finished and every item has checked out. This is what turns `FieldLock.isOn` on at launch.
    static var isOn: Bool { stored == .on }

    // MARK: Levels (Patch 35g1a, D44)

    /// How much there is to lock. Level 1 is the words, which Patch 35b locks. Each part of 35g adds fields and raises
    /// this by one: 35g1b made it 2 (check-ins, sleep and Recovery), 35g2 makes it 3 (the Journal, messages and people). A store that was locked at an earlier level is
    /// still locked, and Lock my data offers to lock the rest, with a new safety copy first.
    static let currentLevel = 3

    /// What the last finished run locked. 0 when nothing is locked. A store locked before levels existed has no
    /// saved number and counts as level 1.
    static var level: Int {
        guard stored == .on else { return 0 }
        let saved = defaults.integer(forKey: levelKey)
        return saved > 0 ? saved : 1
    }

    /// True when the words are locked but newer fields are not yet.
    static var needsMore: Bool { levelNeedsMore(isOn: isOn, savedLevel: level, current: currentLevel) }

    /// The rule behind `needsMore`, apart from what is saved, so it can be checked on its own.
    static func levelNeedsMore(isOn: Bool, savedLevel: Int, current: Int) -> Bool {
        isOn && savedLevel < current
    }

    /// What a new run would lock beyond what is locked now, in plain words for the Lock my data screen.
    static var moreToLock: String {
        var parts: [String] = []
        if level < 2 { parts.append("check-ins, sleep and Recovery") }
        if level < 3 { parts.append("the Journal, messages and people") }
        if parts.isEmpty { return "More of what Anchor keeps can be locked now." }
        return "Dates, numbers and marks in " + parts.joined(separator: " and ") + " can be locked now."
    }

    struct Status {
        var isOn = false
        var needsMore = false
        var lockedAt: Date?
        var items = 0
        var waiting = false
        var scrubWaiting = false
        var lastResult: String?
    }

    static func status() -> Status {
        var status = Status()
        status.isOn = isOn
        status.needsMore = needsMore
        status.lockedAt = (defaults.object(forKey: lockedAtKey) as? Double).map(Date.init(timeIntervalSince1970:))
        status.items = defaults.integer(forKey: itemsKey)
        status.waiting = defaults.object(forKey: requestedKey) != nil
        status.scrubWaiting = defaults.bool(forKey: scrubKey)
        status.lastResult = defaults.string(forKey: resultKey)
        return status
    }

    static func clearLastResult() {
        defaults.removeObject(forKey: resultKey)
    }

    private static func setResult(_ text: String) {
        defaults.set(text, forKey: resultKey)
    }

    // MARK: Asking for it

    /// Records the job and asks for a safety copy. The lock itself waits for the next start.
    static func request() {
        guard !isOn || needsMore else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: requestedKey)
        SafetyCopy.request(.make)
    }

    static func cancelRequest() {
        defaults.removeObject(forKey: requestedKey)
        if SafetyCopy.status().pending == .make { SafetyCopy.cancelRequest() }
    }

    // MARK: At launch, before the database is opened

    /// A run that never finished, because the app was closed in the middle of it, is put right by going back to the
    /// safety copy that was made just before it began. Nothing was written in between, so going back loses nothing.
    /// Must run before `SafetyCopy.runAtLaunch`, which does the going back.
    static func recoverInterruptedRun() {
        // A run that locks the rest of a store that is already locked: the words stay locked, so the state stays on,
        // and only the safety copy made just before the run is put back.
        if defaults.bool(forKey: upgradeRunningKey) {
            defaults.removeObject(forKey: upgradeRunningKey)
            defaults.removeObject(forKey: requestedKey)
            defaults.removeObject(forKey: scrubKey)
            SafetyCopy.request(.goBack)
            setResult("Locking the rest was stopped before it was checked, so Anchor went back to the safety copy made just before it began. Your text stays locked. Safety copy says how that went.")
            return
        }
        guard stored == .running else { return }
        defaults.set(Stored.off.rawValue, forKey: stateKey)
        defaults.removeObject(forKey: requestedKey)
        defaults.removeObject(forKey: scrubKey)
        SafetyCopy.request(.goBack)
        setResult("Locking was stopped before it was checked, so Anchor went back to the safety copy made just before it began. Safety copy says how that went.")
    }

    /// Rebuilds the database file, once, after a good lock, so old plain text does not stay in unused space in it.
    /// Runs before the database is opened. If it cannot, nothing is lost: the file is only less tidy.
    static func scrubAtLaunch() {
        guard defaults.bool(forKey: scrubKey) else { return }
        defaults.removeObject(forKey: scrubKey)
        var db: OpaquePointer?
        guard sqlite3_open_v2(SafetyCopy.liveStoreURL.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(db)
            setResult("Your data is locked. Clearing the old plain copies out of the database file did not run, because the file could not be opened for it.")
            return
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 3000)
        let steps = [
            "PRAGMA wal_checkpoint(TRUNCATE);",
            "PRAGMA secure_delete = ON;",
            "VACUUM;",
            "PRAGMA wal_checkpoint(TRUNCATE);"
        ]
        for sql in steps {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                setResult("Your data is locked. Clearing the old plain copies out of the database file did not finish, so some may still be in it. Nothing was lost.")
                return
            }
        }
        setResult("Your data is locked, and the database file was rebuilt so the old plain copies are gone from it. The safety copy still holds what it held before the run, unlocked, so delete it when you are happy.")
    }

    // MARK: The run, once the database is open

    struct Report {
        var kinds = 0
        var items = 0
    }

    struct Failure: Error {
        let message: String
    }

    /// Every model with locked fields. `scripts/check-locked-fields.mjs` fails if one is missing from this list.
    struct Kind {
        let name: String
        let items: (ModelContext) throws -> [any LockableModel]
    }

    private static func kind<T: LockableModel>(_ type: T.Type) -> Kind {
        Kind(name: String(describing: type)) { context in
            try context.fetch(FetchDescriptor<T>()).map { $0 as any LockableModel }
        }
    }

    static var kinds: [Kind] {
        [
            kind(JournalEntry.self), kind(TrustedContact.self), kind(GroundingTool.self),
            kind(SafetyPlan.self), kind(SafetyPlanSection.self), kind(BoundarySection.self),
            kind(SleepEntry.self), kind(PersonSection.self), kind(PersonalGoal.self),
            kind(MessageStarter.self), kind(TriggerWindow.self), kind(AppointmentSeries.self),
            kind(AppointmentOccurrence.self), kind(BridgeDraftItem.self), kind(FeedbackLoopDiagram.self),
            kind(ThreadMessage.self), kind(SupportCalendarEntry.self), kind(FutureNote.self),
            kind(UnsentDraft.self), kind(DecisionPresetCategory.self), kind(DecisionPresetChoice.self),
            kind(DeEscalationScript.self), kind(Affirmation.self), kind(NextHourItem.self),
            kind(TaskItem.self), kind(QuickList.self), kind(Routine.self), kind(ItemList.self),
            kind(CheckIn.self), kind(RecoveryCounter.self), kind(RecoveryMotivation.self), kind(RecoveryDayEntry.self),
            kind(RecoveryUrge.self)
        ]
    }

    /// Runs the waiting job, if there is one. Called once the real database is open, before any screen.
    @MainActor
    static func runIfWaiting(container: ModelContainer) {
        guard let asked = defaults.object(forKey: requestedKey) as? Double else { return }
        defaults.removeObject(forKey: requestedKey)
        let requested = Date(timeIntervalSince1970: asked)

        guard !DemoMode.isOn, AnchorSchema.openedPersistentStore else {
            setResult("Nothing was locked, because Anchor could not open your saved data this time.")
            return
        }
        guard !isOn || needsMore else {
            setResult("Your text was already locked, so nothing was done.")
            return
        }
        // Locking the rest of a store whose text is already locked (Patch 35g1a) is the same run, with one difference
        // that matters: if it fails, the text is still locked, so the lock stays on and the state stays on.
        let upgrading = isOn
        // The way back has to exist, and be the one made for this run.
        let copy = SafetyCopy.status()
        guard copy.exists, let made = copy.createdAt, made.addingTimeInterval(2) >= requested else {
            setResult("Nothing was locked, because the safety copy was not made. Safety copy says why. Try again once it has been made.")
            return
        }
        // The key has to be here, open what it seals, and match the recovery file.
        guard case .found(let key) = DataKeyStore.lookup(), keyWorks(key) else {
            setResult("Nothing was locked, because the data key could not be read on this start. Close Anchor and open it again, then try once more.")
            return
        }
        guard let blob = RecoveryFile.read(),
              let fileID = RecoveryBlob.keyID(inBlob: blob),
              fileID == RecoveryBlob.keyID(of: key) else {
            setResult("Nothing was locked, because the recovery file is missing or was made for a different key. Make a new recovery key in Encryption first.")
            return
        }

        if upgrading {
            defaults.set(true, forKey: upgradeRunningKey)
        } else {
            defaults.set(Stored.running.rawValue, forKey: stateKey)
        }
        FieldLock.isOn = true
        do {
            let report = try lockAll(in: container)
            // The run is over first, then the level is kept, then the state. If the app stops between these, the
            // data is locked all the way and the level is still the old one, so asking again just does it again.
            defaults.removeObject(forKey: upgradeRunningKey)
            defaults.set(Date().timeIntervalSince1970, forKey: lockedAtKey)
            defaults.set(report.items, forKey: itemsKey)
            defaults.set(true, forKey: scrubKey)
            defaults.set(currentLevel, forKey: levelKey)
            defaults.set(Stored.on.rawValue, forKey: stateKey)
            setResult("Locked \(report.items) \(report.items == 1 ? "item" : "items") and checked every one. Close Anchor and open it again to finish: the old plain copies are cleared out of the database file on that start.")
        } catch {
            let reason = (error as? Failure)?.message ?? "Something did not work."
            if upgrading {
                defaults.removeObject(forKey: upgradeRunningKey)
                SafetyCopy.request(.goBack)
                setResult("\(reason) Nothing new is kept: Anchor will go back to the safety copy the next time it starts, and your text stays locked. Close it from the app switcher and open it again, and do not add anything before that.")
            } else {
                FieldLock.isOn = false
                defaults.set(Stored.off.rawValue, forKey: stateKey)
                SafetyCopy.request(.goBack)
                setResult("\(reason) Nothing is kept: Anchor will go back to the safety copy the next time it starts. Close it from the app switcher and open it again, and do not add anything before that.")
            }
        }
    }

    /// Locks every item and checks the result in a fresh context. Throws, with something to say, if anything is off.
    /// The caller turns `FieldLock.isOn` on first, and puts it back if this throws.
    @MainActor
    static func lockAll(in container: ModelContainer) throws -> Report {
        let all = kinds

        // What everything reads as now.
        let beforeContext = ModelContext(container)
        var baseline: [[PersistentIdentifier: String]] = []
        for kind in all {
            var map: [PersistentIdentifier: String] = [:]
            do {
                for item in try kind.items(beforeContext) { map[item.persistentModelID] = item.lockedSnapshot() }
            } catch {
                throw Failure(message: "Anchor could not read your \(kind.name) items before locking.")
            }
            baseline.append(map)
        }

        // Lock them.
        let context = container.mainContext
        do {
            for kind in all {
                for item in try kind.items(context) { item.lockExistingValues() }
            }
            try context.save()
        } catch {
            throw Failure(message: "Locking could not be saved.")
        }

        // Read everything again, from the store, in a context that has seen none of the above.
        let checkContext = ModelContext(container)
        var report = Report()
        for (index, kind) in all.enumerated() {
            let items: [any LockableModel]
            do {
                items = try kind.items(checkContext)
            } catch {
                throw Failure(message: "Anchor could not read your \(kind.name) items back after locking.")
            }
            guard items.count == baseline[index].count else {
                throw Failure(message: "The number of \(kind.name) items changed (\(baseline[index].count) before, \(items.count) after).")
            }
            for item in items {
                guard let was = baseline[index][item.persistentModelID], was == item.lockedSnapshot() else {
                    throw Failure(message: "An item in \(kind.name) did not read back exactly as it was.")
                }
                guard item.lockedFieldsAreSealed() else {
                    throw Failure(message: "An item in \(kind.name) was not locked.")
                }
            }
            if !items.isEmpty {
                report.kinds += 1
                report.items += items.count
            }
        }
        return report
    }

    static func keyWorks(_ key: SymmetricKey) -> Bool {
        let probe = "anchor lock probe"
        guard let sealed = try? FieldCipher.seal(probe, context: "LockMyData.probe", key: key) else { return false }
        return FieldCipher.open(sealed, context: "LockMyData.probe", key: key) == probe
    }
}

// MARK: - Voice notes and Journal photos (Patch 35d, D31)

/// Whether a new voice note or photo is sealed as it is saved. False until Lock my files has checked every file,
/// and then turned on at every launch (`FieldLockWiring.install`).
enum FileLock {
    nonisolated(unsafe) static var isOn = false
}

/// The one way in and out for the two folders of files: voice notes and Journal photos. A file in either folder is
/// plain or sealed (`FileCipher`), and this reads both, so a folder that is part locked, part plain, which is what
/// a run that was stopped leaves, always opens. `scripts/check-locked-files.mjs` keeps every other file from
/// reading or writing these folders on its own.
enum StoredFiles {
    enum Folder: CaseIterable {
        case voiceNotes, journalPhotos

        /// The folder's name inside a safety copy, and inside the context a file is sealed for.
        var label: String { self == .voiceNotes ? "VoiceNotes" : "JournalAttachments" }
        var url: URL { self == .voiceNotes ? VoiceNoteStore.folder : JournalAttachmentStore.folderURL }
    }

    enum SealResult {
        case sealed, alreadySealed, left, gone, failed
    }

    /// Files changed in the last two minutes are left alone by a lock run and a sweep, because a recording may
    /// still be writing to one. The recording seals itself when it stops.
    static let recentSeconds: TimeInterval = 120

    static func context(_ folder: Folder, _ name: String) -> String {
        "File." + folder.label + "/" + name
    }

    // MARK: Listing and looking

    /// The files that belong to the app in a folder: regular files, and nothing that starts with a dot, which is
    /// where a half-made lock copy lives.
    static func names(in folder: Folder) -> [String] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder.url, includingPropertiesForKeys: keys)) ?? []
        return urls.compactMap { url -> String? in
            let name = url.lastPathComponent
            guard !name.hasPrefix("."),
                  (try? url.resourceValues(forKeys: Set(keys)))?.isRegularFile == true else { return nil }
            return name
        }.sorted()
    }

    static func isSealed(at url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: FileCipher.magic.count) else { return false }
        return FileCipher.looksSealed(head)
    }

    static func isRecent(_ url: URL) -> Bool {
        guard let changed = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return false }
        return Date().timeIntervalSince(changed) < recentSeconds
    }

    struct Counts {
        var sealed = 0
        var plain = 0
        var total: Int { sealed + plain }
    }

    static func counts() -> Counts {
        var counts = Counts()
        for folder in Folder.allCases {
            for name in names(in: folder) {
                if isSealed(at: folder.url.appendingPathComponent(name)) { counts.sealed += 1 } else { counts.plain += 1 }
            }
        }
        return counts
    }

    // MARK: Reading and writing one file, by its URL, with the key given

    /// The file's own bytes. Plain bytes as they are; a sealed file opened with the key; nil if it is missing, or
    /// sealed and the key is missing or wrong.
    static func readFile(at url: URL, context: String, key: @autoclosure () -> SymmetricKey?) -> Data? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard FileCipher.looksSealed(data) else { return data }
        guard let key = key() else { return nil }
        return FileCipher.open(data, context: context, key: key)
    }

    /// Seals one plain file where it lies. The sealed bytes are made, opened again and compared with the plain
    /// ones, written beside the file under a name that starts with a dot, read back from there, and only then put
    /// in the plain file's place in one step. The plain file is never touched before that. A file that is already
    /// sealed is left alone, but only counts as sealed if it opens.
    static func sealFile(at url: URL, context: String, key: SymmetricKey, skipRecent: Bool = false) -> SealResult {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return .gone }
        guard let data = try? Data(contentsOf: url) else { return .failed }
        if FileCipher.looksSealed(data) {
            return FileCipher.open(data, context: context, key: key) == nil ? .failed : .alreadySealed
        }
        if skipRecent && isRecent(url) { return .left }
        guard let sealed = try? FileCipher.seal(data, context: context, key: key),
              FileCipher.open(sealed, context: context, key: key) == data else { return .failed }
        let temp = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".locking")
        try? manager.removeItem(at: temp)
        do {
            try sealed.write(to: temp, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            guard try Data(contentsOf: temp) == sealed else {
                try? manager.removeItem(at: temp)
                return .failed
            }
            // A file deleted while this ran stays deleted.
            guard manager.fileExists(atPath: url.path) else {
                try? manager.removeItem(at: temp)
                return .gone
            }
            _ = try manager.replaceItemAt(url, withItemAt: temp)
        } catch {
            try? manager.removeItem(at: temp)
            return .failed
        }
        return readFile(at: url, context: context, key: key) == data ? .sealed : .failed
    }

    // MARK: The folders, with the data key

    static func read(_ folder: Folder, _ name: String) -> Data? {
        readFile(at: folder.url.appendingPathComponent(name), context: context(folder, name), key: FieldLockWiring.currentKey())
    }

    /// Saves a new file, sealed when locking files is on and the key is here. If sealing is wanted and cannot be
    /// done the file is saved plain, so a photo is never lost; the next start seals it.
    static func write(_ data: Data, _ folder: Folder, _ name: String) throws {
        let url = folder.url.appendingPathComponent(name)
        if FileLock.isOn, let key = FieldLockWiring.currentKey(),
           let sealed = try? FileCipher.seal(data, context: context(folder, name), key: key) {
            try sealed.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } else {
            try data.write(to: url)
        }
    }

    /// For a file made some other way, a recording: seals it when it is finished, if locking files is on.
    static func sealIfOn(_ folder: Folder, _ name: String) {
        guard FileLock.isOn, let key = FieldLockWiring.currentKey() else { return }
        _ = sealFile(at: folder.url.appendingPathComponent(name), context: context(folder, name), key: key)
    }

    // MARK: Handing a file to another app

    private static var sharedFolder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AnchorShared", isDirectory: true)
    }

    /// A plain file another app can be given (Share, Messages). A plain file is given as it is. A sealed one is
    /// opened into a copy in the phone's temporary folder, which `clearSharedCopies` removes when the sheet closes
    /// and at every start. Nil if the file is missing or cannot be opened.
    static func sendableCopy(_ folder: Folder, _ name: String) -> URL? {
        let url = folder.url.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard isSealed(at: url) else { return url }
        guard let plain = read(folder, name) else { return nil }
        let directory = sharedFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let copy = directory.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try plain.write(to: copy, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return copy
        } catch {
            return nil
        }
    }

    static func clearSharedCopies() {
        try? FileManager.default.removeItem(at: sharedFolder)
    }
}

/// Lock my files (Patch 35d, D31): the second step of locking. Lock my data (35b3) locks the words; this locks the
/// voice notes and Journal photos, which are files and not stored text.
///
/// The order, and why it is not like Lock my data:
/// 1. It is offered only once the text is locked, so the recovery key was checked and the backup box ticked there.
/// 2. Choosing it records a job and asks for a new safety copy, which holds the files as they are now.
/// 3. On the next start, after the copy is made and the database is open, the run refuses unless the copy is fresh
///    and the key opens what it seals. Then it works through the files in the background, one at a time.
/// 4. Each file is sealed, checked and swapped in by itself (`StoredFiles.sealFile`). A run that stops, or a file
///    that cannot be sealed, leaves some files sealed and some plain, and every one of them still opens. That is
///    why this needs no automatic way back: nothing is ever half done.
/// 5. From the middle of the run, new files are sealed as they are saved, and a second pass takes any saved before.
///    Only if every file then reads back from its sealed form does the state become on.
/// 6. When it is on, every start looks for files still plain (a recording cut short, files put back by Go back) and
///    seals them.
enum LockMyFiles {
    private enum Stored: String {
        case off, running, on
    }

    private static let stateKey = "lockMyFiles.state"
    private static let requestedKey = "lockMyFiles.requested"
    private static let resultKey = "lockMyFiles.lastResult"
    private static let lockedAtKey = "lockMyFiles.lockedAt"
    private static let itemsKey = "lockMyFiles.items"
    private static let defaults = UserDefaults.standard

    private static var stored: Stored {
        defaults.string(forKey: stateKey).flatMap(Stored.init(rawValue:)) ?? .off
    }

    /// True once a run has finished and every file has checked out. This is what turns `FileLock.isOn` on at launch.
    static var isOn: Bool { stored == .on }

    struct Status {
        var isOn = false
        var running = false
        var waiting = false
        var lockedAt: Date?
        var files = 0
        var lastResult: String?
    }

    static func status() -> Status {
        var status = Status()
        status.isOn = isOn
        status.running = stored == .running
        status.waiting = defaults.object(forKey: requestedKey) != nil
        status.lockedAt = (defaults.object(forKey: lockedAtKey) as? Double).map(Date.init(timeIntervalSince1970:))
        status.files = defaults.integer(forKey: itemsKey)
        status.lastResult = defaults.string(forKey: resultKey)
        return status
    }

    static func clearLastResult() {
        defaults.removeObject(forKey: resultKey)
    }

    private static func setResult(_ text: String) {
        defaults.set(text, forKey: resultKey)
    }

    // MARK: Asking for it

    /// Records the job and asks for a safety copy. The run waits for the next start.
    static func request() {
        guard LockMyData.isOn, !isOn else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: requestedKey)
        SafetyCopy.request(.make)
    }

    static func cancelRequest() {
        defaults.removeObject(forKey: requestedKey)
        if SafetyCopy.status().pending == .make { SafetyCopy.cancelRequest() }
    }

    // MARK: At launch

    /// A run that was stopped, because the app was closed in the middle of it, is only part done. Nothing is lost:
    /// the files already sealed open, the rest are plain. It says so, and the run can be asked for again.
    static func recoverInterruptedRun() {
        guard stored == .running else { return }
        defaults.set(Stored.off.rawValue, forKey: stateKey)
        FileLock.isOn = false
        setResult("Locking the voice notes and photos was stopped before it finished. Nothing was lost: the ones already locked open as usual and the rest are as they were. Lock them again to finish.")
    }

    /// Runs the waiting job, if there is one, once the real database is open. The work itself runs in the
    /// background, so a long list of photos never holds up the start.
    @MainActor
    static func runIfWaiting() {
        StoredFiles.clearSharedCopies()
        guard let asked = defaults.object(forKey: requestedKey) as? Double else { return }
        defaults.removeObject(forKey: requestedKey)
        let requested = Date(timeIntervalSince1970: asked)

        guard !DemoMode.isOn, AnchorSchema.openedPersistentStore else {
            setResult("Nothing was locked, because Anchor could not open your saved data this time.")
            return
        }
        guard LockMyData.isOn else {
            setResult("Nothing was locked, because your text is not locked yet. Lock my data comes first.")
            return
        }
        guard !isOn else {
            setResult("Your voice notes and photos were already locked, so nothing was done.")
            return
        }
        let copy = SafetyCopy.status()
        guard copy.exists, let made = copy.createdAt, made.addingTimeInterval(2) >= requested else {
            setResult("Nothing was locked, because the safety copy was not made. Safety copy says why. Try again once it has been made.")
            return
        }
        guard case .found(let key) = DataKeyStore.lookup(), LockMyData.keyWorks(key) else {
            setResult("Nothing was locked, because the data key could not be read on this start. Close Anchor and open it again, then try once more.")
            return
        }
        guard let blob = RecoveryFile.read(),
              let fileID = RecoveryBlob.keyID(inBlob: blob),
              fileID == RecoveryBlob.keyID(of: key) else {
            setResult("Nothing was locked, because the recovery file is missing or was made for a different key. Make a new recovery key in Encryption first.")
            return
        }

        defaults.set(Stored.running.rawValue, forKey: stateKey)
        Task.detached(priority: .utility) { run(key: key) }
    }

    /// When files are locked, seals any that are still plain. Quiet, in the background, and it leaves a file that
    /// changed in the last two minutes for the next start.
    static func sweepAtLaunch() {
        guard isOn, !DemoMode.isOn else { return }
        Task.detached(priority: .utility) {
            guard let key = FieldLockWiring.currentKey() else { return }
            for folder in StoredFiles.Folder.allCases {
                clearLeftovers(in: folder)
                for name in StoredFiles.names(in: folder) {
                    _ = StoredFiles.sealFile(at: folder.url.appendingPathComponent(name),
                                             context: StoredFiles.context(folder, name), key: key, skipRecent: true)
                }
            }
        }
    }

    // MARK: The run

    /// Half-made copies from a run that was stopped. They start with a dot, so nothing else ever reads them.
    private static func clearLeftovers(in folder: StoredFiles.Folder) {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder.url, includingPropertiesForKeys: nil)) ?? []
        for url in urls where url.lastPathComponent.hasPrefix(".") && url.lastPathComponent.hasSuffix(".locking") {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private struct PassResult {
        var failed = 0
        var left = 0
    }

    private static func pass(key: SymmetricKey) -> PassResult {
        var result = PassResult()
        for folder in StoredFiles.Folder.allCases {
            clearLeftovers(in: folder)
            for name in StoredFiles.names(in: folder) {
                switch StoredFiles.sealFile(at: folder.url.appendingPathComponent(name),
                                            context: StoredFiles.context(folder, name), key: key, skipRecent: true) {
                case .failed: result.failed += 1
                case .left: result.left += 1
                case .sealed, .alreadySealed, .gone: break
                }
            }
        }
        return result
    }

    /// Seals every file, turns on sealing for new ones, takes the ones saved in between, and reads every file back.
    private static func run(key: SymmetricKey) {
        _ = pass(key: key)
        // From here a new file is sealed as it is saved.
        FileLock.isOn = true
        let second = pass(key: key)

        // Read every file again, from its sealed form.
        var total = 0, unreadable = 0, recent = 0
        for folder in StoredFiles.Folder.allCases {
            for name in StoredFiles.names(in: folder) {
                let url = folder.url.appendingPathComponent(name)
                total += 1
                if StoredFiles.isSealed(at: url) {
                    if StoredFiles.readFile(at: url, context: StoredFiles.context(folder, name), key: key) == nil { unreadable += 1 }
                } else if StoredFiles.isRecent(url) {
                    recent += 1
                } else {
                    unreadable += 1
                }
            }
        }

        if second.failed == 0 && unreadable == 0 {
            defaults.set(Date().timeIntervalSince1970, forKey: lockedAtKey)
            defaults.set(total - recent, forKey: itemsKey)
            defaults.set(Stored.on.rawValue, forKey: stateKey)
            let later = recent == 0 ? "" : " \(recent) saved in the last two minutes will be locked on the next start."
            setResult("Locked \(total - recent) \(total - recent == 1 ? "file" : "files") and checked every one. From now on a new voice note or photo is locked as it is saved.\(later) The safety copy still holds them unlocked, so delete it when you are happy.")
        } else {
            FileLock.isOn = false
            defaults.set(Stored.off.rawValue, forKey: stateKey)
            let count = max(second.failed, unreadable)
            setResult("\(count) \(count == 1 ? "file" : "files") could not be locked. Nothing was lost: every file still opens, the ones locked stay locked and the rest are as they were. Try again, and if it keeps happening, the safety copy has every file as it was.")
        }
    }
}

#if DEBUG
/// Checks, in a test build and on a store that lives only in memory with a made-up key and made-up text, that
/// locking what is already stored seals every locked field, that every item reads back exactly, that running it
/// again changes nothing, and that it refuses and says so when sealing is not possible. Nothing real is touched.
/// Patch 35b3.
enum LockMyDataSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Lock my data self-test: \(message)") }
    }

    @MainActor
    static func run() {
        if hasRun { return }
        hasRun = true
        let schema = Schema(AnchorSchema.models)
        guard let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]) else {
            fatalError("Lock my data self-test: could not make a store in memory.")
        }
        let key = SymmetricKey(data: Data((0..<32).map { UInt8(255 - $0) }))
        let savedSealer = FieldLock.sealer, savedOpener = FieldLock.opener, savedOn = FieldLock.isOn
        defer {
            FieldLock.sealer = savedSealer
            FieldLock.opener = savedOpener
            FieldLock.isOn = savedOn
        }
        FieldLock.sealer = { text, ctx in try? FieldCipher.seal(text, context: ctx, key: key) }
        FieldLock.opener = { stored, ctx in FieldCipher.open(stored, context: ctx, key: key) }

        // Plain items, made while locking is off.
        FieldLock.isOn = false
        let context = container.mainContext
        let entry = JournalEntry(text: "plain journal words")
        let contact = TrustedContact(name: "Sam", phoneNumber: "0400 000 000", sortOrder: 0, discordUserID: "42")
        let list = QuickList(title: "Bag", items: [QuickListItem(text: "keys")])
        let counter = RecoveryCounter(name: "Mine", savingsAmount: 12.5, savingsPeriod: .week, currencyCode: "AUD")
        let runs = counter.runsData
        counter.acknowledgedMilestones = [1, 3]
        let when = Date(timeIntervalSinceReferenceDate: 700_000_000.25)
        let checkIn = CheckIn(timestamp: when, physicalExhaustion: 0.25, cognitiveBurnout: 0.5, mentalLoad: 0.75, physicalEnergy: 0.1, socialEnergy: 0.9)
        let night = SleepEntry(nightDate: when, bedTime: when.addingTimeInterval(-28_800), wakeTime: nil, minutesAsleep: 450, feel: 1)
        let urge = RecoveryUrge(counterID: counter.id, date: when, strength: .intense)
        context.insert(entry)
        context.insert(contact)
        context.insert(list)
        context.insert(counter)
        context.insert(checkIn)
        context.insert(night)
        context.insert(urge)
        entry.isFavorited = true
        entry.linkedContext = .checkInSlider
        contact.escalationWindowMinutes = 45
        contact.timeZoneIdentifier = "Australia/Sydney"
        contact.availableFromHour = 9
        try? context.save()
        check(entry.textSealed == nil && !entry.lockedFieldsAreSealed(), "an item was sealed while locking was off.")

        // Lock them.
        FieldLock.isOn = true
        guard let report = try? LockMyData.lockAll(in: container) else { fatalError("Lock my data self-test: locking threw.") }
        check(report.items == 7, "the number of locked items was \(report.items), not 7.")
        check(entry.text == "plain journal words" && entry.textPlain.isEmpty && entry.lockedFieldsAreSealed(), "a journal entry was not locked and readable.")
        check(contact.name == "Sam" && contact.discordUserID == "42" && contact.lockedFieldsAreSealed(), "a contact was not locked and readable.")
        check(list.items.count == 1 && list.items[0].text == "keys" && list.lockedFieldsAreSealed(), "a list was not locked and readable.")
        check(counter.runsData == runs && counter.lockedFieldsAreSealed(), "a counter was not locked and readable.")
        check(counter.savingsAmount == 12.5 && counter.savingsPeriod == .week && counter.currencyCode == "AUD" && counter.acknowledgedMilestones == [1, 3], "a counter's numbers were not locked and readable.")
        check(counter.savingsAmountPlain == 0 && counter.currencyCodePlain.isEmpty && counter.acknowledgedMilestonesPlain.isEmpty, "a counter kept a number in plain.")
        check(checkIn.timestamp == when && checkIn.mentalLoad == 0.75 && checkIn.socialEnergy == 0.9 && checkIn.lockedFieldsAreSealed(), "a check-in was not locked and readable.")
        check(checkIn.timestampPlain == Date.lockedPlaceholder && checkIn.mentalLoadPlain == 0, "a check-in kept a value in plain.")
        check(night.nightDate == when && night.bedTime == when.addingTimeInterval(-28_800) && night.wakeTime == nil && night.minutesAsleep == 450 && night.feel == 1 && night.lockedFieldsAreSealed(), "a night was not locked and readable.")
        check(night.bedTimePlain == nil && night.minutesAsleepPlain == nil && night.wakeTimeSealed != nil, "a night kept a value in plain, or nothing was not sealed as nothing.")
        check(entry.isFavorited && entry.linkedContext == .checkInSlider && !entry.isFavoritedPlain && entry.linkedContextPlain == nil && entry.createdAtPlain == Date.lockedPlaceholder, "a journal entry kept a mark or a date in plain, or did not read back.")
        check(contact.escalationWindowMinutes == 45 && contact.timeZoneIdentifier == "Australia/Sydney" && contact.availableFromHour == 9 && contact.availableToHour == nil, "a contact's hours were not locked and readable.")
        check(contact.escalationWindowMinutesPlain == nil && contact.timeZoneIdentifierPlain == nil && contact.availableFromHourPlain == nil && contact.availableToHourSealed != nil, "a contact kept a value in plain, or nothing was not sealed as nothing.")
        check(urge.date == when && urge.strength == .intense && urge.strengthPlain == .mild && urge.lockedFieldsAreSealed(), "an urge was not locked and readable.")

        // Again: nothing is sealed twice and nothing changes.
        let stored = entry.textSealed
        guard (try? LockMyData.lockAll(in: container)) != nil else { fatalError("Lock my data self-test: a second run threw.") }
        check(entry.textSealed == stored, "a second run changed a sealed value.")

        // Levels (Patch 35g1a): more is offered only when the text is locked and the saved level is lower.
        check(!LockMyData.levelNeedsMore(isOn: false, savedLevel: 0, current: 2), "more was offered while nothing was locked.")
        check(LockMyData.levelNeedsMore(isOn: true, savedLevel: 1, current: 2), "more was not offered at an earlier level.")
        check(!LockMyData.levelNeedsMore(isOn: true, savedLevel: 2, current: 2), "more was offered at the current level.")
        check(!LockMyData.levelNeedsMore(isOn: true, savedLevel: 3, current: 2), "more was offered at a higher level.")

        // Dates, numbers, marks and choices (Patch 35g1a): sealed as text, read back exactly, nothing readable left in
        // the plain property, and a value that cannot be sealed or opened is never made up.
        let moment = Date(timeIntervalSinceReferenceDate: 784_111_777.123_456)
        let sealedMoment = FieldLock.storeScalar(moment, context: "Test.date")
        check(sealedMoment.plain == Date.lockedPlaceholder && sealedMoment.sealed != nil, "a date was not sealed.")
        check(FieldLock.readScalar(plain: sealedMoment.plain, sealed: sealedMoment.sealed, context: "Test.date") == moment, "a date did not read back exactly.")
        check(FieldLock.readScalar(plain: sealedMoment.plain, sealed: sealedMoment.sealed, context: "Test.other") == Date.lockedPlaceholder, "a date opened in another field.")
        let sum = 0.1 + 0.2
        let sealedNumber = FieldLock.storeScalar(sum, context: "Test.number")
        check(FieldLock.readScalar(plain: sealedNumber.plain, sealed: sealedNumber.sealed, context: "Test.number") == sum, "a decimal number did not read back exactly.")
        let sealedWhole = FieldLock.storeScalar(-42, context: "Test.whole")
        check(sealedWhole.plain == 0 && FieldLock.readScalar(plain: sealedWhole.plain, sealed: sealedWhole.sealed, context: "Test.whole") == -42, "a whole number did not read back.")
        let sealedMark = FieldLock.storeScalar(true, context: "Test.mark")
        check(sealedMark.plain == false && FieldLock.readScalar(plain: sealedMark.plain, sealed: sealedMark.sealed, context: "Test.mark") == true, "a mark did not read back.")
        let someDate = FieldLock.storeOptionalScalar(Date?.some(moment), context: "Test.maybe")
        let noDate = FieldLock.storeOptionalScalar(Date?.none, context: "Test.maybe")
        check(someDate.plain == nil && someDate.sealed != nil && noDate.plain == nil && noDate.sealed != nil, "an optional date was not sealed, or something was left plain.")
        check(FieldLock.readOptionalScalar(plain: someDate.plain, sealed: someDate.sealed, context: "Test.maybe") == moment, "an optional date did not read back.")
        check(FieldLock.readOptionalScalar(plain: noDate.plain, sealed: noDate.sealed, context: "Test.maybe") == nil, "no date did not read back as no date.")
        let sealedChoice = FieldLock.storeChoice(DayCountMode.classicStreak, context: "Test.choice")
        check(sealedChoice.plain == .runAndTotal && FieldLock.readChoice(plain: sealedChoice.plain, sealed: sealedChoice.sealed, context: "Test.choice") == .classicStreak, "a choice did not read back.")
        let workingSealer = FieldLock.sealer
        FieldLock.sealer = { _, _ in nil }
        let unsealed = FieldLock.storeScalar(moment, context: "Test.date")
        check(unsealed.plain == moment && unsealed.sealed == nil, "a date was lost when it could not be sealed.")
        FieldLock.sealer = workingSealer
        let ascending = [3, 1, 2, 1].sortedByKey { $0 }
        let descending = [3, 1, 2].sortedByKey(descending: true) { $0 }
        check(ascending == [1, 1, 2, 3] && descending == [3, 2, 1], "sortedByKey did not sort.")
        let tied = [(1, "a"), (0, "b"), (1, "c")].sortedByKey { $0.0 }
        let tiedNames = tied.map { $0.1 }
        check(tiedNames == ["b", "a", "c"], "sortedByKey changed the order of items with the same key.")

        // When sealing is not possible, it says so instead of leaving things half done and calling it good.
        let other = JournalEntry(text: "made while the key worked")
        context.insert(other)
        try? context.save()
        FieldLock.sealer = { _, _ in nil }
        let late = JournalEntry(text: "plain because the key failed")
        context.insert(late)
        try? context.save()
        check(!late.lockedFieldsAreSealed(), "a value was sealed with no key.")
        var refused = false
        do { _ = try LockMyData.lockAll(in: container) } catch { refused = true }
        check(refused, "locking went on although a value could not be sealed.")
    }
}
#endif

#if DEBUG
/// Checks, in a test build and in a folder made for the purpose, with a made-up key and made-up bytes, that a
/// file is sealed and opens again exactly, that sealing twice changes nothing, that a wrong key, a wrong name or a
/// changed byte does not open, that a plain file still reads, and that no half-made copy is left. Nothing real is
/// touched. Patch 35d.
enum LockMyFilesSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Lock my files self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appendingPathComponent("lockfiles-selftest-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: folder) }
        guard (try? manager.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else {
            fatalError("Lock my files self-test: could not make a folder.")
        }
        let key = SymmetricKey(data: Data((0..<32).map { UInt8($0 &* 3) }))
        let other = SymmetricKey(data: Data((0..<32).map { UInt8($0 &* 5 &+ 1) }))
        let plain = Data([0xFF, 0xD8, 0xFF, 0xE0] + (0..<2000).map { UInt8($0 % 251) })
        let url = folder.appendingPathComponent("a.jpg")
        let context = "File.JournalAttachments/a.jpg"
        check((try? plain.write(to: url)) != nil, "could not write a plain file.")

        check(StoredFiles.readFile(at: url, context: context, key: nil) == plain, "a plain file did not read without a key.")
        check(!StoredFiles.isSealed(at: url), "a plain file looked sealed.")
        check(StoredFiles.sealFile(at: url, context: context, key: key) == .sealed, "a plain file was not sealed.")
        check(StoredFiles.isSealed(at: url), "a sealed file did not look sealed.")
        check(StoredFiles.readFile(at: url, context: context, key: key) == plain, "a sealed file did not open to the same bytes.")
        check(StoredFiles.readFile(at: url, context: context, key: other) == nil, "a sealed file opened with the wrong key.")
        check(StoredFiles.readFile(at: url, context: context, key: nil) == nil, "a sealed file opened with no key.")
        check(StoredFiles.readFile(at: url, context: "File.JournalAttachments/b.jpg", key: key) == nil, "a sealed file opened for another name.")

        let sealedBytes = try? Data(contentsOf: url)
        check(StoredFiles.sealFile(at: url, context: context, key: key) == .alreadySealed, "a sealed file was sealed twice.")
        check((try? Data(contentsOf: url)) == sealedBytes, "sealing twice changed the file.")
        check(StoredFiles.sealFile(at: url, context: context, key: other) == .failed, "a sealed file that does not open was called fine.")

        let names = (try? manager.contentsOfDirectory(atPath: folder.path)) ?? []
        check(names == ["a.jpg"], "a half-made copy was left behind: \(names).")

        if var changed = sealedBytes, changed.count > 40 {
            changed[changed.count - 20] ^= 0x01
            let damaged = folder.appendingPathComponent("c.jpg")
            check((try? changed.write(to: damaged)) != nil, "could not write a damaged file.")
            check(StoredFiles.readFile(at: damaged, context: context, key: key) == nil, "a changed file opened.")
        }

        let missing = folder.appendingPathComponent("none.jpg")
        check(StoredFiles.sealFile(at: missing, context: "File.JournalAttachments/none.jpg", key: key) == .gone, "a missing file was not reported as gone.")

        let fresh = folder.appendingPathComponent("d.m4a")
        check((try? Data([1, 2, 3]).write(to: fresh)) != nil, "could not write a fresh file.")
        check(StoredFiles.sealFile(at: fresh, context: "File.VoiceNotes/d.m4a", key: key, skipRecent: true) == .left, "a file written just now was not left alone.")
        check(!StoredFiles.isSealed(at: fresh), "a file written just now was sealed.")
    }
}
#endif
