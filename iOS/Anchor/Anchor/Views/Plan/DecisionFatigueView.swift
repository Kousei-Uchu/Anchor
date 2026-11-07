//
//  DecisionFatigueView.swift
//  Anchor
//
//  Previously plain view @State — reset to empty on every launch, which is
//  the "presets don't seem to save" bug. Now real SwiftData models
//  (DecisionPresetCategory/DecisionPresetChoice), and restructured per
//  feedback: each choice is a name in a menu, and a choice with steps can be
//  run as a real click-through sequence (reusing StepByStepRunnerView, the
//  same UI as Grounding Tools) rather than a flat list of text. A choice with
//  no steps written just shows as a flat option with nothing to click
//  through — steps are optional, not required.
//
//  Editing follows the app-wide pattern: tap an option to edit it, tap a
//  category's name to rename it, the plus in the bar adds a category and the
//  plus inside a card adds an option. Delete is in each editor and, for an
//  option, in its long-press menu. A play button on an option with steps runs
//  it; that is using it, not editing it.
//

import SwiftUI
import SwiftData

/// Decision presets as cards: each category lists its options.
struct DecisionFatigueView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DecisionPresetCategory.sortOrder) private var categories: [DecisionPresetCategory]
    @State private var editingCategory: DecisionPresetCategory?
    @State private var editingChoice: DecisionPresetChoice?
    @State private var categoryToDelete: DecisionPresetCategory?
    @State private var choiceToDelete: DecisionPresetChoice?
    @State private var runningChoice: DecisionPresetChoice?

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if categories.isEmpty {
                    Anchor.EmptyState(
                        icon: "checklist",
                        title: "No presets yet",
                        message: "Set these up once when you're not exhausted, so a depleted morning doesn't have to include deciding anything.",
                        actionTitle: "Add a category",
                        tint: Anchor.Theme.accent
                    ) { startNewCategory() }
                } else {
                    Text("Set up once when you're not exhausted, so a depleted morning doesn't have to include deciding anything.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(categories) { category in
                        DecisionCategoryCard(
                            category: category,
                            onEditCategory: { editingCategory = category },
                            onAddOption: { startNewOption(in: category) },
                            onEditChoice: { editingChoice = $0 },
                            onRun: { runningChoice = $0 },
                            onDeleteChoice: { modelContext.delete($0) }
                        )
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Decision-fatigue presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.AddToolbarButton(label: "Add a category") { startNewCategory() }
            }
        }
        .sheet(item: $editingCategory, onDismiss: finishEditing) { category in
            DecisionCategoryEditor(category: category) { categoryToDelete = category }
        }
        .sheet(item: $editingChoice, onDismiss: finishEditing) { choice in
            DecisionChoiceEditor(choice: choice) { choiceToDelete = choice }
        }
        .fullScreenCover(item: $runningChoice) { choice in
            StepByStepRunnerView(title: choice.name, stepsText: choice.steps, tint: Anchor.Theme.accent)
        }
        .onAppear { seedDefaultsIfNeeded() }
    }

    /// Seeds the three categories from the original request (Outfit, Food,
    /// Morning routine) only the very first time — after that, the user's
    /// own categories (including deletions/renames/additions) are
    /// authoritative.
    private func seedDefaultsIfNeeded() {
        guard categories.isEmpty else { return }
        for (index, name) in ["Outfit", "Food", "Morning routine"].enumerated() {
            modelContext.insert(DecisionPresetCategory(name: name, sortOrder: index))
        }
    }

    private func startNewCategory() {
        let new = DecisionPresetCategory(name: "", sortOrder: categories.count)
        modelContext.insert(new)
        editingCategory = new
    }

    private func startNewOption(in category: DecisionPresetCategory) {
        let new = DecisionPresetChoice(name: "", sortOrder: category.choices.count, category: category)
        modelContext.insert(new)
        editingChoice = new
    }

    /// Runs once an editor has closed. Deleting here, not while the editor is
    /// still on screen, keeps the editor from reading something that is
    /// already gone. A category or option added and then left blank is dropped.
    private func finishEditing() {
        let deletingChoice = choiceToDelete
        let deletingCategory = categoryToDelete
        choiceToDelete = nil
        categoryToDelete = nil
        if let deletingChoice { modelContext.delete(deletingChoice) }
        if let deletingCategory { modelContext.delete(deletingCategory) }

        for category in categories where category !== deletingCategory {
            for choice in category.choices where choice !== deletingChoice && isBlank(choice) {
                modelContext.delete(choice)
            }
            if category.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && category.choices.isEmpty {
                modelContext.delete(category)
            }
        }
    }

    private func isBlank(_ choice: DecisionPresetChoice) -> Bool {
        choice.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && choice.steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct DecisionCategoryCard: View {
    let category: DecisionPresetCategory
    let onEditCategory: () -> Void
    let onAddOption: () -> Void
    let onEditChoice: (DecisionPresetChoice) -> Void
    let onRun: (DecisionPresetChoice) -> Void
    let onDeleteChoice: (DecisionPresetChoice) -> Void

    private var sortedChoices: [DecisionPresetChoice] {
        category.choices.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func hasSteps(_ choice: DecisionPresetChoice) -> Bool {
        !choice.steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 10) {
                Button(action: onEditCategory) {
                    HStack {
                        Anchor.SectionHeader(icon: "checklist", title: category.name.isEmpty ? "Untitled" : category.name)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the category editor")

                if sortedChoices.isEmpty {
                    Text("No options yet.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(sortedChoices) { choice in
                        choiceRow(choice)
                            .anchorDeletable { onDeleteChoice(choice) }
                    }
                }

                Button(action: onAddOption) {
                    Label("Add an option", systemImage: "plus.circle")
                }
                .buttonStyle(Anchor.SecondaryButtonStyle())
                .padding(.top, 2)
            }
        }
    }

    private func choiceRow(_ choice: DecisionPresetChoice) -> some View {
        HStack(spacing: 10) {
            Button { onEditChoice(choice) } label: {
                HStack(spacing: 10) {
                    Image(systemName: hasSteps(choice) ? "list.number" : "circle")
                        .foregroundStyle(Anchor.Theme.accent)
                    Text(choice.name.isEmpty ? "Untitled" : choice.name)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the editor")

            if hasSteps(choice) {
                Button { onRun(choice) } label: {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(Anchor.Theme.accent)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Try \(choice.name.isEmpty ? "this option" : choice.name) step by step")
            }
        }
    }
}

/// A category in one sheet: its name, and Delete.
private struct DecisionCategoryEditor: View {
    @Bindable var category: DecisionPresetCategory
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: category.name.isEmpty ? "New category" : category.name,
            onDelete: onDelete,
            deleteTitle: "Delete category",
            deleteQuestion: "Delete this category and its options?"
        ) {
            Form {
                Section("Name") {
                    TextField("Category name (e.g. Snacks)", text: $category.name)
                }
            }
        }
    }
}

/// One option in one sheet: its name, its steps, and Delete.
private struct DecisionChoiceEditor: View {
    @Bindable var choice: DecisionPresetChoice
    let onDelete: () -> Void
    @State private var showRunner = false
    @State private var newStepText = ""
    @State private var editMode: EditMode = .inactive

    private var hasSteps: Bool {
        !choice.steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `choice.steps` stays a single newline-joined string underneath (so
    /// StepByStepRunnerView's parsing doesn't need to change), but the
    /// editor itself works as a real editable list — one row per step,
    /// add/delete/reorder — matching the same pattern already used for
    /// de-escalation scripts, instead of one big free-text box.
    private var stepList: [String] {
        choice.steps.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        Anchor.ItemEditorSheet(
            title: choice.name.isEmpty ? "New option" : choice.name,
            onDelete: onDelete,
            deleteTitle: "Delete option",
            deleteQuestion: "Delete this option?"
        ) {
            Form {
                Section("Name") {
                    TextField("e.g. Chicken tenders", text: $choice.name)
                }

                Section {
                    ForEach(stepList.indices, id: \.self) { index in
                        TextField("Step", text: Binding(
                            get: { stepList[index] },
                            set: { newText in
                                var current = stepList
                                current[index] = newText
                                choice.steps = current.joined(separator: "\n")
                            }
                        ), axis: .vertical)
                        .deleteDisabled(editMode.isEditing)
                    }
                    .onDelete { offsets in
                        var current = stepList
                        current.remove(atOffsets: offsets)
                        choice.steps = current.joined(separator: "\n")
                    }
                    .onMove { source, destination in
                        var current = stepList
                        current.move(fromOffsets: source, toOffset: destination)
                        choice.steps = current.joined(separator: "\n")
                    }

                    HStack {
                        TextField("Add a step", text: $newStepText, axis: .vertical)
                        Button("Add") {
                            let trimmed = newStepText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            var current = stepList
                            current.append(trimmed)
                            choice.steps = current.joined(separator: "\n")
                            newStepText = ""
                        }
                    }
                } header: {
                    HStack {
                        Text("Steps (optional)")
                        Spacer()
                        if stepList.count > 1 {
                            Button(editMode.isEditing ? "Done" : "Reorder") {
                                withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                            }
                            .textCase(nil)
                        }
                    }
                } footer: {
                    Text("Leave empty if this is just a flat option with nothing to click through. For example: \"Get packet from freezer\" as one step, \"Put 4-6 in air fryer\" as the next.")
                }

                if hasSteps {
                    Section {
                        Button {
                            showRunner = true
                        } label: {
                            Label("Try it step by step", systemImage: "play.fill")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .fullScreenCover(isPresented: $showRunner) {
                StepByStepRunnerView(title: choice.name, stepsText: choice.steps, tint: Anchor.Theme.accent)
            }
        }
    }
}

// MARK: - Presets: decisions and routines in one screen

/// Decision presets and routines share one screen, with a switch at the top.
/// Each part keeps its own title and plus button.
struct PresetsView: View {
    enum Part: String, CaseIterable, Identifiable {
        case decisions = "Decisions"
        case routines = "Routines"
        var id: Self { self }
    }

    @State private var part: Part

    init(start: Part = .decisions) {
        _part = State(initialValue: start)
    }

    var body: some View {
        Group {
            switch part {
            case .decisions: DecisionFatigueView()
            case .routines: RoutinesView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Presets", selection: $part) {
                ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

// MARK: - Routines

/// Routines as cards: a name, a one-line summary, and a play button. Tap a
/// card to edit it, the plus adds one, and Delete is inside the editor and in
/// the long-press menu. Running a routine is using it, not editing it, and
/// records nothing.
struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @State private var editing: Routine?
    @State private var toDelete: Routine?
    @State private var running: Routine?

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if routines.isEmpty {
                    Anchor.EmptyState(
                        icon: "list.number",
                        title: "No routines yet",
                        message: "A routine is a list of steps you do in the same order each time, like a school morning. Run it and Anchor shows one step at a time.",
                        actionTitle: "Add a routine",
                        tint: Anchor.Theme.accent
                    ) { startNew() }
                } else {
                    ForEach(routines) { routine in
                        RoutineCard(
                            routine: routine,
                            onEdit: { editing = routine },
                            onRun: { running = routine }
                        )
                        .contextMenu {
                            Button { editing = routine } label: { Label("Edit", systemImage: "pencil") }
                            Button(role: .destructive) { modelContext.delete(routine) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.AddToolbarButton(label: "Add a routine") { startNew() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { routine in
            RoutineEditor(routine: routine) { toDelete = routine }
        }
        .fullScreenCover(item: $running) { routine in
            RoutineRunnerView(routine: routine)
        }
    }

    private func startNew() {
        let new = Routine(name: "")
        modelContext.insert(new)
        editing = new
    }

    /// Runs once the editor has closed, so it never reads a routine that is
    /// already gone. A routine added and then left blank is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for routine in routines where routine !== deleting && routine.isBlank {
            modelContext.delete(routine)
        }
    }
}

private struct RoutineCard: View {
    let routine: Routine
    let onEdit: () -> Void
    let onRun: () -> Void

    var body: some View {
        Anchor.Card {
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.displayName)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(routine.summaryText ?? "No steps yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the editor")

                if !routine.writtenSteps.isEmpty {
                    Button(action: onRun) {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Anchor.Theme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Run \(routine.displayName)")
                }
            }
        }
    }
}

/// One routine in one sheet: its name, its steps with optional times, and Delete.
private struct RoutineEditor: View {
    @Bindable var routine: Routine
    let onDelete: () -> Void
    @State private var newStepText = ""
    @State private var editMode: EditMode = .inactive
    @State private var showRunner = false

    var body: some View {
        Anchor.ItemEditorSheet(
            title: routine.name.isEmpty ? "New routine" : routine.name,
            onDelete: onDelete,
            deleteTitle: "Delete routine",
            deleteQuestion: "Delete this routine?"
        ) {
            Form {
                Section("Name") {
                    TextField("e.g. School mornings", text: $routine.name)
                }

                Section {
                    ForEach($routine.steps) { $step in
                        HStack(alignment: .top, spacing: 8) {
                            TextField("Step", text: $step.text, axis: .vertical)
                            Menu {
                                Picker("How long", selection: $step.minutes) {
                                    ForEach(Routine.minuteChoices, id: \.self) { minutes in
                                        Text(minutes == 0 ? "No estimate" : TaskItem.durationText(minutes))
                                            .tag(minutes)
                                    }
                                }
                            } label: {
                                Text(step.minutes == 0 ? "Time" : TaskItem.durationText(step.minutes))
                                    .font(.footnote)
                                    .foregroundStyle(step.minutes == 0 ? .secondary : Anchor.Theme.accent)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(.quaternary, in: Capsule())
                            }
                            .accessibilityLabel(step.minutes == 0 ? "Set how long this step takes" : "Takes \(TaskItem.durationText(step.minutes))")
                        }
                        .deleteDisabled(editMode.isEditing)
                    }
                    .onDelete { routine.steps.remove(atOffsets: $0) }
                    .onMove { routine.steps.move(fromOffsets: $0, toOffset: $1) }

                    if routine.steps.count < Routine.maxSteps {
                        HStack {
                            TextField("Add a step", text: $newStepText, axis: .vertical)
                            Button("Add") { addStep() }
                        }
                    }
                } header: {
                    HStack {
                        Text("Steps")
                        Spacer()
                        if routine.steps.count > 1 {
                            Button(editMode.isEditing ? "Done" : "Reorder") {
                                withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                            }
                            .textCase(nil)
                        }
                    }
                } footer: {
                    if let summary = routine.summaryText { Text(summary) }
                }

                if !routine.writtenSteps.isEmpty {
                    Section {
                        Button { showRunner = true } label: {
                            Label("Run it", systemImage: "play.fill")
                        }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .fullScreenCover(isPresented: $showRunner) {
                RoutineRunnerView(routine: routine)
            }
        }
    }

    /// A pasted block with several lines becomes several steps.
    private func addStep() {
        let added = Routine.parsedSteps(from: newStepText)
        guard !added.isEmpty else { return }
        let room = max(0, Routine.maxSteps - routine.steps.count)
        routine.steps.append(contentsOf: added.prefix(room))
        newStepText = ""
    }
}

/// Run it: one step at a time, like the grounding tools, with the step's rough
/// time shown if it has one. Nothing is timed, scored or saved, and a step can
/// take as long as it takes.
struct RoutineRunnerView: View {
    let routine: Routine
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    private var steps: [RoutineStep] { routine.writtenSteps }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if steps.isEmpty {
                    Spacer()
                    Text("No steps written for this yet.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    let safeIndex = min(index, steps.count - 1)
                    let step = steps[safeIndex]

                    ProgressView(value: Double(safeIndex + 1), total: Double(steps.count))
                        .tint(Anchor.Theme.accent)
                        .padding(.horizontal)

                    Text("Step \(safeIndex + 1) of \(steps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    VStack(spacing: 10) {
                        Text(step.text)
                            .font(.system(.title2, design: .rounded))
                            .multilineTextAlignment(.center)
                        if step.minutes > 0 {
                            Text("About \(TaskItem.durationText(step.minutes))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 28)

                    Spacer()

                    HStack(spacing: 12) {
                        if safeIndex > 0 {
                            Button("Back") { withAnimation { index = safeIndex - 1 } }
                                .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.accent))
                        }
                        Button(safeIndex == steps.count - 1 ? "Done" : "Next") {
                            if safeIndex == steps.count - 1 {
                                dismiss()
                            } else {
                                withAnimation { index = safeIndex + 1 }
                            }
                        }
                        .buttonStyle(Anchor.PrimaryButtonStyle(tint: Anchor.Theme.accent))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(routine.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .anchorBackground()
        }
    }
}
