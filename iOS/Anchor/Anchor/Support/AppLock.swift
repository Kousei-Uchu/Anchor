//
//  AppLock.swift
//  Anchor
//
//  Gates the whole app behind Face ID/passcode, independent of whether the
//  phone itself is currently unlocked — per spec: "app has its own Face
//  ID/passcode lock independent of phone lock state." Re-locks whenever
//  the app goes to the background, so leaving Anchor open on a desk still
//  protects the safety plan/journal from a passing glance.
//
//  Deliberately does NOT lock someone out of their own safety plan if the
//  device has no biometrics or passcode configured at all (a real
//  possibility, and the worst possible failure mode for a safety app would
//  be "can't reach my own crisis numbers because of a security feature") —
//  in that one case it unlocks automatically rather than showing a dead end.
//

import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()

    @Published private(set) var isUnlocked = false
    @Published private(set) var lastAuthError: String?

    /// Guards against a real bug: `.onAppear` and `.onChange(of: scenePhase)`
    /// going to `.active` can both fire `attemptUnlock()` within the same
    /// runloop at cold launch — two concurrent `LAContext` evaluations
    /// stepping on each other is exactly the kind of thing that shows up as
    /// "janky, doesn't quite work, hard to explain why." This flag makes a
    /// second call while one's already in flight a no-op instead of a race.
    private var isAuthenticating = false

    /// Kept so a mid-prompt backgrounding can cleanly cancel the evaluation
    /// (`LAContext.invalidate()`) rather than leaving it dangling.
    private var activeContext: LAContext?

    private static let enabledDefaultsKey = "anchor.appLockEnabled"

    /// Whether the app should even ask for Face ID/passcode. Defaults to
    /// on, but user-toggleable in Settings for cases like: shared device
    /// during onboarding, or Face ID being awkward for someone's setup.
    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledDefaultsKey) }
    }

    private init() {}

    /// Whether this device has Face ID, Touch ID, or even just a passcode
    /// set up at all. Used both to decide whether to show the "Require
    /// Face ID" toggle as meaningful, and to avoid locking someone out
    /// with no way back in.
    func canAuthenticate() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Called once at launch and whenever the app returns to foreground.
    func lock() {
        guard isEnabled else { return }
        // If a Face ID prompt was mid-flight when this fired (e.g. the app
        // was backgrounded while the system sheet was up), cancel it
        // cleanly instead of leaving a stale evaluation dangling.
        activeContext?.invalidate()
        activeContext = nil
        isAuthenticating = false
        isUnlocked = false
    }

    /// If the lock is turned off, or the device genuinely has no
    /// authentication configured, don't block access at all.
    func bypassIfNotApplicable() {
        if !isEnabled || !canAuthenticate() {
            isUnlocked = true
        }
    }

    func attemptUnlock() async {
        bypassIfNotApplicable()
        guard !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        activeContext = context
        defer { activeContext = nil }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Anchor to see your safety plan and journal."
            )
            isUnlocked = success
            lastAuthError = success ? nil : "Authentication didn't succeed."
        } catch {
            isUnlocked = false
            // Don't show a scary error for a cancellation Anchor itself
            // triggered (e.g. backgrounded mid-prompt via lock()) — only
            // surface errors the user would actually recognize as theirs.
            if let laError = error as? LAError, laError.code == .appCancel {
                lastAuthError = nil
            } else {
                lastAuthError = error.localizedDescription
            }
        }
    }
}

/// Wraps the whole app: shows a lock screen until Face ID/passcode
/// succeeds (or the lock is disabled/unavailable), and re-locks whenever
/// the app leaves the foreground.
struct AppLockGateView<Content: View>: View {
    @StateObject private var lock = AppLock.shared
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
                .opacity(lock.isUnlocked ? 1 : 0)
                .allowsHitTesting(lock.isUnlocked)

            if !lock.isUnlocked {
                AppLockScreenView(lock: lock)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lock.isUnlocked)
        .onAppear {
            lock.bypassIfNotApplicable()
            if !lock.isUnlocked {
                Task { await lock.attemptUnlock() }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lock.lock()
            case .active:
                if !lock.isUnlocked {
                    Task { await lock.attemptUnlock() }
                }
            default:
                break
            }
        }
    }
}

private struct AppLockScreenView: View {
    @ObservedObject var lock: AppLock

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            MascotCharacterView(mood: .neutral)
                .frame(width: 84, height: 84)

            Text("Anchor is locked")
                .font(.system(.title3, design: .rounded).weight(.semibold))

            Text("Face ID keeps this private, independent of your phone's own lock.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let error = lock.lastAuthError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 40)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await lock.attemptUnlock() }
            } label: {
                Label("Unlock", systemImage: "faceid")
            }
            .buttonStyle(Anchor.PrimaryButtonStyle())
            .padding(.horizontal, 60)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .anchorBackground()
    }
}
