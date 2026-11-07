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

import SwiftUI
import SwiftData

struct PostSessionNotesView: View {
    @Bindable var series: AppointmentSeries
    @Environment(\.modelContext) private var modelContext
    @State private var editing: AppointmentOccurrence?
    @State private var lastEdited: AppointmentOccurrence?

    private var pastOccurrences: [AppointmentOccurrence] {
        series.occurrences
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
        if entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(entry)
            occurrence.postSessionNoteEntryID = nil
        }
    }
}

private struct PostSessionNoteEditor: View {
    @Bindable var occurrence: AppointmentOccurrence
    @Environment(\.modelContext) private var modelContext
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
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
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
}
