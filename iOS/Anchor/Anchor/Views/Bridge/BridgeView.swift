//
//  BridgeView.swift
//  Anchor
//

import SwiftUI
import SwiftData

struct BridgeView: View {
    @AppStorage(TabLayoutStyle.storageKey) private var layoutRaw = TabLayoutStyle.widgets.rawValue
    @State private var showReframing = false
    @State private var showExport = false

    private var usesWidgets: Bool { layoutRaw != TabLayoutStyle.icons.rawValue }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if usesWidgets {
                        widgetLayout
                    } else {
                        tileLayout
                    }
                }
                .padding(.vertical, 8)
            }
            .anchorBackground()
            .navigationTitle("Bridge")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button { showExport = true } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Export for someone")
                        .hiddenInShowcase()
                        HelpToolbarButton(topic: .bridge)
                    }
                }
            }
            .sheet(isPresented: $showReframing) {
                ReframingPromptView()
            }
            .sheet(isPresented: $showExport) {
                BridgeExportView()
            }
        }
    }

    // Widgets (default). Order and visibility come from the saved layout.
    private var widgetLayout: some View {
        Anchor.WidgetStack(tab: .bridge) { id in
            bridgeWidget(id)
        } more: { id in
            bridgeMoreTile(id)
        }
        .padding(.horizontal)
    }

    @ViewBuilder private func bridgeWidget(_ id: WidgetID) -> some View {
        switch id {
        case .thingsToRaise: ThingsToRaiseWidget()
        case .nextSession: NextSessionWidget()
        case .reframing: ReframingWidget { showReframing = true }
        case .feedbackLoops: FeedbackLoopsWidget()
        case .personalGoals: PersonalGoalsWidget()
        // Personal copy only: compiled out of every public build. See NSWMentalHealthReferenceView.swift.
        #if PERSONAL_BUILD
        case .nswLaw:
            Anchor.Widget(icon: "building.columns.fill", title: "NSW mental health law") {
                NSWMentalHealthReferenceView()
            } content: {
                Anchor.WidgetCaption(text: "Reference")
            }
        #endif
        default: EmptyView()
        }
    }

    @ViewBuilder private func bridgeMoreTile(_ id: WidgetID) -> some View {
        switch id {
        case .thingsToRaise: Anchor.MoreTile(id: id) { BridgeDraftListView() }
        case .nextSession: Anchor.MoreTile(id: id) { ProviderPageHost(page: .prep) }
        case .reframing:
            Button { showReframing = true } label: {
                Anchor.TileButtonLabel(icon: id.icon, title: id.title, tint: id.tint)
            }
            .buttonStyle(.plain)
        case .feedbackLoops: Anchor.MoreTile(id: id) { FeedbackLoopDiagramListView() }
        case .personalGoals: Anchor.MoreTile(id: id) { PersonalGoalsView() }
        #if PERSONAL_BUILD
        case .nswLaw: Anchor.MoreTile(id: id) { NSWMentalHealthReferenceView() }
        #endif
        default: EmptyView()
        }
    }

    // Icons (classic): the original tile rows.
    private var tileLayout: some View {
        VStack(alignment: .leading, spacing: 26) {
                    Anchor.TileRow(title: "For your psych") {
                        NavigationLink { BridgeDraftListView() } label: {
                            Anchor.TileButtonLabel(icon: "doc.text.fill", title: "Draft notes", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { ProviderPageHost(page: .prep) } label: {
                            Anchor.TileButtonLabel(icon: "list.bullet.clipboard.fill", title: "Session prep", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { ProviderPageHost(page: .afterSession) } label: {
                            Anchor.TileButtonLabel(icon: "note.text", title: "Post-session notes", tint: Anchor.Theme.accent)
                        }
                    }

                    Anchor.TileRow(title: "Tools & reference") {
                        Button {
                            showReframing = true
                        } label: {
                            Anchor.TileButtonLabel(icon: "arrow.triangle.2.circlepath", title: "Reframing", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { FeedbackLoopDiagramListView() } label: {
                            Anchor.TileButtonLabel(icon: "point.3.connected.trianglepath.dotted", title: "Feedback loops", tint: Anchor.Theme.sage)
                        }
                        NavigationLink { PersonalGoalsView() } label: {
                            Anchor.TileButtonLabel(icon: "flag.fill", title: "Personal goals", tint: Anchor.Theme.sage)
                        }
                        // Personal copy only: compiled out of every public build. See NSWMentalHealthReferenceView.swift.
                        #if PERSONAL_BUILD
                        NavigationLink { NSWMentalHealthReferenceView() } label: {
                            Anchor.TileButtonLabel(icon: "building.columns.fill", title: "NSW mental health law", tint: Anchor.Theme.accent)
                        }
                        #endif
                    }
                }
    }
}
