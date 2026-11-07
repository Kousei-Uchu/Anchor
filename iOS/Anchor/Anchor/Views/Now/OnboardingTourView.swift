//
//  OnboardingTourView.swift
//  Anchor
//
//  Shown automatically once, on first launch (tracked via UserDefaults,
//  not SwiftData — this is a device preference, not user data). Reuses
//  the exact same HelpTopic content as the per-tab "?" buttons, so there's
//  one source of truth for these explanations, not two to keep in sync.
//  Replayable anytime from Plan → Settings (gear).
//

import SwiftUI

struct OnboardingTourView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0

    private let topics = HelpTopic.allCases

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(topics.enumerated()), id: \.offset) { index, topic in
                        tourPage(topic).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(pageIndex == topics.count - 1 ? "Start using Anchor" : "Next") {
                    if pageIndex == topics.count - 1 {
                        dismiss()
                    } else {
                        withAnimation { pageIndex += 1 }
                    }
                }
                .buttonStyle(Anchor.PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
            .anchorBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
        }
    }

    private func tourPage(_ topic: HelpTopic) -> some View {
        VStack(spacing: 20) {
            Spacer()
            MascotCharacterView(mood: .gentle)
                .frame(width: 84, height: 84)
            ZStack {
                Circle().fill(Anchor.Theme.accentSoft).frame(width: 56, height: 56)
                Image(systemName: topic.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Anchor.Theme.accent)
            }
            Text(topic.tabName)
                .font(.system(.title2, design: .rounded).weight(.semibold))
            Text(topic.explanation)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

/// Drives whether the tour auto-shows on launch. A plain UserDefaults
/// flag, not SwiftData — this is "has this device seen the tour," not
/// something that belongs in an exportable data set.
enum OnboardingState {
    private static let key = "anchor.hasSeenTour"

    static var hasSeenTour: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
