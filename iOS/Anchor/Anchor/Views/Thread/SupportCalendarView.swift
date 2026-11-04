//
//  SupportCalendarView.swift
//  Anchor
//
//  "Visible to" is an explicit opt-in list per entry, never "everyone" by
//  default — matches Thread's spec of only the people the user chooses.
//  This app is local-first with no required backend, so "visible to"
//  previously had no actual effect — nothing was ever shared anywhere, it
//  was just a tag. Now "Share with…" generates a real .ics calendar file
//  (the standard format every calendar app reads — Apple Calendar, Google
//  Calendar, Outlook) containing only that contact's visible entries, sent
//  through the normal share sheet (AirDrop, Messages, email, whatever). The
//  recipient never needs to install Anchor.
//

import SwiftUI
import SwiftData

struct SupportCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SupportCalendarEntry.date) private var entries: [SupportCalendarEntry]
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]
    @State private var editingEntry: SupportCalendarEntry?
    @State private var icsShareURL: IdentifiableURL?
    @State private var noVisibleEntriesMessage: String?

    var body: some View {
        List {
            if !contacts.isEmpty {
                Section {
                    Menu {
                        ForEach(contacts) { contact in
                            Button(contact.name) { shareCalendar(with: contact) }
                        }
                    } label: {
                        Anchor.MenuRow(icon: "square.and.arrow.up", title: "Share with…",
                                       subtitle: "Sends a real calendar file, they don't need Anchor", tint: Anchor.Theme.accent)
                    }
                }
            }

            ForEach(entries) { entry in
                Button {
                    editingEntry = entry
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                        Text(entry.note).foregroundStyle(.secondary)
                        if !entry.visibleToContactIDs.isEmpty {
                            Text("Visible to: " + visibleNames(entry))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(entries[index]) }
            }

            Button("Add extra-support day") {
                let new = SupportCalendarEntry(date: .now, note: "")
                modelContext.insert(new)
                editingEntry = new
            }
        }
        .navigationTitle("Support calendar")
        .sheet(item: $editingEntry) { entry in
            SupportCalendarEntryEditor(entry: entry, contacts: contacts)
        }
        .sheet(item: $icsShareURL) { wrapped in
            ShareSheet(activityItems: [wrapped.url])
        }
        .alert("Nothing to share", isPresented: Binding(
            get: { noVisibleEntriesMessage != nil },
            set: { if !$0 { noVisibleEntriesMessage = nil } }
        )) {
            Button("OK", role: .cancel) { noVisibleEntriesMessage = nil }
        } message: {
            Text(noVisibleEntriesMessage ?? "")
        }
    }

    private func visibleNames(_ entry: SupportCalendarEntry) -> String {
        contacts.filter { entry.visibleToContactIDs.contains($0.id) }
            .map(\.name)
            .joined(separator: ", ")
    }

    private func shareCalendar(with contact: TrustedContact) {
        let visibleEntries = entries.filter { $0.visibleToContactIDs.contains(contact.id) }
        guard !visibleEntries.isEmpty else {
            noVisibleEntriesMessage = "No entries are marked visible to \(contact.name) yet. Toggle that on for an entry first."
            return
        }
        let ics = generateICS(for: visibleEntries)
        guard let data = ics.data(using: .utf8) else { return }
        let safeName = contact.name.isEmpty ? "contact" : contact.name.replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("anchor-support-days-\(safeName).ics")
        do {
            try data.write(to: url)
            icsShareURL = IdentifiableURL(url: url)
        } catch {
            noVisibleEntriesMessage = "Couldn't create the calendar file."
        }
    }

    /// Plain-text .ics generation — no EventKit dependency needed since
    /// this never touches the user's own calendar, it's just building a
    /// file for someone else to import into theirs.
    private func generateICS(for visibleEntries: [SupportCalendarEntry]) -> String {
        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Anchor//Support Calendar//EN", "CALSCALE:GREGORIAN"]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let stampFormatter = ISO8601DateFormatter()
        stampFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]

        for entry in visibleEntries {
            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(entry.id.uuidString)@anchor")
            lines.append("DTSTAMP:\(stampFormatter.string(from: .now).replacingOccurrences(of: "-", with: "").replacingOccurrences(of: ":", with: ""))")
            lines.append("DTSTART;VALUE=DATE:\(dateFormatter.string(from: entry.date))")
            lines.append("SUMMARY:Extra support day")
            if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let escaped = entry.note
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: ",", with: "\\,")
                    .replacingOccurrences(of: "\n", with: "\\n")
                lines.append("DESCRIPTION:\(escaped)")
            }
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n")
    }
}

private struct SupportCalendarEntryEditor: View {
    @Bindable var entry: SupportCalendarEntry
    let contacts: [TrustedContact]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                TextField("Note", text: $entry.note, axis: .vertical)

                Section("Visible to") {
                    if contacts.isEmpty {
                        Text("Add contacts in Plan first.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(contacts) { contact in
                        Toggle(contact.name, isOn: Binding(
                            get: { entry.visibleToContactIDs.contains(contact.id) },
                            set: { isOn in
                                if isOn {
                                    if !entry.visibleToContactIDs.contains(contact.id) {
                                        entry.visibleToContactIDs.append(contact.id)
                                    }
                                } else {
                                    entry.visibleToContactIDs.removeAll { $0 == contact.id }
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Support day")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
