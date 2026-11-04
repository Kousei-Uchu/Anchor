//
//  DecisionPresetsQuickView.swift
//  Anchor
//
//  Quick access to decision-fatigue presets from Now, rather than requiring
//  a trip to Plan first — this is exactly the kind of thing you want in
//  the moment you're too depleted to decide, not one tab over. Tapping a
//  choice with steps runs it step by step immediately; a flat choice with
//  no steps just opens the full editor to that category.
//

import SwiftUI
import SwiftData

struct DecisionPresetsQuickView: View {
    @Query(sort: \DecisionPresetCategory.sortOrder) private var categories: [DecisionPresetCategory]
    @State private var runnerChoice: DecisionPresetChoice?

    var body: some View {
        if !categories.isEmpty {
            Anchor.Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Anchor.SectionHeader(icon: "checklist", title: "Decision presets")
                        Spacer()
                        NavigationLink("See all") { DecisionFatigueView() }
                            .font(.caption)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories) { category in
                                if let firstChoice = category.choices.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
                                    Button {
                                        tap(firstChoice)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(category.name)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(firstChoice.name.isEmpty ? "Untitled" : firstChoice.name)
                                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                                .foregroundStyle(.primary)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Anchor.Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Text("One less thing to decide right now. Tap a category's top pick, or see all your options.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .fullScreenCover(item: $runnerChoice) { choice in
                StepByStepRunnerView(title: choice.name, stepsText: choice.steps, tint: Anchor.Theme.accent)
            }
        }
    }

    private func tap(_ choice: DecisionPresetChoice) {
        let hasSteps = !choice.steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasSteps {
            runnerChoice = choice
        }
        // A flat choice with no steps has nothing to run — it's just shown
        // as the top pick already, nothing further to do on tap.
    }
}
