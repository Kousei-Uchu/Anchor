//
//  SpeakerExport.swift
//  Anchor
//
//  Speaker tags in exports (Patch VN5, docs/OPTIONAL_FEATURES.md, E2, D43, D64, D79). A voice note that was
//  labelled with Label who is speaking, Find who is speaking or Replay and tap leaves lines in a Journal entry
//  that start with a name and a colon. When an entry is handed to someone, the person can choose, for each
//  person in it, whether the name is shown, hidden (the lines start with Speaker A, Speaker B and so on) or
//  the lines are left out. The choice is made on the export screen, for that export only.
//
//  Nothing is kept. The choices are a plain value held by the export screen and dropped with it, they are not
//  Codable, and this file makes no storage, database, Keychain, file or network call. It reads text it is given
//  and returns text. The full JSON and the encrypted backup never call it, so a restore stays exact.
//  `scripts/check-speaker-separation.mjs` fails if any of that stops being true.
//

import Foundation

/// What one export does with one person's lines.
enum SpeakerExportMode: String, CaseIterable, Identifiable, Sendable {
    case showName
    case hideName
    case leaveOut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .showName: return "Show name"
        case .hideName: return "Hide name"
        case .leaveOut: return "Leave out"
        }
    }
}

/// One Journal entry that has people in it, as the export screen lists it.
struct SpeakerExportRow: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let people: [String]
}

/// The choices made on one export screen, by entry and then by the name that starts a person's lines. Only the
/// choices that change something are held, so an empty value means the export is exactly as it was before.
/// It lives in the screen's state and is dropped with the screen.
struct SpeakerExportChoices: Equatable {
    private(set) var byEntry: [UUID: [String: SpeakerExportMode]] = [:]

    /// The choices for one entry, ready for `JournalBlocks.sharedText`.
    func modes(for entry: UUID) -> [String: SpeakerExportMode] {
        byEntry[entry] ?? [:]
    }

    func mode(entry: UUID, person: String) -> SpeakerExportMode {
        byEntry[entry]?[person] ?? .showName
    }

    mutating func set(_ mode: SpeakerExportMode, entry: UUID, person: String) {
        var forEntry = byEntry[entry] ?? [:]
        if mode == .showName {
            forEntry[person] = nil
        } else {
            forEntry[person] = mode
        }
        byEntry[entry] = forEntry.isEmpty ? nil : forEntry
    }

    /// The same choice for every person in every listed entry.
    mutating func setAll(_ mode: SpeakerExportMode, in rows: [SpeakerExportRow]) {
        for row in rows {
            for person in row.people {
                set(mode, entry: row.id, person: person)
            }
        }
    }

    /// Drops choices for entries that are no longer listed, for example after the person left an entry out.
    mutating func keepOnly(_ rows: [SpeakerExportRow]) {
        let listed = Set(rows.map(\.id))
        for entry in byEntry.keys where !listed.contains(entry) {
            byEntry[entry] = nil
        }
    }

    var isEmpty: Bool { byEntry.isEmpty }
}

enum SpeakerExport {
    /// Names Anchor writes itself when a person has not typed one.
    static func isStandardLabel(_ name: String) -> Bool {
        if SpeakerLabels.names.contains(name) { return true }
        guard name.hasPrefix("Person "), let number = Int(name.dropFirst(7)) else { return false }
        return number >= 1 && number <= 6
    }

    /// The name at the start of a line, when the line is a name, a colon, and then a space and words or nothing.
    /// A name is letters, digits, spaces, full stops, apostrophes and hyphens, starts with a letter and is at most
    /// 40 characters, so a Markdown line, a label in square brackets or a web address is never taken for a person.
    static func candidate(_ line: String) -> String? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let name = String(line[line.startIndex..<colon])
        let after = line[line.index(after: colon)...]
        guard after.isEmpty || after.hasPrefix(" ") else { return nil }
        guard !name.isEmpty, name.count <= 40, let first = name.first, first.isLetter else { return nil }
        guard name == name.trimmingCharacters(in: .whitespaces) else { return nil }
        let plain = name.allSatisfy { character in
            character.isLetter || character.isNumber || character == " " || character == "." || character == "'"
                || character == "\u{2019}" || character == "-"
        }
        return plain ? name : nil
    }

    /// The person speaking on each line, or nil where the line is not a person's. A line counts when its name is
    /// one Anchor writes itself, or when it sits in a run of lines that start with at least two different names,
    /// which is how a conversation reads. One line such as Note: buy milk is never taken for a person.
    static func speakers(in lines: [String]) -> [String?] {
        let found = lines.map { candidate($0) }
        var result = [String?](repeating: nil, count: lines.count)
        var index = 0
        while index < found.count {
            if found[index] == nil {
                index += 1
                continue
            }
            var end = index
            while end < found.count, found[end] != nil { end += 1 }
            let names = found[index..<end].compactMap { $0 }
            let isConversation = names.count >= 2 && Set(names).count >= 2
            for position in index..<end {
                if let name = found[position], isConversation || isStandardLabel(name) {
                    result[position] = name
                }
            }
            index = end
        }
        return result
    }

    /// The people in an entry, in the order they first speak.
    static func people(in text: String) -> [String] {
        firstAppearances(speakers(in: text.components(separatedBy: "\n")))
    }

    private static func firstAppearances(_ speakers: [String?]) -> [String] {
        var seen: [String] = []
        for case let name? in speakers where !seen.contains(name) {
            seen.append(name)
        }
        return seen
    }

    /// Applies the choices to an entry's text. A shown name is left as it is. A hidden name is replaced at the
    /// start of that person's lines by Speaker A, Speaker B and so on, given in the order the people first speak
    /// in this entry, skipping a label that someone in the entry already has. A person who is left out loses every
    /// line that starts with their name. Only the start of a line is read, so a name inside what someone said
    /// stays as it was, and so do words on a line that does not start with a name.
    static func apply(_ text: String, modes: [String: SpeakerExportMode]) -> String {
        guard modes.values.contains(where: { $0 != .showName }) else { return text }
        let lines = text.components(separatedBy: "\n")
        let owners = speakers(in: lines)
        let everyone = firstAppearances(owners)

        var hidden: [String: String] = [:]
        var taken = Set(everyone)
        var next = 0
        for name in everyone where modes[name] == .hideName {
            var label = "Speaker " + letter(next)
            next += 1
            while taken.contains(label) {
                label = "Speaker " + letter(next)
                next += 1
            }
            taken.insert(label)
            hidden[name] = label
        }

        var out: [String] = []
        for (index, line) in lines.enumerated() {
            guard let name = owners[index] else {
                out.append(line)
                continue
            }
            switch modes[name] ?? .showName {
            case .showName:
                out.append(line)
            case .leaveOut:
                break
            case .hideName:
                out.append((hidden[name] ?? name) + String(line.dropFirst(name.count)))
            }
        }
        return out.joined(separator: "\n")
    }

    /// A, B, C and on to Z, then plain numbers.
    private static func letter(_ index: Int) -> String {
        if index < 26 { return String(Character(UnicodeScalar(UInt8(65 + index)))) }
        return String(index + 1)
    }
}

#if DEBUG
/// Checks, in a test build, that people are found only in a conversation or under the names Anchor writes, that a
/// hidden name gets a letter that nobody already has, that a left out person loses their lines and nothing
/// else, and that an entry with a tool's shorter version in it loses that version when anyone is hidden or left
/// out, because a shorter version can carry a name or words.
enum SpeakerExportSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Speaker export self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true

        let dictated = "Notes:\nhello there\nSpeaker 1: how are you\nSpeaker 2: fine thanks"
        check(SpeakerExport.people(in: dictated) == ["Speaker 1", "Speaker 2"], "the labels written while dictating are found: \(SpeakerExport.people(in: dictated))")
        check(SpeakerExport.people(in: "Note: buy milk").isEmpty, "one line with a colon is not a person")
        check(SpeakerExport.people(in: "[Original: the writer's own words]\nhttp://example.com: hi").isEmpty, "a label in brackets and a web address are not people")
        check(SpeakerExport.people(in: "Person 2: hello") == ["Person 2"], "a name Anchor writes counts on its own")
        check(SpeakerExport.people(in: "Mum: hi\nDr Lee: hello\nMum: bye") == ["Mum", "Dr Lee"], "a typed name counts in a conversation, in the order first heard")
        check(SpeakerExport.people(in: "Mum:\nDr Lee: hello") == ["Mum", "Dr Lee"], "a name with nothing after it is a line too")

        let chat = "Mum: hi\nDr Lee: hello\nMum: bye"
        check(SpeakerExport.apply(chat, modes: [:]) == chat, "no choice changes nothing")
        check(SpeakerExport.apply(chat, modes: ["Mum": .showName]) == chat, "showing a name changes nothing")
        check(SpeakerExport.apply(chat, modes: ["Dr Lee": .leaveOut]) == "Mum: hi\nMum: bye", "a left out person loses their lines only")
        check(SpeakerExport.apply(chat, modes: ["Mum": .hideName]) == "Speaker A: hi\nDr Lee: hello\nSpeaker A: bye", "a hidden name becomes a letter")
        check(SpeakerExport.apply(chat, modes: ["Mum": .hideName, "Dr Lee": .hideName]) == "Speaker A: hi\nSpeaker B: hello\nSpeaker A: bye", "letters follow who speaks first")
        check(SpeakerExport.apply("Speaker A: x\nMum: y", modes: ["Mum": .hideName]) == "Speaker A: x\nSpeaker B: y", "a letter someone already has is skipped")
        check(SpeakerExport.apply("Mum:\nDr Lee: hello", modes: ["Mum": .leaveOut]) == "Dr Lee: hello", "an empty line of a left out person goes too")
        check(SpeakerExport.apply("Mum: tell Dr Lee\nDr Lee: ok", modes: ["Dr Lee": .hideName]) == "Mum: tell Dr Lee\nSpeaker A: ok", "only the start of a line is changed")
        check(SpeakerExport.apply("Note: buy milk", modes: ["Note": .leaveOut]) == "Note: buy milk", "a line that is not a person's is never touched")

        var choices = SpeakerExportChoices()
        let entry = UUID()
        choices.set(.hideName, entry: entry, person: "Mum")
        check(choices.mode(entry: entry, person: "Mum") == .hideName && choices.modes(for: entry).count == 1, "a choice is held")
        choices.set(.showName, entry: entry, person: "Mum")
        check(choices.isEmpty, "going back to showing the name holds nothing")
        let row = SpeakerExportRow(id: entry, date: .now, people: ["Mum", "Dr Lee"])
        choices.setAll(.leaveOut, in: [row])
        check(choices.modes(for: entry).count == 2, "one choice for everyone in the list")
        choices.keepOnly([])
        check(choices.isEmpty, "choices for an entry that is no longer listed are dropped")

        // Through the one function every export uses.
        let voice = "[Voice note](anchorvoice://v1?f=a.m4a)"
        let withBlocks = voice + "\n" + chat + "\n" + JournalAssist(rewrite: "Mum and Dr Lee said hello.", original: chat).markdownLine
        let shared = JournalBlocks.sharedText(withBlocks, includeAssist: false, speakers: ["Dr Lee": .leaveOut])
        check(shared == "Mum: hi\nMum: bye", "left out through the shared text: \(shared)")
        let kept = JournalBlocks.sharedText(withBlocks, includeAssist: true, speakers: [:])
        check(kept.contains("Mum and Dr Lee said hello."), "with no choice the shorter version still comes when ticked")
        let dropped = JournalBlocks.sharedText(withBlocks, includeAssist: true, speakers: ["Mum": .hideName])
        check(!dropped.contains("Mum") && !dropped.contains("Dr Lee said hello") && dropped.contains("Speaker A: hi"), "the shorter version is left out when a name is hidden: \(dropped)")
    }
}
#endif
