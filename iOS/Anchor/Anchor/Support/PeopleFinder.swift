//
//  PeopleFinder.swift
//  Anchor
//
//  Puts words beside who was speaking in one recording (Patch VN4a3, docs/OPTIONAL_FEATURES.md, E2, D38, D63, D64,
//  D74). `SpeakerSeparation` says who spoke when; `FileTranscription` says which word was said when; this lines
//  them up and gives back labelled lines, Person 1, Person 2 and so on.
//
//  It keeps nothing. It makes no storage, database or Keychain calls, goes nowhere online, and what it returns
//  cannot be saved by itself (it is not Codable). It reads the recording only from a plain working copy that it
//  removes in a defer, however the run ends. The people screen goes through this file and never reaches the
//  model or the recogniser itself. `scripts/check-speaker-separation.mjs` fails if any of that stops being true.
//

import Foundation

enum PeopleFinder {
    typealias Turn = SpeakerSeparation.Turn

    /// One person's words, from where they start speaking until another person does.
    struct Line: Equatable, Sendable {
        let person: Int
        let start: TimeInterval
        let text: String
    }

    struct Outcome: Equatable, Sendable {
        let turns: [SpeakerSeparation.Turn]
        let lines: [Line]
        /// False when the phone could not turn the words into text; the people and times are still right.
        let hasWords: Bool
        /// The words with their times, kept in memory while the people screen is open so other turns (VN4b taps, VN4c
        /// guesses) can be lined up with them. Empty when no words were made out. Never saved.
        var words: [FileTranscription.Word] = []

        var personCount: Int { SpeakerSeparation.personCount(in: turns) }

        /// The words cut into numbered pieces, for guessing from the words (Patch VN4c2).
        var pieces: [SpeakerWords.Piece] { SpeakerWords.pieces(from: words) }

        /// The person numbers heard, in the order they first speak.
        var people: [Int] { Set(turns.map(\.person)).sorted() }

        /// How long one person spoke for, in seconds.
        func seconds(of person: Int) -> TimeInterval {
            turns.filter { $0.person == person }.reduce(0) { $0 + ($1.end - $1.start) }
        }
    }

    /// Whether this build carries the speaker model.
    static var isAvailable: Bool { SpeakerSeparation.isAvailable }

    /// The plain line to show for a run that did not finish. Never an error code.
    static func plainText(for error: Error) -> String {
        if let failure = error as? SpeakerSeparation.Failure { return failure.plainText }
        return SpeakerSeparation.Failure.failed.plainText
    }

    /// The start of what one person said, for beside their name, or nil if no words were made out.
    static func preview(of lines: [Line], person: Int, limit: Int = 80) -> String? {
        guard let first = lines.first(where: { $0.person == person }), !first.text.isEmpty else { return nil }
        guard first.text.count > limit else { return first.text }
        return String(first.text.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Who spoke when, and as many of the words as the phone can make out, for one kept recording.
    /// If the words cannot be had (language not ready, permission, nothing made out) the people still come back
    /// and `hasWords` is false, so the screen can say so instead of showing nothing.
    static func find(_ folder: StoredFiles.Folder, _ name: String) async throws -> Outcome {
        let turns = try await SpeakerSeparation.separate(folder, name)
        try Task.checkCancellation()
        return try await withWords(folder, name, turns: turns)
    }

    /// The same, for turns the person tapped (Patch VN4b): no model reads the recording; only the words are made out.
    static func find(_ folder: StoredFiles.Folder, _ name: String, tapped turns: [Turn]) async throws -> Outcome {
        try await withWords(folder, name, turns: turns)
    }

    private static func withWords(_ folder: StoredFiles.Folder, _ name: String, turns: [Turn]) async throws -> Outcome {
        guard let copy = StoredFiles.workingCopy(folder, name) else { throw SpeakerSeparation.Failure.cannotOpen }
        defer { StoredFiles.removeWorkingCopy(copy) }

        let words: [FileTranscription.Word]
        do {
            words = try await FileTranscription.words(at: copy)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return Outcome(turns: turns, lines: [], hasWords: false)
        }
        try Task.checkCancellation()
        return Outcome(turns: turns, lines: lines(words: words, turns: turns), hasWords: true, words: words)
    }

    /// The same words given to other turns (Patch VN4c2): who spoke when changes, the words do not.
    static func relined(_ outcome: Outcome, turns: [Turn]) -> Outcome {
        Outcome(turns: turns, lines: lines(words: outcome.words, turns: turns), hasWords: outcome.hasWords, words: outcome.words)
    }

    // MARK: Lining the words up

    /// Gives each word to the person speaking most while it was said (or, if it falls in a gap, the nearest
    /// turn), then joins neighbouring words by the same person into one line. Pure: it only works on what it is
    /// given.
    static func lines(words: [FileTranscription.Word], turns: [SpeakerSeparation.Turn]) -> [Line] {
        guard !turns.isEmpty else { return [] }
        var out: [Line] = []
        var current: (person: Int, start: TimeInterval, words: [String])?
        for word in words.sorted(by: { $0.start < $1.start }) {
            let person = owner(of: word, in: turns)
            if var open = current, open.person == person {
                open.words.append(word.text)
                current = open
            } else {
                if let open = current { out.append(Line(person: open.person, start: open.start, text: join(open.words))) }
                current = (person, word.start, [word.text])
            }
        }
        if let open = current { out.append(Line(person: open.person, start: open.start, text: join(open.words))) }
        return out
    }

    private static func owner(of word: FileTranscription.Word, in turns: [SpeakerSeparation.Turn]) -> Int {
        var best: (person: Int, overlap: TimeInterval)?
        for turn in turns {
            let overlap = min(word.end, turn.end) - max(word.start, turn.start)
            if overlap > 0, overlap > (best?.overlap ?? 0) { best = (turn.person, overlap) }
        }
        if let best { return best.person }
        // In a gap between turns: the nearest turn by distance from the middle of the word.
        let middle = (word.start + word.end) / 2
        let nearest = turns.min { distance(middle, $0) < distance(middle, $1) }
        return nearest?.person ?? 1
    }

    private static func distance(_ time: TimeInterval, _ turn: SpeakerSeparation.Turn) -> TimeInterval {
        if time < turn.start { return turn.start - time }
        if time > turn.end { return time - turn.end }
        return 0
    }

    private static func join(_ words: [String]) -> String {
        words.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: Writing it down

    /// The lines as text the way Speaker 1 and Speaker 2 are written (VN3): one line a turn, `Name: words`.
    /// `names` holds what the person typed for each person number; anything missing, empty or containing a colon
    /// is written as Person 1, Person 2 and so on.
    static func text(of lines: [Line], names: [Int: String] = [:]) -> String {
        lines.map { line -> String in
            let typed = names[line.person]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let label = (typed.isEmpty || typed.contains(":") || typed.contains("\n") || typed.count > 40) ? "Person \(line.person)" : typed
            return label + ": " + line.text
        }.joined(separator: "\n")
    }
}

#if DEBUG
/// Checks, in a test build, that words go to the person speaking while they were said, that a word in a gap goes
/// to the nearest turn, that neighbouring words by one person become one line, and that names are written safely.
enum PeopleFinderSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("People finder self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let turns = [
            SpeakerSeparation.Turn(person: 1, start: 0, end: 4),
            SpeakerSeparation.Turn(person: 2, start: 5, end: 9)
        ]
        func w(_ t: String, _ s: Double, _ e: Double) -> FileTranscription.Word { .init(text: t, start: s, end: e) }
        let lines = PeopleFinder.lines(words: [
            w("hello", 0.2, 0.6), w("there", 0.7, 1.1),
            w("fine", 5.1, 5.4), w("thanks", 5.5, 6.0),
            w("and", 8.8, 9.3),
            w("you", 9.4, 9.8)
        ], turns: turns)
        check(lines.map(\.person) == [1, 2], "two lines: \(lines)")
        check(lines[0].text == "hello there", "words joined: \(lines[0].text)")
        check(lines[1].text == "fine thanks and you", "a word in the last turn and one just after it go to the nearest: \(lines[1].text)")
        let straddle = PeopleFinder.lines(words: [w("so", 3.9, 5.1)], turns: turns)
        check(straddle.first?.person == 1 || straddle.first?.person == 2, "a word across two turns goes to one")
        check(PeopleFinder.lines(words: [w("x", 0, 1)], turns: []).isEmpty, "no turns, no lines")
        check(PeopleFinder.lines(words: [], turns: turns).isEmpty, "no words, no lines")
        let text = PeopleFinder.text(of: lines, names: [1: "Mum", 2: "a:b"])
        check(text == "Mum: hello there\nPerson 2: fine thanks and you", "names written, a colon refused: \(text)")
        check(PeopleFinder.text(of: lines, names: [1: String(repeating: "x", count: 41)]).hasPrefix("Person 1: "), "a very long name is refused")
        check(PeopleFinder.preview(of: lines, person: 2) == "fine thanks and you", "preview of one person")
        check(PeopleFinder.preview(of: lines, person: 3) == nil, "no preview for someone with no words")
        let long = [PeopleFinder.Line(person: 1, start: 0, text: String(repeating: "a", count: 100))]
        check(PeopleFinder.preview(of: long, person: 1)?.count == 81, "a long preview is cut")
        let outcome = PeopleFinder.Outcome(turns: turns, lines: lines, hasWords: true)
        let swapped = PeopleFinder.relined(PeopleFinder.Outcome(turns: turns, lines: lines, hasWords: true, words: [w("hello", 0.2, 0.6), w("fine", 5.1, 5.4)]), turns: [SpeakerSeparation.Turn(person: 1, start: 0, end: 9)])
        check(swapped.lines.count == 1 && swapped.lines[0].text == "hello fine", "the same words given to other turns")
        check(outcome.people == [1, 2] && outcome.seconds(of: 2) == 4, "people and time spoken")
    }
}
#endif
