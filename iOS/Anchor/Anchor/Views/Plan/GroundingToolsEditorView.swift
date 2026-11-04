//
//  GroundingToolsEditorView.swift
//  Anchor
//
//  Now's empty state says "add your own tools in Plan" — this is that
//  screen. Still user-authored only: no seeded suggestions here either.
//

import SwiftUI
import SwiftData

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
        .navigationTitle("Grounding tools")
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
            .navigationTitle(tool.title.isEmpty ? "New tool" : tool.title)
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
