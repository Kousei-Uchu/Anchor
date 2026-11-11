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
    @State private var showingOnePage = false

    private var nextOccurrence: AppointmentOccurrence? {
        series.occurrenceList.filter { $0.scheduledDate > .now }.sorted { $0.scheduledDate < $1.scheduledDate }.first
    }

    private var lastSessionDate: Date? {
        series.occurrenceList.map(\.scheduledDate).filter { $0 <= .now }.max()
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
        Set(series.occurrenceList.flatMap { [$0.prepNoteEntryID, $0.postSessionNoteEntryID] }.compactMap { $0 })
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

                    // What is waiting in Things to raise for this person or for
                    // anyone. Read-only here; nothing is added unless the person taps.
                    RaiseSessionCard(providerID: series.id, onAddToNotes: appendToNotes)

                    // A short list of things to have with them, for this session only.
                    PrepChecklistCard(occurrence: next)

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

                    // A one-page layout of the same things, to bring or to hand over. The
                    // person chooses what goes on it; nothing is added for them.
                    Button { showingOnePage = true } label: {
                        Label("Make a one-page sheet", systemImage: "doc.plaintext")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.accent))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint("Choose what goes on it, then make a PDF")
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
        .guideButton("bridge.session-prep", tab: .bridge)
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
        .sheet(isPresented: $showingOnePage) {
            if let next = nextOccurrence {
                SessionOnePageSheet(
                    seriesName: series.displayName,
                    providerID: series.id,
                    sessionDate: next.scheduledDate,
                    prepNotes: entry?.text ?? "",
                    toBring: next.prepChecklist,
                    since: summaryStart,
                    sinceIsLastSession: lastSessionDate != nil,
                    excluding: ownNoteIDs
                )
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

    @Query private var allEntriesStored: [JournalEntry]

    /// Sorted after the items are opened, because a locked createdAt cannot be sorted by the database (Patch 35g2).

    private var allEntries: [JournalEntry] { allEntriesStored.sortedByKey(descending: true) { $0.createdAt } }
    @Query private var allCheckIns: [CheckIn]
    @State private var showingList = false
    @State private var chosen: Set<UUID> = []
    @State private var added = false

    private let listLimit = 12

    /// Bookmarked entries first, then the rest, newest first in each group.
    private var entries: [JournalEntry] {
        Self.eligibleEntries(in: allEntries, since: since, excluding: excluding)
    }

    private var checkInCount: Int { Self.checkInTally(in: allCheckIns, since: since) }

    private var countsLine: String { Self.countsText(entries: entries, checkIns: checkInCount) }

    /// Entries with words in them, written since `since`, other than this series' own notes. Bookmarked
    /// first, then the rest, newest first in each group. The one-page sheet reads the same list.
    static func eligibleEntries(in all: [JournalEntry], since: Date, excluding: Set<UUID>) -> [JournalEntry] {
        let sorted = all.sorted { $0.createdAt > $1.createdAt }
        let inRange = sorted.filter {
            $0.createdAt >= since
                && !excluding.contains($0.id)
                && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return inRange.filter { $0.isBookmarked } + inRange.filter { !$0.isBookmarked }
    }

    static func checkInTally(in all: [CheckIn], since: Date) -> Int {
        all.filter { $0.timestamp >= since }.count
    }

    /// "4 journal entries (1 bookmarked) and 3 check-ins". Only counts.
    static func countsText(entries: [JournalEntry], checkIns: Int) -> String {
        func plural(_ n: Int, _ one: String, _ many: String) -> String {
            n == 1 ? "1 \(one)" : "\(n) \(many)"
        }
        var parts: [String] = []
        if !entries.isEmpty {
            var entryPart = plural(entries.count, "journal entry", "journal entries")
            let bookmarked = entries.filter { $0.isBookmarked }.count
            if bookmarked > 0 { entryPart += " (\(bookmarked) bookmarked)" }
            parts.append(entryPart)
        }
        if checkIns > 0 { parts.append(plural(checkIns, "check-in", "check-ins")) }
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

    @Query private var allNightsStored: [SleepEntry]

    /// Sorted after the items are opened, because a locked nightDate cannot be sorted by the database (Patch 35g1b).

    private var allNights: [SleepEntry] { allNightsStored.sortedByKey(descending: true) { $0.nightDate } }
    @State private var added = false

    /// Nights with something written down, from the day of the last session on.
    private var nights: [SleepEntry] { Self.nightsWritten(in: allNights, since: since) }

    private func dayText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private var lines: [String] { Self.describingLines(nights: nights, since: since) }

    /// Nights with something written down, from the day of the last session on. The one-page
    /// sheet reads the same nights.
    static func nightsWritten(in all: [SleepEntry], since: Date) -> [SleepEntry] {
        let start = Calendar.current.startOfDay(for: since)
        return all.filter { !$0.isBlank && $0.nightDate >= start && $0.nightDate <= .now }
    }

    /// The lines the card shows: how many nights, the shortest and longest time asleep, and the
    /// usual bedtime window. It only describes. There is no average, no target and no word for
    /// whether it was enough.
    static func describingLines(nights: [SleepEntry], since: Date) -> [String] {
        let day = since.formatted(date: .abbreviated, time: .omitted)
        let count = nights.count
        let countLine = (count == 1 ? "1 night" : "\(count) nights") + " written down since \(day)."

        var asleepLine: String?
        let minutes = nights.compactMap { $0.shownMinutes }
        if let low = minutes.min(), let high = minutes.max() {
            if minutes.count == 1 {
                asleepLine = "Asleep about \(SleepEntry.describe(minutes: low)) on the night with a time."
            } else if low == high {
                asleepLine = "Asleep about \(SleepEntry.describe(minutes: low)) each of those nights."
            } else {
                asleepLine = "Time asleep from \(SleepEntry.describe(minutes: low)) to \(SleepEntry.describe(minutes: high))."
            }
        }

        // Bed times as minutes after 6 pm, so a bedtime after midnight sorts after one before it.
        let cal = Calendar.current
        let offsets: [Int] = nights.compactMap { $0.bedTime }.map { bed in
            let parts = cal.dateComponents([.hour, .minute], from: bed)
            let clock = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            return (clock - 18 * 60 + 24 * 60) % (24 * 60)
        }.sorted()

        func clockText(offset: Int) -> String {
            let clock = (offset + 18 * 60) % (24 * 60)
            let date = cal.date(bySettingHour: clock / 60, minute: clock % 60, second: 0, of: .now) ?? .now
            return date.formatted(date: .omitted, time: .shortened)
        }

        // The middle of the bed times, rounded to a quarter of an hour, from three nights up.
        // The same rule as the usual range on the Sleep screen.
        var bedtimeLine: String?
        if offsets.count >= 3 {
            func rounded(_ value: Int) -> Int { ((value + 7) / 15) * 15 }
            let low = rounded(offsets[Int((Double(offsets.count - 1) * 0.2).rounded())])
            let high = rounded(offsets[Int((Double(offsets.count - 1) * 0.8).rounded())])
            if low == high {
                bedtimeLine = "Usually in bed around \(clockText(offset: low))."
            } else {
                bedtimeLine = "Usually in bed between \(clockText(offset: low)) and \(clockText(offset: high))."
            }
        }

        return [countLine, asleepLine, bedtimeLine].compactMap { $0 }
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

// MARK: - Things to raise for session prep

/// What is waiting in Things to raise for this provider or for anyone: the
/// open items and the questions not yet asked. It is shown here so the list is
/// in front of the person while they prepare, and it only goes into the prep
/// notes if they tap the button.
struct RaiseSessionCard: View {
    let providerID: UUID
    let onAddToNotes: (String) -> Void

    @Query private var allItemsStored: [BridgeDraftItem]

    /// Sorted after the items are opened, because a locked createdAt cannot be sorted by the database (Patch 35g2).

    private var allItems: [BridgeDraftItem] { allItemsStored.sortedByKey { $0.createdAt } }
    @Query(sort: \AppointmentSeries.sortOrder) private var providers: [AppointmentSeries]
    @State private var added = false

    private var items: [BridgeDraftItem] {
        Self.waitingItems(in: allItems, providerID: providerID, providers: providers)
    }

    /// What is still waiting for this provider or for anyone. The one-page sheet reads the same list.
    static func waitingItems(in all: [BridgeDraftItem], providerID: UUID, providers: [AppointmentSeries]) -> [BridgeDraftItem] {
        all.sorted { $0.createdAt < $1.createdAt }.filter {
            !$0.isResolved
                && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.isFor(providerID, in: providers)
        }
    }

    private var summaryText: String {
        var parts = ["To raise:"]
        parts.append(contentsOf: items.map { ($0.isQuestion ? "- Question: " : "- ") + $0.text })
        return parts.joined(separator: "\n")
    }

    var body: some View {
        if !items.isEmpty {
            Anchor.Card {
                VStack(alignment: .leading, spacing: 10) {
                    Anchor.SectionHeader(icon: "text.bubble.fill", title: "Waiting to be raised")

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: item.isQuestion ? "questionmark.circle" : "circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(item.text)
                                    .font(.system(.subheadline, design: .rounded))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(item.isQuestion ? "Question: \(item.text)" : item.text)
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
                    .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.accent))
                    .disabled(added)
                }
            }
            .onChange(of: items.map(\.id)) { _, _ in added = false }
        }
    }
}

// MARK: - Checklist for one session

/// A short list of what the person wants to have with them for one session
/// (a card, a form, a page of notes). They write it and they tick it. Nothing
/// is suggested, counted or reminded, and ticks carry nothing over to the next
/// session.
struct PrepChecklistCard: View {
    @Bindable var occurrence: AppointmentOccurrence
    @State private var newText = ""
    @FocusState private var typing: Bool

    private var trimmed: String { newText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func add() {
        guard !trimmed.isEmpty else { return }
        occurrence.prepChecklist = occurrence.prepChecklist + [QuickListItem(text: trimmed)]
        newText = ""
        typing = true
    }

    private func toggle(_ item: QuickListItem) {
        var list = occurrence.prepChecklist
        guard let index = list.firstIndex(where: { $0.id == item.id }) else { return }
        list[index].isDone.toggle()
        occurrence.prepChecklist = list
    }

    private func remove(_ item: QuickListItem) {
        occurrence.prepChecklist = occurrence.prepChecklist.filter { $0.id != item.id }
    }

    var body: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 10) {
                Anchor.SectionHeader(icon: "checklist", title: "To bring")

                ForEach(occurrence.prepChecklist) { item in
                    HStack(alignment: .top, spacing: 4) {
                        Button { toggle(item) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.isDone ? Anchor.Theme.sage : Anchor.Theme.accent)
                                Text(item.text)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(item.isDone ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.text)
                        .accessibilityValue(item.isDone ? "Ticked" : "Not ticked")
                        .accessibilityHint("Double tap to change")

                        Button { remove(item) } label: {
                            Image(systemName: "xmark")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(item.text)")
                    }
                }

                HStack(spacing: 8) {
                    TextField("Add something to bring", text: $newText)
                        .focused($typing)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(trimmed.isEmpty)
                }
                .frame(minHeight: 44)
            }
        }
    }
}
