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
        ("30o", "Letters stay closed in the viewer", "Look at what's stored lists a letter by its Open when words, not by what it says, and a search does not look inside it. A letter never shows as locked.",
         "Your data, Look at what's stored, To future me. Search for a word from the letter, such as gentle: it is not found. Tap the letter to read it.", 1, .yourData),
        ("45d", "Trigger window reminders", "The lock screen says only Anchor and a plain line; your label and safety plan line show when you open one. Answering one day's escalation leaves the next weeks.",
         "Not scheduled in demo mode. On your own copy: make a window a few minutes ahead with a contact on Escalate, open its reminder, then check Settings, Notifications for the later days.", 1, .triggerWindows),
        ("45e", "Session reminders, the rest", "A choice of evening time, and a tap on a reminder opens Session prep.",
         "Settings, Session reminders: switch on The evening before and change Evening time. (Not scheduled in demo mode.)", 1, .settings),
        ("30n1", "Hello reminders", "A regular hello to one person: off until switched on, on the days and time you pick, a plain line on the lock screen, at most one a day. Tapping it opens a message to them.",
         "Settings, Hello reminders: switch on Sam (already on in demo) and change the days. (Not scheduled in demo mode.)", 1, .settings),
        ("30n2", "Support day reminders", "For a person who can see a day on your Support calendar: a reminder at 9 am the morning of it or the day before, off until switched on. The lock screen says only that there is something to remember. It takes the place of a hello that day, and at most one comes on any day.",
         "Settings, Support day reminders: Sam is on, the day before. Switch Alex on too and change When it comes. Support calendar shows the days Sam can see. (Not scheduled in demo mode.)", 1, .settings),
        ("30n3", "Follow-up reminders", "When you write to someone you can ask for a reminder 1 to 7 days later, at 10 am. Off unless you choose one, and set only when you save and send. The lock screen says only that it is a follow-up you set earlier. It takes the place of a hello that day, and a support day or an earlier follow-up keeps the day.",
         "Thread, Message log, Write something: pick Jordan, choose Follow up, then Save and send. Open that message to see or remove it. Settings, Follow-up reminders removes them all. (Not scheduled in demo mode.)", 1, .messages),
        ("30p1", "Hard-time reminders", "At the start of a trigger window you pick, a reminder that a person you chose is one option: off until switched on. The lock screen says only a gentle nudge for this morning, afternoon or evening, naming no one. It takes the place of a hello that day, a support day or a follow-up keeps its day, and at most one comes on any day. Tapping it opens a message to that person.",
         "Settings, Hard-time reminders: Alex is on for Sunday evenings in demo. Switch Sam on and pick a window. (Not scheduled in demo mode.)", 1, .settings),
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
         "Open Trigger windows (three, one off), then Decision presets (each category has options, one with steps), Recovery (Energy drinks: Streaks, Calendar, Urges, Motivations), Things I haven't said, Appointments, Earlier sessions with notes, the message log for Alex and Jordan, and the Journal Month and Year views.", 1, .triggerWindows),
        ("RV5a", "Export check-in names fixed", "In Export for someone and in the older CSV and PDF, a check-in's values are named from the right sliders: Energy, Clarity, Room in head, Moving and Social energy. Before, Moving was called Energy and the real Physical energy slider was missing. The data viewer names the five sliders as the check-in asks them.",
         "Open the Bridge share button, Export for someone, pick Check-ins and look at the preview and the web page: five values each, five small charts. Open Your data, Look at what's stored, Check-ins, and compare a check-in with the bars in the Journal.", 2, nil),
        ("SL6", "Sleep in the CSV and the PDFs", "The CSV from Your data has its own sleep columns (bed_time, wake_time, minutes_asleep, feel) at the end, and the PDFs from Your data and from Export for someone draw the same plain time-asleep line as the web page, with no target line. The web page's Download CSV has in_bed, up and minutes_asleep columns.",
         "Open Your data, Export Journal, Check-ins and Sleep (PDF) and look for the Sleep heading with a line above the nights. Then Export for someone with Sleep switched on, make the PDF and the web page, and press Download CSV in the page. Export and Share are off in showcase and demo mode, so try this on your own copy.", 1, .yourData),
        ("AB2", "What's new by version", "What's new is a fold for each version with what it added, changed and removed. The newest is open, the others closed, and a group with nothing in it is not shown.",
         "Open About, then What's new. There is one version so far, 1.0, open, with its eight additions. Fold and open it again and try large text.", 1, .about),
        ("30q", "Session actions offered as tasks", "In Post-session notes, a line that starts with [ ] is a thing to do and has an Add as task button under the note. Nothing is added until you tap, the task has no date, and the line stays in the note.",
         "Open Post-session notes for Dr Lee, open the session 14 days ago and look under the note: two things to do. Tap Add as task on one, then open Tasks and find it with no date. Back in the note it now says In Tasks. Add a thing to do puts a new [ ] line at the end.", 3, .afterSession),
        ("SH2a", "Showcase passcode on the number pad", "The showcase passcode is 4 to 6 digits typed on the number pad, twice. Typing anything else is ignored, and the exit screen asks for it on the number pad.",
         "Settings, Your data and help, Showcase mode, Set a passcode. Try letters (they do not appear), 3 digits (it says to use 4 to 6), two different entries, then a good one. Showcase mode cannot be turned on in a review run, so check the exit screen on your own copy.", 1, .settings),
        ("30o2", "Sealed notes stay sealed in the viewer", "Look at what's stored lists a note that is sealed until a date by that date, not by what it says, and a search does not find its words. They show once the date has passed.",
         "Your data, Look at what's stored, To future me. The note sealed for two weeks reads Sealed until and the date; search for got through and it is not found. The letter and the note whose day has passed still show their words.", 1, .yourData),
        ("30r", "One-page sheet", "Session prep and Export for someone can each make a one-page PDF of what they hold. The print gets smaller to fit and nothing is cut. If it still would not fit, it says so and makes nothing.",
         "Open Session prep for Dr Lee and tap Make a one-page sheet at the bottom: prep notes, waiting to be raised and to bring are on, Recovery, journal and check-in counts and sleep are off. Switch them on, open Preview, make the PDF and look at it in the share sheet. Then the Bridge share button, Export for someone, switch on Journal entries and Check-ins and look at Make a one-page PDF. If it says it is too long the button is off and nothing is cut; narrow the dates or leave things out until it switches on.", 3, .prep),
        ("R2", "Last night card and sleep question", "The Last night card on Now and the How did you sleep? question in a check-in now show in a review run at any hour. Before, they were hidden by design, which looked like a fault.",
         "Look at Now for the Last night card and try Not now. Then start a check-in and look for the sleep question near the end.", 0, nil),
        ("RV10", "Check-in mascot keeps one calm face", "The mascot no longer changes its face as the sliders move. One switch in the code (mascotFollowsSliders) brings the old behaviour back.",
         "Start a check-in on Now and move each slider all the way both ways. The mascot should keep the same calm face.", 0, nil),
        ("46b2", "Names match across the app", "Look at what's stored names each kind as its screen is named, and the presets screen is titled Decision presets.",
         "Your data, Look at what's stored: check the kinds read Contacts, Message log, To future me, Things I haven't said, Decision presets and Lists. Then open Decision presets from Plan and check its title.", 1, .yourData),
        ("35a2", "Widgets' key in the Keychain", "The key that seals the widget summaries moves into a Keychain item the app and the widgets share. Test builds only. A review run cannot show it.",
         "In Xcode, open Signing and Capabilities on the Anchor and AnchorWidget targets and check Keychain Sharing lists page.aspens.anchor.widgetkey. On a normal build, check a contacts widget still shows your contacts.", 1, nil),
        ("35b1-35b3, AI0", "Safety copy, Lock my data, AI tools", "Four test-only rows in Settings: Encryption, Safety copy, Lock my data and AI tools. A safety copy and Lock my data are asked for here and run at the next start. AI tools is one switch, off, with nothing behind it yet.",
         "Look at the four rows. In a review run the buttons that make a copy, lock your text or turn AI on are switched off on purpose, so do not try Lock my data here. The real try is on a copy of your own data: make a safety copy, check the recovery key, tick the backup box, Lock my data, restart, then look at Journal, Contacts and a Recovery counter.", 1, .settings),
        ("30p2", "After-session reminders", "After a session you have scheduled, a reminder to ask whether you want to tell a person you chose how it went: off until switched on, that evening or the next morning. The lock screen says only something for this evening or morning, naming no one. It takes the place of a hello that day, and a support day, a follow-up or a hard-time reminder keeps its day over it. Tapping it opens a message to that person.",
         "Settings, After-session reminders: Sam is on in demo. Switch Alex on and change When it comes. Appointments shows the sessions it follows. (Not scheduled in demo mode.)", 1, .settings),
        ("RV1a", "Task cards: short facts with icons", "A task card's quiet line is now a few small facts, each with an icon and a few words: the day, how long, started, the energy it needs, steps done and focus sessions. They move to a second row instead of being cut off, and the first step wraps to two lines.",
         "Open Tasks, and try the largest text size too. Look at a task with a day, an estimate and steps: nothing should end in dots. VoiceOver reads each fact in full.", 1, .tasks)
    ])
}

// MARK: - State and notes

final class ReviewState: ObservableObject {
    static let shared = ReviewState()
    private static let notesKey = "anchor.review.notes.v2"
    private static let indexKey = "anchor.review.index.v2"

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
