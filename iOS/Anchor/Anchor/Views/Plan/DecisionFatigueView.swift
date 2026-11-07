//
//  DecisionFatigueView.swift
//  Anchor
//
//  Previously plain view @State — reset to empty on every launch, which is
//  the "presets don't seem to save" bug. Now real SwiftData models
//  (DecisionPresetCategory/DecisionPresetChoice), and restructured per
//  feedback: each choice is a name in a menu, and tapping it opens a real
//  click-through sequence (reusing StepByStepRunnerView, the same UI as
//  Grounding Tools) rather than a flat list of text. A choice with no
//  steps written just shows as a flat option with nothing to click
//  through — steps are optional, not required.
//

import SwiftUI
import SwiftData

/// Decision presets as something to browse: each category is a card listing
/// its options. Tapping an option that has steps runs it step by step (using
/// it, not editing it). Adding, renaming, reordering and deleting live
/// behind Edit (`DecisionPresetsEditorView`).
struct DecisionFatigueView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DecisionPresetCategory.sortOrder) private var categories: [DecisionPresetCategory]
    @State private var showingEditor = false
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
                    ) { showingEditor = true }
                } else {
                    Text("Set up once when you're not exhausted, so a depleted morning doesn't have to include deciding anything.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(categories) { category in
                        DecisionCategoryCard(category: category) { choice in
                            runningChoice = choice
                        }
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
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit presets") {
                DecisionPresetsEditorView()
            }
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
}

private struct DecisionCategoryCard: View {
    let category: DecisionPresetCategory
    let onRun: (DecisionPresetChoice) -> Void

    private var sortedChoices: [DecisionPresetChoice] {
        category.choices.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func hasSteps(_ choice: DecisionPresetChoice) -> Bool {
        !choice.steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 10) {
                Anchor.SectionHeader(icon: "checklist", title: category.name.isEmpty ? "Untitled" : category.name)
                if sortedChoices.isEmpty {
                    Text("No options yet.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(sortedChoices) { choice in
                        if hasSteps(choice) {
                            Button { onRun(choice) } label: {
                                choiceRow(choice, runnable: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            choiceRow(choice, runnable: false)
                        }
                    }
                }
            }
        }
    }

    private func choiceRow(_ choice: DecisionPresetChoice, runnable: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: runnable ? "list.number" : "circle")
                .foregroundStyle(Anchor.Theme.accent)
            Text(choice.name.isEmpty ? "Untitled" : choice.name)
                .font(.system(.body, design: .rounded))
            Spacer()
            if runnable {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// The presets editor: categories and options, add/rename/delete. Presented
/// from `DecisionFatigueView` via Edit, never browsed to directly.
private struct DecisionPresetsEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DecisionPresetCategory.sortOrder) private var categories: [DecisionPresetCategory]
    @State private var newCategoryName = ""
    @State private var showAddCategory = false

    var body: some View {
        List {
            Section {
                Text("Set these up once when you're not exhausted, so a depleted morning doesn't have to include deciding anything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            ForEach(categories) { category in
                Section(category.name) {
                    ForEach(category.choices.sorted { $0.sortOrder < $1.sortOrder }) { choice in
                        NavigationLink {
                            DecisionChoiceEditorView(choice: choice)
                        } label: {
                            HStack {
                                Image(systemName: choice.steps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "circle" : "list.number")
                                    .foregroundStyle(Anchor.Theme.accent)
                                Text(choice.name.isEmpty ? "Untitled" : choice.name)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let sorted = category.choices.sorted { $0.sortOrder < $1.sortOrder }
                        for index in offsets { modelContext.delete(sorted[index]) }
                    }

                    Button {
                        let choice = DecisionPresetChoice(
                            name: "New option",
                            sortOrder: category.choices.count,
                            category: category
                        )
                        modelContext.insert(choice)
                    } label: {
                        Label("Add option", systemImage: "plus.circle")
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(categories[index]) }
            }

            Section {
                if showAddCategory {
                    HStack {
                        TextField("Category name (e.g. Snacks)", text: $newCategoryName)
                        Button("Add") {
                            let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            modelContext.insert(DecisionPresetCategory(name: trimmed, sortOrder: categories.count))
                            newCategoryName = ""
                            showAddCategory = false
                        }
                    }
                } else {
                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add a category", systemImage: "folder.badge.plus")
                    }
                }
            }
        }
    }
}

private struct DecisionChoiceEditorView: View {
    @Bindable var choice: DecisionPresetChoice
    @State private var showRunner = false
    @State private var newStepText = ""

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
                Text("Steps (optional)")
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
        .anchorSettingsStyle()
        .navigationTitle(choice.name.isEmpty ? "Option" : choice.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .fullScreenCover(isPresented: $showRunner) {
            StepByStepRunnerView(title: choice.name, stepsText: choice.steps, tint: Anchor.Theme.accent)
        }
    }
}
