//
//  AnchorApp.swift
//  Anchor
//

import SwiftUI
import SwiftData
import UserNotifications
import WidgetKit

@main
struct AnchorApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        #if DEBUG
        WidgetSealSelfTest.run()
        #endif
        if !DemoMode.isOn {
            ContainerHolder.prepareRealStore(ContainerHolder.shared.container)
        } else if ShowcaseMode.isOn {
            // A launch that starts in showcase mode opens nothing from the real store, and leaves
            // nothing waiting or delivered that could show your own words.
            ShowcaseSweep.begin()
        }
    }

    var body: some Scene {
        WindowGroup {
            AnchorRootView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Brings in new nights from Apple Health and keeps what Anchor saved there in line, only if either was turned on.
            // Showcase and demo runs never reach Health (the readers check DemoMode.isOn).
            if phase == .active {
                Task {
                    let context = ContainerHolder.shared.container.mainContext
                    await SleepHealthReader.shared.sync(context: context)
                    await SleepHealthWriter.shared.reconcile(context: context)
                }
            }
        }
    }
}

/// The app's one window. It reads the container from `ContainerHolder`, and when that changes
/// (showcase mode turned on or off) the whole tree is made again, so no screen, sheet or
/// query is left holding something from the other store.
struct AnchorRootView: View {
    @ObservedObject private var holder = ContainerHolder.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        AppLockGateView {
            ContentView()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !AnchorSchema.openedPersistentStore {
                StoreWarningBanner()
            }
        }
        .modelContainer(holder.container)
        .id(holder.generation)
        .overlay {
            // The app switcher takes its picture while the app is not the one in front.
            if ShowcaseMode.isOn && scenePhase != .active {
                ShowcaseCover()
            }
        }
    }
}

/// Holds the container the app is using. On a normal launch it is the real store. While
/// showcase mode is on it is the in-memory demo store, and the real store file is not
/// opened at all on that launch. Turning showcase mode on or off swaps it while the app
/// is running and makes the window again.
final class ContainerHolder: ObservableObject {
    static let shared = ContainerHolder()

    @Published private(set) var container: ModelContainer
    @Published private(set) var generation = 0
    /// Kept when the real store was already open, so leaving showcase mode does not open it a second time.
    private var realContainer: ModelContainer?

    private init() {
        var demo: ModelContainer?
        if DemoMode.isOn {
            demo = DemoMode.makeContainer()
            if demo == nil {
                // Made-up content could not be made. A launch for the screenshot tests promises never to
                // touch the real store, so it stops. Showcase mode turns itself off instead, which leaves
                // the real store behind Anchor's own lock, as on any other launch, and never shows it
                // as if it were the showcase.
                if CommandLine.arguments.contains("-AnchorDemo") || !ShowcaseMode.isOn {
                    fatalError("Could not make the in-memory store for made-up content")
                }
                ShowcaseMode.setOn(false)
            }
        }
        if let demo {
            container = demo
        } else {
            let real = AnchorSchema.makeContainer()
            realContainer = real
            container = real
        }
    }

    /// What a normal launch does with the real store once it is open: locks a plain widget copy left
    /// by an earlier version and moves older data into the newer models. Each step keeps its own flag,
    /// so running it again is harmless. A launch that started in showcase mode skips it, so it also
    /// runs when showcase mode is turned off and the real store is opened for the first time.
    @MainActor
    static func prepareRealStore(_ container: ModelContainer) {
        WidgetSealing.sealLeftovers()
        TaskMigration.migrateNextHourItemsIfNeeded(container: container)
        SafetyPlanMigration.migrateIfNeeded(container: container)
    }

    /// Returns false, and changes nothing, when the made-up store cannot be made. The real store is never
    /// shown as a stand-in for it.
    @discardableResult
    func enterShowcase() -> Bool {
        guard let demo = DemoMode.makeContainer() else { return false }
        ShowcaseMode.setOn(true)
        ShowcaseSweep.begin()
        container = demo
        generation += 1
        return true
    }

    func leaveShowcase() {
        ShowcaseMode.setOn(false)
        let openedNow = (realContainer == nil)
        if openedNow {
            realContainer = AnchorSchema.makeContainer()
        }
        guard let real = realContainer else { return }
        container = real
        generation += 1
        Task { @MainActor in
            if openedNow { Self.prepareRealStore(real) }
            ShowcaseSweep.end(container: real)
        }
    }
}

struct StoreWarningBanner: View {
    var body: some View {
        Text("Anchor couldn't open your saved data, so anything you add now won't be kept. Close and reopen the app. If this keeps happening, contact support before adding anything.")
            .font(.system(.footnote, design: .rounded).weight(.medium))
            .foregroundStyle(.white)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.9))
    }
}

#Preview {
    AppLockGateView {
        ContentView()
    }
    .modelContainer(AnchorSchema.makeContainer())
}

/// Launch with `-AnchorDemo` (the screenshot tests do) to run on a throwaway
/// in-memory store filled with made-up content. Nothing is written to disk,
/// so a real store on the same device or simulator is never touched. Normal
/// launches never reach this code, unless showcase mode is on (see `ShowcaseMode`),
/// which uses the same store and the same content, so there is one set of made-up data.
enum DemoMode {
    static var isOn: Bool { CommandLine.arguments.contains("-AnchorDemo") || ShowcaseMode.isOn }

    /// Nil when an in-memory store cannot be made. It never stands in with the real store: a showcase
    /// that fell back to your own data would show it to the person the phone was handed to.
    static func makeContainer() -> ModelContainer? {
        let schema = Schema(AnchorSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            return nil
        }
        let context = ModelContext(container)
        let now = Date.now
        func ago(_ days: Double, hour: Double = 0) -> Date { now.addingTimeInterval(-days * 86_400 - hour * 3_600) }

        let demoSam = TrustedContact(name: "Sam", phoneNumber: "0400 000 001", sortOrder: 0)
        context.insert(demoSam)
        context.insert(TrustedContact(name: "Alex", phoneNumber: "0400 000 002", sortOrder: 1))
        context.insert(TrustedContact(name: "Jordan", phoneNumber: "0400 000 003", sortOrder: 2))
        context.insert(PersonSection(contactID: demoSam.id, title: "Notes",
                                     text: "Prefers a short text to a call.\nUsually free on Sunday evenings.",
                                     iconName: "doc.text.fill", tintName: "sage", sortOrder: 0))
        context.insert(PersonSection(contactID: demoSam.id, title: "Things I've told them",
                                     text: "That sleep has been rough lately.",
                                     iconName: "heart.fill", tintName: "accent", sortOrder: 1))

        for section in SafetyPlanSections.makeSections(
            warningSigns: "Skipping meals\nStaying up very late\nNot answering messages",
            copingStrategies: "Cold water on my wrists\nA short walk\nPut on a familiar playlist",
            reasons: "My sister's wedding next year\nMy dog needs me\nI want to finish my course",
            environment: "Keep my phone charged\nLet Sam know when I have a rough night"
        ) {
            context.insert(section)
        }

        context.insert(GroundingTool(title: "5-4-3-2-1", kind: .physicalAction,
            steps: "Name 5 things you can see.\nName 4 things you can touch.\nName 3 things you can hear.\nName 2 things you can smell.\nTake 1 slow breath.",
            sortOrder: 0))
        context.insert(GroundingTool(title: "Cold water", kind: .physicalAction,
            steps: "Go to a tap.\nRun cold water over your wrists.\nBreathe out slowly, twice.", sortOrder: 1))
        context.insert(GroundingTool(title: "Slow breathing", kind: .physicalAction,
            steps: "Breathe in for four.\nHold for four.\nBreathe out for six.", sortOrder: 2))

        let tuesday = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 10, minute: 30, weekday: 3),
                                                matchingPolicy: .nextTime) ?? now.addingTimeInterval(3 * 86_400)
        let lee = AppointmentSeries(clinicianLabel: "Dr Lee", typicalDayOfWeek: 3,
            typicalTime: DateComponents(hour: 10, minute: 30), typicalCadenceDays: 14,
            occurrences: [AppointmentOccurrence(scheduledDate: tuesday)],
            role: "Psychologist", sortOrder: 0)
        context.insert(lee)
        let patel = AppointmentSeries(clinicianLabel: "Dr Patel", typicalCadenceDays: 60,
            occurrences: [AppointmentOccurrence(scheduledDate: now.addingTimeInterval(12 * 86_400))],
            role: "GP", exportLabel: "My GP", notes: "Ask for the longer appointment.", sortOrder: 1)
        context.insert(patel)

        let water = TaskItem(title: "Drink some water", sortOrder: 0, energy: .little, estimateMinutes: 5)
        water.setDue(.today)
        context.insert(water)
        let reply = TaskItem(title: "Reply to one message", notes: "Just the easy one.", sortOrder: 1, energy: .some,
                             focusSessions: 2, focusMinutes: 50, estimateMinutes: 30)
        reply.setDue(.thisWeek)
        context.insert(reply)
        context.insert(TaskItem(title: "Pick the easy one", isDone: true, completedAt: ago(0, hour: 1), sortOrder: 0, parentID: reply.id))
        context.insert(TaskItem(title: "Write two lines", sortOrder: 1, parentID: reply.id))
        context.insert(TaskItem(title: "Send it", sortOrder: 2, parentID: reply.id))
        let call = TaskItem(title: "Call to book the appointment", sortOrder: 3, energy: .some,
                            firstStep: "Find the number and put it on the screen.", estimateMinutes: 15)
        context.insert(call)
        context.insert(TaskItem(title: "Bring the form along", sortOrder: 4, blockedByIDs: [call.id]))
        context.insert(TaskItem(title: "Step outside for five minutes", isDone: true, completedAt: ago(0, hour: 2), sortOrder: 2))
        context.insert(TaskItem(title: "Sort out the old paperwork", sortOrder: 5, status: .setAside, energy: .lots))

        context.insert(QuickList(title: "Before I leave the house", createdAt: ago(0, hour: 4), items: [
            QuickListItem(text: "Keys", isDone: true),
            QuickListItem(text: "Phone and charger", isDone: true),
            QuickListItem(text: "Water bottle"),
            QuickListItem(text: "Wallet")
        ]))
        context.insert(QuickList(title: "Shopping", createdAt: ago(2), items: [
            QuickListItem(text: "Bread", isDone: true),
            QuickListItem(text: "Milk", isDone: true),
            QuickListItem(text: "Bananas", isDone: true)
        ], archivedAt: ago(1)))

        context.insert(Routine(name: "School mornings", createdAt: ago(5), steps: [
            RoutineStep(text: "Drink a glass of water", minutes: 2),
            RoutineStep(text: "Get dressed", minutes: 10),
            RoutineStep(text: "Eat something, even something small", minutes: 15),
            RoutineStep(text: "Pack the bag and check for keys and phone", minutes: 5),
            RoutineStep(text: "Head out")
        ]))

        let boundaryHeadings = BoundarySection.startingSections()
        boundaryHeadings[0].text = "I go quiet when I am overwhelmed. It is not about you.\nI need a bit of notice before plans change."
        boundaryHeadings[0].isShareable = true
        boundaryHeadings[1].text = "A short text asking how I am\nSitting nearby without needing to talk"
        boundaryHeadings[1].isShareable = true
        boundaryHeadings[2].text = "Being asked to explain myself in the moment"
        for section in boundaryHeadings { context.insert(section) }

        context.insert(MessageStarter(text: "I'm not up to talking right now, but I'm safe.", sortOrder: 0))
        context.insert(MessageStarter(text: "Could you check in on me tomorrow?", sortOrder: 1))

        let days = ListVariable(name: "Day", value: 3)
        let weekend = ItemList(name: "Weekend away", createdAt: ago(4), variables: [days], items: [
            ListItem(name: "Phone charger", category: "Things", isDone: true),
            ListItem(name: "Keys", category: "Things"),
            ListItem(name: "T-shirts", category: "Clothes", rule: QuantityRule(variableID: days.id, per: 1)),
            ListItem(name: "Socks", category: "Clothes",
                     rule: QuantityRule(variableID: days.id, per: 1, extra: 1, extraEvery: 3)),
            ListItem(name: "Toothbrush", category: "Wash bag", isDone: true),
            ListItem(name: "Medication organiser", category: "Wash bag")
        ])
        context.insert(weekend)

        context.insert(Affirmation(text: "I got through today. That counts.", sortOrder: 0))
        context.insert(Affirmation(text: "Small steps still move me forward.", sortOrder: 1))

        context.insert(JournalEntry(createdAt: ago(0, hour: 3), text: "Slept badly, but the walk helped a bit."))
        context.insert(JournalEntry(createdAt: ago(1, hour: 2), text: "Quiet day. Made toast, answered one message, and that was enough."))
        context.insert(JournalEntry(createdAt: ago(3), text: "Felt tense before the call, but it went better than I expected."))
        context.insert(CheckIn(timestamp: ago(1, hour: 5), physicalExhaustion: 0.4, cognitiveBurnout: 0.5,
                               mentalLoad: 0.45, physicalEnergy: 0.5, socialEnergy: 0.35))

        context.insert(BridgeDraftItem(text: "Sleep has been off"))
        context.insert(BridgeDraftItem(text: "Medication question", providerID: patel.id))
        context.insert(BridgeDraftItem(text: "Ask about next steps", isQuestion: true, providerID: lee.id))
        context.insert(BridgeDraftItem(createdAt: ago(9), text: "Is it worth trying a different time of day?", isResolved: true,
                                       isQuestion: true, answer: "Worth a try for two weeks, then we look again."))

        let demoAsleep = [450, 410, 480, 390, 465, 435, 420]
        let demoFeel: [Int?] = [0, 1, 0, 2, 0, nil, 1]
        for index in 0..<7 {
            let cal = Calendar.current
            let night = cal.startOfDay(for: ago(Double(index)))
            let wake = night.addingTimeInterval(7 * 3_600 + Double(index % 3) * 900)
            let bed = wake.addingTimeInterval(-Double(demoAsleep[index] + 20) * 60)
            context.insert(SleepEntry(nightDate: night, bedTime: bed, wakeTime: wake,
                                      minutesAsleep: index == 3 ? demoAsleep[index] : nil,
                                      feel: demoFeel[index],
                                      note: index == 3 ? "Woke a few times. Mind was busy." : ""))
        }
        context.insert(PersonalGoal(title: "Get outside for a short walk most days",
                                    why: "It helps my head more than I expect.",
                                    notes: [GoalNote(date: ago(3), text: "Walked to the end of the street and back. That counted."),
                                            GoalNote(date: ago(1), text: "Skipped it today and that was fine.")],
                                    sortOrder: 0))
        context.insert(PersonalGoal(title: "Go back to the pottery class", status: .reached, sortOrder: 1))

        context.insert(FeedbackLoopDiagram(
            title: "Waking in the night",
            graphJSON: DiagramGraph.loop([
                ("I wake up and check the time", .same),
                ("I start thinking about tomorrow", .same),
                ("I feel tense and wide awake", .same)
            ]).encoded()))
        context.insert(FeedbackLoopDiagram(
            title: "Taking on too much",
            graphJSON: DiagramGraph.loop([
                ("I take on more", .same),
                ("I feel stretched thin", .same),
                ("I say no to something", .opposite)
            ]).encoded()))
        context.insert(FeedbackLoopDiagram(
            title: "How a hard day spreads",
            graphJSON: DiagramGraph.demoMap().encoded()))

        context.insert(FutureNote(unlockDate: now.addingTimeInterval(14 * 86_400), text: "You got through last time too."))
        context.insert(FutureNote(unlockDate: now, text: "Be gentle with yourself tonight. Some water, something small to eat, and one message to someone.", openWhen: "it is a hard night"))
        context.insert(ThreadMessage(timestamp: ago(2), text: "Thanks for checking in on me.", withContactID: demoSam.id))
        context.insert(SupportCalendarEntry(date: now.addingTimeInterval(5 * 86_400),
                                            note: "A hard day coming up. A check-in would help.",
                                            visibleToContactIDs: [demoSam.id]))

        try? context.save()
        return container
    }
}

// MARK: - Showcase mode: what is cleared outside the store

/// The store is swapped by `ContainerHolder`. This is the rest: what lives outside the store and
/// could still show someone else your own content. `begin` takes it off the phone when showcase
/// mode starts, and `end` puts it back from the real store when it stops.
///
/// What is taken: the widget summaries (your top contacts and the Recovery counters, which the lock
/// screen shows), and every reminder that is waiting or already delivered, because the trigger window
/// reminders quote a line from your own plan. While showcase mode is on nothing writes them again:
/// the widget writers and the reminder schedulers do nothing.
enum ShowcaseSweep {
    static func begin() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        WidgetDataStore.clear()
        CounterWidgetStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Runs after the flag is already off, so the writers and schedulers work again.
    @MainActor
    static func end(container: ModelContainer) {
        let context = container.mainContext

        // The widget summary, the same one Plan writes when it appears.
        let contacts = (try? context.fetch(FetchDescriptor<TrustedContact>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let sections = (try? context.fetch(FetchDescriptor<SafetyPlanSection>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let scripts = (try? context.fetch(FetchDescriptor<DeEscalationScript>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let affirmations = (try? context.fetch(FetchDescriptor<Affirmation>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        let windows = (try? context.fetch(FetchDescriptor<TriggerWindow>())) ?? []
        WidgetDataStore.refresh(
            contacts: contacts,
            hasSafetyPlan: SafetyPlanSections.hasContent(sections),
            deEscalationScriptLine: scripts.first?.text ?? "I need 10 minutes, then we can talk.",
            nextTriggerWindowLabel: TimeWindowHelper.nextWindowLabel(among: windows),
            currentAffirmation: affirmations.first?.text
        )

        // The reminders and the counter widget, the same ones Plan refreshes when it appears.
        RecoveryNotifications.refresh(using: context)
        RoutineReminders.refresh(using: context)
        SleepReminder.refresh()
        NotificationScheduler.resyncTriggerWindows(using: context)
        DailyCheckInSettings.reapplyIfEnabled(using: context)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Laid over the window while showcase mode is on and the app is not the one in front, so the app
/// switcher shows a plain screen. It covers the main window only, not a sheet that happens to be open.
struct ShowcaseCover: View {
    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
