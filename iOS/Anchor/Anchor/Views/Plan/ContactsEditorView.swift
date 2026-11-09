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
//  Editing follows the app-wide pattern: tap a person to edit them, the plus
//  adds someone, and Delete is in the editor and in the long-press menu.
//  Order matters here (the top two are the quick buttons on Now), so there is
//  a labelled Reorder button.
//

import SwiftUI
import SwiftData
import ContactsUI

/// Contacts as cards. Tap one to change it, use the plus to add someone, and
/// use Reorder to change who is on Now.
struct ContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]
    @State private var editingContact: TrustedContact?
    @State private var contactToDelete: TrustedContact?
    @State private var showContactPicker = false
    @State private var pickedContact: (name: String, phone: String)?
    @State private var showingAvailability = false

    var body: some View {
        Group {
            if contacts.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "person.2.fill",
                        title: "No one here yet",
                        message: "Add the people you'd want to reach in a hard moment. The first two show up as quick buttons on Now.",
                        actionTitle: "Add someone",
                        tint: Anchor.Theme.accent
                    ) { addManually() }
                    .padding()
                }
            } else {
                List {
                    Button {
                        showingAvailability = true
                    } label: {
                        Anchor.Card(accentColor: Anchor.Theme.sage) {
                            HStack {
                                Anchor.MenuRow(icon: "sun.horizon.fill", title: "Who's awake right now",
                                               subtitle: "Local times for people in other timezones",
                                               tint: Anchor.Theme.sage)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .anchorCardRow()

                    ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                        Button {
                            editingContact = contact
                        } label: {
                            ContactCard(contact: contact, isQuickContact: index < 2)
                        }
                        .buttonStyle(.plain)
                        .anchorDeletable { remove(contact) }
                        .anchorCardRow()
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Contacts")
        .guideButton("plan.contacts", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingAvailability) {
            ContactAvailabilityView(contacts: contacts)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if contacts.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Menu {
                    Button {
                        showContactPicker = true
                    } label: {
                        Label("Pick from Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                    Button {
                        addManually()
                    } label: {
                        Label("Add manually", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add someone")
            }
        }
        .sheet(item: $editingContact, onDismiss: finishEditing) { contact in
            ContactEditorSheet(contact: contact) { contactToDelete = contact }
        }
        .sheet(isPresented: $showContactPicker, onDismiss: openPickedContact) {
            ContactPickerView { name, phoneNumber in
                pickedContact = (name, phoneNumber)
            }
        }
    }

    private func addManually() {
        let new = TrustedContact(name: "", phoneNumber: "", sortOrder: contacts.count)
        modelContext.insert(new)
        editingContact = new
    }

    /// Runs when the system picker has closed, so the editor never opens on
    /// top of a picker that is still leaving.
    private func openPickedContact() {
        guard let picked = pickedContact else { return }
        pickedContact = nil
        let new = TrustedContact(name: picked.name, phoneNumber: picked.phone, sortOrder: contacts.count)
        modelContext.insert(new)
        editingContact = new
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = contacts
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, contact) in reordered.enumerated() { contact.sortOrder = index }
    }

    /// Runs once the editor has closed. Deleting here, not while the editor
    /// is still on screen, keeps the editor from reading a contact that is
    /// already gone. Someone added and then left completely blank is dropped.
    private func finishEditing() {
        let deleting = contactToDelete
        contactToDelete = nil
        if let deleting { remove(deleting) }
        for contact in contacts where contact !== deleting && isBlank(contact) {
            remove(contact)
        }
        HelloReminders.refresh(contacts: contacts.filter { $0 !== deleting && !isBlank($0) }, using: modelContext)
    }

    /// Deleting a person also removes the page of notes kept about them.
    private func remove(_ contact: TrustedContact) {
        PersonSection.removeAll(for: contact.id, in: modelContext)
        modelContext.delete(contact)
    }

    private func isBlank(_ contact: TrustedContact) -> Bool {
        contact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && contact.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (contact.discordUserID ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ContactCard: View {
    let contact: TrustedContact
    let isQuickContact: Bool

    var body: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(contact.name.isEmpty ? "Unnamed" : contact.name)
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    if isQuickContact {
                        Label("On Now", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundStyle(Anchor.Theme.sage)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(contact.contactMethod == .discord ? "Discord" : contact.phoneNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if contact.escalationEnabled, let minutes = contact.escalationWindowMinutes {
                    Label("Reminder to reach out after \(minutes) min", systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(Anchor.Theme.accent)
                }
                if !contact.messageTemplates.isEmpty {
                    Text("\(contact.messageTemplates.count) message template\(contact.messageTemplates.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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
    let onDelete: () -> Void
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
        Anchor.ItemEditorSheet(
            title: contact.name.isEmpty ? "New contact" : contact.name,
            onDelete: onDelete,
            deleteQuestion: "Delete this contact?"
        ) {
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
                        .onChange(of: contact.escalationEnabled) { _, isOn in
                            if isOn { NotificationScheduler.askForPermissionIfNeeded() }
                        }
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
