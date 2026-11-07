//
//  BridgeView.swift
//  Anchor
//

import SwiftUI
import SwiftData

struct BridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appointmentSeries: [AppointmentSeries]
    @AppStorage(TabLayoutStyle.storageKey) private var layoutRaw = TabLayoutStyle.widgets.rawValue
    @State private var showReframing = false

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
                    HelpToolbarButton(topic: .bridge)
                }
            }
            .sheet(isPresented: $showReframing) {
                ReframingPromptView()
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
        case .nextSession: NextSessionWidget(fallbackSeries: currentAppointmentSeries)
        case .reframing: ReframingWidget { showReframing = true }
        case .feedbackLoops: FeedbackLoopsWidget()
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
        case .nextSession: Anchor.MoreTile(id: id) { AppointmentPrepView(series: currentAppointmentSeries) }
        case .reframing:
            Button { showReframing = true } label: {
                Anchor.TileButtonLabel(icon: id.icon, title: id.title, tint: id.tint)
            }
            .buttonStyle(.plain)
        case .feedbackLoops: Anchor.MoreTile(id: id) { FeedbackLoopDiagramListView() }
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
                        NavigationLink { AppointmentPrepView(series: currentAppointmentSeries) } label: {
                            Anchor.TileButtonLabel(icon: "list.bullet.clipboard.fill", title: "Session prep", tint: Anchor.Theme.accent)
                        }
                        NavigationLink { PostSessionNotesView(series: currentAppointmentSeries) } label: {
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
                        // Personal copy only: compiled out of every public build. See NSWMentalHealthReferenceView.swift.
                        #if PERSONAL_BUILD
                        NavigationLink { NSWMentalHealthReferenceView() } label: {
                            Anchor.TileButtonLabel(icon: "building.columns.fill", title: "NSW mental health law", tint: Anchor.Theme.accent)
                        }
                        #endif
                    }
                }
    }

    private var currentAppointmentSeries: AppointmentSeries {
        if let existing = appointmentSeries.first { return existing }
        let new = AppointmentSeries(clinicianLabel: "Psych")
        modelContext.insert(new)
        return new
    }
}
