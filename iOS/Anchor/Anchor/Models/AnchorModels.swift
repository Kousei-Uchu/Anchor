//
//  AnchorModels.swift
//  Anchor
//
//  Shared SwiftData model layer.
//
//  Design rule baked into every model here: no field in this file exists
//  to score, streak, gamify, or track body/weight. If you're adding a
//  property, ask "does this describe something the user wrote or chose,
//  or does it grade them?" Only the former belongs in this file.
//  (The optional Recovery area in RecoveryModels.swift is a documented, opt-in
//  exception: a counter is a date the user chose, and is never scored.)
//
//  Journal is not a separate silo — JournalEntry is the one shared content
//  pool. Bridge, Plan notifications, and Thread all read from it via
//  `linkedContext`, they don't duplicate it.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Journal (the shared content pool)

/// A single journal entry. This is the canonical store of the user's own
/// words — everything else in the app (notification copy, Bridge exports,
/// Thread quotes) points back into this table rather than generating new text.
@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var text: String

    /// Free-text search; no mood score, no numeric field of any kind.
    var isFavorited: Bool

    /// If this entry was opened as an expansion of a check-in, tool tap,
    /// or contact message elsewhere in the app, this records where it came
    /// from so Bridge/Plan can trace context — never shown as a metric,
    /// just used for "why was this entry surfaced" provenance.
    var linkedContext: EntryOrigin?

    /// Voice memo file reference, if this entry was captured via voice-to-text
    /// and the user chose to keep the audio alongside the transcript.
    var audioFileName: String?

    init(id: UUID = UUID(), createdAt: Date = .now, text: String, linkedContext: EntryOrigin? = nil, audioFileName: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.isFavorited = false
        self.linkedContext = linkedContext
        self.audioFileName = audioFileName
    }
}

enum EntryOrigin: String, Codable {
    case checkInSlider
    case groundingTool
    case contactMessage
    case triggerWindowNotification
    case manualOpen   // opened Journal directly as "just write"
}

// MARK: - Now: check-ins

/// The five-slider exhaustion model, described in the user's own words.
/// No history graph, no streak, no "you haven't checked in today" nag —
/// this is a snapshot the user can optionally save, not a tracker.
@Model
final class CheckIn {
    @Attribute(.unique) var id: UUID
    var timestamp: Date

    // Each is a private 0...1 continuous value the user sets by feel,
    // not a labeled 1-10 "score." No aggregate/average is ever computed
    // or displayed — that would just be a score by another name.
    var physicalExhaustion: Double
    var cognitiveBurnout: Double
    var mentalLoad: Double
    var physicalEnergy: Double
    var socialEnergy: Double

    /// Optional link to a journal entry if the user expanded this check-in
    /// into free writing.
    var expandedEntryID: UUID?

    init(id: UUID = UUID(), timestamp: Date = .now,
         physicalExhaustion: Double, cognitiveBurnout: Double, mentalLoad: Double,
         physicalEnergy: Double, socialEnergy: Double, expandedEntryID: UUID? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.physicalExhaustion = physicalExhaustion
        self.cognitiveBurnout = cognitiveBurnout
        self.mentalLoad = mentalLoad
        self.physicalEnergy = physicalEnergy
        self.socialEnergy = socialEnergy
        self.expandedEntryID = expandedEntryID
    }
}

// MARK: - Contacts

@Model
final class TrustedContact {
    @Attribute(.unique) var id: UUID
    var name: String
    var phoneNumber: String   // routes to native Messages, not a custom backend
    var sortOrder: Int

    /// `URL(string: "tel:0412 345 678")` returns nil because of the spaces
    /// — phone numbers are stored exactly as typed (so they display right
    /// everywhere), but dialing needs digits + an optional leading "+"
    /// only. Same logic as ContactWidgetSummary.dialableNumber, needed
    /// here too now that the actual call happens in-app.
    var dialableNumber: String {
        var result = ""
        for (index, character) in phoneNumber.enumerated() {
            if character.isNumber {
                result.append(character)
            } else if character == "+" && index == 0 {
                result.append(character)
            }
        }
        return result
    }

    /// Opt-in per contact. Off by default. Never auto-enabled by the app.
    var escalationEnabled: Bool
    /// Minutes to wait for a response to a routine check-in before this
    /// contact is notified. Only used if escalationEnabled == true.
    var escalationWindowMinutes: Int?

    var messageTemplates: [MessageTemplate]

    /// How reaching this person actually works. Phone (SMS/call) is the
    /// default and always available; Discord needs their numeric user ID
    /// — Discord's URL scheme can't resolve a DM from a username alone.
    var contactMethod: ContactMethod
    var discordUserID: String?

    /// Optional — powers the "who's awake" screen. All nil means "unknown,
    /// don't show a status for this person."
    var timeZoneIdentifier: String?
    var availableFromHour: Int?
    var availableFromMinute: Int?
    var availableToHour: Int?
    var availableToMinute: Int?

    init(id: UUID = UUID(), name: String, phoneNumber: String, sortOrder: Int,
         escalationEnabled: Bool = false, escalationWindowMinutes: Int? = nil,
         messageTemplates: [MessageTemplate] = [],
         contactMethod: ContactMethod = .phone, discordUserID: String? = nil,
         timeZoneIdentifier: String? = nil,
         availableFromHour: Int? = nil, availableFromMinute: Int? = nil,
         availableToHour: Int? = nil, availableToMinute: Int? = nil) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
        self.sortOrder = sortOrder
        self.escalationEnabled = escalationEnabled
        self.escalationWindowMinutes = escalationWindowMinutes
        self.messageTemplates = messageTemplates
        self.contactMethod = contactMethod
        self.discordUserID = discordUserID
        self.timeZoneIdentifier = timeZoneIdentifier
        self.availableFromHour = availableFromHour
        self.availableFromMinute = availableFromMinute
        self.availableToHour = availableToHour
        self.availableToMinute = availableToMinute
    }
}

enum ContactMethod: String, Codable {
    case phone, discord
}

struct MessageTemplate: Codable, Identifiable {
    var id: UUID = UUID()
    var label: String     // e.g. "Need to talk", "Just checking in", "Quiet room"
    var body: String
    var isCustom: Bool
}

// MARK: - Grounding tools

enum GroundingToolKind: String, Codable {
    case physicalAction   // shown as described steps
    case deepLink         // opens a specific external destination
}

enum DeepLinkDestination: Codable {
    case spotifyPlaylist(uri: String)
    case discordChannel(url: String)
    case app(urlScheme: String)
    case website(url: String)
}

/// User-authored grounding tools only. No generic "hold ice / snap a rubber
/// band" suggestions are ever seeded or offered by this app.
@Model
final class GroundingTool {
    @Attribute(.unique) var id: UUID
    var title: String
    var kind: GroundingToolKind
    var steps: String?                 // for .physicalAction
    var deepLink: DeepLinkDestination? // for .deepLink
    var sortOrder: Int

    /// Which times of day this makes sense to surface (ties into the
    /// "filtered to what's near/available right now" behavior). Empty
    /// means "always relevant."
    var relevantTimeWindows: [TimeWindowTag]

    init(id: UUID = UUID(), title: String, kind: GroundingToolKind,
         steps: String? = nil, deepLink: DeepLinkDestination? = nil,
         sortOrder: Int, relevantTimeWindows: [TimeWindowTag] = []) {
        self.id = id
        self.title = title
        self.kind = kind
        self.steps = steps
        self.deepLink = deepLink
        self.sortOrder = sortOrder
        self.relevantTimeWindows = relevantTimeWindows
    }
}

enum TimeWindowTag: String, Codable {
    case morning, afternoon, evening, lateNight
}

// MARK: - Plan: safety plan, trigger windows, appointments

@Model
final class SafetyPlan {
    @Attribute(.unique) var id: UUID
    var lastEditedAt: Date
    var warningSignsText: String
    var copingStrategiesText: String
    var reasonsToKeepGoingText: String   // source pool for templated notification quotes
    var environmentSafetyStepsText: String

    init(id: UUID = UUID(), lastEditedAt: Date = .now,
         warningSignsText: String = "", copingStrategiesText: String = "",
         reasonsToKeepGoingText: String = "", environmentSafetyStepsText: String = "") {
        self.id = id
        self.lastEditedAt = lastEditedAt
        self.warningSignsText = warningSignsText
        self.copingStrategiesText = copingStrategiesText
        self.reasonsToKeepGoingText = reasonsToKeepGoingText
        self.environmentSafetyStepsText = environmentSafetyStepsText
    }
}

/// A user-defined risk window, e.g. "school mornings," "afternoons,"
/// "missing my friend at the station." Time/routine-based only — never
/// a location trigger.
@Model
final class TriggerWindow {
    @Attribute(.unique) var id: UUID
    var label: String
    var daysOfWeek: [Int]      // 1 = Sunday ... 7 = Saturday, Calendar-style

    // Stored separately because DateComponents contains Calendar internally,
    // which SwiftData cannot persist.
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    var isActive: Bool

    init(
        id: UUID = UUID(),
        label: String,
        daysOfWeek: [Int],
        startTime: DateComponents,
        endTime: DateComponents,
        isActive: Bool = true
    ) {
        self.id = id
        self.label = label
        self.daysOfWeek = daysOfWeek

        self.startHour = startTime.hour ?? 0
        self.startMinute = startTime.minute ?? 0
        self.endHour = endTime.hour ?? 0
        self.endMinute = endTime.minute ?? 0

        self.isActive = isActive
    }

    var startTime: DateComponents {
        get {
            DateComponents(hour: startHour, minute: startMinute)
        }
        set {
            startHour = newValue.hour ?? 0
            startMinute = newValue.minute ?? 0
        }
    }

    var endTime: DateComponents {
        get {
            DateComponents(hour: endHour, minute: endMinute)
        }
        set {
            endHour = newValue.hour ?? 0
            endMinute = newValue.minute ?? 0
        }
    }
}

/// Appointments are a recurring RULE (e.g. "usually Tuesdays 4pm") plus
/// individually-editable occurrences, because real life moves sessions
/// around. Never a hardcoded fixed interval.
@Model
final class AppointmentSeries {
    @Attribute(.unique) var id: UUID
    var clinicianLabel: String
    var typicalDayOfWeek: Int?

    // Stored separately because DateComponents contains Calendar internally.
    var typicalHour: Int?
    var typicalMinute: Int?

    var typicalCadenceDays: Int

    @Relationship(deleteRule: .cascade)
    var occurrences: [AppointmentOccurrence]

    init(
        id: UUID = UUID(),
        clinicianLabel: String,
        typicalDayOfWeek: Int? = nil,
        typicalTime: DateComponents? = nil,
        typicalCadenceDays: Int = 14,
        occurrences: [AppointmentOccurrence] = []
    ) {
        self.id = id
        self.clinicianLabel = clinicianLabel
        self.typicalDayOfWeek = typicalDayOfWeek

        self.typicalHour = typicalTime?.hour
        self.typicalMinute = typicalTime?.minute

        self.typicalCadenceDays = typicalCadenceDays
        self.occurrences = occurrences
    }

    var typicalTime: DateComponents? {
        guard let hour = typicalHour,
              let minute = typicalMinute else {
            return nil
        }

        return DateComponents(hour: hour, minute: minute)
    }
}

@Model
final class AppointmentOccurrence {
    @Attribute(.unique) var id: UUID
    var scheduledDate: Date       // editable independent of the series rule
    var wasMoved: Bool
    var prepNoteEntryID: UUID?    // links to a Journal/Bridge prep entry
    var postSessionNoteEntryID: UUID?

    init(id: UUID = UUID(), scheduledDate: Date, wasMoved: Bool = false,
         prepNoteEntryID: UUID? = nil, postSessionNoteEntryID: UUID? = nil) {
        self.id = id
        self.scheduledDate = scheduledDate
        self.wasMoved = wasMoved
        self.prepNoteEntryID = prepNoteEntryID
        self.postSessionNoteEntryID = postSessionNoteEntryID
    }
}

// MARK: - Bridge

@Model
final class BridgeDraftItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var text: String
    var isResolved: Bool   // "brought this up already" — not a score, just a checkbox

    init(id: UUID = UUID(), createdAt: Date = .now, text: String, isResolved: Bool = false) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.isResolved = isResolved
    }
}

@Model
final class FeedbackLoopDiagram {
    @Attribute(.unique) var id: UUID
    var title: String
    var lastEditedAt: Date
    /// Serialized node/edge graph the user builds to externalize their own
    /// systems metaphors (e.g. the "like Cloudflare" defense model). Stored
    /// as JSON so the diagram editor can be swapped out without migrating data.
    var graphJSON: Data

    init(id: UUID = UUID(), title: String, lastEditedAt: Date = .now, graphJSON: Data) {
        self.id = id
        self.title = title
        self.lastEditedAt = lastEditedAt
        self.graphJSON = graphJSON
    }
}

// MARK: - Thread

@Model
final class ThreadMessage {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var text: String
    var audioFileName: String?
    var withContactID: UUID?

    init(id: UUID = UUID(), timestamp: Date = .now, text: String,
         audioFileName: String? = nil, withContactID: UUID? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.audioFileName = audioFileName
        self.withContactID = withContactID
    }
}

@Model
final class SupportCalendarEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String
    var visibleToContactIDs: [UUID]   // explicit opt-in list, not "everyone"

    init(id: UUID = UUID(), date: Date, note: String, visibleToContactIDs: [UUID] = []) {
        self.id = id
        self.date = date
        self.note = note
        self.visibleToContactIDs = visibleToContactIDs
    }
}

@Model
final class FutureNote {
    @Attribute(.unique) var id: UUID
    var writtenAt: Date
    var unlockDate: Date
    var text: String
    var isUnlocked: Bool   // derived at read-time from unlockDate, cached here for widget/UI convenience

    init(id: UUID = UUID(), writtenAt: Date = .now, unlockDate: Date, text: String) {
        self.id = id
        self.writtenAt = writtenAt
        self.unlockDate = unlockDate
        self.text = text
        self.isUnlocked = false
    }
}

@Model
final class UnsentDraft {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var recipientLabel: String   // "partner", "school friend", etc — no full identity required
    var text: String
    var wasSent: Bool

    init(id: UUID = UUID(), createdAt: Date = .now, recipientLabel: String, text: String, wasSent: Bool = false) {
        self.id = id
        self.createdAt = createdAt
        self.recipientLabel = recipientLabel
        self.text = text
        self.wasSent = wasSent
    }
}

// MARK: - Decision-fatigue presets
//
// Previously plain view @State with no persistence at all — every launch
// (and every time the view was recreated) silently reset to empty, which
// is exactly the "presets don't seem to save" bug. Now real SwiftData
// models. Choices carry a `steps` string (same one-step-per-line
// convention as GroundingTool.steps) so a preset can be either a flat
// option ("Green pants + brown shirt") or a click-through sequence
// ("Get packet from freezer" → "Put 4-6 in air fryer" → ...), reusing the
// same step-by-step runner UI as Grounding Tools.

@Model
final class DecisionPresetCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \DecisionPresetChoice.category)
    var choices: [DecisionPresetChoice]

    init(id: UUID = UUID(), name: String, sortOrder: Int = 0, choices: [DecisionPresetChoice] = []) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.choices = choices
    }
}

@Model
final class DecisionPresetChoice {
    @Attribute(.unique) var id: UUID
    var name: String
    /// One step per line, same convention as GroundingTool.steps. Empty
    /// means this is just a flat option with no click-through sequence.
    var steps: String
    var sortOrder: Int
    var category: DecisionPresetCategory?

    init(id: UUID = UUID(), name: String, steps: String = "", sortOrder: Int = 0, category: DecisionPresetCategory? = nil) {
        self.id = id
        self.name = name
        self.steps = steps
        self.sortOrder = sortOrder
        self.category = category
    }
}

// MARK: - De-escalation scripts
//
// Previously a single hardcoded string with no way to edit it — the
// user's own feedback ("could do with some workshopping") is exactly why
// this needs to be their words, not a fixed line picked for them. Now a
// user-editable, reorderable list; Now shows one at a time with a way to
// cycle to another.

@Model
final class DeEscalationScript {
    @Attribute(.unique) var id: UUID
    var text: String
    var sortOrder: Int

    init(id: UUID = UUID(), text: String, sortOrder: Int = 0) {
        self.id = id
        self.text = text
        self.sortOrder = sortOrder
    }
}

// MARK: - Affirmations / quotes
//
// A user's own active rotation, shown on Now and a widget. Entirely
// user-controlled: write your own, or add from a curated suggestion pool
// (Views/Now/AffirmationsView.swift) — nothing is added automatically.

@Model
final class Affirmation {
    @Attribute(.unique) var id: UUID
    var text: String
    var sortOrder: Int

    init(id: UUID = UUID(), text: String, sortOrder: Int = 0) {
        self.id = id
        self.text = text
        self.sortOrder = sortOrder
    }
}

// MARK: - Next hour only
//
// Also previously plain @State with no persistence, meaning it silently
// reset every time NowView's card was recreated (essentially every app
// launch) — same class of bug as the decision presets. Now persisted, with
// a self-cleaning rule (anything older than a few hours is purged on load)
// so it stays true to "just this hour" instead of becoming a permanent,
// ever-growing to-do list. `reminderIdentifier` links to a real EventKit
// EKReminder when the user chooses to also add it to Reminders.
@Model
final class NextHourItem {
    @Attribute(.unique) var id: UUID
    var text: String
    var isDone: Bool
    var createdAt: Date
    var reminderIdentifier: String?

    init(id: UUID = UUID(), text: String, isDone: Bool = false, createdAt: Date = .now, reminderIdentifier: String? = nil) {
        self.id = id
        self.text = text
        self.isDone = isDone
        self.createdAt = createdAt
        self.reminderIdentifier = reminderIdentifier
    }
}

// MARK: - Tasks
//
// Replaces the self-clearing "Next hour only" list with a real, lasting task
// list. Every property after `title` has a default, so later patches can add
// fields (due dates, subtasks, dependencies) without a store migration.
// `reminderIdentifier` links a task that was imported from the Reminders app.
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String = ""
    var isDone: Bool = false
    var completedAt: Date? = nil
    var createdAt: Date = Date.now
    var sortOrder: Int = 0
    var reminderIdentifier: String? = nil
    /// How the task is timed. `dueDate` holds the exact day for `.exact`, and
    /// the last moment of the day, week or month for those loose choices, so
    /// that a plan which has passed can be told apart from one still ahead.
    var dueKind: TaskDueKind = TaskDueKind.noDate
    var dueDate: Date? = nil
    /// A step is a task with a `parentID`: the id of the task it belongs to.
    /// Steps share this model so ticking, ordering, export and import all
    /// work as they do for tasks, and no store migration is needed.
    var parentID: UUID? = nil
    /// Whether this task's steps are folded away on the list.
    var subtasksCollapsed: Bool = false

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        isDone: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        sortOrder: Int = 0,
        reminderIdentifier: String? = nil,
        dueKind: TaskDueKind = .noDate,
        dueDate: Date? = nil,
        parentID: UUID? = nil,
        subtasksCollapsed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isDone = isDone
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.reminderIdentifier = reminderIdentifier
        self.dueKind = dueKind
        self.dueDate = dueDate
        self.parentID = parentID
        self.subtasksCollapsed = subtasksCollapsed
    }

    /// Ticks the task off or back on, keeping `completedAt` in step.
    func setDone(_ done: Bool) {
        isDone = done
        completedAt = done ? Date.now : nil
    }
}

/// When a task is meant to happen. Loose choices ("this week") are as valid as
/// an exact date, and nothing here is ever shown as late or overdue.
enum TaskDueKind: String, Codable, CaseIterable, Identifiable {
    case noDate, asap, today, thisWeek, thisMonth, someday, exact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noDate: return "No date"
        case .asap: return "As soon as I can"
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .thisMonth: return "This month"
        case .someday: return "Someday"
        case .exact: return "A particular day"
        }
    }
}

/// The groups the task list is shown in, in this order.
enum TaskBucket: Int, CaseIterable, Identifiable {
    case today, thisWeek, later, noDate

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .later: return "Later"
        case .noDate: return "No date"
        }
    }
}

extension TaskItem {
    /// Sets the timing, working out the stored date for the loose choices.
    /// `day` is only used for `.exact`.
    func setDue(_ kind: TaskDueKind, day: Date? = nil, now: Date = .now, calendar: Calendar = .current) {
        dueKind = kind
        switch kind {
        case .noDate, .asap, .someday:
            dueDate = nil
        case .exact:
            dueDate = calendar.startOfDay(for: day ?? dueDate ?? now)
        case .today:
            dueDate = Self.lastMoment(of: .day, containing: now, calendar: calendar)
        case .thisWeek:
            dueDate = Self.lastMoment(of: .weekOfYear, containing: now, calendar: calendar)
        case .thisMonth:
            dueDate = Self.lastMoment(of: .month, containing: now, calendar: calendar)
        }
    }

    private static func lastMoment(of component: Calendar.Component, containing date: Date, calendar: Calendar) -> Date? {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return nil }
        return interval.end.addingTimeInterval(-1)
    }

    /// Where the task sits in the list. A plan whose time has passed moves
    /// into Today, quietly, rather than being flagged as late.
    func bucket(now: Date = .now, calendar: Calendar = .current) -> TaskBucket {
        switch dueKind {
        case .noDate: return .noDate
        case .asap: return .today
        case .someday: return .later
        case .exact:
            guard let due = dueDate else { return .noDate }
            let day = calendar.startOfDay(for: due)
            if day <= calendar.startOfDay(for: now) { return .today }
            if let week = calendar.dateInterval(of: .weekOfYear, for: now), day < week.end { return .thisWeek }
            return .later
        case .today, .thisWeek, .thisMonth:
            if let end = dueDate, end < now { return .today }
            switch dueKind {
            case .today: return .today
            case .thisWeek: return .thisWeek
            default: return .later
            }
        }
    }

    /// A short, calm line about the timing, or nil when there is none.
    func dueText(now: Date = .now, calendar: Calendar = .current) -> String? {
        switch dueKind {
        case .noDate: return nil
        case .asap: return "As soon as I can"
        case .someday: return "Someday"
        case .exact:
            guard let due = dueDate else { return nil }
            let text = due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            return calendar.startOfDay(for: due) < calendar.startOfDay(for: now) ? "Planned for \(text)" : text
        case .today, .thisWeek, .thisMonth:
            if let end = dueDate, end < now { return "Carried over from \(dueKind.label.lowercased())" }
            return dueKind.label
        }
    }

    /// Open tasks in the order the list shows them: group first, then your own order.
    static func listOrder(_ tasks: [TaskItem], now: Date = .now) -> [TaskItem] {
        topLevel(tasks).filter { !$0.isDone }.sorted {
            let a = $0.bucket(now: now), b = $1.bucket(now: now)
            return a.rawValue != b.rawValue ? a.rawValue < b.rawValue : $0.sortOrder < $1.sortOrder
        }
    }
}

extension TaskItem {
    /// Tasks that are not steps of another task. A step whose task is gone is
    /// treated as a task of its own, so it never drops out of sight.
    static func topLevel(_ tasks: [TaskItem]) -> [TaskItem] {
        let ids = Set(tasks.map(\.id))
        return tasks.filter { task in
            guard let parent = task.parentID else { return true }
            return !ids.contains(parent)
        }
    }

    /// The steps of one task, in the order you set.
    static func steps(of task: TaskItem, in tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.parentID == task.id }.sorted { $0.sortOrder < $1.sortOrder }
    }
}

extension ModelContext {
    /// Deleting a task takes its steps with it.
    func deleteTask(_ task: TaskItem, among tasks: [TaskItem]) {
        for step in TaskItem.steps(of: task, in: tasks) { delete(step) }
        delete(task)
    }
}

enum TaskMigration {
    private static let flagKey = "anchor.tasksMigratedFromNextHour"

    /// One time: turns any "Next hour only" rows into tasks and removes the old
    /// rows, so nothing shows twice. It does nothing when the saved store could
    /// not be opened (the app is then on a temporary store), and it only marks
    /// itself done once the copy has been saved.
    @MainActor
    static func migrateNextHourItemsIfNeeded(container: ModelContainer) {
        guard AnchorSchema.openedPersistentStore,
              !UserDefaults.standard.bool(forKey: flagKey) else { return }
        let context = container.mainContext
        guard let old = try? context.fetch(FetchDescriptor<NextHourItem>(sortBy: [SortDescriptor(\.createdAt)])) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<TaskItem>())) ?? 0
        for (index, item) in old.enumerated() {
            context.insert(TaskItem(
                title: item.text,
                isDone: item.isDone,
                completedAt: item.isDone ? item.createdAt : nil,
                createdAt: item.createdAt,
                sortOrder: existing + index,
                reminderIdentifier: item.reminderIdentifier
            ))
        }
        do {
            try context.save()
        } catch {
            // Nothing was kept. The next launch starts again from the old rows.
            return
        }
        // The tasks are saved, so never copy again, even if removing the old
        // rows below fails. They are no longer read anywhere.
        UserDefaults.standard.set(true, forKey: flagKey)
        for item in old { context.delete(item) }
        try? context.save()
    }
}

// MARK: - Mascot (pre-written lines only — never generative at runtime)

enum MascotMood: String, Codable {
    case gentle, quietDay, encouragingNotPerformative, neutral
}

enum MascotTrigger: String, Codable {
    case appOpen, checkInPrompt, groundingToolOffered, triggerWindowNotification,
         appointmentReminder, journalPrompt
}

/// Every line the mascot can ever say is authored and reviewed ahead of time
/// and lives in this table (seeded from a reviewed content pack, editable by
/// the user). At runtime the app only ever *selects* from this pool — it
/// never asks an LLM or any generator to author new dialogue, especially
/// nothing crisis-adjacent.
@Model
final class MascotLine {
    @Attribute(.unique) var id: UUID
    var trigger: MascotTrigger
    var mood: MascotMood
    var text: String
    var isUserAuthored: Bool   // false = shipped with the reviewed content pack

    init(id: UUID = UUID(), trigger: MascotTrigger, mood: MascotMood, text: String, isUserAuthored: Bool = false) {
        self.id = id
        self.trigger = trigger
        self.mood = mood
        self.text = text
        self.isUserAuthored = isUserAuthored
    }
}

// MARK: - Container

enum AnchorSchema {
    static var models: [any PersistentModel.Type] {
        [
            JournalEntry.self, CheckIn.self, TrustedContact.self, GroundingTool.self,
            SafetyPlan.self, TriggerWindow.self, AppointmentSeries.self, AppointmentOccurrence.self,
            BridgeDraftItem.self, FeedbackLoopDiagram.self,
            ThreadMessage.self, SupportCalendarEntry.self, FutureNote.self, UnsentDraft.self,
            MascotLine.self, DecisionPresetCategory.self, DecisionPresetChoice.self,
            DeEscalationScript.self, NextHourItem.self, TaskItem.self, Affirmation.self,
            RecoveryCounter.self, RecoveryMotivation.self, RecoveryDayEntry.self, RecoveryUrge.self
        ]
    }

    /// False if the saved store could not be opened and Anchor fell back to a
    /// temporary in-memory store. In that case the real files are left
    /// untouched on disk (never deleted or reset), and the app shows a banner
    /// so nobody keeps writing into a store that won't be saved.
    static private(set) var openedPersistentStore = true

    static func makeContainer() -> ModelContainer {
        let schema = Schema(models)
        // Local-first: no CloudKit configuration and no sync service. Data moves
        // only through explicit export/import, never a required third-party cloud.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            applyDataProtection(at: configuration.url)
            return container
        } catch {
            openedPersistentStore = false
            let temporary = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [temporary])
            } catch {
                fatalError("Could not create any Anchor ModelContainer: \(error)")
            }
        }
    }

    /// Encryption at rest through iOS Data Protection, without a custom
    /// crypto layer or a third-party dependency. The store is encrypted with
    /// a key derived from the device passcode. `completeUntilFirstUserAuthentication`
    /// (rather than `complete`) is deliberate: with `complete`, a background
    /// launch while the phone is locked, for example from a notification
    /// action, cannot open the database at all.
    private static func applyDataProtection(at url: URL) {
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        // SwiftData/Core Data stores are typically split across the main
        // file plus -wal/-shm sidecar files; protect all three if present.
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            guard FileManager.default.fileExists(atPath: path) else { continue }
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: path)
        }
    }
}
