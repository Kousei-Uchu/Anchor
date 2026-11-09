//
//  BridgeDraftListView.swift
//  Anchor
//
//  Built up between sessions. "Resolved" just means "already brought this
//  up" — a checkbox, not a score, and resolved items stay visible (toggled,
//  not hidden) so the running history is still there to export.
//
//  Tap an item to reword it, the plus adds one, and Delete is inside the item
//  and in its long-press menu. Ticking an item off stays on the card, because
//  it is a quick action, not editing.
//

import SwiftUI
import SwiftData

struct BridgeDraftListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BridgeDraftItem.createdAt, order: .reverse) private var items: [BridgeDraftItem]
    @Query(sort: \AppointmentSeries.sortOrder) private var providers: [AppointmentSeries]
    @State private var editing: BridgeDraftItem?
    @State private var toDelete: BridgeDraftItem?
    @State private var showingExport = false
    /// Whose things are shown. Nil shows everything. Not remembered.
    @State private var filterID: UUID?

    /// The provider being filtered on, if they still exist.
    private var filterProvider: AppointmentSeries? {
        providers.first { $0.id == filterID }
    }

    /// With a provider chosen, what is for them and for anyone: the same
    /// set their export would hold.
    private var shown: [BridgeDraftItem] {
        guard let filterProvider else { return items }
        return items.filter { $0.isFor(filterProvider.id, in: providers) }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "doc.text.fill",
                        title: "Nothing to bring up yet",
                        message: "Add things here as they come up, whenever they come up. They'll be waiting for your next session.",
                        actionTitle: "Add something",
                        tint: Anchor.Theme.accent
                    ) { startNew() }
                    .padding()
                }
            } else {
                List {
                    if shown.isEmpty, let filterProvider {
                        Text("Nothing here for \(filterProvider.displayName) yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    ForEach(shown) { item in
                        BridgeDraftItemCard(item: item, providerName: item.provider(in: providers)?.displayName) { editing = item }
                            .anchorDeletable { modelContext.delete(item) }
                            .anchorCardRow()
                    }
                }
                .listStyle(.plain)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let filterProvider {
                HStack(alignment: .firstTextBaseline) {
                    Label("Showing what is for \(filterProvider.displayName) and for anyone", systemImage: "person.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Show all") { filterID = nil }
                        .font(.footnote.weight(.semibold))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)
            }
        }
        .anchorBackground()
        .navigationTitle("Bridge draft")
        .guideButton("bridge.things-to-raise", tab: .bridge)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if providers.count > 1 {
                    Menu {
                        Picker("Show", selection: $filterID) {
                            Text("Everything").tag(UUID?.none)
                            ForEach(providers) { provider in
                                Text(provider.displayName).tag(UUID?.some(provider.id))
                            }
                        }
                    } label: {
                        Image(systemName: filterProvider == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Show things for one person")
                }
                Button {
                    showingExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export")
                Anchor.AddToolbarButton(label: "Add something") { startNew() }
            }
        }
        .sheet(isPresented: $showingExport) {
            BridgeExportView()
        }
        .sheet(item: $editing, onDismiss: finishEditing) { item in
            BridgeDraftItemEditorSheet(item: item) { toDelete = item }
        }
    }

    private func startNew() {
        let new = BridgeDraftItem(text: "", providerID: filterProvider?.id)
        modelContext.insert(new)
        editing = new
    }

    /// Runs once the editor has closed, so the editor never reads an item that
    /// is already gone. One added and left blank is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for item in items where item !== deleting
            && item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(item)
        }
    }
}

private struct BridgeDraftItemCard: View {
    @Bindable var item: BridgeDraftItem
    /// Who it is for, when it is for one person. Nil for anyone.
    let providerName: String?
    let onEdit: () -> Void

    private var footnote: String {
        let date = item.createdAt.formatted(date: .abbreviated, time: .omitted)
        guard let providerName else { return date }
        return "For \(providerName) · \(date)"
    }

    var body: some View {
        Anchor.Card {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    item.isResolved.toggle()
                } label: {
                    Image(systemName: item.isResolved ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isResolved ? Anchor.Theme.sage : Anchor.Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isResolved ? "Mark as not brought up" : "Mark as brought up")

                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 4) {
                        if item.isQuestion {
                            Label("Question", systemImage: "questionmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.text.isEmpty ? "Untitled" : item.text)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(item.isResolved ? .secondary : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                        if item.isQuestion, !item.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Answer: \(item.answer)")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(footnote)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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

private struct BridgeDraftItemEditorSheet: View {
    @Bindable var item: BridgeDraftItem
    let onDelete: () -> Void
    @Query(sort: \AppointmentSeries.sortOrder) private var providers: [AppointmentSeries]

    /// Shown with two or more providers, or when the item is already for
    /// one, so a person with a single provider is never asked.
    private var showsWho: Bool {
        providers.count > 1 || item.provider(in: providers) != nil
    }

    /// An item whose provider was removed reads as for anyone.
    private var whoBinding: Binding<UUID?> {
        Binding(
            get: { item.provider(in: providers)?.id },
            set: { item.providerID = $0 }
        )
    }

    var body: some View {
        Anchor.ItemEditorSheet(
            title: item.text.isEmpty ? "New item" : "Item",
            onDelete: onDelete,
            deleteQuestion: "Delete this item?"
        ) {
            Form {
                Section {
                    TextField("Something to bring up next session", text: $item.text, axis: .vertical)
                        .lineLimit(3...8)
                }
                if showsWho {
                    Section {
                        Picker("Who it is for", selection: whoBinding) {
                            Text("Anyone").tag(UUID?.none)
                            ForEach(providers) { provider in
                                Text(provider.displayName).tag(UUID?.some(provider.id))
                            }
                        }
                    }
                }
                Section {
                    Toggle("It is a question to ask", isOn: $item.isQuestion)
                }
                if item.isQuestion {
                    Section("Answer") {
                        TextField("What they said, once you have asked", text: $item.answer, axis: .vertical)
                            .lineLimit(3...8)
                    }
                }
                Section {
                    Toggle("Already brought up", isOn: $item.isResolved)
                }
            }
        }
    }
}


// MARK: - Personal goals

/// The person's own goals, in their own words, each with short dated notes
/// along the way. No scores, no percentages and no framing as treatment.
/// Tap a goal to open it, the plus adds one, and Delete is in the goal and in
/// its long-press menu. Reorder shows with two or more goals being worked on,
/// because the order is theirs to set. Goals that are reached or set aside
/// move to their own groups, and moving one back is a change in its sheet.
struct PersonalGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonalGoal.sortOrder) private var goals: [PersonalGoal]
    @State private var editing: PersonalGoal?
    @State private var toDelete: PersonalGoal?

    private func group(_ status: GoalStatus) -> [PersonalGoal] {
        goals.filter { $0.status == status }
    }

    var body: some View {
        Group {
            if goals.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "flag.fill",
                        title: "Nothing here yet",
                        message: "Goals of your own, in your own words, with a few notes along the way. There are no scores and nothing to keep up.",
                        actionTitle: "Write one",
                        tint: Anchor.Theme.sage
                    ) { startNew() }
                    .padding()
                }
            } else {
                List {
                    ForEach(group(.active)) { goal in
                        row(goal)
                    }
                    .onMove(perform: move)

                    if !group(.reached).isEmpty {
                        Section {
                            ForEach(group(.reached)) { goal in row(goal) }
                        } header: {
                            Text("Reached")
                        }
                        .listRowBackground(Color.clear)
                    }
                    if !group(.setAside).isEmpty {
                        Section {
                            ForEach(group(.setAside)) { goal in row(goal) }
                        } header: {
                            Text("Set aside for now")
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Personal goals")
        .guideButton("bridge.goals", tab: .bridge)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if group(.active).count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Anchor.AddToolbarButton(label: "Write a goal") { startNew() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { goal in
            PersonalGoalEditorSheet(goal: goal) { toDelete = goal }
        }
    }

    private func row(_ goal: PersonalGoal) -> some View {
        Button { editing = goal } label: {
            Anchor.Card(accentColor: Anchor.Theme.sage) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title.isEmpty ? "Untitled" : goal.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(goal.status == .active ? .primary : .secondary)
                        .multilineTextAlignment(.leading)
                    if let line = SafetyPlanSections.firstLine(goal.why) {
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if let caption = caption(goal) {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the goal")
        .anchorDeletable { modelContext.delete(goal) }
        .anchorCardRow()
    }

    private func caption(_ goal: PersonalGoal) -> String? {
        var parts: [String] = []
        if goal.usesSMART { parts.append("SMART") }
        if !goal.notes.isEmpty { parts.append(goal.notes.count == 1 ? "1 note" : "\(goal.notes.count) notes") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private func startNew() {
        let new = PersonalGoal(sortOrder: (goals.map(\.sortOrder).max() ?? -1) + 1)
        modelContext.insert(new)
        editing = new
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = group(.active)
        reordered.move(fromOffsets: offsets, toOffset: destination)
        let others = goals.filter { $0.status != .active }
        for (index, goal) in (reordered + others).enumerated() { goal.sortOrder = index }
    }

    /// Runs once the sheet has closed, so it never reads a goal that is
    /// already gone. A goal added and left with no title and no why is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for goal in goals where goal !== deleting
            && goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && goal.why.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && goal.smartSpecific.isEmpty && goal.smartMeasurable.isEmpty
            && goal.smartAchievable.isEmpty && goal.smartTimeBound.isEmpty
            && goal.notes.isEmpty {
            modelContext.delete(goal)
        }
    }
}

private struct PersonalGoalEditorSheet: View {
    @Bindable var goal: PersonalGoal
    let onDelete: () -> Void
    @State private var newNote = ""

    private var sortedNotes: [GoalNote] { goal.notes.sorted { $0.date > $1.date } }

    private var trimmedNewNote: String {
        newNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Changes whenever any part of the SMART frame changes, so the goal's edited time follows it.
    private var smartSignature: String {
        [goal.usesSMART ? "1" : "0", goal.smartSpecific, goal.smartMeasurable,
         goal.smartAchievable, goal.smartTimeBound].joined(separator: "\u{1F}")
    }

    private func smartField(_ letter: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(letter)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(1...4)
        }
    }

    var body: some View {
        Anchor.ItemEditorSheet(
            title: goal.title.isEmpty ? "New goal" : "Goal",
            onDelete: onDelete,
            deleteQuestion: "Delete this goal and its notes?"
        ) {
            Form {
                Section {
                    TextField("What I want", text: $goal.title, axis: .vertical)
                        .lineLimit(1...4)
                    TextField(goal.usesSMART ? "Relevant: why it matters to me" : "Why it matters to me",
                              text: $goal.why, axis: .vertical)
                        .lineLimit(2...8)
                }
                Section {
                    Toggle("Use the SMART frame", isOn: $goal.usesSMART)
                } footer: {
                    Text("Specific, Measurable, Achievable, Relevant, Time-bound. It is optional, and any part can stay blank.")
                }
                if goal.usesSMART {
                    Section {
                        smartField("Specific", prompt: "What exactly would I do?", text: $goal.smartSpecific)
                        smartField("Measurable", prompt: "How would I know I am getting somewhere?", text: $goal.smartMeasurable)
                        smartField("Achievable", prompt: "What makes it doable for me right now?", text: $goal.smartAchievable)
                        smartField("Time-bound", prompt: "When, in my own words, if that helps", text: $goal.smartTimeBound)
                    } footer: {
                        Text("Relevant is the box above. Time-bound can stay open: no date is needed, and nothing is ever marked late.")
                    }
                }
                Section {
                    Picker("Where it is", selection: Binding(
                        get: { goal.status },
                        set: { goal.status = $0; goal.lastEditedAt = .now }
                    )) {
                        ForEach(GoalStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }
                Section("Notes along the way") {
                    ForEach(sortedNotes) { note in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.text)
                            Text(note.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        let sorted = sortedNotes
                        let ids = Set(offsets.map { sorted[$0].id })
                        goal.notes.removeAll { ids.contains($0.id) }
                        goal.lastEditedAt = .now
                    }
                    HStack(alignment: .top) {
                        TextField("Add a note", text: $newNote, axis: .vertical)
                        Button("Add") {
                            goal.notes.append(GoalNote(text: trimmedNewNote))
                            goal.lastEditedAt = .now
                            newNote = ""
                        }
                        .buttonStyle(.borderless)
                        .disabled(trimmedNewNote.isEmpty)
                    }
                }
            }
            .onChange(of: goal.title) { _, _ in goal.lastEditedAt = .now }
            .onChange(of: goal.why) { _, _ in goal.lastEditedAt = .now }
            .onChange(of: smartSignature) { _, _ in goal.lastEditedAt = .now }
        }
    }
}
