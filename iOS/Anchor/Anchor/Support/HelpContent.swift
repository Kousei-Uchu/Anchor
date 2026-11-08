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
            return "Your quick-access dashboard. Crisis numbers, grounding tools, your tasks, quick contacts, check-ins, and today's affirmation all live here. If you've added a Recovery counter, it sits here too, with a shortcut to ride out an urge. Everything on this screen is meant to be used in the moment, not configured. When you need something right now, this is the tab."
        case .plan:
            return "Where everything gets set up ahead of time. Contacts, your safety plan (in sections you can rename, reorder, add, hide and delete, with one of them used for reminder quotes), trigger windows, appointments (you can keep more than one provider, each with their own sessions, notes and a name to use on exports), your task list (a task can have steps, can wait on another task, can be moved to tomorrow or set aside for now, and can say how much energy it needs, so a low day can show only the small ones, and can be worked on with the focus timer: hold a task or step, or use the menu on the Tasks screen, and the length of focus and break is yours to set, with an optional alert and lock screen timer that never show the task; Plan my day, in the same menu, lets you pick a few tasks or steps, put them in order and walk through them one at a time; Quick list, also in that menu, is a one-off checklist: type or paste one item per line, tick them off, and it goes to an Archive by itself when the last one is ticked, or you can move what is left into your tasks), and the presets Now pulls from (grounding tools, decision presets, de-escalation scripts, affirmations; Presets also holds item lists, packing-style checklists with headings where an amount can follow a number you set, like one T-shirt for each day, and routines, which are lists of steps you run one at a time, each with an optional rough time and an optional reminder on the days you pick, off until you switch it on) are all edited here, and nothing else: switches, reminders and your data live behind the gear at the top, in Settings. In Settings, Your data has Look at what's stored, which asks for your lock again and then shows everything Anchor holds, kind by kind, read only, with a switch that blurs what is written. Come here when you're calm and have a moment, not mid-crisis. The Customise button under the widgets lets you drag them into a new order, hide the ones you don't use and add them back, and make some half-width widgets full width. Sleep is a quiet journal of your nights, added hidden: turn it on under Customise and a night holds when you went to bed and woke, how long you slept (worked out from the times, or typed if you do not know them), how it felt in three words you can rename, and a note. It has no score, no target hours and no streak, and it is only a record for you to look back over. Settings has switches, all off to begin with, for a Last night card on Now in the morning, a small row for each night in the Journal, one more optional question in a check-in, and a morning reminder at a time you pick whose wording never mentions sleep. In a check-in the answer is kept as the note on last night, and the question is not asked when last night is already written down. At the bottom of the Sleep screen, Apple Health can be connected so the nights it already has are brought in, one summary per night, the last 30 days at first and then whatever is new. Anchor only reads sleep, only after you tap Connect, and a night you typed is never replaced. If you change an imported night it becomes yours, and Remove imported sleep takes out the nights that came from Apple Health and stops bringing in more, without touching anything in Health. A second switch there, off to begin with, saves the nights you type to Apple Health when they have both a bed time and a wake time, marked as coming from Anchor. A night Health already has from somewhere else is left alone, deleting a night here removes the one Anchor saved, and Remove what Anchor saved takes back all of it."
        case .journal:
            return "A timeline of what you've written, with your check-ins on the same line. Switch to Month for a calendar and tap a day to open it, or to Year to see the whole year at a glance and tap a month. Tap the pencil to write. While you write, the tools at the bottom give you Journaling Suggestions (calendar events, photos and music from that day), photos, drawings, a prompt, and formatting. Search finds anything you've written. The page is laid out like a journal: the date at the top, your writing in paragraphs, and photos, events, songs and suggestions as their own blocks that you can move or remove from the small menu on each. One row of tools sits at the bottom. Bookmark an entry from the menu at the top of the page, or press and hold it in the list, and use Bookmarked only in the menu to see just those. Press and hold an entry, or use the menu at the top of the page, to copy its first line into Things to raise in Bridge. If you use the Sleep journal, Settings can show each night as a small row on its morning here and as a moon mark on the month view. Tapping the row opens the night, and a note on a night can be copied into your journal as an ordinary entry."
        case .bridge:
            return "Everything that makes talking to your psych easier. Drafting what you want to say (an item can be marked as a question, with room to write the answer once you have asked), prepping for a session, notes afterward, optional cognitive tools (reframing, feedback-loop diagrams), and a plain-language reference for NSW mental health law. If you keep a Recovery counter, session prep can show how it's gone since your last session, and you choose whether to add that to your notes. Session prep also counts the journal entries and check-ins since then, and lets you pick entries to bring (check-ins are only ever counted, never read out). The Customise button under the widgets lets you drag them into a new order, hide the ones you don't use and add them back, and make some half-width widgets full width. A feedback-loop diagram starts as a loop: write what happens first, what that leads to, and so on, and the last step leads back to the first. Mark each link as more leading to more or more leading to less, and Anchor says in plain words whether the loop tends to keep itself going or to settle back. A free map is there too, from the plus menu: drag the background to move around, pinch to zoom, drag items to place them, switch to Link and drag from one item onto another to connect them, and use the pencil on an item for its words, colour and links. Undo and Redo are at the bottom. A loop can be opened as a free map from the menu on its page. The plus menu also has From a template, which makes a copy you can rewrite. The menu on a diagram's page can share it as a picture or a PDF, with the written reading switched on or off. Personal goals are yours alone: write what you want and why, say where it is, and add short dated notes along the way. Nothing is scored. Each provider you add has their own sessions, prep and after-session notes, and a row of names at the top switches between them. The share button at the top of Bridge (and the one in Things to raise) opens Export for someone: write who it is for and an optional note for the top, then choose what goes in. Only Things to raise is on to begin with, every time; your journal, check-ins, sleep and a Recovery summary are left out unless you switch them on, and you can limit it to a date range or tick individual items. A count and a preview show what it holds before anything is made, and the name is in the file name and at the top. You can make a PDF, or a web page: one file that opens in any browser with search, a timeline, charts of check-ins and buttons to print, or to download a CSV or a Word file, and that can have a password. Anchor does not keep the password and cannot get it back, so tell the person it another way. Some mail apps block web pages, so a PDF is the safer thing to send. Choosing a provider fills in their name for exports. With two or more providers, each item in Things to raise can be for anyone or for one of them, which you choose in the item. The filter button at the top then shows what is for one person and for anyone, and exporting for that person leaves out what was meant for someone else. If you remove a provider, their items stay and become for anyone."
        case .thread:
            return "Where you keep track of the people who matter. A message log tied to real contacts: write to someone in one tap, send it through Messages or Discord or just keep it, add a voice note, and look back over what you've told each person, short message starters of your own (from the speech bubble in the log, or while writing) that you can tap to begin a message and also use from Quick contact on Now, a support calendar you can share with someone outside the app, notes to your future self (sealed until a date, or a letter that opens when you choose), a private space for bigger things you might never send to anyone, and a Boundaries list: what you would like people to know, what helps and what does not, in sections you can rename, reorder, hide and mark as shareable, so that Share sends only those. People gives each of your contacts a page of their own: sections you write and arrange yourself (a note, what helps, things you have told them, anything else), the last few messages in your log with them, and the support calendar days you have shared with them. Nothing on a page is counted or scored, and nothing is sent from it. Deleting a contact deletes their page. The Customise button under the widgets lets you drag them into a new order, hide the ones you don't use and add them back, and make some half-width widgets full width."
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
