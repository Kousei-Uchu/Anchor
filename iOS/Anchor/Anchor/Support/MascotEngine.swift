//
//  MascotEngine.swift
//  Anchor
//
//  Lightweight local state machine. This file must never call an LLM, never
//  format free-form strings into something that reads as "written for this
//  moment," and never author new sentences. Its only job is: given a
//  trigger and the current mood, pick one line out of the existing
//  MascotLine pool. If a matching mood has no lines, it falls back to
//  .neutral rather than inventing something.
//

import Foundation
import SwiftData

@MainActor
struct MascotEngine {
    let context: ModelContext

    /// Returns a single line to show for this trigger, preferring an exact
    /// mood match, falling back to .neutral, and returning nil if the pool
    /// truly has nothing yet (first launch, before the content pack seeds).
    ///
    /// Deliberately does NOT use `#Predicate` to filter by `trigger` here.
    /// SwiftData's `#Predicate` macro has real, documented reliability
    /// issues comparing enum properties with `==` — when it fails, the
    /// error is silently swallowed by the `try?` a caller would reasonably
    /// write, meaning this could return `nil` on every single call with no
    /// visible error anywhere, which matches "the mascot never seems to
    /// say anything" exactly. These pools are small (tens of lines, not
    /// thousands), so fetching everything and filtering in plain Swift —
    /// where enum equality is unconditionally reliable — costs nothing and
    /// removes that failure mode entirely.
    func line(for trigger: MascotTrigger, mood: MascotMood) -> MascotLine? {
        guard let allLines = try? context.fetch(FetchDescriptor<MascotLine>()), !allLines.isEmpty else {
            return nil
        }
        let candidates = allLines.filter { $0.trigger == trigger }
        guard !candidates.isEmpty else { return nil }

        if let exact = candidates.filter({ $0.mood == mood }).randomElement() {
            return exact
        }
        return candidates.filter({ $0.mood == .neutral }).randomElement() ?? candidates.randomElement()
    }

    /// Seeds a minimal starter set so the app isn't silent on first launch,
    /// before the user's own reviewed content pack is imported. These are
    /// intentionally plain and low-key — not trying to do emotional work
    /// on their own, just present. Replace/extend via the real content pack.
    static func seedIfNeeded(context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<MascotLine>())
        guard (existing ?? []).isEmpty else { return }

        let starter: [(MascotTrigger, MascotMood, String)] = [
            (.appOpen, .neutral, "Hey. I'm here."),
            (.appOpen, .quietDay, "No pressure to do anything right now."),
            (.checkInPrompt, .gentle, "Want to check in? Totally fine to skip."),
            (.groundingToolOffered, .gentle, "Here's what's near you right now."),
            (.appointmentReminder, .neutral, "Your next session is coming up."),
        ]
        for (trigger, mood, text) in starter {
            context.insert(MascotLine(trigger: trigger, mood: mood, text: text, isUserAuthored: false))
        }

        // A real request was "1000 prompts, maybe dynamic" — this is a
        // curated, reviewed set instead, on purpose: dynamic generation
        // would mean an LLM authoring a prompt at runtime, which breaks the
        // same rule that applies everywhere else in this app (pre-written
        // pools only, nothing generated live). A rotating pool this size
        // still feels fresh across normal use without needing to fake a
        // number nobody could actually hand-review.
        for prompt in journalPrompts {
            context.insert(MascotLine(trigger: .journalPrompt, mood: .neutral, text: prompt, isUserAuthored: false))
        }
    }

    private static let journalPrompts: [String] = [
        "What's taking up the most space in your head right now?",
        "What's something small that went okay today?",
        "If today had a weather forecast, what would it be?",
        "What's something you're avoiding thinking about?",
        "What's a conversation that's been sitting with you lately?",
        "What do you wish someone would ask you right now?",
        "What's something you did today that you'd do again?",
        "What's something you did today you wouldn't repeat?",
        "What's a worry that keeps circling back?",
        "What's something you're looking forward to, even a little?",
        "Who crossed your mind today, and why?",
        "What's a rule you hold yourself to that you'd never hold someone else to?",
        "What's something that made you laugh, or almost did?",
        "What does your body feel like right now?",
        "What's something you needed today that you didn't get?",
        "What's something you needed today that you did get?",
        "If you could say one true thing out loud right now, what would it be?",
        "What's a memory that showed up uninvited today?",
        "What's something you're proud of that nobody noticed?",
        "What's a decision you're avoiding making?",
        "What would you tell yourself from this morning?",
        "What's something that felt heavier than it should have today?",
        "What's a small comfort you leaned on today?",
        "What's something you wish you'd said differently?",
        "What's a question you don't know the answer to right now?",
        "What's something you're curious about, even if it's unrelated to anything?",
        "What's a place you wish you were right now?",
        "What's something you're carrying that isn't actually yours to carry?",
        "What's one thing that would make tomorrow 5% easier?",
        "What's a pattern you've noticed in yourself lately?",
        "What's something you did purely for yourself today?",
        "What's a fear that felt smaller once you looked at it directly?",
        "What's something you're grateful nobody saw today?",
        "What's a boundary you held today, or wish you had?",
        "What's something you're still figuring out about yourself?",
        "What's a sound, smell, or song that shifted your mood today?",
        "What's something you did today that your younger self would be surprised by?",
        "What's a hope you haven't said out loud yet?",
        "What's something that felt unfinished today?",
        "What's a way you took care of yourself today, even a small one?",
        "What's something you noticed about someone else today?",
        "What's a story you keep telling yourself that might not be true?",
        "What's something you want more of in your life right now?",
        "What's something you want less of?",
        "What's a moment today you wish had lasted longer?",
        "What's something you're learning to accept?",
        "What's a version of today you're glad didn't happen?",
        "What's something you did today that took more effort than it looked like?",
        "What's a question you'd ask your future self?",
        "What's something small that felt like a win?",
        "What's on your mind that you haven't told anyone yet?"
    ]
}
