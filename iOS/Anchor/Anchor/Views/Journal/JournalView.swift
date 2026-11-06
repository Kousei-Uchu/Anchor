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

struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.createdAt) private var entries: [JournalEntry]
    @Query(sort: \CheckIn.timestamp) private var checkIns: [CheckIn]
    @Query(sort: \RecoveryCounter.sortOrder) private var recoveryCounters: [RecoveryCounter]
    @State private var searchText = ""
    @State private var entryToEdit: JournalEntry?
    @State private var checkInToView: CheckIn?

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
        return (entryItems + checkInItems).sorted { $0.timestamp < $1.timestamp }
    }

    private var groupedByDay: [(day: Date, items: [TimelineItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: timelineItems) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.keys.sorted().map { day in
            (day, grouped[day]!.sorted { $0.timestamp < $1.timestamp })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if groupedByDay.isEmpty {
                        emptyState
                    }
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
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .anchorBackground()
            .searchable(text: $searchText, prompt: "Search your journal")
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HelpToolbarButton(topic: .journal)
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
            .sheet(item: $checkInToView) { checkIn in
                CheckInDetailSheet(checkIn: checkIn)
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
                entryToEdit = entry
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
