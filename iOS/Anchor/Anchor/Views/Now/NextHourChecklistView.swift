//
//  NextHourChecklistView.swift
//  Anchor
//
//  The task list. This file used to hold the self-clearing "Next hour only"
//  checklist and keeps its name so the Xcode project needs no change; it now
//  holds the tasks card on Now, the full Tasks screen (the Plan widget opens
//  it) and the optional import from the Reminders app.
//
//  Tasks last until you remove them. Old "Next hour only" rows were copied
//  across once by `TaskMigration`.
//

import SwiftUI
import SwiftData
import EventKit

// MARK: - Reminders (optional import)

/// A thin wrapper around EventKit. Anchor only reads the reminders you choose
/// to import, and ticks them off in Reminders when you tick the matching task.
enum RemindersBridge {
    private static let store = EKEventStore()

    static func requestAccess(_ completion: @escaping (Bool) -> Void) {
        store.requestFullAccessToReminders { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func incompleteReminders(_ completion: @escaping ([ImportableReminder]) -> Void) {
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { reminders in
            let found = (reminders ?? []).prefix(15).map {
                ImportableReminder(id: $0.calendarItemIdentifier, title: $0.title ?? "Untitled")
            }
            DispatchQueue.main.async { completion(Array(found)) }
        }
    }

    static func setCompleted(_ done: Bool, identifier: String) {
        guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        reminder.isCompleted = done
        try? store.save(reminder, commit: true)
    }
}

struct ImportableReminder: Identifiable {
    let id: String
    let title: String
}

/// Ticks a task off (or back on) and keeps a linked reminder in step.
private func setTask(_ task: TaskItem, done: Bool, among tasks: [TaskItem]) {
    task.setDone(done)
    if !done {
        // Back on the list: put it at the end of the open tasks.
        task.sortOrder = (tasks.map(\.sortOrder).max() ?? 0) + 1
    }
    if let identifier = task.reminderIdentifier {
        RemindersBridge.setCompleted(done, identifier: identifier)
    }
}

// MARK: - Tasks card on Now

/// The first few open tasks, with a quick add. The header opens the full list.
struct TasksNowCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @State private var newTitle = ""

    private var open: [TaskItem] { tasks.filter { !$0.isDone } }
    private let shown = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                TasksView()
            } label: {
                HStack {
                    Anchor.SectionHeader(icon: "checkmark.circle.fill", title: "Tasks")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open.isEmpty {
                Text(tasks.isEmpty ? "Nothing added yet." : "All ticked off.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            }

            ForEach(open.prefix(shown)) { task in
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.snappy) { setTask(task, done: true, among: tasks) }
                    } label: {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark \(task.title) as done")
                    Text(task.title)
                        .font(.system(.subheadline, design: .rounded))
                    Spacer()
                }
            }

            if open.count > shown {
                Text("and \(open.count - shown) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("Add something small", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTask)
                Button("Add", action: addTask)
                    .buttonStyle(Anchor.SecondaryButtonStyle())
            }
        }
    }

    private func addTask() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newTitle = ""
        modelContext.insert(TaskItem(title: trimmed, sortOrder: (tasks.map(\.sortOrder).max() ?? -1) + 1))
    }
}

// MARK: - Tasks screen

/// The full list. Tap a task to edit it, the plus adds one with room for
/// notes, the bar at the bottom adds a title in one go, and Delete is in the
/// editor and in the swipe and long-press menu. Reorder is labelled because
/// the order is yours to set.
struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @State private var editing: TaskItem?
    @State private var toDelete: TaskItem?
    @State private var newTitle = ""
    @State private var importable: [ImportableReminder] = []
    @State private var showImporter = false
    @State private var remindersDenied = false
    @State private var confirmingClearDone = false

    private var open: [TaskItem] { tasks.filter { !$0.isDone } }
    private var done: [TaskItem] {
        tasks.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    var body: some View {
        Group {
            if tasks.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "checkmark.circle.fill",
                        title: "Nothing to do yet",
                        message: "Add something small. A few words is enough.",
                        actionTitle: "Add a task",
                        tint: Anchor.Theme.accent
                    ) { startNew() }
                    .padding()
                }
            } else {
                List {
                    ForEach(open) { task in
                        TaskCard(task: task, onToggle: { toggle(task) }, onEdit: { editing = task })
                            .anchorDeletable { modelContext.delete(task) }
                            .anchorCardRow()
                    }
                    .onMove(perform: moveOpen)

                    if !done.isEmpty {
                        HStack {
                            Text("Done")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear done") { confirmingClearDone = true }
                                .font(.subheadline)
                        }
                        .anchorCardRow()

                        ForEach(done) { task in
                            TaskCard(task: task, onToggle: { toggle(task) }, onEdit: { editing = task })
                                .anchorDeletable { modelContext.delete(task) }
                                .anchorCardRow()
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .safeAreaInset(edge: .bottom) { quickAddBar }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if open.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Menu {
                    Button { importFromReminders() } label: {
                        Label("Import from Reminders", systemImage: "arrow.down.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
                Anchor.AddToolbarButton(label: "Add a task") { startNew() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { task in
            TaskEditorSheet(task: task, allTasks: tasks) { toDelete = task }
        }
        .confirmationDialog("Import which reminders?", isPresented: $showImporter, titleVisibility: .visible) {
            ForEach(importable) { reminder in
                Button(reminder.title) {
                    modelContext.insert(TaskItem(
                        title: reminder.title,
                        sortOrder: (tasks.map(\.sortOrder).max() ?? -1) + 1,
                        reminderIdentifier: reminder.id
                    ))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if importable.isEmpty {
                Text("No incomplete reminders found.")
            }
        }
        .confirmationDialog("Clear \(done.count) done \(done.count == 1 ? "task" : "tasks")?",
                            isPresented: $confirmingClearDone, titleVisibility: .visible) {
            Button("Clear done", role: .destructive) {
                for task in done { modelContext.delete(task) }
            }
            Button("Keep them", role: .cancel) {}
        }
        .alert("Reminders access is off", isPresented: $remindersDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can turn it on in Settings, then Anchor.")
        }
    }

    private var quickAddBar: some View {
        HStack(spacing: 8) {
            TextField("Add a task", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(quickAdd)
            Button("Add", action: quickAdd)
                .buttonStyle(Anchor.SecondaryButtonStyle())
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.thinMaterial)
    }

    private func nextSortOrder() -> Int { (tasks.map(\.sortOrder).max() ?? -1) + 1 }

    private func quickAdd() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newTitle = ""
        modelContext.insert(TaskItem(title: trimmed, sortOrder: nextSortOrder()))
    }

    private func startNew() {
        let new = TaskItem(title: "", sortOrder: nextSortOrder())
        modelContext.insert(new)
        editing = new
    }

    private func toggle(_ task: TaskItem) {
        withAnimation(.snappy) { setTask(task, done: !task.isDone, among: tasks) }
    }

    private func moveOpen(from offsets: IndexSet, to destination: Int) {
        var reordered = open
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, task) in reordered.enumerated() { task.sortOrder = index }
    }

    /// Runs once the editor has closed, so the editor never reads a task that
    /// is already gone. A task added and left blank is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for task in tasks where task !== deleting
            && task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(task)
        }
    }

    private func importFromReminders() {
        RemindersBridge.requestAccess { granted in
            guard granted else {
                remindersDenied = true
                return
            }
            RemindersBridge.incompleteReminders { found in
                importable = found
                showImporter = true
            }
        }
    }
}

private struct TaskCard: View {
    @Bindable var task: TaskItem
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Anchor.Card {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isDone ? Anchor.Theme.sage : Anchor.Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isDone ? "Mark as not done" : "Mark as done")

                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title.isEmpty ? "Untitled" : task.title)
                            .font(.system(.body, design: .rounded))
                            .strikethrough(task.isDone)
                            .foregroundStyle(task.isDone ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !task.notes.isEmpty {
                            Text(task.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the editor")
            }
        }
    }
}

private struct TaskEditorSheet: View {
    @Bindable var task: TaskItem
    let allTasks: [TaskItem]
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: task.title.isEmpty ? "New task" : "Task",
            onDelete: onDelete,
            deleteQuestion: "Delete this task?"
        ) {
            Form {
                Section {
                    TextField("What needs doing?", text: $task.title, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("Notes") {
                    TextField("Anything to remember", text: $task.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Toggle("Done", isOn: Binding(
                        get: { task.isDone },
                        set: { setTask(task, done: $0, among: allTasks) }
                    ))
                }
            }
        }
    }
}
