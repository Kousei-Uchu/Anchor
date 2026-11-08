//
//  OnboardingTourView.swift
//  Anchor
//
//  Shown automatically once, on first launch (tracked via UserDefaults,
//  not SwiftData — this is a device preference, not user data). It reads
//  the guide registry (Guide.tourEntries in HelpContent.swift), the same
//  entries the "?" buttons open, so there's one source of truth for these
//  explanations, not two to keep in sync. Retakeable anytime from Settings,
//  Your data and help, Take the tour.
//

import SwiftUI

struct OnboardingTourView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0

    private let entries = Guide.tourEntries

    private var isLast: Bool { pageIndex >= entries.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        ScrollView {
                            VStack(spacing: 18) {
                                MascotCharacterView(mood: .gentle)
                                    .frame(width: 84, height: 84)
                                GuideEntryBody(entry: entry)
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 24)
                            .padding(.bottom, 16)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Text("\(pageIndex + 1) of \(entries.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                HStack(spacing: 12) {
                    if pageIndex > 0 {
                        Button("Back") {
                            withAnimation { pageIndex -= 1 }
                        }
                        .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.accent))
                    }
                    Button(isLast ? "Start using Anchor" : "Next") {
                        if isLast {
                            dismiss()
                        } else {
                            withAnimation { pageIndex += 1 }
                        }
                    }
                    .buttonStyle(Anchor.PrimaryButtonStyle())
                }
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
