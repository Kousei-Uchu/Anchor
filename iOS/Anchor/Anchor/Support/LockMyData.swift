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
    private static let defaults = UserDefaults.standard

    private static var stored: Stored {
        defaults.string(forKey: stateKey).flatMap(Stored.init(rawValue:)) ?? .off
    }

    /// True once a run has finished and every item has checked out. This is what turns `FieldLock.isOn` on at launch.
    static var isOn: Bool { stored == .on }

    struct Status {
        var isOn = false
        var lockedAt: Date?
        var items = 0
        var waiting = false
        var scrubWaiting = false
        var lastResult: String?
    }

    static func status() -> Status {
        var status = Status()
        status.isOn = isOn
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
        guard !isOn else { return }
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
            setResult("Your text is locked. Clearing the old plain copies out of the database file did not run, because the file could not be opened for it.")
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
                setResult("Your text is locked. Clearing the old plain copies out of the database file did not finish, so some may still be in it. Nothing was lost.")
                return
            }
        }
        setResult("Your text is locked, and the database file was rebuilt so the old plain copies are gone from it. The safety copy still holds your text unlocked, so delete it when you are happy.")
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
            kind(RecoveryCounter.self), kind(RecoveryMotivation.self), kind(RecoveryDayEntry.self),
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
        guard !isOn else {
            setResult("Your text was already locked, so nothing was done.")
            return
        }
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

        defaults.set(Stored.running.rawValue, forKey: stateKey)
        FieldLock.isOn = true
        do {
            let report = try lockAll(in: container)
            // One write turns it on, and the same write ends the run.
            defaults.set(Date().timeIntervalSince1970, forKey: lockedAtKey)
            defaults.set(report.items, forKey: itemsKey)
            defaults.set(true, forKey: scrubKey)
            defaults.set(Stored.on.rawValue, forKey: stateKey)
            setResult("Locked \(report.items) \(report.items == 1 ? "item" : "items") and checked every one. Close Anchor and open it again to finish: the old plain copies are cleared out of the database file on that start.")
        } catch {
            FieldLock.isOn = false
            defaults.set(Stored.off.rawValue, forKey: stateKey)
            SafetyCopy.request(.goBack)
            let reason = (error as? Failure)?.message ?? "Something did not work."
            setResult("\(reason) Nothing is kept: Anchor will go back to the safety copy the next time it starts. Close it from the app switcher and open it again, and do not add anything before that.")
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

    private static func keyWorks(_ key: SymmetricKey) -> Bool {
        let probe = "anchor lock probe"
        guard let sealed = try? FieldCipher.seal(probe, context: "LockMyData.probe", key: key) else { return false }
        return FieldCipher.open(sealed, context: "LockMyData.probe", key: key) == probe
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
        let counter = RecoveryCounter(name: "Mine")
        let runs = counter.runsData
        context.insert(entry)
        context.insert(contact)
        context.insert(list)
        context.insert(counter)
        try? context.save()
        check(entry.textSealed == nil && !entry.lockedFieldsAreSealed(), "an item was sealed while locking was off.")

        // Lock them.
        FieldLock.isOn = true
        guard let report = try? LockMyData.lockAll(in: container) else { fatalError("Lock my data self-test: locking threw.") }
        check(report.items == 4, "the number of locked items was \(report.items), not 4.")
        check(entry.text == "plain journal words" && entry.textPlain.isEmpty && entry.lockedFieldsAreSealed(), "a journal entry was not locked and readable.")
        check(contact.name == "Sam" && contact.discordUserID == "42" && contact.lockedFieldsAreSealed(), "a contact was not locked and readable.")
        check(list.items.count == 1 && list.items[0].text == "keys" && list.lockedFieldsAreSealed(), "a list was not locked and readable.")
        check(counter.runsData == runs && counter.lockedFieldsAreSealed(), "a counter was not locked and readable.")

        // Again: nothing is sealed twice and nothing changes.
        let stored = entry.textSealed
        guard (try? LockMyData.lockAll(in: container)) != nil else { fatalError("Lock my data self-test: a second run threw.") }
        check(entry.textSealed == stored, "a second run changed a sealed value.")

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
