//
//  AnchorApp.swift
//  Anchor
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct AnchorApp: App {
    let container = DemoMode.isOn ? DemoMode.makeContainer() : AnchorSchema.makeContainer()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        if !DemoMode.isOn {
            TaskMigration.migrateNextHourItemsIfNeeded(container: container)
            SafetyPlanMigration.migrateIfNeeded(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppLockGateView {
                ContentView()
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !AnchorSchema.openedPersistentStore {
                    StoreWarningBanner()
                }
            }
        }
        .modelContainer(container)
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
/// launches never reach this code.
enum DemoMode {
    static var isOn: Bool { CommandLine.arguments.contains("-AnchorDemo") }

    static func makeContainer() -> ModelContainer {
        let schema = Schema(AnchorSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [configuration]) else {
            return AnchorSchema.makeContainer()
        }
        let context = ModelContext(container)
        let now = Date.now
        func ago(_ days: Double, hour: Double = 0) -> Date { now.addingTimeInterval(-days * 86_400 - hour * 3_600) }

        let demoSam = TrustedContact(name: "Sam", phoneNumber: "0400 000 001", sortOrder: 0)
        context.insert(demoSam)
        context.insert(TrustedContact(name: "Alex", phoneNumber: "0400 000 002", sortOrder: 1))
        context.insert(TrustedContact(name: "Jordan", phoneNumber: "0400 000 003", sortOrder: 2))

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

        try? context.save()
        return container
    }
}
