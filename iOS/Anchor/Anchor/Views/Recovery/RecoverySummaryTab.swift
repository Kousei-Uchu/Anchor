//
//  RecoverySummaryTab.swift
//  Anchor
//
//  The Summary tab of a counter: a row of swipeable pages (live time, this
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
            .frame(height: 340)

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

/// Live time on this run: days, hours, minutes and seconds as slanted bars.
private struct RecoveryTimePage: View {
    let counter: RecoveryCounter

    var body: some View {
        SummaryPage(title: "Time on this run") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 10) {
                    ForEach(rows(at: context.date), id: \.unit) { row in
                        SlantedMeter(value: row.value, unit: row.unit, fraction: row.fraction)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private struct Row { let unit: String; let value: Int; let fraction: Double }

    private func rows(at now: Date) -> [Row] {
        guard let start = counter.currentRun?.start else { return [] }
        let total = Int(max(0, now.timeIntervalSince(start)))
        let d = total / 86_400, h = total % 86_400 / 3_600, m = total % 3_600 / 60, s = total % 60
        let all: [Row] = [
            Row(unit: d == 1 ? "day" : "days", value: d, fraction: min(1, Double(d) / 30)),
            Row(unit: h == 1 ? "hour" : "hours", value: h, fraction: Double(h) / 24),
            Row(unit: m == 1 ? "minute" : "minutes", value: m, fraction: Double(m) / 60),
            Row(unit: s == 1 ? "second" : "seconds", value: s, fraction: Double(s) / 60)
        ]
        let startIndex = d > 0 ? 0 : (h > 0 ? 1 : 2)
        return Array(all[startIndex...].prefix(3))
    }
}

private struct SlantedBar: Shape {
    var slant: CGFloat = 16
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - slant, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SlantedMeter: View {
    let value: Int
    let unit: String
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                SlantedBar().fill(Color.secondary.opacity(0.14))
                SlantedBar()
                    .fill(LinearGradient(colors: [Anchor.Theme.sage, Anchor.Theme.accent.opacity(0.85)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(110, proxy.size.width * CGFloat(fraction)))
                HStack(spacing: 6) {
                    Text("\(value)").font(.system(.title3, design: .rounded).weight(.bold)).italic()
                    Text(unit).font(.system(.title3, design: .rounded)).italic()
                }
                .foregroundStyle(.white)
                .padding(.leading, 14)
            }
        }
        .frame(height: 44)
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
