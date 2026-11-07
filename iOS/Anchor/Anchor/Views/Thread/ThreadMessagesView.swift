//
//  ThreadMessagesView.swift
//  Anchor
//
//  Renamed from "Async check-ins" to "Message log" — the real confusion
//  wasn't the feature itself, it was that it sat right next to "Things I
//  haven't said" (UnsentDraftsView) sounding like the same thing. They're
//  not: this one is tied to a real TrustedContact and can actually send
//  (via Messages or Discord); that one uses a free-text label, never
//  sends anything itself, and is for bigger things that might never go
//  anywhere. The header text below spells out that contrast directly.
//
//  The log is a read screen. Writing a message is its own compose sheet
//  (`ThreadMessageComposer`), opened by the plus. Tapping a message opens it
//  with a Delete button; swipe-style delete is also in the long-press menu.
//  The text of a logged message is not editable, since it is a record of
//  what was said.
//

import SwiftUI
import SwiftData
import MessageUI

struct ThreadMessagesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ThreadMessage.timestamp, order: .reverse) private var messages: [ThreadMessage]
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]

    @State private var showingComposer = false
    @State private var openedMessage: ThreadMessage?
    @State private var messageToDelete: ThreadMessage?

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                Text("Quick notes tied to a real contact. Sent right away if you want, or just saved as a log of what you've told them over time. For bigger things you might never send, that's \"Things I haven't said\" instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if messages.isEmpty {
                    Anchor.EmptyState(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "No messages yet",
                        message: "Write a quick note to someone, or just save it privately as a record of what you've told them.",
                        actionTitle: "Write something",
                        tint: Anchor.Theme.accent
                    ) { showingComposer = true }
                } else {
                    ForEach(messages) { message in
                        Button {
                            openedMessage = message
                        } label: {
                            Anchor.Card {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let name = contactName(for: message) {
                                            Text(name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(message.text)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .anchorDeletable { modelContext.delete(message) }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Message log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.AddToolbarButton(label: "Write something") { showingComposer = true }
            }
        }
        .sheet(isPresented: $showingComposer) {
            ThreadMessageComposer()
        }
        .sheet(item: $openedMessage, onDismiss: finishViewing) { message in
            ThreadMessageSheet(message: message, contactName: contactName(for: message)) {
                messageToDelete = message
            }
        }
    }

    private func contactName(for message: ThreadMessage) -> String? {
        guard let contactID = message.withContactID else { return nil }
        return contacts.first(where: { $0.id == contactID })?.name
    }

    /// Deleting waits until the sheet has closed, so the sheet never reads
    /// a message that is already gone.
    private func finishViewing() {
        if let message = messageToDelete {
            modelContext.delete(message)
            messageToDelete = nil
        }
    }
}

/// One logged message, with a Delete button.
private struct ThreadMessageSheet: View {
    let message: ThreadMessage
    let contactName: String?
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(title: "Message", onDelete: onDelete, deleteQuestion: "Delete this message?") {
            Form {
                if let contactName {
                    Section("About") { Text(contactName) }
                }
                Section("Message") { Text(message.text) }
                Section("Written") {
                    Text(message.timestamp.formatted(date: .complete, time: .shortened))
                }
            }
        }
    }
}

/// Compose a new log entry: pick who it's about, write it, then either save
/// it privately or save and send. Creating something new, so it's its own flow.
private struct ThreadMessageComposer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]

    @State private var newMessageText = ""
    @State private var selectedContactID: UUID?
    @State private var pendingMessage: PendingMessage?
    @State private var discordFailureMessage: String?

    struct PendingMessage: Identifiable {
        let id = UUID()
        let recipient: String
        let body: String
    }

    var body: some View {
        NavigationStack {
            Form {
                if !contacts.isEmpty {
                    Section("About") {
                        Picker("About", selection: $selectedContactID) {
                            Text("No one in particular").tag(UUID?.none)
                            ForEach(contacts) { contact in
                                Text(contact.name).tag(Optional(contact.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Message") {
                    TextField("Write something…", text: $newMessageText, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section {
                    Button("Save privately") {
                        saveOnly()
                        dismiss()
                    }
                    .disabled(newMessageTrimmed.isEmpty)

                    if let contactID = selectedContactID, let contact = contacts.first(where: { $0.id == contactID }) {
                        switch contact.contactMethod {
                        case .phone:
                            Button("Save & send via Messages") {
                                let body = newMessageTrimmed
                                saveOnly()
                                pendingMessage = PendingMessage(recipient: contact.phoneNumber, body: body)
                            }
                            .disabled(newMessageTrimmed.isEmpty)
                        case .discord:
                            Button("Save & open Discord") {
                                saveOnly()
                                DiscordOpener.openUser(contact.discordUserID) { message in
                                    discordFailureMessage = message
                                }
                            }
                            .disabled(newMessageTrimmed.isEmpty)
                        }
                    }
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Write something")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $pendingMessage, onDismiss: { dismiss() }) { message in
                if MFMessageComposeViewController.canSendText() {
                    MessageComposeView(recipient: message.recipient, body: message.body)
                } else {
                    Text("This device can't send text messages.")
                        .padding()
                }
            }
            .alert("Couldn't open Discord", isPresented: Binding(
                get: { discordFailureMessage != nil },
                set: { if !$0 { discordFailureMessage = nil } }
            )) {
                Button("OK", role: .cancel) { discordFailureMessage = nil }
            } message: {
                Text(discordFailureMessage ?? "")
            }
        }
    }

    private var newMessageTrimmed: String {
        newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveOnly() {
        let trimmed = newMessageTrimmed
        guard !trimmed.isEmpty else { return }
        modelContext.insert(ThreadMessage(text: trimmed, withContactID: selectedContactID))
        newMessageText = ""
    }
}
