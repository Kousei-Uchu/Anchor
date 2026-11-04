//
//  WidgetActionConfirmationView.swift
//  Anchor
//
//  Per feedback, widget taps weren't reliably performing actions (calling,
//  etc.) directly from widget content. Widgets are a genuinely constrained
//  surface — multiple Link/Button tap targets in the same widget view are
//  a known source of exactly this kind of "sometimes works, can't explain
//  why" unreliability. So widgets themselves no longer try to perform
//  actions at all: every widget tap now just opens the app via a single
//  `.widgetURL` per widget, and the actual action (dialing, etc.) happens
//  from a real screen inside the app, where a real SwiftUI Button behaves
//  exactly as expected — no widget-rendering ambiguity involved.
//

import SwiftUI
import SwiftData

enum WidgetAction: Identifiable {
    case call
    var id: Self { self }
}

struct WidgetActionConfirmationView: View {
    let action: WidgetAction
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]

    var body: some View {
        NavigationStack {
            switch action {
            case .call:
                callConfirmation
            }
        }
    }

    @ViewBuilder
    private var callConfirmation: some View {
        if let contact = contacts.first {
            VStack(spacing: 20) {
                Spacer()
                MascotCharacterView(mood: .neutral)
                    .frame(width: 72, height: 72)
                Text("Call \(contact.name)?")
                    .font(.system(.title3, design: .rounded).weight(.semibold))

                switch contact.contactMethod {
                case .phone:
                    Button {
                        callContact(contact)
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                    }
                    .buttonStyle(Anchor.PrimaryButtonStyle())
                    .padding(.horizontal, 60)
                case .discord:
                    Button {
                        DiscordOpener.openUser(contact.discordUserID) { _ in }
                        dismiss()
                    } label: {
                        Label("Open Discord", systemImage: "message.fill")
                    }
                    .buttonStyle(Anchor.PrimaryButtonStyle())
                    .padding(.horizontal, 60)
                }

                Button("Not right now") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .anchorBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        } else {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(Anchor.Theme.accent)
                Text("No contact set up yet")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Button("Add one in Plan") {
                    dismiss()
                    // A brief delay so the sheet finishes dismissing before
                    // ContentView's own URL handling switches tabs — avoids
                    // fighting two navigation changes in the same instant.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: .anchorOpenContactsInPlan, object: nil)
                    }
                }
                .buttonStyle(Anchor.PrimaryButtonStyle())
                .padding(.horizontal, 60)
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .anchorBackground()
        }
    }

    private func callContact(_ contact: TrustedContact) {
        guard let url = URL(string: "tel:\(contact.dialableNumber)") else {
            dismiss()
            return
        }
        UIApplication.shared.open(url)
        dismiss()
    }
}

extension Notification.Name {
    static let anchorOpenContactsInPlan = Notification.Name("anchorOpenContactsInPlan")
}
