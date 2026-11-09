//
//  SpeakerLabels.swift
//  Anchor
//
//  Who is speaking, inside one recording (Patch VN3, docs/OPTIONAL_FEATURES.md, E2, D38). While Dictate listens,
//  the person taps Speaker 1 or Speaker 2 as the speaker changes, and what is heard next goes on a new line
//  that starts with that label. Nothing here listens to a voice or tells voices apart: the person says when it
//  changes. A label is plain text in the entry like any other word, and nothing about a speaker is kept
//  anywhere else, so there is no voiceprint, no profile and no list of names.
//

import Foundation

enum SpeakerLabels {
    static let names = ["Speaker 1", "Speaker 2"]

    static func name(_ number: Int) -> String { names[max(0, min(number - 1, names.count - 1))] }

    /// Whether a paragraph has a line that starts with one of the labels.
    static func isUsed(in text: String) -> Bool {
        text.components(separatedBy: "\n").contains { line in
            names.contains { line.hasPrefix($0 + ": ") || line == $0 + ":" }
        }
    }

    /// Replaces the label at the start of each line, and nothing else. A new name must be plain: no line
    /// break and no colon, and not empty, otherwise the label is left as it is.
    static func renamed(_ text: String, first: String, second: String) -> String {
        let replacements = [(names[0], clean(first)), (names[1], clean(second))]
        return text.components(separatedBy: "\n").map { line -> String in
            for (old, new) in replacements {
                guard let new, new != old else { continue }
                if line.hasPrefix(old + ": ") { return new + ": " + String(line.dropFirst(old.count + 2)) }
                if line == old + ":" { return new + ":" }
            }
            return line
        }
        .joined(separator: "\n")
    }

    private static func clean(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(":"), !trimmed.contains("\n"), trimmed.count <= 40 else { return nil }
        return trimmed
    }

    /// Drops a last line that is only a label with nothing said after it, left when the person tapped a
    /// speaker and then stopped.
    static func trimmingEmptyTurn(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        while let last = lines.last,
              names.contains(where: { last.trimmingCharacters(in: .whitespaces) == $0 + ":" }) {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }
}

#if DEBUG
/// Checks, in a test build, that turns are written and renamed as they should be: words go on lines that start
/// with the label, words said before the first tap stay unlabelled, tapping the same speaker twice changes
/// nothing, renaming touches only line starts, and a label with nothing after it is dropped.
enum SpeakerLabelsSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Speaker labels self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        var target = DictationTarget(blockID: UUID(), base: "Notes:", lastWritten: "Notes:")
        target.lastHeard = "hello there"
        target.startTurn("Speaker 1")
        target.lastHeard = "hello there how are you"
        target.startTurn("Speaker 1")
        check(target.turns.count == 1, "the same speaker twice changes nothing")
        target.startTurn("Speaker 2")
        target.lastHeard = "hello there how are you fine thanks"
        let written = target.text(for: target.lastHeard)
        check(written == "Notes:\nhello there\nSpeaker 1: how are you\nSpeaker 2: fine thanks", "turns written on their own lines: \(written)")
        check(SpeakerLabels.isUsed(in: written), "labels are found")
        let renamed = SpeakerLabels.renamed(written + "\nSpeaker 1 said so", first: "Mum", second: "Dr Lee")
        check(renamed.contains("\nMum: how are you") && renamed.contains("\nDr Lee: fine thanks") && renamed.hasSuffix("Speaker 1 said so"), "only line starts are renamed")
        check(SpeakerLabels.renamed("Speaker 1: hi", first: "a:b", second: "x") == "Speaker 1: hi", "a name with a colon is refused")
        check(SpeakerLabels.trimmingEmptyTurn("Speaker 1: hi\nSpeaker 2: ") == "Speaker 1: hi", "an empty turn is dropped")
        var fresh = DictationTarget(blockID: UUID(), base: "", lastWritten: "")
        fresh.startTurn("Speaker 2")
        fresh.lastHeard = "first words"
        check(fresh.text(for: fresh.lastHeard) == "Speaker 2: first words", "a turn at the very start has no blank line")
    }
}
#endif
