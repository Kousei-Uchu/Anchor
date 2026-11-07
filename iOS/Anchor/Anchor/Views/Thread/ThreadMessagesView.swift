//
//  ThreadMessagesView.swift
//  Anchor
//
//  The message log is tied to a real TrustedContact and can actually send
//  (via Messages or Discord). "Things I haven't said" (UnsentDraftsView) is
//  the other one: a free-text label, never sent, for bigger things.
//
//  Two jobs, both on this screen:
//  - Quick sending: a "Write to" row at the top opens the composer already
//    pointed at that person, so it is one tap from the log to writing.
//  - Per-person history: the log can be narrowed to one person.
//
//  The text of a logged message is not editable, since it is a record of
//  what was said. Tapping one opens it, with Send again, Copy and Delete.
//

import SwiftUI
import SwiftData
import MessageUI

// MARK: - The log

/// Names the person the composer should start with, if any.
struct MessageComposerRequest: Identifiable {
    let id = UUID()
    var contactID: UUID?
}

struct ThreadMessagesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ThreadMessage.timestamp, order: .reverse) private var messages: [ThreadMessage]
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]

    @State private var composerRequest: MessageComposerRequest?
    @State private var openedMessage: ThreadMessage?
    @State private var messageToDelete: ThreadMessage?
    @State private var filterContactID: UUID?

    private var shownMessages: [ThreadMessage] {
        guard let filterContactID else { return messages }
        return messages.filter { $0.withContactID == filterContactID }
    }

    /// Only people who actually have something in the log are offered as a filter.
    private var contactsWithMessages: [TrustedContact] {
        let ids = Set(messages.compactMap(\.withContactID))
        return contacts.filter { ids.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                Text("Quick notes tied to a real contact. Sent right away if you want, or just saved as a log of what you've told them over time. For bigger things you might never send, that's \"Things I haven't said\" instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !contacts.isEmpty {
                    writeToRow
                }

                if messages.isEmpty {
                    Anchor.EmptyState(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "No messages yet",
                        message: "Write a quick note to someone, or just save it privately as a record of what you've told them.",
                        actionTitle: "Write something",
                        tint: Anchor.Theme.accent
                    ) { composerRequest = MessageComposerRequest() }
                } else {
                    if contactsWithMessages.count > 0 {
                        filterMenu
                    }
                    if shownMessages.isEmpty {
                        Text("Nothing here yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(shownMessages) { message in
                        messageCard(message)
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
                Anchor.AddToolbarButton(label: "Write something") {
                    composerRequest = MessageComposerRequest(contactID: filterContactID)
                }
            }
        }
        .sheet(item: $composerRequest) { request in
            ThreadMessageComposer(startingContactID: request.contactID)
        }
        .sheet(item: $openedMessage, onDismiss: finishViewing) { message in
            ThreadMessageSheet(message: message, contact: contact(for: message)) {
                messageToDelete = message
            }
        }
    }

    /// One tap from the log to writing to a particular person.
    private var writeToRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Write to")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(contacts) { contact in
                        Button {
                            composerRequest = MessageComposerRequest(contactID: contact.id)
                        } label: {
                            Label(contact.name, systemImage: "square.and.pencil")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Anchor.Theme.accentSoft))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Anchor.Theme.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterMenu: some View {
        HStack {
            Menu {
                Picker("Show", selection: $filterContactID) {
                    Text("Everyone").tag(UUID?.none)
                    ForEach(contactsWithMessages) { contact in
                        Text(contact.name).tag(Optional(contact.id))
                    }
                }
            } label: {
                Label(
                    filterContactID.flatMap { id in contacts.first(where: { $0.id == id })?.name } ?? "Everyone",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .font(.system(.subheadline, design: .rounded).weight(.medium))
            }
            Spacer()
        }
    }

    private func messageCard(_ message: ThreadMessage) -> some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    openedMessage = message
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = contact(for: message)?.name {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !message.text.isEmpty {
                                Text(message.text)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func contact(for message: ThreadMessage) -> TrustedContact? {
        guard let contactID = message.withContactID else { return nil }
        return contacts.first(where: { $0.id == contactID })
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

// MARK: - One message

private struct SendRequest: Identifiable {
    let id = UUID()
    let recipient: String
    let body: String
}

/// One logged message, with Send again, Copy and Delete.
private struct ThreadMessageSheet: View {
    let message: ThreadMessage
    let contact: TrustedContact?
    let onDelete: () -> Void

    @State private var sendRequest: SendRequest?
    @State private var discordFailureMessage: String?
    @State private var copied = false

    var body: some View {
        Anchor.ItemEditorSheet(title: "Message", onDelete: onDelete, deleteQuestion: "Delete this message?") {
            Form {
                if let contact {
                    Section("About") { Text(contact.name) }
                }
                if !message.text.isEmpty {
                    Section("Message") { Text(message.text) }
                }
                Section("Written") {
                    Text(message.timestamp.formatted(date: .complete, time: .shortened))
                }
                Section {
                    if let contact {
                        switch contact.contactMethod {
                        case .phone:
                            Button("Send again via Messages") {
                                sendRequest = SendRequest(recipient: contact.phoneNumber, body: message.text)
                            }
                        case .discord:
                            Button("Open Discord") {
                                DiscordOpener.openUser(contact.discordUserID) { discordFailureMessage = $0 }
                            }
                        }
                    }
                    if !message.text.isEmpty {
                        Button(copied ? "Copied" : "Copy text") {
                            UIPasteboard.general.string = message.text
                            copied = true
                        }
                    }
                }
            }
            .sheet(item: $sendRequest) { request in
                if MFMessageComposeViewController.canSendText() {
                    MessageComposeView(recipient: request.recipient, body: request.body)
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
}

// MARK: - Writing

/// Compose a new log entry: pick who it's about, write it, then either
/// save it privately or save and send.
struct ThreadMessageComposer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]

    @FocusState private var textFocused: Bool

    @State private var newMessageText = ""
    @State private var selectedContactID: UUID?
    @State private var sendRequest: SendRequest?
    @State private var discordFailureMessage: String?

    init(startingContactID: UUID? = nil) {
        _selectedContactID = State(initialValue: startingContactID)
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
                        .focused($textFocused)
                }

                Section {
                    Button("Save privately") {
                        _ = saveOnly()
                        dismiss()
                    }
                    .disabled(!canSave)

                    if let contactID = selectedContactID, let contact = contacts.first(where: { $0.id == contactID }) {
                        switch contact.contactMethod {
                        case .phone:
                            Button("Save & send via Messages") {
                                let body = newMessageTrimmed
                                _ = saveOnly()
                                sendRequest = SendRequest(recipient: contact.phoneNumber, body: body)
                            }
                            .disabled(!canSave)
                        case .discord:
                            Button("Save & open Discord") {
                                _ = saveOnly()
                                DiscordOpener.openUser(contact.discordUserID) { message in
                                    discordFailureMessage = message
                                }
                            }
                            .disabled(!canSave)
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
            .onAppear { textFocused = true }
            .sheet(item: $sendRequest, onDismiss: { dismiss() }) { request in
                if MFMessageComposeViewController.canSendText() {
                    MessageComposeView(recipient: request.recipient, body: request.body)
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

    private var canSave: Bool {
        !newMessageTrimmed.isEmpty
    }

    private var newMessageTrimmed: String {
        newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    private func saveOnly() -> Bool {
        let trimmed = newMessageTrimmed
        guard !trimmed.isEmpty else { return false }
        modelContext.insert(ThreadMessage(text: trimmed, withContactID: selectedContactID))
        newMessageText = ""
        return true
    }
}
