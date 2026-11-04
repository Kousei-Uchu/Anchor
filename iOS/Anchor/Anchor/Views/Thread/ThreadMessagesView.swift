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

import SwiftUI
import SwiftData
import MessageUI

struct ThreadMessagesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ThreadMessage.timestamp, order: .reverse) private var messages: [ThreadMessage]
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
        VStack(spacing: 0) {
            List {
                Section {
                    Text("Quick notes tied to a real contact. Sent right away if you want, or just saved as a log of what you've told them over time. For bigger things you might never send, that's \"Things I haven't said\" instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)

                ForEach(messages) { message in
                    VStack(alignment: .leading, spacing: 4) {
                        if let contactID = message.withContactID,
                           let contact = contacts.first(where: { $0.id == contactID }) {
                            Text(contact.name).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(message.text)
                        Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(messages[index]) }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                if !contacts.isEmpty {
                    Picker("About", selection: $selectedContactID) {
                        Text("No one in particular").tag(UUID?.none)
                        ForEach(contacts) { contact in
                            Text(contact.name).tag(Optional(contact.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                HStack {
                    TextField("Write something…", text: $newMessageText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button("Save privately") {
                        saveOnly()
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle())

                    if let contactID = selectedContactID, let contact = contacts.first(where: { $0.id == contactID }) {
                        switch contact.contactMethod {
                        case .phone:
                            Button("Save & send via Messages") {
                                saveOnly()
                                pendingMessage = PendingMessage(recipient: contact.phoneNumber, body: newMessageTrimmed)
                            }
                            .buttonStyle(Anchor.PrimaryButtonStyle())
                        case .discord:
                            Button("Save & open Discord") {
                                saveOnly()
                                DiscordOpener.openUser(contact.discordUserID) { message in
                                    discordFailureMessage = message
                                }
                            }
                            .buttonStyle(Anchor.PrimaryButtonStyle())
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Message log")
        .sheet(item: $pendingMessage) { message in
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
