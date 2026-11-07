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
    @Query(sort: \FutureNote.unlockDate) private var notes: [FutureNote]
    @State private var showingComposer = false
    @State private var showingEditor = false
    @State private var openedNote: FutureNote?

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
                            if unlocked { openedNote = note }
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
                        .disabled(!unlocked)
                    }
                    Button {
                        showingComposer = true
                    } label: {
                        Label("Write a note to future you", systemImage: "plus")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle())
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("To future me")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !notes.isEmpty {
                    Anchor.EditToolbarButton { showingEditor = true }
                }
            }
        }
        .sheet(isPresented: $showingComposer) {
            FutureNoteComposer()
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit notes") {
                FutureNotesManageView()
            }
        }
        .sheet(item: $openedNote) { note in
            NavigationStack {
                ScrollView {
                    Text(note.text).padding()
                }
                .anchorBackground()
                .navigationTitle("From \(note.writtenAt.formatted(date: .abbreviated, time: .omitted))")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

/// Delete notes. Presented from Edit. Locked notes show only their dates,
/// never their text, here as everywhere else.
private struct FutureNotesManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FutureNote.unlockDate) private var notes: [FutureNote]

    var body: some View {
        List {
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.unlockDate <= .now ? "Unlocked" : "Locked until \(note.unlockDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(.subheadline, design: .rounded))
                    Text("Written \(note.writtenAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(notes[index]) }
            }
        }
        .toolbar { EditButton() }
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
