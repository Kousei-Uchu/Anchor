//
//  HelpContent.swift
//  Anchor
//
//  Fixed, reviewed explanations for each tab — concise on purpose (per
//  feedback: "ensure all sections are explained concisely, so the user
//  knows how to use them, what they're for, why they're there, and when
//  to use them"). Reached via a "?" button in each tab's toolbar, plus
//  gathered into a first-launch tour (OnboardingTourView) so nobody has
//  to discover the "?" button to get the basics.
//

import SwiftUI

enum HelpTopic: String, CaseIterable, Identifiable {
    case now, plan, journal, bridge, thread
    var id: Self { self }

    var title: String { "About \(tabName)" }

    var tabName: String {
        switch self {
        case .now: return "Now"
        case .plan: return "Plan"
        case .journal: return "Journal"
        case .bridge: return "Bridge"
        case .thread: return "Thread"
        }
    }

    var icon: String {
        switch self {
        case .now: return "sun.max.fill"
        case .plan: return "map.fill"
        case .journal: return "pencil.and.outline"
        case .bridge: return "arrow.left.arrow.right"
        case .thread: return "bubble.left.and.bubble.right.fill"
        }
    }

    var explanation: String {
        switch self {
        case .now:
            return "Your quick-access dashboard. Crisis numbers, grounding tools, your next-hour list, quick contacts, check-ins, and today's affirmation all live here. If you've added a Recovery counter, it sits here too, with a shortcut to ride out an urge. Everything on this screen is meant to be used in the moment, not configured. When you need something right now, this is the tab."
        case .plan:
            return "Where everything gets set up ahead of time. Contacts, your safety plan, trigger windows, appointments, and the presets Now pulls from (grounding tools, decision presets, de-escalation scripts, affirmations) are all edited here, and nothing else: switches, reminders and your data live behind the gear at the top, in Settings. Come here when you're calm and have a moment, not mid-crisis."
        case .journal:
            return "A timeline of what you've written, with your check-in trends running alongside it. Tap the pencil to write. While you write, the Add button gives you Journaling Suggestions (calendar events, photos and music from that day), photos, drawings, a prompt, and formatting. Search finds anything you've written."
        case .bridge:
            return "Everything that makes talking to your psych easier. Drafting what you want to say, prepping for a session, notes afterward, optional cognitive tools (reframing, feedback-loop diagrams), and a plain-language reference for NSW mental health law. If you keep a Recovery counter, session prep can show how it's gone since your last session, and you choose whether to add that to your notes."
        case .thread:
            return "Where you keep track of the people who matter. A message log tied to real contacts you can actually send to, a support calendar you can share with someone outside the app, notes to your future self, and a private space for bigger things you might never send to anyone."
        }
    }
}

struct HelpSheetView: View {
    let topic: HelpTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                ZStack {
                    Circle().fill(Anchor.Theme.accentSoft).frame(width: 64, height: 64)
                    Image(systemName: topic.icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Anchor.Theme.accent)
                }
                Text(topic.title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text(topic.explanation)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .anchorBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
    }
}

/// Small reusable toolbar button — one line to drop into any tab's root
/// view rather than repeating the sheet-presentation boilerplate five times.
struct HelpToolbarButton: View {
    let topic: HelpTopic
    @State private var showHelp = false

    var body: some View {
        Button {
            showHelp = true
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .sheet(isPresented: $showHelp) {
            HelpSheetView(topic: topic)
        }
    }
}
