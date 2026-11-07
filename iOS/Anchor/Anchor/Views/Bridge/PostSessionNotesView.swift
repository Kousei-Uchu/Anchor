//
//  PostSessionNotesView.swift
//  Anchor
//
//  Capture right after a session while it's fresh. Links back to the
//  specific AppointmentOccurrence via postSessionNoteEntryID rather than
//  living as an untethered journal entry.
//
//  Browse/edit split: the list and each session's notes are read screens;
//  writing happens in a sheet behind Edit.
//

import SwiftUI
import SwiftData

struct PostSessionNotesView: View {
    @Bindable var series: AppointmentSeries

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
                        NavigationLink {
                            PostSessionNoteView(occurrence: occurrence)
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
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Post-session notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One session's notes, as something to read. Edit opens the writing sheet.
private struct PostSessionNoteView: View {
    let occurrence: AppointmentOccurrence
    @Environment(\.modelContext) private var modelContext
    @State private var entry: JournalEntry?
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                Anchor.TextCard(
                    icon: "note.text",
                    title: "Your notes",
                    text: entry?.text ?? "",
                    placeholder: "No notes for this session yet. Tap Edit to write some.",
                    tint: Anchor.Theme.accent
                )
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle(occurrence.scheduledDate.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: loadEntry) {
            Anchor.EditorSheet(title: "Session notes") {
                PostSessionNoteEditor(occurrence: occurrence)
            }
        }
        .onAppear(perform: loadEntry)
    }

    private func loadEntry() {
        guard let id = occurrence.postSessionNoteEntryID else { return }
        let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == id })
        entry = try? modelContext.fetch(descriptor).first
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
