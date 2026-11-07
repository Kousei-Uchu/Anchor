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

    private func appendToNotes(_ text: String) {
        guard let entry else { return }
        let existing = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.text = existing.isEmpty ? text : entry.text + "\n\n" + text
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Anchor.Theme.spacing) {
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
