//
//  JournalView.swift
//  Anchor
//
//  Check-ins are merged directly into the timeline instead of being
//  drawn as a separate, absolutely-positioned overlay. Folding check-ins
//  into the same per-day, timestamp-sorted list as journal entries keeps
//  everything on one spine, and tapping a check-in now opens a detail
//  sheet with the full five-metric breakdown — previously check-ins had
//  no tap target at all.
//
//  Same underlying JournalEntry/CheckIn stores that Now, Bridge, and
//  Thread all read from — nothing new to persist.
//

import SwiftUI
import SwiftData
import Charts

/// How the Journal tab is laid out. Days is the timeline; Month is a
/// calendar you can tap a day in.
enum JournalLayout: String, CaseIterable, Identifiable {
    case days = "Days"
    case month = "Month"
    case year = "Year"
    var id: String { rawValue }
}

/// What happened on one day, as plain counts. Nothing here is a score.
struct JournalDayCount {
    var entries = 0
    var checkIns = 0
}

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt) private var entries: [JournalEntry]
    @Query(sort: \CheckIn.timestamp) private var checkIns: [CheckIn]
    @Query(sort: \RecoveryCounter.sortOrder) private var recoveryCounters: [RecoveryCounter]
    @State private var searchText = ""
    @State private var entryToEdit: JournalEntry?
    @State private var entryToRead: JournalEntry?
    @State private var checkInToView: CheckIn?
    @AppStorage("anchor.journal.layout") private var layout: JournalLayout = .days
    @State private var displayedMonth = Date()
    @State private var pendingScrollDay: Date?

    // MARK: - Unified timeline item

    /// A single thing that can appear on the timeline. Journal entries and
    /// check-ins are different model types, but on screen they're both
    /// just "something that happened at a point in time" — merging them
    /// into one enum and sorting together (instead of drawing them on two
    /// separate tracks) is what actually makes the timeline read as one
    /// timeline.
    private enum TimelineItem: Identifiable {
        case entry(JournalEntry)
        case checkIn(CheckIn)

        var id: String {
            switch self {
            case .entry(let e): return "entry-\(e.id)"
            case .checkIn(let c): return "checkin-\(c.id)"
            }
        }

        var timestamp: Date {
            switch self {
            case .entry(let e): return e.createdAt
            case .checkIn(let c): return c.timestamp
            }
        }
    }

    private var filteredEntries: [JournalEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    /// Check-ins don't have searchable text, so while the user is
    /// searching we only surface journal entries that match — but each
    /// still appears filed under its real day, alongside whatever
    /// check-ins happened that day.
    private var timelineItems: [TimelineItem] {
        let entryItems = filteredEntries.map(TimelineItem.entry)
        let checkInItems = searchText.isEmpty ? checkIns.map(TimelineItem.checkIn) : []
        return (entryItems + checkInItems).sorted { $0.timestamp > $1.timestamp }
    }

    /// Newest day first, and newest item first within each day, so the
    /// most recent thing is always at the top.
    private var groupedByDay: [(day: Date, items: [TimelineItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: timelineItems) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]!.sorted { $0.timestamp > $1.timestamp })
        }
    }

    private let topAnchorID = "journal-top"

    private var dayCounts: [Date: JournalDayCount] {
        let calendar = Calendar.current
        var result: [Date: JournalDayCount] = [:]
        for item in timelineItems {
            let day = calendar.startOfDay(for: item.timestamp)
            var count = result[day] ?? JournalDayCount()
            switch item {
            case .entry: count.entries += 1
            case .checkIn: count.checkIns += 1
            }
            result[day] = count
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            VStack(spacing: 0) {
            Picker("Layout", selection: $layout) {
                ForEach(JournalLayout.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id(topAnchorID)
                    if layout == .year {
                        JournalYearView(
                            counts: dayCounts,
                            earliest: timelineItems.last?.timestamp ?? Date(),
                            year: $displayedMonth,
                            onPickMonth: { month in
                                displayedMonth = month
                                layout = .month
                            }
                        )
                    }
                    if layout == .month {
                        JournalMonthView(
                            counts: dayCounts,
                            earliest: timelineItems.last?.timestamp ?? Date(),
                            month: $displayedMonth,
                            onPickDay: { day in
                                pendingScrollDay = day
                                layout = .days
                            }
                        )
                    }
                    if groupedByDay.isEmpty {
                        emptyState
                    }
                    if layout == .days {
                    ForEach(groupedByDay, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            dayMarker(group.day)

                            ForEach(group.items) { item in
                                switch item {
                                case .entry(let entry):
                                    timelineRow(entry)
                                case .checkIn(let checkIn):
                                    checkInRow(checkIn)
                                }
                            }
                        }
                        .id(group.day)
                    }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            }
            .anchorBackground()
            .onChange(of: layout) { _, newLayout in
                if newLayout == .days, let day = pendingScrollDay {
                    DispatchQueue.main.async {
                        proxy.scrollTo(day, anchor: .top)
                        pendingScrollDay = nil
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search your journal")
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HelpToolbarButton(topic: .journal)
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        switch layout {
                        case .days:
                            withAnimation { proxy.scrollTo(topAnchorID, anchor: .top) }
                        case .month, .year:
                            displayedMonth = Date()
                        }
                    } label: {
                        Label("Jump to today", systemImage: "arrow.up.to.line")
                    }
                    .disabled(groupedByDay.isEmpty)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let entry = JournalEntry(text: "", linkedContext: .manualOpen)
                        modelContext.insert(entry)
                        entryToEdit = entry
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $entryToEdit) { entry in
                JournalEntryEditorView(entry: entry)
            }
            .sheet(item: $entryToRead) { entry in
                JournalEntryReadSheet(entry: entry)
            }
            .sheet(item: $checkInToView) { checkIn in
                CheckInDetailSheet(checkIn: checkIn)
            }
            }
        }
    }

    // MARK: - Row builders

    private func dayMarker(_ day: Date) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Anchor.Theme.accentSoft).frame(width: 44, height: 44)
                VStack(spacing: 0) {
                    Text(day.formatted(.dateTime.day())).font(.system(.subheadline, design: .rounded).bold())
                    Text(day.formatted(.dateTime.month(.abbreviated))).font(.caption2)
                }
                .foregroundStyle(Anchor.Theme.accent)
            }
            Rectangle().fill(Anchor.Theme.accent.opacity(0.2)).frame(height: 1)
        }
        .padding(.vertical, 10)
    }

    private func timelineRow(_ entry: JournalEntry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            timelineConnector(color: Anchor.Theme.accent)

            Button {
                entryToRead = entry
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(entry.text.isEmpty ? "Empty entry" : firstLine(entry.text))
                        .font(.system(.subheadline, design: .rounded))
                        .lineLimit(2)
                        .foregroundStyle(entry.text.isEmpty ? .secondary : .primary)

                    RecoveryDayChips(date: entry.createdAt, counters: recoveryCounters, topPadding: 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Anchor.Theme.accentSoft,
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(.leading, 5)
    }

    /// Check-ins get a lighter-weight row than journal entries: a small
    /// mood-colored dot on the spine and a compact label. Tapping opens
    /// CheckInDetailSheet with the full five-metric breakdown.
    private func checkInRow(_ checkIn: CheckIn) -> some View {
        HStack(alignment: .top, spacing: 0) {
            timelineConnector(color: moodColor(for: checkIn), checkIn: true)

            Button {
                checkInToView = checkIn
            } label: {
                HStack(spacing: 6) {
                    Text(checkIn.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(moodLabel(for: checkIn))
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(moodColor(for: checkIn))

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.bottom, 10)
                .padding(.leading, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.leading, 5)
    }

    /// The vertical spine, connector dot, and horizontal tick shared by
    /// both row types, so entries and check-ins visually line up on the
    /// same timeline rather than living on two different tracks.
    private func timelineConnector(color: Color, checkIn: Bool = false) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Anchor.Theme.accent.opacity(0.25))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
            
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .offset(x: 0, y: 6)
            
            Rectangle()
                .fill(!checkIn ? Anchor.Theme.accent.opacity(0.25) : Anchor.Theme.accent.opacity(0))
                .frame(width: 11, height: 2)
                .offset(x: 10, y: 10)
        }
        .padding(.trailing, 10)
    }

    // MARK: - Score helpers

    /// 0...1 "how good" score, in the same "more = better" direction
    /// established in the check-in redesign (physicalExhaustion/
    /// cognitiveBurnout/mentalLoad are inverted before averaging).
    private func normalizedScore(for checkIn: CheckIn) -> Double {
        let better =
            (1 - checkIn.physicalExhaustion) +
            (1 - checkIn.cognitiveBurnout) +
            (1 - checkIn.mentalLoad) +
            checkIn.physicalEnergy +
            checkIn.socialEnergy

        return better / 5
    }

    private func moodColor(for checkIn: CheckIn) -> Color {
        switch normalizedScore(for: checkIn) {
        case ..<0.35: return .red.opacity(0.8)
        case ..<0.65: return .orange.opacity(0.8)
        default: return Anchor.Theme.accent
        }
    }

    private func moodLabel(for checkIn: CheckIn) -> String {
        switch normalizedScore(for: checkIn) {
        case ..<0.35: return "Rough check-in"
        case ..<0.65: return "Mixed check-in"
        default: return "Good check-in"
        }
    }

    private func firstLine(_ text: String) -> String {
        text.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? text
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "pencil.and.outline")
                .font(.largeTitle)
                .foregroundStyle(Anchor.Theme.accent.opacity(0.5))
            Text(searchText.isEmpty ? "Nothing here yet. Tap the pencil to write." : "No entries match \"\(searchText)\".")
                .foregroundStyle(.secondary)
                .font(.system(.subheadline, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Month view

/// A month grid. Each day that has something on it shows a small dot per
/// entry (up to three) and a small square if there was a check-in. Days
/// with nothing are plain numbers. Tapping a day with something on it
/// opens that day in the timeline.
struct JournalMonthView: View {
    let counts: [Date: JournalDayCount]
    let earliest: Date
    @Binding var month: Date
    let onPickDay: (Date) -> Void

    private var calendar: Calendar { Calendar.current }

    private var monthStart: Date {
        calendar.dateInterval(of: .month, for: month)?.start ?? month
    }

    private var canGoBack: Bool {
        guard let first = calendar.dateInterval(of: .month, for: earliest)?.start else { return false }
        return monthStart > first
    }

    private var canGoForward: Bool {
        guard let current = calendar.dateInterval(of: .month, for: Date())?.start else { return false }
        return monthStart < current
    }

    private var weekdayHeaders: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let lead = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<range.count {
            result.append(calendar.date(byAdding: .day, value: offset, to: monthStart))
        }
        return result
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Previous month")
                Spacer()
                Text(monthStart.formatted(.dateTime.month(.wide).year()))
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(!canGoForward)
                    .accessibilityLabel("Next month")
            }
            .foregroundStyle(Anchor.Theme.accent)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        cell(for: day)
                    } else {
                        Color.clear.frame(minHeight: 48)
                    }
                }
            }

            HStack(spacing: 16) {
                legend(shape: AnyView(Circle().fill(Anchor.Theme.accent)), label: "Entry")
                legend(shape: AnyView(RoundedRectangle(cornerRadius: 1).fill(Anchor.Theme.sage)), label: "Check-in")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private func shift(_ months: Int) {
        if let next = calendar.date(byAdding: .month, value: months, to: monthStart) {
            month = next
        }
    }

    private func legend(shape: AnyView, label: String) -> some View {
        HStack(spacing: 5) {
            shape.frame(width: 7, height: 7)
            Text(label)
        }
    }

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let count = counts[calendar.startOfDay(for: day)]
        let hasItems = (count?.entries ?? 0) + (count?.checkIns ?? 0) > 0
        let isToday = calendar.isDateInToday(day)

        let content = VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(.subheadline, design: .rounded).weight(isToday ? .bold : .regular))
                .foregroundStyle(hasItems || isToday ? Color.primary : Color.secondary)
            HStack(spacing: 3) {
                ForEach(0..<min(count?.entries ?? 0, 3), id: \.self) { _ in
                    Circle().fill(Anchor.Theme.accent).frame(width: 6, height: 6)
                }
                if (count?.checkIns ?? 0) > 0 {
                    RoundedRectangle(cornerRadius: 1).fill(Anchor.Theme.sage).frame(width: 6, height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(
            isToday ? Anchor.Theme.accentSoft : Color.clear,
            in: RoundedRectangle(cornerRadius: 10)
        )

        if hasItems {
            Button { onPickDay(day) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: day, count: count))
        } else {
            content
                .accessibilityLabel(day.formatted(.dateTime.day().month(.wide)))
        }
    }

    private func accessibilityLabel(for day: Date, count: JournalDayCount?) -> String {
        var parts = [day.formatted(.dateTime.day().month(.wide))]
        if let n = count?.entries, n > 0 { parts.append(n == 1 ? "1 entry" : "\(n) entries") }
        if let c = count?.checkIns, c > 0 { parts.append(c == 1 ? "1 check-in" : "\(c) check-ins") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Year view

/// Twelve small months. A day with something on it is a filled square,
/// a little darker if there was more than one thing. There is no target,
/// no colour for better or worse, and empty days look like empty days.
/// Tapping a month opens it in the Month view.
struct JournalYearView: View {
    let counts: [Date: JournalDayCount]
    let earliest: Date
    @Binding var year: Date
    let onPickMonth: (Date) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    private var calendar: Calendar { Calendar.current }

    private var yearStart: Date {
        calendar.dateInterval(of: .year, for: year)?.start ?? year
    }

    private var canGoBack: Bool {
        guard let first = calendar.dateInterval(of: .year, for: earliest)?.start else { return false }
        return yearStart > first
    }

    private var canGoForward: Bool {
        guard let current = calendar.dateInterval(of: .year, for: Date())?.start else { return false }
        return yearStart < current
    }

    private var months: [Date] {
        (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: yearStart) }
    }

    private var currentMonthStart: Date {
        calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
    }

    private var columns: [GridItem] {
        let count = typeSize.isAccessibilitySize ? 2 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .disabled(!canGoBack)
                    .accessibilityLabel("Previous year")
                Spacer()
                Text(yearStart.formatted(.dateTime.year()))
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(!canGoForward)
                    .accessibilityLabel("Next year")
            }
            .foregroundStyle(Anchor.Theme.accent)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(months, id: \.self) { start in
                    miniMonth(start)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func shift(_ years: Int) {
        if let next = calendar.date(byAdding: .year, value: years, to: yearStart) {
            year = next
        }
    }

    private func days(in start: Date) -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: start)
        let lead = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<range.count {
            result.append(calendar.date(byAdding: .day, value: offset, to: start))
        }
        return result
    }

    private func totals(of days: [Date?]) -> JournalDayCount {
        var total = JournalDayCount()
        for day in days.compactMap({ $0 }) {
            if let count = counts[calendar.startOfDay(for: day)] {
                total.entries += count.entries
                total.checkIns += count.checkIns
            }
        }
        return total
    }

    @ViewBuilder
    private func miniMonth(_ start: Date) -> some View {
        let cells = days(in: start)
        let total = totals(of: cells)
        let isFuture = start > currentMonthStart
        let name = start.formatted(.dateTime.month(.abbreviated))

        let content = VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isFuture ? Color.secondary : Color.primary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(shade(for: counts[calendar.startOfDay(for: day)]))
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Anchor.Theme.sageSoft, in: RoundedRectangle(cornerRadius: 10))
        .opacity(isFuture ? 0.5 : 1)

        if isFuture {
            content.accessibilityLabel(name)
        } else {
            Button { onPickMonth(start) } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel(label(name: name, total: total))
        }
    }

    private func shade(for count: JournalDayCount?) -> Color {
        let n = (count?.entries ?? 0) + (count?.checkIns ?? 0)
        switch n {
        case 0: return Color.secondary.opacity(0.14)
        case 1: return Anchor.Theme.accent.opacity(0.45)
        default: return Anchor.Theme.accent
        }
    }

    private func label(name: String, total: JournalDayCount) -> String {
        var parts = [name]
        if total.entries > 0 { parts.append(total.entries == 1 ? "1 entry" : "\(total.entries) entries") }
        if total.checkIns > 0 { parts.append(total.checkIns == 1 ? "1 check-in" : "\(total.checkIns) check-ins") }
        if parts.count == 1 { parts.append("nothing yet") }
        return parts.joined(separator: ", ")
    }
}

/// Detail sheet shown when a check-in row is tapped. Breaks the single
/// rolled-up score back out into its five source metrics so the user can
/// see what actually drove it, each shown as a labeled bar in the same
/// "more = better" direction used everywhere else (the three burden
/// metrics are inverted before display, matching moodColor/moodLabel).
private struct CheckInDetailSheet: View {
    let checkIn: CheckIn
    @Environment(\.dismiss) private var dismiss

    private var metrics: [(label: String, value: Double)] {
        [
            ("Physical energy", checkIn.physicalEnergy),
            ("Social energy", checkIn.socialEnergy),
            ("Physical exhaustion", 1 - checkIn.physicalExhaustion),
            ("Cognitive burnout", 1 - checkIn.cognitiveBurnout),
            ("Mental load", 1 - checkIn.mentalLoad),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(checkIn.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(metrics, id: \.label) { metric in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metric.label)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Anchor.Theme.accentSoft)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Anchor.Theme.accent)
                                            .frame(width: geo.size.width * CGFloat(metric.value))
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .anchorBackground()
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}


/// Opening an existing entry shows it as rendered text (formatting, photos,
/// drawings), not a text box. Edit switches to the editor; Done in the
/// editor returns here.
private struct JournalEntryReadSheet: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecoveryCounter.sortOrder) private var recoveryCounters: [RecoveryCounter]
    @State private var isEditing = false

    var body: some View {
        if isEditing {
            JournalEntryEditorView(entry: entry, onFinish: { isEditing = false })
        } else {
            NavigationStack {
                VStack(spacing: 0) {
                    RecoveryDayChips(date: entry.createdAt, counters: recoveryCounters, topPadding: 6)
                        .padding(.horizontal)
                    MarkdownPreviewView(markdown: entry.text)
                }
                .anchorBackground()
                .navigationTitle(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Anchor.EditToolbarButton { isEditing = true }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
}
