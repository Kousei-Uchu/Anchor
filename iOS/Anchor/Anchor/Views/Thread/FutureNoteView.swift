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
    @State private var noteToDelete: FutureNote?

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if notes.isEmpty {
                    Anchor.EmptyState(
                        icon: "envelope.open.badge.clock",
                        title: "No notes to future you yet",
                        message: "Write something now and pick a date. It stays sealed until then.",
                        actionTitle: "Write a note",
                        tint: Anchor.Theme.sage
                    ) { showingComposer = true }
                } else {
                    ForEach(notes) { note in
                        let unlocked = note.unlockDate <= .now
                        Button {
                            openedNote = note
                        } label: {
                            Anchor.Card(accentColor: unlocked ? Anchor.Theme.accent : Anchor.Theme.sage) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(unlocked ? "Unlocked" : "Locked until \(note.unlockDate.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text("Written \(note.writtenAt.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: unlocked ? "lock.open" : "lock")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .anchorDeletable { modelContext.delete(note) }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("To future me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.AddToolbarButton(label: "New note") { showingComposer = true }
            }
        }
        .sheet(isPresented: $showingComposer) {
            FutureNoteComposer()
        }
        .sheet(item: $openedNote, onDismiss: finishViewing) { note in
            FutureNoteSheet(note: note) { noteToDelete = note }
        }
    }

    /// Deleting waits until the sheet has closed, so the sheet never reads
    /// a note that is already gone.
    private func finishViewing() {
        if let note = noteToDelete {
            modelContext.delete(note)
            noteToDelete = nil
        }
    }
}

/// One note. A locked note shows only its date, never its text, here as
/// everywhere else. Delete works on locked and unlocked notes alike.
private struct FutureNoteSheet: View {
    let note: FutureNote
    let onDelete: () -> Void

    var body: some View {
        let unlocked = note.unlockDate <= .now
        Anchor.ItemEditorSheet(
            title: "From \(note.writtenAt.formatted(date: .abbreviated, time: .omitted))",
            onDelete: onDelete,
            deleteQuestion: "Delete this note?"
        ) {
            Form {
                Section {
                    if unlocked {
                        Text(note.text)
                    } else {
                        Text("This note stays sealed until \(note.unlockDate.formatted(date: .abbreviated, time: .omitted)).")
                            .foregroundStyle(.secondary)
                    }
                }
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
            .anchorSettingsStyle()
            .navigationTitle("New note")
            .navigationBarTitleDisplayMode(.inline)
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
