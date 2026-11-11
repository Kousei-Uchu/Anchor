//
//  TapTurns.swift
//  Anchor
//
//  Who is speaking, from taps (Patch VN4b, docs/OPTIONAL_FEATURES.md, E2, D38, D63). The person plays a recording
//  back and taps who is speaking each time it changes; this turns those taps into the same turns the speaker model
//  gives, so the same people screen can use them. No model reads the recording and nothing about a voice is
//  computed: the only numbers are the times the person tapped. Pure, and kept nowhere.
//

import Foundation

enum TapTurns {
    /// One tap: this person starts speaking at this time, in seconds from the start of the recording.
    struct Tap: Equatable, Sendable {
        let person: Int
        let time: TimeInterval
    }

    /// The most people a person can tap between.
    static let mostPeople = 6

    /// Turns from taps. A turn lasts until the next tap and the last until the end of the recording. A tap for the
    /// person already speaking changes nothing, taps are put in time order, and a stretch under a tenth of a second
    /// (a slip of the finger) is dropped by merging it into what came before.
    static func turns(from taps: [Tap], duration: TimeInterval) -> [SpeakerSeparation.Turn] {
        let ordered = taps
            .filter { $0.person >= 1 && $0.person <= mostPeople && $0.time >= 0 && $0.time < max(duration, 0.1) }
            .sorted { $0.time < $1.time }
        var starts: [Tap] = []
        for tap in ordered {
            if let last = starts.last {
                if last.person == tap.person { continue }
                if tap.time - last.time < 0.1 { starts.removeLast(); if starts.last?.person == tap.person { continue } }
            }
            starts.append(tap)
        }
        var out: [SpeakerSeparation.Turn] = []
        for (index, tap) in starts.enumerated() {
            let end = index + 1 < starts.count ? starts[index + 1].time : max(duration, tap.time)
            if end > tap.time { out.append(SpeakerSeparation.Turn(person: tap.person, start: tap.time, end: end)) }
        }
        return out
    }
}

#if DEBUG
/// Checks, in a test build, that taps become turns that run to the next tap, that the same person tapped twice
/// changes nothing, that taps out of order are sorted, that a slip of the finger is merged away, and that nothing
/// in gives nothing out.
enum TapTurnsSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Tap turns self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        typealias T = TapTurns.Tap
        let turns = TapTurns.turns(from: [T(person: 2, time: 5), T(person: 1, time: 0), T(person: 1, time: 2), T(person: 2, time: 8)], duration: 10)
        check(turns.map(\.person) == [1, 2], "two turns: \(turns)")
        check(turns[0] == SpeakerSeparation.Turn(person: 1, start: 0, end: 5), "runs to the next tap: \(turns[0])")
        check(turns[1] == SpeakerSeparation.Turn(person: 2, start: 5, end: 10), "the last runs to the end: \(turns[1])")
        let slip = TapTurns.turns(from: [T(person: 1, time: 0), T(person: 2, time: 4), T(person: 1, time: 4.05)], duration: 6)
        check(slip == [SpeakerSeparation.Turn(person: 1, start: 0, end: 6)], "a slip is merged away: \(slip)")
        check(TapTurns.turns(from: [], duration: 10).isEmpty, "nothing in, nothing out")
        check(TapTurns.turns(from: [T(person: 9, time: 1)], duration: 10).isEmpty, "a person out of range is ignored")
        check(TapTurns.turns(from: [T(person: 1, time: 12)], duration: 10).isEmpty, "a tap after the end is ignored")
    }
}
#endif
