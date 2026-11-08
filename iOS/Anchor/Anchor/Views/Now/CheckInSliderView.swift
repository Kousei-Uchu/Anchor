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
    @AppStorage(SleepSettings.checkInKey) private var askAboutSleep = false
    @Query private var sleepEntries: [SleepEntry]

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

    /// One optional question: the question itself, a line of reassurance
    /// under it, and a few ways to begin the answer.
    private struct CheckInPrompt {
        let text: String
        let detail: String
        let starters: [String]
        /// A different mood per question, so the mascot isn't a fixed face.
        let mood: MascotMood
        /// The sleep question. Its answer becomes the note on last night in the
        /// sleep journal and is not copied into the journal entry.
        var isSleep = false
    }

    /// Fixed, reviewed set, deliberately short so answering all of them
    /// never feels tedious. Every one is skippable. Answers are keyed by
    /// `text`, so changing the wording of a question starts a fresh answer.
    private static let prompts: [CheckInPrompt] = [
        CheckInPrompt(
            text: "What's currently on your mind?",
            detail: "Anything at all is fine, big or small. It doesn't need to make sense yet.",
            starters: ["Right now I'm thinking about\u{2026}", "I keep coming back to\u{2026}", "What's taking up space is\u{2026}"],
            mood: .neutral
        ),
        CheckInPrompt(
            text: "What's your biggest emotion right now?",
            detail: "Naming a feeling, even roughly, can make it a little less heavy.",
            starters: ["Right now I feel\u{2026}", "Mostly I'm feeling\u{2026}", "It's hard to name, but it's something like\u{2026}"],
            mood: .gentle
        ),
        CheckInPrompt(
            text: "Is there anything coming up that's on your mind?",
            detail: "A date, a conversation, a task, or anything else that's waiting for you.",
            starters: ["Coming up, I'm thinking about\u{2026}", "I'm a bit unsure about\u{2026}", "Nothing big, but\u{2026}"],
            mood: .quietDay
        ),
        CheckInPrompt(
            text: "Would you say today's closer to a good day, a bad day, or somewhere in between?",
            detail: "There's no right answer. \"In between\" is a very normal one.",
            starters: ["Today feels like\u{2026}", "It's been a good day because\u{2026}", "It's been a harder day because\u{2026}", "Somewhere in between, since\u{2026}"],
            mood: .encouragingNotPerformative
        ),
        CheckInPrompt(
            text: "What's something you're looking forward to?",
            detail: "It can be tiny, like a meal or a quiet evening.",
            starters: ["I'm looking forward to\u{2026}", "One small thing I'm hoping for is\u{2026}"],
            mood: .gentle
        )
    ]

    /// Only offered when the person has switched it on in Settings, and never
    /// when last night already has something written down, so it is not asked twice.
    private static let sleepPrompt = CheckInPrompt(
        text: "How did you sleep?",
        detail: "However it went is fine. A few words are enough, or skip it.",
        starters: ["I got to sleep around\u{2026}", "I woke up\u{2026}", "I slept through, and\u{2026}", "It was hard to switch off, so\u{2026}"],
        mood: .gentle,
        isSleep: true
    )

    private var lastNightLogged: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return sleepEntries.contains { Calendar.current.startOfDay(for: $0.nightDate) == today && !$0.isBlank }
    }

    /// The fixed questions, plus the sleep one at the end when it applies.
    private var activePrompts: [CheckInPrompt] {
        askAboutSleep && !lastNightLogged ? Self.prompts + [Self.sleepPrompt] : Self.prompts
    }

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
            .onChange(of: sliderMood) { _, mood in
                if let line = MascotEngine(context: modelContext).line(for: .checkInPrompt, mood: mood) {
                    mascotLine = line
                }
            }
        }
    }

    @State private var mascotLine: MascotLine?

    private var sliderStage: some View {
        ScrollView {
            VStack(spacing: 14) {
                MascotPresenceView(line: mascotLine, mood: sliderMood)
                    .animation(.easeInOut(duration: 0.4), value: sliderMood)

                sliderCard("Physical energy", icon: "bolt.fill",
                           low: "running on empty", high: "fully charged", value: $physicalEnergyLevel)
                sliderCard("Mental clarity", icon: "lightbulb.fill",
                           low: "foggy", high: "clear", value: $mentalClarityLevel)
                sliderCard("Room in your head", icon: "cloud.fill",
                           low: "crowded", high: "plenty of space", value: $mentalSpaceLevel)
                sliderCard("Physical energy to move", icon: "figure.walk",
                           low: "hard to move", high: "ready to move", value: $physicalEnergy)
                sliderCard("Social energy", icon: "person.2.fill",
                           low: "need space", high: "up for company", value: $socialEnergy)

                Text("More = better, across all five. Just for you, nothing here is scored, averaged, or shown as a streak.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .anchorBackground()
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
        let current = activePrompts[promptIndex]
        return ScrollView {
            VStack(spacing: 16) {
                MascotPresenceView(line: nil, mood: current.mood)
                    .padding(.horizontal, 24)
                    .id(promptIndex)

                ProgressView(value: Double(promptIndex + 1), total: Double(activePrompts.count))
                    .tint(Anchor.Theme.accent)
                    .padding(.horizontal)

                Text("Question \(promptIndex + 1) of \(activePrompts.count), skip any of these")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(current.text)
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(current.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                TextField("Optional", text: Binding(
                    get: { promptAnswers[current.text] ?? "" },
                    set: { promptAnswers[current.text] = $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 24)
                .lineLimit(3...6)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Need a start?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(current.starters, id: \.self) { starter in
                                Button(starter) { insertStarter(starter, for: current) }
                                    .font(.footnote)
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.capsule)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    if promptIndex > 0 {
                        Button("Back") { withAnimation { promptIndex -= 1 } }
                            .buttonStyle(Anchor.SecondaryButtonStyle())
                    }
                    Button(promptIndex == activePrompts.count - 1 ? "Finish" : "Next") {
                        if promptIndex == activePrompts.count - 1 {
                            finishWithPrompts()
                        } else {
                            withAnimation { promptIndex += 1 }
                        }
                    }
                    .buttonStyle(Anchor.PrimaryButtonStyle())
                }

                Button("Finish now, skip the rest") {
                    finishWithPrompts()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
    }

    /// Adds a sentence starter to the end of the current answer.
    private func insertStarter(_ starter: String, for prompt: CheckInPrompt) {
        let existing = promptAnswers[prompt.text] ?? ""
        let needsSpace = !existing.isEmpty && !existing.hasSuffix(" ") && !existing.hasSuffix("\n")
        promptAnswers[prompt.text] = existing + (needsSpace ? " " : "") + starter + " "
    }

    /// The mascot's mood follows where the sliders sit. It is only a mood for
    /// the picture: nothing is stored, shown as a number, or compared with
    /// earlier check-ins, and the words it says still come from the reviewed
    /// line pool.
    /// Switched off for now: the mascot keeps one calm face while the sliders move.
    /// Set this to true to bring the following back.
    private static let mascotFollowsSliders = false

    private var sliderMood: MascotMood {
        guard Self.mascotFollowsSliders else { return .gentle }
        let level = (physicalEnergyLevel + mentalClarityLevel + mentalSpaceLevel + physicalEnergy + socialEnergy) / 5
        if level < 0.34 { return .quietDay }
        if level > 0.66 { return .encouragingNotPerformative }
        return .gentle
    }

    private func sliderCard(_ label: String, icon: String, low: String, high: String,
                            value: Binding<Double>) -> some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 8) {
                Anchor.SectionHeader(icon: icon, title: label)
                Slider(value: value, in: 0...1)
                    .tint(Anchor.Theme.accent)
                    .accessibilityLabel(label)
                HStack(alignment: .firstTextBaseline) {
                    Text(low)
                    Spacer(minLength: 12)
                    Text(high).multilineTextAlignment(.trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
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
        let answered = activePrompts.filter { !$0.isSleep }.compactMap { prompt -> String? in
            guard let answer = promptAnswers[prompt.text]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !answer.isEmpty else { return nil }
            return "\(prompt.text)\n\(answer)"
        }
        if let sleepPrompt = activePrompts.first(where: \.isSleep),
           let sleepAnswer = promptAnswers[sleepPrompt.text]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !sleepAnswer.isEmpty {
            modelContext.insert(SleepEntry(nightDate: Calendar.current.startOfDay(for: .now), note: sleepAnswer))
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
