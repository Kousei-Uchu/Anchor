import Foundation

extension Notification.Name {
    /// Posted when AI tools are turned off, so anything half done (a request waiting for an answer, a
    /// rewrite not yet kept) can be dropped. Features that talk to a provider listen for it.
    static let aiToolsTurnedOff = Notification.Name("page.aspens.anchor.aiToolsTurnedOff")
}

/// The one switch for every AI feature (Patch AI0, docs/OPTIONAL_FEATURES.md, E5).
///
/// It is off to begin with and stays off until the person turns it on in Settings. Every place that
/// shows an AI button, loads a model or opens a connection to a provider must ask `AIGate.isEnabled`
/// first and do nothing when it is false. `scripts/check-ai-gate.mjs` fails if a file that talks to a
/// provider never mentions the gate, so a later patch cannot skip it.
///
/// Showcase mode and the demo store keep it off, so made-up content is never sent anywhere.
enum AIGate {
    static let storageKey = "aiToolsEnabled"

    /// What the person chose. Off unless they turned it on.
    static var isChosen: Bool { UserDefaults.standard.bool(forKey: storageKey) }

    /// Whether AI may be used right now. Use this, never `isChosen`, to decide what to show or do.
    static var isEnabled: Bool {
        if DemoMode.isOn { return false }
        return isChosen
    }

    /// Turning it off also tells listeners to drop anything half done.
    static func setChosen(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: storageKey)
        if !on {
            NotificationCenter.default.post(name: .aiToolsTurnedOff, object: nil)
        }
    }
}
