//
//  FutureNoteView.swift
//  Anchor
//
//  Locked notes actually stay unreadable until their date — the text isn't
//  shown, not even faded/blurred-preview, until isUnlocked resolves true.
//

import SwiftUI
import SwiftData

struct FutureNoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FutureNote.unlockDate) private var notes: [FutureNote]
    @State private var showingComposer = false
    @State private var openedNote: FutureNote?

    var body: some View {
        List {
            ForEach(notes) { note in
                let unlocked = note.unlockDate <= .now
                Button {
                    if unlocked { openedNote = note }
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(unlocked ? "Unlocked" : "Locked until \(note.unlockDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                            Text("Written \(note.writtenAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: unlocked ? "lock.open" : "lock")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!unlocked)
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(notes[index]) }
            }

            Button("Write a note to future you") {
                showingComposer = true
            }
        }
        .navigationTitle("To future me")
        .sheet(isPresented: $showingComposer) {
            FutureNoteComposer()
        }
        .sheet(item: $openedNote) { note in
            NavigationStack {
                ScrollView {
                    Text(note.text).padding()
                }
                .navigationTitle("From \(note.writtenAt.formatted(date: .abbreviated, time: .omitted))")
            }
        }
    }
}

private struct FutureNoteComposer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var unlockDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                Section("Unlock on") {
                    DatePicker("", selection: $unlockDate, in: Date.now..., displayedComponents: .date)
                        .labelsHidden()
                }
                Section("Your note") {
                    TextEditor(text: $text).frame(minHeight: 200)
                }
            }
            .navigationTitle("New note")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        modelContext.insert(FutureNote(unlockDate: unlockDate, text: text))
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
