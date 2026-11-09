//
//  ReviewWalkthrough.swift
//  Anchor
//
//  A numbered walk through every change in the patch plan, for going through the app one change
//  at a time on made-up content. Test builds only: the whole file is compiled out of Release.
//
//  It runs only when the app is launched with both -AnchorDemo and -AnchorReview, so it always sits
//  on the in-memory store and never touches your real data. scripts/review-on-device.sh does that.
//

#if DEBUG

import SwiftUI
import SwiftData

enum ReviewMode {
    static var isOn: Bool {
        CommandLine.arguments.contains("-AnchorReview") && CommandLine.arguments.contains("-AnchorDemo")
    }
}

// MARK: - The stops

enum ReviewScreen: String, Identifiable {
    case tasks, sleep, decisions, routines, lists, contacts, safetyPlan, triggerWindows, grounding
    case affirmations, deEscalation, recovery, motivations, drafts, diagrams, goals, boundaries
    case people, futureNotes, supportCalendar, messages, starters, about, yourData, settings, unsent
    case appointments, prep, afterSession
    case customisePlan, customiseBridge, customiseThread

    var id: String { rawValue }

    @ViewBuilder var view: some View {
        switch self {
        case .tasks: TasksView()
        case .sleep: SleepView()
        case .decisions: PresetsView(start: .decisions)
        case .routines: PresetsView(start: .routines)
        case .lists: PresetsView(start: .lists)
        case .contacts: ContactsView()
        case .safetyPlan: SafetyPlanView()
        case .triggerWindows: TriggerWindowListView()
        case .grounding: GroundingToolsListView()
        case .affirmations: AffirmationsView()
        case .deEscalation: DeEscalationScriptsView()
        case .recovery: RecoveryHomeView()
        case .motivations: RecoveryMotivationsView()
        case .drafts: BridgeDraftListView()
        case .diagrams: FeedbackLoopDiagramListView()
        case .goals: PersonalGoalsView()
        case .boundaries: BoundariesView()
        case .people: PeopleView()
        case .futureNotes: FutureNoteListView()
        case .supportCalendar: SupportCalendarView()
        case .messages: ThreadMessagesView()
        case .starters: MessageStartersView()
        case .about: AboutView()
        case .yourData: DataControlView()
        case .settings: SettingsView()
        case .unsent: UnsentDraftsView()
        case .appointments: ProviderPageHost(page: .sessions)
        case .prep: ProviderPageHost(page: .prep)
        case .afterSession: ProviderPageHost(page: .afterSession)
        case .customisePlan: CustomiseWidgetsView(initialTab: .plan)
        case .customiseBridge: CustomiseWidgetsView(initialTab: .bridge)
        case .customiseThread: CustomiseWidgetsView(initialTab: .thread)
        }
    }
}

struct ReviewStop: Identifiable {
    let number: Int
    let patch: String
    let title: String
    /// What changed, in a line.
    let change: String
    /// What to do to see it.
    let tryIt: String
    /// Which tab to land on: 0 Now, 1 Plan, 2 Journal, 3 Bridge, 4 Thread.
    let tab: Int
    /// A screen to open over the tab, when it can be opened directly.
    let screen: ReviewScreen?

    var id: Int { number }
}

enum ReviewStops {
    private static func make(_ rows: [(String, String, String, String, Int, ReviewScreen?)]) -> [ReviewStop] {
        rows.enumerated().map { index, row in
            ReviewStop(number: index + 1, patch: row.0, title: row.1, change: row.2, tryIt: row.3, tab: row.4, screen: row.5)
        }
    }

    static let all: [ReviewStop] = make([
        ("1", "Never show 0 days", "A counter's current run steps down to hours or minutes instead of 0 days.",
         "Open Started today, the counter begun twenty minutes ago. Check the first-day wording, and the counter widget on Now.", 0, .recovery),
        ("2", "Cut-off labels", "Long widget titles and captions wrap to three lines, then shrink, and go full width.",
         "Look through the widgets on Now. Try a larger text size in Settings, Display.", 0, nil),
        ("3", "Check-in action bar", "Finish and A few optional questions are pinned in a bottom bar.",
         "On Now, start a check-in on this phone and see whether both buttons stay visible.", 0, nil),
        ("4", "Check-in question lines", "Each optional question has a reassurance line and sentence starters.",
         "Open A few optional questions and step through them.", 0, nil),
        ("5", "Check-in visual refresh", "Sliders are soft cards with an icon and end labels, and the mascot follows them.",
         "Move each slider and watch the card and the mascot.", 0, nil),
        ("6", "Journal newest first", "The timeline shows the newest day and entry first, with Jump to today.",
         "Scroll the Journal down, then use Jump to today.", 2, nil),
        ("7", "Journal editor", "One calm writing surface, a single Add button, Preview in a menu.",
         "Tap the pencil. Try Add, a prompt, and Preview.", 2, nil),
        ("8", "Journal month calendar", "Days and Month switch; a dot per entry and a square per check-in.",
         "Switch to Month and tap a day.", 2, nil),
        ("9", "Journal year overview", "Twelve small months; tap a month to open it.",
         "Switch to Year and tap a month.", 2, nil),
        ("10-11", "Tap to edit, Thread screens", "Tap a card to open it, plus to add, delete from inside or long-press.",
         "Try Thread: Boundaries, To future me, Support calendar. Tap, add, long-press.", 4, .futureNotes),
        ("12a", "Safety plan and trigger windows", "Tap a section to change it; trigger window cards open on tap; delete stops its reminders.",
         "Edit a section, then open a trigger window.", 1, .safetyPlan),
        ("12b", "Contacts and grounding tools", "One sheet when tapped, plus to add, labelled Reorder, a play button on tools with steps.",
         "Open Contacts, use Reorder. Open Grounding tools and press play.", 1, .contacts),
        ("12c", "Decision presets", "Tap an option to edit, tap a category name to rename, plus to add.",
         "Rename a category and add an option from inside its card.", 1, .decisions),
        ("12d", "Appointments", "One screen: tap a calendar day, plus for any date. (RV3 moved the cadence into the person's details.)",
         "Tap a calendar day and schedule a session.", 1, .appointments),
        ("13a", "Affirmations and scripts", "Open in one sheet when tapped; labelled Reorder on the first two.",
         "Open Affirmations, then De-escalation scripts.", 1, .affirmations),
        ("13b", "Bridge editing", "Tap a draft item, prep notes or a past session to write in it; the old Edit button is gone.",
         "Open Things to raise and tap an item.", 3, .drafts),
        ("14a", "Message log", "Write to a person in one tap, filter by person, Send again and Copy.",
         "Open the Message log, use Write to, and the person menu.", 4, .messages),
        ("14b", "Voice notes", "A message can carry a voice note: record, play, send as an attachment.",
         "Write a message and record a short voice note. (Needs the microphone allowed.)", 4, .messages),
        ("15", "Tasks", "A task list that lasts: tick, notes, plus, bottom bar, reorder, Reminders import.",
         "Open Tasks and add, tick and reorder.", 1, .tasks),
        ("16", "Task due dates", "Loose or exact timing; grouped as Today, This week, Later, No date.",
         "Open a task and change its timing. Check the groups.", 1, .tasks),
        ("17", "Subtasks", "Steps with a chevron, 2 of 5 steps and a small bar.",
         "Open Reply to one message and tick steps.", 1, .tasks),
        ("18", "Task dependencies", "A task can wait on others; dimmed and showing what it waits on.",
         "Find Bring the form along, then tick Call to book the appointment.", 1, .tasks),
        ("19", "Task status and energy", "Tiny first step, energy, started or set aside, swipe to tomorrow, lighter-only filter.",
         "Swipe a task to tomorrow. Use the filter for a low day.", 1, .tasks),
        ("20", "Widget editing", "Customise lets you drag, hide, add back and widen widgets.",
         "Open Customise on Plan, drag one widget, hide one, add it back.", 1, .customisePlan),
        ("21", "Focus timer", "Hold a task and Focus on this; lengths and alerts set with the gear; a bar shows it.",
         "Start a short focus session. Check the bar and the session count.", 1, .tasks),
        ("21b", "Focus on the lock screen", "A Live Activity with the phase and countdown, never the task.",
         "Switch it on in the timer settings, start a focus, lock the phone. (Needs a real device.)", 1, .tasks),
        ("22", "Plan my day", "Time estimates, pick tasks, order them, walk through one at a time.",
         "Tasks menu, Plan my day. Say how much time you have and go through it.", 1, .tasks),
        ("23", "Quick list", "A one-off checklist that moves to an Archive when the last item is ticked.",
         "Tasks menu, Quick list. Tick Water bottle and Wallet and watch it archive.", 1, .tasks),
        ("24", "Routines", "A named list of steps with rough times, run one step at a time.",
         "Open School mornings and use Run it.", 1, .routines),
        ("24b", "Routine reminder", "A reminder on the days and time you pick, off until switched on.",
         "Open a routine and look at its reminder. (Reminders are not scheduled in demo mode.)", 1, .routines),
        ("25", "Item lists", "Headings, numbers like Day, amounts that follow them, Reset ticks, Make a copy.",
         "Open Weekend away and change Day from 3 to 5.", 1, .lists),
        ("26", "Feedback loops, builder", "A guided loop with links marked more or less, and a plain reading.",
         "Open Waking in the night.", 3, .diagrams),
        ("27", "Feedback loops, free map", "Pan, zoom, undo and redo, arrows, colours, drag-to-link.",
         "Open How a hard day spreads. Pan, pinch, and drag one item onto another.", 3, .diagrams),
        ("28", "Diagram templates and sharing", "Start from a template; share as a picture or PDF.",
         "Use the plus menu, From a template. Then the menu on a diagram page.", 3, .diagrams),
        ("30a", "Safety plan sections", "Sections you rename, add, reorder, hide and delete, with icons and colours.",
         "Add a section and reorder. Choose the one used for reminder quotes.", 1, .safetyPlan),
        ("30b", "Boundaries", "Sections you can rename, hide and mark shareable.",
         "Open Boundaries. Check which sections are marked shareable.", 4, .boundaries),
        ("30c", "Message starters", "Your own short lines to start a message, also in Quick contact on Now.",
         "Open Message starters, then tap one while writing.", 4, .starters),
        ("30d", "Letters you open", "A note to future you that opens when you choose.",
         "Open To future me and the letter that says Open when it is a hard night.", 4, .futureNotes),
        ("30o", "Letters stay closed in the viewer", "Look at what's stored lists a letter by its Open when words, not by what it says, and a search does not look inside it. A letter never shows as locked.",
         "Your data, Look at what's stored, Notes to future you. Search for a word from the letter, such as gentle: it is not found. Tap the letter to read it.", 1, .yourData),
        ("30e", "Questions to ask", "An item can be a question with room for the answer after the session.",
         "Open Things to raise. Look at Ask about next steps and the answered one.", 3, .drafts),
        ("30f", "Personal goals", "Goals in your words with dated notes; reached or set aside.",
         "Open Personal goals and add a dated note.", 3, .goals),
        ("30g", "Journal to Things to raise", "Copy a journal entry's first line into Things to raise.",
         "Press and hold a journal entry and choose the copy action.", 2, nil),
        ("30h", "Journal since last session", "Session prep counts entries and check-ins since then.",
         "Open Session prep and the Journal since your last session card.", 3, .prep),
        ("30i", "Journal page as blocks", "Date at top, paragraphs, blocks for photos, events, songs; bookmarks.",
         "Open an entry. Bookmark it, then show Bookmarked only.", 2, nil),
        ("30j", "Providers", "Several providers, each with sessions, notes and an export name.",
         "Open Appointments and switch between Dr Lee and Dr Patel.", 1, .appointments),
        ("30k", "Things to raise per provider", "An item is for anyone or one provider; a filter on the list.",
         "Open Things to raise and use the filter.", 3, .drafts),
        ("30l", "Person pages", "A page per contact with your sections, recent messages and shared days.",
         "Open People and then Sam.", 4, .people),
        ("30m", "Session prep, rest", "Waiting to be raised card and a To bring checklist.",
         "Open Session prep and add something to To bring.", 3, .prep),
        ("SL1", "Sleep journal", "A quiet entry per night: times, time asleep, how it felt, a note.",
         "Open Sleep (turn it on under Customise first) and open a night.", 1, .sleep),
        ("SL2a", "Last night card", "An optional card on Now in the morning, with a Settings switch.",
         "Check Now for the Last night card. Try Not now.", 0, nil),
        ("SL2b", "Sleep in the Journal", "A small row per night and a moon mark on the month view.",
         "Open the Journal and its Month view.", 2, nil),
        ("SL2c", "Sleep in the check-in", "An optional How did you sleep? question.",
         "Start a check-in and look for the sleep question.", 0, nil),
        ("SL2d", "Sleep morning reminder", "An optional reminder at a time you pick.",
         "Settings, Sleep. (Reminders are not scheduled in demo mode.)", 1, .settings),
        ("SL3-4", "Apple Health sleep", "Read nights in, and optionally save typed nights. (RV9 made both of them plain switches.)",
         "Sleep screen, Apple Health card. Hidden in showcase mode; best tested on a real device.", 1, .sleep),
        ("SL5", "Sleep on session prep", "A Sleep since your last session card.",
         "Open Session prep and find the sleep card.", 3, .prep),
        ("32", "About Anchor", "Version, support email, links, licences and What's new.",
         "Open About and check What's new.", 1, .about),
        ("33-35a", "Backup, keys, sealed widgets", "Encrypted backup, data key, recovery key, sealed widget data.",
         "Your data: look at the encrypted backup option. Export and Import are off in demo mode.", 1, .yourData),
        ("31", "Data viewer", "Look at what's stored, lock each time, read-only, blur switch.",
         "Your data, Look at what's stored.", 1, .yourData),
        ("36-38a", "Export for someone", "A picker, preview, PDF, web page with charts, and Word download.",
         "Bridge, share button at the top. Choose what goes in and look at the preview.", 3, nil),
        ("39-40b", "Showcase mode", "Made-up content, passcode, exit flow, switch in Settings.",
         "Settings, Your data and help, Showcase mode. Look, but do not turn it on while reviewing.", 1, .settings),
        ("41-43b", "Guide and ? buttons", "A ? on most screens explains that screen; the tour is rebuilt.",
         "Tap the ? on three different screens and read what it says.", 1, .settings),
        ("44a", "Audit 1: calendar days and labels", "Tomorrow all day, month button labels, neutral Recovery words.",
         "Look at the next appointment card. Open the Recovery calendar.", 1, .recovery),
        ("44b", "Longest run hidden", "The longest run and Personal best bar show only after you switch it on.",
         "Open a counter, then Settings, Recovery, Show my longest run and look again.", 1, .recovery),
        ("45a", "Session reminders", "Optional, off by default, with plain lock-screen wording.",
         "Settings, Session reminders. (Not scheduled in demo mode.)", 1, .settings),
        ("45d", "Trigger window reminders", "The lock screen says only Anchor and a plain line; your label and safety plan line show when you open one. Answering one day's escalation leaves the next weeks.",
         "Not scheduled in demo mode. On your own copy: make a window a few minutes ahead with a contact on Escalate, open its reminder, then check Settings, Notifications for the later days.", 1, .triggerWindows),
        ("45e", "Session reminders, the rest", "A choice of evening time, and a tap on a reminder opens Session prep.",
         "Settings, Session reminders: switch on The evening before and change Evening time. (Not scheduled in demo mode.)", 1, .settings),
        ("45b", "Suggestions ask when tapped", "Calendar, photos and music are asked for only when each button is tapped.",
         "Journal, new entry, Add, Journaling Suggestions.", 2, nil),
        ("45c", "No scoring of check-ins", "A check-in row only says Check-in, with no rating or colour (RV5 added the sliders as plain bars).",
         "Look at the check-in row in the Journal timeline.", 2, nil),
        ("46a", "Docs and privacy page", "The privacy page covers Recovery, widget, reminders and Live Activity.",
         "Settings, privacy page, read the Recovery and reminders sections.", 1, .settings),
        ("RV1", "Lighter task rows, add several at once", "A task card is a title and one quiet line; steps start folded; the editor keeps the common things up front; a button next to Add takes a pasted list.",
         "Open Tasks. Tap the list button by Add and paste: Pack bag, then an indented line Charger, then a deeper line Cable. Open one task and look at More options.", 1, .tasks),
        ("RV2", "Steps inside steps", "Steps nest to any depth, and each step opens its own details and steps.",
         "Open Get ready for the weekend away, open its arrow, then open the step Pack and its arrow. Press and hold a step for Open details.", 1, .tasks),
        ("RV4", "Goals: an optional SMART frame", "A switch inside a goal, off by default, adds Specific, Measurable, Achievable and Time-bound boxes; Relevant is the existing why box. Nothing is required or dated.",
         "Open Personal goals. The walking goal has it on; open the pottery goal, turn the switch on and off, and leave boxes blank.", 3, .goals),
        ("RV5", "Check-ins on the Journal rows", "Each check-in row shows its own five sliders as small bars, one colour, no numbers, nothing added up. The detail sheet now names each slider as the check-in did, with both ends.",
         "Open the Journal. Compare the three check-ins (five, three and one day ago): the bars differ, nothing else does. Tap one and check the names match Now. Try large text.", 2, nil),
        ("RV3", "Appointments, calmer", "Two cards instead of four: Coming up, each with how far away it is, then the calendar. Earlier sessions fold away, Remove all is in the three dots menu, the usual gap moved into the schedule sheet and the person's details, and a new session starts at the time of the last one.",
         "Open Appointments. Look at Coming up, then Show all, then open Earlier sessions. Tap the plus: the time should be that of the last session. Turn Repeat on and change the gap. Open the person button, Details, and find Usual gap. Check the three dots menu.", 1, .appointments),
        ("RV9", "Apple Health sleep, tidier", "Both halves are the same: a switch with one short line under it, and the buttons that belong to it only when it is on. The long paragraphs moved into the Sleep guide, and the Connect button became a switch.",
         "Open Sleep and scroll to Apple Health. Switch Bring in nights from Apple Health on and off, and Save nights I type on and off. In a review run Health is never touched, so the switches go back to off; check them on a normal build.", 1, .sleep),
        ("RV8", "The ? guides, less crowded", "Each guide shows its ideas one to a line, four at first with Show more for the rest, and the extras wait behind Show more on longer ones. The five tab guides are short overviews. The tour now meets all five tabs first, then each tab's screens. Export for someone has its own ? .",
         "Open the ? on Now, Plan and Bridge, then on Appointments and Sleep and tap Show more. Take the tour from Settings and check the first five pages are the tabs. Open Export for someone from the share button on Bridge and tap its ?.", 2, nil),
        ("RV7", "Showcase content", "Every kind of content the app keeps now has made-up content in the demo, so showcase mode no longer shows empty screens. A script checks that a new kind cannot be left out.",
         "Open Trigger windows (three, one off), then Decision presets (each category has options, one with steps), Recovery (Energy drinks: Streaks, Calendar, Urges, Motivations), Unsent drafts, Appointments, Earlier sessions with notes, the message log for Alex and Jordan, and the Journal Month and Year views.", 1, .triggerWindows),
        ("RV5a", "Export check-in names fixed", "In Export for someone and in the older CSV and PDF, a check-in's values are named from the right sliders: Energy, Clarity, Room in head, Moving and Social energy. Before, Moving was called Energy and the real Physical energy slider was missing. The data viewer names the five sliders as the check-in asks them.",
         "Open the Bridge share button, Export for someone, pick Check-ins and look at the preview and the web page: five values each, five small charts. Open Your data, Look at what's stored, Check-ins, and compare a check-in with the bars in the Journal.", 2, nil),
        ("SL6", "Sleep in the CSV and the PDFs", "The CSV from Your data has its own sleep columns (bed_time, wake_time, minutes_asleep, feel) at the end, and the PDFs from Your data and from Export for someone draw the same plain time-asleep line as the web page, with no target line. The web page's Download CSV has in_bed, up and minutes_asleep columns.",
         "Open Your data, Export Journal, Check-ins and Sleep (PDF) and look for the Sleep heading with a line above the nights. Then Export for someone with Sleep switched on, make the PDF and the web page, and press Download CSV in the page. Export and Share are off in showcase and demo mode, so try this on your own copy.", 1, .yourData),
        ("AB2", "What's new by version", "What's new is a fold for each version with what it added, changed and removed. The newest is open, the others closed, and a group with nothing in it is not shown.",
         "Open About, then What's new. There is one version so far, 1.0, open, with its eight additions. Fold and open it again and try large text.", 1, .about)
    ])
}

// MARK: - State and notes

final class ReviewState: ObservableObject {
    static let shared = ReviewState()
    private static let notesKey = "anchor.review.notes"
    private static let indexKey = "anchor.review.index"

    @Published var index: Int {
        didSet { UserDefaults.standard.set(index, forKey: Self.indexKey) }
    }
    @Published var notes: [String: String] {
        didSet { UserDefaults.standard.set(notes, forKey: Self.notesKey) }
    }
    @Published var listOpen = false

    private init() {
        index = UserDefaults.standard.integer(forKey: Self.indexKey)
        notes = (UserDefaults.standard.dictionary(forKey: Self.notesKey) as? [String: String]) ?? [:]
        if index < 0 || index >= ReviewStops.all.count { index = 0 }
    }

    var stop: ReviewStop { ReviewStops.all[index] }

    func go(_ newIndex: Int) {
        index = max(0, min(ReviewStops.all.count - 1, newIndex))
    }

    func note(for stop: ReviewStop) -> String { notes["\(stop.number)"] ?? "" }

    func setNote(_ text: String, for stop: ReviewStop) {
        notes["\(stop.number)"] = text
    }

    /// Every stop as a numbered line, with your note under it, ready to paste into your own notes.
    var exportText: String {
        ReviewStops.all.map { stop in
            let note = self.note(for: stop).trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(stop.number). Patch \(stop.patch): \(stop.title)\n   Notes: \(note.isEmpty ? "-" : note)"
        }.joined(separator: "\n")
    }
}

// MARK: - The bar and the card

struct ReviewBar: View {
    @ObservedObject var state = ReviewState.shared
    var onOpen: () -> Void

    @State private var expanded = false
    @State private var draft = ""

    var body: some View {
        let stop = state.stop
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button { state.go(state.index - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(state.index == 0)
                Button { expanded.toggle() } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stop.number) of \(ReviewStops.all.count)  Patch \(stop.patch)")
                            .font(.caption.weight(.semibold))
                        Text(stop.title).font(.subheadline.weight(.medium)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button { state.listOpen = true } label: { Image(systemName: "list.number") }
                Button { state.go(state.index + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(state.index == ReviewStops.all.count - 1)
            }
            if expanded {
                Text(stop.change).font(.footnote)
                Text("Try: \(stop.tryIt)").font(.footnote).foregroundStyle(.secondary)
                TextField("Notes for this change", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onChange(of: draft) { _, value in state.setNote(value, for: stop) }
                if stop.screen != nil {
                    Button("Open the screen", action: onOpen).buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .onAppear { draft = state.note(for: stop) }
        .onChange(of: state.index) { _, _ in draft = state.note(for: state.stop) }
    }

}

struct ReviewListSheet: View {
    @ObservedObject var state = ReviewState.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(ReviewStops.all) { stop in
                Button {
                    state.go(stop.number - 1)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(stop.number). Patch \(stop.patch): \(stop.title)")
                            .foregroundStyle(.primary)
                        if !state.note(for: stop).isEmpty {
                            Text(state.note(for: stop)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("Review list")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: state.exportText) { Label("Share notes", systemImage: "square.and.arrow.up") }
                }
            }
        }
    }
}

private struct ReviewModifier: ViewModifier {
    @Binding var selectedTab: Int
    @ObservedObject private var state = ReviewState.shared
    @State private var opened: ReviewScreen?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if ReviewMode.isOn && opened == nil {
                    ReviewBar(onOpen: { opened = state.stop.screen })
                        .padding(.bottom, 52)
                }
            }
            .onChange(of: state.index) { _, _ in
                selectedTab = state.stop.tab
                opened = state.stop.screen
            }
            .onAppear { if ReviewMode.isOn { selectedTab = state.stop.tab } }
            .sheet(item: $opened) { screen in
                NavigationStack { screen.view }
                    .safeAreaInset(edge: .bottom) {
                        ReviewBar(onOpen: {})
                    }
            }
            .sheet(isPresented: $state.listOpen) { ReviewListSheet() }
    }
}

extension View {
    /// Adds the review bar in a test build launched with -AnchorReview. Does nothing otherwise.
    func reviewWalkthrough(selectedTab: Binding<Int>) -> some View {
        modifier(ReviewModifier(selectedTab: selectedTab))
    }
}

// MARK: - Extra made-up content for the review

enum ReviewSeed {
    /// Content the shared demo store leaves out, added only in a review run: two short-lived counters for the
    /// Recovery changes (the shared demo has its own, Energy drinks, which sorts after these) and a nested task.
    static func apply(to container: ModelContainer) {
        let context = ModelContext(container)
        // The shared demo has a sleep entry for today, which hides the Last night card and the sleep
        // question in a check-in. Take it out here so both can be seen.
        let today = Calendar.current.startOfDay(for: .now)
        if let nights = try? context.fetch(FetchDescriptor<SleepEntry>()) {
            for night in nights where Calendar.current.startOfDay(for: night.nightDate) == today {
                context.delete(night)
            }
        }
        let start = Date.now.addingTimeInterval(-40 * 86_400)
        let trip = TaskItem(title: "Get ready for the weekend away", sortOrder: 90)
        let pack = TaskItem(title: "Pack", sortOrder: 1, parentID: trip.id)
        let clothes = TaskItem(title: "Clothes", sortOrder: 1, parentID: pack.id)
        context.insert(trip)
        context.insert(pack)
        context.insert(clothes)
        context.insert(TaskItem(title: "Socks", sortOrder: 1, parentID: clothes.id))
        context.insert(TaskItem(title: "Charger and cable", sortOrder: 2, parentID: pack.id))
        context.insert(TaskItem(title: "Book the train", sortOrder: 2, parentID: trip.id))
        context.insert(RecoveryCounter(name: "Example counter", startDate: start))
        context.insert(RecoveryCounter(name: "Started today", startDate: Date.now.addingTimeInterval(-20 * 60), sortOrder: 1))
        try? context.save()
    }
}

#else

enum ReviewMode { static var isOn: Bool { false } }

extension View {
    func reviewWalkthrough(selectedTab: Binding<Int>) -> some View { self }
}

#endif
