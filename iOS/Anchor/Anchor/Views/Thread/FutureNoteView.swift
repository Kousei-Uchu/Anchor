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

    private var datedNotes: [FutureNote] { notes.filter { !$0.isOpenWhenLetter } }
    private var letters: [FutureNote] {
        notes.filter { $0.isOpenWhenLetter }.sorted { $0.writtenAt > $1.writtenAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if notes.isEmpty {
                    Anchor.EmptyState(
                        icon: "envelope.open.badge.clock",
                        title: "No notes to future you yet",
                        message: "Write something now and pick a date. It stays sealed until then. Or write a letter to open when you choose.",
                        actionTitle: "Write a note",
                        tint: Anchor.Theme.sage
                    ) { showingComposer = true }
                } else {
                    ForEach(datedNotes) { note in
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

                    if !letters.isEmpty {
                        Text("Letters to open when you choose")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, datedNotes.isEmpty ? 0 : 8)
                        ForEach(letters) { letter in
                            Button {
                                openedNote = letter
                            } label: {
                                Anchor.Card(accentColor: Anchor.Theme.sage) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Open when \(letter.openWhen)")
                                                .font(.system(.headline, design: .rounded))
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                            Text("Written \(letter.writtenAt.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "envelope")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .anchorDeletable { modelContext.delete(letter) }
                        }
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
    /// A letter stays closed until the person taps Open, so it is never read
    /// by accident. It closes again each time the sheet is shown.
    @State private var letterOpened = false

    var body: some View {
        let unlocked = note.unlockDate <= .now
        Anchor.ItemEditorSheet(
            title: "From \(note.writtenAt.formatted(date: .abbreviated, time: .omitted))",
            onDelete: onDelete,
            deleteQuestion: "Delete this note?"
        ) {
            Form {
                Section {
                    if note.isOpenWhenLetter {
                        if letterOpened {
                            Text(note.text)
                        } else {
                            Text("Open when \(note.openWhen)")
                                .foregroundStyle(.secondary)
                            Button("Open this letter") { letterOpened = true }
                        }
                    } else if unlocked {
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
    private enum Kind: String, CaseIterable, Identifiable {
        case date = "On a date"
        case letter = "When I choose"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .date
    @State private var text = ""
    @State private var openWhen = ""
    @State private var unlockDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now

    private var canSave: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTitle = !openWhen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText && (kind == .date || hasTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Opens", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                if kind == .date {
                    Section("Unlock on") {
                        DatePicker("", selection: $unlockDate, in: Date.now..., displayedComponents: .date)
                            .labelsHidden()
                    }
                } else {
                    Section("Open when") {
                        TextField("it is a hard night", text: $openWhen)
                    }
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
                        if kind == .date {
                            modelContext.insert(FutureNote(unlockDate: unlockDate, text: text))
                        } else {
                            modelContext.insert(FutureNote(
                                unlockDate: .now,
                                text: text,
                                openWhen: openWhen.trimmingCharacters(in: .whitespacesAndNewlines)
                            ))
                        }
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
