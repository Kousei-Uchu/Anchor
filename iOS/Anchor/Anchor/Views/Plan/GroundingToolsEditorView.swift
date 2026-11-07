//
//  GroundingToolsEditorView.swift
//  Anchor
//
//  Now's empty state says "add your own tools in Plan" — this is that
//  screen. Still user-authored only: no seeded suggestions here either.
//

import SwiftUI
import SwiftData

/// Grounding tools as something to browse: a card per tool, with its kind and
/// when it's relevant shown as labels. A tool with written steps can be run
/// right here (that's using it, not editing it); adding, deleting and
/// rewriting live behind Edit (`GroundingToolsEditorView`).
struct GroundingToolsListView: View {
    @Query(sort: \GroundingTool.sortOrder) private var tools: [GroundingTool]
    @State private var showingEditor = false
    @State private var runningTool: GroundingTool?

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if tools.isEmpty {
                    Anchor.EmptyState(
                        icon: "leaf.fill",
                        title: "No grounding tools yet",
                        message: "Add the things that actually help you settle: a few steps, or a link to a playlist or app. They'll show up on Now.",
                        actionTitle: "Add a tool",
                        tint: Anchor.Theme.sage
                    ) { showingEditor = true }
                } else {
                    ForEach(tools) { tool in
                        if tool.kind == .physicalAction, groundingHasSteps(tool) {
                            Button { runningTool = tool } label: {
                                GroundingToolCard(tool: tool, runnable: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            GroundingToolCard(tool: tool, runnable: false)
                        }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Grounding tools")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit grounding tools") {
                GroundingToolsEditorView()
            }
        }
        .fullScreenCover(item: $runningTool) { tool in
            StepByStepRunnerView(title: tool.title, stepsText: tool.steps ?? "", tint: Anchor.Theme.sage)
        }
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

private struct GroundingToolCard: View {
    let tool: GroundingTool
    let runnable: Bool

    private var whenText: String {
        tool.relevantTimeWindows.isEmpty
            ? "Any time of day"
            : tool.relevantTimeWindows.map(groundingTimeLabel).joined(separator: " \u{00B7} ")
    }

    var body: some View {
        Anchor.Card(accentColor: Anchor.Theme.sage) {
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
                if runnable {
                    Label("Try it step by step", systemImage: "play.fill")
                        .font(.caption)
                        .foregroundStyle(Anchor.Theme.sage)
                }
            }
        }
    }
}

/// The grounding-tools editor: add, delete, open a tool's details. Presented
/// from `GroundingToolsListView` via Edit, never browsed to directly.
struct GroundingToolsEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroundingTool.sortOrder) private var tools: [GroundingTool]
    @State private var editingTool: GroundingTool?

    var body: some View {
        List {
            ForEach(tools) { tool in
                Button {
                    editingTool = tool
                } label: {
                    VStack(alignment: .leading) {
                        Text(tool.title).font(.headline)
                        Text(tool.kind == .deepLink ? "Opens a link" : "Described steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(tools[index]) }
            }

            Button("Add grounding tool") {
                let new = GroundingTool(title: "", kind: .physicalAction, steps: "", sortOrder: tools.count)
                modelContext.insert(new)
                editingTool = new
            }
        }
        .sheet(item: $editingTool) { tool in
            GroundingToolEditorSheet(tool: tool)
        }
    }
}

private struct GroundingToolEditorSheet: View {
    @Bindable var tool: GroundingTool
    @Environment(\.dismiss) private var dismiss
    @State private var deepLinkURLString: String = ""

    var body: some View {
        NavigationStack {
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
            .anchorSettingsStyle()
            .navigationTitle(tool.title.isEmpty ? "New tool" : tool.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
