//
//  RecoveryCalendarTab.swift
//  Anchor
//
//  A month calendar: sober days are joined pills, a day with a slip is a
//  circled cross, and a link leads to the full streak history.
//

import SwiftUI

struct RecoveryCalendarTab: View {
    let counter: RecoveryCounter

    @State private var month: Date = {
        let calendar = Calendar.current
        return calendar.dateInterval(of: .month, for: .now)?.start ?? .now
    }()

    private let calendar = Calendar.current

    var body: some View {
        let timeline = counter.timeline()
        VStack(spacing: 18) {
            Anchor.Card {
                VStack(spacing: 12) {
                    header
                    weekdayRow
                    VStack(spacing: 6) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            HStack(spacing: 0) {
                                ForEach(0..<7, id: \.self) { index in
                                    cell(week[index], in: week, index: index, timeline: timeline)
                                }
                            }
                        }
                    }
                }
            }

            summaryPill(timeline: timeline)
            legend

            NavigationLink { RecoveryStreaksView(counter: counter) } label: {
                Anchor.Card {
                    HStack {
                        Label("Streaks", systemImage: "chart.bar.doc.horizontal")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").padding(8) }
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.system(.headline, design: .rounded))
            Spacer()
            Button { shift(1) } label: { Image(systemName: "chevron.right").padding(8) }
                .disabled(isCurrentMonth)
        }
        .tint(.primary)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    private func shift(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: month) { month = next }
    }

    private var weekdayRow: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(symbols[(offset + index) % 7])
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Grid

    /// Weeks of the displayed month; `nil` pads the days that belong to neighbouring months.
    private var weeks: [[Date?]] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let first = interval.start
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<count { days.append(calendar.date(byAdding: .day, value: offset, to: first)) }
        while days.count % 7 != 0 { days.append(nil) }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0 + 7]) }
    }

    @ViewBuilder
    private func cell(_ day: Date?, in week: [Date?], index: Int, timeline: RecoveryTimeline) -> some View {
        if let day {
            let status = timeline.status(day)
            let previousSober = index > 0 && (week[index - 1].map { timeline.status($0) == .sober } ?? false)
            let nextSober = index < 6 && (week[index + 1].map { timeline.status($0) == .sober } ?? false)
            ZStack {
                if status == .sober {
                    UnevenRoundedRectangle(
                        topLeadingRadius: previousSober ? 0 : 19, bottomLeadingRadius: previousSober ? 0 : 19,
                        bottomTrailingRadius: nextSober ? 0 : 19, topTrailingRadius: nextSober ? 0 : 19)
                        .fill(Anchor.Theme.sage)
                } else if status == .slip {
                    Circle().stroke(Anchor.Theme.accent, lineWidth: 1.5).padding(2)
                }
                VStack(spacing: -1) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(.subheadline, design: .rounded))
                    if status == .slip {
                        Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                    }
                }
                .foregroundStyle(status == .sober ? Color.white : (status == .slip ? Anchor.Theme.accent : Color.primary))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        } else {
            Color.clear.frame(maxWidth: .infinity).frame(height: 38)
        }
    }

    // MARK: Footer

    private func summaryPill(timeline: RecoveryTimeline) -> some View {
        let count = timeline.soberDayCount(inMonthOf: month)
        let when = isCurrentMonth ? "this month" : "in \(month.formatted(.dateTime.month(.wide)))"
        return Text("\(count) sober \(count == 1 ? "day" : "days") \(when)")
            .font(.system(.footnote, design: .rounded).weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Anchor.Theme.sage.opacity(0.25)))
    }

    private var legend: some View {
        HStack(spacing: 18) {
            HStack(spacing: 6) {
                Circle().fill(Anchor.Theme.sage).frame(width: 8, height: 8)
                Text("Sober")
            }
            HStack(spacing: 6) {
                Circle().stroke(Anchor.Theme.accent, lineWidth: 1.5).frame(width: 8, height: 8)
                Text("Started again")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
