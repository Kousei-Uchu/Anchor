//
//  PostSessionNotesView.swift
//  Anchor
//
//  Capture right after a session while it's fresh. Links back to the
//  specific AppointmentOccurrence via postSessionNoteEntryID rather than
//  living as an untethered journal entry.
//

import SwiftUI
import SwiftData

struct PostSessionNotesView: View {
    @Bindable var series: AppointmentSeries
    @Environment(\.modelContext) private var modelContext

    private var pastOccurrences: [AppointmentOccurrence] {
        series.occurrences
            .filter { $0.scheduledDate <= .now }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    var body: some View {
        List {
            if pastOccurrences.isEmpty {
                Text("No past sessions yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(pastOccurrences) { occurrence in
                NavigationLink {
                    PostSessionNoteEditor(occurrence: occurrence)
                } label: {
                    VStack(alignment: .leading) {
                        Text(occurrence.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        if occurrence.postSessionNoteEntryID != nil {
                            Text("Has notes").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Post-session notes")
    }
}

private struct PostSessionNoteEditor: View {
    @Bindable var occurrence: AppointmentOccurrence
    @Environment(\.modelContext) private var modelContext
    @State private var entry: JournalEntry?

    var body: some View {
        Group {
            if let entry {
                TextEditor(text: Binding(
                    get: { entry.text },
                    set: { entry.text = $0 }
                ))
                .padding(8)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(occurrence.scheduledDate.formatted(date: .abbreviated, time: .omitted))
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
