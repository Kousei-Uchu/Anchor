//
//  ContactsEditorView.swift
//  Anchor
//
//  Nothing else in the app could create a TrustedContact until this
//  existed — Now's quick-contact row only ever displayed what was already
//  there. This is also where escalation opt-in lives, since it's a
//  per-contact, explicit choice per spec (never automatic).
//
//  Added per feedback: pick a contact straight from the system Contacts
//  app instead of typing everything by hand; a Discord option alongside
//  phone (needs their numeric user ID — Discord's URL scheme can't
//  resolve a DM from just a username); and optional timezone/availability
//  so "Who's awake" can tell you who's actually reachable right now.
//

import SwiftUI
import SwiftData
import ContactsUI

struct ContactsEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]
    @State private var editingContact: TrustedContact?
    @State private var showContactPicker = false

    var body: some View {
        List {
            Section {
                Text("Top 2 are shown as quick-contact buttons on Now. Reorder by dragging.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            if !contacts.isEmpty {
                NavigationLink { ContactAvailabilityView(contacts: contacts) } label: {
                    Anchor.MenuRow(icon: "sun.horizon.fill", title: "Who's awake right now", tint: Anchor.Theme.sage)
                }
            }

            ForEach(contacts) { contact in
                Button {
                    editingContact = contact
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.name).font(.headline)
                        Text(contact.contactMethod == .discord ? "Discord" : contact.phoneNumber)
                            .font(.caption).foregroundStyle(.secondary)
                        if contact.escalationEnabled, let minutes = contact.escalationWindowMinutes {
                            Text("Escalation: \(minutes) min").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onMove { offsets, destination in
                var reordered = contacts
                reordered.move(fromOffsets: offsets, toOffset: destination)
                for (index, contact) in reordered.enumerated() { contact.sortOrder = index }
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(contacts[index]) }
            }

            Section {
                Button {
                    showContactPicker = true
                } label: {
                    Label("Pick from Contacts", systemImage: "person.crop.circle.badge.plus")
                }
                Button("Add manually") {
                    let new = TrustedContact(name: "", phoneNumber: "", sortOrder: contacts.count)
                    modelContext.insert(new)
                    editingContact = new
                }
            }
        }
        .toolbar { EditButton() }
        .navigationTitle("Contacts")
        .sheet(item: $editingContact) { contact in
            ContactEditorSheet(contact: contact)
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerView { name, phoneNumber in
                let new = TrustedContact(name: name, phoneNumber: phoneNumber, sortOrder: contacts.count)
                modelContext.insert(new)
                editingContact = new
            }
        }
    }
}

/// Wraps the system contact picker — no usage-description/permission
/// prompt needed for this specific API, since it runs out-of-process as
/// Apple's own UI rather than the app directly reading the address book.
struct ContactPickerView: UIViewControllerRepresentable {
    let onPick: (String, String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        return picker
    }
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String, String) -> Void
        init(onPick: @escaping (String, String) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            onPick(name.isEmpty ? "Contact" : name, phone)
        }
    }
}

private struct ContactEditorSheet: View {
    @Bindable var contact: TrustedContact
    @Environment(\.dismiss) private var dismiss
    @State private var newTemplateLabel = ""
    @State private var newTemplateBody = ""

    /// A short, common list rather than all ~400 IANA identifiers — good
    /// enough for picking where someone lives without an unwieldy list.
    private static let commonTimeZones = [
        "Australia/Sydney", "Australia/Melbourne", "Australia/Brisbane", "Australia/Perth",
        "Australia/Adelaide", "Pacific/Auckland", "Asia/Tokyo", "Asia/Singapore",
        "Asia/Kolkata", "Europe/London", "Europe/Zagreb", "Europe/Berlin", "Europe/Paris",
        "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
        "UTC"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $contact.name)

                    Picker("Contact via", selection: $contact.contactMethod) {
                        Text("Phone").tag(ContactMethod.phone)
                        Text("Discord").tag(ContactMethod.discord)
                    }
                    .pickerStyle(.segmented)

                    if contact.contactMethod == .phone {
                        TextField("Phone number", text: $contact.phoneNumber)
                            .keyboardType(.phonePad)
                    } else {
                        TextField("Discord user ID", text: Binding(
                            get: { contact.discordUserID ?? "" },
                            set: { contact.discordUserID = $0 }
                        ))
                        .keyboardType(.numberPad)
                        Text("Their numeric ID, not username. In Discord, enable Developer Mode in Settings → Advanced, then \"Copy User ID\" from their profile.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Toggle("Escalate if I don't respond", isOn: $contact.escalationEnabled)
                    if contact.escalationEnabled {
                        Stepper(
                            "After \(contact.escalationWindowMinutes ?? 30) minutes",
                            value: Binding(
                                get: { contact.escalationWindowMinutes ?? 30 },
                                set: { contact.escalationWindowMinutes = $0 }
                            ),
                            in: 5...120, step: 5
                        )
                    }
                } footer: {
                    Text("Opt-in only. If enabled, a reminder to message \(contact.name.isEmpty ? "this contact" : contact.name) appears if a trigger-window check-in goes unanswered. Anchor never messages anyone automatically.")
                }

                Section("Message templates") {
                    ForEach(contact.messageTemplates) { template in
                        VStack(alignment: .leading) {
                            Text(template.label).font(.subheadline).bold()
                            Text(template.body).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        contact.messageTemplates.remove(atOffsets: offsets)
                    }

                    TextField("Label (e.g. \"Need to talk\")", text: $newTemplateLabel)
                    TextField("Message", text: $newTemplateBody)
                    Button("Add template") {
                        guard !newTemplateLabel.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        contact.messageTemplates.append(
                            MessageTemplate(label: newTemplateLabel, body: newTemplateBody, isCustom: true)
                        )
                        newTemplateLabel = ""
                        newTemplateBody = ""
                    }
                }

                Section {
                    Picker("Timezone", selection: Binding(
                        get: { contact.timeZoneIdentifier ?? "Not set" },
                        set: { contact.timeZoneIdentifier = $0 == "Not set" ? nil : $0 }
                    )) {
                        Text("Not set").tag("Not set")
                        ForEach(Self.commonTimeZones, id: \.self) { identifier in
                            Text(identifier.replacingOccurrences(of: "_", with: " ")).tag(identifier)
                        }
                    }

                    if contact.timeZoneIdentifier != nil {
                        Stepper(
                            "Wakes around \(String(format: "%02d:%02d", contact.availableFromHour ?? 8, contact.availableFromMinute ?? 0))",
                            value: Binding(
                                get: { contact.availableFromHour ?? 8 },
                                set: { contact.availableFromHour = $0 }
                            ), in: 0...23
                        )
                        Stepper(
                            "Sleeps around \(String(format: "%02d:%02d", contact.availableToHour ?? 22, contact.availableToMinute ?? 0))",
                            value: Binding(
                                get: { contact.availableToHour ?? 22 },
                                set: { contact.availableToHour = $0 }
                            ), in: 0...23
                        )
                    }
                } header: {
                    Text("Timezone & availability")
                } footer: {
                    Text("Optional. Powers \"Who's awake right now\" so you're not guessing across timezones.")
                }
            }
            .navigationTitle(contact.name.isEmpty ? "New contact" : contact.name)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// "Who's awake right now" — shows each contact's current local time and a
/// best-effort awake/asleep read based on the availability window they (or
/// the user, on their behalf) set, converted through their timezone.
/// Contacts with no timezone set are shown without a status rather than
/// guessed at.
struct ContactAvailabilityView: View {
    let contacts: [TrustedContact]

    var body: some View {
        List(contacts) { contact in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name).font(.system(.body, design: .rounded))
                    if let localTime = localTimeString(for: contact) {
                        Text(localTime).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No timezone set").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let awake = isLikelyAwake(contact) {
                    Label(awake ? "Awake" : "Asleep", systemImage: awake ? "sun.max.fill" : "moon.fill")
                        .font(.caption)
                        .foregroundStyle(awake ? Anchor.Theme.accent : .secondary)
                }
            }
        }
        .navigationTitle("Who's awake")
    }

    private func localTimeString(for contact: TrustedContact) -> String? {
        guard let identifier = contact.timeZoneIdentifier, let timeZone = TimeZone(identifier: identifier) else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = timeZone
        return formatter.string(from: .now)
    }

    private func isLikelyAwake(_ contact: TrustedContact) -> Bool? {
        guard let identifier = contact.timeZoneIdentifier, let timeZone = TimeZone(identifier: identifier),
              let fromHour = contact.availableFromHour, let toHour = contact.availableToHour else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let nowMinutes = calendar.component(.hour, from: .now) * 60 + calendar.component(.minute, from: .now)
        let fromMinutes = fromHour * 60 + (contact.availableFromMinute ?? 0)
        let toMinutes = toHour * 60 + (contact.availableToMinute ?? 0)
        if fromMinutes <= toMinutes {
            return (fromMinutes...toMinutes).contains(nowMinutes)
        } else {
            return nowMinutes >= fromMinutes || nowMinutes <= toMinutes
        }
    }
}
