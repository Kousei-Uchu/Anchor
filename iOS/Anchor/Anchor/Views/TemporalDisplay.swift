import SwiftUI

// MARK: - TemporalDisplay
//
// A reusable calendar-aware elapsed-time display.
//
// Usage examples:
//
// TemporalDisplay(start: startedAt)
//     .mode(.screen)
//     .onLongPress { ... }
//
// TemporalDisplay(start: startedAt)
//     .mode(.widget)
//
// TemporalDisplay(start: startedAt, end: deadline)
//     .mode(.inline)
//
// TemporalDisplay(start: startedAt)
//     .axis(.vertical)
//
// Calendar-aware behaviour:
// - Months and years are calculated using Calendar, not fixed 30/365-day lengths.
// - A month means "the same calendar day/time in the next month".
// - The display omits leading zero units.
// - Once a larger unit becomes active, lower units remain visible even when zero.
// - Swipe down/up hides/reveals the smallest visible unit.
// - In horizontal mode, swipe right/left performs the equivalent action.
// - Long-press calls the supplied closure.
//
// The view accepts a Date for the start and optionally an end date.
// If end is nil, the display measures from start until Date.now.
// If end is supplied, the display measures from start toward end.

public struct TemporalDisplay: View {

    public enum DisplayMode {
        case screen
        case widget
        case inline
    }

    public enum Axis {
        case vertical
        case horizontal
    }

    private let start: Date
    private let end: Date?
    private let calendar: Calendar
    private let onLongPress: () -> Void

    @State private var displayMode: DisplayMode = .screen
    @State private var axis: Axis = .vertical
    @State private var visibleUnitCount = 6

    public init(
        start: Date,
        end: Date? = nil,
        calendar: Calendar = .current,
        onLongPress: @escaping () -> Void = {}
    ) {
        self.start = start
        self.end = end
        self.calendar = calendar
        self.onLongPress = onLongPress
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            content(now: timeline.date)
        }
    }

    // MARK: - Public Configuration

    public func mode(_ mode: DisplayMode) -> Self {
        var copy = self
        copy._displayMode = State(initialValue: mode)
        return copy
    }

    public func axis(_ axis: Axis) -> Self {
        var copy = self
        copy._axis = State(initialValue: axis)
        return copy
    }

    // MARK: - Content

    @ViewBuilder
    private func content(now: Date) -> some View {
        GeometryReader { geometry in
            let breakdown = makeBreakdown(now: now)
            let units = visibleUnits(from: breakdown)

            Group {
                switch axis {
                case .vertical:
                    verticalLayout(
                        units: units,
                        breakdown: breakdown,
                        geometry: geometry
                    )

                case .horizontal:
                    horizontalLayout(
                        units: units,
                        breakdown: breakdown,
                        geometry: geometry
                    )
                }
            }
            .background(Color.black)
            .clipShape(Rectangle())
            .contentShape(Rectangle())
            .animation(
                .spring(
                    response: 0.55,
                    dampingFraction: 0.82
                ),
                value: visibleUnitCount
            )
            .gesture(swipeGesture)
            .onLongPressGesture(
                minimumDuration: 0.45,
                perform: onLongPress
            )
        }
        .background(Color.black)
    }

    // MARK: - Layout

    @ViewBuilder
    private func verticalLayout(
        units: [TimeUnit],
        breakdown: TimeBreakdown,
        geometry: GeometryProxy
    ) -> some View {
        let totalWeight = units.reduce(0) {
            $0 + $1.weight
        }

        VStack(spacing: spacing) {
            ForEach(units) { unit in
                TemporalBar(
                    unit: unit,
                    value: breakdown.value(for: unit),
                    progress: progress(
                        for: unit,
                        now: Date.now
                    ),
                    mode: displayMode,
                    axis: axis,
                    onLongPress: onLongPress
                )
                .frame(
                    height: max(
                        1,
                        geometry.size.height
                            * unit.weight
                            / max(totalWeight, 1)
                    )
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.96)),
                        removal: .move(edge: .bottom)
                            .combined(with: .opacity)
                    )
                )
            }
        }
        .padding(edgePadding)
    }

    @ViewBuilder
    private func horizontalLayout(
        units: [TimeUnit],
        breakdown: TimeBreakdown,
        geometry: GeometryProxy
    ) -> some View {
        let totalWeight = units.reduce(0) {
            $0 + $1.weight
        }

        HStack(spacing: spacing) {
            ForEach(units) { unit in
                TemporalBar(
                    unit: unit,
                    value: breakdown.value(for: unit),
                    progress: progress(
                        for: unit,
                        now: Date.now
                    ),
                    mode: displayMode,
                    axis: axis,
                    onLongPress: onLongPress
                )
                .frame(
                    width: max(
                        1,
                        geometry.size.width
                            * unit.weight
                            / max(totalWeight, 1)
                    )
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.96)),
                        removal: .move(edge: .leading)
                            .combined(with: .opacity)
                    )
                )
            }
        }
        .padding(edgePadding)
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { gesture in
                let translation = gesture.translation

                switch axis {
                case .vertical:
                    guard abs(translation.height) > abs(translation.width) else {
                        return
                    }

                    if translation.height > 45 {
                        hideSmallestUnit()
                    } else if translation.height < -45 {
                        revealSmallestUnit()
                    }

                case .horizontal:
                    guard abs(translation.width) > abs(translation.height) else {
                        return
                    }

                    // Right = hide smaller unit.
                    // Left = reveal smaller unit.
                    if translation.width > 45 {
                        hideSmallestUnit()
                    } else if translation.width < -45 {
                        revealSmallestUnit()
                    }
                }
            }
    }

    private func hideSmallestUnit() {
        guard visibleUnitCount > minimumVisibleUnitCount else {
            return
        }

        withAnimation {
            visibleUnitCount -= 1
        }
    }

    private func revealSmallestUnit() {
        guard visibleUnitCount < TimeUnit.allCases.count else {
            return
        }

        withAnimation {
            visibleUnitCount += 1
        }
    }

    // MARK: - Breakdown

    private func makeBreakdown(now: Date) -> TimeBreakdown {
        let target = end ?? now

        if target >= start {
            return calendarAwareBreakdown(
                from: start,
                to: target
            )
        } else {
            return calendarAwareBreakdown(
                from: target,
                to: start
            )
        }
    }

    /// Produces a calendar-aware elapsed duration.
    ///
    /// Example:
    /// Jan 15 12:00 → Feb 15 12:00 = 1 month,
    /// regardless of whether that month contains 28, 29, 30 or 31 days.
    private func calendarAwareBreakdown(
        from start: Date,
        to end: Date
    ) -> TimeBreakdown {
        guard start <= end else {
            return .zero
        }

        var cursor = start

        let years = wholeUnits(
            .year,
            from: cursor,
            to: end
        )
        cursor = calendar.date(
            byAdding: .year,
            value: years,
            to: cursor
        ) ?? cursor

        let months = wholeUnits(
            .month,
            from: cursor,
            to: end
        )
        cursor = calendar.date(
            byAdding: .month,
            value: months,
            to: cursor
        ) ?? cursor

        let days = wholeUnits(
            .day,
            from: cursor,
            to: end
        )
        cursor = calendar.date(
            byAdding: .day,
            value: days,
            to: cursor
        ) ?? cursor

        let hours = wholeUnits(
            .hour,
            from: cursor,
            to: end
        )
        cursor = calendar.date(
            byAdding: .hour,
            value: hours,
            to: cursor
        ) ?? cursor

        let minutes = wholeUnits(
            .minute,
            from: cursor,
            to: end
        )
        cursor = calendar.date(
            byAdding: .minute,
            value: minutes,
            to: cursor
        ) ?? cursor

        let seconds = wholeUnits(
            .second,
            from: cursor,
            to: end
        )

        return TimeBreakdown(
            years: years,
            months: months,
            days: days,
            hours: hours,
            minutes: minutes,
            seconds: seconds
        )
    }

    private func wholeUnits(
        _ component: Calendar.Component,
        from start: Date,
        to end: Date
    ) -> Int {
        max(
            0,
            calendar.dateComponents(
                [component],
                from: start,
                to: end
            ).value(for: component) ?? 0
        )
    }

    // MARK: - Active Units

    private func visibleUnits(
        from breakdown: TimeBreakdown
    ) -> [TimeUnit] {
        let naturallyActive = TimeUnit.allCases.filter {
            breakdown.shouldShow($0)
        }

        guard !naturallyActive.isEmpty else {
            return [.seconds]
        }

        let limited = naturallyActive.filter {
            $0.rawValue <= visibleUnitCount
        }

        // The smallest naturally-active unit is always retained.
        // This prevents a swipe from making the display completely empty.
        if limited.isEmpty {
            return [naturallyActive.last ?? .seconds]
        }

        return limited.sorted {
            $0.rawValue > $1.rawValue
        }
    }

    private var minimumVisibleUnitCount: Int {
        1
    }

    // MARK: - Progress

    private func progress(
        for unit: TimeUnit,
        now: Date
    ) -> Double {
        let target = end ?? now

        guard target >= start else {
            return 0
        }

        let breakdown = calendarAwareBreakdown(
            from: start,
            to: target
        )

        switch unit {
        case .years:
            return calendarUnitProgress(
                component: .year,
                start: start,
                elapsed: breakdown,
                now: target
            )

        case .months:
            let afterYears = calendar.date(
                byAdding: .year,
                value: breakdown.years,
                to: start
            ) ?? start

            return calendarUnitProgress(
                component: .month,
                start: afterYears,
                elapsed: breakdown,
                now: target
            )

        case .days:
            let afterYears = calendar.date(
                byAdding: .year,
                value: breakdown.years,
                to: start
            ) ?? start

            let afterMonths = calendar.date(
                byAdding: .month,
                value: breakdown.months,
                to: afterYears
            ) ?? afterYears

            return calendarUnitProgress(
                component: .day,
                start: afterMonths,
                elapsed: breakdown,
                now: target
            )

        case .hours:
            return fractionalProgress(
                smallerUnit: .minute,
                value: breakdown.minutes,
                denominator: 60
            )

        case .minutes:
            return fractionalProgress(
                smallerUnit: .second,
                value: breakdown.seconds,
                denominator: 60
            )

        case .seconds:
            return fractionalSecondProgress(
                start: start,
                target: target
            )
        }
    }

    private func calendarUnitProgress(
        component: Calendar.Component,
        start: Date,
        elapsed: TimeBreakdown,
        now: Date
    ) -> Double {
        let value: Int

        switch component {
        case .year:
            value = elapsed.years

        case .month:
            value = elapsed.months

        case .day:
            value = elapsed.days

        default:
            return 0
        }

        let current = calendar.date(
            byAdding: component,
            value: value,
            to: start
        ) ?? start

        let next = calendar.date(
            byAdding: component,
            value: 1,
            to: current
        ) ?? current

        let total = next.timeIntervalSince(current)

        guard total > 0 else {
            return 0
        }

        let elapsed = now.timeIntervalSince(current)

        return min(
            max(elapsed / total, 0),
            1
        )
    }

    private func fractionalProgress(
        smallerUnit: Calendar.Component,
        value: Int,
        denominator: Double
    ) -> Double {
        Double(value) / denominator
    }

    private func fractionalSecondProgress(
        start: Date,
        target: Date
    ) -> Double {
        let seconds = target.timeIntervalSince(start)
        let fractional = seconds - floor(seconds)

        return min(
            max(fractional, 0),
            1
        )
    }

    // MARK: - Appearance

    private var spacing: CGFloat {
        switch displayMode {
        case .screen:
            return 8

        case .widget:
            return 4

        case .inline:
            return 2
        }
    }

    private var edgePadding: CGFloat {
        switch displayMode {
        case .screen:
            return 8

        case .widget:
            return 5

        case .inline:
            return 0
        }
    }
}

// MARK: - Time Breakdown

private struct TimeBreakdown: Equatable {

    let years: Int
    let months: Int
    let days: Int
    let hours: Int
    let minutes: Int
    let seconds: Int

    static let zero = TimeBreakdown(
        years: 0,
        months: 0,
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0
    )

    func value(for unit: TimeUnit) -> Int {
        switch unit {
        case .years:
            years

        case .months:
            months

        case .days:
            days

        case .hours:
            hours

        case .minutes:
            minutes

        case .seconds:
            seconds
        }
    }

    func shouldShow(_ unit: TimeUnit) -> Bool {
        switch unit {
        case .years:
            return years > 0

        case .months:
            return years > 0 || months > 0

        case .days:
            return years > 0
                || months > 0
                || days > 0

        case .hours:
            return years > 0
                || months > 0
                || days > 0
                || hours > 0

        case .minutes:
            return years > 0
                || months > 0
                || days > 0
                || hours > 0
                || minutes > 0

        case .seconds:
            return true
        }
    }
}

// MARK: - Units

private enum TimeUnit: Int, CaseIterable, Identifiable {

    case years = 6
    case months = 5
    case days = 4
    case hours = 3
    case minutes = 2
    case seconds = 1

    var id: Self {
        self
    }

    var weight: Double {
        Double(rawValue)
    }

    var singularName: String {
        switch self {
        case .years:
            "year"

        case .months:
            "month"

        case .days:
            "day"

        case .hours:
            "hour"

        case .minutes:
            "minute"

        case .seconds:
            "second"
        }
    }

    var pluralName: String {
        switch self {
        case .years:
            "years"

        case .months:
            "months"

        case .days:
            "days"

        case .hours:
            "hours"

        case .minutes:
            "minutes"

        case .seconds:
            "seconds"
        }
    }
}

// MARK: - Bar

private struct TemporalBar: View {

    let unit: TimeUnit
    let value: Int
    let progress: Double
    let mode: TemporalDisplay.DisplayMode
    let axis: TemporalDisplay.Axis
    let onLongPress: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let progressSize = axis == .vertical
                ? geometry.size.width * progress
                : geometry.size.height * progress

            ZStack {
                RoundedRectangle(
                    cornerRadius: cornerRadius
                )
                .fill(.white)

                if axis == .vertical {
                    verticalFill(
                        width: progressSize
                    )
                } else {
                    horizontalFill(
                        height: progressSize
                    )
                }

                invertedLabel(
                    geometry: geometry
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius
                )
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: cornerRadius
                )
            )
        }
    }

    @ViewBuilder
    private func verticalFill(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.black
                .frame(width: width)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func horizontalFill(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Color.black
                .frame(height: height)
        }
    }

    private func invertedLabel(
        geometry: GeometryProxy
    ) -> some View {
        let text = Text(
            "\(value) \(value == 1 ? unit.singularName : unit.pluralName)"
        )
        .font(font)
        .minimumScaleFactor(0.35)
        .lineLimit(mode == .inline ? 1 : 2)

        return ZStack {
            text
                .foregroundStyle(.black)

            text
                .foregroundStyle(.white)
                .mask {
                    if axis == .vertical {
                        HStack(spacing: 0) {
                            Color.white
                                .frame(
                                    width: geometry.size.width * progress
                                )

                            Color.clear
                        }
                    } else {
                        VStack(spacing: 0) {
                            Color.clear

                            Color.white
                                .frame(
                                    height: geometry.size.height * progress
                                )
                        }
                    }
                }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .rotationEffect(
            axis == .horizontal
                ? .degrees(-90)
                : .degrees(0)
        )
    }

    private var cornerRadius: CGFloat {
        switch mode {
        case .screen:
            return 18

        case .widget:
            return 12

        case .inline:
            return 7
        }
    }

    private var font: Font {
        switch mode {
        case .screen:
            .system(
                size: 32,
                weight: .semibold,
                design: .rounded
            )

        case .widget:
            .system(
                size: 17,
                weight: .semibold,
                design: .rounded
            )

        case .inline:
            .system(
                size: 13,
                weight: .medium,
                design: .rounded
            )
        }
    }
}

// MARK: - Convenience Initialisers

public extension TemporalDisplay {

    /// A normal calendar-aware "time since" display.
    init(
        since start: Date,
        calendar: Calendar = .current,
        onLongPress: @escaping () -> Void = {}
    ) {
        self.init(
            start: start,
            end: nil,
            calendar: calendar,
            onLongPress: onLongPress
        )
    }

    /// A calendar-aware countdown / elapsed-time display between two dates.
    init(
        from start: Date,
        until end: Date,
        calendar: Calendar = .current,
        onLongPress: @escaping () -> Void = {}
    ) {
        self.init(
            start: start,
            end: end,
            calendar: calendar,
            onLongPress: onLongPress
        )
    }
}

// MARK: - Preview

#Preview("Screen — Vertical") {
    TemporalDisplay(
        since: Calendar.current.date(
            byAdding: .month,
            value: -2,
            to: .now
        )!,
        onLongPress: {
            print("Long pressed")
        }
    )
    .mode(.screen)
    .axis(.vertical)
    .frame(
        maxWidth: .infinity,
        maxHeight: .infinity
    )
    .preferredColorScheme(.dark)
}

#Preview("Widget — Horizontal") {
    TemporalDisplay(
        since: Calendar.current.date(
            byAdding: .day,
            value: -2,
            to: .now
        )!
    )
    .mode(.widget)
    .axis(.horizontal)
    .frame(
        width: 350,
        height: 100
    )
}

#Preview("Inline — Countdown") {
    TemporalDisplay(
        from: .now,
        until: Calendar.current.date(
            byAdding: .day,
            value: 14,
            to: .now
        )!
    )
    .mode(.inline)
    .axis(.vertical)
    .frame(
        width: 220,
        height: 80
    )
}
