//
//  GroundingToolsEditorView.swift
//  Anchor
//
//  Now's empty state says "add your own tools in Plan" — this is that
//  screen. Still user-authored only: no seeded suggestions here either.
//
//  Editing follows the app-wide pattern: tap a tool to edit it, the plus adds
//  one, and Delete is in the editor and in the long-press menu. Order matters
//  (it is the order on Now), so there is a labelled Reorder button. A tool
//  with written steps has a play button on its card to run it right here;
//  that is using it, not editing it.
//

import SwiftUI
import SwiftData

/// Grounding tools as cards, with each tool's kind and when it is relevant
/// shown as labels.
struct GroundingToolsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroundingTool.sortOrder) private var tools: [GroundingTool]
    @State private var editingTool: GroundingTool?
    @State private var toolToDelete: GroundingTool?
    @State private var runningTool: GroundingTool?

    var body: some View {
        Group {
            if tools.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "leaf.fill",
                        title: "No grounding tools yet",
                        message: "Add the things that actually help you settle: a few steps, or a link to a playlist or app. They'll show up on Now.",
                        actionTitle: "Add a tool",
                        tint: Anchor.Theme.sage
                    ) { startNewTool() }
                    .padding()
                }
            } else {
                List {
                    ForEach(tools) { tool in
                        GroundingToolCard(
                            tool: tool,
                            onEdit: { editingTool = tool },
                            onRun: canRun(tool) ? { runningTool = tool } : nil
                        )
                        .anchorDeletable { modelContext.delete(tool) }
                        .anchorCardRow()
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Grounding tools")
        .guideButton("plan.grounding-tools", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if tools.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Anchor.AddToolbarButton(label: "Add a tool") { startNewTool() }
            }
        }
        .sheet(item: $editingTool, onDismiss: finishEditing) { tool in
            GroundingToolEditorSheet(tool: tool) { toolToDelete = tool }
        }
        .fullScreenCover(item: $runningTool) { tool in
            StepByStepRunnerView(title: tool.title, stepsText: tool.steps ?? "", tint: Anchor.Theme.sage)
        }
    }

    private func canRun(_ tool: GroundingTool) -> Bool {
        tool.kind == .physicalAction && groundingHasSteps(tool)
    }

    private func startNewTool() {
        let new = GroundingTool(title: "", kind: .physicalAction, steps: "", sortOrder: tools.count)
        modelContext.insert(new)
        editingTool = new
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = tools
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, tool) in reordered.enumerated() { tool.sortOrder = index }
    }

    /// Runs once the editor has closed. Deleting here, not while the editor
    /// is still on screen, keeps the editor from reading a tool that is
    /// already gone. A tool added and then left blank is dropped.
    private func finishEditing() {
        let deleting = toolToDelete
        toolToDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for tool in tools where tool !== deleting && isBlank(tool) {
            modelContext.delete(tool)
        }
    }

    private func isBlank(_ tool: GroundingTool) -> Bool {
        tool.kind == .physicalAction
            && tool.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !groundingHasSteps(tool)
    }
}

private func groundingHasSteps(_ tool: GroundingTool) -> Bool {
    !(tool.steps ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}

private func groundingTimeLabel(_ tag: TimeWindowTag) -> String {
    switch tag {
    case .morning: return "Morning"
    case .afternoon: return "Afternoon"
    case .evening: return "Evening"
    case .lateNight: return "Late night"
    }
}

/// A tool as a card. The card opens the editor. The play button, when there
/// is one, runs the steps instead.
private struct GroundingToolCard: View {
    let tool: GroundingTool
    let onEdit: () -> Void
    let onRun: (() -> Void)?

    private var whenText: String {
        tool.relevantTimeWindows.isEmpty
            ? "Any time of day"
            : tool.relevantTimeWindows.map(groundingTimeLabel).joined(separator: " \u{00B7} ")
    }

    var body: some View {
        Anchor.Card(accentColor: Anchor.Theme.sage) {
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(tool.title.isEmpty ? "Untitled tool" : tool.title)
                                .font(.system(.headline, design: .rounded))
                            Spacer()
                            Label(tool.kind == .deepLink ? "Opens a link" : "Steps",
                                  systemImage: tool.kind == .deepLink ? "arrow.up.forward.app.fill" : "list.number")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(whenText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the editor")

                if let onRun {
                    Button(action: onRun) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Anchor.Theme.sage)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Try \(tool.title.isEmpty ? "this tool" : tool.title) step by step")
                }
            }
        }
    }
}

private struct GroundingToolEditorSheet: View {
    @Bindable var tool: GroundingTool
    let onDelete: () -> Void
    @State private var deepLinkURLString: String = ""

    var body: some View {
        Anchor.ItemEditorSheet(
            title: tool.title.isEmpty ? "New tool" : tool.title,
            onDelete: onDelete,
            deleteQuestion: "Delete this tool?"
        ) {
            Form {
                TextField("Title", text: $tool.title)

                Picker("Type", selection: $tool.kind) {
                    Text("Physical action").tag(GroundingToolKind.physicalAction)
                    Text("Deep link").tag(GroundingToolKind.deepLink)
                }
                .pickerStyle(.segmented)

                if tool.kind == .physicalAction {
                    Section {
                        TextEditor(text: Binding(
                            get: { tool.steps ?? "" },
                            set: { tool.steps = $0 }
                        ))
                        .frame(minHeight: 140)
                    } header: {
                        Text("Steps")
                    } footer: {
                        Text("One step per line. Each line becomes its own screen you can step through one at a time. For example: \"Feel your feet on the floor\" on one line, \"Take 3 slow breaths\" on the next.")
                    }
                } else {
                    Section {
                        TextField("e.g. spotify:playlist:37i9dQ..., discord://, or https://...", text: $deepLinkURLString)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onAppear { deepLinkURLString = currentURLString() }
                            .onChange(of: deepLinkURLString) { _, newValue in
                                tool.deepLink = .website(url: newValue)
                            }
                    } header: {
                        Text("Link")
                    } footer: {
                        Text("If a Spotify or Discord link doesn't have the app installed, Anchor will try opening it in the browser instead of failing silently.")
                    }
                }

                Section {
                    ForEach([TimeWindowTag.morning, .afternoon, .evening, .lateNight], id: \.self) { tag in
                        Toggle(label(for: tag), isOn: Binding(
                            get: { tool.relevantTimeWindows.contains(tag) },
                            set: { isOn in
                                if isOn {
                                    if !tool.relevantTimeWindows.contains(tag) {
                                        tool.relevantTimeWindows.append(tag)
                                    }
                                } else {
                                    tool.relevantTimeWindows.removeAll { $0 == tag }
                                }
                            }
                        ))
                    }
                } header: {
                    Text("When it's relevant")
                } footer: {
                    Text("Leave all off to show this tool at any time of day.")
                }
            }
        }
    }

    private func currentURLString() -> String {
        switch tool.deepLink {
        case .spotifyPlaylist(let uri): return uri
        case .discordChannel(let url): return url
        case .app(let scheme): return scheme
        case .website(let url): return url
        case .none: return ""
        }
    }

    private func label(for tag: TimeWindowTag) -> String {
        switch tag {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .lateNight: return "Late night"
        }
    }
}
