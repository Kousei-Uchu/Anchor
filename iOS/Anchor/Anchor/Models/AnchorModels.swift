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
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil

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
        self.textPlain = text
        self.isFavorited = false
        self.linkedContext = linkedContext
        self.audioFileName = audioFileName
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension JournalEntry {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "JournalEntry.text") }
        set {
            let kept = FieldLock.store(newValue, context: "JournalEntry.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        textSealed != nil && textPlain.isEmpty
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
    @Attribute(originalName: "name") var namePlain: String
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    @Attribute(originalName: "phoneNumber") var phoneNumberPlain: String   // routes to native Messages, not a custom backend
    /// The locked form of `phoneNumber`, empty until locking is turned on. Read and written through `phoneNumber` only.
    var phoneNumberSealed: String? = nil
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

    @Attribute(originalName: "messageTemplates") var messageTemplatesPlain: [MessageTemplate]
    /// The locked form of `messageTemplates`, empty until locking is turned on. Read and written through `messageTemplates` only.
    var messageTemplatesSealed: String? = nil

    /// How reaching this person actually works. Phone (SMS/call) is the
    /// default and always available; Discord needs their numeric user ID
    /// — Discord's URL scheme can't resolve a DM from a username alone.
    var contactMethod: ContactMethod
    @Attribute(originalName: "discordUserID") var discordUserIDPlain: String?
    /// The locked form of `discordUserID`, empty until locking is turned on. Read and written through `discordUserID` only.
    var discordUserIDSealed: String? = nil

    /// Optional — powers the "who's awake" screen. All nil means "unknown,
    /// don't show a status for this person."
    var timeZoneIdentifier: String?
    var availableFromHour: Int?
    var availableFromMinute: Int?
    var availableToHour: Int?
    var availableToMinute: Int?

    /// An optional regular hello you set for this person. Off unless you switch it on.
    var helloEnabled: Bool = false
    /// Calendar weekdays it comes on, 1 = Sunday to 7 = Saturday.
    var helloDays: [Int] = []
    var helloHour: Int = 17
    var helloMinute: Int = 0

    /// An optional reminder for each day on the Support calendar that this person can see.
    /// Off unless you switch it on. False is the morning of the day, true is the day before.
    var supportDaysEnabled: Bool = false
    var supportDaysDayBefore: Bool = false

    /// An optional reminder at the start of a trigger window, to say this person is one option.
    /// Off unless you switch it on. It comes only for the windows listed here.
    var companionEnabled: Bool = false
    var companionWindowIDs: [UUID] = []

    init(id: UUID = UUID(), name: String, phoneNumber: String, sortOrder: Int,
         escalationEnabled: Bool = false, escalationWindowMinutes: Int? = nil,
         messageTemplates: [MessageTemplate] = [],
         contactMethod: ContactMethod = .phone, discordUserID: String? = nil,
         timeZoneIdentifier: String? = nil,
         availableFromHour: Int? = nil, availableFromMinute: Int? = nil,
         availableToHour: Int? = nil, availableToMinute: Int? = nil,
         helloEnabled: Bool = false, helloDays: [Int] = [],
         helloHour: Int = 17, helloMinute: Int = 0,
         supportDaysEnabled: Bool = false, supportDaysDayBefore: Bool = false,
         companionEnabled: Bool = false, companionWindowIDs: [UUID] = []) {
        self.id = id
        self.namePlain = name
        self.phoneNumberPlain = phoneNumber
        self.sortOrder = sortOrder
        self.escalationEnabled = escalationEnabled
        self.escalationWindowMinutes = escalationWindowMinutes
        self.messageTemplatesPlain = messageTemplates
        self.contactMethod = contactMethod
        self.discordUserIDPlain = discordUserID
        self.timeZoneIdentifier = timeZoneIdentifier
        self.availableFromHour = availableFromHour
        self.availableFromMinute = availableFromMinute
        self.availableToHour = availableToHour
        self.availableToMinute = availableToMinute
        self.helloEnabled = helloEnabled
        self.helloDays = helloDays
        self.helloHour = helloHour
        self.helloMinute = helloMinute
        self.supportDaysEnabled = supportDaysEnabled
        self.supportDaysDayBefore = supportDaysDayBefore
        self.companionEnabled = companionEnabled
        self.companionWindowIDs = companionWindowIDs
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension TrustedContact {
    var name: String {
        get { FieldLock.read(plain: namePlain, sealed: nameSealed, context: "TrustedContact.name") }
        set {
            let kept = FieldLock.store(newValue, context: "TrustedContact.name")
            namePlain = kept.plain
            nameSealed = kept.sealed
        }
    }
    var phoneNumber: String {
        get { FieldLock.read(plain: phoneNumberPlain, sealed: phoneNumberSealed, context: "TrustedContact.phoneNumber") }
        set {
            let kept = FieldLock.store(newValue, context: "TrustedContact.phoneNumber")
            phoneNumberPlain = kept.plain
            phoneNumberSealed = kept.sealed
        }
    }
    var messageTemplates: [MessageTemplate] {
        get { FieldLock.readCoded(messageTemplatesPlain, sealed: messageTemplatesSealed, context: "TrustedContact.messageTemplates") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "TrustedContact.messageTemplates")
            messageTemplatesPlain = kept.plain
            messageTemplatesSealed = kept.sealed
        }
    }
    var discordUserID: String? {
        get { FieldLock.readOptional(plain: discordUserIDPlain, sealed: discordUserIDSealed, context: "TrustedContact.discordUserID") }
        set {
            let kept = FieldLock.storeOptional(newValue, context: "TrustedContact.discordUserID")
            discordUserIDPlain = kept.plain
            discordUserIDSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        name = namePlain
        phoneNumber = phoneNumberPlain
        messageTemplates = messageTemplatesPlain
        discordUserID = discordUserIDPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if nameSealed == nil { name = namePlain }
        if phoneNumberSealed == nil { phoneNumber = phoneNumberPlain }
        if messageTemplatesSealed == nil { messageTemplates = messageTemplatesPlain }
        if discordUserIDSealed == nil, let kept = discordUserIDPlain { discordUserID = kept }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(name),
            FieldLock.describe(phoneNumber),
            FieldLock.describe(messageTemplates),
            FieldLock.describe(discordUserID)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        nameSealed != nil && namePlain.isEmpty
            && phoneNumberSealed != nil && phoneNumberPlain.isEmpty
            && messageTemplatesSealed != nil && messageTemplatesPlain.isEmpty
            && discordUserIDPlain == nil
    }
}

extension TrustedContact {
    /// "Sun at 5:00 PM", "Every day at 5:00 PM", or nil while the hello is off or has no days.
    var helloSummary: String? {
        guard helloEnabled else { return nil }
        let days = Set(helloDays.filter { (1...7).contains($0) })
        guard !days.isEmpty else { return nil }
        let calendar = Calendar.current
        var parts = DateComponents(); parts.hour = helloHour; parts.minute = helloMinute
        let time = calendar.date(from: parts)?.formatted(date: .omitted, time: .shortened) ?? ""
        if days.count == 7 { return "Every day at \(time)" }
        let names = calendar.shortWeekdaySymbols
        let ordered = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }.filter { days.contains($0) }
        return ordered.map { names[$0 - 1] }.joined(separator: ", ") + " at " + time
    }

    /// "1 trigger window" or "2 trigger windows", or nil while the hard-time reminder is off or has none.
    var companionSummary: String? {
        guard companionEnabled, !companionWindowIDs.isEmpty else { return nil }
        return companionWindowIDs.count == 1 ? "1 trigger window" : "\(companionWindowIDs.count) trigger windows"
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
    @Attribute(originalName: "title") var titlePlain: String
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    var kind: GroundingToolKind
    @Attribute(originalName: "steps") var stepsPlain: String?                 // for .physicalAction
    /// The locked form of `steps`, empty until locking is turned on. Read and written through `steps` only.
    var stepsSealed: String? = nil
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
        self.titlePlain = title
        self.kind = kind
        self.stepsPlain = steps
        self.deepLink = deepLink
        self.sortOrder = sortOrder
        self.relevantTimeWindows = relevantTimeWindows
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension GroundingTool {
    var title: String {
        get { FieldLock.read(plain: titlePlain, sealed: titleSealed, context: "GroundingTool.title") }
        set {
            let kept = FieldLock.store(newValue, context: "GroundingTool.title")
            titlePlain = kept.plain
            titleSealed = kept.sealed
        }
    }
    var steps: String? {
        get { FieldLock.readOptional(plain: stepsPlain, sealed: stepsSealed, context: "GroundingTool.steps") }
        set {
            let kept = FieldLock.storeOptional(newValue, context: "GroundingTool.steps")
            stepsPlain = kept.plain
            stepsSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        title = titlePlain
        steps = stepsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if titleSealed == nil { title = titlePlain }
        if stepsSealed == nil, let kept = stepsPlain { steps = kept }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(title),
            FieldLock.describe(steps)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        titleSealed != nil && titlePlain.isEmpty
            && stepsPlain == nil
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
    @Attribute(originalName: "warningSignsText") var warningSignsTextPlain: String
    /// The locked form of `warningSignsText`, empty until locking is turned on. Read and written through `warningSignsText` only.
    var warningSignsTextSealed: String? = nil
    @Attribute(originalName: "copingStrategiesText") var copingStrategiesTextPlain: String
    /// The locked form of `copingStrategiesText`, empty until locking is turned on. Read and written through `copingStrategiesText` only.
    var copingStrategiesTextSealed: String? = nil
    @Attribute(originalName: "reasonsToKeepGoingText") var reasonsToKeepGoingTextPlain: String   // source pool for templated notification quotes
    /// The locked form of `reasonsToKeepGoingText`, empty until locking is turned on. Read and written through `reasonsToKeepGoingText` only.
    var reasonsToKeepGoingTextSealed: String? = nil
    @Attribute(originalName: "environmentSafetyStepsText") var environmentSafetyStepsTextPlain: String
    /// The locked form of `environmentSafetyStepsText`, empty until locking is turned on. Read and written through `environmentSafetyStepsText` only.
    var environmentSafetyStepsTextSealed: String? = nil

    init(id: UUID = UUID(), lastEditedAt: Date = .now,
         warningSignsText: String = "", copingStrategiesText: String = "",
         reasonsToKeepGoingText: String = "", environmentSafetyStepsText: String = "") {
        self.id = id
        self.lastEditedAt = lastEditedAt
        self.warningSignsTextPlain = warningSignsText
        self.copingStrategiesTextPlain = copingStrategiesText
        self.reasonsToKeepGoingTextPlain = reasonsToKeepGoingText
        self.environmentSafetyStepsTextPlain = environmentSafetyStepsText
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension SafetyPlan {
    var warningSignsText: String {
        get { FieldLock.read(plain: warningSignsTextPlain, sealed: warningSignsTextSealed, context: "SafetyPlan.warningSignsText") }
        set {
            let kept = FieldLock.store(newValue, context: "SafetyPlan.warningSignsText")
            warningSignsTextPlain = kept.plain
            warningSignsTextSealed = kept.sealed
        }
    }
    var copingStrategiesText: String {
        get { FieldLock.read(plain: copingStrategiesTextPlain, sealed: copingStrategiesTextSealed, context: "SafetyPlan.copingStrategiesText") }
        set {
            let kept = FieldLock.store(newValue, context: "SafetyPlan.copingStrategiesText")
            copingStrategiesTextPlain = kept.plain
            copingStrategiesTextSealed = kept.sealed
        }
    }
    var reasonsToKeepGoingText: String {
        get { FieldLock.read(plain: reasonsToKeepGoingTextPlain, sealed: reasonsToKeepGoingTextSealed, context: "SafetyPlan.reasonsToKeepGoingText") }
        set {
            let kept = FieldLock.store(newValue, context: "SafetyPlan.reasonsToKeepGoingText")
            reasonsToKeepGoingTextPlain = kept.plain
            reasonsToKeepGoingTextSealed = kept.sealed
        }
    }
    var environmentSafetyStepsText: String {
        get { FieldLock.read(plain: environmentSafetyStepsTextPlain, sealed: environmentSafetyStepsTextSealed, context: "SafetyPlan.environmentSafetyStepsText") }
        set {
            let kept = FieldLock.store(newValue, context: "SafetyPlan.environmentSafetyStepsText")
            environmentSafetyStepsTextPlain = kept.plain
            environmentSafetyStepsTextSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        warningSignsText = warningSignsTextPlain
        copingStrategiesText = copingStrategiesTextPlain
        reasonsToKeepGoingText = reasonsToKeepGoingTextPlain
        environmentSafetyStepsText = environmentSafetyStepsTextPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if warningSignsTextSealed == nil { warningSignsText = warningSignsTextPlain }
        if copingStrategiesTextSealed == nil { copingStrategiesText = copingStrategiesTextPlain }
        if reasonsToKeepGoingTextSealed == nil { reasonsToKeepGoingText = reasonsToKeepGoingTextPlain }
        if environmentSafetyStepsTextSealed == nil { environmentSafetyStepsText = environmentSafetyStepsTextPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(warningSignsText),
            FieldLock.describe(copingStrategiesText),
            FieldLock.describe(reasonsToKeepGoingText),
            FieldLock.describe(environmentSafetyStepsText)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        warningSignsTextSealed != nil && warningSignsTextPlain.isEmpty
            && copingStrategiesTextSealed != nil && copingStrategiesTextPlain.isEmpty
            && reasonsToKeepGoingTextSealed != nil && reasonsToKeepGoingTextPlain.isEmpty
            && environmentSafetyStepsTextSealed != nil && environmentSafetyStepsTextPlain.isEmpty
    }
}

/// One section of the safety plan: a title, the person's own words, and how
/// it looks. Sections can be renamed, reordered, added, hidden and removed.
/// The four text fields on `SafetyPlan` are the older form: they are copied
/// into sections once, never changed afterwards, and no longer read.
@Model
final class SafetyPlanSection {
    @Attribute(.unique) var id: UUID
    @Attribute(originalName: "title") var titlePlain: String
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
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
        self.titlePlain = title
        self.textPlain = text
        self.iconName = iconName
        self.tintName = tintName
        self.sortOrder = sortOrder
        self.isHidden = isHidden
        self.role = role
        self.lastEditedAt = lastEditedAt
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension SafetyPlanSection {
    var title: String {
        get { FieldLock.read(plain: titlePlain, sealed: titleSealed, context: "SafetyPlanSection.title") }
        set {
            let kept = FieldLock.store(newValue, context: "SafetyPlanSection.title")
            titlePlain = kept.plain
            titleSealed = kept.sealed
        }
    }
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "SafetyPlanSection.text") }
        set {
            let kept = FieldLock.store(newValue, context: "SafetyPlanSection.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        title = titlePlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if titleSealed == nil { title = titlePlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(title),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        titleSealed != nil && titlePlain.isEmpty
            && textSealed != nil && textPlain.isEmpty
    }
}

/// One section of the Boundaries list: things the person would like others to
/// know, what helps, what does not. The same shape as a safety plan section
/// plus a flag saying whether it may be shared when they choose to share the
/// list. Nothing is shared unless they do it themselves.
@Model
final class BoundarySection {
    @Attribute(.unique) var id: UUID
    @Attribute(originalName: "title") var titlePlain: String
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
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
        self.titlePlain = title
        self.textPlain = text
        self.iconName = iconName
        self.tintName = tintName
        self.sortOrder = sortOrder
        self.isHidden = isHidden
        self.isShareable = isShareable
        self.lastEditedAt = lastEditedAt
        lockNewValues()
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

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension BoundarySection {
    var title: String {
        get { FieldLock.read(plain: titlePlain, sealed: titleSealed, context: "BoundarySection.title") }
        set {
            let kept = FieldLock.store(newValue, context: "BoundarySection.title")
            titlePlain = kept.plain
            titleSealed = kept.sealed
        }
    }
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "BoundarySection.text") }
        set {
            let kept = FieldLock.store(newValue, context: "BoundarySection.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        title = titlePlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if titleSealed == nil { title = titlePlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(title),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        titleSealed != nil && titlePlain.isEmpty
            && textSealed != nil && textPlain.isEmpty
    }
}

/// One night in the sleep journal. A quiet record and nothing more: there is
/// no score, no target, no streak and no word for a "bad" night. Every field
/// is optional or defaulted, so a night can hold just a note, or just a time.
@Model
final class SleepEntry {
    @Attribute(.unique) var id: UUID
    /// The night this belongs to, as the start of the day you woke up on.
    var nightDate: Date
    var bedTime: Date? = nil
    var wakeTime: Date? = nil
    /// Time asleep, in minutes, when it was typed. Nil means it is worked out
    /// from the two times, if both are there.
    var minutesAsleep: Int? = nil
    /// Which of the three feel words, 0 to 2. Nil means nothing was chosen.
    var feel: Int? = nil
    @Attribute(originalName: "note") var notePlain: String = ""
    /// The locked form of `note`, empty until locking is turned on. Read and written through `note` only.
    var noteSealed: String? = nil
    /// "typed" for now. Later versions may add other sources.
    var sourceRaw: String = "typed"
    /// For a night that came from somewhere else, that source's own id, so
    /// the same night is never added twice. Nil for typed nights.
    var externalID: String? = nil
    var createdAt: Date = Date.now
    var lastEditedAt: Date = Date.now

    init(id: UUID = UUID(), nightDate: Date = Calendar.current.startOfDay(for: .now),
         bedTime: Date? = nil, wakeTime: Date? = nil, minutesAsleep: Int? = nil,
         feel: Int? = nil, note: String = "", sourceRaw: String = "typed",
         externalID: String? = nil, createdAt: Date = .now, lastEditedAt: Date = .now) {
        self.id = id
        self.nightDate = nightDate
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.minutesAsleep = minutesAsleep
        self.feel = feel
        self.notePlain = note
        self.sourceRaw = sourceRaw
        self.externalID = externalID
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
        lockNewValues()
    }

    /// Minutes between going to bed and waking, when both are known and make sense.
    var minutesInBed: Int? {
        guard let bedTime, let wakeTime, wakeTime > bedTime else { return nil }
        let minutes = Int(wakeTime.timeIntervalSince(bedTime) / 60)
        return minutes <= 24 * 60 ? minutes : nil
    }

    /// What is shown as time asleep: what was typed, else worked out from the times.
    var shownMinutes: Int? { minutesAsleep ?? minutesInBed }

    /// True when there is nothing in it at all, so it can be dropped again.
    var isBlank: Bool {
        bedTime == nil && wakeTime == nil && minutesAsleep == nil && feel == nil
            && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// "7 h 30 min", "8 h" or "45 min".
    static func describe(minutes: Int) -> String {
        let hours = minutes / 60, mins = minutes % 60
        if hours == 0 { return "\(mins) min" }
        return mins == 0 ? "\(hours) h" : "\(hours) h \(mins) min"
    }

    /// The moment with this clock time that comes last before `wake`, so a
    /// 11:30 pm bedtime for a morning wake is the evening before.
    static func bedMoment(clock: Date, night: Date, wake: Date?) -> Date {
        let cal = Calendar.current
        let parts = cal.dateComponents([.hour, .minute], from: clock)
        let reference = wake ?? cal.date(byAdding: .hour, value: 8, to: night) ?? night
        var candidate = cal.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: reference) ?? reference
        if candidate >= reference { candidate = cal.date(byAdding: .day, value: -1, to: candidate) ?? candidate }
        return candidate
    }

    /// The wake time on the morning of `night`.
    static func wakeMoment(clock: Date, night: Date) -> Date {
        let cal = Calendar.current
        let parts = cal.dateComponents([.hour, .minute], from: clock)
        return cal.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: night) ?? night
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension SleepEntry {
    var note: String {
        get { FieldLock.read(plain: notePlain, sealed: noteSealed, context: "SleepEntry.note") }
        set {
            let kept = FieldLock.store(newValue, context: "SleepEntry.note")
            notePlain = kept.plain
            noteSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        note = notePlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if noteSealed == nil { note = notePlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(note)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        noteSealed != nil && notePlain.isEmpty
    }
}

/// The three words for how a night felt. They start as plain, neutral words
/// and the person can rename them. Nothing is coloured or ranked.
enum SleepFeelWords {
    static let storageKey = "sleepFeelWords"
    static let defaults = ["Rested", "So-so", "Tired"]

    /// Three words from the saved text (separated by a bar), falling back to
    /// the default for any left empty.
    static func words(from raw: String) -> [String] {
        let saved = raw.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (0..<3).map { index in
            index < saved.count && !saved[index].isEmpty ? saved[index] : defaults[index]
        }
    }

    static func encode(_ words: [String]) -> String {
        words.map { $0.replacingOccurrences(of: "|", with: " ") }.joined(separator: "|")
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
    @Attribute(originalName: "title") var titlePlain: String
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
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
        self.titlePlain = title
        self.textPlain = text
        self.iconName = iconName
        self.tintName = tintName
        self.sortOrder = sortOrder
        self.isHidden = isHidden
        self.lastEditedAt = lastEditedAt
        lockNewValues()
    }

    /// Removes every section on one person's page. Called when the person is
    /// deleted, so nothing is left behind that can no longer be seen.
    static func removeAll(for contactID: UUID, in context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<PersonSection>()) else { return }
        for section in all where section.contactID == contactID { context.delete(section) }
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension PersonSection {
    var title: String {
        get { FieldLock.read(plain: titlePlain, sealed: titleSealed, context: "PersonSection.title") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonSection.title")
            titlePlain = kept.plain
            titleSealed = kept.sealed
        }
    }
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "PersonSection.text") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonSection.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        title = titlePlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if titleSealed == nil { title = titlePlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(title),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        titleSealed != nil && titlePlain.isEmpty
            && textSealed != nil && textPlain.isEmpty
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
    @Attribute(originalName: "title") var titlePlain: String
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "why") var whyPlain: String = ""
    /// The locked form of `why`, empty until locking is turned on. Read and written through `why` only.
    var whySealed: String? = nil
    var statusRaw: String = "active"
    @Attribute(originalName: "notes") var notesPlain: [GoalNote] = []
    /// The locked form of `notes`, empty until locking is turned on. Read and written through `notes` only.
    var notesSealed: String? = nil
    var sortOrder: Int = 0
    var createdAt: Date = Date.now
    var lastEditedAt: Date = Date.now
    /// An optional frame some people find useful, off unless switched on for a goal. Every part can stay
    /// blank. Nothing here is required, scored or dated. "Relevant" is the goal's own `why`, so it is not
    /// stored twice, and Time-bound is the person's own words, never a date that can pass.
    var usesSMART: Bool = false
    @Attribute(originalName: "smartSpecific") var smartSpecificPlain: String = ""
    /// The locked form of `smartSpecific`, empty until locking is turned on. Read and written through `smartSpecific` only.
    var smartSpecificSealed: String? = nil
    @Attribute(originalName: "smartMeasurable") var smartMeasurablePlain: String = ""
    /// The locked form of `smartMeasurable`, empty until locking is turned on. Read and written through `smartMeasurable` only.
    var smartMeasurableSealed: String? = nil
    @Attribute(originalName: "smartAchievable") var smartAchievablePlain: String = ""
    /// The locked form of `smartAchievable`, empty until locking is turned on. Read and written through `smartAchievable` only.
    var smartAchievableSealed: String? = nil
    @Attribute(originalName: "smartTimeBound") var smartTimeBoundPlain: String = ""
    /// The locked form of `smartTimeBound`, empty until locking is turned on. Read and written through `smartTimeBound` only.
    var smartTimeBoundSealed: String? = nil

    init(id: UUID = UUID(), title: String = "", why: String = "", status: GoalStatus = .active,
         notes: [GoalNote] = [], sortOrder: Int = 0, createdAt: Date = .now, lastEditedAt: Date = .now,
         usesSMART: Bool = false, smartSpecific: String = "", smartMeasurable: String = "",
         smartAchievable: String = "", smartTimeBound: String = "") {
        self.id = id
        self.titlePlain = title
        self.whyPlain = why
        self.statusRaw = status.rawValue
        self.notesPlain = notes
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.lastEditedAt = lastEditedAt
        self.usesSMART = usesSMART
        self.smartSpecificPlain = smartSpecific
        self.smartMeasurablePlain = smartMeasurable
        self.smartAchievablePlain = smartAchievable
        self.smartTimeBoundPlain = smartTimeBound
        lockNewValues()
    }

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension PersonalGoal {
    var title: String {
        get { FieldLock.read(plain: titlePlain, sealed: titleSealed, context: "PersonalGoal.title") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonalGoal.title")
            titlePlain = kept.plain
            titleSealed = kept.sealed
        }
    }
    var why: String {
        get { FieldLock.read(plain: whyPlain, sealed: whySealed, context: "PersonalGoal.why") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonalGoal.why")
            whyPlain = kept.plain
            whySealed = kept.sealed
        }
    }
    var notes: [GoalNote] {
        get { FieldLock.readCoded(notesPlain, sealed: notesSealed, context: "PersonalGoal.notes") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "PersonalGoal.notes")
            notesPlain = kept.plain
            notesSealed = kept.sealed
        }
    }
    var smartSpecific: String {
        get { FieldLock.read(plain: smartSpecificPlain, sealed: smartSpecificSealed, context: "PersonalGoal.smartSpecific") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonalGoal.smartSpecific")
            smartSpecificPlain = kept.plain
            smartSpecificSealed = kept.sealed
        }
    }
    var smartMeasurable: String {
        get { FieldLock.read(plain: smartMeasurablePlain, sealed: smartMeasurableSealed, context: "PersonalGoal.smartMeasurable") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonalGoal.smartMeasurable")
            smartMeasurablePlain = kept.plain
            smartMeasurableSealed = kept.sealed
        }
    }
    var smartAchievable: String {
        get { FieldLock.read(plain: smartAchievablePlain, sealed: smartAchievableSealed, context: "PersonalGoal.smartAchievable") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonalGoal.smartAchievable")
            smartAchievablePlain = kept.plain
            smartAchievableSealed = kept.sealed
        }
    }
    var smartTimeBound: String {
        get { FieldLock.read(plain: smartTimeBoundPlain, sealed: smartTimeBoundSealed, context: "PersonalGoal.smartTimeBound") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonalGoal.smartTimeBound")
            smartTimeBoundPlain = kept.plain
            smartTimeBoundSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        title = titlePlain
        why = whyPlain
        notes = notesPlain
        smartSpecific = smartSpecificPlain
        smartMeasurable = smartMeasurablePlain
        smartAchievable = smartAchievablePlain
        smartTimeBound = smartTimeBoundPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if titleSealed == nil { title = titlePlain }
        if whySealed == nil { why = whyPlain }
        if notesSealed == nil { notes = notesPlain }
        if smartSpecificSealed == nil { smartSpecific = smartSpecificPlain }
        if smartMeasurableSealed == nil { smartMeasurable = smartMeasurablePlain }
        if smartAchievableSealed == nil { smartAchievable = smartAchievablePlain }
        if smartTimeBoundSealed == nil { smartTimeBound = smartTimeBoundPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(title),
            FieldLock.describe(why),
            FieldLock.describe(notes),
            FieldLock.describe(smartSpecific),
            FieldLock.describe(smartMeasurable),
            FieldLock.describe(smartAchievable),
            FieldLock.describe(smartTimeBound)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        titleSealed != nil && titlePlain.isEmpty
            && whySealed != nil && whyPlain.isEmpty
            && notesSealed != nil && notesPlain.isEmpty
            && smartSpecificSealed != nil && smartSpecificPlain.isEmpty
            && smartMeasurableSealed != nil && smartMeasurablePlain.isEmpty
            && smartAchievableSealed != nil && smartAchievablePlain.isEmpty
            && smartTimeBoundSealed != nil && smartTimeBoundPlain.isEmpty
    }
}

/// One of the person's own short lines for starting a message on a hard day,
/// such as "I'm not up to talking, but I'm safe". Nothing is written for them:
/// the list starts empty. Tapping one puts it in the message box, where it can
/// be changed before anything is saved or sent.
@Model
final class MessageStarter {
    @Attribute(.unique) var id: UUID
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var sortOrder: Int
    var lastEditedAt: Date

    init(id: UUID = UUID(), text: String = "", sortOrder: Int = 0, lastEditedAt: Date = .now) {
        self.id = id
        self.textPlain = text
        self.sortOrder = sortOrder
        self.lastEditedAt = lastEditedAt
        lockNewValues()
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

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension MessageStarter {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "MessageStarter.text") }
        set {
            let kept = FieldLock.store(newValue, context: "MessageStarter.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        textSealed != nil && textPlain.isEmpty
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
    @Attribute(originalName: "label") var labelPlain: String
    /// The locked form of `label`, empty until locking is turned on. Read and written through `label` only.
    var labelSealed: String? = nil
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
        self.labelPlain = label
        self.daysOfWeek = daysOfWeek

        self.startHour = startTime.hour ?? 0
        self.startMinute = startTime.minute ?? 0
        self.endHour = endTime.hour ?? 0
        self.endMinute = endTime.minute ?? 0

        self.isActive = isActive
        lockNewValues()
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

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension TriggerWindow {
    var label: String {
        get { FieldLock.read(plain: labelPlain, sealed: labelSealed, context: "TriggerWindow.label") }
        set {
            let kept = FieldLock.store(newValue, context: "TriggerWindow.label")
            labelPlain = kept.plain
            labelSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        label = labelPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if labelSealed == nil { label = labelPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(label)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        labelSealed != nil && labelPlain.isEmpty
    }
}

/// Appointments are a recurring RULE (e.g. "usually Tuesdays 4pm") plus
/// individually-editable occurrences, because real life moves sessions
/// around. Never a hardcoded fixed interval.
@Model
final class AppointmentSeries {
    @Attribute(.unique) var id: UUID
    @Attribute(originalName: "clinicianLabel") var clinicianLabelPlain: String
    /// The locked form of `clinicianLabel`, empty until locking is turned on. Read and written through `clinicianLabel` only.
    var clinicianLabelSealed: String? = nil
    var typicalDayOfWeek: Int?

    // Stored separately because DateComponents contains Calendar internally.
    var typicalHour: Int?
    var typicalMinute: Int?

    var typicalCadenceDays: Int

    /// What they do, in the person's own words ("GP", "Counsellor"). Optional.
    @Attribute(originalName: "role") var rolePlain: String = ""
    /// The locked form of `role`, empty until locking is turned on. Read and written through `role` only.
    var roleSealed: String? = nil
    /// The name used on anything exported or shared. Empty means the name as shown.
    @Attribute(originalName: "exportLabel") var exportLabelPlain: String = ""
    /// The locked form of `exportLabel`, empty until locking is turned on. Read and written through `exportLabel` only.
    var exportLabelSealed: String? = nil
    /// Anything the person wants to remember about them, in their own words.
    @Attribute(originalName: "notes") var notesPlain: String = ""
    /// The locked form of `notes`, empty until locking is turned on. Read and written through `notes` only.
    var notesSealed: String? = nil
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
        self.clinicianLabelPlain = clinicianLabel
        self.typicalDayOfWeek = typicalDayOfWeek

        self.typicalHour = typicalTime?.hour
        self.typicalMinute = typicalTime?.minute

        self.typicalCadenceDays = typicalCadenceDays
        self.occurrences = occurrences
        self.rolePlain = role
        self.exportLabelPlain = exportLabel
        self.notesPlain = notes
        self.sortOrder = sortOrder
        lockNewValues()
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

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension AppointmentSeries {
    var clinicianLabel: String {
        get { FieldLock.read(plain: clinicianLabelPlain, sealed: clinicianLabelSealed, context: "AppointmentSeries.clinicianLabel") }
        set {
            let kept = FieldLock.store(newValue, context: "AppointmentSeries.clinicianLabel")
            clinicianLabelPlain = kept.plain
            clinicianLabelSealed = kept.sealed
        }
    }
    var role: String {
        get { FieldLock.read(plain: rolePlain, sealed: roleSealed, context: "AppointmentSeries.role") }
        set {
            let kept = FieldLock.store(newValue, context: "AppointmentSeries.role")
            rolePlain = kept.plain
            roleSealed = kept.sealed
        }
    }
    var exportLabel: String {
        get { FieldLock.read(plain: exportLabelPlain, sealed: exportLabelSealed, context: "AppointmentSeries.exportLabel") }
        set {
            let kept = FieldLock.store(newValue, context: "AppointmentSeries.exportLabel")
            exportLabelPlain = kept.plain
            exportLabelSealed = kept.sealed
        }
    }
    var notes: String {
        get { FieldLock.read(plain: notesPlain, sealed: notesSealed, context: "AppointmentSeries.notes") }
        set {
            let kept = FieldLock.store(newValue, context: "AppointmentSeries.notes")
            notesPlain = kept.plain
            notesSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        clinicianLabel = clinicianLabelPlain
        role = rolePlain
        exportLabel = exportLabelPlain
        notes = notesPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if clinicianLabelSealed == nil { clinicianLabel = clinicianLabelPlain }
        if roleSealed == nil { role = rolePlain }
        if exportLabelSealed == nil { exportLabel = exportLabelPlain }
        if notesSealed == nil { notes = notesPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(clinicianLabel),
            FieldLock.describe(role),
            FieldLock.describe(exportLabel),
            FieldLock.describe(notes)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        clinicianLabelSealed != nil && clinicianLabelPlain.isEmpty
            && roleSealed != nil && rolePlain.isEmpty
            && exportLabelSealed != nil && exportLabelPlain.isEmpty
            && notesSealed != nil && notesPlain.isEmpty
    }
}

@Model
final class AppointmentOccurrence {
    @Attribute(.unique) var id: UUID
    var scheduledDate: Date       // editable independent of the series rule
    var wasMoved: Bool
    var prepNoteEntryID: UUID?    // links to a Journal/Bridge prep entry
    var postSessionNoteEntryID: UUID?
    /// What the person wants to have with them for this one session, written
    /// and ticked by them. It reuses the small text-and-tick value that quick
    /// lists use, kept inside the occurrence so there is no new record.
    @Attribute(originalName: "prepChecklist") var prepChecklistPlain: [QuickListItem] = []
    /// The locked form of `prepChecklist`, empty until locking is turned on. Read and written through `prepChecklist` only.
    var prepChecklistSealed: String? = nil

    init(id: UUID = UUID(), scheduledDate: Date, wasMoved: Bool = false,
         prepNoteEntryID: UUID? = nil, postSessionNoteEntryID: UUID? = nil,
         prepChecklist: [QuickListItem] = []) {
        self.id = id
        self.scheduledDate = scheduledDate
        self.wasMoved = wasMoved
        self.prepNoteEntryID = prepNoteEntryID
        self.postSessionNoteEntryID = postSessionNoteEntryID
        self.prepChecklistPlain = prepChecklist
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension AppointmentOccurrence {
    var prepChecklist: [QuickListItem] {
        get { FieldLock.readCoded(prepChecklistPlain, sealed: prepChecklistSealed, context: "AppointmentOccurrence.prepChecklist") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "AppointmentOccurrence.prepChecklist")
            prepChecklistPlain = kept.plain
            prepChecklistSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        prepChecklist = prepChecklistPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if prepChecklistSealed == nil { prepChecklist = prepChecklistPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(prepChecklist)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        prepChecklistSealed != nil && prepChecklistPlain.isEmpty
    }
}

// MARK: - Bridge

@Model
final class BridgeDraftItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var isResolved: Bool   // "brought this up already" — not a score, just a checkbox
    /// True when the item is a question to ask rather than something to raise.
    var isQuestion: Bool = false
    /// What was said in answer, written by the person after the session.
    /// Only used when the item is a question.
    @Attribute(originalName: "answer") var answerPlain: String = ""
    /// The locked form of `answer`, empty until locking is turned on. Read and written through `answer` only.
    var answerSealed: String? = nil
    /// The provider (an `AppointmentSeries` id) this is for. Nil means it is
    /// for anyone. Kept as a plain id rather than a relationship, so removing
    /// a provider can never remove an item.
    var providerID: UUID? = nil

    init(id: UUID = UUID(), createdAt: Date = .now, text: String, isResolved: Bool = false,
         isQuestion: Bool = false, answer: String = "", providerID: UUID? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.textPlain = text
        self.isResolved = isResolved
        self.isQuestion = isQuestion
        self.answerPlain = answer
        self.providerID = providerID
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension BridgeDraftItem {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "BridgeDraftItem.text") }
        set {
            let kept = FieldLock.store(newValue, context: "BridgeDraftItem.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }
    var answer: String {
        get { FieldLock.read(plain: answerPlain, sealed: answerSealed, context: "BridgeDraftItem.answer") }
        set {
            let kept = FieldLock.store(newValue, context: "BridgeDraftItem.answer")
            answerPlain = kept.plain
            answerSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        text = textPlain
        answer = answerPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if textSealed == nil { text = textPlain }
        if answerSealed == nil { answer = answerPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(text),
            FieldLock.describe(answer)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        textSealed != nil && textPlain.isEmpty
            && answerSealed != nil && answerPlain.isEmpty
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
    @Attribute(originalName: "title") var titlePlain: String
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    var lastEditedAt: Date
    /// Serialized node/edge graph the user builds to externalize their own
    /// systems metaphors (e.g. the "like Cloudflare" defense model). Stored
    /// as JSON so the diagram editor can be swapped out without migrating data.
    @Attribute(originalName: "graphJSON") var graphJSONPlain: Data
    /// The locked form of `graphJSON`, empty until locking is turned on. Read and written through `graphJSON` only.
    var graphJSONSealed: String? = nil

    init(id: UUID = UUID(), title: String, lastEditedAt: Date = .now, graphJSON: Data) {
        self.id = id
        self.titlePlain = title
        self.lastEditedAt = lastEditedAt
        self.graphJSONPlain = graphJSON
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension FeedbackLoopDiagram {
    var title: String {
        get { FieldLock.read(plain: titlePlain, sealed: titleSealed, context: "FeedbackLoopDiagram.title") }
        set {
            let kept = FieldLock.store(newValue, context: "FeedbackLoopDiagram.title")
            titlePlain = kept.plain
            titleSealed = kept.sealed
        }
    }
    var graphJSON: Data {
        get { FieldLock.readData(graphJSONPlain, sealed: graphJSONSealed, context: "FeedbackLoopDiagram.graphJSON") }
        set {
            let kept = FieldLock.storeData(newValue, context: "FeedbackLoopDiagram.graphJSON")
            graphJSONPlain = kept.plain
            graphJSONSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        title = titlePlain
        graphJSON = graphJSONPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if titleSealed == nil { title = titlePlain }
        if graphJSONSealed == nil { graphJSON = graphJSONPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(title),
            FieldLock.describe(graphJSON)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        titleSealed != nil && titlePlain.isEmpty
            && graphJSONSealed != nil && graphJSONPlain.isEmpty
    }
}

// MARK: - Thread

@Model
final class ThreadMessage {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var audioFileName: String?
    var withContactID: UUID?
    /// The day a follow-up reminder was asked for when this was written and sent, as the start of
    /// that day. Empty unless the person chose one. Nothing is inferred and nothing sets it by itself.
    var followUpAt: Date?

    init(id: UUID = UUID(), timestamp: Date = .now, text: String,
         audioFileName: String? = nil, withContactID: UUID? = nil, followUpAt: Date? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.textPlain = text
        self.audioFileName = audioFileName
        self.withContactID = withContactID
        self.followUpAt = followUpAt
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension ThreadMessage {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "ThreadMessage.text") }
        set {
            let kept = FieldLock.store(newValue, context: "ThreadMessage.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        textSealed != nil && textPlain.isEmpty
    }
}

@Model
final class SupportCalendarEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    @Attribute(originalName: "note") var notePlain: String
    /// The locked form of `note`, empty until locking is turned on. Read and written through `note` only.
    var noteSealed: String? = nil
    var visibleToContactIDs: [UUID]   // explicit opt-in list, not "everyone"

    init(id: UUID = UUID(), date: Date, note: String, visibleToContactIDs: [UUID] = []) {
        self.id = id
        self.date = date
        self.notePlain = note
        self.visibleToContactIDs = visibleToContactIDs
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension SupportCalendarEntry {
    var note: String {
        get { FieldLock.read(plain: notePlain, sealed: noteSealed, context: "SupportCalendarEntry.note") }
        set {
            let kept = FieldLock.store(newValue, context: "SupportCalendarEntry.note")
            notePlain = kept.plain
            noteSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        note = notePlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if noteSealed == nil { note = notePlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(note)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        noteSealed != nil && notePlain.isEmpty
    }
}

@Model
final class FutureNote {
    @Attribute(.unique) var id: UUID
    var writtenAt: Date
    var unlockDate: Date
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var isUnlocked: Bool   // derived at read-time from unlockDate, cached here for widget/UI convenience
    /// What the person wrote after "Open when", for a letter they open when
    /// they choose. Empty for a note sealed until a date. A letter has no
    /// date to wait for, and nothing opens it, counts it or reminds them of it.
    @Attribute(originalName: "openWhen") var openWhenPlain: String = ""
    /// The locked form of `openWhen`, empty until locking is turned on. Read and written through `openWhen` only.
    var openWhenSealed: String? = nil

    init(id: UUID = UUID(), writtenAt: Date = .now, unlockDate: Date, text: String, openWhen: String = "") {
        self.id = id
        self.writtenAt = writtenAt
        self.unlockDate = unlockDate
        self.textPlain = text
        self.isUnlocked = false
        self.openWhenPlain = openWhen
        lockNewValues()
    }

    var isOpenWhenLetter: Bool {
        !openWhen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension FutureNote {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "FutureNote.text") }
        set {
            let kept = FieldLock.store(newValue, context: "FutureNote.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }
    var openWhen: String {
        get { FieldLock.read(plain: openWhenPlain, sealed: openWhenSealed, context: "FutureNote.openWhen") }
        set {
            let kept = FieldLock.store(newValue, context: "FutureNote.openWhen")
            openWhenPlain = kept.plain
            openWhenSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        text = textPlain
        openWhen = openWhenPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if textSealed == nil { text = textPlain }
        if openWhenSealed == nil { openWhen = openWhenPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(text),
            FieldLock.describe(openWhen)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        textSealed != nil && textPlain.isEmpty
            && openWhenSealed != nil && openWhenPlain.isEmpty
    }
}

@Model
final class UnsentDraft {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    @Attribute(originalName: "recipientLabel") var recipientLabelPlain: String   // "partner", "school friend", etc — no full identity required
    /// The locked form of `recipientLabel`, empty until locking is turned on. Read and written through `recipientLabel` only.
    var recipientLabelSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var wasSent: Bool

    init(id: UUID = UUID(), createdAt: Date = .now, recipientLabel: String, text: String, wasSent: Bool = false) {
        self.id = id
        self.createdAt = createdAt
        self.recipientLabelPlain = recipientLabel
        self.textPlain = text
        self.wasSent = wasSent
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension UnsentDraft {
    var recipientLabel: String {
        get { FieldLock.read(plain: recipientLabelPlain, sealed: recipientLabelSealed, context: "UnsentDraft.recipientLabel") }
        set {
            let kept = FieldLock.store(newValue, context: "UnsentDraft.recipientLabel")
            recipientLabelPlain = kept.plain
            recipientLabelSealed = kept.sealed
        }
    }
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "UnsentDraft.text") }
        set {
            let kept = FieldLock.store(newValue, context: "UnsentDraft.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        recipientLabel = recipientLabelPlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if recipientLabelSealed == nil { recipientLabel = recipientLabelPlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(recipientLabel),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        recipientLabelSealed != nil && recipientLabelPlain.isEmpty
            && textSealed != nil && textPlain.isEmpty
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
    @Attribute(originalName: "name") var namePlain: String
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    var sortOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \DecisionPresetChoice.category)
    var choices: [DecisionPresetChoice]

    init(id: UUID = UUID(), name: String, sortOrder: Int = 0, choices: [DecisionPresetChoice] = []) {
        self.id = id
        self.namePlain = name
        self.sortOrder = sortOrder
        self.choices = choices
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension DecisionPresetCategory {
    var name: String {
        get { FieldLock.read(plain: namePlain, sealed: nameSealed, context: "DecisionPresetCategory.name") }
        set {
            let kept = FieldLock.store(newValue, context: "DecisionPresetCategory.name")
            namePlain = kept.plain
            nameSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        name = namePlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if nameSealed == nil { name = namePlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(name)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        nameSealed != nil && namePlain.isEmpty
    }
}

@Model
final class DecisionPresetChoice {
    @Attribute(.unique) var id: UUID
    @Attribute(originalName: "name") var namePlain: String
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    /// One step per line, same convention as GroundingTool.steps. Empty
    /// means this is just a flat option with no click-through sequence.
    @Attribute(originalName: "steps") var stepsPlain: String
    /// The locked form of `steps`, empty until locking is turned on. Read and written through `steps` only.
    var stepsSealed: String? = nil
    var sortOrder: Int
    var category: DecisionPresetCategory?

    init(id: UUID = UUID(), name: String, steps: String = "", sortOrder: Int = 0, category: DecisionPresetCategory? = nil) {
        self.id = id
        self.namePlain = name
        self.stepsPlain = steps
        self.sortOrder = sortOrder
        self.category = category
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension DecisionPresetChoice {
    var name: String {
        get { FieldLock.read(plain: namePlain, sealed: nameSealed, context: "DecisionPresetChoice.name") }
        set {
            let kept = FieldLock.store(newValue, context: "DecisionPresetChoice.name")
            namePlain = kept.plain
            nameSealed = kept.sealed
        }
    }
    var steps: String {
        get { FieldLock.read(plain: stepsPlain, sealed: stepsSealed, context: "DecisionPresetChoice.steps") }
        set {
            let kept = FieldLock.store(newValue, context: "DecisionPresetChoice.steps")
            stepsPlain = kept.plain
            stepsSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        name = namePlain
        steps = stepsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if nameSealed == nil { name = namePlain }
        if stepsSealed == nil { steps = stepsPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(name),
            FieldLock.describe(steps)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        nameSealed != nil && namePlain.isEmpty
            && stepsSealed != nil && stepsPlain.isEmpty
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
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var sortOrder: Int

    init(id: UUID = UUID(), text: String, sortOrder: Int = 0) {
        self.id = id
        self.textPlain = text
        self.sortOrder = sortOrder
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension DeEscalationScript {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "DeEscalationScript.text") }
        set {
            let kept = FieldLock.store(newValue, context: "DeEscalationScript.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        textSealed != nil && textPlain.isEmpty
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
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var sortOrder: Int

    init(id: UUID = UUID(), text: String, sortOrder: Int = 0) {
        self.id = id
        self.textPlain = text
        self.sortOrder = sortOrder
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension Affirmation {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "Affirmation.text") }
        set {
            let kept = FieldLock.store(newValue, context: "Affirmation.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        textSealed != nil && textPlain.isEmpty
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
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var isDone: Bool
    var createdAt: Date
    var reminderIdentifier: String?

    init(id: UUID = UUID(), text: String, isDone: Bool = false, createdAt: Date = .now, reminderIdentifier: String? = nil) {
        self.id = id
        self.textPlain = text
        self.isDone = isDone
        self.createdAt = createdAt
        self.reminderIdentifier = reminderIdentifier
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension NextHourItem {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "NextHourItem.text") }
        set {
            let kept = FieldLock.store(newValue, context: "NextHourItem.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        textSealed != nil && textPlain.isEmpty
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
    @Attribute(originalName: "title") var titlePlain: String
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "notes") var notesPlain: String = ""
    /// The locked form of `notes`, empty until locking is turned on. Read and written through `notes` only.
    var notesSealed: String? = nil
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
    /// Whether this task's steps are folded away on the list. New tasks start folded, so a card stays small.
    var subtasksCollapsed: Bool = true
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
    @Attribute(originalName: "firstStep") var firstStepPlain: String = ""
    /// The locked form of `firstStep`, empty until locking is turned on. Read and written through `firstStep` only.
    var firstStepSealed: String? = nil
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
        subtasksCollapsed: Bool = true,
        blockedByIDs: [UUID] = [],
        status: TaskStatus = .notStarted,
        energy: TaskEnergy = .unset,
        firstStep: String = "",
        focusSessions: Int = 0,
        focusMinutes: Int = 0,
        estimateMinutes: Int = 0
    ) {
        self.id = id
        self.titlePlain = title
        self.notesPlain = notes
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
        self.firstStepPlain = firstStep
        self.focusSessions = focusSessions
        self.focusMinutes = focusMinutes
        self.estimateMinutes = estimateMinutes
        lockNewValues()
    }

    /// Ticks the task off or back on, keeping `completedAt` in step.
    func setDone(_ done: Bool) {
        isDone = done
        completedAt = done ? Date.now : nil
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension TaskItem {
    var title: String {
        get { FieldLock.read(plain: titlePlain, sealed: titleSealed, context: "TaskItem.title") }
        set {
            let kept = FieldLock.store(newValue, context: "TaskItem.title")
            titlePlain = kept.plain
            titleSealed = kept.sealed
        }
    }
    var notes: String {
        get { FieldLock.read(plain: notesPlain, sealed: notesSealed, context: "TaskItem.notes") }
        set {
            let kept = FieldLock.store(newValue, context: "TaskItem.notes")
            notesPlain = kept.plain
            notesSealed = kept.sealed
        }
    }
    var firstStep: String {
        get { FieldLock.read(plain: firstStepPlain, sealed: firstStepSealed, context: "TaskItem.firstStep") }
        set {
            let kept = FieldLock.store(newValue, context: "TaskItem.firstStep")
            firstStepPlain = kept.plain
            firstStepSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        title = titlePlain
        notes = notesPlain
        firstStep = firstStepPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if titleSealed == nil { title = titlePlain }
        if notesSealed == nil { notes = notesPlain }
        if firstStepSealed == nil { firstStep = firstStepPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(title),
            FieldLock.describe(notes),
            FieldLock.describe(firstStep)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        titleSealed != nil && titlePlain.isEmpty
            && notesSealed != nil && notesPlain.isEmpty
            && firstStepSealed != nil && firstStepPlain.isEmpty
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
    /// Deleting a task takes its steps with it, and their steps, to any depth.
    func deleteTask(_ task: TaskItem, among tasks: [TaskItem]) {
        for step in TaskItem.steps(of: task, in: tasks) { deleteTask(step, among: tasks) }
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
    @Attribute(originalName: "title") var titlePlain: String
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    var createdAt: Date = Date.now
    @Attribute(originalName: "items") var itemsPlain: [QuickListItem] = []
    /// The locked form of `items`, empty until locking is turned on. Read and written through `items` only.
    var itemsSealed: String? = nil
    /// Set when the last open item is ticked, and cleared again when one is
    /// unticked or a new item is added. nil while the list is still in use.
    var archivedAt: Date? = nil

    init(id: UUID = UUID(), title: String, createdAt: Date = .now,
         items: [QuickListItem] = [], archivedAt: Date? = nil) {
        self.id = id
        self.titlePlain = title
        self.createdAt = createdAt
        self.itemsPlain = items
        self.archivedAt = archivedAt
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension QuickList {
    var title: String {
        get { FieldLock.read(plain: titlePlain, sealed: titleSealed, context: "QuickList.title") }
        set {
            let kept = FieldLock.store(newValue, context: "QuickList.title")
            titlePlain = kept.plain
            titleSealed = kept.sealed
        }
    }
    var items: [QuickListItem] {
        get { FieldLock.readCoded(itemsPlain, sealed: itemsSealed, context: "QuickList.items") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "QuickList.items")
            itemsPlain = kept.plain
            itemsSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        title = titlePlain
        items = itemsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if titleSealed == nil { title = titlePlain }
        if itemsSealed == nil { items = itemsPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(title),
            FieldLock.describe(items)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        titleSealed != nil && titlePlain.isEmpty
            && itemsSealed != nil && itemsPlain.isEmpty
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
    @Attribute(originalName: "name") var namePlain: String
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    var createdAt: Date = Date.now
    @Attribute(originalName: "steps") var stepsPlain: [RoutineStep] = []
    /// The locked form of `steps`, empty until locking is turned on. Read and written through `steps` only.
    var stepsSealed: String? = nil
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
        self.namePlain = name
        self.createdAt = createdAt
        self.stepsPlain = steps
        self.reminderEnabled = reminderEnabled
        self.reminderDays = reminderDays
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension Routine {
    var name: String {
        get { FieldLock.read(plain: namePlain, sealed: nameSealed, context: "Routine.name") }
        set {
            let kept = FieldLock.store(newValue, context: "Routine.name")
            namePlain = kept.plain
            nameSealed = kept.sealed
        }
    }
    var steps: [RoutineStep] {
        get { FieldLock.readCoded(stepsPlain, sealed: stepsSealed, context: "Routine.steps") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "Routine.steps")
            stepsPlain = kept.plain
            stepsSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        name = namePlain
        steps = stepsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if nameSealed == nil { name = namePlain }
        if stepsSealed == nil { steps = stepsPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(name),
            FieldLock.describe(steps)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        nameSealed != nil && namePlain.isEmpty
            && stepsSealed != nil && stepsPlain.isEmpty
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
    @Attribute(originalName: "name") var namePlain: String
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    var createdAt: Date = Date.now
    @Attribute(originalName: "variables") var variablesPlain: [ListVariable] = []
    /// The locked form of `variables`, empty until locking is turned on. Read and written through `variables` only.
    var variablesSealed: String? = nil
    @Attribute(originalName: "items") var itemsPlain: [ListItem] = []
    /// The locked form of `items`, empty until locking is turned on. Read and written through `items` only.
    var itemsSealed: String? = nil

    init(id: UUID = UUID(), name: String, createdAt: Date = .now,
         variables: [ListVariable] = [], items: [ListItem] = []) {
        self.id = id
        self.namePlain = name
        self.createdAt = createdAt
        self.variablesPlain = variables
        self.itemsPlain = items
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension ItemList {
    var name: String {
        get { FieldLock.read(plain: namePlain, sealed: nameSealed, context: "ItemList.name") }
        set {
            let kept = FieldLock.store(newValue, context: "ItemList.name")
            namePlain = kept.plain
            nameSealed = kept.sealed
        }
    }
    var variables: [ListVariable] {
        get { FieldLock.readCoded(variablesPlain, sealed: variablesSealed, context: "ItemList.variables") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "ItemList.variables")
            variablesPlain = kept.plain
            variablesSealed = kept.sealed
        }
    }
    var items: [ListItem] {
        get { FieldLock.readCoded(itemsPlain, sealed: itemsSealed, context: "ItemList.items") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "ItemList.items")
            itemsPlain = kept.plain
            itemsSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        name = namePlain
        variables = variablesPlain
        items = itemsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if nameSealed == nil { name = namePlain }
        if variablesSealed == nil { variables = variablesPlain }
        if itemsSealed == nil { items = itemsPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(name),
            FieldLock.describe(variables),
            FieldLock.describe(items)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        nameSealed != nil && namePlain.isEmpty
            && variablesSealed != nil && variablesPlain.isEmpty
            && itemsSealed != nil && itemsPlain.isEmpty
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
            SafetyPlan.self, SafetyPlanSection.self, BoundarySection.self, PersonSection.self, SleepEntry.self, MessageStarter.self, PersonalGoal.self, TriggerWindow.self, AppointmentSeries.self, AppointmentOccurrence.self,
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

// Patch 35b3: every model with locked fields can be locked in place, and checked, by Lock my data.
extension JournalEntry: LockableModel {}
extension TrustedContact: LockableModel {}
extension GroundingTool: LockableModel {}
extension SafetyPlan: LockableModel {}
extension SafetyPlanSection: LockableModel {}
extension BoundarySection: LockableModel {}
extension SleepEntry: LockableModel {}
extension PersonSection: LockableModel {}
extension PersonalGoal: LockableModel {}
extension MessageStarter: LockableModel {}
extension TriggerWindow: LockableModel {}
extension AppointmentSeries: LockableModel {}
extension AppointmentOccurrence: LockableModel {}
extension BridgeDraftItem: LockableModel {}
extension FeedbackLoopDiagram: LockableModel {}
extension ThreadMessage: LockableModel {}
extension SupportCalendarEntry: LockableModel {}
extension FutureNote: LockableModel {}
extension UnsentDraft: LockableModel {}
extension DecisionPresetCategory: LockableModel {}
extension DecisionPresetChoice: LockableModel {}
extension DeEscalationScript: LockableModel {}
extension Affirmation: LockableModel {}
extension NextHourItem: LockableModel {}
extension TaskItem: LockableModel {}
extension QuickList: LockableModel {}
extension Routine: LockableModel {}
extension ItemList: LockableModel {}
