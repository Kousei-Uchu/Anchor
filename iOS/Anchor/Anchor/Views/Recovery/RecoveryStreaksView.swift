//
//  RecoveryStreaksView.swift
//  Anchor
//
//  Streak history (each run, with a bar showing its length against the best)
//  and the Times list (how many times a slip happened on each day).
//

import SwiftUI
import SwiftData

struct RecoveryStreaksView: View {
    let counter: RecoveryCounter
    @Query private var allEntries: [RecoveryDayEntry]
    @State private var segment = 0
    @State private var showingPriorEditor = false

    private var slipDays: [RecoveryDayEntry] {
        allEntries
            .filter { $0.counterID == counter.id && $0.slipTimes > 0 }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    pill("Streaks", index: 0)
                    pill("Times", index: 1)
                    Spacer()
                }
                if segment == 0 { streaksList } else { timesList }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle(counter.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPriorEditor) {
            Anchor.ItemEditorSheet(title: "Before tracking") {
                Form {
                    Section {
                        Stepper("\(counter.priorTimesPerDay) \(counter.priorTimesPerDay == 1 ? "time" : "times")",
                                value: Binding(get: { counter.priorTimesPerDay }, set: { counter.priorTimesPerDay = $0 }),
                                in: 0...50)
                    } footer: {
                        Text("On a typical day before you started tracking, how many times did it happen? Just for your own reference.")
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func pill(_ title: String, index: Int) -> some View {
        Button { segment = index } label: {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(segment == index ? Anchor.Theme.sage.opacity(0.35) : Color.secondary.opacity(0.12)))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: Streaks

    private var streaksList: some View {
        let timeline = counter.timeline()
        let streaks = timeline.streaks
        let longest = streaks.map { $0.length(now: timeline.now) }.max() ?? 1
        let bestID = streaks.max(by: { $0.length(now: timeline.now) < $1.length(now: timeline.now) })?.id
        return VStack(alignment: .leading, spacing: 14) {
            Text("Streaks").font(.system(.title2, design: .rounded).weight(.bold))
            if let current = streaks.last(where: { $0.isCurrent }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today \u{00B7} \(Date.now.formatted(date: .numeric, time: .omitted))")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(current.lengthText(now: timeline.now)).font(.footnote).foregroundStyle(.secondary)
                }
                Divider()
            }
            ForEach(streaks.reversed()) { streak in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(streak.start.formatted(date: .numeric, time: .omitted)).font(.body)
                        Text("\u{00B7} \(streak.start.formatted(date: .omitted, time: .shortened))")
                            .font(.footnote).foregroundStyle(.secondary)
                        if streak.isCurrent {
                            Text("Current start date")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(Anchor.Theme.sage.opacity(0.3)))
                        }
                        Spacer()
                    }
                    HStack(spacing: 4) {
                        Text(streak.lengthText(now: timeline.now)).font(.footnote).foregroundStyle(.secondary)
                        if streak.id == bestID, streaks.count > 1 || streak.length(now: timeline.now) > 0 {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(Anchor.Theme.accent)
                        }
                    }
                    GeometryReader { proxy in
                        Capsule().fill(Anchor.Theme.sage)
                            .frame(width: max(6, proxy.size.width * CGFloat(streak.length(now: timeline.now) / max(longest, 1))))
                    }
                    .frame(height: 4)
                }
                Divider()
            }
        }
    }

    // MARK: Times

    private var timesList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Times").font(.system(.title2, design: .rounded).weight(.bold))
            if slipDays.isEmpty {
                Text("When you start again, you can note how many times it happened that day. They'll show up here. Nothing here is a score.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(slipDays) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.day.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.body)
                    HStack(spacing: 4) {
                        HStack(spacing: 3) {
                            ForEach(0..<min(entry.slipTimes, 6), id: \.self) { _ in
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Anchor.Theme.accent.opacity(0.8))
                            }
                        }
                        Text(entry.slipTimes > 6 ? "+\(entry.slipTimes - 6)" : "").font(.caption)
                        Text("\(entry.slipTimes) \(entry.slipTimes == 1 ? "time" : "times")")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                Divider()
            }

            Anchor.TapToEditRow(action: { showingPriorEditor = true }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before tracking").font(.system(.headline, design: .rounded))
                    Text("On a typical day before you started tracking, how many times did it happen? Just for your own reference.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("\(counter.priorTimesPerDay) \(counter.priorTimesPerDay == 1 ? "time" : "times") on a typical day")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 8)
        }
    }
}
