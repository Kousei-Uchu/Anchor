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
    /// 1 when a night of sleep is written down for this day and the person has
    /// chosen to see sleep in the Journal. Only ever a mark, never a number.
    var sleepNights = 0
}

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entriesStored: [JournalEntry]
    /// Sorted after the items are opened, because a locked createdAt cannot be sorted by the database (Patch 35g2).
    private var entries: [JournalEntry] { entriesStored.sortedByKey { $0.createdAt } }
    @Query private var checkInsStored: [CheckIn]
    /// Sorted after the items are opened, because a locked timestamp cannot be sorted by the database (Patch 35g1b).
    private var checkIns: [CheckIn] { checkInsStored.sortedByKey { $0.timestamp } }
    @Query(sort: \RecoveryCounter.sortOrder) private var recoveryCounters: [RecoveryCounter]
    @Query private var sleepEntriesStored: [SleepEntry]
    /// Sorted after the items are opened, because a locked nightDate cannot be sorted by the database (Patch 35g1b).
    private var sleepEntries: [SleepEntry] { sleepEntriesStored.sortedByKey { $0.nightDate } }
    @AppStorage(SleepSettings.journalKey) private var showsSleep = false
    @State private var sleepToEdit: SleepEntry?
    @State private var searchText = ""
    @State private var entryToEdit: JournalEntry?
    @State private var entryToRead: JournalEntry?
    @State private var checkInToView: CheckIn?
    /// A check-in deleted from inside its sheet is removed once the sheet has closed (Patch R5).
    @State private var checkInToDelete: CheckIn?
    @State private var addedToBridge = false
    /// Not remembered between launches, so nothing stays hidden by accident.
    @State private var bookmarksOnly = false
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
        let base = bookmarksOnly ? entries.filter { $0.isBookmarked } : entries
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    /// Check-ins don't have searchable text, so while the user is
    /// searching we only surface journal entries that match — but each
    /// still appears filed under its real day, alongside whatever
    /// check-ins happened that day.
    private var timelineItems: [TimelineItem] {
        let entryItems = filteredEntries.map(TimelineItem.entry)
        let checkInItems = (searchText.isEmpty && !bookmarksOnly) ? checkIns.map(TimelineItem.checkIn) : []
        return (entryItems + checkInItems).sorted { $0.timestamp > $1.timestamp }
    }

    /// The nights to show, by the day they belong to. Only with the switch on
    /// in Settings, and like check-ins, not while searching or showing
    /// bookmarks. A night with nothing in it is never shown.
    private var sleepByDay: [Date: SleepEntry] {
        guard showsSleep, searchText.isEmpty, !bookmarksOnly else { return [:] }
        let calendar = Calendar.current
        var result: [Date: SleepEntry] = [:]
        for entry in sleepEntries where !entry.isBlank {
            let day = calendar.startOfDay(for: entry.nightDate)
            if result[day] == nil { result[day] = entry }
        }
        return result
    }

    /// Newest day first, and newest item first within each day, so the
    /// most recent thing is always at the top. A day with only a night of
    /// sleep still gets its place.
    private var groupedByDay: [(day: Date, items: [TimelineItem])] {
        let calendar = Calendar.current
        var grouped = Dictionary(grouping: timelineItems) { calendar.startOfDay(for: $0.timestamp) }
        for day in sleepByDay.keys where grouped[day] == nil { grouped[day] = [] }
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
        for day in sleepByDay.keys {
            var count = result[day] ?? JournalDayCount()
            count.sleepNights = 1
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
                    if bookmarksOnly {
                        HStack {
                            Label("Showing bookmarked entries", systemImage: "bookmark.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Show all") { bookmarksOnly = false }
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 8)
                    }
                    if groupedByDay.isEmpty {
                        emptyState
                    }
                    if layout == .days {
                    ForEach(groupedByDay, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            dayMarker(group.day)

                            if let night = sleepByDay[group.day] {
                                sleepRow(night)
                            }

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
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        bookmarksOnly.toggle()
                    } label: {
                        Label(bookmarksOnly ? "Show all entries" : "Bookmarked only",
                              systemImage: bookmarksOnly ? "bookmark.slash" : "bookmark")
                    }
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
            .sheet(item: $checkInToView, onDismiss: {
                if let doomed = checkInToDelete {
                    modelContext.delete(doomed)
                    checkInToDelete = nil
                }
            }) { checkIn in
                CheckInDetailSheet(checkIn: checkIn) { checkInToDelete = checkIn }
            }
            .sheet(item: $sleepToEdit) { night in
                SleepEntryEditor(entry: night)
            }
            .alert("Added to Things to raise", isPresented: $addedToBridge) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can reword it in Bridge. The journal entry is unchanged.")
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        if entry.isBookmarked {
                            Image(systemName: "bookmark.fill")
                                .font(.caption2)
                                .foregroundStyle(Anchor.Theme.accent)
                                .accessibilityLabel("Bookmarked")
                        }
                    }

                    let preview = JournalBlocks.previewLine(entry.text)
                    Text(preview ?? "Empty entry")
                        .font(.system(.subheadline, design: .rounded))
                        .lineLimit(2)
                        .foregroundStyle(preview == nil ? .secondary : .primary)

                    let pictures = JournalBlocks.imageNames(in: entry.text)
                    if !pictures.isEmpty {
                        JournalThumbnailStrip(filenames: pictures)
                    }

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
            Button {
                entry.isBookmarked.toggle()
            } label: {
                Label(entry.isBookmarked ? "Remove bookmark" : "Bookmark",
                      systemImage: entry.isBookmarked ? "bookmark.slash" : "bookmark")
            }
            Button {
                if let item = BridgeDraftItem.raising(fromJournal: entry.text) {
                    modelContext.insert(item)
                    addedToBridge = true
                }
            } label: {
                Label("Add to things to raise", systemImage: "doc.text")
            }
            .disabled(BridgeDraftItem.raising(fromJournal: entry.text) == nil)
            Button(role: .destructive) {
                JournalBlocks.deleteVoiceFiles(in: entry.text)
                modelContext.delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(.leading, 5)
    }

    /// Check-ins get a lighter-weight row than journal entries: a small
    /// dot on the spine, a plain label and the five sliders exactly as they
    /// were set. Nothing is rated, summed or coloured by how they were set,
    /// and there are no numbers. Tapping opens CheckInDetailSheet.
    private func checkInRow(_ checkIn: CheckIn) -> some View {
        HStack(alignment: .top, spacing: 0) {
            timelineConnector(color: Anchor.Theme.accent, checkIn: true)

            Button {
                checkInToView = checkIn
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(checkIn.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("Check-in")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(Anchor.Theme.accent)

                        if !checkIn.answers.isEmpty {
                            Image(systemName: "text.bubble")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if checkIn.expandedEntryID != nil {
                            Image(systemName: "link")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    CheckInReadingsStrip(readings: checkIn.readings)
                }
                .padding(.vertical, 6)
                .padding(.bottom, 10)
                .padding(.leading, 10)
                .padding(.trailing, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Check-in, \(checkIn.timestamp.formatted(date: .omitted, time: .shortened)). \(checkIn.readings.map(\.spoken).joined(separator: ". "))")
            .accessibilityHint("Opens the check-in")

            Spacer(minLength: 0)
        }
        .padding(.leading, 5)
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(checkIn)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// A small, quiet row at the top of the morning a night belongs to. It
    /// says how long, if that is known, and nothing about whether it was
    /// enough. Tapping opens the night.
    private func sleepRow(_ night: SleepEntry) -> some View {
        HStack(alignment: .top, spacing: 0) {
            timelineConnector(color: Anchor.Theme.sage, checkIn: true)

            Button {
                sleepToEdit = night
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption)
                        .foregroundStyle(Anchor.Theme.sage)
                    Text(night.shownMinutes.map { "Slept \(SleepEntry.describe(minutes: $0))" } ?? "A night noted")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .padding(.bottom, 10)
                .padding(.leading, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the night")

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

    private var emptyMessage: String {
        if !searchText.isEmpty { return "No entries match \"\(searchText)\"." }
        if bookmarksOnly { return "No bookmarked entries yet. Press and hold an entry to bookmark it." }
        return "Nothing here yet. Tap the pencil to write."
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "pencil.and.outline")
                .font(.largeTitle)
                .foregroundStyle(Anchor.Theme.accent.opacity(0.5))
            Text(emptyMessage)
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
                if counts.values.contains(where: { $0.sleepNights > 0 }) {
                    legend(shape: AnyView(Image(systemName: "moon.fill").resizable().scaledToFit().foregroundStyle(Anchor.Theme.sage)), label: "Sleep")
                }
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
        let hasItems = (count?.entries ?? 0) + (count?.checkIns ?? 0) + (count?.sleepNights ?? 0) > 0
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
                if (count?.sleepNights ?? 0) > 0 {
                    Image(systemName: "moon.fill").font(.system(size: 6)).foregroundStyle(Anchor.Theme.sage)
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
        if let s = count?.sleepNights, s > 0 { parts.append("sleep noted") }
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

/// Detail sheet shown when a check-in row is tapped. Shows the five sliders
/// as they were set, each as a labeled bar in the same "more = better"
/// direction (the three burden metrics are inverted before display). There
/// is no total and no rating.
private struct CheckInDetailSheet: View {
    let checkIn: CheckIn
    /// Asked to delete this check-in. The Journal removes it once this sheet has closed.
    var onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Query private var entriesStored: [JournalEntry]
    @State private var linking = false
    @State private var entryToOpen: JournalEntry?
    @State private var confirmingDelete = false

    init(checkIn: CheckIn, onDelete: @escaping () -> Void) {
        self.checkIn = checkIn
        self.onDelete = onDelete
    }

    /// The Journal entry this check-in is linked to, if it still exists.
    private var linkedEntry: JournalEntry? {
        guard let id = checkIn.expandedEntryID else { return nil }
        return entriesStored.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(checkIn.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(checkIn.readings) { reading in
                            VStack(alignment: .leading, spacing: 4) {
                                Label(reading.title, systemImage: reading.icon)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)

                                CheckInBar(value: reading.value, height: 8)

                                HStack(alignment: .firstTextBaseline) {
                                    Text(reading.low)
                                    Spacer(minLength: 12)
                                    Text(reading.high).multilineTextAlignment(.trailing)
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(reading.spoken)
                        }
                    }

                    // The answers to the optional questions, kept on the check-in itself.
                    let answers = checkIn.answers
                    if !answers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Your answers", systemImage: "text.bubble")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                            ForEach(answers) { item in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.question)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(item.answer)
                                        .font(.system(.body, design: .rounded))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }

                    // The link to a Journal entry, which can be made, changed, opened or removed here.
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Journal entry", systemImage: "link")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                        if let entry = linkedEntry {
                            Text(JournalBlocks.previewLine(entry.text) ?? "Empty entry")
                                .font(.system(.subheadline, design: .rounded))
                                .lineLimit(3)
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 10) {
                                Button("Open") { entryToOpen = entry }
                                    .buttonStyle(.bordered)
                                Button("Change") { linking = true }
                                    .buttonStyle(.bordered)
                                Button("Unlink", role: .destructive) { checkIn.expandedEntryID = nil }
                                    .buttonStyle(.bordered)
                            }
                        } else {
                            Text("Not linked to a Journal entry.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button { linking = true } label: {
                                Label("Link a Journal entry", systemImage: "link.badge.plus")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Label("Delete this check-in", systemImage: "trash")
                    }
                    .padding(.top, 8)

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
            .sheet(isPresented: $linking) {
                JournalEntryPickerSheet(selectedID: checkIn.expandedEntryID) { entry in
                    checkIn.expandedEntryID = entry.id
                }
            }
            .sheet(item: $entryToOpen) { entry in
                JournalEntryEditorView(entry: entry)
            }
            .confirmationDialog("Delete this check-in?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("The Journal entry it is linked to, if any, is not deleted.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// A list of Journal entries to pick one from, newest first. Used to link a check-in to an entry.
struct JournalEntryPickerSheet: View {
    var selectedID: UUID?
    var onPick: (JournalEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query private var entriesStored: [JournalEntry]

    init(selectedID: UUID? = nil, onPick: @escaping (JournalEntry) -> Void) {
        self.selectedID = selectedID
        self.onPick = onPick
    }

    private var entries: [JournalEntry] {
        Array(entriesStored.sortedByKey(descending: true) { $0.createdAt }.prefix(100))
    }

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Text("There are no Journal entries yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    Button {
                        onPick(entry)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(JournalBlocks.previewLine(entry.text) ?? "Empty entry")
                                    .font(.system(.subheadline, design: .rounded))
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                            }
                            Spacer(minLength: 8)
                            if entry.id == selectedID {
                                Image(systemName: "checkmark").foregroundStyle(Anchor.Theme.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link a Journal entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

/// A list of check-ins to pick one from, newest first. Used to link a Journal entry to a check-in.
struct CheckInPickerSheet: View {
    var selectedIDs: Set<UUID> = []
    var onPick: (CheckIn) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query private var checkInsStored: [CheckIn]

    init(selectedIDs: Set<UUID> = [], onPick: @escaping (CheckIn) -> Void) {
        self.selectedIDs = selectedIDs
        self.onPick = onPick
    }

    private var checkIns: [CheckIn] {
        Array(checkInsStored.sortedByKey(descending: true) { $0.timestamp }.prefix(100))
    }

    var body: some View {
        NavigationStack {
            List {
                if checkIns.isEmpty {
                    Text("There are no check-ins yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(checkIns) { checkIn in
                    Button {
                        onPick(checkIn)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(checkIn.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                CheckInReadingsStrip(readings: checkIn.readings)
                            }
                            Spacer(minLength: 8)
                            if selectedIDs.contains(checkIn.id) {
                                Image(systemName: "checkmark").foregroundStyle(Anchor.Theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Link a check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

/// One slider of a check-in as it was set, in the words the check-in used.
/// `value` is 0 to 1 with more always the better direction, the same way the
/// sliders on Now are drawn. It is never turned into a number on screen.
private struct CheckInReading: Identifiable {
    let id: String
    let title: String
    let short: String
    let icon: String
    let low: String
    let high: String
    let value: Double

    /// Position along the slider, in words for VoiceOver. Stated as where the
    /// slider was left, not as a verdict.
    var spoken: String {
        "\(title), the slider was left \(Int((value * 100).rounded())) percent of the way from \(low) to \(high)"
    }
}

private extension CheckIn {
    /// The five sliders in the order the check-in asks them. Three are stored
    /// the other way round (as exhaustion, burnout and load), so they are
    /// turned back here to what the person actually moved.
    var readings: [CheckInReading] {
        func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
        return [
            CheckInReading(id: "energy", title: "Physical energy", short: "Energy", icon: "bolt.fill",
                           low: "running on empty", high: "fully charged", value: clamp(1 - physicalExhaustion)),
            CheckInReading(id: "clarity", title: "Mental clarity", short: "Clarity", icon: "lightbulb.fill",
                           low: "foggy", high: "clear", value: clamp(1 - cognitiveBurnout)),
            CheckInReading(id: "room", title: "Room in your head", short: "Room", icon: "cloud.fill",
                           low: "crowded", high: "plenty of space", value: clamp(1 - mentalLoad)),
            CheckInReading(id: "move", title: "Physical energy to move", short: "Moving", icon: "figure.walk",
                           low: "hard to move", high: "ready to move", value: clamp(physicalEnergy)),
            CheckInReading(id: "social", title: "Social energy", short: "Social", icon: "person.2.fill",
                           low: "need space", high: "up for company", value: clamp(socialEnergy))
        ]
    }
}

/// A plain filled bar, the same colour for every value and every check-in.
private struct CheckInBar: View {
    let value: Double
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Anchor.Theme.accentSoft)
                Capsule().fill(Anchor.Theme.accent)
                    .frame(width: geo.size.width * CGFloat(value))
            }
        }
        .frame(height: height)
    }
}

/// The five readings on a Journal row. Side by side on a normal text size;
/// one under another, with the full names, at accessibility sizes so nothing
/// is cut off. Hidden from VoiceOver because the row reads them itself.
private struct CheckInReadingsStrip: View {
    let readings: [CheckInReading]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(readings) { reading in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(reading.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            CheckInBar(value: reading.value)
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(readings) { reading in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(reading.short)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            CheckInBar(value: reading.value)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: 320, alignment: .leading)
        .accessibilityHidden(true)
    }
}


/// Opening an existing entry shows it as rendered text (formatting, photos,
/// drawings), not a text box. Tapping the entry switches to the editor; Done
/// in the editor returns here.
private struct JournalEntryReadSheet: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecoveryCounter.sortOrder) private var recoveryCounters: [RecoveryCounter]
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var addedToBridge = false

    var body: some View {
        if isEditing {
            JournalEntryEditorView(entry: entry, onFinish: { isEditing = false })
        } else {
            NavigationStack {
                MarkdownPreviewView(markdown: entry.text) {
                    VStack(alignment: .leading, spacing: 6) {
                        JournalPageHeader(date: entry.createdAt, bookmarked: entry.isBookmarked)
                        RecoveryDayChips(date: entry.createdAt, counters: recoveryCounters, topPadding: 0)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isEditing = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the editor")
                .anchorBackground()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { isEditing = true } label: { Image(systemName: "pencil") }
                            .accessibilityLabel("Edit entry")
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { entry.isBookmarked.toggle() } label: {
                            Image(systemName: entry.isBookmarked ? "bookmark.fill" : "bookmark")
                        }
                        .accessibilityLabel(entry.isBookmarked ? "Remove bookmark" : "Bookmark")
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            if let item = BridgeDraftItem.raising(fromJournal: entry.text) {
                                modelContext.insert(item)
                                addedToBridge = true
                            }
                        } label: { Image(systemName: "doc.text") }
                            .disabled(BridgeDraftItem.raising(fromJournal: entry.text) == nil)
                            .accessibilityLabel("Add to things to raise")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .alert("Added to Things to raise", isPresented: $addedToBridge) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("You can reword it in Bridge. The journal entry is unchanged.")
                }
            }
        }
    }
}
