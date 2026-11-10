//
//  AIOffNotice.swift
//  Anchor
//
//  What stands in for an AI tool while AI tools are off (Patch AI7, D41).
//

import SwiftUI

/// A button for an AI tool that is switched off. It looks greyed out but can still be tapped, because a greyed
/// button that does nothing leaves a person wondering why. Tapping it only sets the flag the screen gave it;
/// the screen puts `.aiOffAlert` on a view and the alert says AI tools are off and where to turn them on.
///
/// It sends nothing, loads no model and opens no connection, so it does not need the consent sheet. Show it only
/// when `AIGate.showsOffButtons` is true, and only for a button that is the feature itself. A button that only
/// improves what the person wrote is left out while AI tools are off.
struct AIOffButton<Content: View>: View {
    let action: () -> Void
    let content: Content

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content.foregroundStyle(.secondary)
        }
        .accessibilityHint("AI tools are off")
    }
}

extension View {
    /// The alert a greyed-out AI button opens. The screen keeps one `@State` flag, sets it from the button and
    /// puts this on a view that is not inside a menu, so the alert is not lost when the menu closes.
    func aiOffAlert(isPresented: Binding<Bool>) -> some View {
        alert("AI tools are off", isPresented: isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can turn them on in Settings, under AI tools.")
        }
    }
}
