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

    /// Written as short paragraphs, one idea each, separated by a blank line. The detail for each
    /// screen is in that screen's own entry, so this stays an overview.
    var explanation: String {
        switch self {
        case .now:
            return "Now is the quick home screen. It is for the moment you are in, so nothing here needs setting up.\n\nThe crisis numbers for your region, your grounding tools, quick contacts, tasks, check-ins and today's affirmation are all here.\n\nIf you keep a Recovery counter, it sits here too, with a shortcut for riding out an urge.\n\nSet things up ahead of time in Plan. Come to Now when you need something straight away."
        case .plan:
            return "Plan is where you set things up ahead of time, so they are ready when you need them. Come here when you are calm, not in the middle of a hard moment.\n\nContacts, your safety plan, trigger windows and appointments are here, each with its own page.\n\nYour tasks are here too, with steps, a focus timer and Plan my day. Grounding tools, decision presets, routines, lists, de-escalation scripts and affirmations are what Now draws on.\n\nSleep is a quiet record of your nights. It is off until you add it under Customise, and it has no score and no target.\n\nCustomise, under the widgets, lets you reorder and hide them. The gear at the top opens Settings, where the switches, reminders and Your data are.\n\nTap the question mark on any of these screens to read about it."
        case .journal:
            return "The Journal is a timeline of what you have written, with your check-ins on the same line. Each check-in shows its five sliders as small bars, exactly where you left them. Nothing is scored.\n\nTap the pencil to write. The tools at the bottom add Journaling Suggestions, photos, drawings, a prompt and formatting.\n\nSwitch to Month for a calendar or Year for the whole year, and use search to find anything you have written.\n\nBookmark an entry from its menu or by pressing and holding it, then choose Bookmarked only to see just those. Press and hold also copies its first line into Things to raise in Bridge.\n\nIf you keep a sleep journal, Settings can show each night as a small row here."
        case .bridge:
            return "Bridge is everything that makes talking to your psych easier.\n\nThings to raise is a list of what you want to bring up. Session prep gathers it for the next session, and Post-session notes are for afterwards. Each person you see has their own.\n\nPersonal goals and Feedback-loop diagrams are optional tools for thinking things through. Nothing in them is scored.\n\nThe share button opens Export for someone. You choose what goes in, and only Things to raise is on to begin with, every time.\n\nTap the question mark on any of these screens to read about it."
        case .thread:
            return "Thread is for the people who matter to you.\n\nThe Message log is a record of what you have written to each of your contacts. You can send a message through Messages or Discord, add a voice note, or just keep it.\n\nMessage starters, People, the Support calendar, notes to your future self, things you have not said and a Boundaries list are all here, and each is yours to arrange. Nothing is scored, and nothing is sent unless you choose to send it.\n\nTap the question mark on any of these screens to read about it."
        }
    }
}

// MARK: - Guide registry

/// One entry in the guide. `id` is stable: a screen names its entry with it,
/// so renaming a title never breaks the link.
struct GuideEntry: Identifiable, Hashable {
    let id: String
    /// The tab it belongs to. The tour goes tab by tab, a tab's own entry first.
    /// Settings is not one of the five tabs, so its entries have no tab.
    let tab: HelpTopic?
    let title: String
    let icon: String
    /// One or two sentences on what this is.
    let whatItIs: String
    /// How to use it, in plain prose.
    let howToUse: String
    /// Short extras, listed under the text when there are any.
    let tips: [String]
    /// False for an entry that only the "?" on its own screen should open, so the tour stays short.
    var inTour: Bool = true
}

enum Guide {
    /// Entries for individual screens. They are written tab by tab, and each
    /// one is looked up by the id a screen passes to `guideButton`.
    static let screenEntries: [GuideEntry] = planEntries + journalEntries + bridgeEntries + threadEntries + recoveryEntries + settingsEntries

    /// The entry for a tab itself, built from its topic so the text lives in one place.
    static func tabEntry(_ topic: HelpTopic) -> GuideEntry {
        GuideEntry(id: topic.rawValue, tab: topic, title: topic.tabName, icon: topic.icon,
                   whatItIs: topic.summary, howToUse: topic.explanation, tips: [])
    }

    /// The entry a screen should show: its own if it has one, otherwise its tab's.
    /// A screen in Settings has no tab, so it falls back to the Settings entry.
    static func entry(for id: String, tab: HelpTopic?) -> GuideEntry {
        if let found = screenEntries.first(where: { $0.id == id }) { return found }
        if let tab { return tabEntry(tab) }
        return screenEntries.first { $0.id == "settings" } ?? tabEntry(.now)
    }

    /// Everything in tour order: the five tabs first, one page each, so the main
    /// places are met before any detail. Then each tab's screens in the same tab
    /// order, and Settings last. Entries marked `inTour: false` are left out.
    static var tourEntries: [GuideEntry] {
        let tabs = HelpTopic.allCases.map { tabEntry($0) }
        let screens = HelpTopic.allCases.flatMap { topic in
            screenEntries.filter { $0.tab == topic && $0.inTour }
        }
        return tabs + screens + screenEntries.filter { $0.tab == nil && $0.inTour }
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
                "Escalate if I don't respond is off until you turn it on. If you then miss a trigger window check-in, a reminder to message that person shows up after the number of minutes you chose. It is only a reminder to you. Anchor never messages anyone by itself, and the words on the lock screen do not name anyone.",
                "For Discord you need the person's numeric user ID, not their username.",
                "Deleting a contact also deletes their page in Thread."
            ]
        ),
        GuideEntry(
            id: "plan.safety-plan", tab: .plan, title: "Safety plan", icon: "shield.fill",
            whatItIs: "A plan you write once, while you are calm, so it is there when you need it.",
            howToUse: "It is made of sections that belong to you. It starts with four, and every one can be renamed, rewritten, hidden or deleted. Tap a card to open it and change its name, its words, its icon and colour, and whether it shows. The plus adds a section of your own, and Reorder changes the order. Nothing is written for you.",
            tips: [
                "One section at a time can be used for reminder quotes. Turn on Use this for reminder quotes inside it, and a line from it shows when you open a trigger window reminder, always in your own words. It never shows on the lock screen.",
                "A hidden section stays saved. It just does not show.",
                "The date it was last changed is shown at the bottom."
            ]
        ),
        GuideEntry(
            id: "plan.trigger-windows", tab: .plan, title: "Trigger windows", icon: "clock.fill",
            whatItIs: "The times of day that tend to be hard, so Anchor can check in with you then.",
            howToUse: "Add a window with a label, the days it applies to, and a start and end time. While a window is active, Anchor sends a reminder on those days at the start time. The first time you switch one on, iOS asks whether Anchor may send notifications. On the lock screen it says only Anchor and a plain line, so a glance at your phone tells nobody anything. Open the reminder and Anchor shows your label, and a line from your safety plan if you have chosen a section for that. A window is only about the time and the days. It never uses your location.",
            tips: [
                "Switch Active off to pause a window without deleting it.",
                "If a contact has Escalate if I don't respond turned on, a check-in you do not answer can lead to a reminder to message them. Answering one day's reminder only skips that day. The following weeks keep theirs.",
                "Reminders stay on this phone."
            ]
        ),
        GuideEntry(
            id: "plan.appointments", tab: .plan, title: "Appointments", icon: "calendar",
            whatItIs: "Your sessions with each person you see, on a calendar you can change.",
            howToUse: "The sessions coming up are at the top, each with how far away it is. Tap an empty day on the calendar to schedule a session, or use the plus for any date. Tap a day with a session, or a session in the list, to move or cancel it. Switch Repeat on when you schedule to make a run of sessions. Earlier sessions are folded under the list. If you see more than one person, the person button at the top adds them and holds each one's details.",
            tips: [
                "Reminders for sessions are off until you switch them on, from the line under the list or in Settings. One comes the evening before, at 6 pm unless you pick another time in Settings, and one a couple of hours ahead. The lock screen only says something you planned is coming up. Tap a reminder and Anchor opens Session prep for that person.",
                "The usual gap between sessions is in each person's details. It is only a starting point for a repeating run.",
                "Remove all sessions is in the three dots menu.",
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
                "Apple Health is optional and sits at the bottom of this screen, with one switch for bringing nights in and one for saving the nights you type. Nothing is asked of Health until you switch one on, and a night you typed is never replaced.",
                "Bringing nights in only reads sleep. To stop Anchor asking at all, change Sleep under Sharing in the Health app. Remove imported sleep takes out the nights that came from Health and leaves Health itself alone.",
                "Saving writes only nights with both a bed time and a wake time, marked as coming from Anchor. A night Health already has from somewhere else is left alone, and deleting a night here removes the one Anchor saved. Remove what Anchor saved takes out only that."
            ]
        ),
        GuideEntry(
            id: "plan.your-data", tab: .plan, title: "Your data", icon: "lock.shield.fill",
            whatItIs: "Everything Anchor stores about you, and what you can do with it.",
            howToUse: "Look at what's stored asks for your lock again, then lists every kind of thing Anchor holds. It is read only, with a switch to blur what is written. Export everything is plain text without photos or voice notes, so anyone with the file can read it. Make an encrypted backup includes photos and voice notes and is locked with a password you choose. Import opens either kind. The CSV and PDF exports are for your journal, check-ins and sleep, over all time or a date range. Clear all data removes everything from this phone and cannot be undone.",
            tips: [
                "Anchor does not keep a backup's password and cannot get it back, so keep it somewhere safe.",
                "To share something with your psych, use the share button on Bridge instead. You choose what goes in."
            ]
        )
    ]
}

// MARK: - Guide entries: Bridge, Thread and Recovery

// Patch 43a. Journal and Settings follow in 43b. There is no entry for the NSW mental health
// law screen, because it is only compiled into personal builds and the tour must not describe
// a screen the public app does not have. Recovery screens sit on the Now tab, where the
// Recovery counter lives.

extension Guide {
    static let bridgeEntries: [GuideEntry] = [
        GuideEntry(
            id: "bridge.things-to-raise", tab: .bridge, title: "Things to raise", icon: "text.bubble.fill",
            whatItIs: "A list of what you want to bring up, kept for your next session.",
            howToUse: "Add things whenever they come up, with the plus. Tap an item to reword it, and tick it off on its card once you have said it. In an item's sheet you can mark it as a question to ask, with room to write the answer afterwards, and switch on Already brought up. With two or more providers, each item can be for anyone or for one person. The filter button then shows what is for one person and for anyone. The share button opens Export for someone.",
            tips: [
                "In the Journal, hold an entry and choose Add to things to raise to copy its first line here.",
                "Session prep shows what is still waiting here, and you choose whether it goes into your notes."
            ]
        ),
        GuideEntry(
            id: "bridge.session-prep", tab: .bridge, title: "Session prep", icon: "calendar.badge.clock",
            whatItIs: "One place to get ready for your next session with a person.",
            howToUse: "It shows the next session and a place for prep notes. Under that are cards that look back since your last session: your journal entries and check-ins, your sleep and your Recovery counters if you keep them, and what is still waiting in Things to raise. To bring is a short checklist of your own for that one session. You need an upcoming session, which you add in Plan under Appointments.",
            tips: [
                "Cards are only shown here. Nothing goes into your notes unless you add it.",
                "Check-ins are only counted, never read out.",
                "Nothing is suggested, and the next session starts with an empty To bring list."
            ]
        ),
        GuideEntry(
            id: "bridge.post-session", tab: .bridge, title: "Post-session notes", icon: "note.text",
            whatItIs: "Your own notes on how a session went, one for each session.",
            howToUse: "Past sessions are listed with whether they have notes yet. Tap one and write whatever you want to keep. If you close it with nothing written, no note is kept. A line that starts with [ ] is a thing to do: Add a thing to do starts one for you, and under the note each one has an Add as task button.",
            tips: [
                "Nothing goes into Tasks unless you tap Add as task. The task has no date, and the line stays in your note.",
                "With more than one provider, a row of names at the top of Bridge switches between them."
            ]
        ),
        GuideEntry(
            id: "bridge.goals", tab: .bridge, title: "Personal goals", icon: "flag.fill",
            whatItIs: "Goals in your own words, with a few notes along the way.",
            howToUse: "Use the plus to write what you want and why it matters to you. Say where it is: Working on it, Reached or Set aside for now. Add short dated notes as things change. Tap a goal to open it.",
            tips: [
                "Nothing is scored and nothing becomes a percentage.",
                "The SMART frame is a switch inside a goal. It is off unless you turn it on, and any part can stay blank."
            ]
        ),
        GuideEntry(
            id: "bridge.feedback-loops", tab: .bridge, title: "Feedback-loop diagrams", icon: "arrow.triangle.2.circlepath",
            whatItIs: "A way to draw how things feed into each other, in your own words, to show someone else.",
            howToUse: "The plus offers New loop, New map or From a template. A loop is a ring of steps: write what happens first, what that leads to, and so on, and the last step leads back to the first. Mark each link as more leading to more, or more leading to less, and Anchor says in plain words whether the loop tends to keep itself going or to settle back. A map is free: drag the background to move, pinch to zoom, drag items to place them, and switch to Link to connect one item to another. The menu on a diagram can share it as a picture or a PDF, with the written reading on or off.",
            tips: [
                "A loop can be opened as a free map from its menu.",
                "Undo and Redo are at the bottom of a map.",
                "A template makes a copy you can rewrite."
            ]
        ),
        GuideEntry(
            id: "bridge.export", tab: .bridge, title: "Export for someone", icon: "square.and.arrow.up",
            whatItIs: "A file for one person, with only what you choose to put in it.",
            howToUse: "Write who it is for, and a note for the top if you like. Then choose what goes in. Only Things to raise is on to begin with, every time. Your journal, check-ins, sleep and a Recovery summary stay out unless you switch them on, and you can limit it to a date range or tick single items. A count and a preview show what it holds before anything is made. You can make a PDF, or a web page that opens in any browser with search, a timeline, charts of check-ins and buttons to print or to download a CSV or a Word file.",
            tips: [
                "The web page can have a password. Anchor does not keep it and cannot get it back, so tell the person another way.",
                "Some mail apps block web pages, so a PDF is the safer thing to send.",
                "Choosing a provider fills in their name, and exporting for that person leaves out what was meant for someone else."
            ],
            inTour: false
        )
    ]

    static let threadEntries: [GuideEntry] = [
        GuideEntry(
            id: "thread.messages", tab: .thread, title: "Message log", icon: "bubble.left.and.bubble.right.fill",
            whatItIs: "A record of what you have written to the people in your life, tied to your contacts.",
            howToUse: "Write something opens a sheet where you pick who it is about, write the message, and add a voice note if you like. You can save it privately, or save it and send it through Messages or Discord. Tap an earlier message to see it, send it again or copy it. The filter at the top shows what you have said to one person. The speech bubble opens your message starters.",
            tips: [
                "Saving privately sends nothing to anyone.",
                "The first time you record, iOS asks for the microphone.",
                "Anchor never sends a message by itself."
            ]
        ),
        GuideEntry(
            id: "thread.message-starters", tab: .thread, title: "Message starters", icon: "text.bubble",
            whatItIs: "Short lines of your own for starting a message when talking is hard.",
            howToUse: "Use the plus to write a line. When you write a message, tap a starter to begin with it, and change it before anything is sent. They also appear when you use Quick contact on Now.",
            tips: [
                "The list starts empty. Nothing is written for you."
            ]
        ),
        GuideEntry(
            id: "thread.people", tab: .thread, title: "People", icon: "person.crop.circle.fill",
            whatItIs: "A page for each of your contacts, for whatever you want to keep about them.",
            howToUse: "People you add under Contacts in Plan appear here. A person's page has sections that you write and arrange yourself, such as a note, what helps, and things you have told them. It also shows the last few messages in your log with them and the support calendar days you have shared with them. Sections can be hidden or deleted.",
            tips: [
                "Nothing on a page is counted or scored, and nothing is sent from it.",
                "Deleting a contact deletes their page."
            ]
        ),
        GuideEntry(
            id: "thread.support-calendar", tab: .thread, title: "Support calendar", icon: "calendar.badge.clock",
            whatItIs: "Days when you would like some extra support, and who can see each one.",
            howToUse: "Use the plus to mark a day and choose which of your contacts can see it. Share with makes a calendar file of the days you chose to share, so the person does not need Anchor to open it.",
            tips: [
                "Add contacts in Plan first, so there is someone to choose.",
                "A day nobody can see is not shared."
            ]
        ),
        GuideEntry(
            id: "thread.future-notes", tab: .thread, title: "To future me", icon: "envelope.open.badge.clock",
            whatItIs: "Notes to yourself that stay sealed until you are ready to read them.",
            howToUse: "Use the plus and choose how it opens. A note on a date stays sealed until that day, and until then only the date shows. A letter that opens when you choose has a few words after Open when, such as the kind of night it is for, and no date. You open it yourself when you need it.",
            tips: [
                "A sealed note cannot be read early.",
                "A letter is never locked. In Your data, Look at what's stored lists it by its Open when words, and a search does not look inside it."
            ]
        ),
        GuideEntry(
            id: "thread.unsent", tab: .thread, title: "Things I haven't said", icon: "square.and.pencil",
            whatItIs: "A private place for the big things you might never send to anyone.",
            howToUse: "Write now, and share only if and when you are ready. If you do send something somewhere, switch on I've actually sent this and it is marked Sent.",
            tips: [
                "Nothing here goes anywhere unless you send it yourself."
            ]
        ),
        GuideEntry(
            id: "thread.boundaries", tab: .thread, title: "Boundaries", icon: "hand.raised.fill",
            whatItIs: "A short list of what you would like people to know, what helps and what does not.",
            howToUse: "It is made of sections that belong to you, like the Safety plan. Tap one to rename it, write in it and change how it looks, and use the plus to add more. A section marked Can be shared goes out when you tap Share, and nothing else does. Hide keeps a section but takes it off the list, and Reorder changes the order.",
            tips: [
                "Deleting a section deletes what is written in it."
            ]
        )
    ]

    static let recoveryEntries: [GuideEntry] = [
        GuideEntry(
            id: "recovery.home", tab: .now, title: "Recovery", icon: "calendar.badge.checkmark",
            whatItIs: "Your own counters, kept on this phone.",
            howToUse: "Add a counter for something you are stepping away from, or a habit you are building. You choose the name, the start date and how the days are counted. From here you can also open Riding out an urge, a timer with your reasons and your grounding tools, and Who I'm doing this for.",
            tips: [
                "Nothing here is scored, shared or compared.",
                "A counter can sit on Now as a widget."
            ]
        ),
        GuideEntry(
            id: "recovery.counter", tab: .now, title: "A counter", icon: "calendar",
            whatItIs: "One counter, with everything that goes with it.",
            howToUse: "The screen has Summary, Savings, Calendar, Urges, Reasons and Today. Today holds the daily pledge and an evening review with a few optional words. Urges lets you log a hard moment and say how strong it was, then ride it out if you want to. When you reach a milestone you can tick Noted, or tell someone, and you can change the message before it sends. If it costs money, Savings keeps a rough running estimate of what you have not spent. Streak history shows your start dates and, when you start again, you can note how many times it happened that day.",
            tips: [
                "Everything stays on your phone.",
                "Starting again is part of the record, not a mark against you.",
                "Before tracking is a number only you see, for your own reference."
            ]
        ),
        GuideEntry(
            id: "recovery.motivations", tab: .now, title: "Who I'm doing this for", icon: "heart.fill",
            whatItIs: "The people, pets or future you that matter, and why.",
            howToUse: "Use the plus to add someone, or a reason in your own words. They show up when you take today's pledge and when you are riding out an urge.",
            tips: [
                "They are only for you."
            ]
        )
    ]
}

// MARK: - Guide entries: Journal and Settings

// Patch 43b. The Journal tab's own page is the tab entry, so only the two screens opened from
// it are here: the page you write on, and Journaling Suggestions. Settings is not a tab, so its
// entries have no tab and come last in the tour. Showcase mode keeps its own help sheet, and
// the Encryption screen is a test build screen, so its entry is only compiled into test builds.
// The words are plain and fixed, and nothing here is scored or counted.

extension Guide {
    static let journalEntries: [GuideEntry] = [
        GuideEntry(
            id: "journal.editor", tab: .journal, title: "Writing a page", icon: "square.and.pencil",
            whatItIs: "One calm page for what you want to write down. Your words go in paragraphs, and photos, drawings and cards sit between them as blocks.",
            howToUse: "Start typing. The row of tools at the bottom has Journaling Suggestions, Photos, Drawing, Writing prompt and Formatting. A photo, drawing or card becomes a block on the page. Hold a block, or use its menu, to move it up or down or remove it. The three dots at the top left can bookmark the entry or copy its first line into Things to raise for your next session, and Done at the top right closes the page.",
            tips: [
                "What you write is saved as you go. An entry with nothing written in it is removed when you tap Done.",
                "A writing prompt is one of a fixed set of lines. Use this adds it to your page, Another one shows a different line, and the cross puts it away. Nothing is made up on the spot.",
                "Formatting opens a row of buttons for the look of your words. Tap it again to put the row away.",
                "Copying a line into Things to raise leaves the entry as it was."
            ]
        ),
        GuideEntry(
            id: "journal.suggestions", tab: .journal, title: "Journaling Suggestions", icon: "sparkles",
            whatItIs: "Things from the day of the entry that you can add to the page: Apple's own suggestions, calendar events, photos and songs you played recently.",
            howToUse: "Browse suggestions opens Apple's picker, where you choose what to share with Anchor. Below it are the events and photos from that day and your recently played songs. Tap one to add it to the page as a block, and this screen closes. Each of those three has its own button, and Anchor asks for that access only when you tap it. If it was allowed before, it just shows. If you say no, that part stays empty and the rest still works.",
            tips: [
                "Nothing is added until you tap it, and nothing leaves your phone.",
                "A photo you add is copied into Anchor and kept with the entry.",
                "You can change what Anchor may see later, in the phone's own Settings under Anchor."
            ],
            inTour: false
        )
    ]

    static let settingsEntries: [GuideEntry] = settingsScreenEntries + settingsTestBuildEntries

    private static let settingsScreenEntries: [GuideEntry] = [
        GuideEntry(
            id: "settings", tab: nil, title: "Settings", icon: "gearshape.fill",
            whatItIs: "The switches, reminders and controls for the whole app. You can use Anchor without changing any of them.",
            howToUse: "Privacy has Require Face ID, which locks Anchor on its own, separately from your phone's lock. Reminders has the daily check-in, with a time you choose, and the focus timer's alerts and lock screen timer. Session reminders has two switches for the evening before and a couple of hours before a session. Layout switches Plan, Bridge and Thread between widgets and a grid of icons, and opens Customise widgets. Your data and help has Your data, Take the tour, About Anchor and Showcase mode.",
            tips: [
                "The reminders and the optional extras are off until you switch them on.",
                "Routine reminders, Recovery and Sleep only show here once you have a routine, a Recovery counter, or have started using Sleep, so Settings stays short until you need them.",
                "Recovery has a Daily pledge, an Evening review and Milestones, each with its own switch.",
                "What shows on the lock screen is plain wording. Routine, Session, Recovery and Sleep reminders never say what they are about.",
                "Require Face ID needs Face ID, Touch ID or a passcode on the phone. Without one, the switch cannot be used."
            ]
        ),
        GuideEntry(
            id: "settings.about", tab: nil, title: "About Anchor", icon: "info.circle",
            whatItIs: "The version and build, a short note on what Anchor is, and how to reach the person who makes it.",
            howToUse: "Email support opens a message that starts with the app version, the iOS version and the phone model, and nothing else, so you can write about a problem without looking those up. Copy puts the address on the clipboard instead. Links opens the website, the privacy policy and the source code, and What's new has a fold for each version of the app, with what it added, changed and removed. The newest is open and the older ones are closed until you tap them.",
            tips: [
                "Nothing is sent unless you send the email yourself.",
                "Replies are not instant. If you are in danger right now, call your local emergency number or a crisis line."
            ],
            inTour: false
        ),
        GuideEntry(
            id: "settings.customise", tab: nil, title: "Customise widgets", icon: "slider.horizontal.3",
            whatItIs: "Choose which widgets show on Plan, Bridge and Thread, and in what order.",
            howToUse: "Pick a tab at the top. Drag a row by its handle to reorder, and use the switch to hide or show a widget. Hidden widgets move to a More row at the bottom of the tab, so nothing is lost. Reset puts that tab back the way it started.",
            tips: [
                "Sleep starts hidden. Turn it on here when you want it.",
                "On Plan, Bridge and Thread you can also customise from the tab itself, and make a half-width widget full width there."
            ],
            inTour: false
        )
    ]

    private static var settingsTestBuildEntries: [GuideEntry] {
        #if DEBUG
        return [
            GuideEntry(
                id: "settings.encryption", tab: nil, title: "Encryption (test build)", icon: "key.fill",
                whatItIs: "The keys that will lock what Anchor stores. Nothing is locked with them yet.",
                howToUse: "Make a key and a recovery key creates a key on this phone and shows the recovery key once, so write it down then. Check my recovery key asks you to type it back, and Make a new recovery key replaces it. Restore with your recovery key is for a phone where the key is missing.",
                tips: [
                    "If the key is lost and there is no recovery key, locked data cannot be opened by anyone.",
                    "The recovery file is kept with your data so a restored phone can get the key back."
                ],
                inTour: false
            )
        ]
        #else
        return []
        #endif
    }
}

/// Splits a guide's text into its separate ideas. Text written as paragraphs (blank lines
/// between them) keeps those paragraphs. Anything else is split into sentences, so each idea
/// stands on its own line and none is buried in a block.
enum GuideText {
    static func ideas(in text: String) -> [String] {
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if paragraphs.count > 1 { return paragraphs }
        var result: [String] = []
        var current = ""
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            current.append(characters[index])
            let endsSentence = ".!?".contains(characters[index])
            if endsSentence, index + 2 < characters.count, characters[index + 1] == " ", characters[index + 2].isUppercase {
                result.append(current)
                current = ""
                index += 2
                continue
            }
            index += 1
        }
        let rest = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty { result.append(rest) }
        return result
    }
}

/// The page for one entry, shared by the "?" sheet and the tour. The first few ideas show,
/// each on its own, and the rest wait behind Show more, along with the extras, so a page is
/// short until the person asks for more.
struct GuideEntryBody: View {
    let entry: GuideEntry
    @State private var expanded = false

    /// How many ideas show before Show more.
    private let visibleIdeas = 4

    private var ideas: [String] { GuideText.ideas(in: entry.howToUse) }
    private var hasMore: Bool { ideas.count > visibleIdeas }
    private var shownIdeas: [String] { expanded ? ideas : Array(ideas.prefix(visibleIdeas)) }
    /// Extras show with the page when it is short, and behind Show more when it is not.
    private var showsTips: Bool { !entry.tips.isEmpty && (expanded || !hasMore) }

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

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(shownIdeas.enumerated()), id: \.offset) { _, idea in
                    Text(idea)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if hasMore {
                    Button(expanded ? "Show less" : "Show more") {
                        withAnimation { expanded.toggle() }
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .tint(Anchor.Theme.accent)
                }
                if showsTips {
                    VStack(alignment: .leading, spacing: 10) {
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
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    let tab: HelpTopic?
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
    /// A screen in Settings has no tab, so it leaves the tab out. A screen that already has
    /// a button on its right, such as Done, can ask for the left.
    func guideButton(_ id: String, tab: HelpTopic? = nil,
                     placement: ToolbarItemPlacement = .topBarTrailing) -> some View {
        toolbar {
            ToolbarItem(placement: placement) {
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
        "Your widgets show made-up content too, and your waiting reminders are taken off the phone, so nothing of yours turns up on the lock screen or as a notification. Your own widgets and reminders come back when you turn it off.",
        "Anything you add while it is on is made up too, and is gone when you close the app. Sharing and exporting work, but only on the made-up content. In Your data the encrypted backup, importing and clearing are switched off, so none of your own things can be sent from a showcase.",
        "Anchor does not ask for Face ID while it is on, and it stays on if you close the app. To turn it off, type the showcase passcode if you set one, or use your phone's own Face ID or passcode. The phone's own always works, so forgetting the showcase passcode never locks you out.",
        "It needs a phone with Face ID, Touch ID or a passcode, so there is always a way out."
    ]
}
