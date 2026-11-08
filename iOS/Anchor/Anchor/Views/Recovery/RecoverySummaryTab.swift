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
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.primary : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }

            HStack(spacing: 0) {
                ShareLink(item: "I'm \(counter.currentRunPhraseIn()).") {
                    actionLabel(icon: "square.and.arrow.up", title: "Share")
                }
                .hiddenInShowcase()
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

    private struct Ring: Identifiable, Equatable {
        let id: Int       // Positional ID among visible rings (0 = innermost active ring)
        let rawUnitId: Int // Original unit identifier to track structural identity for animations
        let value: Int
        let unit: String
        let fraction: Double
        let tint: Color
    }

    // Define the base palette bounds
    private static let startColor = Anchor.Theme.sage
    private static let endColor = Anchor.Theme.accent

    private var rings: [Ring] {
        guard let startDate = start else { return [] }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        // 1. Calculate dynamic date breakdown precisely via Calendar API
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate, to: now)
        
        let y = components.year ?? 0
        let mo = components.month ?? 0
        let d = components.day ?? 0
        let h = components.hour ?? 0
        let m = components.minute ?? 0
        let s = components.second ?? 0

        // 2. Derive precision fractions for each unit
        // Year: fraction of current year completed
        let currentYear = calendar.component(.year, from: now)
        let totalDaysInYear = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let daysInCurrentYear = calendar.dateComponents([.day], from: calendar.date(from: DateComponents(year: currentYear))!, to: now).day ?? 0
        let yFraction = Double(daysInCurrentYear) / Double(totalDaysInYear)

        // Month: fraction of current month completed
        let totalDaysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let currentDayInMonth = calendar.component(.day, from: now)
        let hInDay = calendar.component(.hour, from: now)
        let moFraction = (Double(currentDayInMonth - 1) + Double(hInDay) / 24.0) / Double(totalDaysInMonth)

        // Days: Fills toward custom recovery milestones
        let reached = RecoveryMilestones.reached(d).last ?? 0
        let next = RecoveryMilestones.next(after: d)
        let dFraction = (next - reached) > 0 ? Double(d - reached) / Double(next - reached) : 0.0

        // Sub-day exact time fractions
        let hFraction = Double(h) / 24.0
        let mFraction = Double(m) / 60.0
        let sFraction = Double(s) / 60.0

        // 3. Construct raw structural items
        let rawRings: [(unitId: Int, value: Int, unit: String, fraction: Double)] = [
            (0, y, y == 1 ? "year" : "years", yFraction),
            (1, mo, mo == 1 ? "month" : "months", moFraction),
            (2, d, d == 1 ? "day" : "days", dFraction),
            (3, h, h == 1 ? "hour" : "hours", hFraction),
            (4, m, m == 1 ? "minute" : "minutes", mFraction),
            (5, s, s == 1 ? "second" : "seconds", sFraction)
        ]

        // 4. Rule: Filter out early rings where neither it nor its parents have a value > 0
        var visibleRawRings: [(unitId: Int, value: Int, unit: String, fraction: Double)] = []
        var parentHasValue = false
        
        for item in rawRings {
            if item.value > 0 || parentHasValue {
                visibleRawRings.append(item)
                parentHasValue = true
            }
        }
        
        // Safety Fallback: Always display at least seconds if nothing has triggered yet
        if visibleRawRings.isEmpty, let last = rawRings.last {
            visibleRawRings.append(last)
        }

        let totalVisible = visibleRawRings.count

        // 5. Build final Ring structures with dynamic IDs and gradient values
        return visibleRawRings.enumerated().map { index, element in
            // Interpolate colors smoothly across active ring counts only
            let pct = totalVisible > 1 ? Double(index) / Double(totalVisible - 1) : 0.0
            let dynamicColor = Self.interpolateColor(from: Self.startColor, to: Self.endColor, fraction: pct)

            return Ring(
                id: index, // Controls radius spacing dynamically
                rawUnitId: element.unitId, // Preserves unique identity for transitions
                value: element.value,
                unit: element.unit,
                fraction: element.fraction,
                tint: dynamicColor
            )
        }
    }

    private var nextMilestoneLabel: String {
        guard let startDate = start else { return "" }
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let d = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
        return RecoveryMilestones.label(RecoveryMilestones.next(after: d))
    }

    var body: some View {
        let activeRings = self.rings
        
        // Converted container to HStack to align dashboard and graphic side-by-side
        HStack(alignment: .center, spacing: 16) {
            
            // Dashboard Stylised Layout Top Left (Left End)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(activeRings) { ring in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(ring.value)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ring.tint)
                        
                        Text(ring.unit)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                    .fixedSize(horizontal: true, vertical: false) // 👈 Prevents the "s" from ever wrapping
                    .minimumScaleFactor(0.85) // 👈 Safety scaling fallback for small screens
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.7)),
                        removal: .opacity.animation(.easeIn(duration: 0.2))
                    ))
                }
            }
            .padding(.leading, 8)
            
            // Pushes the layout pieces to perfectly opposite ends of the card track
            Spacer(minLength: 12)
            
            // Rings Graphic Area (Right End)
            GeometryReader { proxy in
                let d = min(proxy.size.width, proxy.size.height)
                let lineWidth = d * 0.035
                let step = d * 0.07
                let firstRadius = d * 0.25
                let centreRadius = d * 0.18

                ZStack {
                    // Rings View Layer
                    ForEach(activeRings) { ring in
                        let radius = firstRadius + CGFloat(ring.id) * step
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.14), lineWidth: lineWidth)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(min(1, max(0, ring.fraction))))
                                .stroke(ring.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .opacity(ring.fraction < 0.002 ? 0 : 1)
                        }
                        .frame(width: radius * 2, height: radius * 2)
                        .animation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.55), value: ring.fraction)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.easeOut(duration: 0.4)),
                            removal: .scale(scale: 1.2).combined(with: .opacity).animation(.easeIn(duration: 0.3))
                        ))
                    }

                    // Solid dynamic center
                    Circle()
                        .fill(LinearGradient(colors: [Self.startColor, Self.endColor.opacity(0.85)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: centreRadius * 2, height: centreRadius * 2)
                        .overlay(
                            Text(name)
                                .font(.system(size: d * 0.06, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                                .padding(d * 0.03)
                        )
                }
                .frame(width: d, height: d)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(width: 140, height: 140) // Locked explicitly to prevent spatial layout overflow in side-by-side viewports
        }
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): " + activeRings.reversed().map { "\($0.value) \($0.unit)" }.joined(separator: ", "))
    }


    private static func interpolateColor(from start: Color, to end: Color, fraction: Double) -> Color {
        let f = CGFloat(min(1, max(0, fraction)))
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        UIColor(start).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(end).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return Color(
            red: r1 + (r2 - r1) * f,
            green: g1 + (g2 - g1) * f,
            blue: b1 + (b2 - b1) * f,
            opacity: a1 + (a2 - a1) * f
        )
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
        let today = calendar.startOfDay(for: .now)
        
        // 1. Get the current month parameters
        let currentMonthInterval = calendar.dateInterval(of: .month, for: .now) ?? DateInterval(start: .now, end: .now)
        let firstOfMonth = currentMonthInterval.start
        let lastOfMonth = currentMonthInterval.end
        let daysInCurrentMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        
        // 2. Map grid columns precisely to the 7 days of the week
        let columns = Array(repeating: GridItem(.fixed(16), spacing: 8), count: 7)
        
        // 3. Calculate calendar weekday padding offset at start of month based on user locale preferences
        // component(.weekday) returns 1 for Sunday, 2 for Monday, etc.
        let firstWeekdayComponent = calendar.component(.weekday, from: firstOfMonth)
        let firstWeekdayIndex = calendar.firstWeekday
        
        // How many empty grid cells belong to the prior month's tail end
        let prefixPaddingCount = (firstWeekdayComponent - firstWeekdayIndex + 7) % 7
        
        // How many empty grid cells are needed to finish the last week row
        let totalActiveCells = prefixPaddingCount + daysInCurrentMonth
        let suffixPaddingCount = (7 - (totalActiveCells % 7)) % 7
        
        return LazyVGrid(columns: columns, spacing: 8) {
            // A. Fill prior month padding days (dulled layout)
            if prefixPaddingCount > 0 {
                ForEach((0..<prefixPaddingCount).reversed(), id: \.self) { offset in
                    let padDay = calendar.date(byAdding: .day, value: -(offset + 1), to: firstOfMonth) ?? firstOfMonth
                    dot(status: timeline.status(padDay), isToday: false, isCurrentMonth: false, isFuture: false)
                }
            }
            
            // B. Fill current month's active layout track
            ForEach(0..<daysInCurrentMonth, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) ?? firstOfMonth
                let isToday = day == today
                let isFuture = day > today
                
                dot(status: timeline.status(day), isToday: isToday, isCurrentMonth: true, isFuture: isFuture)
            }
            
            if suffixPaddingCount > 0 {
                ForEach((0..<suffixPaddingCount).reversed(), id: \.self) { offset in
                    dot(status: .untracked, isToday: false, isCurrentMonth: false, isFuture: false)
                }
            }
        }
    }

    @ViewBuilder
    private func dot(status: RecoveryDayStatus, isToday: Bool, isCurrentMonth: Bool, isFuture: Bool) -> some View {
        // Base opacity reductions for tail-end matching or future visibility rules
        let baseOpacity: Double = isCurrentMonth ? 1.0 : 0.35
        
        if isFuture {
            // Darker grey circle for future days within the active month boundary
            Circle()
                .fill(Color.secondary.opacity(0.45))
                .frame(width: 14, height: 14)
        } else {
            switch status {
            case .sober:
                Circle()
                    .fill(Anchor.Theme.sage.opacity(baseOpacity))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(isToday ? Color.primary : Color.clear, lineWidth: 1.5)
                            .padding(-3)
                    )
            case .slip:
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Anchor.Theme.accent.opacity(baseOpacity))
                    .frame(width: 14, height: 14)
            case .untracked:
                Circle()
                    .fill(Color.secondary.opacity(isCurrentMonth ? 0.25 : 0.12))
                    .frame(width: 14, height: 14)
            }
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
                            : "Your best streak is still \(timeline.longestStreakPhrase).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                VStack(spacing: 6) {
                    HStack {
                        Text("Personal best").font(.subheadline)
                        Spacer()
                        Text(timeline.longestStreakPhrase).font(.subheadline.weight(.semibold))
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
        let reading = counter.currentRunReading()
        SummaryPage(title: "My streak is") {
            VStack(spacing: 2) {
                Text(reading.number)
                    .font(.system(size: 110, weight: .thin, design: .rounded))
                Text(reading.label)
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
