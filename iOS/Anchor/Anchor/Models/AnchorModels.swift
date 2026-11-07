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

extension JournalEntry {
    /// What the person sees as a bookmark. It is kept in the existing
    /// `isFavorited` field, so nothing about the stored data or exports changes.
    var isBookmarked: Bool {
        get { isFavorited }
        set { isFavorited = newValue }
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

/// One section of the safety plan: a title, the person's own words, and how
/// it looks. Sections can be renamed, reordered, added, hidden and removed.
/// The four text fields on `SafetyPlan` are the older form: they are copied
/// into sections once, never changed afterwards, and no longer read.
@Model
final class SafetyPlanSection {
    @Attribute(.unique) var id: UUID
    var title: String
    var text: String
    var iconName: String
    var tintName: String
    var sortOrder: Int
    var isHidden: Bool
    /// Empty for an ordinary section. `reasonsRole` marks the one section that
    /// reminder quotes are taken from.
    var role: String
    var lastEditedAt: Date

    static let reasonsRole = "reasons"

    init(id: UUID = UUID(), title: String = "", text: String = "",
         iconName: String = "doc.text.fill", tintName: String = "sage",
         sortOrder: Int = 0, isHidden: Bool = false, role: String = "",
         lastEditedAt: Date = .now) {
        self.id = id
        self.title = title
        self.text = text
        self.iconName = iconName
        self.tintName = tintName
        self.sortOrder = sortOrder
        self.isHidden = isHidden
        self.role = role
        self.lastEditedAt = lastEditedAt
    }
}

/// One section of the Boundaries list: things the person would like others to
/// know, what helps, what does not. The same shape as a safety plan section
/// plus a flag saying whether it may be shared when they choose to share the
/// list. Nothing is shared unless they do it themselves.
@Model
final class BoundarySection {
    @Attribute(.unique) var id: UUID
    var title: String
    var text: String
    var iconName: String
    var tintName: String
    var sortOrder: Int
    var isHidden: Bool
    var isShareable: Bool
    var lastEditedAt: Date

    init(id: UUID = UUID(), title: String = "", text: String = "",
         iconName: String = "hand.raised.fill", tintName: String = "sage",
         sortOrder: Int = 0, isHidden: Bool = false, isShareable: Bool = false,
         lastEditedAt: Date = .now) {
        self.id = id
        self.title = title
        self.text = text
        self.iconName = iconName
        self.tintName = tintName
        self.sortOrder = sortOrder
        self.isHidden = isHidden
        self.isShareable = isShareable
        self.lastEditedAt = lastEditedAt
    }

    /// The three headings suggested for a new list, all blank, none shareable.
    /// They are made only when the person asks for them.
    static func startingSections() -> [BoundarySection] {
        [
            BoundarySection(title: "Things I'd like people to know", iconName: "person.2.fill", tintName: "sage", sortOrder: 0),
            BoundarySection(title: "Things that help", iconName: "heart.fill", tintName: "accent", sortOrder: 1),
            BoundarySection(title: "Things that don't", iconName: "hand.raised.fill", tintName: "sage", sortOrder: 2)
        ]
    }

    /// Plain text of the shown sections marked shareable that have words in
    /// them, each under its title. Empty when there is nothing to share.
    static func shareText(from sections: [BoundarySection]) -> String {
        sections
            .filter { $0.isShareable && !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { section -> String? in
                let words = section.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !words.isEmpty else { return nil }
                let name = section.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? words : "\(name)\n\(words)"
            }
            .joined(separator: "\n\n")
    }
}

/// One section of a person's page: a note about them, what helps, things the
/// person has told them, or anything else the person decides to keep. The
/// same shape as a safety plan section, tied to one trusted contact by id.
/// Nothing is made for anyone, and nothing here is counted or scored.
@Model
final class PersonSection {
    @Attribute(.unique) var id: UUID
    /// The `TrustedContact` this page belongs to.
    var contactID: UUID
    var title: String
    var text: String
    var iconName: String
    var tintName: String
    var sortOrder: Int
    var isHidden: Bool
    var lastEditedAt: Date

    init(id: UUID = UUID(), contactID: UUID, title: String = "", text: String = "",
         iconName: String = "doc.text.fill", tintName: String = "sage",
         sortOrder: Int = 0, isHidden: Bool = false, lastEditedAt: Date = .now) {
        self.id = id
        self.contactID = contactID
        self.title = title
        self.text = text
        self.iconName = iconName
        self.tintName = tintName
        self.sortOrder = sortOrder
        self.isHidden = isHidden
        self.lastEditedAt = lastEditedAt
    }

    /// Removes every section on one person's page. Called when the person is
    /// deleted, so nothing is left behind that can no longer be seen.
    static func removeAll(for contactID: UUID, in context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<PersonSection>()) else { return }
        for section in all where section.contactID == contactID { context.delete(section) }
    }
}

/// A short dated note the person adds to one of their goals along the way.
struct GoalNote: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = .now
    var text: String
}

enum GoalStatus: String, CaseIterable, Identifiable {
    case active, reached, setAside

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active: return "Working on it"
        case .reached: return "Reached"
        case .setAside: return "Set aside for now"
        }
    }
}

/// One of the person's own goals, written in their words, with short dated
/// notes along the way. Nothing is scored, counted as a percentage or framed
/// as treatment: a note is just something they wanted to remember. Where a
/// goal is (working on it, reached, set aside for now) is the person's call.
@Model
final class PersonalGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var why: String = ""
    var statusRaw: String = "active"
    var notes: [GoalNote] = []
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var lastEditedAt: Date = Date.now

    init(id: UUID = UUID(), title: String = "", why: String = "", status: GoalStatus = .active,
         notes: [GoalNote] = [], sortOrder: Int = 0, createdAt: Date = .now, lastEditedAt: Date = .now) {
        self.id = id
        self.title = title
        self.why = why
        self.statusRaw = status.rawValue
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
    }

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
}

/// One of the person's own short lines for starting a message on a hard day,
/// such as "I'm not up to talking, but I'm safe". Nothing is written for them:
/// the list starts empty. Tapping one puts it in the message box, where it can
/// be changed before anything is saved or sent.
@Model
final class MessageStarter {
    @Attribute(.unique) var id: UUID
    var text: String
    var sortOrder: Int
    var lastEditedAt: Date

    init(id: UUID = UUID(), text: String = "", sortOrder: Int = 0, lastEditedAt: Date = .now) {
        self.id = id
        self.text = text
        self.sortOrder = sortOrder
        self.lastEditedAt = lastEditedAt
    }

    /// `existing` with `starter` put in: it replaces nothing, so a message the
    /// person has already begun keeps its words and the starter follows them.
    static func adding(_ starter: String, to existing: String) -> String {
        let line = starter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return existing }
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return line }
        let separator = existing.last?.isWhitespace == true ? "" : " "
        return existing + separator + line
    }
}

enum SafetyPlanSections {
    /// The four sections the plan always had, in their old order, holding the
    /// given text. Used for the one-time copy and for a plan started fresh.
    static func makeSections(warningSigns: String = "", copingStrategies: String = "",
                             reasons: String = "", environment: String = "",
                             edited: Date = .now) -> [SafetyPlanSection] {
        [
            SafetyPlanSection(title: "Warning signs", text: warningSigns,
                              iconName: "exclamationmark.triangle.fill", tintName: "accent",
                              sortOrder: 0, lastEditedAt: edited),
            SafetyPlanSection(title: "Coping strategies", text: copingStrategies,
                              iconName: "leaf.fill", tintName: "sage",
                              sortOrder: 1, lastEditedAt: edited),
            SafetyPlanSection(title: "Reasons to keep going", text: reasons,
                              iconName: "heart.fill", tintName: "accent",
                              sortOrder: 2, role: SafetyPlanSection.reasonsRole, lastEditedAt: edited),
            SafetyPlanSection(title: "Making the environment safer", text: environment,
                              iconName: "house.fill", tintName: "sage",
                              sortOrder: 3, lastEditedAt: edited)
        ]
    }

    static func firstLine(_ text: String) -> String? {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }

    /// The lines reminder quotes may use: the lines of the shown section
    /// marked for it. With no such section there is nothing to quote, so
    /// reminders carry their plain wording.
    static func reasonLines(from sections: [SafetyPlanSection]) -> [String] {
        guard let source = sections.first(where: { $0.role == SafetyPlanSection.reasonsRole && !$0.isHidden }) else { return [] }
        return source.text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Whether any section, shown or not, has something written in it.
    static func hasContent(_ sections: [SafetyPlanSection]) -> Bool {
        sections.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func hasText(_ plan: SafetyPlan) -> Bool {
        [plan.warningSignsText, plan.copingStrategiesText, plan.reasonsToKeepGoingText, plan.environmentSafetyStepsText]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

enum SafetyPlanMigration {
    private static let flagKey = "anchor.safetyPlanSectionsMade"

    /// One time: copies the four old text fields into sections, so nothing is
    /// lost, and leaves the old fields exactly as they were. It does nothing
    /// when the saved store could not be opened, never copies twice, and only
    /// marks itself done once the sections are saved.
    @MainActor
    static func migrateIfNeeded(container: ModelContainer) {
        guard AnchorSchema.openedPersistentStore,
              !UserDefaults.standard.bool(forKey: flagKey) else { return }
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<SafetyPlanSection>())) ?? 0
        if existing == 0,
           let plans = try? context.fetch(FetchDescriptor<SafetyPlan>()),
           let plan = plans.first(where: SafetyPlanSections.hasText) {
            let made = SafetyPlanSections.makeSections(
                warningSigns: plan.warningSignsText,
                copingStrategies: plan.copingStrategiesText,
                reasons: plan.reasonsToKeepGoingText,
                environment: plan.environmentSafetyStepsText,
                edited: plan.lastEditedAt
            )
            for section in made { context.insert(section) }
            do {
                try context.save()
            } catch {
                // Nothing was kept. The next launch starts again.
                return
            }
        }
        UserDefaults.standard.set(true, forKey: flagKey)
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

    /// What they do, in the person's own words ("GP", "Counsellor"). Optional.
    var role: String = ""
    /// The name used on anything exported or shared. Empty means the name as shown.
    var exportLabel: String = ""
    /// Anything the person wants to remember about them, in their own words.
    var notes: String = ""
    /// Position in the list of providers.
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade)
    var occurrences: [AppointmentOccurrence]

    init(
        id: UUID = UUID(),
        clinicianLabel: String,
        typicalDayOfWeek: Int? = nil,
        typicalTime: DateComponents? = nil,
        typicalCadenceDays: Int = 14,
        occurrences: [AppointmentOccurrence] = [],
        role: String = "",
        exportLabel: String = "",
        notes: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.clinicianLabel = clinicianLabel
        self.typicalDayOfWeek = typicalDayOfWeek

        self.typicalHour = typicalTime?.hour
        self.typicalMinute = typicalTime?.minute

        self.typicalCadenceDays = typicalCadenceDays
        self.occurrences = occurrences
        self.role = role
        self.exportLabel = exportLabel
        self.notes = notes
        self.sortOrder = sortOrder
    }

    /// The name shown in the app. Never empty, so a provider added and left
    /// unnamed still has something to tap.
    var displayName: String {
        let trimmed = clinicianLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed" : trimmed
    }

    /// The name that goes on anything exported or shared: the export label
    /// if one was written, otherwise the name as shown.
    var exportName: String {
        let trimmed = exportLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? displayName : trimmed
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
    /// True when the item is a question to ask rather than something to raise.
    var isQuestion: Bool = false
    /// What was said in answer, written by the person after the session.
    /// Only used when the item is a question.
    var answer: String = ""
    /// The provider (an `AppointmentSeries` id) this is for. Nil means it is
    /// for anyone. Kept as a plain id rather than a relationship, so removing
    /// a provider can never remove an item.
    var providerID: UUID? = nil

    init(id: UUID = UUID(), createdAt: Date = .now, text: String, isResolved: Bool = false,
         isQuestion: Bool = false, answer: String = "", providerID: UUID? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.isResolved = isResolved
        self.isQuestion = isQuestion
        self.answer = answer
        self.providerID = providerID
    }
}

extension BridgeDraftItem {
    /// The provider this item is for, or nil when it is for anyone. An item
    /// whose provider has since gone counts as being for anyone, so nothing
    /// is ever hidden by a missing person.
    func provider(in providers: [AppointmentSeries]) -> AppointmentSeries? {
        guard let providerID else { return nil }
        return providers.first { $0.id == providerID }
    }

    /// True when this belongs on a page or an export for the given provider:
    /// it is for them, or for anyone.
    func isFor(_ providerID: UUID, in providers: [AppointmentSeries]) -> Bool {
        guard let own = provider(in: providers) else { return true }
        return own.id == providerID
    }
}

extension BridgeDraftItem {
    /// A Things to raise item made from a journal entry: its first line with
    /// any heading, bullet or quote mark dropped, up to 160 characters. Nil
    /// when the entry has no words. The entry itself is never changed or
    /// linked, so the item can be reworded freely.
    static func raising(fromJournal text: String) -> BridgeDraftItem? {
        // Photo and card lines are blocks, not words, so they are skipped.
        guard let first = text.split(separator: "\n")
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { !$0.isEmpty && !$0.hasPrefix("![") && !$0.contains("](anchorcard://") }) else { return nil }
        let marks = CharacterSet(charactersIn: "#-*>").union(.whitespaces)
        let cleaned = first.trimmingCharacters(in: marks)
        guard !cleaned.isEmpty else { return nil }
        return BridgeDraftItem(text: String(cleaned.prefix(160)))
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
    /// What the person wrote after "Open when", for a letter they open when
    /// they choose. Empty for a note sealed until a date. A letter has no
    /// date to wait for, and nothing opens it, counts it or reminds them of it.
    var openWhen: String = ""

    init(id: UUID = UUID(), writtenAt: Date = .now, unlockDate: Date, text: String, openWhen: String = "") {
        self.id = id
        self.writtenAt = writtenAt
        self.unlockDate = unlockDate
        self.text = text
        self.isUnlocked = false
        self.openWhen = openWhen
    }

    var isOpenWhenLetter: Bool {
        !openWhen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    /// Tasks this one is waiting on. While any of them is still open, this
    /// task sits under "Waiting on something else". A blocker that has been
    /// deleted is simply ignored.
    var blockedByIDs: [UUID] = []
    /// Where the task is in your own words: not started, started, or set aside
    /// for now. Done stays `isDone`. A task with a step ticked off also counts
    /// as started without you having to say so (see `isStarted`).
    var status: TaskStatus = TaskStatus.notStarted
    /// How much energy the task needs, if you have said. Only used to narrow
    /// the list on a low day; nothing is scored or compared.
    var energy: TaskEnergy = TaskEnergy.unset
    /// The smallest way to begin, in a few words. Separate from steps so it
    /// can be a single line.
    var firstStep: String = ""
    /// How many focus sessions have run to the end on this task, and the
    /// minutes they added up to. A plain record: nothing is scored, compared
    /// or shown against a goal.
    var focusSessions: Int = 0
    var focusMinutes: Int = 0
    /// A rough guess at how long the task takes, in minutes. 0 means no
    /// estimate. Only used to add up a day's plan; nothing is checked against it.
    var estimateMinutes: Int = 0

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
        subtasksCollapsed: Bool = false,
        blockedByIDs: [UUID] = [],
        status: TaskStatus = .notStarted,
        energy: TaskEnergy = .unset,
        firstStep: String = "",
        focusSessions: Int = 0,
        focusMinutes: Int = 0,
        estimateMinutes: Int = 0
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
        self.blockedByIDs = blockedByIDs
        self.status = status
        self.energy = energy
        self.firstStep = firstStep
        self.focusSessions = focusSessions
        self.focusMinutes = focusMinutes
        self.estimateMinutes = estimateMinutes
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
enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted, inProgress, setAside

    var id: String { rawValue }

    var label: String {
        switch self {
        case .notStarted: return "Not started"
        case .inProgress: return "Started"
        case .setAside: return "Set aside for now"
        }
    }
}

enum TaskEnergy: String, Codable, CaseIterable, Identifiable {
    case unset, little, some, lots

    var id: String { rawValue }

    /// The choice as it reads in the editor.
    var label: String {
        switch self {
        case .unset: return "Not set"
        case .little: return "A little"
        case .some: return "Some"
        case .lots: return "A lot"
        }
    }

    /// The tag as it reads on a task card, or nil when it is not set.
    var cardText: String? {
        switch self {
        case .unset: return nil
        case .little: return "Needs a little energy"
        case .some: return "Needs some energy"
        case .lots: return "Needs a lot of energy"
        }
    }
}

/// Narrows the Tasks list on a low day. Tasks with no energy set are always
/// shown, because nothing is known about them.
enum TaskEnergyFilter: String, CaseIterable, Identifiable {
    case everything, someOrLess, littleOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everything: return "Everything"
        case .someOrLess: return "Some energy or less"
        case .littleOnly: return "Only a little energy"
        }
    }

    /// The line shown above the list while a filter is on.
    var summary: String {
        switch self {
        case .everything: return ""
        case .someOrLess: return "Showing tasks that need some energy or less, and any with no energy set."
        case .littleOnly: return "Showing tasks that need only a little energy, and any with no energy set."
        }
    }

    func allows(_ energy: TaskEnergy) -> Bool {
        switch self {
        case .everything: return true
        case .someOrLess: return energy != .lots
        case .littleOnly: return energy != .some && energy != .lots
        }
    }
}

enum TaskBucket: Int, CaseIterable, Identifiable {
    case today, thisWeek, later, noDate, waiting, setAside

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .thisWeek: return "This week"
        case .later: return "Later"
        case .noDate: return "No date"
        case .waiting: return "Waiting on something else"
        case .setAside: return "Set aside for now"
        }
    }
}

extension TaskItem {
    /// The quick choices offered for an estimate, besides none.
    static let estimateChoices = [5, 15, 30, 60]

    /// "About 15 min", or nil when there is no estimate.
    var estimateText: String? {
        estimateMinutes > 0 ? "About \(TaskItem.durationText(estimateMinutes))" : nil
    }

    /// "45 min", "1 hr", "1 hr 30 min". Lives here, not with the screens,
    /// because this file is also built into the widget.
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        if rest == 0 { return "\(hours) hr" }
        return "\(hours) hr \(rest) min"
    }
}

extension TaskItem {
    /// "2 focus sessions, 50 minutes", or nil before the first one.
    var focusSummary: String? {
        guard focusSessions > 0 else { return nil }
        let sessions = focusSessions == 1 ? "1 focus session" : "\(focusSessions) focus sessions"
        let minutes = focusMinutes == 1 ? "1 minute" : "\(focusMinutes) minutes"
        return "\(sessions), \(minutes)"
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
            if calendar.isDate(due, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now) { return "Tomorrow" }
            let text = due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            return calendar.startOfDay(for: due) < calendar.startOfDay(for: now) ? "Planned for \(text)" : text
        case .today, .thisWeek, .thisMonth:
            if let end = dueDate, end < now { return "Carried over from \(dueKind.label.lowercased())" }
            return dueKind.label
        }
    }

    /// Open tasks in the order the list shows them: group first, then your own order.
    /// `includeWaiting: false` leaves out tasks that are waiting on another and
    /// tasks you have set aside, for places that show what can be done now.
    static func listOrder(_ tasks: [TaskItem], now: Date = .now, includeWaiting: Bool = true) -> [TaskItem] {
        topLevel(tasks).filter { !$0.isDone && (includeWaiting || ($0.status != .setAside && !$0.isBlocked(among: tasks))) }.sorted {
            let a = $0.listBucket(among: tasks, now: now), b = $1.listBucket(among: tasks, now: now)
            return a.rawValue != b.rawValue ? a.rawValue < b.rawValue : $0.sortOrder < $1.sortOrder
        }
    }
}

extension TaskItem {
    /// The open tasks this one is waiting on, if any.
    func openBlockers(among tasks: [TaskItem]) -> [TaskItem] {
        guard !isDone else { return [] }
        return blockedByIDs.compactMap { id in tasks.first(where: { $0.id == id }) }.filter { !$0.isDone }
    }

    func isBlocked(among tasks: [TaskItem]) -> Bool {
        !openBlockers(among: tasks).isEmpty
    }

    /// Where the list puts the task: set aside if you chose that, Waiting while
    /// blocked, otherwise by its timing.
    func listBucket(among tasks: [TaskItem], now: Date = .now, calendar: Calendar = .current) -> TaskBucket {
        if !isDone && status == .setAside { return .setAside }
        return isBlocked(among: tasks) ? .waiting : bucket(now: now, calendar: calendar)
    }

    /// True once you have said so, or as soon as one of its steps is ticked.
    /// A task set aside or done is never shown as started.
    func isStarted(steps: [TaskItem]) -> Bool {
        guard !isDone, status != .setAside else { return false }
        return status == .inProgress || steps.contains(where: \.isDone)
    }

    /// Moves the task to tomorrow. It comes back to Today on its own when the
    /// day arrives, and nothing marks it as late.
    func snoozeToTomorrow(now: Date = .now, calendar: Calendar = .current) {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        setDue(.exact, day: tomorrow, now: now, calendar: calendar)
        if status == .setAside { status = .notStarted }
    }

    /// True when `candidate` already waits on this task, directly or through
    /// others, so choosing it as a blocker would make two tasks wait on each other.
    func wouldCycle(waitingOn candidate: TaskItem, among tasks: [TaskItem]) -> Bool {
        var seen = Set<UUID>()
        var stack = [candidate]
        while let current = stack.popLast() {
            if current.id == id { return true }
            guard seen.insert(current.id).inserted else { continue }
            for blockerID in current.blockedByIDs {
                if let next = tasks.first(where: { $0.id == blockerID }) { stack.append(next) }
            }
        }
        return false
    }

    /// Tasks that could be chosen as something to wait on.
    func possibleBlockers(among tasks: [TaskItem]) -> [TaskItem] {
        TaskItem.topLevel(tasks)
            .filter { $0.id != id && !$0.isDone && !blockedByIDs.contains($0.id) && !wouldCycle(waitingOn: $0, among: tasks) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

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

// MARK: - Quick lists
//
// A one-off checklist: type or paste one item per line, tick things off, and
// the list moves to the Archive by itself when the last one is ticked. The
// items sit inside the list as a small array of values (the way a contact
// keeps its message templates), so a quick list is one record and one entry
// in an export. It is separate from tasks on purpose: no dates, steps,
// waiting or energy, and ticking the last item ends the list instead of
// leaving a finished task behind.

struct QuickListItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var isDone: Bool = false
}

@Model
final class QuickList {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date = Date.now
    var items: [QuickListItem] = []
    /// Set when the last open item is ticked, and cleared again when one is
    /// unticked or a new item is added. nil while the list is still in use.
    var archivedAt: Date? = nil

    init(id: UUID = UUID(), title: String, createdAt: Date = .now,
         items: [QuickListItem] = [], archivedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.items = items
        self.archivedAt = archivedAt
    }
}

extension QuickList {
    /// The most items a list can hold. Far more than a quick list needs; it
    /// only stops a huge paste from making the screen slow.
    static let maxItems = 200

    var isArchived: Bool { archivedAt != nil }
    var doneCount: Int { items.filter(\.isDone).count }
    var openCount: Int { items.count - doneCount }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Quick list" : title
    }

    /// The name a list gets when you leave the name blank, so two lists made
    /// on different days can be told apart.
    static func defaultTitle(now: Date = .now) -> String {
        "Quick list, " + now.formatted(.dateTime.day().month(.abbreviated))
    }

    /// "5 items", "2 of 5 ticked", or "Finished 7 Nov, 5 items" once archived.
    var summaryText: String {
        let count = items.count == 1 ? "1 item" : "\(items.count) items"
        if let archivedAt {
            return "Finished \(archivedAt.formatted(.dateTime.day().month(.abbreviated))), \(count)"
        }
        return doneCount == 0 ? count : "\(doneCount) of \(items.count) ticked"
    }

    /// Items from typed or pasted text, one per line. Blank lines are skipped,
    /// and a bullet, number or tick box at the start of a line is dropped, so a
    /// list copied from Notes or a message pastes cleanly.
    static func parsedItems(from text: String) -> [QuickListItem] {
        var found: [QuickListItem] = []
        for line in text.split(whereSeparator: { $0.isNewline }) {
            let cleaned = cleanedLine(String(line))
            if !cleaned.isEmpty { found.append(QuickListItem(text: cleaned)) }
        }
        return found
    }

    /// One line without its list marker. A marker needs a space after it, so
    /// "-5 degrees" and "2024 taxes" keep their first characters.
    static func cleanedLine(_ raw: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // A bullet or dash: "- ", "* " or a round bullet.
        if let first = line.first, "-*\u{2022}".contains(first), line.dropFirst().first == " " {
            line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        // A number: "1. " or "2) ".
        let digits = line.prefix(while: { $0.isASCII && $0.isNumber })
        if !digits.isEmpty, digits.count <= 3 {
            let rest = line.dropFirst(digits.count)
            if let mark = rest.first, mark == "." || mark == ")", rest.dropFirst().first == " " {
                line = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
        }
        // A tick box: "[ ]" or "[x]".
        for box in ["[ ]", "[x]", "[X]"] where line.hasPrefix(box) {
            line = String(line.dropFirst(box.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        return line
    }

    /// Keeps the archive in step with the ticks: archived while every item is
    /// ticked, back in use the moment one is not. A list with no items is
    /// never archived; it is removed when its screen closes.
    func syncArchive(now: Date = .now) {
        let finished = !items.isEmpty && items.allSatisfy { $0.isDone }
        if finished {
            if archivedAt == nil { archivedAt = now }
        } else if archivedAt != nil {
            archivedAt = nil
        }
    }

    func setItem(_ id: UUID, done: Bool, now: Date = .now) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone = done
        syncArchive(now: now)
    }

    func addItems(_ new: [QuickListItem]) {
        items.append(contentsOf: new.prefix(max(0, QuickList.maxItems - items.count)))
        syncArchive()
    }

    func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
        syncArchive()
    }

    /// Unticks everything, so the same list can be used again.
    func startAgain() {
        for index in items.indices { items[index].isDone = false }
        syncArchive()
    }
}

extension ModelContext {
    /// Run once a quick list's screen has closed, so the screen never reads a
    /// list that is already gone: removes the list you chose to delete, and any
    /// list left with no items (one that was emptied, or moved into Tasks).
    func finishQuickLists(deleting list: QuickList?, among lists: [QuickList]) {
        if let list { delete(list) }
        for other in lists where other !== list && other.items.isEmpty { delete(other) }
    }
}

// MARK: - Routines
//
// A routine is a named list of steps done in the same order each time ("School
// mornings"), with an optional rough time on each step. It sits beside the
// decision presets and is run one step at a time. The steps are a small array
// of values inside the routine (the way a quick list keeps its items), so a
// routine is one record and one entry in an export. Every field has a default,
// and it is a new model, so there is no store migration.

struct RoutineStep: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    /// Rough minutes for this step. 0 means no estimate.
    var minutes: Int = 0
}

@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date = Date.now
    var steps: [RoutineStep] = []
    /// An optional reminder you set yourself. Off unless you switch it on.
    var reminderEnabled: Bool = false
    /// Calendar weekdays the reminder repeats on, 1 = Sunday to 7 = Saturday.
    var reminderDays: [Int] = []
    var reminderHour: Int = 8
    var reminderMinute: Int = 0

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, steps: [RoutineStep] = [],
         reminderEnabled: Bool = false, reminderDays: [Int] = [],
         reminderHour: Int = 8, reminderMinute: Int = 0) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.steps = steps
        self.reminderEnabled = reminderEnabled
        self.reminderDays = reminderDays
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }
}

extension Routine {
    /// The most steps a routine can hold. It only stops a huge paste from
    /// making the screen slow.
    static let maxSteps = 60

    /// The minute choices offered on a step. 0 is no estimate.
    static let minuteChoices = [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60]

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled routine" : name
    }

    /// Steps with some text in them. A step left blank is never run or counted.
    var writtenSteps: [RoutineStep] {
        steps.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var totalMinutes: Int { writtenSteps.reduce(0) { $0 + $1.minutes } }
    var stepsWithoutEstimate: Int { writtenSteps.filter { $0.minutes == 0 }.count }

    /// "6 steps, about 25 min", or "6 steps, about 25 min plus 2 with no
    /// estimate", or just "6 steps" when nothing has a time. nil when empty.
    var summaryText: String? {
        let count = writtenSteps.count
        guard count > 0 else { return nil }
        let steps = count == 1 ? "1 step" : "\(count) steps"
        guard totalMinutes > 0 else { return steps }
        var text = "\(steps), about \(TaskItem.durationText(totalMinutes))"
        let missing = stepsWithoutEstimate
        if missing > 0 { text += " plus \(missing) with no estimate" }
        return text
    }

    /// "Mon, Wed, Fri at 7:30 AM", "Every day at 8:00 AM", or nil while the
    /// reminder is off or has no days.
    var reminderSummary: String? {
        guard reminderEnabled else { return nil }
        let days = Set(reminderDays.filter { (1...7).contains($0) })
        guard !days.isEmpty else { return nil }
        let calendar = Calendar.current
        var parts = DateComponents(); parts.hour = reminderHour; parts.minute = reminderMinute
        let time = calendar.date(from: parts)?.formatted(date: .omitted, time: .shortened) ?? ""
        if days.count == 7 { return "Every day at \(time)" }
        let names = calendar.shortWeekdaySymbols
        let ordered = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }.filter { days.contains($0) }
        return ordered.map { names[$0 - 1] }.joined(separator: ", ") + " at " + time
    }

    /// True for a routine added and then left with no name and no steps.
    var isBlank: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && writtenSteps.isEmpty
    }

    /// Splits pasted text into steps, one per line. A bullet, dash, number or
    /// tick box at the start of a line is dropped (the marker needs a space
    /// after it, so "-5 degrees" and "2024 taxes" are left alone).
    static func parsedSteps(from text: String) -> [RoutineStep] {
        QuickList.parsedItems(from: text).map { RoutineStep(text: $0.text) }
    }
}

// MARK: - Item lists
//
// A packing-style checklist: items sorted under categories, each with a
// quantity that is either a fixed number or worked out from a variable the
// list holds ("Day: 5", "Person: 2"). A rule like "1 per day + 1 extra for
// every 3" follows the variable, so changing the number of days updates every
// quantity at once. Variables, items and rules are small arrays of values
// inside the list (the way a quick list keeps its items), so a list is one
// record and one entry in an export. A new model with defaults on every field,
// so there is no store migration.

struct ListVariable: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var value: Int = 1
}

/// How many of an item. Fixed, or `per` for each of a variable, plus an
/// optional `extra` for every `extraEvery` of it (rounded down).
struct QuantityRule: Codable, Hashable {
    var fixed: Int = 1
    var variableID: UUID? = nil
    var per: Int = 1
    var extra: Int = 0
    var extraEvery: Int = 0

    /// `variableValue` is nil when the rule has no variable or the variable
    /// has been deleted; the fixed number is used then.
    func quantity(variableValue: Int?) -> Int {
        guard variableID != nil, let value = variableValue else { return fixed }
        var total = per * value
        if extra > 0 && extraEvery > 0 { total += extra * (value / extraEvery) }
        return max(total, 0)
    }
}

struct ListItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: String = ""
    var rule: QuantityRule = QuantityRule()
    var isDone: Bool = false
}

@Model
final class ItemList {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date = Date.now
    var variables: [ListVariable] = []
    var items: [ListItem] = []

    init(id: UUID = UUID(), name: String, createdAt: Date = .now,
         variables: [ListVariable] = [], items: [ListItem] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.variables = variables
        self.items = items
    }
}

extension ItemList {
    static let maxItems = 300
    static let maxVariables = 6
    static let otherCategory = "Other"

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled list" : name
    }

    var isBlank: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && items.isEmpty
    }

    var tickedCount: Int { items.filter(\.isDone).count }

    /// "12 items", or "5 of 12 ticked" once something is ticked. Never a
    /// percentage, and nothing changes when everything is ticked.
    var summaryText: String {
        let count = items.count == 1 ? "1 item" : "\(items.count) items"
        if items.isEmpty { return "No items yet" }
        return tickedCount == 0 ? count : "\(tickedCount) of \(items.count) ticked"
    }

    func variableValue(for id: UUID?) -> Int? {
        guard let id else { return nil }
        return variables.first { $0.id == id }?.value
    }

    func variableName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return variables.first { $0.id == id }?.name
    }

    func quantity(of item: ListItem) -> Int {
        item.rule.quantity(variableValue: variableValue(for: item.rule.variableID))
    }

    /// "x5", or "" for one, so a list of single things stays quiet.
    func quantityBadge(of item: ListItem) -> String {
        let quantity = quantity(of: item)
        return quantity == 1 ? "" : "\u{00D7}\(quantity)"
    }

    /// "1 per day + 1 extra for every 3", or "" for a fixed number.
    func ruleDescription(for item: ListItem) -> String {
        let rule = item.rule
        guard let name = variableName(for: rule.variableID) else { return "" }
        let label = name.trimmingCharacters(in: .whitespaces).lowercased()
        var text = "\(rule.per) per \(label.isEmpty ? "unit" : label)"
        if rule.extra > 0 && rule.extraEvery > 0 {
            text += " + \(rule.extra) extra for every \(rule.extraEvery)"
        }
        return text
    }

    /// Category names in the order they first appear, with items that have
    /// none gathered under "Other" at the end.
    var categoryNames: [String] {
        var seen: [String] = []
        for item in items {
            let name = Self.categoryName(for: item)
            if name != Self.otherCategory, !seen.contains(name) { seen.append(name) }
        }
        if items.contains(where: { Self.categoryName(for: $0) == Self.otherCategory }) { seen.append(Self.otherCategory) }
        return seen
    }

    static func categoryName(for item: ListItem) -> String {
        let trimmed = item.category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? otherCategory : trimmed
    }

    func items(in category: String) -> [ListItem] {
        items.filter { Self.categoryName(for: $0) == category }
    }

    /// Unticks everything, so the same list can be used again.
    func resetTicks() {
        for index in items.indices { items[index].isDone = false }
    }

    /// A new list with the same variables and items, all unticked, new ids so
    /// the copy's rules follow the copy's own variables.
    func copied(named newName: String) -> ItemList {
        var idMap: [UUID: UUID] = [:]
        let newVariables = variables.map { variable -> ListVariable in
            let fresh = ListVariable(name: variable.name, value: variable.value)
            idMap[variable.id] = fresh.id
            return fresh
        }
        let newItems = items.map { item -> ListItem in
            var rule = item.rule
            if let old = rule.variableID { rule.variableID = idMap[old] }
            return ListItem(name: item.name, category: item.category, rule: rule, isDone: false)
        }
        return ItemList(name: newName, variables: newVariables, items: newItems)
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
            SafetyPlan.self, SafetyPlanSection.self, BoundarySection.self, PersonSection.self, MessageStarter.self, PersonalGoal.self, TriggerWindow.self, AppointmentSeries.self, AppointmentOccurrence.self,
            BridgeDraftItem.self, FeedbackLoopDiagram.self,
            ThreadMessage.self, SupportCalendarEntry.self, FutureNote.self, UnsentDraft.self,
            MascotLine.self, DecisionPresetCategory.self, DecisionPresetChoice.self,
            DeEscalationScript.self, NextHourItem.self, TaskItem.self, Affirmation.self,
            RecoveryCounter.self, RecoveryMotivation.self, RecoveryDayEntry.self, RecoveryUrge.self,
            QuickList.self, Routine.self, ItemList.self
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
