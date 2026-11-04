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

    private var nextOccurrence: AppointmentOccurrence? {
        series.occurrences.filter { $0.scheduledDate > .now }.sorted { $0.scheduledDate < $1.scheduledDate }.first
    }

    var body: some View {
        Group {
            if let next = nextOccurrence {
                VStack(alignment: .leading, spacing: 12) {
                    Text(next.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.title3)
                    if let entry {
                        Text("Prep notes").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: Binding(get: { entry.text }, set: { entry.text = $0 }))
                            .frame(minHeight: 200)
                    } else {
                        ProgressView()
                    }
                }
                .padding()
                .onAppear { loadOrCreateEntry(for: next) }
            } else {
                Text("No upcoming session scheduled. Add one in Plan → Appointments.")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .navigationTitle("Session prep")
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
