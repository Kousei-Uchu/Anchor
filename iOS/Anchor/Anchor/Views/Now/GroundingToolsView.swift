//
//  GroundingToolsView.swift
//  Anchor
//
//  Only ever shows tools the user themselves has authored. No generic
//  suggestions (ice, rubber bands, etc.) are seeded or offered anywhere in
//  this file — if the tools list is empty, the empty state says so plainly
//  and points to adding one, it doesn't fill the gap with defaults.
//
//  Two real fixes from the previous pass:
//  1. Deep links now try the given URL, then fall back to a web URL for
//     known services if the native scheme doesn't resolve, and surface a
//     visible alert if nothing could be opened — instead of failing silently.
//  2. Physical-action tools no longer just expand a paragraph inline. They
//     open a dedicated full-screen runner that walks through steps one at
//     a time (GroundingToolStepRunnerView, below), since scrolling to a
//     wall of text mid-crisis isn't the same as being guided through it.
//

import SwiftUI
import SwiftData

struct GroundingToolsView: View {
    let allTools: [GroundingTool]
    @State private var runningTool: GroundingTool?
    @State private var linkFailureMessage: String?

    private var relevantTools: [GroundingTool] {
        let currentTag = TimeWindowHelper.currentTag()
        let filtered = allTools.filter {
            $0.relevantTimeWindows.isEmpty || $0.relevantTimeWindows.contains(currentTag)
        }
        return filtered.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Anchor.SectionHeader(icon: "leaf.fill", title: "Grounding tools", tint: Anchor.Theme.sage)

            if relevantTools.isEmpty {
                Text("Nothing set up for right now yet. Add your own tools in Plan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(relevantTools) { tool in
                        GroundingToolRow(tool: tool) {
                            switch tool.kind {
                            case .physicalAction:
                                runningTool = tool
                            case .deepLink:
                                DeepLinkOpener.open(tool.deepLink) { message in
                                    linkFailureMessage = message
                                }
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $runningTool) { tool in
            GroundingToolStepRunnerView(tool: tool)
        }
        .alert("Couldn't open that", isPresented: Binding(
            get: { linkFailureMessage != nil },
            set: { if !$0 { linkFailureMessage = nil } }
        )) {
            Button("OK", role: .cancel) { linkFailureMessage = nil }
        } message: {
            Text(linkFailureMessage ?? "")
        }
    }
}

private struct GroundingToolRow: View {
    let tool: GroundingTool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: tool.kind == .deepLink ? "arrow.up.forward.app.fill" : "list.number")
                    .foregroundStyle(Anchor.Theme.sage)
                    .frame(width: 20)
                Text(tool.title.isEmpty ? "Untitled tool" : tool.title)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Anchor.Theme.sageSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Handles opening a GroundingTool's deep link with a real fallback chain
/// instead of a single silent `UIApplication.shared.open` call:
/// 1. Try the stored URL as-is.
/// 2. If that fails and it looks like a known service, try that service's
///    web URL instead (works even without the native app installed).
/// 3. If everything fails, report back so the UI can show an alert rather
///    than doing nothing with no feedback.
enum DeepLinkOpener {
    static func open(_ destination: DeepLinkDestination?, onFailure: @escaping (String) -> Void) {
        guard let destination else {
            onFailure("This tool doesn't have a link set up yet.")
            return
        }

        let primary = urlString(for: destination)
        guard let primaryURL = URL(string: primary) else {
            onFailure("The saved link (\"\(primary)\") isn't a valid URL. Edit this tool in Plan.")
            return
        }

        UIApplication.shared.open(primaryURL, options: [:]) { success in
            if success { return }
            if let fallback = webFallback(for: destination), let fallbackURL = URL(string: fallback) {
                UIApplication.shared.open(fallbackURL, options: [:]) { fallbackSuccess in
                    if !fallbackSuccess {
                        onFailure("Couldn't open this link, or its fallback. Double check it in Plan.")
                    }
                }
            } else {
                onFailure("Couldn't open this link. If it points to an app scheme, make sure the app is installed, or edit it in Plan.")
            }
        }
    }

    private static func urlString(for destination: DeepLinkDestination) -> String {
        switch destination {
        case .spotifyPlaylist(let uri): return uri
        case .discordChannel(let url): return url
        case .app(let scheme): return scheme
        case .website(let url): return url
        }
    }

    /// A web URL that works even if the native app isn't installed.
    private static func webFallback(for destination: DeepLinkDestination) -> String? {
        switch destination {
        case .spotifyPlaylist(let uri):
            // spotify:playlist:XYZ -> https://open.spotify.com/playlist/XYZ
            let id = uri.components(separatedBy: ":").last ?? ""
            return id.isEmpty ? nil : "https://open.spotify.com/playlist/\(id)"
        case .discordChannel(let url):
            return url.hasPrefix("http") ? url : nil
        case .app, .website:
            return nil
        }
    }
}

/// Walks through a physical-action tool's steps one at a time, full screen,
/// instead of dumping the whole text block on the Now screen at once.
/// Steps are stored as one string (one step per line, authored in Plan) and
/// parsed here — kept as a simple string in the data model so nothing about
/// the SwiftData schema needed to change to fix this.
struct GroundingToolStepRunnerView: View {
    let tool: GroundingTool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        StepByStepRunnerView(title: tool.title, stepsText: tool.steps ?? "", tint: Anchor.Theme.sage)
    }
}

/// The generic one-step-at-a-time runner: progress bar, centered step text,
/// Back/Next, "Close" always available. Used by Grounding Tools and by
/// Decision Presets (Views/Plan/DecisionFatigueView.swift) — the exact same
/// UI on purpose, since click-through steps are the same kind of relief in
/// both places: reducing "everything at once" down to one thing at a time.
struct StepByStepRunnerView: View {
    let title: String
    let stepsText: String
    var tint: Color = Anchor.Theme.sage
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0

    private var steps: [String] {
        stepsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if steps.isEmpty {
                    Spacer()
                    Text("No steps written for this yet.")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ProgressView(value: Double(currentIndex + 1), total: Double(steps.count))
                        .tint(tint)
                        .padding(.horizontal)

                    Text("Step \(currentIndex + 1) of \(steps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(steps[currentIndex])
                        .font(.system(.title2, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    Spacer()

                    HStack(spacing: 12) {
                        if currentIndex > 0 {
                            Button("Back") { withAnimation { currentIndex -= 1 } }
                                .buttonStyle(Anchor.SecondaryButtonStyle(tint: tint))
                        }

                        Button(currentIndex == steps.count - 1 ? "Done" : "Next") {
                            if currentIndex == steps.count - 1 {
                                dismiss()
                            } else {
                                withAnimation { currentIndex += 1 }
                            }
                        }
                        .buttonStyle(Anchor.PrimaryButtonStyle(tint: tint))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(title)
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
