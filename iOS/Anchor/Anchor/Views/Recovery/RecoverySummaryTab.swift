//
//  RecoverySummaryTab.swift
//  Anchor
//
//  The Summary tab of a counter: a row of swipeable pages (live time as nested rings, this
//  month, total days, streak record, current streak, start date) with Share,
//  Log urge and Start again underneath.
//

import SwiftUI

struct RecoverySummaryTab: View {
    let counter: RecoveryCounter
    let onShowCalendar: () -> Void
    let onLogUrge: () -> Void
    let onStartAgain: () -> Void

    @State private var page = 0
    private let pageCount = 6

    var body: some View {
        VStack(spacing: 18) {
            TabView(selection: $page) {
                RecoveryTimePage(counter: counter).tag(0)
                RecoveryMonthPage(counter: counter, onShowCalendar: onShowCalendar).tag(1)
                RecoveryTotalPage(counter: counter).tag(2)
                RecoveryRecordPage(counter: counter).tag(3)
                RecoveryStreakPage(counter: counter).tag(4)
                RecoveryStartPage(counter: counter).tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 410)

            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.primary : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }

            HStack(spacing: 0) {
                ShareLink(item: "I'm \(RecoveryText.days(counter.currentRunDays())) in.") {
                    actionLabel(icon: "square.and.arrow.up", title: "Share")
                }
                Button(action: onLogUrge) { actionLabel(icon: "waveform.path", title: "Log urge") }
                Button(action: onStartAgain) { actionLabel(icon: "arrow.counterclockwise", title: "Start again") }
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(icon: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20))
            Text(title).font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Page frame

private struct SummaryPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Anchor.Card {
                content().frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(value).font(.subheadline.weight(.semibold))
            }
            Divider()
        }
    }
}

// MARK: - Pages

/// Live time on this run as nested circles: a solid circle in the middle with the
/// counter's name, and one concentric ring per unit (days innermost, seconds
/// outermost). Every ring is driven by continuous elapsed time rather than the
/// whole-number value, so the arcs glide instead of snapping from one day to the next.
private struct RecoveryTimePage: View {
    let counter: RecoveryCounter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SummaryPage(title: "Time on this run") {
            if reduceMotion {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    NestedTimeRings(name: counter.name, start: counter.currentRun?.start, now: context.date)
                }
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    NestedTimeRings(name: counter.name, start: counter.currentRun?.start, now: context.date)
                }
            }
        }
    }
}

private struct NestedTimeRings: View {
    let name: String
    let start: Date?
    let now: Date

    private struct Ring: Identifiable {
        let id: Int
        let value: Int
        let unit: String
        let fraction: Double
        let tint: Color
    }

    // Sage (days) blending to terracotta (seconds), using the theme's own two colours.
    private static let tints: [Color] = [
        Anchor.Theme.sage,
        Color(red: 0.651, green: 0.598, blue: 0.491),
        Color(red: 0.721, green: 0.537, blue: 0.432),
        Anchor.Theme.accent
    ]

    private var elapsed: Double { max(0, now.timeIntervalSince(start ?? now)) }

    private var rings: [Ring] {
        let t = elapsed
        let whole = Int(t)
        let d = whole / 86_400, h = whole % 86_400 / 3_600, m = whole % 3_600 / 60, s = whole % 60

        // Days have no bigger cycle to fill, so that ring fills toward the next milestone.
        let daysElapsed = t / 86_400
        let previous = RecoveryMilestones.reached(Int(daysElapsed)).last ?? 0
        let next = RecoveryMilestones.next(after: Int(daysElapsed))
        let daysFraction = Double(next - previous) > 0 ? (daysElapsed - Double(previous)) / Double(next - previous) : 0

        return [
            Ring(id: 0, value: d, unit: d == 1 ? "day" : "days", fraction: daysFraction, tint: Self.tints[0]),
            Ring(id: 1, value: h, unit: h == 1 ? "hour" : "hours", fraction: t.truncatingRemainder(dividingBy: 86_400) / 86_400, tint: Self.tints[1]),
            Ring(id: 2, value: m, unit: m == 1 ? "minute" : "minutes", fraction: t.truncatingRemainder(dividingBy: 3_600) / 3_600, tint: Self.tints[2]),
            Ring(id: 3, value: s, unit: s == 1 ? "second" : "seconds", fraction: t.truncatingRemainder(dividingBy: 60) / 60, tint: Self.tints[3])
        ]
    }

    private var nextMilestoneLabel: String {
        RecoveryMilestones.label(RecoveryMilestones.next(after: Int(elapsed / 86_400)))
    }

    var body: some View {
        let rings = self.rings
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let d = min(proxy.size.width, proxy.size.height)
                let lineWidth = d * 0.035
                let firstRadius = d * 0.27
                let step = d * 0.07
                let centreRadius = d * 0.2

                ZStack {
                    // Rings
                    ForEach(rings) { ring in
                        let radius = firstRadius + CGFloat(ring.id) * step
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.14), lineWidth: lineWidth)
                            Circle()
                                .trim(from: 0, to: CGFloat(min(1, max(0, ring.fraction))))
                                .stroke(ring.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .opacity(ring.fraction < 0.002 ? 0 : 1)
                        }
                        .frame(width: radius * 2, height: radius * 2)
                    }

                    // Solid centre with the counter's name
                    Circle()
                        .fill(LinearGradient(colors: [Anchor.Theme.sage, Anchor.Theme.accent.opacity(0.85)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: centreRadius * 2, height: centreRadius * 2)
                        .overlay(
                            Text(name)
                                .font(.system(size: d * 0.065, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.5)
                                .padding(d * 0.04)
                        )

                    // Labels, sitting on each ring just left of the 12 o'clock start
                    ForEach(rings) { ring in
                        let radius = firstRadius + CGFloat(ring.id) * step
                        let labelWidth = d / 2 - 4
                        Text("\(ring.value) \(ring.unit)")
                            .font(.system(size: d * 0.036, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.thinMaterial))
                            .frame(width: labelWidth, alignment: .trailing)
                            .position(x: labelWidth / 2, y: d / 2 - radius)
                    }
                }
                .frame(width: d, height: d)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 300)

            Text("The days ring fills toward \(nextMilestoneLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): " + rings.reversed().map { "\($0.value) \($0.unit)" }.joined(separator: ", "))
    }
}

/// A dot for each day of this month: filled = sober, cross = a slip, grey = not reached yet.
private struct RecoveryMonthPage: View {
    let counter: RecoveryCounter
    let onShowCalendar: () -> Void

    var body: some View {
        let timeline = counter.timeline()
        let count = timeline.soberDayCount(inMonthOf: .now)
        SummaryPage(title: "Progress this month") {
            VStack(spacing: 6) {
                Text("\(count)")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                Text("\(count == 1 ? "Day" : "Days") \u{00B7} \(Date.now.formatted(.dateTime.month(.wide)))")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                dots(timeline: timeline)
                    .padding(.vertical, 10)
                Button("View full calendar", action: onShowCalendar)
                    .font(.footnote)
                    .tint(Anchor.Theme.accent)
            }
        }
    }

    private func dots(timeline: RecoveryTimeline) -> some View {
        let calendar = Calendar.current
        let first = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let days = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let today = calendar.startOfDay(for: .now)
        let columns = Array(repeating: GridItem(.fixed(16), spacing: 8), count: 8)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<days, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: first) ?? first
                dot(status: timeline.status(day), isToday: day == today)
            }
        }
    }

    @ViewBuilder
    private func dot(status: RecoveryDayStatus, isToday: Bool) -> some View {
        switch status {
        case .sober:
            Circle().fill(Anchor.Theme.sage).frame(width: 14, height: 14)
                .overlay(Circle().stroke(isToday ? Color.primary : Color.clear, lineWidth: 1.5).padding(-3))
        case .slip:
            Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Anchor.Theme.accent)
                .frame(width: 14, height: 14)
        case .untracked:
            Circle().fill(Color.secondary.opacity(0.25)).frame(width: 14, height: 14)
        }
    }
}

private struct RecoveryTotalPage: View {
    let counter: RecoveryCounter

    var body: some View {
        let timeline = counter.timeline()
        let total = counter.totalDays()
        SummaryPage(title: "Total days") {
            VStack(spacing: 4) {
                Text("\(total)")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                Text("Days overall")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 18)
                StatRow(label: "Whole weekends", value: "\(timeline.wholeWeekends())")
                StatRow(label: "Fresh starts", value: "\(timeline.freshStarts)")
                StatRow(label: "First started",
                        value: timeline.originalStart?.formatted(.dateTime.day().month().year()) ?? "-")
            }
        }
    }
}

private struct RecoveryRecordPage: View {
    let counter: RecoveryCounter

    var body: some View {
        let timeline = counter.timeline()
        let current = counter.currentRunDays()
        let best = max(timeline.longestStreakDays, 1)
        let isBest = current >= timeline.longestStreakDays && current > 0
        SummaryPage(title: "Streak record") {
            VStack(spacing: 10) {
                Text(isBest ? "Your longest yet" : "A new streak")
                    .font(.system(.title, design: .rounded).weight(.bold))
                Text(isBest ? "That's your longest streak so far."
                            : "Your best streak is still \(RecoveryText.days(timeline.longestStreakDays)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 6) {
                    HStack {
                        Text("Personal best").font(.subheadline)
                        Spacer()
                        Text(RecoveryText.days(timeline.longestStreakDays)).font(.subheadline.weight(.semibold))
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.18))
                            Capsule().fill(Anchor.Theme.sage)
                                .frame(width: proxy.size.width * CGFloat(min(1, Double(current) / Double(best))))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 6)
                NavigationLink { RecoveryStreaksView(counter: counter) } label: {
                    Text("View streak history").font(.footnote)
                }
                .tint(Anchor.Theme.accent)
                Divider()
                HStack {
                    Text("Current start date").font(.subheadline)
                    Spacer()
                    Text(counter.currentRun?.start.formatted(.dateTime.day().month().year()) ?? "-")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }
}

private struct RecoveryStreakPage: View {
    let counter: RecoveryCounter

    var body: some View {
        let days = counter.currentRunDays()
        SummaryPage(title: "My streak is") {
            VStack(spacing: 2) {
                Text("\(days)")
                    .font(.system(size: 110, weight: .thin, design: .rounded))
                Text(days == 1 ? "day" : "days")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
    }
}

private struct RecoveryStartPage: View {
    let counter: RecoveryCounter

    var body: some View {
        let start = counter.currentRun?.start ?? .now
        SummaryPage(title: "My start date") {
            VStack(spacing: 6) {
                Text(start.formatted(.dateTime.day().month(.wide).year()))
                    .font(.system(.title, design: .rounded).weight(.regular))
                    .multilineTextAlignment(.center)
                Text(start.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 40)
        }
    }
}
