//
//  PostSessionNotesView.swift
//  Anchor
//
//  Capture right after a session while it's fresh. Links back to the
//  specific AppointmentOccurrence via postSessionNoteEntryID rather than
//  living as an untethered journal entry.
//
//  Tap a session to write or change its notes. There is no separate page
//  to read them on first, so it is one tap, not two.
//
//  A line that starts with [ ] is a thing to do. Under the note each one has
//  an Add as task button. Nothing is added until it is tapped, the task has
//  no date, and the line stays in the note.
//

import SwiftUI
import SwiftData

struct PostSessionNotesView: View {
    @Bindable var series: AppointmentSeries
    @Environment(\.modelContext) private var modelContext
    @State private var editing: AppointmentOccurrence?
    @State private var lastEdited: AppointmentOccurrence?

    private var pastOccurrences: [AppointmentOccurrence] {
        series.occurrenceList
            .filter { $0.scheduledDate <= .now }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if pastOccurrences.isEmpty {
                    Anchor.EmptyState(
                        icon: "note.text",
                        title: "No past sessions yet",
                        message: "After a session, the notes you write about it will be kept here, one per session.",
                        tint: Anchor.Theme.accent
                    )
                } else {
                    ForEach(pastOccurrences) { occurrence in
                        Button {
                            lastEdited = occurrence
                            editing = occurrence
                        } label: {
                            Anchor.Card {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(occurrence.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text(occurrence.postSessionNoteEntryID != nil ? "Has notes" : "No notes yet")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the notes")
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Post-session notes")
        .guideButton("bridge.post-session", tab: .bridge)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing, onDismiss: dropBlankNote) { occurrence in
            Anchor.ItemEditorSheet(title: occurrence.scheduledDate.formatted(date: .abbreviated, time: .omitted)) {
                PostSessionNoteEditor(occurrence: occurrence)
            }
        }
    }

    /// Opening a session's notes creates an empty entry to write into. If
    /// nothing was written, remove it, so the session doesn't say "Has notes".
    private func dropBlankNote() {
        guard let occurrence = lastEdited, let id = occurrence.postSessionNoteEntryID else { return }
        lastEdited = nil
        let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })
        guard let entry = try? modelContext.fetch(descriptor).first else {
            occurrence.postSessionNoteEntryID = nil
            return
        }
        // A note that holds only an empty [ ] marker has nothing written in it.
        if SessionActions.written(in: entry.text).isEmpty {
            modelContext.delete(entry)
            occurrence.postSessionNoteEntryID = nil
        }
    }
}

/// The lines of a note that were marked as a thing to do by starting them with [ ].
enum SessionActions {
    static let marker = "[ ]"

    /// The words after the marker on each marked line, in order, each once.
    static func lines(in text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix(marker) else { continue }
            let title = line.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty, seen.insert(title).inserted { result.append(title) }
        }
        return result
    }

    /// The note with empty markers taken out and trimmed, so a note that is only a marker counts as blank.
    static func written(in text: String) -> String {
        text.replacingOccurrences(of: marker, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PostSessionNoteEditor: View {
    @Bindable var occurrence: AppointmentOccurrence
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @State private var entry: JournalEntry?

    var body: some View {
        Group {
            if let entry {
                Form {
                    Section {
                        TextEditor(text: Binding(
                            get: { entry.text },
                            set: { entry.text = $0 }
                        ))
                        .frame(minHeight: 260)
                    }
                    Section {
                        Button {
                            addMarker(to: entry)
                        } label: {
                            Label("Add a thing to do", systemImage: "checklist")
                                .font(.system(.subheadline, design: .rounded))
                        }
                        ForEach(SessionActions.lines(in: entry.text), id: \.self) { title in
                            HStack(spacing: 12) {
                                Text(title)
                                    .font(.system(.subheadline, design: .rounded))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if inTasks(title) {
                                    Text("In Tasks")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Button("Add as task") { addTask(title) }
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                                        .buttonStyle(.borderless)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        Text("Things to do")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            loadEntry()
        }
    }

    /// Starts a new line with the marker, ready to type after.
    private func addMarker(to entry: JournalEntry) {
        var text = entry.text
        if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
        entry.text = text + SessionActions.marker + " "
    }

    private func inTasks(_ title: String) -> Bool {
        tasks.contains { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) == title }
    }

    /// A task with the line as its title and no date. The line stays in the note.
    private func addTask(_ title: String) {
        guard !inTasks(title) else { return }
        let order = (tasks.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(TaskItem(title: title, sortOrder: order))
    }

    private func loadEntry() {
        if let id = occurrence.postSessionNoteEntryID {
            let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })
            entry = try? modelContext.fetch(descriptor).first
        }
        if entry == nil {
            let newEntry = JournalEntry(text: "")
            modelContext.insert(newEntry)
            occurrence.postSessionNoteEntryID = newEntry.id
            entry = newEntry
        }
    }
}
