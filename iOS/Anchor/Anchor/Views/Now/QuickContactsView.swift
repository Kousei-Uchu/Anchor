//
//  QuickContactsView.swift
//  Anchor
//
//  Routes through native Messages (MFMessageComposeViewController) rather
//  than any custom backend. Escalation ("if I don't respond in X minutes")
//  is opt-in per contact and configured in Plan — this view only sends.
//

import SwiftUI
import SwiftData
import MessageUI

struct QuickContactsView: View {
    let contacts: [TrustedContact]
    @Query(sort: \MessageStarter.sortOrder) private var starters: [MessageStarter]
    @State private var pendingMessage: PendingMessage?
    @State private var discordFailureMessage: String?
    @State private var selectedContactID: UUID?

    struct PendingMessage: Identifiable {
        let id = UUID()
        let recipient: String
        let body: String
    }

    private var topContacts: [TrustedContact] { Array(contacts.prefix(2)) }

    private var selectedContact: TrustedContact? {
        topContacts.first(where: { $0.id == selectedContactID }) ?? topContacts.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Anchor.SectionHeader(icon: "message.fill", title: "Quick contact")

            if topContacts.count > 1 {
                HStack(spacing: 8) {
                    ForEach(topContacts) { contact in
                        contactChip(contact)
                    }
                }
            }

            if let contact = selectedContact {
                let templates = contact.messageTemplates.isEmpty
                    ? [MessageTemplate(label: "Just checking in", body: "Hey, just wanted to check in.", isCustom: false)]
                    : contact.messageTemplates

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates) { template in
                            Button(template.label) {
                                send(template.body, to: contact)
                            }
                            .buttonStyle(Anchor.SecondaryButtonStyle())
                        }
                        ForEach(usableStarters) { starter in
                            Button(starter.text) {
                                send(starter.text, to: contact)
                            }
                            .lineLimit(1)
                            .buttonStyle(Anchor.SecondaryButtonStyle())
                            .frame(maxWidth: 260)
                        }
                    }
                }
            }
        }
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

    private var usableStarters: [MessageStarter] {
        starters.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func send(_ body: String, to contact: TrustedContact) {
        switch contact.contactMethod {
        case .phone:
            pendingMessage = PendingMessage(recipient: contact.phoneNumber, body: body)
        case .discord:
            DiscordOpener.openUser(contact.discordUserID) { message in
                discordFailureMessage = message
            }
        }
    }

    private func contactChip(_ contact: TrustedContact) -> some View {
        let isSelected = contact.id == (selectedContactID ?? topContacts.first?.id)
        return Button {
            selectedContactID = contact.id
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Anchor.Theme.accent : Anchor.Theme.accentSoft)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String(contact.name.prefix(1)))
                            .font(.caption2.bold())
                            .foregroundStyle(isSelected ? .white : Anchor.Theme.accent)
                    )
                Text(contact.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                if contact.contactMethod == .discord {
                    Image(systemName: "message.badge.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Anchor.Theme.accentSoft : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

/// Opens a Discord user by numeric ID — Discord's URL scheme can't
/// resolve a DM from a username alone. This may land on their profile
/// rather than straight into a DM, depending on the installed Discord
/// app's version and whether a DM channel already exists; tries the app
/// scheme first, falls back to the web profile if that fails.
enum DiscordOpener {
    static func openUser(_ userID: String?, onFailure: @escaping (String) -> Void) {
        guard let userID, !userID.trimmingCharacters(in: .whitespaces).isEmpty else {
            onFailure("No Discord user ID set for this contact yet. Add it in Plan → Contacts.")
            return
        }
        guard let primary = URL(string: "discord://-/users/\(userID)") else {
            onFailure("Couldn't build a Discord link from that ID.")
            return
        }
        UIApplication.shared.open(primary, options: [:]) { success in
            if success { return }
            guard let fallback = URL(string: "https://discord.com/users/\(userID)") else {
                onFailure("Couldn't open Discord.")
                return
            }
            UIApplication.shared.open(fallback, options: [:]) { fallbackSuccess in
                if !fallbackSuccess { onFailure("Couldn't open Discord.") }
            }
        }
    }
}

/// Thin UIKit bridge so sending goes through the real Messages app rather
/// than a custom messaging backend.
struct MessageComposeView: UIViewControllerRepresentable {
    let recipient: String
    let body: String
    var attachmentURL: URL? = nil

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = [recipient]
        controller.body = body
        if let attachmentURL, MFMessageComposeViewController.canSendAttachments() {
            controller.addAttachmentURL(attachmentURL, withAlternateFilename: "Voice note.m4a")
        }
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                           didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }
}
