//
//  NextHourChecklistView.swift
//  Anchor
//
//  Was plain view @State — reset to empty on every launch (same bug class
//  as the old decision presets). Now a real SwiftData model (NextHourItem)
//  with a self-cleaning rule: anything older than a few hours is purged on
//  load, so this stays true to "just this hour" instead of turning into a
//  permanent, ever-growing to-do list.
//
//  Also now bridges to the real Reminders app via EventKit — "the function
//  of Next Hour Only is unclear, perhaps pull from Reminders" — rather
//  than a separate parallel to-do system. Importing pulls today's
//  incomplete reminders in; adding an item here can optionally also create
//  a real EKReminder, and checking it off here marks that reminder done
//  too.
//

import SwiftUI
import SwiftData
import EventKit

struct NextHourChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NextHourItem.createdAt) private var items: [NextHourItem]

    @State private var newItemText = ""
    @State private var alsoAddToReminders = false
    @State private var showReminderImporter = false
    @State private var importableReminders: [EKReminder] = []
    @State private var reminderAccessDenied = false

    private let eventStore = EKEventStore()

    /// Anything this old gets purged on load — "just this hour" is the
    /// promise, so a three-hour cushion (rather than a literal one) allows
    /// for a slow morning without ever becoming a permanent list.
    private static let staleAfter: TimeInterval = 3 * 3600

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Anchor.SectionHeader(icon: "hourglass", title: "Next hour only")
                Spacer()
                Button {
                    importFromReminders()
                } label: {
                    Image(systemName: "arrow.down.doc")
                        .font(.caption)
                        .foregroundStyle(Anchor.Theme.sage)
                }
                .accessibilityLabel("Import from Reminders")
            }
            Text("Just this hour. The rest of the day can wait, and this list clears itself. It isn't a permanent to-do list.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if items.isEmpty {
                Text("Nothing added yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            }

            ForEach(items) { item in
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) { item.isDone.toggle() }
                        syncCompletionToReminders(item)
                    } label: {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isDone ? Anchor.Theme.accent : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    Text(item.text)
                        .font(.system(.subheadline, design: .rounded))
                        .strikethrough(item.isDone)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                    Spacer()
                    if item.reminderIdentifier != nil {
                        Image(systemName: "checklist")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Add something small", text: $newItemText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    alsoAddToReminders.toggle()
                } label: {
                    Image(systemName: alsoAddToReminders ? "bell.fill" : "bell")
                        .foregroundStyle(alsoAddToReminders ? Anchor.Theme.accent : .secondary)
                }
                .accessibilityLabel("Also add to Reminders")

                Button("Add") { addItem() }
                    .buttonStyle(Anchor.SecondaryButtonStyle())
            }

            if reminderAccessDenied {
                Text("Reminders access is off. You can turn it on in Settings → Anchor.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { purgeStaleItems() }
        .confirmationDialog("Import which reminders?", isPresented: $showReminderImporter, titleVisibility: .visible) {
            ForEach(importableReminders, id: \.calendarItemIdentifier) { reminder in
                Button(reminder.title ?? "Untitled") {
                    modelContext.insert(NextHourItem(text: reminder.title ?? "Untitled", reminderIdentifier: reminder.calendarItemIdentifier))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if importableReminders.isEmpty {
                Text("No incomplete reminders found.")
            }
        }
    }

    private func purgeStaleItems() {
        let cutoff = Date().addingTimeInterval(-Self.staleAfter)
        for item in items where item.createdAt < cutoff {
            modelContext.delete(item)
        }
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newItemText = ""

        guard alsoAddToReminders else {
            modelContext.insert(NextHourItem(text: trimmed))
            return
        }

        requestRemindersAccessIfNeeded { granted in
            if granted {
                createReminder(title: trimmed) { identifier in
                    modelContext.insert(NextHourItem(text: trimmed, reminderIdentifier: identifier))
                }
            } else {
                reminderAccessDenied = true
                modelContext.insert(NextHourItem(text: trimmed))
            }
        }
    }

    private func requestRemindersAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        eventStore.requestFullAccessToReminders { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    private func createReminder(title: String, completion: @escaping (String?) -> Void) {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        do {
            try eventStore.save(reminder, commit: true)
            completion(reminder.calendarItemIdentifier)
        } catch {
            completion(nil)
        }
    }

    private func syncCompletionToReminders(_ item: NextHourItem) {
        guard let identifier = item.reminderIdentifier,
              let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        reminder.isCompleted = item.isDone
        try? eventStore.save(reminder, commit: true)
    }

    private func importFromReminders() {
        requestRemindersAccessIfNeeded { granted in
            guard granted else {
                reminderAccessDenied = true
                return
            }
            let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
            eventStore.fetchReminders(matching: predicate) { reminders in
                DispatchQueue.main.async {
                    importableReminders = Array((reminders ?? []).prefix(15))
                    showReminderImporter = true
                }
            }
        }
    }
}
