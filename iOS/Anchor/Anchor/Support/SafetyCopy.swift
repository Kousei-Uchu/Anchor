import Foundation
import CryptoKit
import SwiftData

/// The safety copy and the way back (Patch 35b1, D15, docs/DECISIONS_EXPLAINED.md).
///
/// An exact copy of everything Anchor has saved: the database, the voice notes and the Journal photos
/// and drawings. It is made, and going back is done, when Anchor starts and BEFORE the database is
/// opened (see `runAtLaunch`, called first thing in `AnchorApp.init`), because files nobody is writing
/// to cannot be half old and half new. Screens only ask for a job; the job runs on the next start.
///
/// Every file in a copy is checked against a fingerprint (SHA-256) kept in the copy's manifest.
/// Going back puts the copy in place and keeps what was there in a set-aside folder, so nothing is
/// deleted. Undo go back swaps the two again. The copy is kept out of phone backups, and is deleted by
/// Clear all data. Nothing here changes what is stored; it only copies and moves files.
enum SafetyCopy {
    enum Request: String {
        case make, goBack, undo
    }

    struct Entry: Codable {
        let path: String
        let size: Int64
        let sha256: String
    }

    struct Manifest: Codable {
        let createdAt: Date
        let entries: [Entry]
    }

    struct Status {
        var exists = false
        var createdAt: Date?
        var files = 0
        var bytes: Int64 = 0
        var hasSetAside = false
        var pending: Request?
        var lastResult: String?
    }

    private struct Failure: Error {
        let message: String
    }

    private static let pendingKey = "safetyCopy.pending"
    private static let resultKey = "safetyCopy.lastResult"
    private static let manifestName = "manifest.json"
    private static let fm = FileManager.default

    // MARK: Places

    private static var support: URL { fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }
    private static var documents: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private static var root: URL { support.appendingPathComponent("SafetyCopy", isDirectory: true) }
    private static var currentDir: URL { root.appendingPathComponent("current", isDirectory: true) }
    private static var buildingDir: URL { root.appendingPathComponent("building", isDirectory: true) }
    private static var asideDir: URL { root.appendingPathComponent("setaside", isDirectory: true) }
    private static var oldAsideDir: URL { root.appendingPathComponent("setaside-old", isDirectory: true) }
    private static var swapDir: URL { root.appendingPathComponent("swap", isDirectory: true) }

    /// The database file as the app opens it, with its two companion files and any folder of
    /// separately stored values that sits beside it.
    private static var storeFile: URL {
        ModelConfiguration(schema: Schema(AnchorSchema.models), isStoredInMemoryOnly: false).url
    }
    private static var storeDir: URL { storeFile.deletingLastPathComponent() }

    /// The database file as the app opens it. Lock my data tidies it, before the app opens it (Patch 35b3).
    static var liveStoreURL: URL { storeFile }

    private static func liveStoreNames() -> [String] {
        let base = storeFile.lastPathComponent
        let support = "." + storeFile.deletingPathExtension().lastPathComponent + "_SUPPORT"
        let names = (try? fm.contentsOfDirectory(atPath: storeDir.path)) ?? []
        return names.filter { $0.hasPrefix(base) || $0 == support }.sorted()
    }

    /// The two folders of files, named as they are inside a copy.
    private static let folderGroups = ["VoiceNotes", "JournalAttachments"]

    private static func liveFolder(_ name: String) -> URL {
        name == "VoiceNotes"
            ? support.appendingPathComponent(name, isDirectory: true)
            : documents.appendingPathComponent(name, isDirectory: true)
    }

    /// Where a file named like `store/default.store` or `VoiceNotes/x.m4a` lives on the phone.
    private static func liveURL(forEntry path: String) -> URL {
        if path.hasPrefix("store/") { return storeDir.appendingPathComponent(String(path.dropFirst("store/".count))) }
        if path.hasPrefix("VoiceNotes/") { return support.appendingPathComponent(path) }
        return documents.appendingPathComponent(path)
    }

    // MARK: Asking for a job, and reading how things stand

    static func request(_ job: Request) {
        UserDefaults.standard.set(job.rawValue, forKey: pendingKey)
    }

    static func cancelRequest() {
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    static func status() -> Status {
        var status = Status()
        status.pending = UserDefaults.standard.string(forKey: pendingKey).flatMap(Request.init(rawValue:))
        status.lastResult = UserDefaults.standard.string(forKey: resultKey)
        status.hasSetAside = fm.fileExists(atPath: asideDir.path)
        if let manifest = readManifest(in: currentDir) {
            status.exists = true
            status.createdAt = manifest.createdAt
            status.files = manifest.entries.count
            status.bytes = manifest.entries.reduce(0) { $0 + $1.size }
        }
        return status
    }

    static func clearLastResult() {
        UserDefaults.standard.removeObject(forKey: resultKey)
    }

    /// Clear all data removes the copy and the set-aside folder as well, so "all" means all.
    static func deleteEverything() {
        try? fm.removeItem(at: root)
        UserDefaults.standard.removeObject(forKey: pendingKey)
        UserDefaults.standard.removeObject(forKey: resultKey)
    }

    /// Deletes the copy only, keeping anything set aside by going back.
    static func deleteCopy() {
        try? fm.removeItem(at: currentDir)
        try? fm.removeItem(at: buildingDir)
    }

    // MARK: The launch step

    /// Runs the waiting job, if there is one. Called before anything opens the database.
    static func runAtLaunch() {
        guard let raw = UserDefaults.standard.string(forKey: pendingKey),
              let job = Request(rawValue: raw) else { return }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        do {
            switch job {
            case .make:
                try make()
                setResult("The safety copy was made and checked.")
            case .goBack:
                try goBack()
                setResult("Anchor went back to the safety copy. What was there before is set aside, and Undo go back brings it back.")
            case .undo:
                try undoGoBack()
                setResult("Undo go back is done. The other set of your data is in place again.")
            }
        } catch let failure as Failure {
            setResult(failure.message)
        } catch {
            setResult("That did not work, and nothing was changed.")
        }
    }

    private static func setResult(_ text: String) {
        UserDefaults.standard.set(text, forKey: resultKey)
    }

    // MARK: Making the copy

    private static func make() throws {
        try? fm.removeItem(at: buildingDir)
        try fm.createDirectory(at: buildingDir, withIntermediateDirectories: true)
        do {
            try copyLive(into: buildingDir)
            let entries = try fingerprints(of: buildingDir)
            if entries.isEmpty { throw Failure(message: "There is nothing saved yet to copy.") }
            for entry in entries {
                let (hash, size) = try sha256(of: liveURL(forEntry: entry.path))
                if hash != entry.sha256 || size != entry.size {
                    throw Failure(message: "The copy did not match what is saved, so it was thrown away and nothing was changed.")
                }
            }
            try writeManifest(Manifest(createdAt: Date(), entries: entries), in: buildingDir)
            try? fm.removeItem(at: currentDir)
            try fm.moveItem(at: buildingDir, to: currentDir)
            protectAndHideFromBackups()
        } catch {
            try? fm.removeItem(at: buildingDir)
            throw error
        }
    }

    // MARK: Going back, and undoing it

    private static func goBack() throws {
        guard let manifest = readManifest(in: currentDir), try matches(manifest, in: currentDir) else {
            throw Failure(message: "The safety copy did not check out, so nothing was changed.")
        }
        try? fm.removeItem(at: oldAsideDir)
        let hadAside = fm.fileExists(atPath: asideDir.path)
        if hadAside { try fm.moveItem(at: asideDir, to: oldAsideDir) }
        do {
            try fm.createDirectory(at: asideDir, withIntermediateDirectories: true)
            try moveLive(into: asideDir)
            try copyBack(from: currentDir)
            for entry in manifest.entries {
                let (hash, size) = try sha256(of: liveURL(forEntry: entry.path))
                if hash != entry.sha256 || size != entry.size {
                    throw Failure(message: "Going back did not check out, so Anchor put everything back as it was.")
                }
            }
            try? fm.removeItem(at: oldAsideDir)
        } catch {
            removeLive()
            try? moveToLive(from: asideDir)
            try? fm.removeItem(at: asideDir)
            if hadAside { try? fm.moveItem(at: oldAsideDir, to: asideDir) }
            if error is Failure { throw error }
            throw Failure(message: "Going back did not work, so Anchor put everything back as it was.")
        }
    }

    /// Swaps what is on the phone with what going back set aside, so doing it twice is going back again.
    private static func undoGoBack() throws {
        guard fm.fileExists(atPath: asideDir.path) else {
            throw Failure(message: "There is nothing set aside to bring back.")
        }
        try? fm.removeItem(at: swapDir)
        try fm.createDirectory(at: swapDir, withIntermediateDirectories: true)
        do {
            try moveLive(into: swapDir)
            try moveToLive(from: asideDir)
            try? fm.removeItem(at: asideDir)
            try fm.moveItem(at: swapDir, to: asideDir)
        } catch {
            removeLive()
            try? moveToLive(from: swapDir)
            try? fm.removeItem(at: swapDir)
            throw Failure(message: "Undo go back did not work, so Anchor put everything back as it was.")
        }
    }

    // MARK: Moving and copying files

    private static func copyLive(into dir: URL) throws {
        let storeOut = dir.appendingPathComponent("store", isDirectory: true)
        try fm.createDirectory(at: storeOut, withIntermediateDirectories: true)
        for name in liveStoreNames() {
            try fm.copyItem(at: storeDir.appendingPathComponent(name), to: storeOut.appendingPathComponent(name))
        }
        for group in folderGroups where fm.fileExists(atPath: liveFolder(group).path) {
            try fm.copyItem(at: liveFolder(group), to: dir.appendingPathComponent(group, isDirectory: true))
        }
    }

    private static func moveLive(into dir: URL) throws {
        let storeOut = dir.appendingPathComponent("store", isDirectory: true)
        try fm.createDirectory(at: storeOut, withIntermediateDirectories: true)
        for name in liveStoreNames() {
            try fm.moveItem(at: storeDir.appendingPathComponent(name), to: storeOut.appendingPathComponent(name))
        }
        for group in folderGroups where fm.fileExists(atPath: liveFolder(group).path) {
            try fm.moveItem(at: liveFolder(group), to: dir.appendingPathComponent(group, isDirectory: true))
        }
    }

    private static func moveToLive(from dir: URL) throws {
        let storeIn = dir.appendingPathComponent("store", isDirectory: true)
        for name in (try? fm.contentsOfDirectory(atPath: storeIn.path)) ?? [] {
            try fm.moveItem(at: storeIn.appendingPathComponent(name), to: storeDir.appendingPathComponent(name))
        }
        for group in folderGroups {
            let source = dir.appendingPathComponent(group, isDirectory: true)
            guard fm.fileExists(atPath: source.path) else { continue }
            try fm.moveItem(at: source, to: liveFolder(group))
        }
    }

    private static func copyBack(from dir: URL) throws {
        let storeIn = dir.appendingPathComponent("store", isDirectory: true)
        for name in (try? fm.contentsOfDirectory(atPath: storeIn.path)) ?? [] {
            try fm.copyItem(at: storeIn.appendingPathComponent(name), to: storeDir.appendingPathComponent(name))
        }
        for group in folderGroups {
            let source = dir.appendingPathComponent(group, isDirectory: true)
            guard fm.fileExists(atPath: source.path) else { continue }
            try fm.copyItem(at: source, to: liveFolder(group))
        }
    }

    private static func removeLive() {
        for name in liveStoreNames() {
            try? fm.removeItem(at: storeDir.appendingPathComponent(name))
        }
        for group in folderGroups {
            try? fm.removeItem(at: liveFolder(group))
        }
    }

    // MARK: Fingerprints

    private static func sha256(of url: URL) throws -> (String, Int64) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var size: Int64 = 0
        while true {
            let chunk = try handle.read(upToCount: 1 << 20) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
            size += Int64(chunk.count)
        }
        return (hasher.finalize().map { String(format: "%02x", $0) }.joined(), size)
    }

    private static func fingerprints(of dir: URL) throws -> [Entry] {
        let base = dir.standardizedFileURL.path + "/"
        guard let walker = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var entries: [Entry] = []
        for case let url as URL in walker {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(base) else { continue }
            let relative = String(path.dropFirst(base.count))
            if relative == manifestName { continue }
            let (hash, size) = try sha256(of: url)
            entries.append(Entry(path: relative, size: size, sha256: hash))
        }
        return entries.sorted { $0.path < $1.path }
    }

    private static func matches(_ manifest: Manifest, in dir: URL) throws -> Bool {
        for entry in manifest.entries {
            let url = dir.appendingPathComponent(entry.path)
            guard fm.fileExists(atPath: url.path) else { return false }
            let (hash, size) = try sha256(of: url)
            if hash != entry.sha256 || size != entry.size { return false }
        }
        return !manifest.entries.isEmpty
    }

    private static func readManifest(in dir: URL) -> Manifest? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(manifestName)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Manifest.self, from: data)
    }

    private static func writeManifest(_ manifest: Manifest, in dir: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: dir.appendingPathComponent(manifestName), options: .atomic)
    }

    /// The copy is a plain copy, so it gets the phone's file protection and stays out of phone backups.
    private static func protectAndHideFromBackups() {
        var url = root
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try? fm.setAttributes(attributes, ofItemAtPath: root.path)
        if let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let item as URL in walker {
                try? fm.setAttributes(attributes, ofItemAtPath: item.path)
            }
        }
    }
}
