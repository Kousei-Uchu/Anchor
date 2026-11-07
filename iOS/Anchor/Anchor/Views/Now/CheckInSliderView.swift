//
//  CheckInSliderView.swift
//  Anchor
//
//  Two fixes from feedback:
//  1. Sentiment consistency — sliders used to mix directions (three framed
//     "more = worse," two framed "more = better"), which is confusing to
//     read at a glance. All five are now framed so dragging right is
//     always the better direction. The underlying CheckIn model still
//     stores physicalExhaustion/cognitiveBurnout/mentalLoad in their
//     original direction (nothing else that reads CheckIn needed to
//     change) — this view just inverts what the slider shows and converts
//     on save.
//  2. The step after sliders is now a real optional flow: a handful of
//     single-question screens (same one-thing-at-a-time pattern as
//     Grounding Tools), every one individually skippable, with "Finish"
//     available at every step. Finishing right after the sliders is the
//     complete, default path — not a partial one. Anything answered in the
//     extra steps becomes a real Journal entry, linked back to this
//     check-in, instead of a separate "expand" button feeling bolted on.
//

import SwiftUI
import SwiftData

struct CheckInSliderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onExpandToJournal: (CheckIn) -> Void

    // Stored here already flipped to "more = better." Converted to the
    // model's original direction only at save time.
    @State private var physicalEnergyLevel: Double = 0.5
    @State private var mentalClarityLevel: Double = 0.5
    @State private var mentalSpaceLevel: Double = 0.5
    @State private var physicalEnergy: Double = 0.5
    @State private var socialEnergy: Double = 0.5

    @State private var stage: Stage = .sliders
    @State private var promptIndex = 0
    @State private var promptAnswers: [String: String] = [:]

    private enum Stage { case sliders, prompts }

    /// Fixed, reviewed set — deliberately short so answering all of them
    /// never feels tedious. Every one is skippable.
    private static let prompts = [
        "What's currently on your mind?",
        "What's your biggest emotion right now?",
        "Is there anything coming up that's on your mind?",
        "Would you say today's closer to a good day, a bad day, or somewhere in between?",
        "What's something you're looking forward to?"
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .sliders: sliderStage
                case .prompts: promptStage
                }
            }
            .navigationTitle("Check in")
            .tint(Anchor.Theme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
            .onAppear {
                mascotLine = MascotEngine(context: modelContext).line(for: .checkInPrompt, mood: .gentle)
            }
        }
    }

    @State private var mascotLine: MascotLine?

    private var sliderStage: some View {
        Form {
            Section {
                MascotPresenceView(line: mascotLine, mood: .gentle)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                sliderRow("Physical energy", value: $physicalEnergyLevel)
                sliderRow("Mental clarity", value: $mentalClarityLevel)
                sliderRow("Room in your head", value: $mentalSpaceLevel)
                sliderRow("Physical energy to move", value: $physicalEnergy)
                sliderRow("Social energy", value: $socialEnergy)
            } footer: {
                Text("More = better, across all five. Just for you, nothing here is scored, averaged, or shown as a streak.")
            }

        }
        // Both actions live in a bar pinned to the bottom, so neither can be
        // pushed below the fold on a small screen and "A few optional
        // questions" can't be missed.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Button("A few optional questions") {
                    stage = .prompts
                }
                .buttonStyle(Anchor.SecondaryButtonStyle())

                Button("Finish") {
                    _ = save()
                    dismiss()
                }
                .buttonStyle(Anchor.PrimaryButtonStyle())

                Text("Finishing here is complete. The questions are extra, not required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    private var promptStage: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(promptIndex + 1), total: Double(Self.prompts.count))
                .tint(Anchor.Theme.accent)
                .padding(.horizontal)

            Text("Question \(promptIndex + 1) of \(Self.prompts.count), skip any of these")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(Self.prompts[promptIndex])
                .font(.system(.title3, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            TextField("Optional", text: Binding(
                get: { promptAnswers[Self.prompts[promptIndex]] ?? "" },
                set: { promptAnswers[Self.prompts[promptIndex]] = $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 24)
            .lineLimit(3...6)

            Spacer()

            HStack(spacing: 12) {
                if promptIndex > 0 {
                    Button("Back") { withAnimation { promptIndex -= 1 } }
                        .buttonStyle(Anchor.SecondaryButtonStyle())
                }
                Button(promptIndex == Self.prompts.count - 1 ? "Finish" : "Next") {
                    if promptIndex == Self.prompts.count - 1 {
                        finishWithPrompts()
                    } else {
                        withAnimation { promptIndex += 1 }
                    }
                }
                .buttonStyle(Anchor.PrimaryButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Button("Finish now, skip the rest") {
                finishWithPrompts()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
    }

    private func sliderRow(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(.subheadline, design: .rounded))
            Slider(value: value, in: 0...1)
                .tint(Anchor.Theme.accent)
        }
        .padding(.vertical, 4)
    }

    @discardableResult
    private func save() -> CheckIn {
        let checkIn = CheckIn(
            physicalExhaustion: 1 - physicalEnergyLevel,
            cognitiveBurnout: 1 - mentalClarityLevel,
            mentalLoad: 1 - mentalSpaceLevel,
            physicalEnergy: physicalEnergy,
            socialEnergy: socialEnergy
        )
        modelContext.insert(checkIn)
        return checkIn
    }

    /// Any answered prompt (blank ones are skipped) becomes one real
    /// Journal entry linked back to this check-in — not a separate,
    /// easy-to-miss "expand" action. If nothing was answered, no entry is
    /// created and the caller isn't asked to open anything.
    private func finishWithPrompts() {
        let checkIn = save()
        let answered = Self.prompts.compactMap { prompt -> String? in
            guard let answer = promptAnswers[prompt]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !answer.isEmpty else { return nil }
            return "\(prompt)\n\(answer)"
        }
        if !answered.isEmpty {
            let entry = JournalEntry(text: answered.joined(separator: "\n\n"), linkedContext: .checkInSlider)
            modelContext.insert(entry)
            checkIn.expandedEntryID = entry.id
            onExpandToJournal(checkIn)
        }
        dismiss()
    }
}
