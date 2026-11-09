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
import UserNotifications
import UIKit
import ActivityKit

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

/// Turns pasted or typed text into tasks. One task a line. A line indented more than the one above it
/// becomes a step of that line, to any depth. Dashes, bullets, numbers and [ ] at the start of a line are
/// dropped, and [x] marks that one done.
enum TaskListParser {
    struct Line: Equatable {
        var depth: Int
        var title: String
        var done: Bool
    }

    static func parse(_ text: String) -> [Line] {
        var raw: [(indent: Int, title: String, done: Bool)] = []
        for rawLine in text.components(separatedBy: .newlines) {
            var indent = 0
            var rest = Substring(rawLine)
            while let first = rest.first, first == " " || first == "\t" {
                indent += first == "\t" ? 4 : 1
                rest = rest.dropFirst()
            }
            var title = rest.trimmingCharacters(in: .whitespaces)
            for bullet in ["- ", "* ", "\u{2022} ", "\u{2013} "] where title.hasPrefix(bullet) {
                title = String(title.dropFirst(bullet.count)).trimmingCharacters(in: .whitespaces)
                break
            }
            var done = false
            for box in ["[ ] ", "[x] ", "[X] "] where title.hasPrefix(box) {
                done = box != "[ ] "
                title = String(title.dropFirst(box.count)).trimmingCharacters(in: .whitespaces)
                break
            }
            if let range = title.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                title = String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            guard !title.isEmpty else { continue }
            raw.append((indent, title, done))
        }
        var open: [Int] = []
        var lines: [Line] = []
        for item in raw {
            while let last = open.last, last >= item.indent { open.removeLast() }
            lines.append(Line(depth: open.count, title: item.title, done: item.done))
            open.append(item.indent)
        }
        return lines
    }

    /// Adds the lines as tasks and steps, after the tasks already there.
    static func insert(_ lines: [Line], into context: ModelContext, startingAt start: Int) {
        var order = start
        var ancestors: [UUID] = []
        for line in lines {
            ancestors = Array(ancestors.prefix(line.depth))
            let task = TaskItem(title: line.title, isDone: line.done,
                                completedAt: line.done ? Date.now : nil,
                                sortOrder: order, parentID: ancestors.last)
            order += 1
            context.insert(task)
            ancestors.append(task.id)
        }
    }
}

private struct AddSeveralSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    let onAdd: (String) -> Void

    private var lines: [TaskListParser.Line] { TaskListParser.parse(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                } header: {
                    Text("One task a line")
                } footer: {
                    Text("Indent a line to make it a step of the one above, as deep as you like. Dashes, bullets and numbers are dropped, so you can paste a list from anywhere.")
                }
                if !lines.isEmpty {
                    Section("Adds \(lines.count)") {
                        ForEach(Array(lines.prefix(60).enumerated()), id: \.offset) { _, line in
                            Text(line.title)
                                .font(line.depth == 0 ? .body : .subheadline)
                                .foregroundStyle(line.depth == 0 ? .primary : .secondary)
                                .padding(.leading, CGFloat(line.depth) * 18)
                        }
                    }
                }
            }
            .navigationTitle("Add several")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(text)
                        dismiss()
                    }
                    .disabled(lines.isEmpty)
                }
            }
        }
    }
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

/// Sets a task aside for now, or brings it back to the list.
private func toggleSetAside(_ task: TaskItem) {
    task.status = task.status == .setAside ? .notStarted : .setAside
}

private extension View {
    /// Swipe right to move a task to tomorrow or set it aside, swipe left to
    /// delete. The long-press menu carries the same three, for people who do
    /// not use swipes.
    func taskRowActions(_ task: TaskItem, onFocus: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        self
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    withAnimation(.snappy) { task.snoozeToTomorrow() }
                } label: {
                    Label("Tomorrow", systemImage: "sunrise")
                }
                .tint(Anchor.Theme.accent)
                Button {
                    withAnimation(.snappy) { toggleSetAside(task) }
                } label: {
                    Label(task.status == .setAside ? "Bring back" : "Set aside",
                          systemImage: task.status == .setAside ? "tray.and.arrow.up" : "tray")
                }
                .tint(.gray)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                if !task.isDone {
                    Button(action: onFocus) {
                        Label("Focus on this", systemImage: "timer")
                    }
                }
                Button {
                    withAnimation(.snappy) { task.snoozeToTomorrow() }
                } label: {
                    Label("Move to tomorrow", systemImage: "sunrise")
                }
                Button {
                    withAnimation(.snappy) { toggleSetAside(task) }
                } label: {
                    Label(task.status == .setAside ? "Bring back" : "Set aside for now",
                          systemImage: task.status == .setAside ? "tray.and.arrow.up" : "tray")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

// MARK: - Tasks card on Now

/// The first few open tasks, with a quick add. The header opens the full list.
struct TasksNowCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @State private var newTitle = ""

    private var open: [TaskItem] { TaskItem.listOrder(tasks, includeWaiting: false) }
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
                Text(tasks.isEmpty ? "Nothing added yet." : (TaskItem.listOrder(tasks).isEmpty ? "All ticked off." : "Nothing to do right now."))
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
    @Query(sort: \QuickList.createdAt, order: .reverse) private var quickLists: [QuickList]
    @State private var editing: TaskItem?
    @State private var toDelete: TaskItem?
    @State private var quickRoute: QuickRoute?
    @State private var quickToDelete: QuickList?
    @State private var showArchive = false
    @State private var newTitle = ""
    @State private var importable: [ImportableReminder] = []
    @State private var showImporter = false
    @State private var remindersDenied = false
    @State private var confirmingClearDone = false
    @State private var energyFilter: TaskEnergyFilter = .everything
    @State private var showFocus = false
    @State private var showDayPlan = false
    @State private var showAddSeveral = false

    private var open: [TaskItem] { TaskItem.listOrder(tasks).filter { energyFilter.allows($0.energy) } }
    private var done: [TaskItem] {
        TaskItem.topLevel(tasks).filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    private var activeQuickLists: [QuickList] { quickLists.filter { !$0.isArchived && !$0.items.isEmpty } }
    private var archivedQuickLists: [QuickList] { quickLists.filter(\.isArchived) }

    var body: some View {
        Group {
            if tasks.isEmpty && quickLists.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        Anchor.EmptyState(
                            icon: "checkmark.circle.fill",
                            title: "Nothing to do yet",
                            message: "Add something small. A few words is enough.",
                            actionTitle: "Add a task",
                            tint: Anchor.Theme.accent
                        ) { startNew() }
                        Button("Add several at once") { showAddSeveral = true }
                            .buttonStyle(Anchor.SecondaryButtonStyle())
                        Button("Make a quick list") { quickRoute = .new }
                            .buttonStyle(Anchor.SecondaryButtonStyle())
                    }
                    .padding()
                }
            } else {
                List {
                    if energyFilter != .everything {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(energyFilter.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Show everything") { energyFilter = .everything }
                                .font(.footnote)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .anchorCardRow()
                    }

                    if !activeQuickLists.isEmpty {
                        HStack {
                            Text("Quick lists")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("New") { quickRoute = .new }
                                .font(.subheadline)
                        }
                        .anchorCardRow()

                        ForEach(activeQuickLists) { list in
                            Button { quickRoute = .open(list) } label: {
                                QuickListCard(list: list)
                            }
                            .buttonStyle(.plain)
                            .anchorDeletable { modelContext.delete(list) }
                            .anchorCardRow()
                        }
                    }

                    ForEach(TaskBucket.allCases) { bucket in
                        let group = open.filter { $0.listBucket(among: tasks) == bucket }
                        if !group.isEmpty {
                            Text(bucket.title)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)
                                .anchorCardRow()

                            ForEach(group) { task in
                                TaskCard(task: task, steps: TaskItem.steps(of: task, in: tasks), allTasks: tasks,
                                         blockedBy: task.openBlockers(among: tasks),
                                         onToggle: { toggle(task) }, onEdit: { editing = task },
                                         onFocusStep: { openFocus($0) }, onEditStep: { editing = $0 })
                                    .taskRowActions(task, onFocus: { openFocus(task) }) { modelContext.deleteTask(task, among: tasks) }
                                    .anchorCardRow()
                            }
                            .onMove { offsets, destination in
                                move(group, from: offsets, to: destination)
                            }
                        }
                    }

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
                            TaskCard(task: task, steps: TaskItem.steps(of: task, in: tasks), allTasks: tasks,
                                     blockedBy: [],
                                     onToggle: { toggle(task) }, onEdit: { editing = task })
                                .anchorDeletable { modelContext.deleteTask(task, among: tasks) }
                                .anchorCardRow()
                        }
                    }

                    if !archivedQuickLists.isEmpty {
                        Button { showArchive = true } label: {
                            Anchor.Card {
                                HStack(spacing: 12) {
                                    Image(systemName: "archivebox")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                    Text("Archive")
                                        .font(.system(.body, design: .rounded))
                                    Spacer()
                                    Text("\(archivedQuickLists.count)")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Archive, \(archivedQuickLists.count) quick \(archivedQuickLists.count == 1 ? "list" : "lists")")
                        .anchorCardRow()
                    }
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .safeAreaInset(edge: .bottom) { quickAddBar }
        .safeAreaInset(edge: .top, spacing: 0) {
            PomodoroBar { showFocus = true }
        }
        .navigationTitle("Tasks")
        .guideButton("now.tasks", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if open.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Menu {
                    Section("Show tasks that need") {
                        Picker("Energy", selection: $energyFilter) {
                            ForEach(TaskEnergyFilter.allCases) { filter in
                                Text(filter.label).tag(filter)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                    Button { quickRoute = .new } label: {
                        Label("Quick list", systemImage: "list.bullet.clipboard")
                    }
                    Button { showDayPlan = true } label: {
                        Label("Plan my day", systemImage: "sun.max")
                    }
                    Button { openFocus(nil) } label: {
                        Label("Focus timer", systemImage: "timer")
                    }
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
        .sheet(isPresented: $showFocus) {
            PomodoroView()
        }
        .sheet(isPresented: $showDayPlan) {
            PlanMyDayView()
        }
        .sheet(isPresented: $showAddSeveral) {
            AddSeveralSheet { text in
                TaskListParser.insert(TaskListParser.parse(text), into: modelContext, startingAt: nextSortOrder())
            }
        }
        .sheet(item: $quickRoute, onDismiss: finishQuickLists) { route in
            switch route {
            case .new:
                QuickListNewSheet(onDelete: { quickToDelete = $0 })
            case .open(let list):
                NavigationStack {
                    QuickListView(list: list, onDelete: { quickToDelete = $0 })
                }
            }
        }
        .navigationDestination(isPresented: $showArchive) {
            QuickListArchiveView()
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
                for task in done { modelContext.deleteTask(task, among: tasks) }
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
            Button { showAddSeveral = true } label: {
                Image(systemName: "text.badge.plus")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add several at once")
        }
        .padding()
        .background(.thinMaterial)
    }

    private func nextSortOrder() -> Int { (tasks.map(\.sortOrder).max() ?? -1) + 1 }

    /// Opens the focus timer, pointed at a task or step when one is given.
    /// A timer in the middle of a focus phase keeps the task it has.
    private func openFocus(_ task: TaskItem?) {
        PomodoroTimer.shared.use(modelContext)
        if let task { PomodoroTimer.shared.setTask(task) }
        showFocus = true
    }

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

    /// Reorders within one group. The group's own order values are shared out
    /// again in the new order, so tasks in other groups are not disturbed.
    private func move(_ group: [TaskItem], from offsets: IndexSet, to destination: Int) {
        let slots = group.map(\.sortOrder).sorted()
        var reordered = group
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, task) in reordered.enumerated() { task.sortOrder = slots[index] }
    }

    /// Runs once the editor has closed, so the editor never reads a task that
    /// is already gone. A task or step added and left blank is dropped; a
    /// blank task that has steps is kept.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.deleteTask(deleting, among: tasks) }
        for task in tasks where task !== deleting
            && task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && TaskItem.steps(of: task, in: tasks).isEmpty {
            modelContext.delete(task)
        }
    }

    /// Runs once a quick list's screen has closed: removes a list you chose to
    /// delete, and any list left empty.
    private func finishQuickLists() {
        let deleting = quickToDelete
        quickToDelete = nil
        modelContext.finishQuickLists(deleting: deleting, among: quickLists)
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
    let steps: [TaskItem]
    /// Every task, so the steps of steps can be shown to any depth.
    let allTasks: [TaskItem]
    /// The open tasks this one is waiting on. Empty when it is free to do.
    let blockedBy: [TaskItem]
    let onToggle: () -> Void
    let onEdit: () -> Void
    var onFocusStep: ((TaskItem) -> Void)? = nil
    var onEditStep: ((TaskItem) -> Void)? = nil

    private var doneSteps: Int { steps.filter(\.isDone).count }
    private var isBlocked: Bool { !task.isDone && !blockedBy.isEmpty }
    private var isSetAside: Bool { !task.isDone && task.status == .setAside }
    private var showsSteps: Bool { !task.isDone && !isBlocked && !isSetAside && !steps.isEmpty }
    private var isStarted: Bool { task.isStarted(steps: steps) }

    private var waitingText: String {
        let first = blockedBy[0].title.isEmpty ? "an untitled task" : blockedBy[0].title
        return blockedBy.count == 1 ? "Waiting on \(first)" : "Waiting on \(first) and \(blockedBy.count - 1) more"
    }

    /// The timing in as few words as will do, so it fits beside its icon. The full wording stays
    /// in the editor and is what VoiceOver reads.
    private var shortDue: String? {
        guard let full = task.dueText() else { return nil }
        switch task.dueKind {
        case .asap:
            return "Soon"
        case .today, .thisWeek, .thisMonth:
            if let end = task.dueDate, end < Date.now { return "Carried over" }
            return full
        case .exact:
            let prefix = "Planned for "
            return full.hasPrefix(prefix) ? String(full.dropFirst(prefix.count)) : full
        default:
            return full
        }
    }

    private var energyIcon: String {
        switch task.energy {
        case .little: return "battery.25percent"
        case .some: return "battery.50percent"
        case .lots: return "battery.100percent"
        case .unset: return "battery.0percent"
        }
    }

    /// Everything worth knowing at a glance, as a few small facts that each have an icon and a few
    /// words, and wrap onto a second row instead of being cut off.
    private var facts: [TaskFact] {
        var items: [TaskFact] = []
        if !task.isDone, let due = shortDue {
            items.append(TaskFact(id: "due", icon: "calendar", text: due, spoken: task.dueText() ?? due))
        }
        if !task.isDone, task.estimateMinutes > 0 {
            items.append(TaskFact(id: "estimate", icon: "clock",
                                  text: TaskItem.durationText(task.estimateMinutes),
                                  spoken: task.estimateText ?? ""))
        }
        if isStarted {
            items.append(TaskFact(id: "started", icon: "play.circle", text: "Started", spoken: "Started"))
        }
        if !task.isDone, let energy = task.energy.cardText {
            items.append(TaskFact(id: "energy", icon: energyIcon, text: task.energy.label, spoken: energy))
        }
        if !task.isDone, !steps.isEmpty {
            items.append(TaskFact(id: "steps", icon: "checklist", text: "\(doneSteps)/\(steps.count)",
                                  spoken: "\(doneSteps) of \(steps.count) steps"))
        }
        if task.focusSessions > 0 {
            items.append(TaskFact(id: "focus", icon: "timer",
                                  text: task.focusSessions == 1 ? "1 session" : "\(task.focusSessions) sessions",
                                  spoken: task.focusSummary ?? ""))
        }
        return items
    }

    private var showsFirstStep: Bool {
        !task.isDone && !isBlocked && !isSetAside && !isStarted && !task.firstStep.isEmpty
    }

    var body: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    leadingControl
                    Button(action: onEdit) {
                        rowText
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the editor")

                    if showsSteps {
                        Button {
                            withAnimation(.snappy) { task.subtasksCollapsed.toggle() }
                        } label: {
                            Image(systemName: task.subtasksCollapsed ? "chevron.down" : "chevron.up")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(task.subtasksCollapsed ? "Show steps" : "Hide steps")
                    }
                }

                if showsSteps && !task.subtasksCollapsed {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(steps) { step in
                            StepTreeRow(step: step, allTasks: allTasks,
                                        onFocusStep: onFocusStep, onEditStep: onEditStep)
                        }
                    }
                    .padding(.leading, 34)
                }
            }
        }
        .opacity(isBlocked || isSetAside ? 0.6 : 1)
    }

    @ViewBuilder private var leadingControl: some View {
        if isBlocked {
            Image(systemName: "hourglass")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Waiting")
        } else {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? Anchor.Theme.sage : Anchor.Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Mark as not done" : "Mark as done")
        }
    }

    private var rowText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(task.title.isEmpty ? "Untitled" : task.title)
                .font(.system(.body, design: .rounded))
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
            if isBlocked {
                Text(waitingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !facts.isEmpty {
                TaskFlowLayout(spacing: 12, lineSpacing: 3) {
                    ForEach(facts) { fact in
                        HStack(spacing: 4) {
                            Image(systemName: fact.icon)
                                .imageScale(.small)
                            Text(fact.text)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(fact.spoken)
                    }
                }
            }
            if showsFirstStep {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "arrow.turn.down.right")
                        .imageScale(.small)
                    Text(task.firstStep)
                        .lineLimit(2)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Start with: \(task.firstStep)")
            }
        }
    }
}

/// One small fact on a task card: an icon and a few words, with the longer wording for VoiceOver.
private struct TaskFact: Identifiable {
    let id: String
    let icon: String
    let text: String
    let spoken: String
}

/// Lays small items out left to right and starts a new row when one would not fit, so nothing on a
/// task card is cut off.
private struct TaskFlowLayout: Layout {
    var spacing: CGFloat = 12
    var lineSpacing: CGFloat = 3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (origins, CGSize(width: widest, height: y + rowHeight))
    }
}

/// One step on a task's card, and the steps under it, to any depth. Tap to tick it; the arrow folds
/// the steps under it away; press and hold for its details or a focus timer.
private struct StepTreeRow: View {
    @Bindable var step: TaskItem
    let allTasks: [TaskItem]
    var onFocusStep: ((TaskItem) -> Void)? = nil
    var onEditStep: ((TaskItem) -> Void)? = nil

    private var children: [TaskItem] { TaskItem.steps(of: step, in: allTasks) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.snappy) { step.setDone(!step.isDone) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(step.isDone ? Anchor.Theme.sage : Color.secondary)
                        Text(step.title.isEmpty ? "Untitled step" : step.title)
                            .font(.system(.subheadline, design: .rounded))
                            .strikethrough(step.isDone)
                            .foregroundStyle(step.isDone ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(step.isDone ? "Mark step as not done" : "Mark step as done")
                .contextMenu {
                    if let onEditStep {
                        Button { onEditStep(step) } label: {
                            Label("Open details", systemImage: "square.and.pencil")
                        }
                    }
                    if !step.isDone, let onFocusStep {
                        Button { onFocusStep(step) } label: {
                            Label("Focus on this step", systemImage: "timer")
                        }
                    }
                }

                if !children.isEmpty {
                    Text("\(children.filter(\.isDone).count)/\(children.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        withAnimation(.snappy) { step.subtasksCollapsed.toggle() }
                    } label: {
                        Image(systemName: step.subtasksCollapsed ? "chevron.down" : "chevron.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(step.subtasksCollapsed ? "Show steps under this step" : "Hide steps under this step")
                }
            }

            if !children.isEmpty && !step.subtasksCollapsed {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(children) { child in
                        StepTreeRow(step: child, allTasks: allTasks,
                                    onFocusStep: onFocusStep, onEditStep: onEditStep)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }
}

private struct TaskEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var liveTasks: [TaskItem]
    @Bindable var task: TaskItem
    let allTasks: [TaskItem]
    let onDelete: () -> Void

    @State private var newStep = ""
    @State private var editMode: EditMode = .inactive
    @State private var showFocus = false
    @State private var showMore = false
    @State private var editingStep: TaskItem?
    @State private var stepToDelete: TaskItem?

    private var isStep: Bool { task.parentID != nil }
    private var steps: [TaskItem] { TaskItem.steps(of: task, in: liveTasks) }
    private var blockers: [TaskItem] {
        task.blockedByIDs.compactMap { id in liveTasks.first(where: { $0.id == id }) }
    }
    private var possibleBlockers: [TaskItem] { task.possibleBlockers(among: liveTasks) }
    private var dueIsTomorrow: Bool {
        task.dueKind == .exact && (task.dueDate.map { Calendar.current.isDateInTomorrow($0) } ?? false)
    }
    /// True when anything under More options has been filled in, so it opens already showing it.
    private var hasMoreSet: Bool {
        !task.firstStep.isEmpty || !task.blockedByIDs.isEmpty || task.estimateMinutes > 0
            || task.status != .notStarted || task.energy != .unset || task.focusSessions > 0
    }

    var body: some View {
        Anchor.ItemEditorSheet(
            title: isStep ? "Step" : (task.title.isEmpty ? "New task" : "Task"),
            onDelete: onDelete,
            deleteQuestion: isStep ? "Delete this step?" : "Delete this task?"
        ) {
            Form {
                Section {
                    TextField(isStep ? "What is this step?" : "What needs doing?", text: $task.title, axis: .vertical)
                        .lineLimit(1...4)
                }
                stepsSection
                Section("When") {
                    Picker("When", selection: Binding(
                        get: { task.dueKind },
                        set: { task.setDue($0) }
                    )) {
                        ForEach(TaskDueKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    if task.dueKind == .exact {
                        DatePicker("Day", selection: Binding(
                            get: { task.dueDate ?? Date.now },
                            set: { task.setDue(.exact, day: $0) }
                        ), displayedComponents: .date)
                    }
                    if !task.isDone && !dueIsTomorrow {
                        Button("Move to tomorrow") { task.snoozeToTomorrow() }
                    }
                }
                Section("Notes") {
                    TextField("Anything to remember", text: $task.notes, axis: .vertical)
                        .lineLimit(2...8)
                }
                Section {
                    Toggle("Done", isOn: Binding(
                        get: { task.isDone },
                        set: { setTask(task, done: $0, among: allTasks) }
                    ))
                    Button {
                        withAnimation { showMore.toggle() }
                    } label: {
                        HStack {
                            Text(showMore ? "Fewer options" : "More options")
                            Spacer()
                            Image(systemName: showMore ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if showMore { moreSections }
            }
            .environment(\.editMode, $editMode)
        }
        .onAppear { if hasMoreSet { showMore = true } }
        .sheet(isPresented: $showFocus) {
            PomodoroView()
        }
        .sheet(item: $editingStep, onDismiss: finishStepEditing) { step in
            TaskEditorSheet(task: step, allTasks: liveTasks) { stepToDelete = step }
        }
    }

    private var stepsSection: some View {
        Section {
            ForEach(steps) { step in
                StepEditorRow(step: step,
                              childCount: TaskItem.steps(of: step, in: liveTasks).count,
                              onOpen: { editingStep = step })
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.deleteTask(step, among: liveTasks)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onMove(perform: moveSteps)

            HStack {
                TextField("Add a step", text: $newStep)
                    .onSubmit(addStep)
                Button("Add", action: addStep)
                    .buttonStyle(.borderless)
                    .disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            HStack {
                Text("Steps")
                Spacer()
                if steps.count > 1 {
                    Button(editMode.isEditing ? "Done" : "Reorder") {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    }
                    .font(.footnote)
                    .textCase(nil)
                }
            }
        } footer: {
            if !steps.isEmpty {
                Text("Tap the arrow on a step to give it its own details and steps.")
            }
        }
    }

    @ViewBuilder private var moreSections: some View {
        Section("First tiny step") {
            TextField("The smallest way to begin", text: $task.firstStep, axis: .vertical)
                .lineLimit(1...3)
        }
        if !blockers.isEmpty || !possibleBlockers.isEmpty {
            Section("Waiting on") {
                ForEach(blockers) { blocker in
                    Label(blocker.title.isEmpty ? "Untitled" : blocker.title,
                          systemImage: blocker.isDone ? "checkmark.circle" : "hourglass")
                        .foregroundStyle(blocker.isDone ? .secondary : .primary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                task.blockedByIDs.removeAll { $0 == blocker.id }
                            } label: {
                                Label("Remove", systemImage: "xmark")
                            }
                        }
                }
                if !possibleBlockers.isEmpty {
                    Menu {
                        ForEach(possibleBlockers) { candidate in
                            Button(candidate.title.isEmpty ? "Untitled" : candidate.title) {
                                task.blockedByIDs.append(candidate.id)
                            }
                        }
                    } label: {
                        Label("Wait on another task", systemImage: "plus")
                    }
                }
            }
        }
        Section("How long") {
            Picker("How long", selection: $task.estimateMinutes) {
                Text("None").tag(0)
                ForEach(TaskItem.estimateChoices, id: \.self) { minutes in
                    Text(minutes == 60 ? "1 hr" : "\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.segmented)
        }
        Section("How it is going") {
            Picker("Status", selection: $task.status) {
                ForEach(TaskStatus.allCases) { status in
                    Text(status.label).tag(status)
                }
            }
            Picker("Energy it needs", selection: $task.energy) {
                ForEach(TaskEnergy.allCases) { energy in
                    Text(energy.label).tag(energy)
                }
            }
        }
        Section("Focus") {
            if !task.isDone {
                Button {
                    PomodoroTimer.shared.use(modelContext)
                    PomodoroTimer.shared.setTask(task)
                    showFocus = true
                } label: {
                    Label("Focus on this task", systemImage: "timer")
                }
            }
            if let focus = task.focusSummary {
                Text(focus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addStep() {
        let trimmed = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        newStep = ""
        modelContext.insert(TaskItem(
            title: trimmed,
            sortOrder: (steps.map(\.sortOrder).max() ?? -1) + 1,
            parentID: task.id
        ))
    }

    /// Shares the steps' own order values out again in the new order.
    private func moveSteps(from offsets: IndexSet, to destination: Int) {
        let slots = steps.map(\.sortOrder).sorted()
        var reordered = steps
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, step) in reordered.enumerated() { step.sortOrder = slots[index] }
    }

    /// Runs once a step's own editor has closed: removes a step you chose to delete, and any step left
    /// blank with nothing under it.
    private func finishStepEditing() {
        let deleting = stepToDelete
        stepToDelete = nil
        if let deleting { modelContext.deleteTask(deleting, among: liveTasks) }
        for step in TaskItem.steps(of: task, in: liveTasks) where step !== deleting
            && step.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && step.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && TaskItem.steps(of: step, in: liveTasks).isEmpty {
            modelContext.delete(step)
        }
    }
}

private struct StepEditorRow: View {
    @Bindable var step: TaskItem
    let childCount: Int
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                step.setDone(!step.isDone)
            } label: {
                Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(step.isDone ? Anchor.Theme.sage : Anchor.Theme.accent)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(step.isDone ? "Mark step as not done" : "Mark step as done")
            TextField("Step", text: $step.title, axis: .vertical)
                .foregroundStyle(step.isDone ? .secondary : .primary)
            if childCount > 0 {
                Text("\(childCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(childCount) steps under this step")
            }
            Button(action: onOpen) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Open step details")
        }
    }
}


// MARK: - Focus timer

/// Focus timer settings. Everything is optional and the defaults are the
/// usual 25 and 5; alerts are off until you switch them on.
enum PomodoroSettings {
    static let focusKey = "anchor.focus.focusMinutes"
    static let shortBreakKey = "anchor.focus.shortBreakMinutes"
    static let longBreakKey = "anchor.focus.longBreakMinutes"
    static let roundsKey = "anchor.focus.roundsBeforeLongBreak"
    static let breaksKey = "anchor.focus.breaksOn"
    static let autoStartKey = "anchor.focus.autoStart"
    static let hapticKey = "anchor.focus.haptic"
    static let alertsKey = "anchor.focus.alertsEnabled"
    static let soundKey = "anchor.focus.alertSound"
    static let lockScreenKey = "anchor.focus.lockScreen"

    private static func int(_ key: String, _ fallback: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? fallback
    }
    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }

    static var focusMinutes: Int { int(focusKey, 25) }
    static var shortBreakMinutes: Int { int(shortBreakKey, 5) }
    static var longBreakMinutes: Int { int(longBreakKey, 15) }
    static var roundsBeforeLongBreak: Int { max(2, int(roundsKey, 4)) }
    static var breaksOn: Bool { bool(breaksKey, true) }
    static var autoStart: Bool { bool(autoStartKey, false) }
    static var hapticOn: Bool { bool(hapticKey, true) }
    static var alertsOn: Bool { bool(alertsKey, false) }
    static var soundOn: Bool { bool(soundKey, false) }
    static var lockScreenOn: Bool { bool(lockScreenKey, false) }

    /// Called when the lock screen switch changes, here or in Settings.
    @MainActor
    static func lockScreenChanged(_ isOn: Bool) {
        PomodoroTimer.shared.refreshActivity()
    }

    /// Called when the alerts switch changes, here or in Settings. The system
    /// permission question is asked now, the first time it is switched on.
    @MainActor
    static func alertsChanged(_ isOn: Bool) {
        if isOn { NotificationScheduler.askForPermissionIfNeeded() }
        PomodoroTimer.shared.refreshAlert()
    }
}

enum PomodoroPhase {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var isBreak: Bool { self != .focus }
}

/// One timer for the whole app, so it keeps going when its screen is closed.
/// It works from an end time rather than a count, so it stays right while the
/// app is in the background. A focus session is added to its task only when
/// the time has run all the way out; stopping early adds nothing and says
/// nothing.
@MainActor
final class PomodoroTimer: ObservableObject {
    static let shared = PomodoroTimer()

    enum State { case idle, running, paused, waiting }

    @Published private(set) var state: State = .idle
    /// The phase running now, or the one that is next while `waiting`.
    @Published private(set) var phase: PomodoroPhase = .focus
    @Published private(set) var round = 1
    @Published private(set) var taskID: UUID?
    @Published private(set) var endDate = Date.now
    private(set) var phaseLength: TimeInterval = 0
    private var pausedRemaining: TimeInterval = 0
    private var context: ModelContext?
    private var ticker: Timer?

    static let alertIdentifier = "focus-timer-phase"

    /// Gives the timer somewhere to record finished sessions. Called by the
    /// screens that can start it.
    func use(_ context: ModelContext) {
        self.context = context
        // A lock screen timer left behind by an earlier run of the app, which
        // iOS closed while it was going, is cleared away.
        if state == .idle { endAllActivities() }
    }

    /// Whether the task can be changed now: not while a focus phase is under way.
    var canChangeTask: Bool { state == .idle || state == .waiting || phase.isBreak }

    func setTask(_ task: TaskItem?) {
        guard canChangeTask else { return }
        taskID = task?.id
    }

    func minutes(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .focus: return PomodoroSettings.focusMinutes
        case .shortBreak: return PomodoroSettings.shortBreakMinutes
        case .longBreak: return PomodoroSettings.longBreakMinutes
        }
    }

    func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .running: return max(0, endDate.timeIntervalSince(now))
        case .paused: return pausedRemaining
        case .idle, .waiting: return TimeInterval(minutes(for: phase) * 60)
        }
    }

    func progress(at now: Date) -> Double {
        guard phaseLength > 0, state == .running || state == .paused else { return 0 }
        return min(1, max(0, 1 - remaining(at: now) / phaseLength))
    }

    // MARK: Controls

    /// Starts the phase that is up next (focus when idle).
    func startPhase() {
        guard state == .idle || state == .waiting else { return }
        phaseLength = TimeInterval(minutes(for: phase) * 60)
        endDate = Date.now.addingTimeInterval(phaseLength)
        state = .running
        startTicker()
        scheduleAlert()
        syncActivity()
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        state = .paused
        stopTicker()
        cancelAlert()
        syncActivity()
    }

    func resume() {
        guard state == .paused else { return }
        endDate = Date.now.addingTimeInterval(pausedRemaining)
        state = .running
        startTicker()
        scheduleAlert()
        syncActivity()
    }

    /// Ends the timer. Nothing is recorded for a phase that did not finish.
    func stop() {
        stopTicker()
        cancelAlert()
        state = .idle
        phase = .focus
        round = 1
        taskID = nil
        syncActivity()
    }

    /// Skips the rest of a break and waits for you to start the next focus.
    func skipBreak() {
        guard phase.isBreak, state != .idle else { return }
        stopTicker()
        cancelAlert()
        advance(after: phase)
        state = .waiting
        syncActivity()
    }

    // MARK: Ticking

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    /// Moves on when a phase has run out. If the app was asleep when it ended,
    /// the next one is never started on your behalf.
    func tick(now: Date = .now) {
        guard state == .running, now >= endDate else { return }
        let finished = phase
        let lateBy = now.timeIntervalSince(endDate)
        if finished == .focus { recordSession() }
        cancelAlert()
        stopTicker()
        if lateBy < 5, PomodoroSettings.hapticOn {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        advance(after: finished)
        state = .waiting
        syncActivity()
        if lateBy < 5, PomodoroSettings.autoStart { startPhase() }
    }

    private func advance(after finished: PomodoroPhase) {
        switch finished {
        case .focus:
            if PomodoroSettings.breaksOn {
                phase = round >= PomodoroSettings.roundsBeforeLongBreak ? .longBreak : .shortBreak
            } else {
                phase = .focus
                round += 1
            }
        case .shortBreak:
            phase = .focus
            round += 1
        case .longBreak:
            phase = .focus
            round = 1
        }
    }

    private func recordSession() {
        guard let id = taskID, let context else { return }
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        guard let task = try? context.fetch(descriptor).first else { return }
        task.focusSessions += 1
        task.focusMinutes += Int((phaseLength / 60).rounded())
    }

    // MARK: Lock screen timer

    private var activity: Activity<PomodoroActivityAttributes>?

    /// Re-applies the lock screen timer after the setting changes.
    func refreshActivity() { syncActivity() }

    /// Shows, updates or removes the lock screen timer to match the timer. It
    /// is only there while a phase is running or paused, only when it is
    /// switched on, and it never carries the task's name.
    private func syncActivity() {
        guard PomodoroSettings.lockScreenOn,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              state == .running || state == .paused else {
            endActivity()
            return
        }
        let content = ActivityContent(
            state: PomodoroActivityAttributes.ContentState(
                phaseTitle: phase.title,
                isBreak: phase.isBreak,
                startDate: endDate.addingTimeInterval(-max(phaseLength, 1)),
                endDate: endDate,
                isPaused: state == .paused,
                pausedRemaining: pausedRemaining
            ),
            staleDate: state == .running ? endDate : nil
        )
        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(attributes: PomodoroActivityAttributes(), content: content, pushType: nil)
        }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    private func endAllActivities() {
        activity = nil
        for running in Activity<PomodoroActivityAttributes>.activities {
            Task { await running.end(nil, dismissalPolicy: .immediate) }
        }
    }

    // MARK: Alert when the phase ends in the background

    /// Re-applies the alert after the setting changes.
    func refreshAlert() {
        cancelAlert()
        if state == .running { scheduleAlert() }
    }

    private func scheduleAlert() {
        guard PomodoroSettings.alertsOn else { return }
        let seconds = endDate.timeIntervalSinceNow
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Anchor"
        // Generic on purpose: no task name on the lock screen.
        switch phase {
        case .focus:
            content.body = PomodoroSettings.breaksOn ? "Focus time is up. A break could be nice." : "Focus time is up."
        case .shortBreak, .longBreak:
            content.body = "Break's over. Ready when you are."
        }
        content.sound = PomodoroSettings.soundOn ? .default : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: Self.alertIdentifier, content: content, trigger: trigger)
        )
    }

    private func cancelAlert() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.alertIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.alertIdentifier])
    }
}

private func clockText(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded(.up))
    return String(format: "%d:%02d", total / 60, total % 60)
}

/// A slim bar at the top of the task list while a timer is going, which
/// reopens the timer.
private struct PomodoroBar: View {
    @ObservedObject private var timer = PomodoroTimer.shared
    let onOpen: () -> Void

    var body: some View {
        if timer.state != .idle {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    Image(systemName: timer.phase.isBreak ? "cup.and.saucer" : "timer")
                        .foregroundStyle(Anchor.Theme.accent)
                    Text(timer.state == .waiting ? "\(timer.phase.title) is next" : timer.phase.title)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                    Spacer()
                    if timer.state == .waiting {
                        Text("Ready")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(clockText(timer.remaining(at: context.date)))
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(timer.state == .paused ? .secondary : .primary)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(.thinMaterial)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the focus timer")
        }
    }
}

struct PomodoroView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var timer = PomodoroTimer.shared
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @AppStorage(PomodoroSettings.alertsKey) private var alertsOn = false
    @AppStorage(PomodoroSettings.lockScreenKey) private var lockScreenOn = false
    @AppStorage(PomodoroSettings.breaksKey) private var breaksOn = true
    @AppStorage(PomodoroSettings.roundsKey) private var rounds = 4

    private var task: TaskItem? {
        guard let id = timer.taskID else { return nil }
        return tasks.first { $0.id == id }
    }

    private var choices: [TaskItem] {
        TaskItem.listOrder(tasks, includeWaiting: false)
    }

    private var roundText: String {
        breaksOn ? "Round \(timer.round) of \(max(2, rounds))" : "Round \(timer.round)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    taskPicker

                    VStack(spacing: 8) {
                        Text(timer.phase.title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.secondary)
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            VStack(spacing: 14) {
                                Text(clockText(timer.remaining(at: context.date)))
                                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .accessibilityAddTraits(.updatesFrequently)
                                ProgressView(value: timer.progress(at: context.date))
                                    .tint(timer.phase.isBreak ? Anchor.Theme.sage : Anchor.Theme.accent)
                                    .frame(maxWidth: 260)
                                    .accessibilityHidden(true)
                            }
                        }
                        Text(timer.state == .waiting ? "Ready when you are" : roundText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    controls

                    if !alertsOn {
                        HStack(spacing: 4) {
                            Text("Alerts when a phase ends are off.")
                            Button("Turn on") { alertsOn = true }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    if !lockScreenOn {
                        HStack(spacing: 4) {
                            Text("The lock screen timer is off.")
                            Button("Turn on") { lockScreenOn = true }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .anchorBackground()
            .navigationTitle("Focus timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        PomodoroSettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Focus timer settings")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                timer.use(modelContext)
                UIApplication.shared.isIdleTimerDisabled = timer.state == .running
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: timer.state) { _, state in
                UIApplication.shared.isIdleTimerDisabled = state == .running
            }
            .onChange(of: alertsOn) { _, isOn in PomodoroSettings.alertsChanged(isOn) }
            .onChange(of: lockScreenOn) { _, isOn in PomodoroSettings.lockScreenChanged(isOn) }
        }
    }

    private var taskPicker: some View {
        Group {
            if timer.canChangeTask {
                Menu {
                    Button("No particular task") { timer.setTask(nil) }
                    ForEach(choices) { candidate in
                        Button(candidate.title.isEmpty ? "Untitled" : candidate.title) {
                            timer.setTask(candidate)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(task.map { $0.title.isEmpty ? "Untitled" : $0.title } ?? "Choose a task")
                            .font(.system(.body, design: .rounded))
                            .multilineTextAlignment(.center)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(task == nil ? Color.secondary : Color.primary)
                }
            } else {
                Text(task.map { $0.title.isEmpty ? "Untitled" : $0.title } ?? "Focus time")
                    .font(.system(.body, design: .rounded))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 12) {
            switch timer.state {
            case .idle:
                Button("Start focus") { timer.startPhase() }
                    .buttonStyle(Anchor.PrimaryButtonStyle())
            case .running:
                Button("Pause") { timer.pause() }
                    .buttonStyle(Anchor.PrimaryButtonStyle())
                secondaryRow
            case .paused:
                Button("Resume") { timer.resume() }
                    .buttonStyle(Anchor.PrimaryButtonStyle())
                secondaryRow
            case .waiting:
                Button("Start \(timer.phase.title.lowercased())") { timer.startPhase() }
                    .buttonStyle(Anchor.PrimaryButtonStyle())
                secondaryRow
            }
        }
        .frame(maxWidth: 360)
    }

    private var secondaryRow: some View {
        HStack(spacing: 12) {
            if timer.phase.isBreak {
                Button("Skip break") { timer.skipBreak() }
                    .buttonStyle(Anchor.SecondaryButtonStyle())
            }
            Button("Stop") { timer.stop() }
                .buttonStyle(Anchor.SecondaryButtonStyle(tint: .gray))
        }
    }
}

struct PomodoroSettingsView: View {
    @AppStorage(PomodoroSettings.focusKey) private var focus = 25
    @AppStorage(PomodoroSettings.shortBreakKey) private var shortBreak = 5
    @AppStorage(PomodoroSettings.longBreakKey) private var longBreak = 15
    @AppStorage(PomodoroSettings.roundsKey) private var rounds = 4
    @AppStorage(PomodoroSettings.breaksKey) private var breaksOn = true
    @AppStorage(PomodoroSettings.autoStartKey) private var autoStart = false
    @AppStorage(PomodoroSettings.hapticKey) private var haptic = true
    @AppStorage(PomodoroSettings.alertsKey) private var alertsOn = false
    @AppStorage(PomodoroSettings.soundKey) private var sound = false
    @AppStorage(PomodoroSettings.lockScreenKey) private var lockScreen = false

    var body: some View {
        Form {
            Anchor.SettingsSection(title: "Lengths") {
                Stepper("Focus: \(focus) minutes", value: $focus, in: 5...90, step: 5)
                    .font(.system(.subheadline, design: .rounded))
                if breaksOn {
                    Stepper("Short break: \(shortBreak) minutes", value: $shortBreak, in: 1...30)
                        .font(.system(.subheadline, design: .rounded))
                    Stepper("Long break: \(longBreak) minutes", value: $longBreak, in: 5...60, step: 5)
                        .font(.system(.subheadline, design: .rounded))
                    Stepper("Focus rounds before a long break: \(rounds)", value: $rounds, in: 2...8)
                        .font(.system(.subheadline, design: .rounded))
                }
            }
            Anchor.SettingsSection(title: "How it runs") {
                Anchor.SettingsToggle(title: "Breaks", isOn: $breaksOn)
                Anchor.SettingsToggle(title: "Start the next one by itself", isOn: $autoStart)
                Anchor.SettingsToggle(title: "Haptic when one ends", isOn: $haptic)
            }
            Anchor.SettingsSection(title: "Alerts") {
                Anchor.SettingsToggle(title: "Alert when one ends in the background", isOn: $alertsOn)
                if alertsOn {
                    Anchor.SettingsToggle(title: "Sound with the alert", isOn: $sound)
                }
                Anchor.SettingsToggle(title: "Show the timer on the lock screen", isOn: $lockScreen)
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Timer settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: alertsOn) { _, isOn in PomodoroSettings.alertsChanged(isOn) }
        .onChange(of: lockScreen) { _, isOn in PomodoroSettings.lockScreenChanged(isOn) }
    }
}


// MARK: - Plan my day

/// Today's plan: the tasks and steps you picked, in order, and the time you
/// said you have. Kept on this device for the day only. A plan from an earlier
/// day is dropped without comment; only the time you said you have carries over.
struct DayPlan: Codable, Equatable {
    var day: Date
    var ids: [UUID] = []
    var availableMinutes: Int = 0

    static let key = "anchor.dayPlan"

    static func today(now: Date = .now, calendar: Calendar = .current) -> DayPlan {
        let start = calendar.startOfDay(for: now)
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(DayPlan.self, from: data) else {
            return DayPlan(day: start)
        }
        if calendar.isDate(saved.day, inSameDayAs: now) { return saved }
        return DayPlan(day: start, ids: [], availableMinutes: saved.availableMinutes)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}

/// Pick a few tasks or steps, put them in the order you like, say how much
/// time you have, and walk through them one at a time. Nothing is scored, and
/// a plan that does not fit the time is only described, never flagged.
struct PlanMyDayView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @State private var plan = DayPlan.today()
    @State private var editMode: EditMode = .inactive
    @State private var walking = false

    private struct Candidate: Identifiable {
        let task: TaskItem
        let parent: TaskItem?
        var id: UUID { task.id }
    }

    /// What can be done now: open tasks that are not waiting or set aside,
    /// and the open steps of those tasks.
    private var candidates: [Candidate] {
        var found: [Candidate] = []
        for task in TaskItem.listOrder(tasks, includeWaiting: false) {
            found.append(Candidate(task: task, parent: nil))
            for step in TaskItem.steps(of: task, in: tasks) where !step.isDone {
                found.append(Candidate(task: step, parent: task))
            }
        }
        return found
    }

    private var planned: [Candidate] {
        let pool = candidates
        return plan.ids.compactMap { id in pool.first { $0.id == id } }
    }

    private var others: [Candidate] {
        let chosen = Set(plan.ids)
        return candidates.filter { !chosen.contains($0.id) }
    }

    private var summary: String {
        let items = planned
        guard !items.isEmpty else { return "Nothing picked yet." }
        let total = items.reduce(0) { $0 + $1.task.estimateMinutes }
        let unknown = items.filter { $0.task.estimateMinutes == 0 }.count
        var text = total > 0 ? "About \(TaskItem.durationText(total)) planned" : "No estimates yet"
        if plan.availableMinutes > 0 { text += ", with \(TaskItem.durationText(plan.availableMinutes)) to spend" }
        if total > 0 && unknown > 0 { text += ", plus \(unknown) with no estimate" }
        return text + "."
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper(value: $plan.availableMinutes, in: 0...720, step: 30) {
                        Text(plan.availableMinutes == 0
                             ? "Time I have: not sure"
                             : "Time I have: \(TaskItem.durationText(plan.availableMinutes))")
                            .font(.system(.subheadline, design: .rounded))
                    }
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !planned.isEmpty {
                    Section("Your plan") {
                        ForEach(planned) { item in
                            row(item, inPlan: true)
                        }
                        .onMove(perform: movePlanned)
                    }
                }

                Section(others.isEmpty && planned.isEmpty ? "Nothing to pick from" : "Add to your plan") {
                    if others.isEmpty && planned.isEmpty {
                        Text("Add a task first, then come back.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(others) { item in
                        row(item, inPlan: false)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !planned.isEmpty {
                    Button("Start") { walking = true }
                        .buttonStyle(Anchor.PrimaryButtonStyle())
                        .padding()
                        .background(.thinMaterial)
                }
            }
            .navigationTitle("Plan my day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if planned.count > 1 {
                    ToolbarItem(placement: .primaryAction) {
                        Anchor.ReorderToolbarButton()
                    }
                }
            }
            .navigationDestination(isPresented: $walking) {
                DayWalkthroughView(ids: planned.map(\.id))
            }
            .onAppear { plan.ids = planned.map(\.id) }
            .onChange(of: plan) { _, new in new.save() }
            .environment(\.editMode, $editMode)
        }
    }

    private func row(_ item: Candidate, inPlan: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { toggle(item.id) }
            } label: {
                Image(systemName: inPlan ? "minus.circle" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(inPlan ? Color.secondary : Anchor.Theme.accent)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(inPlan ? "Take out of the plan" : "Add to the plan")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.task.title.isEmpty ? "Untitled" : item.task.title)
                    .font(.system(.body, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                if let parent = item.parent {
                    Text("Step of \(parent.title.isEmpty ? "an untitled task" : parent.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let estimate = item.task.estimateText {
                    Text(estimate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if plan.ids.contains(id) {
            plan.ids.removeAll { $0 == id }
        } else {
            plan.ids.append(id)
        }
    }

    private func movePlanned(from offsets: IndexSet, to destination: Int) {
        var ids = planned.map(\.id)
        ids.move(fromOffsets: offsets, toOffset: destination)
        plan.ids = ids
    }
}

/// Goes through the plan one item at a time. Done ticks it off, Not now moves
/// on without changing anything, and Focus on this opens the timer.
private struct DayWalkthroughView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    let ids: [UUID]
    @State private var skipped: Set<UUID> = []
    @State private var showFocus = false

    private var queue: [TaskItem] {
        ids.compactMap { id in tasks.first { $0.id == id && !$0.isDone } }
    }
    private var current: TaskItem? { queue.first { !skipped.contains($0.id) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let task = current {
                    VStack(spacing: 10) {
                        Text("Now")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(task.title.isEmpty ? "Untitled" : task.title)
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if !task.firstStep.isEmpty {
                            Text("Start with: \(task.firstStep)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        if let estimate = task.estimateText {
                            Text(estimate)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !task.notes.isEmpty {
                            Text(task.notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        Button("Focus on this") {
                            PomodoroTimer.shared.use(modelContext)
                            PomodoroTimer.shared.setTask(task)
                            showFocus = true
                        }
                        .buttonStyle(Anchor.PrimaryButtonStyle())
                        Button("Done") {
                            withAnimation(.snappy) { setTask(task, done: true, among: tasks) }
                        }
                        .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
                        if queue.count > 1 {
                            Button("Not now") {
                                withAnimation(.snappy) { _ = skipped.insert(task.id) }
                            }
                            .buttonStyle(Anchor.SecondaryButtonStyle(tint: .gray))
                        }
                    }
                    .frame(maxWidth: 360)
                } else {
                    VStack(spacing: 12) {
                        Text("That is the plan for today.")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .multilineTextAlignment(.center)
                        if !queue.isEmpty {
                            Button("Go back to the ones I set down") {
                                withAnimation(.snappy) { skipped.removeAll() }
                            }
                            .buttonStyle(Anchor.SecondaryButtonStyle())
                        }
                    }
                    .padding(.top, 48)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .anchorBackground()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFocus) {
            PomodoroView()
        }
    }
}

// MARK: - Quick lists

/// What the quick list sheet on the Tasks screen is showing: the form for a
/// new list, or one list that already exists.
private enum QuickRoute: Identifiable {
    case new
    case open(QuickList)

    var id: String {
        switch self {
        case .new: return "new"
        case .open(let list): return list.id.uuidString
        }
    }
}

/// One list in the Tasks screen's Quick lists section and in the Archive.
private struct QuickListCard: View {
    let list: QuickList

    var body: some View {
        Anchor.Card {
            HStack(spacing: 12) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.title3)
                    .foregroundStyle(list.isArchived ? Color.secondary : Anchor.Theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.displayTitle)
                        .font(.system(.body, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(list.summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Type or paste one item per line, then Start opens the list right here as
/// one focused checklist. Nothing is saved until Start.
private struct QuickListNewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let onDelete: (QuickList) -> Void
    @State private var title = ""
    @State private var text = ""
    @State private var created: QuickList?

    private var parsed: [QuickListItem] { QuickList.parsedItems(from: text) }

    private var countText: String {
        let count = parsed.count
        if count == 0 { return "" }
        if count > QuickList.maxItems { return "\(count) lines. The first \(QuickList.maxItems) will be used." }
        return count == 1 ? "1 item" : "\(count) items"
    }

    var body: some View {
        NavigationStack {
            if let created {
                QuickListView(list: created, onDelete: onDelete)
            } else {
                Form {
                    Section {
                        TextField("Name (optional)", text: $title)
                    }
                    Section {
                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("One item per line. You can paste a list.")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $text)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 180)
                        }
                    } footer: {
                        Text(countText)
                    }
                }
                .anchorSettingsStyle()
                .navigationTitle("Quick list")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Start", action: start)
                            .disabled(parsed.isEmpty)
                    }
                }
            }
        }
    }

    private func start() {
        let items = Array(parsed.prefix(QuickList.maxItems))
        guard !items.isEmpty else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = QuickList(title: name.isEmpty ? QuickList.defaultTitle() : name, items: items)
        modelContext.insert(list)
        created = list
    }
}

/// One list as a single focused checklist: tap an item to tick it, swipe to
/// remove it, add more at the bottom. Ticking the last item moves the list to
/// the Archive; unticking one brings it back. Nothing is counted against you.
private struct QuickListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]
    @Bindable var list: QuickList
    /// Asks whoever opened this screen to delete the list once it has closed,
    /// so this screen never reads a list that is already gone.
    let onDelete: (QuickList) -> Void
    @State private var newItem = ""
    @State private var confirmingDelete = false

    var body: some View {
        List {
            if list.isArchived {
                Text("All ticked off. This list is in the Archive.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(list.items) { item in
                row(item)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .anchorBackground()
        .safeAreaInset(edge: .bottom) { addBar }
        .navigationTitle(list.displayTitle)
        .guideButton("now.quick-list", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: moveToTasks) {
                        Label("Move open items to Tasks", systemImage: "arrow.right.circle")
                    }
                    .disabled(list.openCount == 0)
                    if list.doneCount > 0 {
                        Button {
                            withAnimation(.snappy) { list.startAgain() }
                        } label: {
                            Label("Start again", systemImage: "arrow.counterclockwise")
                        }
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete list", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .confirmationDialog("Delete this list?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete list", role: .destructive) {
                onDelete(list)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        }
    }

    private func row(_ item: QuickListItem) -> some View {
        Button {
            withAnimation(.snappy) { list.setItem(item.id, done: !item.isDone) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isDone ? Anchor.Theme.sage : Anchor.Theme.accent)
                Text(item.text)
                    .font(.system(.title3, design: .rounded))
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.text)
        .accessibilityValue(item.isDone ? "Ticked" : "Not ticked")
        .anchorDeletable {
            withAnimation(.snappy) { list.removeItem(item.id) }
        }
    }

    private var addBar: some View {
        HStack(spacing: 8) {
            TextField("Add an item", text: $newItem)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addItem)
            Button("Add", action: addItem)
                .buttonStyle(Anchor.SecondaryButtonStyle())
                .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.thinMaterial)
    }

    private func addItem() {
        let new = QuickList.parsedItems(from: newItem)
        guard !new.isEmpty else { return }
        newItem = ""
        withAnimation(.snappy) { list.addItems(new) }
    }

    /// Copies what is still open into Tasks, and takes those items off the
    /// list, so nothing shows twice. What was ticked stays on the list. A list
    /// left with nothing is removed when this screen closes.
    private func moveToTasks() {
        let open = list.items.filter { !$0.isDone }
        guard !open.isEmpty else { return }
        var order = (tasks.map(\.sortOrder).max() ?? -1) + 1
        for item in open {
            modelContext.insert(TaskItem(title: item.text, sortOrder: order))
            order += 1
        }
        list.items.removeAll { !$0.isDone }
        list.syncArchive()
        dismiss()
    }
}

/// Lists that were ticked off to the end. Tap one to look at it, or untick an
/// item (or use Start again) to use it again.
private struct QuickListArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuickList.createdAt, order: .reverse) private var lists: [QuickList]
    @State private var opened: QuickList?
    @State private var toDelete: QuickList?

    private var archived: [QuickList] {
        lists.filter(\.isArchived).sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }
    }

    var body: some View {
        Group {
            if archived.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "archivebox",
                        title: "Nothing in the Archive",
                        message: "A quick list moves here by itself when you tick off the last item.",
                        tint: Anchor.Theme.sage
                    )
                    .padding()
                }
            } else {
                List {
                    ForEach(archived) { list in
                        Button { opened = list } label: {
                            QuickListCard(list: list)
                        }
                        .buttonStyle(.plain)
                        .anchorDeletable { modelContext.delete(list) }
                        .anchorCardRow()
                    }
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Archive")
        .guideButton("now.quick-list", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $opened, onDismiss: finish) { list in
            NavigationStack {
                QuickListView(list: list, onDelete: { toDelete = $0 })
            }
        }
    }

    private func finish() {
        let deleting = toDelete
        toDelete = nil
        modelContext.finishQuickLists(deleting: deleting, among: lists)
    }
}
