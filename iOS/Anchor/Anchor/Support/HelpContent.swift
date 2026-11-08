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
//  Everything below the topics is one guide registry (GuideEntry and Guide).
//  The tour, the "?" sheet and the "?" button on each screen all read from
//  it, so a screen is explained in one place. A screen asks for its entry by
//  id; until it has one of its own, it shows the entry for its tab.
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

    /// One line on what the tab is, shown above the longer explanation.
    var summary: String {
        switch self {
        case .now: return "The quick-access home screen, made for the moment you are in."
        case .plan: return "Where you set things up ahead of time, so they are ready when you need them."
        case .journal: return "A timeline of what you have written, with your check-ins on the same line."
        case .bridge: return "Everything that makes talking to your psych easier."
        case .thread: return "Where you keep track of the people who matter to you."
        }
    }

    var explanation: String {
        switch self {
        case .now:
            return "Your quick-access dashboard. Crisis numbers, grounding tools, your tasks, quick contacts, check-ins, and today's affirmation all live here. If you've added a Recovery counter, it sits here too, with a shortcut to ride out an urge. Everything on this screen is meant to be used in the moment, not configured. When you need something right now, this is the tab."
        case .plan:
            return "Where everything gets set up ahead of time. Contacts, your safety plan (in sections you can rename, reorder, add, hide and delete, with one of them used for reminder quotes), trigger windows, appointments (you can keep more than one provider, each with their own sessions, notes and a name to use on exports), your task list (a task can have steps, can wait on another task, can be moved to tomorrow or set aside for now, and can say how much energy it needs, so a low day can show only the small ones, and can be worked on with the focus timer: hold a task or step, or use the menu on the Tasks screen, and the length of focus and break is yours to set, with an optional alert and lock screen timer that never show the task; Plan my day, in the same menu, lets you pick a few tasks or steps, put them in order and walk through them one at a time; Quick list, also in that menu, is a one-off checklist: type or paste one item per line, tick them off, and it goes to an Archive by itself when the last one is ticked, or you can move what is left into your tasks), and the presets Now pulls from (grounding tools, decision presets, de-escalation scripts, affirmations; Presets also holds item lists, packing-style checklists with headings where an amount can follow a number you set, like one T-shirt for each day, and routines, which are lists of steps you run one at a time, each with an optional rough time and an optional reminder on the days you pick, off until you switch it on) are all edited here, and nothing else: switches, reminders and your data live behind the gear at the top, in Settings. In Settings, Your data can make an encrypted backup, locked with a password you choose, that holds photos and voice notes too; the same Import button opens it. Your data has Look at what's stored, which asks for your lock again and then shows everything Anchor holds, kind by kind, read only, with a switch that blurs what is written. Come here when you're calm and have a moment, not mid-crisis. The Customise button under the widgets lets you drag them into a new order, hide the ones you don't use and add them back, and make some half-width widgets full width. Sleep is a quiet journal of your nights, added hidden: turn it on under Customise and a night holds when you went to bed and woke, how long you slept (worked out from the times, or typed if you do not know them), how it felt in three words you can rename, and a note. It has no score, no target hours and no streak, and it is only a record for you to look back over. Settings has switches, all off to begin with, for a Last night card on Now in the morning, a small row for each night in the Journal, one more optional question in a check-in, and a morning reminder at a time you pick whose wording never mentions sleep. In a check-in the answer is kept as the note on last night, and the question is not asked when last night is already written down. At the bottom of the Sleep screen, Apple Health can be connected so the nights it already has are brought in, one summary per night, the last 30 days at first and then whatever is new. Anchor only reads sleep, only after you tap Connect, and a night you typed is never replaced. If you change an imported night it becomes yours, and Remove imported sleep takes out the nights that came from Apple Health and stops bringing in more, without touching anything in Health. A second switch there, off to begin with, saves the nights you type to Apple Health when they have both a bed time and a wake time, marked as coming from Anchor. A night Health already has from somewhere else is left alone, deleting a night here removes the one Anchor saved, and Remove what Anchor saved takes back all of it."
        case .journal:
            return "A timeline of what you've written, with your check-ins on the same line. Switch to Month for a calendar and tap a day to open it, or to Year to see the whole year at a glance and tap a month. Tap the pencil to write. While you write, the tools at the bottom give you Journaling Suggestions (calendar events, photos and music from that day), photos, drawings, a prompt, and formatting. Search finds anything you've written. The page is laid out like a journal: the date at the top, your writing in paragraphs, and photos, events, songs and suggestions as their own blocks that you can move or remove from the small menu on each. One row of tools sits at the bottom. Bookmark an entry from the menu at the top of the page, or press and hold it in the list, and use Bookmarked only in the menu to see just those. Press and hold an entry, or use the menu at the top of the page, to copy its first line into Things to raise in Bridge. If you use the Sleep journal, Settings can show each night as a small row on its morning here and as a moon mark on the month view. Tapping the row opens the night, and a note on a night can be copied into your journal as an ordinary entry."
        case .bridge:
            return "Everything that makes talking to your psych easier. Drafting what you want to say (an item can be marked as a question, with room to write the answer once you have asked), prepping for a session, notes afterward, optional cognitive tools (reframing, feedback-loop diagrams), and a plain-language reference for NSW mental health law. If you keep a Recovery counter, session prep can show how it's gone since your last session, and you choose whether to add that to your notes. Session prep also counts the journal entries and check-ins since then, and lets you pick entries to bring (check-ins are only ever counted, never read out). Under those, Waiting to be raised lists what is still open in Things to raise for that provider and for anyone, and you choose whether to add it to your notes. To bring is a short list of your own for that one session: type what you want to have with you, tick it off, and remove what you no longer need. Nothing is suggested or counted, and the next session starts with an empty list. If you keep a sleep journal, a card shows how many nights are written down since then, the shortest and longest time asleep and your usual bedtime, and you choose whether to add that to your notes. The Customise button under the widgets lets you drag them into a new order, hide the ones you don't use and add them back, and make some half-width widgets full width. A feedback-loop diagram starts as a loop: write what happens first, what that leads to, and so on, and the last step leads back to the first. Mark each link as more leading to more or more leading to less, and Anchor says in plain words whether the loop tends to keep itself going or to settle back. A free map is there too, from the plus menu: drag the background to move around, pinch to zoom, drag items to place them, switch to Link and drag from one item onto another to connect them, and use the pencil on an item for its words, colour and links. Undo and Redo are at the bottom. A loop can be opened as a free map from the menu on its page. The plus menu also has From a template, which makes a copy you can rewrite. The menu on a diagram's page can share it as a picture or a PDF, with the written reading switched on or off. Personal goals are yours alone: write what you want and why, say where it is, and add short dated notes along the way. Nothing is scored. Each provider you add has their own sessions, prep and after-session notes, and a row of names at the top switches between them. The share button at the top of Bridge (and the one in Things to raise) opens Export for someone: write who it is for and an optional note for the top, then choose what goes in. Only Things to raise is on to begin with, every time; your journal, check-ins, sleep and a Recovery summary are left out unless you switch them on, and you can limit it to a date range or tick individual items. A count and a preview show what it holds before anything is made, and the name is in the file name and at the top. You can make a PDF, or a web page: one file that opens in any browser with search, a timeline, charts of check-ins and buttons to print, or to download a CSV or a Word file, and that can have a password. Anchor does not keep the password and cannot get it back, so tell the person it another way. Some mail apps block web pages, so a PDF is the safer thing to send. Choosing a provider fills in their name for exports. With two or more providers, each item in Things to raise can be for anyone or for one of them, which you choose in the item. The filter button at the top then shows what is for one person and for anyone, and exporting for that person leaves out what was meant for someone else. If you remove a provider, their items stay and become for anyone."
        case .thread:
            return "Where you keep track of the people who matter. A message log tied to real contacts: write to someone in one tap, send it through Messages or Discord or just keep it, add a voice note, and look back over what you've told each person, short message starters of your own (from the speech bubble in the log, or while writing) that you can tap to begin a message and also use from Quick contact on Now, a support calendar you can share with someone outside the app, notes to your future self (sealed until a date, or a letter that opens when you choose), a private space for bigger things you might never send to anyone, and a Boundaries list: what you would like people to know, what helps and what does not, in sections you can rename, reorder, hide and mark as shareable, so that Share sends only those. People gives each of your contacts a page of their own: sections you write and arrange yourself (a note, what helps, things you have told them, anything else), the last few messages in your log with them, and the support calendar days you have shared with them. Nothing on a page is counted or scored, and nothing is sent from it. Deleting a contact deletes their page. The Customise button under the widgets lets you drag them into a new order, hide the ones you don't use and add them back, and make some half-width widgets full width."
        }
    }
}

// MARK: - Guide registry

/// One entry in the guide. `id` is stable: a screen names its entry with it,
/// so renaming a title never breaks the link.
struct GuideEntry: Identifiable, Hashable {
    let id: String
    /// The tab it belongs to. The tour goes tab by tab, a tab's own entry first.
    let tab: HelpTopic
    let title: String
    let icon: String
    /// One or two sentences on what this is.
    let whatItIs: String
    /// How to use it, in plain prose.
    let howToUse: String
    /// Short extras, listed under the text when there are any.
    let tips: [String]
}

enum Guide {
    /// Entries for individual screens. They are written tab by tab, and each
    /// one is looked up by the id a screen passes to `guideButton`.
    static let screenEntries: [GuideEntry] = planEntries

    /// The entry for a tab itself, built from its topic so the text lives in one place.
    static func tabEntry(_ topic: HelpTopic) -> GuideEntry {
        GuideEntry(id: topic.rawValue, tab: topic, title: topic.tabName, icon: topic.icon,
                   whatItIs: topic.summary, howToUse: topic.explanation, tips: [])
    }

    /// The entry a screen should show: its own if it has one, otherwise its tab's.
    static func entry(for id: String, tab: HelpTopic) -> GuideEntry {
        screenEntries.first { $0.id == id } ?? tabEntry(tab)
    }

    /// Everything in tour order: each tab's own entry, then that tab's screens.
    static var tourEntries: [GuideEntry] {
        HelpTopic.allCases.flatMap { topic in
            [tabEntry(topic)] + screenEntries.filter { $0.tab == topic }
        }
    }
}

// MARK: - Guide entries: Plan

// Patch 42. The screens reached from Plan, in the order Plan lists them. Tasks, Quick list,
// De-escalation scripts and Affirmations keep their original `now.` ids (a screen asks for its
// entry by id, so the ids do not change) but belong to Plan, because that is where they are
// opened from. The words are plain and fixed, and nothing here is scored or counted.

extension Guide {
    static let planEntries: [GuideEntry] = [
        GuideEntry(
            id: "plan.contacts", tab: .plan, title: "Contacts", icon: "person.2.fill",
            whatItIs: "The people you would want to reach in a hard moment.",
            howToUse: "The plus adds someone, either from your phone's Contacts or by typing them in. Tap a card to open it and choose how to reach them (phone or Discord), write message templates for that person, and set an optional reminder. The first two people in the list are the quick buttons on Now, so use Reorder to put the two you would reach for first. A card can also hold a timezone and the hours someone is usually awake, which Who's awake right now uses so you are not guessing across timezones.",
            tips: [
                "Escalate if I don't respond is off until you turn it on. If you then miss a trigger window check-in, a reminder to message that person shows up after the number of minutes you chose. It is only a reminder to you. Anchor never messages anyone by itself.",
                "For Discord you need the person's numeric user ID, not their username.",
                "Deleting a contact also deletes their page in Thread."
            ]
        ),
        GuideEntry(
            id: "plan.safety-plan", tab: .plan, title: "Safety plan", icon: "shield.fill",
            whatItIs: "A plan you write once, while you are calm, so it is there when you need it.",
            howToUse: "It is made of sections that belong to you. It starts with four, and every one can be renamed, rewritten, hidden or deleted. Tap a card to open it and change its name, its words, its icon and colour, and whether it shows. The plus adds a section of your own, and Reorder changes the order. Nothing is written for you.",
            tips: [
                "One section at a time can be used for reminder quotes. Turn on Use this for reminder quotes inside it, and trigger window reminders can quote a line from it, always in your own words.",
                "A hidden section stays saved. It just does not show.",
                "The date it was last changed is shown at the bottom."
            ]
        ),
        GuideEntry(
            id: "plan.trigger-windows", tab: .plan, title: "Trigger windows", icon: "clock.fill",
            whatItIs: "The times of day that tend to be hard, so Anchor can check in with you then.",
            howToUse: "Add a window with a label, the days it applies to, and a start and end time. While a window is active, Anchor sends a reminder on those days at the start time, with your label as its title. The first time you switch one on, iOS asks whether Anchor may send notifications. The wording is a plain fixed line, sometimes with a line from your safety plan. A window is only about the time and the days. It never uses your location.",
            tips: [
                "Switch Active off to pause a window without deleting it.",
                "If a contact has Escalate if I don't respond turned on, a check-in you do not answer can lead to a reminder to message them.",
                "Reminders stay on this phone."
            ]
        ),
        GuideEntry(
            id: "plan.appointments", tab: .plan, title: "Appointments", icon: "calendar",
            whatItIs: "Your sessions with each person you see, on a calendar you can change.",
            howToUse: "Tap an empty day to schedule a session, or use the plus for any date. Tap a day with a session to move or cancel it. A session you have moved is marked Moved. Switch Repeat on when you schedule to make a run of sessions. Typical cadence is only a starting point for suggesting dates, and the real gap can be shorter or longer. If you see more than one person, add them from the menu at the top. Each one has their own sessions and notes, and a Name on exports, which is the name used on files you make for them.",
            tips: [
                "Session prep and Things to raise in Bridge follow the person you pick.",
                "If you remove someone, their items stay and become for anyone."
            ]
        ),
        GuideEntry(
            id: "plan.grounding-tools", tab: .plan, title: "Grounding tools", icon: "leaf.fill",
            whatItIs: "Things that help you settle, written by you and shown on Now.",
            howToUse: "A tool is either a physical action or a link. For an action, write one step per line and each line becomes its own screen, so you can step through one at a time. For a link, paste a Spotify or Discord link or any other. If the app is not installed, Anchor tries the browser instead. Under When it's relevant you can limit a tool to certain times of day, or leave them all off to show it at any time. Try it step by step shows how it will look.",
            tips: [
                "Nothing is built in. Only what you add appears on Now."
            ]
        ),
        GuideEntry(
            id: "now.tasks", tab: .plan, title: "Tasks", icon: "checkmark.circle.fill",
            whatItIs: "A task list that can be as small or as detailed as the day allows.",
            howToUse: "Type in the box and tap Add, or use the plus for the full sheet. Tick the circle to finish a task. Swipe right to move a task to tomorrow or set it aside, and swipe left to delete it. Holding a task shows the same choices. Tasks sit in groups: Today, This week, Later, No date, Waiting on something else, and Set aside for now. In a task's sheet you can add steps, a first tiny step, a task it is waiting on, when it is due (including As soon as I can and Someday), how long it takes, how it is going, how much energy it needs, and notes. The menu at the top has Quick list, Plan my day, the Focus timer and Import from Reminders.",
            tips: [
                "On a low day the menu can show only the tasks that need a little energy, or some energy or less. A task with no energy set always shows.",
                "A task that waits on another is dimmed until the other is done, then it unlocks by itself.",
                "Plan my day lets you pick a few tasks or steps, put them in order and go through them one at a time.",
                "The Focus timer has lengths you set yourself. Its alert and its lock screen timer are off until you turn them on, and neither shows the task."
            ]
        ),
        GuideEntry(
            id: "now.quick-list", tab: .plan, title: "Quick list", icon: "list.bullet.clipboard",
            whatItIs: "A one-off checklist for something small, like a shopping run or a bag to pack.",
            howToUse: "Choose Quick list in the Tasks menu, or Make a quick list when there are no tasks yet. Give it a name if you like, then type or paste the items, one per line. Tick them off as you go. When the last one is ticked, the list moves to the Archive by itself, and unticking one brings it back. The menu on a list can move what is left into your tasks, start it again, or delete it.",
            tips: [
                "Pasting works well. A bullet, dash, number or tick box at the start of a line is dropped.",
                "Nothing is counted against you."
            ]
        ),
        GuideEntry(
            id: "plan.presets", tab: .plan, title: "Decision presets", icon: "checklist",
            whatItIs: "Choices you make once, ahead of time, so a worn-out day does not have to include deciding.",
            howToUse: "The Presets screen has three sides at the top: Decisions, Routines and Lists. On Decisions, each category holds options, such as what to eat when you cannot think. Tap an option to change it, tap a category's name to rename it, and use the plus for a new category. Add an option sits inside each card. An option can have steps to click through, and the play button runs them one at a time.",
            tips: [
                "Leave the steps empty if an option is just a plain choice.",
                "These are easiest to set up on a calmer day."
            ]
        ),
        GuideEntry(
            id: "plan.routines", tab: .plan, title: "Routines", icon: "list.number",
            whatItIs: "Steps you do in the same order each time, like a school morning.",
            howToUse: "Add a routine, name it and write its steps. Each step can have a rough time. Run it shows one step at a time and where you are in the list. Remind me is off until you switch it on, and then you pick the days and the time. The first time you switch it on, iOS asks whether Anchor may send notifications.",
            tips: [
                "The reminder never shows the routine's name on your lock screen.",
                "Nothing is counted. There are no streaks."
            ]
        ),
        GuideEntry(
            id: "plan.lists", tab: .plan, title: "Lists", icon: "list.bullet.rectangle",
            whatItIs: "Checklists sorted under headings, where an amount can follow a number you set.",
            howToUse: "A list holds items under headings and ticks them off. Add a number to the list, like Days or People, and an item can follow it: one T-shirt for each day, with some extra for every few days. Change the number and every amount changes with it. A list shows how many are ticked, never a percentage. The menu on a list has Reset ticks to start again, Make a copy, and Delete list.",
            tips: [
                "An item that followed a number you remove goes back to a set amount."
            ]
        ),
        GuideEntry(
            id: "now.de-escalation", tab: .plan, title: "De-escalation scripts", icon: "wind",
            whatItIs: "Words for getting some space, in a voice that sounds like you.",
            howToUse: "A script is a short line you can say or send when you need ten minutes. On Now, one shows at a time with a Try another button. Tap a card here to rewrite it, use the plus to add one, and use Reorder to change the order Try another goes through.",
            tips: [
                "Write them in the words you would really use."
            ]
        ),
        GuideEntry(
            id: "now.affirmations", tab: .plan, title: "Affirmations", icon: "sparkles",
            whatItIs: "Lines you want to hold onto, shown on Now one at a time.",
            howToUse: "Write your own, or open Browse suggestions and keep the ones that land. On Now, the Something to hold onto card shows one with an Another button. Tap a card here to rewrite it, and use Reorder to change the order Another goes through.",
            tips: [
                "The quotes in trigger window reminders come from your safety plan, not from here."
            ]
        ),
        GuideEntry(
            id: "plan.sleep", tab: .plan, title: "Sleep", icon: "moon.stars.fill",
            whatItIs: "A quiet record of your nights, only for you to look back over.",
            howToUse: "Add a night with when you went to bed and when you woke, and the time asleep is worked out. If you do not know the times, type how long you slept instead. Pick how it felt from three words you can rename, and write a note if you want one. The screen shows a dot for each of the last 30 nights and a plain line on the usual range. There is no score, no target and no streak. Settings has switches for a Last night card on Now, a small row for each night in the Journal, one more question in a check-in, and a morning reminder. All of them are off until you turn them on.",
            tips: [
                "Sleep starts hidden on Plan. Turn it on under Customise.",
                "Apple Health is optional and sits at the bottom of this screen. Nothing is asked of Health until you tap Connect, and a night you typed is never replaced.",
                "Remove imported sleep takes out the nights that came from Health, and leaves Health itself alone."
            ]
        ),
        GuideEntry(
            id: "plan.your-data", tab: .plan, title: "Your data", icon: "lock.shield.fill",
            whatItIs: "Everything Anchor stores about you, and what you can do with it.",
            howToUse: "Look at what's stored asks for your lock again, then lists every kind of thing Anchor holds. It is read only, with a switch to blur what is written. Export everything is plain text without photos or voice notes, so anyone with the file can read it. Make an encrypted backup includes photos and voice notes and is locked with a password you choose. Import opens either kind. The CSV and PDF exports are for your journal and check-ins, over all time or a date range. Clear all data removes everything from this phone and cannot be undone.",
            tips: [
                "Anchor does not keep a backup's password and cannot get it back, so keep it somewhere safe.",
                "To share something with your psych, use the share button on Bridge instead. You choose what goes in."
            ]
        )
    ]
}

/// The page for one entry, shared by the "?" sheet and the tour.
struct GuideEntryBody: View {
    let entry: GuideEntry

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Anchor.Theme.accentSoft).frame(width: 56, height: 56)
                Image(systemName: entry.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Anchor.Theme.accent)
            }
            .accessibilityHidden(true)
            Text(entry.title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
            Text(entry.whatItIs)
                .font(.system(.body, design: .rounded).weight(.medium))
                .multilineTextAlignment(.center)
            Text(entry.howToUse)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !entry.tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Good to know")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    ForEach(entry.tips, id: \.self) { tip in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(tip)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct GuideSheetView: View {
    let entry: GuideEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                GuideEntryBody(entry: entry)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 32)
            }
            .anchorBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
    }
}

/// The sheet for a tab's own topic, kept so the five tab roots need no change.
struct HelpSheetView: View {
    let topic: HelpTopic

    var body: some View {
        GuideSheetView(entry: Guide.tabEntry(topic))
    }
}

/// The "?" button for one screen. It opens that screen's entry, or its tab's
/// while the screen has none of its own yet.
struct GuideToolbarButton: View {
    let entryID: String
    let tab: HelpTopic
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .accessibilityLabel("Help for this screen")
        .sheet(isPresented: $showing) {
            GuideSheetView(entry: Guide.entry(for: entryID, tab: tab))
        }
    }
}

extension View {
    /// Puts the "?" button in a screen's toolbar. Pass the screen's guide id and its tab.
    func guideButton(_ id: String, tab: HelpTopic) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GuideToolbarButton(entryID: id, tab: tab)
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
        .accessibilityLabel("Help for this screen")
        .sheet(isPresented: $showHelp) {
            HelpSheetView(topic: topic)
        }
    }
}

/// A help sheet for something that is not one of the five tabs, such as Showcase mode in Settings.
/// It looks like HelpSheetView, with room for several short paragraphs.
struct HelpNoteSheet: View {
    let icon: String
    let title: String
    let paragraphs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Anchor.Theme.accentSoft).frame(width: 64, height: 64)
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(Anchor.Theme.accent)
                    }
                    .padding(.top, 32)
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    ForEach(paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .anchorBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it") { dismiss() }
                }
            }
        }
    }
}

/// The "?" button for a screen that is not a tab. It opens a HelpNoteSheet.
struct HelpNoteToolbarButton: View {
    let icon: String
    let title: String
    let paragraphs: [String]
    @State private var showHelp = false

    var body: some View {
        Button {
            showHelp = true
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .accessibilityLabel("Help for this screen")
        .sheet(isPresented: $showHelp) {
            HelpNoteSheet(icon: icon, title: title, paragraphs: paragraphs)
        }
    }
}

enum ShowcaseHelp {
    static let paragraphs: [String] = [
        "Showcase mode lets you show someone Anchor without showing them your own things. While it is on, Anchor shows made-up people, entries and plans, and your real data is not opened.",
        "Your widgets are emptied and your waiting reminders are taken off the phone, so nothing of yours turns up on the lock screen or as a notification. Both come back when you turn it off.",
        "Anything you add while it is on is made up too, and is gone when you close the app. The buttons for sharing and exporting are left out, and Your data is switched off, so nothing can be sent from a showcase.",
        "Anchor does not ask for Face ID while it is on, and it stays on if you close the app. To turn it off, type the showcase passcode if you set one, or use your phone's own Face ID or passcode. The phone's own always works, so forgetting the showcase passcode never locks you out.",
        "It needs a phone with Face ID, Touch ID or a passcode, so there is always a way out."
    ]
}
