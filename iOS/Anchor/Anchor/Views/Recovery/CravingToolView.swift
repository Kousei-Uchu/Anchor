//
//  CravingToolView.swift
//  Anchor
//
//  "Riding out an urge": a quiet timer with a slow breathing circle, the
//  user's own reasons, and the grounding tools they already wrote. Nothing is
//  recorded unless the user chooses to write a line about it afterwards.
//

import SwiftUI
import SwiftData

struct CravingToolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecoveryMotivation.sortOrder) private var motivations: [RecoveryMotivation]
    @Query(sort: \GroundingTool.sortOrder) private var tools: [GroundingTool]

    private enum Phase { case setup, running, done }

    @State private var phase: Phase = .setup
    @State private var minutes = 15
    @State private var endDate = Date.now
    @State private var now = Date.now
    @State private var breathing = false
    @State private var note = ""
    @State private var noteSaved = false
    @State private var checkInNudgeDismissed = false
    @State private var showingCheckIn = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let calmLines = [
        "Urges rise, peak and pass. You only have to ride this one.",
        "You don't have to fight it. Just wait with it.",
        "Breathe out slowly. Make the out-breath longer than the in-breath.",
        "This feeling is not an instruction."
    ]

    private var totalSeconds: Double { Double(minutes * 60) }
    private var remaining: Double { max(0, endDate.timeIntervalSince(now)) }
    private var physicalTools: [GroundingTool] { tools.filter { $0.kind == .physicalAction && !($0.steps ?? "").isEmpty } }

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                switch phase {
                case .setup: setupView
                case .running: runningView
                case .done: doneView
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Riding out an urge")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(ticker) { date in
            now = date
            if phase == .running, date >= endDate { phase = .done }
        }
        .onChange(of: phase) { _, newPhase in
            // Keep the screen awake while the timer runs, and let it sleep again afterwards.
            UIApplication.shared.isIdleTimerDisabled = (newPhase == .running)
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .recoveryCheckInSheet(isPresented: $showingCheckIn)
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(spacing: Anchor.Theme.spacing) {
            Anchor.Card(accentColor: Anchor.Theme.sage) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Most urges peak and fade in a few minutes. Pick a length of time to wait it out, and let the timer do the counting.")
                        .font(.subheadline)
                    Picker("Minutes", selection: $minutes) {
                        ForEach([5, 10, 15, 20], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Button("Start") {
                        now = .now
                        endDate = Date.now.addingTimeInterval(totalSeconds)
                        phase = .running
                        breathing = true
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
                }
            }
            motivationCard
            toolsCard
        }
    }

    // MARK: Running

    private var runningView: some View {
        VStack(spacing: Anchor.Theme.spacing) {
            Anchor.Card(accentColor: Anchor.Theme.sage) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(Anchor.Theme.sageSoft, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: totalSeconds > 0 ? 1 - remaining / totalSeconds : 0)
                            .stroke(Anchor.Theme.sage, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Circle()
                            .fill(Anchor.Theme.sageSoft)
                            .padding(34)
                            .scaleEffect(breathing ? 1.0 : 0.72)
                            .animation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: breathing)
                        Text(timeString(remaining))
                            .font(.system(size: 40, weight: .light, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(width: 240, height: 240)

                    Text(calmLines[Int(now.timeIntervalSince1970 / 20) % calmLines.count])
                        .font(.system(.body, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 52)
                }
                .frame(maxWidth: .infinity)
            }
            motivationCard
            toolsCard
            Button("I'm done waiting") { phase = .done }
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Done

    private var doneView: some View {
        VStack(spacing: Anchor.Theme.spacing) {
            Anchor.Card(accentColor: Anchor.Theme.sage) {
                VStack(alignment: .leading, spacing: 10) {
                    Anchor.SectionHeader(icon: "checkmark.circle.fill", title: "You waited it out", tint: Anchor.Theme.sage)
                    Text("Whatever happens next, you gave yourself that time. That counts.")
                        .font(.subheadline)
                }
            }
            if !checkInNudgeDismissed {
                RecoveryCheckInNudge(
                    message: "Want to check in now that it's passed? Totally fine to skip.",
                    onCheckIn: { checkInNudgeDismissed = true; showingCheckIn = true },
                    onDismiss: { checkInNudgeDismissed = true }
                )
            }
            Anchor.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Want to write a line about it?")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    TextField("Only if you feel like it", text: $note, axis: .vertical)
                    if noteSaved {
                        Label("Saved to your journal", systemImage: "checkmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Save to journal") {
                            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            modelContext.insert(JournalEntry(text: trimmed, linkedContext: .groundingTool))
                            noteSaved = true
                        }
                        .buttonStyle(Anchor.SecondaryButtonStyle())
                    }
                }
            }
            Text("If this feels bigger than an urge, your crisis numbers are in Plan, and the people in your contacts are there for you.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Shared cards

    @ViewBuilder
    private var motivationCard: some View {
        if !motivations.isEmpty {
            let index = Int(now.timeIntervalSince1970 / 15) % motivations.count
            let item = motivations[index]
            Anchor.Card {
                VStack(alignment: .leading, spacing: 8) {
                    Anchor.SectionHeader(icon: "heart.fill", title: "Why you're here")
                    Text(item.kind == .person ? "For \(item.text)" : item.text)
                        .font(.system(.title3, design: .rounded))
                }
            }
        }
    }

    @ViewBuilder
    private var toolsCard: some View {
        if !physicalTools.isEmpty {
            Anchor.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Anchor.SectionHeader(icon: "leaf.fill", title: "Your grounding tools", tint: Anchor.Theme.sage)
                    ForEach(physicalTools) { tool in
                        DisclosureGroup(tool.title) {
                            Text(tool.steps ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
