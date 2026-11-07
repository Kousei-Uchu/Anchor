//
//  NowView.swift
//  Anchor
//
//  Default/first tab. Every prompt here is dismissible with zero guilt UI —
//  nothing on this screen tracks whether the user engaged with it.
//

import SwiftUI
import SwiftData

struct NowView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]
    @Query(sort: \GroundingTool.sortOrder) private var groundingTools: [GroundingTool]

    /// Set by ContentView when the daily check-in notification (or its
    /// "Check in now" action) is tapped, so that notification can actually
    /// open the check-in sheet instead of just landing on a blank tab.
    @Binding var openCheckInSignal: Bool

    @State private var showCheckIn = false
    @State private var mascotLine: MascotLine?
    @State private var mascotMood: MascotMood = .neutral
    @State private var journalDraftToOpen: JournalEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Anchor.Theme.spacing) {
                    CrisisNumbersView()

                    MascotPresenceView(line: mascotLine, mood: mascotMood)
                        .padding(.top, 4)

                    Button {
                        showCheckIn = true
                    } label: {
                        Label("Check in", systemImage: "circle.hexagongrid.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(Anchor.PrimaryButtonStyle())

                    if !contacts.isEmpty {
                        Anchor.Card {
                            QuickContactsView(contacts: contacts)
                        }
                    }

                    // Only appears once the user has added a Recovery counter.
                    RecoveryNowCard()

                    NextAppointmentCardView()

                    // Only with the switch on in Settings, and only in the morning.
                    SleepMorningCard()

                    SafetyPlanShortcutView()

                    DecisionPresetsQuickView()

                    Anchor.Card(accentColor: Anchor.Theme.sage) {
                        GroundingToolsView(allTools: groundingTools)
                    }

                    Anchor.Card {
                        TasksNowCard()
                    }

                    Anchor.Card(accentColor: Anchor.Theme.sage) {
                        DeEscalationCardView()
                    }

                    Anchor.Card {
                        AffirmationsCardView()
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .anchorBackground()
            .navigationTitle("Now")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HelpToolbarButton(topic: .now)
                }
            }
            .sheet(isPresented: $showCheckIn) {
                CheckInSliderView { checkIn in
                    // The check-in flow itself already creates and links a
                    // Journal entry when the user answers any optional
                    // prompts — this just opens that entry to review/edit,
                    // rather than creating a second, separate blank one.
                    guard let entryID = checkIn.expandedEntryID else { return }
                    let descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.id == entryID })
                    if let entry = try? modelContext.fetch(descriptor).first {
                        journalDraftToOpen = entry
                    }
                }
                .presentationDetents([.large])
                .fullHeightPadSheet()
            }
            .sheet(item: $journalDraftToOpen) { entry in
                JournalEntryEditorView(entry: entry)
            }
            .onAppear {
                MascotEngine.seedIfNeeded(context: modelContext)
                let engine = MascotEngine(context: modelContext)
                let newLine = engine.line(for: .appOpen, mood: .neutral)
                mascotLine = newLine
                mascotMood = newLine?.mood ?? .neutral
            }
            .onChange(of: openCheckInSignal) { _, shouldOpen in
                guard shouldOpen else { return }
                showCheckIn = true
                openCheckInSignal = false
            }
        }
    }
}

private extension View {
    /// iPad shows sheets as a short centred card by default, which clips the
    /// check-in sliders. Use the taller page sizing where it exists (iOS 18+).
    @ViewBuilder
    func fullHeightPadSheet() -> some View {
        if #available(iOS 18.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}
