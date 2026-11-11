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
        ("30p2", "After-session reminders", "After a session you have scheduled, a reminder to ask whether you want to tell a person you chose how it went: off until switched on, that evening or the next morning. The lock screen says only something for this evening or morning, naming no one. It takes the place of a hello that day, and a support day, a follow-up or a hard-time reminder keeps its day over it. Tapping it opens a message to that person.",
         "Settings, After-session reminders: Sam is on in demo. Switch Alex on and change When it comes. Appointments shows the sessions it follows. (Not scheduled in demo mode.)", 1, .settings),
        ("RV1a", "Task cards: short facts with icons", "A task card's quiet line is now a few small facts, each with an icon and a few words: the day, how long, started, the energy it needs, steps done and focus sessions. They move to a second row instead of being cut off, and the first step wraps to two lines.",
         "Open Tasks, and try the largest text size too. Look at a task with a day, an estimate and steps: nothing should end in dots. VoiceOver reads each fact in full.", 1, .tasks),
        ("35d", "Lock voice notes and photos", "Once your text is locked, Lock my data has a second step that locks the voice notes and Journal photos one file at a time. Each file is checked before it replaces the original, so a run that stops leaves files that all still open. Test builds only.",
         "A review run cannot lock files, because it has no real files and the text is not locked in it, so look at the screen only: Settings, Lock my data. On your own copy of your data, after the text is locked, tap Lock voice notes and photos, restart, and check that the count on that screen matches what you have. Then open a Journal photo, play a voice note and share one: all three should work as before. Make an encrypted backup afterwards and check it still holds them.", 1, .settings),
        ("AI1", "AI tools: asked first, every time", "AI tools has a consent sheet and a place it runs. Before anything is sent you see the exact text, the instruction that goes with it, where it goes and what happens to it, and you choose Send or Cancel. Don't ask again is a switch on the sheet, and the ones you turn on are listed under Asking. Test builds only, and no real tool uses it yet, so a Try it box runs Make shorter on text you type.",
         "A review run keeps AI tools off, so this cannot be tried here. On a normal test build on your phone (Run from Xcode), open Settings, AI tools and switch Use AI tools on. Where it runs should say Ready, or say what to turn on. In Try it, tap Make shorter: the sheet shows the whole text, and Send and Cancel stay at the bottom, also at large text. Cancel sends nothing; Send gives a shorter text. Switch on Don't ask again, send, then tap Make shorter again: no sheet. Find it under Asking and tap Ask again.", 1, .settings),
        ("AI2", "AI Optimised block in the Journal", "Make shorter, in the three dots at the top left of a Journal page, for one paragraph or the whole entry. After the consent sheet it gives a shorter version that waits for Keep or Discard. A kept one is a folded block called AI Optimised, with your original one tap away. The AI tools row in Settings now shows in every build. Exports leave the shorter versions out unless you tick them.",
         "In the review run AI tools are off, so open Journal and look at the entry from two days ago: the folded AI Optimised block, open it, Show original, and its menu (Use the original text). Export for someone, Journal entries has Include AI Optimised versions. On a normal test build, switch Use AI tools on, open an entry, three dots, Make shorter, This paragraph: read the sheet, Send, read the answer, Keep. Then Discard on a second try and check nothing was added. Turn AI tools off and check the menu item is gone and the kept block stays.", 2, nil),
        ("AI3", "Task helper: Break into steps, Estimate time", "On a task, under its steps, two plain buttons that show only while AI tools are on. Break into steps suggests a list you tick and only the ticked ones become steps. Estimate time suggests minutes you can use or discard. A task can also remember which Journal entry it came from, shown as a quiet line. The How long choices show a guess that is not one of the usual five.",
         "In a review run AI tools are off, so open Tasks, open Bring my notes to the next appointment, and look for the quiet line From your Journal. Then on a normal test build, switch Use AI tools on, open a task with a clear title, tap Break into steps, read the sheet, Send, tick two lines, Add 2 steps: only those two appear. Try Estimate time and Use this, then look at How long under More options. Turn AI tools off and check both buttons go.", 1, .tasks),
        ("AI4", "Tidy a braindump: Turn into tasks, Turn into things to raise", "Words from a Journal page, a pasted list or a brain dump go to a sheet with two plain buttons, Turn into tasks and Turn into things to raise, so you choose where they go. You see exactly what is sent, then a list to tick, and only the ticked lines are added. A task or thing to raise made from a Journal entry shows a quiet line saying which entry. The button shows only while AI tools are on.",
         "In a review run AI tools are off, so open Bridge, Things to raise, open Ask whether the evening routine can change, and look for the quiet line From your Journal. On a normal test build, switch Use AI tools on. In a Journal entry open the three dots, Tidy a braindump, Whole entry, then Turn into tasks: read the sheet, Send, tick two lines, Add 2 tasks, and check the entry did not change. In Tasks, the list button by Add, paste a messy paragraph, Tidy a braindump. In Things to raise, the clipboard button at the top, paste, Turn into things to raise. Turn AI tools off and check every one of those buttons goes.", 1, .tasks),
        ("VN1", "Dictate in the Journal",
         "A switch in Settings, Journal, off to begin with. When it is on, a microphone button joins the row of tools on a Journal page. It turns what you say into text on this phone, after the words already in the paragraph, and the sound is not kept. If the phone cannot do your language on its own, it says so and does not start. Typing while it listens stops it.",
         "A review run keeps Dictate off, so look at the switch only: Settings, Journal, Dictate in the Journal. On a normal test build on your phone, switch it on, open a Journal page and tap the microphone: the phone asks for speech recognition and then the microphone. Say a sentence and watch it appear in the paragraph; tap the microphone again to stop. Try it with words already in the paragraph, then type a letter while it listens: it should stop and leave your typing alone. Lock the phone while it listens: it should stop. Turn the switch off and check the microphone button goes.", 2, .settings),
        ("VN2", "Keep a voice note while dictating",
         "A second switch in Settings, Journal, off to begin with and shown only while Dictate is on. With it on, Dictate also saves what you say as a voice note on the page, right after the paragraph, and a small card under it lets you choose Keep both, Text only or Voice note only. Nothing is applied until you tap, so leaving it keeps both.",
         "A review run keeps Dictate off, so look at the switch only: Settings, Journal, switch Dictate on, and Keep a voice note while dictating appears under it. On a normal test build on your phone, switch both on, open a Journal page with a few words in a paragraph, tap the microphone and say a sentence, then tap it again. Check a Voice note block appears under the paragraph and plays, then try each of the three buttons on separate goes: Text only should remove the block, Voice note only should take your spoken words out and leave what was there before, and leaving the card alone should keep both. Remove a voice note block from its three dots and delete an entry that has one, then check neither leaves a sound behind in Look at what's stored. With the second switch off, check Dictate keeps no sound.", 2, .settings),
        ("VN3", "Label who is speaking",
         "A third switch in Settings, Journal, off to begin with and shown only while Dictate is on. While Dictate listens, two buttons, Speaker 1 and Speaker 2, let you say when the speaker changes: the words that follow go on a new line that starts with that label. Rename speakers, in a page's three dots, changes the names on that page only. Anchor does not tell voices apart.",
         "A review run keeps Dictate off, so look at the switch only: Settings, Journal, switch Dictate on, and Label who is speaking appears under it. On a normal test build on your phone, switch it on, open a Journal page, tap the microphone and say a sentence, tap Speaker 1, say another, tap Speaker 2, say a third, then tap the microphone to stop. Check each sentence is on its own line and the first has no label. Tap Speaker 2 and stop at once: no empty label should be left. Open the three dots, Rename speakers, type Mum and Dr Lee, and check only the line starts change. Check Rename speakers is missing from a page with no labels.", 2, .settings),
        ("AI5", "AI tools on your own computer", "A third place to run a tool: your own computer through Ollama, at an address on your own network and a model name you type. Nothing is sent until you confirm the consent sheet.",
         "A review run keeps AI tools off, so look at the screen only: Settings, AI tools. On a normal test build with Ollama running, switch Use AI tools on, choose On my computer, type the address and a model name, and tap Look for models.", 1, .settings),
        ("AI6", "AI tools: Other service", "Where it runs has a third choice, Other, for a service you already use: an https address, a key (shown as dots, with Remove key) and a model name. A plain http address, a name with no dot and an address with a question mark are refused with a line. The consent sheet shows the address and model, says Anchor cannot see how the service keeps the text, and has no Don't ask again.",
         "On a normal test build, switch AI tools on, choose Other and try each refused address, then a good one. Use a tool: read the sheet. A wrong key should say the provider did not accept it.", 1, .settings),
        ("AI7", "AI buttons grey when AI is off", "With AI tools off, the buttons that are the feature show greyed instead of vanishing, and tapping one says AI tools are off and where to turn them on. Make shorter is hidden.",
         "This works in a review run, where AI tools are off. In a Journal entry open the three dots: Tidy a braindump greyed, no Make shorter. Then Bridge, Things to raise, Tasks (Add several, after typing words) and a named task's steps. A menu item may not look grey. Then switch AI tools on in a normal build and check the real buttons are back.", 2, nil),
        ("AI8", "Ollama away from home", "A Tailscale number (100.x) is accepted after a prompt and a confirmation. Until you confirm, nothing connects and Look for models stays greyed. A plain http address with a name is refused and asks for https. A home address works as before.",
         "On a normal test build, Settings, AI tools, On my computer: type a 100.x address and check it says the address is away and shows Use this address. Confirm, Look for models, then use a tool: the sheet says the computer is away and that it can use mobile data. Change one digit and it should ask again. Try http://my-mac.example.com.", 1, .settings),
        ("AI9", "AI Optimised versions in exports", "When Include AI Optimised versions is ticked in an export, your own words sit under Original: the writer's own words and the shorter version under its AI Optimised label, with your words not appearing twice. Unticked, the export is as before.",
         "On a normal test build, make a shorter version in a Journal page and keep it. Then Bridge, Export for someone, Journal entries with the box ticked and unticked, and CSV or PDF from Settings, Your data. Export is off in a review run.", 3, nil),
        ("35e", "Encryption, Safety copy, Lock my data for everyone", "Settings shows Encryption, Safety copy and Lock my data in every build, and the Encryption guide page (the question mark) opens.",
         "Open Settings and look for the three rows. Open each and check the names. Tap the question mark on Encryption.", 1, .settings),
        ("35g, SY0, SY1a", "Locked numbers and dates, unique ids gone", "Dates, numbers, marks and typed settings are locked too, the places that sorted on them sort after opening, the database no longer asks for a unique id, and a backup imported twice adds nothing the second time. Every stored property has a default for sync later.",
         "A review run cannot lock anything, so do this on your own copy: Settings, Safety copy first, then Lock my data (More to lock, Lock the rest), close and open the app, and read Last time. Then check-ins in the Journal, Sleep, a Recovery counter, Tasks, Appointments, Trigger windows, the quick lists and Thread. Everything should look as before. Make a new check-in, task and night, and import the same backup twice.", 1, .settings),
        ("R5", "Sleep question no longer crashes a check-in", "Answering the How did you sleep? question and finishing now saves the check-in and puts the answer on last night. Before, the app closed and nothing was saved.",
         "Start a check-in on Now, tap A few optional questions, go to the last one (How did you sleep?), type a few words and tap Finish. The app should stay open. Open the Journal: the check-in is there. Open Plan, Sleep: last night has your words.", 0, nil),
        ("R5", "Answers stay on the check-in", "The answers to the optional questions are kept on the check-in, not in a new Journal entry. Open a check-in in the Journal to read them.",
         "In the Journal, open the check-in from one day ago: Your answers shows two. Make a new check-in with answers: no new Journal entry appears, and the check-in row shows a small speech icon.", 2, nil),
        ("R5", "Delete a check-in", "A check-in can be deleted the same way as an entry: press and hold its row. The check-in's sheet also has Delete this check-in, which asks first.",
         "Journal: press and hold a check-in row, Delete. Open another check-in, scroll down, Delete this check-in, Delete. The sheet closes and the row is gone.", 2, nil),
        ("R5", "Link a check-in and a Journal entry", "From a check-in, link, change, open or unlink a Journal entry. From an entry's three dots menu, Link a check-in or Unlink the check-in. A linked check-in row shows a small link icon.",
         "Open a check-in, Link a Journal entry, pick one: the row now shows a link and the sheet shows the entry with Open, Change, Unlink. Then open that entry, three dots: it says which check-in it is linked to. Try Link another check-in and Unlink.", 2, nil),
        ("R5", "Last night sheet stays open", "On the Last night card, choosing a start time no longer makes the sheet close.",
         "On Now, tap Log it on Last night, tap the start time and pick a time. The sheet should stay open. Fill in more, then close it.", 0, nil),
        ("R5", "Sleep in Journaling Suggestions", "The Journaling Suggestions screen starts with Sleep: the night for that entry's day to tap and add, Write down how you slept when there is none, and earlier nights below.",
         "Open any entry, tap the sparkles button at the bottom. Sleep is first. Today has no night in a review run: tap Write down how you slept, set a time, close it, and the card lands on the page. Then reopen Journaling Suggestions and tap an earlier night.", 2, nil),
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
