//
//  PeopleSettings.swift
//  Anchor
//
//  The switch for finding who is speaking in a recording (Patch VN4a4, E2, D38, D76). Off to begin with, and off in
//  showcase mode and in the demo store, so a made-up page never listens. While it is off no button for it shows
//  anywhere and nothing reads a recording for it.
//

import Foundation

enum PeopleSettings {
    static let key = "findWhoIsSpeaking"

    /// Whether the buttons on a voice note may show right now.
    static var isOn: Bool {
        if DemoMode.isOn { return false }
        return UserDefaults.standard.bool(forKey: key)
    }
}
