//
//  BridgeView.swift
//  Anchor
//

import SwiftUI
import SwiftData

struct BridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appointmentSeries: [AppointmentSeries]
    @State private var showReframing = false

    var body: some View {
        NavigationStack {
            ScrollView {
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

    private var currentAppointmentSeries: AppointmentSeries {
        if let existing = appointmentSeries.first { return existing }
        let new = AppointmentSeries(clinicianLabel: "Psych")
        modelContext.insert(new)
        return new
    }
}
