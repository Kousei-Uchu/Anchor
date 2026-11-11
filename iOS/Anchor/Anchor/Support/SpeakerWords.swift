//
//  SpeakerWords.swift
//  Anchor
//
//  Guessing who is speaking from the words alone (Patch VN4c1, docs/OPTIONAL_FEATURES.md, E2, D38, D64, D77). The
//  words of a recording are cut into numbered pieces, a language model is asked where the speaker seems to change
//  (only from how the words read, it cannot hear anyone), and its answer is turned into the same turns the speaker
//  model and the tapped turns give, so the same people screen can show them. This file only prepares the words and
//  reads the answer. It sends nothing: the one place text goes to a model is `AIAsk`, behind the AI switch and the
//  consent sheet. It keeps nothing, goes nowhere online and makes nothing that can be saved.
//

import Foundation

enum SpeakerWords {
    /// A run of words that is treated as one piece, in seconds from the start of the recording.
    struct Piece: Equatable, Sendable {
        let number: Int
        let start: TimeInterval
        let end: TimeInterval
        let text: String
    }

    /// What is sent, and which pieces it covers.
    struct Prompt: Equatable, Sendable {
        let text: String
        let pieces: [Piece]
        /// False when the words were too long to send in one go and only the first pieces are covered.
        let coversAll: Bool
    }

    /// A pause this long between two words starts a new piece.
    static let pause: TimeInterval = 0.8

    /// A piece never holds more than this many words.
    static let mostWords = 40

    /// The most letters the answer may use, one for each person.
    static let mostPeople = 6

    /// Cuts words into pieces at a pause, after a full stop, question mark or exclamation mark, or when a piece gets
    /// long. Pure: it only works on the words it is given.
    static func pieces(from words: [FileTranscription.Word]) -> [Piece] {
        var out: [Piece] = []
        var current: [FileTranscription.Word] = []
        func close() {
            guard let first = current.first, let last = current.last else { return }
            let text = current.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: " ")
            if !text.isEmpty { out.append(Piece(number: out.count + 1, start: first.start, end: max(last.end, first.start), text: text)) }
            current = []
        }
        for word in words.sorted(by: { $0.start < $1.start }) {
            if let last = current.last, word.start - last.end >= pause { close() }
            current.append(word)
            let trimmed = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let endsSentence = trimmed.last.map { ".?!".contains($0) } ?? false
            if endsSentence || current.count >= mostWords { close() }
        }
        close()
        return out
    }

    /// The numbered pieces as the text that is sent, one `number: words` line each, as many as fit in `limit`
    /// characters. The consent sheet shows this exact text.
    static func prompt(for pieces: [Piece], limit: Int) -> Prompt {
        var lines: [String] = []
        var used = 0
        var taken: [Piece] = []
        for piece in pieces {
            let line = "\(piece.number): \(piece.text)"
            let cost = line.count + (lines.isEmpty ? 0 : 1)
            if used + cost > limit { break }
            lines.append(line)
            taken.append(piece)
            used += cost
        }
        return Prompt(text: lines.joined(separator: "\n"), pieces: taken, coversAll: taken.count == pieces.count)
    }

    /// A piece number, then a letter on its own: `2 B`, `2: B`, `Piece 2 - b`.
    private static let lineShape = try! NSRegularExpression(pattern: #"^(?:piece\s*)?(\d{1,4})\s*[:.\-)]?\s*([A-Za-z])\b"#, options: [.caseInsensitive])

    /// Turns the model's answer into turns. Each line is a piece number and a letter: the speaker from that piece
    /// on. Letters are numbered as people in the order they first appear, so A is Person 1. A line that is not a
    /// number and a letter, a number that is not a piece, a letter past the sixth, or a number that does not come
    /// after the one before is skipped, so a muddled answer gives fewer changes and never a wrong shape. If the
    /// answer says nothing about piece 1, the first person is taken to start there. Nothing readable gives nothing.
    static func turns(from answer: String, pieces: [Piece]) -> [SpeakerSeparation.Turn] {
        guard let firstPiece = pieces.first, let lastPiece = pieces.last else { return [] }
        let known = Set(pieces.map(\.number))
        var starts: [(number: Int, letter: Character)] = []
        for raw in answer.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let match = lineShape.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let numberRange = Range(match.range(at: 1), in: line),
                  let letterRange = Range(match.range(at: 2), in: line),
                  let number = Int(line[numberRange]),
                  known.contains(number),
                  let letter = line[letterRange].uppercased().first,
                  "ABCDEF".contains(letter) else { continue }
            if let last = starts.last, number <= last.number { continue }
            starts.append((number, letter))
        }
        guard !starts.isEmpty else { return [] }
        if starts[0].number != firstPiece.number { starts = [(number: firstPiece.number, letter: "A")] + starts }

        var people: [Character: Int] = [:]
        var out: [SpeakerSeparation.Turn] = []
        let byNumber = Dictionary(uniqueKeysWithValues: pieces.map { ($0.number, $0) })
        for (index, item) in starts.enumerated() {
            guard let piece = byNumber[item.number] else { continue }
            let person: Int
            if let seen = people[item.letter] {
                person = seen
            } else {
                person = people.count + 1
                people[item.letter] = person
            }
            let end = index + 1 < starts.count ? (byNumber[starts[index + 1].number]?.start ?? lastPiece.end) : lastPiece.end
            guard end > piece.start else { continue }
            if let last = out.last, last.person == person {
                out[out.count - 1] = SpeakerSeparation.Turn(person: person, start: last.start, end: end)
            } else {
                out.append(SpeakerSeparation.Turn(person: person, start: piece.start, end: end))
            }
        }
        return out
    }
}

#if DEBUG
/// Checks, in a test build, that words are cut into pieces at pauses and sentence ends, that the sent text is numbered
/// and held to its limit, and that an answer is read into turns: letters are numbered by who appears first, a
/// returning letter is the same person, muddled lines are skipped, and nothing readable gives nothing.
enum SpeakerWordsSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Speaker words self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        func w(_ t: String, _ s: Double, _ e: Double) -> FileTranscription.Word { .init(text: t, start: s, end: e) }
        let words = [
            w("How", 0.0, 0.3), w("are", 0.3, 0.5), w("you?", 0.5, 0.9),
            w("Fine", 1.0, 1.3), w("thanks", 1.3, 1.7),
            w("and", 3.0, 3.2), w("you", 3.2, 3.5),
            w("Good.", 3.6, 4.0)
        ]
        let pieces = SpeakerWords.pieces(from: words)
        check(pieces.map(\.text) == ["How are you?", "Fine thanks", "and you Good."], "cut at a question mark and at a pause: \(pieces.map(\.text))")
        check(pieces.map(\.number) == [1, 2, 3], "numbered from one")
        check(SpeakerWords.pieces(from: []).isEmpty, "no words, no pieces")

        let prompt = SpeakerWords.prompt(for: pieces, limit: 1000)
        check(prompt.text == "1: How are you?\n2: Fine thanks\n3: and you Good." && prompt.coversAll, "numbered lines: \(prompt.text)")
        let cut = SpeakerWords.prompt(for: pieces, limit: 30)
        check(cut.pieces.count == 2 && !cut.coversAll && cut.text.count <= 30, "held to the limit and says so: \(cut.text)")

        let turns = SpeakerWords.turns(from: "1 A\n2 B\n3 A", pieces: pieces)
        check(turns.map(\.person) == [1, 2, 1], "a returning letter is the same person: \(turns)")
        check(turns[0] == SpeakerSeparation.Turn(person: 1, start: 0.0, end: 1.0), "a turn runs to the next piece: \(turns[0])")
        check(turns[2] == SpeakerSeparation.Turn(person: 1, start: 3.0, end: 4.0), "the last runs to the end: \(turns[2])")
        let swapped = SpeakerWords.turns(from: "2: B", pieces: pieces)
        check(swapped.map(\.person) == [1, 2], "piece 1 is the first person when the answer skips it: \(swapped)")
        let muddled = SpeakerWords.turns(from: "hello\n2 B\n2 A\n9 B\n1 Z\nPiece 3 - a", pieces: pieces)
        check(muddled.map(\.person) == [1, 2, 1], "muddled lines are skipped: \(muddled)")
        check(SpeakerWords.turns(from: "I cannot tell.", pieces: pieces).isEmpty, "nothing readable gives nothing")
        check(SpeakerWords.turns(from: "1 A", pieces: []).isEmpty, "no pieces, no turns")
        let one = SpeakerWords.turns(from: "1 A", pieces: pieces)
        check(one.count == 1 && one[0].person == 1 && one[0].end == 4.0, "one person throughout: \(one)")
    }
}
#endif
