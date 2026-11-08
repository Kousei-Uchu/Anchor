//
//  AppointmentPrepView.swift
//  Anchor
//
//  Prep note is linked to the specific upcoming AppointmentOccurrence via
//  prepNoteEntryID, same pattern as post-session notes — tied to the real
//  editable occurrence, not a generic countdown against a fixed interval.
//

import SwiftUI
import SwiftData

struct AppointmentPrepView: View {
    @Bindable var series: AppointmentSeries
    @Environment(\.modelContext) private var modelContext
    @State private var entry: JournalEntry?
    @State private var showingEditor = false

    private var nextOccurrence: AppointmentOccurrence? {
        series.occurrences.filter { $0.scheduledDate > .now }.sorted { $0.scheduledDate < $1.scheduledDate }.first
    }

    private var lastSessionDate: Date? {
        series.occurrences.map(\.scheduledDate).filter { $0 <= .now }.max()
    }

    /// Where the Recovery summary starts counting: the last session, or a typical gap before now.
    private var summaryStart: Date {
        lastSessionDate
            ?? Calendar.current.date(byAdding: .day, value: -max(series.typicalCadenceDays, 7), to: .now)
            ?? .now
    }

    /// Journal entries that are this series' own prep and post-session notes,
    /// which are not offered back as things written since the last session.
    private var ownNoteIDs: Set<UUID> {
        Set(series.occurrences.flatMap { [$0.prepNoteEntryID, $0.postSessionNoteEntryID] }.compactMap { $0 })
    }

    private func appendToNotes(_ text: String) {
        guard let entry else { return }
        let existing = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.text = existing.isEmpty ? text : entry.text + "\n\n" + text
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Anchor.Theme.spacing) {
                if !series.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Anchor.SectionHeader(icon: "person.text.rectangle", title: "About \(series.displayName)")
                            Text(series.notes)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                if let next = nextOccurrence {
                    Anchor.Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Anchor.SectionHeader(icon: "calendar.badge.clock", title: "Next session")
                            Text(next.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(.title3, design: .rounded))
                        }
                    }

                    // Only appears once the user has a Recovery counter. Read-only until
                    // they choose to add it to their prep notes.
                    RecoverySessionSummaryCard(
                        since: summaryStart,
                        sinceIsLastSession: lastSessionDate != nil,
                        onAddToNotes: appendToNotes
                    )

                    // Journal entries and check-ins since then. Counts only, no values;
                    // the person picks which entries to bring.
                    JournalSessionSummaryCard(
                        since: summaryStart,
                        sinceIsLastSession: lastSessionDate != nil,
                        excluding: ownNoteIDs,
                        onAddToNotes: appendToNotes
                    )

                    // Only appears once there are nights written down since then.
                    // Descriptive only; nothing is added unless the person taps.
                    SleepSessionSummaryCard(
                        since: summaryStart,
                        sinceIsLastSession: lastSessionDate != nil,
                        onAddToNotes: appendToNotes
                    )

                    Button { showingEditor = true } label: {
                        Anchor.TextCard(
                            icon: "list.bullet.clipboard.fill",
                            title: "Prep notes",
                            text: entry?.text ?? "",
                            placeholder: "Nothing written yet. Tap here to jot down what you want to bring up.",
                            tint: Anchor.Theme.accent
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the editor")
                } else {
                    Anchor.EmptyState(
                        icon: "calendar",
                        title: "No upcoming session",
                        message: "Add one in Plan → Appointments and your prep notes will live here.",
                        tint: Anchor.Theme.accent
                    )
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Session prep")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) {
            Anchor.ItemEditorSheet(title: "Prep notes") {
                if let entry {
                    Form {
                        Section {
                            TextEditor(text: Binding(get: { entry.text }, set: { entry.text = $0 }))
                                .frame(minHeight: 260)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .onAppear {
            if let next = nextOccurrence { loadOrCreateEntry(for: next) }
        }
    }

    private func loadOrCreateEntry(for occurrence: AppointmentOccurrence) {
        if let id = occurrence.prepNoteEntryID {
            let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })
            entry = try? modelContext.fetch(descriptor).first
        }
        if entry == nil {
            let newEntry = JournalEntry(text: "")
            modelContext.insert(newEntry)
            occurrence.prepNoteEntryID = newEntry.id
            entry = newEntry
        }
    }
}

// MARK: - Recovery summary for session prep

/// "Since your last session", drawn from the user's Recovery counters. It is
/// the user's own record, shown plainly (no scores, no comparison) and only added
/// to their prep notes if they tap the button.
struct RecoverySessionSummaryCard: View {
    let since: Date
    let sinceIsLastSession: Bool
    let onAddToNotes: (String) -> Void

    @Query(sort: \RecoveryCounter.sortOrder) private var allCounters: [RecoveryCounter]
    @Query private var allUrges: [RecoveryUrge]
    @State private var added = false

    private var counters: [RecoveryCounter] { allCounters.filter { !$0.isArchived } }

    private func lines(for counter: RecoveryCounter) -> [String] {
        RecoverySummary.lines(for: counter, urges: allUrges, range: min(since, .now)...Date.now)
    }

    private var summaryText: String {
        var parts: [String] = ["Recovery since \(since.formatted(date: .abbreviated, time: .omitted)):"]
        for counter in counters {
            parts.append("\(counter.name): " + lines(for: counter).joined(separator: "; "))
        }
        return parts.joined(separator: "\n")
    }

    var body: some View {
        if !counters.isEmpty {
            Anchor.Card(accentColor: Anchor.Theme.sage) {
                VStack(alignment: .leading, spacing: 10) {
                    Anchor.SectionHeader(icon: "calendar.badge.checkmark",
                                         title: sinceIsLastSession ? "Recovery since your last session" : "Recovery lately",
                                         tint: Anchor.Theme.sage)

                    ForEach(counters) { counter in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(counter.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            ForEach(lines(for: counter), id: \.self) { line in
                                Text(line)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Text("Only shown here. Nothing goes into your notes unless you add it.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button {
                        onAddToNotes(summaryText)
                        added = true
                    } label: {
                        Label(added ? "Added to prep notes" : "Add to prep notes",
                              systemImage: added ? "checkmark" : "plus")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
                    .disabled(added)
                }
            }
        }
    }
}

// MARK: - Journal and check-ins for session prep

/// "Since your last session", drawn from the journal and check-ins. It shows how
/// many of each there are and lets the person pick journal entries to bring. A
/// check-in is only ever counted, never read out: no values, no averages. Nothing
/// goes into the prep notes unless the person taps the button.
struct JournalSessionSummaryCard: View {
    let since: Date
    let sinceIsLastSession: Bool
    let excluding: Set<UUID>
    let onAddToNotes: (String) -> Void

    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var allEntries: [JournalEntry]
    @Query private var allCheckIns: [CheckIn]
    @State private var showingList = false
    @State private var chosen: Set<UUID> = []
    @State private var added = false

    private let listLimit = 12

    /// Bookmarked entries first, then the rest, newest first in each group.
    private var entries: [JournalEntry] {
        let inRange = allEntries.filter {
            $0.createdAt >= since
                && !excluding.contains($0.id)
                && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return inRange.filter { $0.isBookmarked } + inRange.filter { !$0.isBookmarked }
    }

    private var bookmarkedCount: Int { entries.filter { $0.isBookmarked }.count }

    private var checkInCount: Int {
        allCheckIns.filter { $0.timestamp >= since }.count
    }

    private func plural(_ n: Int, _ one: String, _ many: String) -> String {
        n == 1 ? "1 \(one)" : "\(n) \(many)"
    }

    private var countsLine: String {
        var parts: [String] = []
        if !entries.isEmpty {
            var entryPart = plural(entries.count, "journal entry", "journal entries")
            if bookmarkedCount > 0 { entryPart += " (\(bookmarkedCount) bookmarked)" }
            parts.append(entryPart)
        }
        if checkInCount > 0 { parts.append(plural(checkInCount, "check-in", "check-ins")) }
        return parts.joined(separator: " and ")
    }

    private func line(for entry: JournalEntry) -> String {
        let first = JournalBlocks.previewLine(entry.text) ?? ""
        return first.count > 140 ? String(first.prefix(140)) + "..." : first
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private var summaryText: String {
        var parts = ["Since \(dayText(since)): \(countsLine)."]
        let picked = entries.filter { chosen.contains($0.id) }
        if !picked.isEmpty {
            parts.append("From my journal:")
            parts.append(contentsOf: picked.reversed().map { "- \(dayText($0.createdAt)): \(line(for: $0))" })
        }
        return parts.joined(separator: "\n")
    }

    var body: some View {
        if !entries.isEmpty || checkInCount > 0 {
            Anchor.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Anchor.SectionHeader(icon: "book.closed.fill",
                                         title: sinceIsLastSession ? "Journal since your last session" : "Journal lately")

                    Text("\(countsLine) since \(dayText(since)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !entries.isEmpty {
                        Button {
                            withAnimation { showingList.toggle() }
                        } label: {
                            HStack {
                                Text(showingList ? "Hide entries" : "Choose entries to bring")
                                Spacer()
                                Image(systemName: showingList ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(showingList ? "Hides the list" : "Shows your entries so you can pick some")

                        if showingList {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(entries.prefix(listLimit)) { entry in
                                    Button {
                                        if chosen.contains(entry.id) { chosen.remove(entry.id) } else { chosen.insert(entry.id) }
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: chosen.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(chosen.contains(entry.id) ? Anchor.Theme.accent : .secondary)
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 4) {
                                                    Text(dayText(entry.createdAt))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                    if entry.isBookmarked {
                                                        Image(systemName: "bookmark.fill")
                                                            .font(.caption2)
                                                            .foregroundStyle(Anchor.Theme.accent)
                                                            .accessibilityLabel("Bookmarked")
                                                    }
                                                }
                                                Text(line(for: entry))
                                                    .font(.subheadline)
                                                    .multilineTextAlignment(.leading)
                                                    .lineLimit(3)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(chosen.contains(entry.id) ? .isSelected : [])
                                }
                                if entries.count > listLimit {
                                    Text("Showing the \(listLimit) most recent.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Text("Only shown here. Nothing goes into your notes unless you add it. Check-ins are only counted.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button {
                        onAddToNotes(summaryText)
                        added = true
                    } label: {
                        Label(added ? "Added to prep notes" : "Add to prep notes",
                              systemImage: added ? "checkmark" : "plus")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.accent))
                    .disabled(added)
                }
            }
            .onChange(of: chosen) { _, _ in added = false }
        }
    }
}

// MARK: - Sleep for session prep

/// "Sleep since your last session": how many nights are written down, the
/// shortest and longest time asleep, and the usual bedtime window. It only
/// describes. There is no average, no target and no word for whether it was
/// enough. Nothing goes into the prep notes unless the person taps the button.
struct SleepSessionSummaryCard: View {
    let since: Date
    let sinceIsLastSession: Bool
    let onAddToNotes: (String) -> Void

    @Query(sort: \SleepEntry.nightDate, order: .reverse) private var allNights: [SleepEntry]
    @State private var added = false

    /// Nights with something written down, from the day of the last session on.
    private var nights: [SleepEntry] {
        let start = Calendar.current.startOfDay(for: since)
        return allNights.filter { !$0.isBlank && $0.nightDate >= start && $0.nightDate <= .now }
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private var countLine: String {
        let n = nights.count
        return (n == 1 ? "1 night" : "\(n) nights") + " written down since \(dayText(since))."
    }

    private var asleepLine: String? {
        let minutes = nights.compactMap { $0.shownMinutes }
        guard let low = minutes.min(), let high = minutes.max() else { return nil }
        if minutes.count == 1 { return "Asleep about \(SleepEntry.describe(minutes: low)) on the night with a time." }
        if low == high { return "Asleep about \(SleepEntry.describe(minutes: low)) each of those nights." }
        return "Time asleep from \(SleepEntry.describe(minutes: low)) to \(SleepEntry.describe(minutes: high))."
    }

    /// Bed times as minutes after 6 pm, so a bedtime after midnight sorts after
    /// one before it.
    private var bedOffsets: [Int] {
        let cal = Calendar.current
        return nights.compactMap { $0.bedTime }.map { bed in
            let parts = cal.dateComponents([.hour, .minute], from: bed)
            let clock = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            return (clock - 18 * 60 + 24 * 60) % (24 * 60)
        }.sorted()
    }

    private func clockText(offset: Int) -> String {
        let clock = (offset + 18 * 60) % (24 * 60)
        let cal = Calendar.current
        let date = cal.date(bySettingHour: clock / 60, minute: clock % 60, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// The middle of the bed times, rounded to a quarter of an hour, from three
    /// nights up. The same rule as the usual range on the Sleep screen.
    private var bedtimeLine: String? {
        let offsets = bedOffsets
        guard offsets.count >= 3 else { return nil }
        func rounded(_ value: Int) -> Int { ((value + 7) / 15) * 15 }
        let low = rounded(offsets[Int((Double(offsets.count - 1) * 0.2).rounded())])
        let high = rounded(offsets[Int((Double(offsets.count - 1) * 0.8).rounded())])
        if low == high { return "Usually in bed around \(clockText(offset: low))." }
        return "Usually in bed between \(clockText(offset: low)) and \(clockText(offset: high))."
    }

    private var lines: [String] {
        [countLine, asleepLine, bedtimeLine].compactMap { $0 }
    }

    var body: some View {
        if !nights.isEmpty {
            Anchor.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Anchor.SectionHeader(icon: "moon.zzz.fill",
                                         title: sinceIsLastSession ? "Sleep since your last session" : "Sleep lately")

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(lines, id: \.self) { line in
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Text("Only shown here. Nothing goes into your notes unless you add it.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button {
                        onAddToNotes("Sleep since \(dayText(since)): " + lines.joined(separator: " "))
                        added = true
                    } label: {
                        Label(added ? "Added to prep notes" : "Add to prep notes",
                              systemImage: added ? "checkmark" : "plus")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.accent))
                    .disabled(added)
                }
            }
            .onChange(of: nights.count) { _, _ in added = false }
        }
    }
}
