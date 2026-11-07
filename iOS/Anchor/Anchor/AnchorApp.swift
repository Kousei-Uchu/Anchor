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

        context.insert(GroundingTool(title: "5-4-3-2-1", kind: .physicalAction,
            steps: "Name 5 things you can see.\nName 4 things you can touch.\nName 3 things you can hear.\nName 2 things you can smell.\nTake 1 slow breath.",
            sortOrder: 0))
        context.insert(GroundingTool(title: "Cold water", kind: .physicalAction,
            steps: "Go to a tap.\nRun cold water over your wrists.\nBreathe out slowly, twice.", sortOrder: 1))
        context.insert(GroundingTool(title: "Slow breathing", kind: .physicalAction,
            steps: "Breathe in for four.\nHold for four.\nBreathe out for six.", sortOrder: 2))

        let tuesday = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 10, minute: 30, weekday: 3),
                                                matchingPolicy: .nextTime) ?? now.addingTimeInterval(3 * 86_400)
        context.insert(AppointmentSeries(clinicianLabel: "Dr Lee", typicalDayOfWeek: 3,
            typicalTime: DateComponents(hour: 10, minute: 30), typicalCadenceDays: 14,
            occurrences: [AppointmentOccurrence(scheduledDate: tuesday)]))

        let water = TaskItem(title: "Drink some water", sortOrder: 0)
        water.setDue(.today)
        context.insert(water)
        let reply = TaskItem(title: "Reply to one message", notes: "Just the easy one.", sortOrder: 1)
        reply.setDue(.thisWeek)
        context.insert(reply)
        context.insert(TaskItem(title: "Pick the easy one", isDone: true, completedAt: ago(0, hour: 1), sortOrder: 0, parentID: reply.id))
        context.insert(TaskItem(title: "Write two lines", sortOrder: 1, parentID: reply.id))
        context.insert(TaskItem(title: "Send it", sortOrder: 2, parentID: reply.id))
        context.insert(TaskItem(title: "Step outside for five minutes", isDone: true, completedAt: ago(0, hour: 2), sortOrder: 2))

        context.insert(Affirmation(text: "I got through today. That counts.", sortOrder: 0))
        context.insert(Affirmation(text: "Small steps still move me forward.", sortOrder: 1))

        context.insert(JournalEntry(createdAt: ago(0, hour: 3), text: "Slept badly, but the walk helped a bit."))
        context.insert(JournalEntry(createdAt: ago(1, hour: 2), text: "Quiet day. Made toast, answered one message, and that was enough."))
        context.insert(JournalEntry(createdAt: ago(3), text: "Felt tense before the call, but it went better than I expected."))
        context.insert(CheckIn(timestamp: ago(1, hour: 5), physicalExhaustion: 0.4, cognitiveBurnout: 0.5,
                               mentalLoad: 0.45, physicalEnergy: 0.5, socialEnergy: 0.35))

        context.insert(BridgeDraftItem(text: "Sleep has been off"))
        context.insert(BridgeDraftItem(text: "Medication question"))
        context.insert(BridgeDraftItem(text: "Ask about next steps"))

        context.insert(FutureNote(unlockDate: now.addingTimeInterval(14 * 86_400), text: "You got through last time too."))
        context.insert(ThreadMessage(timestamp: ago(2), text: "Thanks for checking in on me.", withContactID: demoSam.id))

        try? context.save()
        return container
    }
}
