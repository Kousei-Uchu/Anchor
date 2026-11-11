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
    var id: UUID = UUID()
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil

    /// Free-text search; no mood score, no numeric field of any kind.
    @Attribute(originalName: "isFavorited") var isFavoritedPlain: Bool = false

    /// If this entry was opened as an expansion of a check-in, tool tap,
    /// The locked form of `isFavorited`, empty until locking is turned on. Read and written through `isFavorited` only.
    var isFavoritedSealed: String? = nil
    /// or contact message elsewhere in the app, this records where it came
    /// from so Bridge/Plan can trace context — never shown as a metric,
    /// just used for "why was this entry surfaced" provenance.
    @Attribute(originalName: "linkedContext") var linkedContextPlain: EntryOrigin?

    /// Voice memo file reference, if this entry was captured via voice-to-text
    /// The locked form of `linkedContext`, empty until locking is turned on. Read and written through `linkedContext` only.
    var linkedContextSealed: String? = nil
    /// and the user chose to keep the audio alongside the transcript.
    var audioFileName: String?

    init(id: UUID = UUID(), createdAt: Date = .now, text: String, linkedContext: EntryOrigin? = nil, audioFileName: String? = nil) {
        self.id = id
        self.createdAtPlain = createdAt
        self.textPlain = text
        self.isFavoritedPlain = false
        self.linkedContextPlain = linkedContext
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

    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "JournalEntry.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "JournalEntry.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }
    var isFavorited: Bool {
        get { FieldLock.readScalar(plain: isFavoritedPlain, sealed: isFavoritedSealed, context: "JournalEntry.isFavorited") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "JournalEntry.isFavorited")
            isFavoritedPlain = kept.plain
            isFavoritedSealed = kept.sealed
        }
    }
    var linkedContext: EntryOrigin? {
        get { FieldLock.readOptionalChoice(plain: linkedContextPlain, sealed: linkedContextSealed, context: "JournalEntry.linkedContext") }
        set {
            let kept = FieldLock.storeOptionalChoice(newValue, context: "JournalEntry.linkedContext")
            linkedContextPlain = kept.plain
            linkedContextSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        createdAt = createdAtPlain
        isFavorited = isFavoritedPlain
        linkedContext = linkedContextPlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if isFavoritedSealed == nil { isFavorited = isFavoritedPlain }
        if linkedContextSealed == nil { linkedContext = linkedContextPlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(createdAt),
            FieldLock.describe(isFavorited),
            FieldLock.describe(linkedContext),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && isFavoritedSealed != nil && isFavoritedPlain == Bool.lockedPlaceholder
            && linkedContextSealed != nil && linkedContextPlain == nil
            && textSealed != nil && textPlain.isEmpty
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

// Patch 35g2: sealed as its raw text when the entry has one (D44).
extension EntryOrigin: LockedChoice { static var lockedPlaceholder: EntryOrigin { .manualOpen } }

// Patch 35g3: the task's day kind, where it stands and how much energy it needs, each sealed as its raw text (D44).
extension TaskDueKind: LockedChoice { static var lockedPlaceholder: TaskDueKind { .noDate } }
extension TaskStatus: LockedChoice { static var lockedPlaceholder: TaskStatus { .notStarted } }
extension TaskEnergy: LockedChoice { static var lockedPlaceholder: TaskEnergy { .unset } }

// MARK: - Now: check-ins

/// The five-slider exhaustion model, described in the user's own words.
/// No history graph, no streak, no "you haven't checked in today" nag —
/// this is a snapshot the user can optionally save, not a tracker.
@Model
final class CheckIn {
    var id: UUID = UUID()
    @Attribute(originalName: "timestamp") var timestampPlain: Date = Date(timeIntervalSinceReferenceDate: 0)

    // Each is a private 0...1 continuous value the user sets by feel,
    /// The locked form of `timestamp`, empty until locking is turned on. Read and written through `timestamp` only.
    var timestampSealed: String? = nil
    // not a labeled 1-10 "score." No aggregate/average is ever computed
    // or displayed — that would just be a score by another name.
    @Attribute(originalName: "physicalExhaustion") var physicalExhaustionPlain: Double = 0
    /// The locked form of `physicalExhaustion`, empty until locking is turned on. Read and written through `physicalExhaustion` only.
    var physicalExhaustionSealed: String? = nil
    @Attribute(originalName: "cognitiveBurnout") var cognitiveBurnoutPlain: Double = 0
    /// The locked form of `cognitiveBurnout`, empty until locking is turned on. Read and written through `cognitiveBurnout` only.
    var cognitiveBurnoutSealed: String? = nil
    @Attribute(originalName: "mentalLoad") var mentalLoadPlain: Double = 0
    /// The locked form of `mentalLoad`, empty until locking is turned on. Read and written through `mentalLoad` only.
    var mentalLoadSealed: String? = nil
    @Attribute(originalName: "physicalEnergy") var physicalEnergyPlain: Double = 0
    /// The locked form of `physicalEnergy`, empty until locking is turned on. Read and written through `physicalEnergy` only.
    var physicalEnergySealed: String? = nil
    @Attribute(originalName: "socialEnergy") var socialEnergyPlain: Double = 0

    /// Optional link to a journal entry if the user expanded this check-in
    /// The locked form of `socialEnergy`, empty until locking is turned on. Read and written through `socialEnergy` only.
    var socialEnergySealed: String? = nil
    /// into free writing.
    var expandedEntryID: UUID?

    /// Patch R5: the answers to the optional questions after the sliders, kept with the check-in itself as one piece
    /// of text (see `CheckInAnswers`). A new field, so it has no older name to carry over.
    var extraAnswersPlain: String = "" // a new locked field, no older name
    /// The locked form of `extraAnswers`, empty until locking is turned on. Read and written through `extraAnswers` only.
    var extraAnswersSealed: String? = nil

    init(id: UUID = UUID(), timestamp: Date = .now,
         physicalExhaustion: Double, cognitiveBurnout: Double, mentalLoad: Double,
         physicalEnergy: Double, socialEnergy: Double, expandedEntryID: UUID? = nil, extraAnswers: String = "") {
        self.id = id
        self.timestampPlain = timestamp
        self.physicalExhaustionPlain = physicalExhaustion
        self.cognitiveBurnoutPlain = cognitiveBurnout
        self.mentalLoadPlain = mentalLoad
        self.physicalEnergyPlain = physicalEnergy
        self.socialEnergyPlain = socialEnergy
        self.expandedEntryID = expandedEntryID
        self.extraAnswersPlain = extraAnswers
        lockNewValues()
    }
}

/// One of the optional questions after the check-in sliders, and what was written for it.
struct CheckInAnswer: Codable, Equatable, Identifiable {
    var question: String
    var answer: String
    var id: String { question }
}

/// The answers kept on a check-in are one piece of text (a list written as JSON), so they are locked as one field.
enum CheckInAnswers {
    static func encode(_ answers: [CheckInAnswer]) -> String {
        guard !answers.isEmpty, let data = try? JSONEncoder().encode(answers) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode(_ text: String) -> [CheckInAnswer] {
        guard !text.isEmpty, let data = text.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([CheckInAnswer].self, from: data)) ?? []
    }
}

// Patch 35g1b: the old names, read and written through FieldLock so a locked value reads as its value.
extension CheckIn {
    var extraAnswers: String {
        get { FieldLock.read(plain: extraAnswersPlain, sealed: extraAnswersSealed, context: "CheckIn.extraAnswers") }
        set {
            let kept = FieldLock.store(newValue, context: "CheckIn.extraAnswers")
            extraAnswersPlain = kept.plain
            extraAnswersSealed = kept.sealed
        }
    }

    /// The questions answered after the sliders, with what was written. Empty when none were.
    var answers: [CheckInAnswer] { CheckInAnswers.decode(extraAnswers) }

    var timestamp: Date {
        get { FieldLock.readScalar(plain: timestampPlain, sealed: timestampSealed, context: "CheckIn.timestamp") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "CheckIn.timestamp")
            timestampPlain = kept.plain
            timestampSealed = kept.sealed
        }
    }
    var physicalExhaustion: Double {
        get { FieldLock.readScalar(plain: physicalExhaustionPlain, sealed: physicalExhaustionSealed, context: "CheckIn.physicalExhaustion") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "CheckIn.physicalExhaustion")
            physicalExhaustionPlain = kept.plain
            physicalExhaustionSealed = kept.sealed
        }
    }
    var cognitiveBurnout: Double {
        get { FieldLock.readScalar(plain: cognitiveBurnoutPlain, sealed: cognitiveBurnoutSealed, context: "CheckIn.cognitiveBurnout") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "CheckIn.cognitiveBurnout")
            cognitiveBurnoutPlain = kept.plain
            cognitiveBurnoutSealed = kept.sealed
        }
    }
    var mentalLoad: Double {
        get { FieldLock.readScalar(plain: mentalLoadPlain, sealed: mentalLoadSealed, context: "CheckIn.mentalLoad") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "CheckIn.mentalLoad")
            mentalLoadPlain = kept.plain
            mentalLoadSealed = kept.sealed
        }
    }
    var physicalEnergy: Double {
        get { FieldLock.readScalar(plain: physicalEnergyPlain, sealed: physicalEnergySealed, context: "CheckIn.physicalEnergy") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "CheckIn.physicalEnergy")
            physicalEnergyPlain = kept.plain
            physicalEnergySealed = kept.sealed
        }
    }
    var socialEnergy: Double {
        get { FieldLock.readScalar(plain: socialEnergyPlain, sealed: socialEnergySealed, context: "CheckIn.socialEnergy") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "CheckIn.socialEnergy")
            socialEnergyPlain = kept.plain
            socialEnergySealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        timestamp = timestampPlain
        physicalExhaustion = physicalExhaustionPlain
        cognitiveBurnout = cognitiveBurnoutPlain
        mentalLoad = mentalLoadPlain
        physicalEnergy = physicalEnergyPlain
        socialEnergy = socialEnergyPlain
        extraAnswers = extraAnswersPlain
    }

    /// Seals what is stored plain and leaves anything already sealed alone, so it is safe to run again. It does
    /// nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if timestampSealed == nil { timestamp = timestampPlain }
        if physicalExhaustionSealed == nil { physicalExhaustion = physicalExhaustionPlain }
        if cognitiveBurnoutSealed == nil { cognitiveBurnout = cognitiveBurnoutPlain }
        if mentalLoadSealed == nil { mentalLoad = mentalLoadPlain }
        if physicalEnergySealed == nil { physicalEnergy = physicalEnergyPlain }
        if socialEnergySealed == nil { socialEnergy = socialEnergyPlain }
        if extraAnswersSealed == nil { extraAnswers = extraAnswersPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its value.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(timestamp),
            FieldLock.describe(physicalExhaustion),
            FieldLock.describe(cognitiveBurnout),
            FieldLock.describe(mentalLoad),
            FieldLock.describe(physicalEnergy),
            FieldLock.describe(socialEnergy),
            FieldLock.describe(extraAnswers)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        timestampSealed != nil && timestampPlain == Date.lockedPlaceholder
            && physicalExhaustionSealed != nil && physicalExhaustionPlain == Double.lockedPlaceholder
            && cognitiveBurnoutSealed != nil && cognitiveBurnoutPlain == Double.lockedPlaceholder
            && mentalLoadSealed != nil && mentalLoadPlain == Double.lockedPlaceholder
            && physicalEnergySealed != nil && physicalEnergyPlain == Double.lockedPlaceholder
            && socialEnergySealed != nil && socialEnergyPlain == Double.lockedPlaceholder
            && extraAnswersSealed != nil && extraAnswersPlain.isEmpty
    }
}

// MARK: - Contacts

@Model
final class TrustedContact {
    var id: UUID = UUID()
    @Attribute(originalName: "name") var namePlain: String = ""
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    @Attribute(originalName: "phoneNumber") var phoneNumberPlain: String = "" // routes to native Messages, not a custom backend
    /// The locked form of `phoneNumber`, empty until locking is turned on. Read and written through `phoneNumber` only.
    var phoneNumberSealed: String? = nil
    var sortOrder: Int = 0

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
    var escalationEnabled: Bool = false
    /// Minutes to wait for a response to a routine check-in before this
    /// contact is notified. Only used if escalationEnabled == true.
    @Attribute(originalName: "escalationWindowMinutes") var escalationWindowMinutesPlain: Int?
    /// The locked form of `escalationWindowMinutes`, empty until locking is turned on. Read and written through `escalationWindowMinutes` only.
    var escalationWindowMinutesSealed: String? = nil

    @Attribute(originalName: "messageTemplates") var messageTemplatesPlain: [MessageTemplate] = []
    /// The locked form of `messageTemplates`, empty until locking is turned on. Read and written through `messageTemplates` only.
    var messageTemplatesSealed: String? = nil

    /// How reaching this person actually works. Phone (SMS/call) is the
    /// default and always available; Discord needs their numeric user ID
    /// — Discord's URL scheme can't resolve a DM from a username alone.
    var contactMethod: ContactMethod = ContactMethod.phone
    @Attribute(originalName: "discordUserID") var discordUserIDPlain: String?
    /// The locked form of `discordUserID`, empty until locking is turned on. Read and written through `discordUserID` only.
    var discordUserIDSealed: String? = nil

    /// Optional — powers the "who's awake" screen. All nil means "unknown,
    /// don't show a status for this person."
    @Attribute(originalName: "timeZoneIdentifier") var timeZoneIdentifierPlain: String?
    /// The locked form of `timeZoneIdentifier`, empty until locking is turned on. Read and written through `timeZoneIdentifier` only.
    var timeZoneIdentifierSealed: String? = nil
    @Attribute(originalName: "availableFromHour") var availableFromHourPlain: Int?
    /// The locked form of `availableFromHour`, empty until locking is turned on. Read and written through `availableFromHour` only.
    var availableFromHourSealed: String? = nil
    @Attribute(originalName: "availableFromMinute") var availableFromMinutePlain: Int?
    /// The locked form of `availableFromMinute`, empty until locking is turned on. Read and written through `availableFromMinute` only.
    var availableFromMinuteSealed: String? = nil
    @Attribute(originalName: "availableToHour") var availableToHourPlain: Int?
    /// The locked form of `availableToHour`, empty until locking is turned on. Read and written through `availableToHour` only.
    var availableToHourSealed: String? = nil
    @Attribute(originalName: "availableToMinute") var availableToMinutePlain: Int?

    /// An optional regular hello you set for this person. Off unless you switch it on.
    /// The locked form of `availableToMinute`, empty until locking is turned on. Read and written through `availableToMinute` only.
    var availableToMinuteSealed: String? = nil
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

    /// An optional reminder after a session, to ask if you want to tell this person how it went. Off
    /// unless you switch it on. It comes that evening, or the next morning if you choose that.
    var afterSessionEnabled: Bool = false
    var afterSessionNextMorning: Bool = false

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
         companionEnabled: Bool = false, companionWindowIDs: [UUID] = [],
         afterSessionEnabled: Bool = false, afterSessionNextMorning: Bool = false) {
        self.id = id
        self.namePlain = name
        self.phoneNumberPlain = phoneNumber
        self.sortOrder = sortOrder
        self.escalationEnabled = escalationEnabled
        self.escalationWindowMinutesPlain = escalationWindowMinutes
        self.messageTemplatesPlain = messageTemplates
        self.contactMethod = contactMethod
        self.discordUserIDPlain = discordUserID
        self.timeZoneIdentifierPlain = timeZoneIdentifier
        self.availableFromHourPlain = availableFromHour
        self.availableFromMinutePlain = availableFromMinute
        self.availableToHourPlain = availableToHour
        self.availableToMinutePlain = availableToMinute
        self.helloEnabled = helloEnabled
        self.helloDays = helloDays
        self.helloHour = helloHour
        self.helloMinute = helloMinute
        self.supportDaysEnabled = supportDaysEnabled
        self.supportDaysDayBefore = supportDaysDayBefore
        self.companionEnabled = companionEnabled
        self.companionWindowIDs = companionWindowIDs
        self.afterSessionEnabled = afterSessionEnabled
        self.afterSessionNextMorning = afterSessionNextMorning
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

    var escalationWindowMinutes: Int? {
        get { FieldLock.readOptionalScalar(plain: escalationWindowMinutesPlain, sealed: escalationWindowMinutesSealed, context: "TrustedContact.escalationWindowMinutes") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "TrustedContact.escalationWindowMinutes")
            escalationWindowMinutesPlain = kept.plain
            escalationWindowMinutesSealed = kept.sealed
        }
    }
    var timeZoneIdentifier: String? {
        get { FieldLock.readOptional(plain: timeZoneIdentifierPlain, sealed: timeZoneIdentifierSealed, context: "TrustedContact.timeZoneIdentifier") }
        set {
            let kept = FieldLock.storeOptional(newValue, context: "TrustedContact.timeZoneIdentifier")
            timeZoneIdentifierPlain = kept.plain
            timeZoneIdentifierSealed = kept.sealed
        }
    }
    var availableFromHour: Int? {
        get { FieldLock.readOptionalScalar(plain: availableFromHourPlain, sealed: availableFromHourSealed, context: "TrustedContact.availableFromHour") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "TrustedContact.availableFromHour")
            availableFromHourPlain = kept.plain
            availableFromHourSealed = kept.sealed
        }
    }
    var availableFromMinute: Int? {
        get { FieldLock.readOptionalScalar(plain: availableFromMinutePlain, sealed: availableFromMinuteSealed, context: "TrustedContact.availableFromMinute") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "TrustedContact.availableFromMinute")
            availableFromMinutePlain = kept.plain
            availableFromMinuteSealed = kept.sealed
        }
    }
    var availableToHour: Int? {
        get { FieldLock.readOptionalScalar(plain: availableToHourPlain, sealed: availableToHourSealed, context: "TrustedContact.availableToHour") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "TrustedContact.availableToHour")
            availableToHourPlain = kept.plain
            availableToHourSealed = kept.sealed
        }
    }
    var availableToMinute: Int? {
        get { FieldLock.readOptionalScalar(plain: availableToMinutePlain, sealed: availableToMinuteSealed, context: "TrustedContact.availableToMinute") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "TrustedContact.availableToMinute")
            availableToMinutePlain = kept.plain
            availableToMinuteSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        escalationWindowMinutes = escalationWindowMinutesPlain
        timeZoneIdentifier = timeZoneIdentifierPlain
        availableFromHour = availableFromHourPlain
        availableFromMinute = availableFromMinutePlain
        availableToHour = availableToHourPlain
        availableToMinute = availableToMinutePlain
        name = namePlain
        phoneNumber = phoneNumberPlain
        messageTemplates = messageTemplatesPlain
        discordUserID = discordUserIDPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if escalationWindowMinutesSealed == nil { escalationWindowMinutes = escalationWindowMinutesPlain }
        if timeZoneIdentifierSealed == nil, let kept = timeZoneIdentifierPlain { timeZoneIdentifier = kept }
        if availableFromHourSealed == nil { availableFromHour = availableFromHourPlain }
        if availableFromMinuteSealed == nil { availableFromMinute = availableFromMinutePlain }
        if availableToHourSealed == nil { availableToHour = availableToHourPlain }
        if availableToMinuteSealed == nil { availableToMinute = availableToMinutePlain }
        if nameSealed == nil { name = namePlain }
        if phoneNumberSealed == nil { phoneNumber = phoneNumberPlain }
        if messageTemplatesSealed == nil { messageTemplates = messageTemplatesPlain }
        if discordUserIDSealed == nil, let kept = discordUserIDPlain { discordUserID = kept }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(escalationWindowMinutes),
            FieldLock.describe(timeZoneIdentifier),
            FieldLock.describe(availableFromHour),
            FieldLock.describe(availableFromMinute),
            FieldLock.describe(availableToHour),
            FieldLock.describe(availableToMinute),
            FieldLock.describe(name),
            FieldLock.describe(phoneNumber),
            FieldLock.describe(messageTemplates),
            FieldLock.describe(discordUserID)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        escalationWindowMinutesSealed != nil && escalationWindowMinutesPlain == nil
            && timeZoneIdentifierPlain == nil
            && availableFromHourSealed != nil && availableFromHourPlain == nil
            && availableFromMinuteSealed != nil && availableFromMinutePlain == nil
            && availableToHourSealed != nil && availableToHourPlain == nil
            && availableToMinuteSealed != nil && availableToMinutePlain == nil
            && nameSealed != nil && namePlain.isEmpty
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

    /// "That evening" or "The next morning", or nil while the after-session reminder is off.
    var afterSessionSummary: String? {
        guard afterSessionEnabled else { return nil }
        return afterSessionNextMorning ? "The next morning" : "That evening"
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
    var id: UUID = UUID()
    @Attribute(originalName: "title") var titlePlain: String = ""
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    var kind: GroundingToolKind = GroundingToolKind.physicalAction
    @Attribute(originalName: "steps") var stepsPlain: String?                 // for .physicalAction
    /// The locked form of `steps`, empty until locking is turned on. Read and written through `steps` only.
    var stepsSealed: String? = nil
    var deepLink: DeepLinkDestination? // for .deepLink
    var sortOrder: Int = 0

    /// Which times of day this makes sense to surface (ties into the
    /// "filtered to what's near/available right now" behavior). Empty
    /// means "always relevant."
    @Attribute(originalName: "relevantTimeWindows") var relevantTimeWindowsPlain: [TimeWindowTag] = []
    /// The locked form of `relevantTimeWindows`, empty until locking is turned on. Read and written through `relevantTimeWindows` only.
    var relevantTimeWindowsSealed: String? = nil

    init(id: UUID = UUID(), title: String, kind: GroundingToolKind,
         steps: String? = nil, deepLink: DeepLinkDestination? = nil,
         sortOrder: Int, relevantTimeWindows: [TimeWindowTag] = []) {
        self.id = id
        self.titlePlain = title
        self.kind = kind
        self.stepsPlain = steps
        self.deepLink = deepLink
        self.sortOrder = sortOrder
        self.relevantTimeWindowsPlain = relevantTimeWindows
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

    var relevantTimeWindows: [TimeWindowTag] {
        get { FieldLock.readCoded(relevantTimeWindowsPlain, sealed: relevantTimeWindowsSealed, context: "GroundingTool.relevantTimeWindows") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "GroundingTool.relevantTimeWindows")
            relevantTimeWindowsPlain = kept.plain
            relevantTimeWindowsSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        relevantTimeWindows = relevantTimeWindowsPlain
        title = titlePlain
        steps = stepsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if relevantTimeWindowsSealed == nil { relevantTimeWindows = relevantTimeWindowsPlain }
        if titleSealed == nil { title = titlePlain }
        if stepsSealed == nil, let kept = stepsPlain { steps = kept }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(relevantTimeWindows),
            FieldLock.describe(title),
            FieldLock.describe(steps)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        relevantTimeWindowsSealed != nil && relevantTimeWindowsPlain.isEmpty
            && titleSealed != nil && titlePlain.isEmpty
            && stepsPlain == nil
    }
}

enum TimeWindowTag: String, Codable {
    case morning, afternoon, evening, lateNight
}

// MARK: - Plan: safety plan, trigger windows, appointments

@Model
final class SafetyPlan {
    var id: UUID = UUID()
    @Attribute(originalName: "lastEditedAt") var lastEditedAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `lastEditedAt`, empty until locking is turned on. Read and written through `lastEditedAt` only.
    var lastEditedAtSealed: String? = nil
    @Attribute(originalName: "warningSignsText") var warningSignsTextPlain: String = ""
    /// The locked form of `warningSignsText`, empty until locking is turned on. Read and written through `warningSignsText` only.
    var warningSignsTextSealed: String? = nil
    @Attribute(originalName: "copingStrategiesText") var copingStrategiesTextPlain: String = ""
    /// The locked form of `copingStrategiesText`, empty until locking is turned on. Read and written through `copingStrategiesText` only.
    var copingStrategiesTextSealed: String? = nil
    @Attribute(originalName: "reasonsToKeepGoingText") var reasonsToKeepGoingTextPlain: String = "" // source pool for templated notification quotes
    /// The locked form of `reasonsToKeepGoingText`, empty until locking is turned on. Read and written through `reasonsToKeepGoingText` only.
    var reasonsToKeepGoingTextSealed: String? = nil
    @Attribute(originalName: "environmentSafetyStepsText") var environmentSafetyStepsTextPlain: String = ""
    /// The locked form of `environmentSafetyStepsText`, empty until locking is turned on. Read and written through `environmentSafetyStepsText` only.
    var environmentSafetyStepsTextSealed: String? = nil

    init(id: UUID = UUID(), lastEditedAt: Date = .now,
         warningSignsText: String = "", copingStrategiesText: String = "",
         reasonsToKeepGoingText: String = "", environmentSafetyStepsText: String = "") {
        self.id = id
        self.lastEditedAtPlain = lastEditedAt
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

    var lastEditedAt: Date {
        get { FieldLock.readScalar(plain: lastEditedAtPlain, sealed: lastEditedAtSealed, context: "SafetyPlan.lastEditedAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "SafetyPlan.lastEditedAt")
            lastEditedAtPlain = kept.plain
            lastEditedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        lastEditedAt = lastEditedAtPlain
        warningSignsText = warningSignsTextPlain
        copingStrategiesText = copingStrategiesTextPlain
        reasonsToKeepGoingText = reasonsToKeepGoingTextPlain
        environmentSafetyStepsText = environmentSafetyStepsTextPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if lastEditedAtSealed == nil { lastEditedAt = lastEditedAtPlain }
        if warningSignsTextSealed == nil { warningSignsText = warningSignsTextPlain }
        if copingStrategiesTextSealed == nil { copingStrategiesText = copingStrategiesTextPlain }
        if reasonsToKeepGoingTextSealed == nil { reasonsToKeepGoingText = reasonsToKeepGoingTextPlain }
        if environmentSafetyStepsTextSealed == nil { environmentSafetyStepsText = environmentSafetyStepsTextPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(lastEditedAt),
            FieldLock.describe(warningSignsText),
            FieldLock.describe(copingStrategiesText),
            FieldLock.describe(reasonsToKeepGoingText),
            FieldLock.describe(environmentSafetyStepsText)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        lastEditedAtSealed != nil && lastEditedAtPlain == Date.lockedPlaceholder
            && warningSignsTextSealed != nil && warningSignsTextPlain.isEmpty
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
    var id: UUID = UUID()
    @Attribute(originalName: "title") var titlePlain: String = ""
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var iconName: String = ""
    var tintName: String = ""
    var sortOrder: Int = 0
    var isHidden: Bool = false
    /// Empty for an ordinary section. `reasonsRole` marks the one section that
    /// reminder quotes are taken from.
    var role: String = ""
    @Attribute(originalName: "lastEditedAt") var lastEditedAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `lastEditedAt`, empty until locking is turned on. Read and written through `lastEditedAt` only.
    var lastEditedAtSealed: String? = nil

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
        self.lastEditedAtPlain = lastEditedAt
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

    var lastEditedAt: Date {
        get { FieldLock.readScalar(plain: lastEditedAtPlain, sealed: lastEditedAtSealed, context: "SafetyPlanSection.lastEditedAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "SafetyPlanSection.lastEditedAt")
            lastEditedAtPlain = kept.plain
            lastEditedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        lastEditedAt = lastEditedAtPlain
        title = titlePlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if lastEditedAtSealed == nil { lastEditedAt = lastEditedAtPlain }
        if titleSealed == nil { title = titlePlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(lastEditedAt),
            FieldLock.describe(title),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        lastEditedAtSealed != nil && lastEditedAtPlain == Date.lockedPlaceholder
            && titleSealed != nil && titlePlain.isEmpty
            && textSealed != nil && textPlain.isEmpty
    }
}

/// One section of the Boundaries list: things the person would like others to
/// know, what helps, what does not. The same shape as a safety plan section
/// plus a flag saying whether it may be shared when they choose to share the
/// list. Nothing is shared unless they do it themselves.
@Model
final class BoundarySection {
    var id: UUID = UUID()
    @Attribute(originalName: "title") var titlePlain: String = ""
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var iconName: String = ""
    var tintName: String = ""
    var sortOrder: Int = 0
    var isHidden: Bool = false
    var isShareable: Bool = false
    @Attribute(originalName: "lastEditedAt") var lastEditedAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `lastEditedAt`, empty until locking is turned on. Read and written through `lastEditedAt` only.
    var lastEditedAtSealed: String? = nil

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
        self.lastEditedAtPlain = lastEditedAt
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

    var lastEditedAt: Date {
        get { FieldLock.readScalar(plain: lastEditedAtPlain, sealed: lastEditedAtSealed, context: "BoundarySection.lastEditedAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "BoundarySection.lastEditedAt")
            lastEditedAtPlain = kept.plain
            lastEditedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        lastEditedAt = lastEditedAtPlain
        title = titlePlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if lastEditedAtSealed == nil { lastEditedAt = lastEditedAtPlain }
        if titleSealed == nil { title = titlePlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(lastEditedAt),
            FieldLock.describe(title),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        lastEditedAtSealed != nil && lastEditedAtPlain == Date.lockedPlaceholder
            && titleSealed != nil && titlePlain.isEmpty
            && textSealed != nil && textPlain.isEmpty
    }
}

/// One night in the sleep journal. A quiet record and nothing more: there is
/// no score, no target, no streak and no word for a "bad" night. Every field
/// is optional or defaulted, so a night can hold just a note, or just a time.
@Model
final class SleepEntry {
    var id: UUID = UUID()
    /// The night this belongs to, as the start of the day you woke up on.
    @Attribute(originalName: "nightDate") var nightDatePlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `nightDate`, empty until locking is turned on. Read and written through `nightDate` only.
    var nightDateSealed: String? = nil
    @Attribute(originalName: "bedTime") var bedTimePlain: Date? = nil
    /// The locked form of `bedTime`, empty until locking is turned on. Read and written through `bedTime` only.
    var bedTimeSealed: String? = nil
    @Attribute(originalName: "wakeTime") var wakeTimePlain: Date? = nil
    /// Time asleep, in minutes, when it was typed. Nil means it is worked out
    /// The locked form of `wakeTime`, empty until locking is turned on. Read and written through `wakeTime` only.
    var wakeTimeSealed: String? = nil
    /// from the two times, if both are there.
    @Attribute(originalName: "minutesAsleep") var minutesAsleepPlain: Int? = nil
    /// Which of the three feel words, 0 to 2. Nil means nothing was chosen.
    /// The locked form of `minutesAsleep`, empty until locking is turned on. Read and written through `minutesAsleep` only.
    var minutesAsleepSealed: String? = nil
    @Attribute(originalName: "feel") var feelPlain: Int? = nil
    /// The locked form of `feel`, empty until locking is turned on. Read and written through `feel` only.
    var feelSealed: String? = nil
    @Attribute(originalName: "note") var notePlain: String = ""
    /// The locked form of `note`, empty until locking is turned on. Read and written through `note` only.
    var noteSealed: String? = nil
    /// "typed" for now. Later versions may add other sources.
    var sourceRaw: String = "typed"
    /// For a night that came from somewhere else, that source's own id, so
    /// the same night is never added twice. Nil for typed nights.
    var externalID: String? = nil
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date.now
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    @Attribute(originalName: "lastEditedAt") var lastEditedAtPlain: Date = Date.now
    /// The locked form of `lastEditedAt`, empty until locking is turned on. Read and written through `lastEditedAt` only.
    var lastEditedAtSealed: String? = nil

    init(id: UUID = UUID(), nightDate: Date = Calendar.current.startOfDay(for: .now),
         bedTime: Date? = nil, wakeTime: Date? = nil, minutesAsleep: Int? = nil,
         feel: Int? = nil, note: String = "", sourceRaw: String = "typed",
         externalID: String? = nil, createdAt: Date = .now, lastEditedAt: Date = .now) {
        self.id = id
        self.nightDatePlain = nightDate
        self.bedTimePlain = bedTime
        self.wakeTimePlain = wakeTime
        self.minutesAsleepPlain = minutesAsleep
        self.feelPlain = feel
        self.notePlain = note
        self.sourceRaw = sourceRaw
        self.externalID = externalID
        self.createdAtPlain = createdAt
        self.lastEditedAtPlain = lastEditedAt
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

    var nightDate: Date {
        get { FieldLock.readScalar(plain: nightDatePlain, sealed: nightDateSealed, context: "SleepEntry.nightDate") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "SleepEntry.nightDate")
            nightDatePlain = kept.plain
            nightDateSealed = kept.sealed
        }
    }
    var bedTime: Date? {
        get { FieldLock.readOptionalScalar(plain: bedTimePlain, sealed: bedTimeSealed, context: "SleepEntry.bedTime") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "SleepEntry.bedTime")
            bedTimePlain = kept.plain
            bedTimeSealed = kept.sealed
        }
    }
    var wakeTime: Date? {
        get { FieldLock.readOptionalScalar(plain: wakeTimePlain, sealed: wakeTimeSealed, context: "SleepEntry.wakeTime") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "SleepEntry.wakeTime")
            wakeTimePlain = kept.plain
            wakeTimeSealed = kept.sealed
        }
    }
    var minutesAsleep: Int? {
        get { FieldLock.readOptionalScalar(plain: minutesAsleepPlain, sealed: minutesAsleepSealed, context: "SleepEntry.minutesAsleep") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "SleepEntry.minutesAsleep")
            minutesAsleepPlain = kept.plain
            minutesAsleepSealed = kept.sealed
        }
    }
    var feel: Int? {
        get { FieldLock.readOptionalScalar(plain: feelPlain, sealed: feelSealed, context: "SleepEntry.feel") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "SleepEntry.feel")
            feelPlain = kept.plain
            feelSealed = kept.sealed
        }
    }
    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "SleepEntry.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "SleepEntry.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }
    var lastEditedAt: Date {
        get { FieldLock.readScalar(plain: lastEditedAtPlain, sealed: lastEditedAtSealed, context: "SleepEntry.lastEditedAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "SleepEntry.lastEditedAt")
            lastEditedAtPlain = kept.plain
            lastEditedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        nightDate = nightDatePlain
        bedTime = bedTimePlain
        wakeTime = wakeTimePlain
        minutesAsleep = minutesAsleepPlain
        feel = feelPlain
        createdAt = createdAtPlain
        lastEditedAt = lastEditedAtPlain
        note = notePlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if nightDateSealed == nil { nightDate = nightDatePlain }
        if bedTimeSealed == nil { bedTime = bedTimePlain }
        if wakeTimeSealed == nil { wakeTime = wakeTimePlain }
        if minutesAsleepSealed == nil { minutesAsleep = minutesAsleepPlain }
        if feelSealed == nil { feel = feelPlain }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if lastEditedAtSealed == nil { lastEditedAt = lastEditedAtPlain }
        if noteSealed == nil { note = notePlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(nightDate),
            FieldLock.describe(bedTime),
            FieldLock.describe(wakeTime),
            FieldLock.describe(minutesAsleep),
            FieldLock.describe(feel),
            FieldLock.describe(createdAt),
            FieldLock.describe(lastEditedAt),
            FieldLock.describe(note)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        nightDateSealed != nil && nightDatePlain == Date.lockedPlaceholder
            && bedTimeSealed != nil && bedTimePlain == nil
            && wakeTimeSealed != nil && wakeTimePlain == nil
            && minutesAsleepSealed != nil && minutesAsleepPlain == nil
            && feelSealed != nil && feelPlain == nil
            && createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && lastEditedAtSealed != nil && lastEditedAtPlain == Date.lockedPlaceholder
            && noteSealed != nil && notePlain.isEmpty
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
        let saved = saved(from: raw).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (0..<3).map { index in
            index < saved.count && !saved[index].isEmpty ? saved[index] : defaults[index]
        }
    }

    /// What was saved, opened if it is sealed and split into its words, with nothing filled in for an empty one. Empty
    /// when the saved value is sealed and does not open (Patch 35g4).
    static func saved(from raw: String) -> [String] {
        guard let text = LockedSetting.text(raw, key: storageKey) else { return [] }
        return text.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    }

    /// The text to save for the words: sealed while locking is on, and empty (the usual words) if it could not be sealed.
    static func encode(_ words: [String]) -> String {
        let plain = words.map { $0.replacingOccurrences(of: "|", with: " ") }.joined(separator: "|")
        return LockedSetting.kept(plain, key: storageKey) ?? ""
    }
}

/// One section of a person's page: a note about them, what helps, things the
/// person has told them, or anything else the person decides to keep. The
/// same shape as a safety plan section, tied to one trusted contact by id.
/// Nothing is made for anyone, and nothing here is counted or scored.
@Model
final class PersonSection {
    var id: UUID = UUID()
    /// The `TrustedContact` this page belongs to.
    var contactID: UUID = UUID()
    @Attribute(originalName: "title") var titlePlain: String = ""
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var iconName: String = ""
    var tintName: String = ""
    var sortOrder: Int = 0
    var isHidden: Bool = false
    @Attribute(originalName: "lastEditedAt") var lastEditedAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `lastEditedAt`, empty until locking is turned on. Read and written through `lastEditedAt` only.
    var lastEditedAtSealed: String? = nil

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
        self.lastEditedAtPlain = lastEditedAt
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

    var lastEditedAt: Date {
        get { FieldLock.readScalar(plain: lastEditedAtPlain, sealed: lastEditedAtSealed, context: "PersonSection.lastEditedAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "PersonSection.lastEditedAt")
            lastEditedAtPlain = kept.plain
            lastEditedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        lastEditedAt = lastEditedAtPlain
        title = titlePlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if lastEditedAtSealed == nil { lastEditedAt = lastEditedAtPlain }
        if titleSealed == nil { title = titlePlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(lastEditedAt),
            FieldLock.describe(title),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        lastEditedAtSealed != nil && lastEditedAtPlain == Date.lockedPlaceholder
            && titleSealed != nil && titlePlain.isEmpty
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
    var id: UUID = UUID()
    @Attribute(originalName: "title") var titlePlain: String = ""
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "why") var whyPlain: String = ""
    /// The locked form of `why`, empty until locking is turned on. Read and written through `why` only.
    var whySealed: String? = nil
    @Attribute(originalName: "statusRaw") var statusRawPlain: String = "active"
    /// The locked form of `statusRaw`, empty until locking is turned on. Read and written through `statusRaw` only.
    var statusRawSealed: String? = nil
    @Attribute(originalName: "notes") var notesPlain: [GoalNote] = []
    /// The locked form of `notes`, empty until locking is turned on. Read and written through `notes` only.
    var notesSealed: String? = nil
    var sortOrder: Int = 0
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date.now
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    @Attribute(originalName: "lastEditedAt") var lastEditedAtPlain: Date = Date.now
    /// An optional frame some people find useful, off unless switched on for a goal. Every part can stay
    /// The locked form of `lastEditedAt`, empty until locking is turned on. Read and written through `lastEditedAt` only.
    var lastEditedAtSealed: String? = nil
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
        self.statusRawPlain = status.rawValue
        self.notesPlain = notes
        self.sortOrder = sortOrder
        self.createdAtPlain = createdAt
        self.lastEditedAtPlain = lastEditedAt
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

    var statusRaw: String {
        get { FieldLock.read(plain: statusRawPlain, sealed: statusRawSealed, context: "PersonalGoal.statusRaw") }
        set {
            let kept = FieldLock.store(newValue, context: "PersonalGoal.statusRaw")
            statusRawPlain = kept.plain
            statusRawSealed = kept.sealed
        }
    }
    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "PersonalGoal.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "PersonalGoal.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }
    var lastEditedAt: Date {
        get { FieldLock.readScalar(plain: lastEditedAtPlain, sealed: lastEditedAtSealed, context: "PersonalGoal.lastEditedAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "PersonalGoal.lastEditedAt")
            lastEditedAtPlain = kept.plain
            lastEditedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        statusRaw = statusRawPlain
        createdAt = createdAtPlain
        lastEditedAt = lastEditedAtPlain
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
        if statusRawSealed == nil { statusRaw = statusRawPlain }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if lastEditedAtSealed == nil { lastEditedAt = lastEditedAtPlain }
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
            FieldLock.describe(statusRaw),
            FieldLock.describe(createdAt),
            FieldLock.describe(lastEditedAt),
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
        statusRawSealed != nil && statusRawPlain.isEmpty
            && createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && lastEditedAtSealed != nil && lastEditedAtPlain == Date.lockedPlaceholder
            && titleSealed != nil && titlePlain.isEmpty
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
    var id: UUID = UUID()
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var sortOrder: Int = 0
    @Attribute(originalName: "lastEditedAt") var lastEditedAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `lastEditedAt`, empty until locking is turned on. Read and written through `lastEditedAt` only.
    var lastEditedAtSealed: String? = nil

    init(id: UUID = UUID(), text: String = "", sortOrder: Int = 0, lastEditedAt: Date = .now) {
        self.id = id
        self.textPlain = text
        self.sortOrder = sortOrder
        self.lastEditedAtPlain = lastEditedAt
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

    var lastEditedAt: Date {
        get { FieldLock.readScalar(plain: lastEditedAtPlain, sealed: lastEditedAtSealed, context: "MessageStarter.lastEditedAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "MessageStarter.lastEditedAt")
            lastEditedAtPlain = kept.plain
            lastEditedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        lastEditedAt = lastEditedAtPlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if lastEditedAtSealed == nil { lastEditedAt = lastEditedAtPlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(lastEditedAt),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        lastEditedAtSealed != nil && lastEditedAtPlain == Date.lockedPlaceholder
            && textSealed != nil && textPlain.isEmpty
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
    var id: UUID = UUID()
    @Attribute(originalName: "label") var labelPlain: String = ""
    /// The locked form of `label`, empty until locking is turned on. Read and written through `label` only.
    var labelSealed: String? = nil
    @Attribute(originalName: "daysOfWeek") var daysOfWeekPlain: [Int] = []   // 1 = Sunday ... 7 = Saturday, Calendar-style
    /// The locked form of `daysOfWeek`, empty until locking is turned on. Read and written through `daysOfWeek` only.
    var daysOfWeekSealed: String? = nil

    // Stored separately because DateComponents contains Calendar internally,
    // which SwiftData cannot persist.
    @Attribute(originalName: "startHour") var startHourPlain: Int = 0
    /// The locked form of `startHour`, empty until locking is turned on. Read and written through `startHour` only.
    var startHourSealed: String? = nil
    @Attribute(originalName: "startMinute") var startMinutePlain: Int = 0
    /// The locked form of `startMinute`, empty until locking is turned on. Read and written through `startMinute` only.
    var startMinuteSealed: String? = nil
    @Attribute(originalName: "endHour") var endHourPlain: Int = 0
    /// The locked form of `endHour`, empty until locking is turned on. Read and written through `endHour` only.
    var endHourSealed: String? = nil
    @Attribute(originalName: "endMinute") var endMinutePlain: Int = 0
    /// The locked form of `endMinute`, empty until locking is turned on. Read and written through `endMinute` only.
    var endMinuteSealed: String? = nil

    var isActive: Bool = false

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
        self.daysOfWeekPlain = daysOfWeek

        self.startHourPlain = startTime.hour ?? 0
        self.startMinutePlain = startTime.minute ?? 0
        self.endHourPlain = endTime.hour ?? 0
        self.endMinutePlain = endTime.minute ?? 0

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

    var daysOfWeek: [Int] {
        get { FieldLock.readCoded(daysOfWeekPlain, sealed: daysOfWeekSealed, context: "TriggerWindow.daysOfWeek") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "TriggerWindow.daysOfWeek")
            daysOfWeekPlain = kept.plain
            daysOfWeekSealed = kept.sealed
        }
    }

    var startHour: Int {
        get { FieldLock.readScalar(plain: startHourPlain, sealed: startHourSealed, context: "TriggerWindow.startHour") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TriggerWindow.startHour")
            startHourPlain = kept.plain
            startHourSealed = kept.sealed
        }
    }

    var startMinute: Int {
        get { FieldLock.readScalar(plain: startMinutePlain, sealed: startMinuteSealed, context: "TriggerWindow.startMinute") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TriggerWindow.startMinute")
            startMinutePlain = kept.plain
            startMinuteSealed = kept.sealed
        }
    }

    var endHour: Int {
        get { FieldLock.readScalar(plain: endHourPlain, sealed: endHourSealed, context: "TriggerWindow.endHour") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TriggerWindow.endHour")
            endHourPlain = kept.plain
            endHourSealed = kept.sealed
        }
    }

    var endMinute: Int {
        get { FieldLock.readScalar(plain: endMinutePlain, sealed: endMinuteSealed, context: "TriggerWindow.endMinute") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TriggerWindow.endMinute")
            endMinutePlain = kept.plain
            endMinuteSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        daysOfWeek = daysOfWeekPlain
        startHour = startHourPlain
        startMinute = startMinutePlain
        endHour = endHourPlain
        endMinute = endMinutePlain
        label = labelPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if daysOfWeekSealed == nil { daysOfWeek = daysOfWeekPlain }
        if startHourSealed == nil { startHour = startHourPlain }
        if startMinuteSealed == nil { startMinute = startMinutePlain }
        if endHourSealed == nil { endHour = endHourPlain }
        if endMinuteSealed == nil { endMinute = endMinutePlain }
        if labelSealed == nil { label = labelPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(daysOfWeek),
            FieldLock.describe(startHour),
            FieldLock.describe(startMinute),
            FieldLock.describe(endHour),
            FieldLock.describe(endMinute),
            FieldLock.describe(label)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        daysOfWeekSealed != nil && daysOfWeekPlain.isEmpty
            && startHourSealed != nil && startHourPlain == Int.lockedPlaceholder
            && startMinuteSealed != nil && startMinutePlain == Int.lockedPlaceholder
            && endHourSealed != nil && endHourPlain == Int.lockedPlaceholder
            && endMinuteSealed != nil && endMinutePlain == Int.lockedPlaceholder
            && labelSealed != nil && labelPlain.isEmpty
    }
}

/// Appointments are a recurring RULE (e.g. "usually Tuesdays 4pm") plus
/// individually-editable occurrences, because real life moves sessions
/// around. Never a hardcoded fixed interval.
@Model
final class AppointmentSeries {
    var id: UUID = UUID()
    @Attribute(originalName: "clinicianLabel") var clinicianLabelPlain: String = ""
    /// The locked form of `clinicianLabel`, empty until locking is turned on. Read and written through `clinicianLabel` only.
    var clinicianLabelSealed: String? = nil
    @Attribute(originalName: "typicalDayOfWeek") var typicalDayOfWeekPlain: Int?
    /// The locked form of `typicalDayOfWeek`, empty until locking is turned on. Read and written through `typicalDayOfWeek` only.
    var typicalDayOfWeekSealed: String? = nil

    // Stored separately because DateComponents contains Calendar internally.
    @Attribute(originalName: "typicalHour") var typicalHourPlain: Int?
    /// The locked form of `typicalHour`, empty until locking is turned on. Read and written through `typicalHour` only.
    var typicalHourSealed: String? = nil
    @Attribute(originalName: "typicalMinute") var typicalMinutePlain: Int?
    /// The locked form of `typicalMinute`, empty until locking is turned on. Read and written through `typicalMinute` only.
    var typicalMinuteSealed: String? = nil

    @Attribute(originalName: "typicalCadenceDays") var typicalCadenceDaysPlain: Int = 0
    /// The locked form of `typicalCadenceDays`, empty until locking is turned on. Read and written through `typicalCadenceDays` only.
    var typicalCadenceDaysSealed: String? = nil

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

    /// Patch SY1b-pre: optional with an inverse, which CloudKit asks of a relationship. Read and changed through
    /// `occurrenceList`, which is never nil, so the rest of the app is unchanged. The stored name is the same as before.
    @Relationship(deleteRule: .cascade, inverse: \AppointmentOccurrence.series)
    var occurrences: [AppointmentOccurrence]? = []

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
        self.typicalDayOfWeekPlain = typicalDayOfWeek

        self.typicalHourPlain = typicalTime?.hour
        self.typicalMinutePlain = typicalTime?.minute

        self.typicalCadenceDaysPlain = typicalCadenceDays
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

    /// The sessions of this series, never nil. Use this instead of `occurrences`.
    var occurrenceList: [AppointmentOccurrence] {
        get { occurrences ?? [] }
        set { occurrences = newValue }
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

    var typicalDayOfWeek: Int? {
        get { FieldLock.readOptionalScalar(plain: typicalDayOfWeekPlain, sealed: typicalDayOfWeekSealed, context: "AppointmentSeries.typicalDayOfWeek") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "AppointmentSeries.typicalDayOfWeek")
            typicalDayOfWeekPlain = kept.plain
            typicalDayOfWeekSealed = kept.sealed
        }
    }

    var typicalHour: Int? {
        get { FieldLock.readOptionalScalar(plain: typicalHourPlain, sealed: typicalHourSealed, context: "AppointmentSeries.typicalHour") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "AppointmentSeries.typicalHour")
            typicalHourPlain = kept.plain
            typicalHourSealed = kept.sealed
        }
    }

    var typicalMinute: Int? {
        get { FieldLock.readOptionalScalar(plain: typicalMinutePlain, sealed: typicalMinuteSealed, context: "AppointmentSeries.typicalMinute") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "AppointmentSeries.typicalMinute")
            typicalMinutePlain = kept.plain
            typicalMinuteSealed = kept.sealed
        }
    }

    var typicalCadenceDays: Int {
        get { FieldLock.readScalar(plain: typicalCadenceDaysPlain, sealed: typicalCadenceDaysSealed, context: "AppointmentSeries.typicalCadenceDays") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "AppointmentSeries.typicalCadenceDays")
            typicalCadenceDaysPlain = kept.plain
            typicalCadenceDaysSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        typicalDayOfWeek = typicalDayOfWeekPlain
        typicalHour = typicalHourPlain
        typicalMinute = typicalMinutePlain
        typicalCadenceDays = typicalCadenceDaysPlain
        clinicianLabel = clinicianLabelPlain
        role = rolePlain
        exportLabel = exportLabelPlain
        notes = notesPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if typicalDayOfWeekSealed == nil { typicalDayOfWeek = typicalDayOfWeekPlain }
        if typicalHourSealed == nil { typicalHour = typicalHourPlain }
        if typicalMinuteSealed == nil { typicalMinute = typicalMinutePlain }
        if typicalCadenceDaysSealed == nil { typicalCadenceDays = typicalCadenceDaysPlain }
        if clinicianLabelSealed == nil { clinicianLabel = clinicianLabelPlain }
        if roleSealed == nil { role = rolePlain }
        if exportLabelSealed == nil { exportLabel = exportLabelPlain }
        if notesSealed == nil { notes = notesPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(typicalDayOfWeek),
            FieldLock.describe(typicalHour),
            FieldLock.describe(typicalMinute),
            FieldLock.describe(typicalCadenceDays),
            FieldLock.describe(clinicianLabel),
            FieldLock.describe(role),
            FieldLock.describe(exportLabel),
            FieldLock.describe(notes)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        typicalDayOfWeekSealed != nil && typicalDayOfWeekPlain == nil
            && typicalHourSealed != nil && typicalHourPlain == nil
            && typicalMinuteSealed != nil && typicalMinutePlain == nil
            && typicalCadenceDaysSealed != nil && typicalCadenceDaysPlain == Int.lockedPlaceholder
            && clinicianLabelSealed != nil && clinicianLabelPlain.isEmpty
            && roleSealed != nil && rolePlain.isEmpty
            && exportLabelSealed != nil && exportLabelPlain.isEmpty
            && notesSealed != nil && notesPlain.isEmpty
    }
}

@Model
final class AppointmentOccurrence {
    var id: UUID = UUID()
    @Attribute(originalName: "scheduledDate") var scheduledDatePlain: Date = Date(timeIntervalSinceReferenceDate: 0) // editable independent of the series rule
    /// The locked form of `scheduledDate`, empty until locking is turned on. Read and written through `scheduledDate` only.
    var scheduledDateSealed: String? = nil
    @Attribute(originalName: "wasMoved") var wasMovedPlain: Bool = false
    /// The locked form of `wasMoved`, empty until locking is turned on. Read and written through `wasMoved` only.
    var wasMovedSealed: String? = nil
    var prepNoteEntryID: UUID?    // links to a Journal/Bridge prep entry
    var postSessionNoteEntryID: UUID?
    /// The series this session belongs to: the other end of `AppointmentSeries.occurrences` (Patch SY1b-pre).
    var series: AppointmentSeries?
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
        self.scheduledDatePlain = scheduledDate
        self.wasMovedPlain = wasMoved
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

    var scheduledDate: Date {
        get { FieldLock.readScalar(plain: scheduledDatePlain, sealed: scheduledDateSealed, context: "AppointmentOccurrence.scheduledDate") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "AppointmentOccurrence.scheduledDate")
            scheduledDatePlain = kept.plain
            scheduledDateSealed = kept.sealed
        }
    }

    var wasMoved: Bool {
        get { FieldLock.readScalar(plain: wasMovedPlain, sealed: wasMovedSealed, context: "AppointmentOccurrence.wasMoved") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "AppointmentOccurrence.wasMoved")
            wasMovedPlain = kept.plain
            wasMovedSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        scheduledDate = scheduledDatePlain
        wasMoved = wasMovedPlain
        prepChecklist = prepChecklistPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if scheduledDateSealed == nil { scheduledDate = scheduledDatePlain }
        if wasMovedSealed == nil { wasMoved = wasMovedPlain }
        if prepChecklistSealed == nil { prepChecklist = prepChecklistPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(scheduledDate),
            FieldLock.describe(wasMoved),
            FieldLock.describe(prepChecklist)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        scheduledDateSealed != nil && scheduledDatePlain == Date.lockedPlaceholder
            && wasMovedSealed != nil && wasMovedPlain == Bool.lockedPlaceholder
            && prepChecklistSealed != nil && prepChecklistPlain.isEmpty
    }
}

// MARK: - Bridge

@Model
final class BridgeDraftItem {
    var id: UUID = UUID()
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    @Attribute(originalName: "isResolved") var isResolvedPlain: Bool = false // "brought this up already" — not a score, just a checkbox
    /// The locked form of `isResolved`, empty until locking is turned on. Read and written through `isResolved` only.
    var isResolvedSealed: String? = nil
    /// True when the item is a question to ask rather than something to raise.
    @Attribute(originalName: "isQuestion") var isQuestionPlain: Bool = false
    /// What was said in answer, written by the person after the session.
    /// The locked form of `isQuestion`, empty until locking is turned on. Read and written through `isQuestion` only.
    var isQuestionSealed: String? = nil
    /// Only used when the item is a question.
    @Attribute(originalName: "answer") var answerPlain: String = ""
    /// The locked form of `answer`, empty until locking is turned on. Read and written through `answer` only.
    var answerSealed: String? = nil
    /// The provider (an `AppointmentSeries` id) this is for. Nil means it is
    /// for anyone. Kept as a plain id rather than a relationship, so removing
    /// a provider can never remove an item.
    var providerID: UUID? = nil
    /// The Journal entry this item was made from, when Tidy a braindump made it from one (Patch AI4). Only a trace
    /// back to the words it came from: nothing reads the entry through it and the entry is never changed. A
    /// deleted entry leaves it pointing at nothing.
    var sourceEntryID: UUID? = nil

    init(id: UUID = UUID(), createdAt: Date = .now, text: String, isResolved: Bool = false,
         isQuestion: Bool = false, answer: String = "", providerID: UUID? = nil, sourceEntryID: UUID? = nil) {
        self.id = id
        self.createdAtPlain = createdAt
        self.textPlain = text
        self.isResolvedPlain = isResolved
        self.isQuestionPlain = isQuestion
        self.answerPlain = answer
        self.providerID = providerID
        self.sourceEntryID = sourceEntryID
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

    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "BridgeDraftItem.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "BridgeDraftItem.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }
    var isResolved: Bool {
        get { FieldLock.readScalar(plain: isResolvedPlain, sealed: isResolvedSealed, context: "BridgeDraftItem.isResolved") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "BridgeDraftItem.isResolved")
            isResolvedPlain = kept.plain
            isResolvedSealed = kept.sealed
        }
    }
    var isQuestion: Bool {
        get { FieldLock.readScalar(plain: isQuestionPlain, sealed: isQuestionSealed, context: "BridgeDraftItem.isQuestion") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "BridgeDraftItem.isQuestion")
            isQuestionPlain = kept.plain
            isQuestionSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        createdAt = createdAtPlain
        isResolved = isResolvedPlain
        isQuestion = isQuestionPlain
        text = textPlain
        answer = answerPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if isResolvedSealed == nil { isResolved = isResolvedPlain }
        if isQuestionSealed == nil { isQuestion = isQuestionPlain }
        if textSealed == nil { text = textPlain }
        if answerSealed == nil { answer = answerPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(createdAt),
            FieldLock.describe(isResolved),
            FieldLock.describe(isQuestion),
            FieldLock.describe(text),
            FieldLock.describe(answer)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && isResolvedSealed != nil && isResolvedPlain == Bool.lockedPlaceholder
            && isQuestionSealed != nil && isQuestionPlain == Bool.lockedPlaceholder
            && textSealed != nil && textPlain.isEmpty
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
        // Photo, card, AI Optimised and voice note lines are blocks, not words, so they are skipped.
        guard let first = text.split(separator: "\n")
            .map({ $0.trimmingCharacters(in: .whitespaces) })
            .first(where: { !$0.isEmpty && !$0.hasPrefix("![") && !$0.contains("](anchorcard://") && !$0.contains("](anchorassist://") && !$0.contains("](anchorvoice://") }) else { return nil }
        let marks = CharacterSet(charactersIn: "#-*>").union(.whitespaces)
        let cleaned = first.trimmingCharacters(in: marks)
        guard !cleaned.isEmpty else { return nil }
        return BridgeDraftItem(text: String(cleaned.prefix(160)))
    }
}

@Model
final class FeedbackLoopDiagram {
    var id: UUID = UUID()
    @Attribute(originalName: "title") var titlePlain: String = ""
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "lastEditedAt") var lastEditedAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `lastEditedAt`, empty until locking is turned on. Read and written through `lastEditedAt` only.
    var lastEditedAtSealed: String? = nil
    /// Serialized node/edge graph the user builds to externalize their own
    /// systems metaphors (e.g. the "like Cloudflare" defense model). Stored
    /// as JSON so the diagram editor can be swapped out without migrating data.
    @Attribute(originalName: "graphJSON") var graphJSONPlain: Data = Data()
    /// The locked form of `graphJSON`, empty until locking is turned on. Read and written through `graphJSON` only.
    var graphJSONSealed: String? = nil

    init(id: UUID = UUID(), title: String, lastEditedAt: Date = .now, graphJSON: Data) {
        self.id = id
        self.titlePlain = title
        self.lastEditedAtPlain = lastEditedAt
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

    var lastEditedAt: Date {
        get { FieldLock.readScalar(plain: lastEditedAtPlain, sealed: lastEditedAtSealed, context: "FeedbackLoopDiagram.lastEditedAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "FeedbackLoopDiagram.lastEditedAt")
            lastEditedAtPlain = kept.plain
            lastEditedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        lastEditedAt = lastEditedAtPlain
        title = titlePlain
        graphJSON = graphJSONPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if lastEditedAtSealed == nil { lastEditedAt = lastEditedAtPlain }
        if titleSealed == nil { title = titlePlain }
        if graphJSONSealed == nil { graphJSON = graphJSONPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(lastEditedAt),
            FieldLock.describe(title),
            FieldLock.describe(graphJSON)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        lastEditedAtSealed != nil && lastEditedAtPlain == Date.lockedPlaceholder
            && titleSealed != nil && titlePlain.isEmpty
            && graphJSONSealed != nil && graphJSONPlain.isEmpty
    }
}

// MARK: - Thread

@Model
final class ThreadMessage {
    var id: UUID = UUID()
    @Attribute(originalName: "timestamp") var timestampPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `timestamp`, empty until locking is turned on. Read and written through `timestamp` only.
    var timestampSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var audioFileName: String?
    var withContactID: UUID?
    /// The day a follow-up reminder was asked for when this was written and sent, as the start of
    /// that day. Empty unless the person chose one. Nothing is inferred and nothing sets it by itself.
    @Attribute(originalName: "followUpAt") var followUpAtPlain: Date?
    /// The locked form of `followUpAt`, empty until locking is turned on. Read and written through `followUpAt` only.
    var followUpAtSealed: String? = nil

    init(id: UUID = UUID(), timestamp: Date = .now, text: String,
         audioFileName: String? = nil, withContactID: UUID? = nil, followUpAt: Date? = nil) {
        self.id = id
        self.timestampPlain = timestamp
        self.textPlain = text
        self.audioFileName = audioFileName
        self.withContactID = withContactID
        self.followUpAtPlain = followUpAt
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

    var timestamp: Date {
        get { FieldLock.readScalar(plain: timestampPlain, sealed: timestampSealed, context: "ThreadMessage.timestamp") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "ThreadMessage.timestamp")
            timestampPlain = kept.plain
            timestampSealed = kept.sealed
        }
    }
    var followUpAt: Date? {
        get { FieldLock.readOptionalScalar(plain: followUpAtPlain, sealed: followUpAtSealed, context: "ThreadMessage.followUpAt") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "ThreadMessage.followUpAt")
            followUpAtPlain = kept.plain
            followUpAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        timestamp = timestampPlain
        followUpAt = followUpAtPlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if timestampSealed == nil { timestamp = timestampPlain }
        if followUpAtSealed == nil { followUpAt = followUpAtPlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(timestamp),
            FieldLock.describe(followUpAt),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        timestampSealed != nil && timestampPlain == Date.lockedPlaceholder
            && followUpAtSealed != nil && followUpAtPlain == nil
            && textSealed != nil && textPlain.isEmpty
    }
}

@Model
final class SupportCalendarEntry {
    var id: UUID = UUID()
    @Attribute(originalName: "date") var datePlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `date`, empty until locking is turned on. Read and written through `date` only.
    var dateSealed: String? = nil
    @Attribute(originalName: "note") var notePlain: String = ""
    /// The locked form of `note`, empty until locking is turned on. Read and written through `note` only.
    var noteSealed: String? = nil
    var visibleToContactIDs: [UUID] = [] // explicit opt-in list, not "everyone"

    init(id: UUID = UUID(), date: Date, note: String, visibleToContactIDs: [UUID] = []) {
        self.id = id
        self.datePlain = date
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

    var date: Date {
        get { FieldLock.readScalar(plain: datePlain, sealed: dateSealed, context: "SupportCalendarEntry.date") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "SupportCalendarEntry.date")
            datePlain = kept.plain
            dateSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        date = datePlain
        note = notePlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if dateSealed == nil { date = datePlain }
        if noteSealed == nil { note = notePlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(date),
            FieldLock.describe(note)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        dateSealed != nil && datePlain == Date.lockedPlaceholder
            && noteSealed != nil && notePlain.isEmpty
    }
}

@Model
final class FutureNote {
    var id: UUID = UUID()
    @Attribute(originalName: "writtenAt") var writtenAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `writtenAt`, empty until locking is turned on. Read and written through `writtenAt` only.
    var writtenAtSealed: String? = nil
    @Attribute(originalName: "unlockDate") var unlockDatePlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `unlockDate`, empty until locking is turned on. Read and written through `unlockDate` only.
    var unlockDateSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    @Attribute(originalName: "isUnlocked") var isUnlockedPlain: Bool = false // derived at read-time from unlockDate, cached here for widget/UI convenience
    /// The locked form of `isUnlocked`, empty until locking is turned on. Read and written through `isUnlocked` only.
    var isUnlockedSealed: String? = nil
    /// What the person wrote after "Open when", for a letter they open when
    /// they choose. Empty for a note sealed until a date. A letter has no
    /// date to wait for, and nothing opens it, counts it or reminds them of it.
    @Attribute(originalName: "openWhen") var openWhenPlain: String = ""
    /// The locked form of `openWhen`, empty until locking is turned on. Read and written through `openWhen` only.
    var openWhenSealed: String? = nil

    init(id: UUID = UUID(), writtenAt: Date = .now, unlockDate: Date, text: String, openWhen: String = "") {
        self.id = id
        self.writtenAtPlain = writtenAt
        self.unlockDatePlain = unlockDate
        self.textPlain = text
        self.isUnlockedPlain = false
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

    var writtenAt: Date {
        get { FieldLock.readScalar(plain: writtenAtPlain, sealed: writtenAtSealed, context: "FutureNote.writtenAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "FutureNote.writtenAt")
            writtenAtPlain = kept.plain
            writtenAtSealed = kept.sealed
        }
    }
    var unlockDate: Date {
        get { FieldLock.readScalar(plain: unlockDatePlain, sealed: unlockDateSealed, context: "FutureNote.unlockDate") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "FutureNote.unlockDate")
            unlockDatePlain = kept.plain
            unlockDateSealed = kept.sealed
        }
    }
    var isUnlocked: Bool {
        get { FieldLock.readScalar(plain: isUnlockedPlain, sealed: isUnlockedSealed, context: "FutureNote.isUnlocked") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "FutureNote.isUnlocked")
            isUnlockedPlain = kept.plain
            isUnlockedSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        writtenAt = writtenAtPlain
        unlockDate = unlockDatePlain
        isUnlocked = isUnlockedPlain
        text = textPlain
        openWhen = openWhenPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if writtenAtSealed == nil { writtenAt = writtenAtPlain }
        if unlockDateSealed == nil { unlockDate = unlockDatePlain }
        if isUnlockedSealed == nil { isUnlocked = isUnlockedPlain }
        if textSealed == nil { text = textPlain }
        if openWhenSealed == nil { openWhen = openWhenPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(writtenAt),
            FieldLock.describe(unlockDate),
            FieldLock.describe(isUnlocked),
            FieldLock.describe(text),
            FieldLock.describe(openWhen)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        writtenAtSealed != nil && writtenAtPlain == Date.lockedPlaceholder
            && unlockDateSealed != nil && unlockDatePlain == Date.lockedPlaceholder
            && isUnlockedSealed != nil && isUnlockedPlain == Bool.lockedPlaceholder
            && textSealed != nil && textPlain.isEmpty
            && openWhenSealed != nil && openWhenPlain.isEmpty
    }
}

@Model
final class UnsentDraft {
    var id: UUID = UUID()
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    @Attribute(originalName: "recipientLabel") var recipientLabelPlain: String = "" // "partner", "school friend", etc — no full identity required
    /// The locked form of `recipientLabel`, empty until locking is turned on. Read and written through `recipientLabel` only.
    var recipientLabelSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    @Attribute(originalName: "wasSent") var wasSentPlain: Bool = false
    /// The locked form of `wasSent`, empty until locking is turned on. Read and written through `wasSent` only.
    var wasSentSealed: String? = nil

    init(id: UUID = UUID(), createdAt: Date = .now, recipientLabel: String, text: String, wasSent: Bool = false) {
        self.id = id
        self.createdAtPlain = createdAt
        self.recipientLabelPlain = recipientLabel
        self.textPlain = text
        self.wasSentPlain = wasSent
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

    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "UnsentDraft.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "UnsentDraft.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }
    var wasSent: Bool {
        get { FieldLock.readScalar(plain: wasSentPlain, sealed: wasSentSealed, context: "UnsentDraft.wasSent") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "UnsentDraft.wasSent")
            wasSentPlain = kept.plain
            wasSentSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        createdAt = createdAtPlain
        wasSent = wasSentPlain
        recipientLabel = recipientLabelPlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if wasSentSealed == nil { wasSent = wasSentPlain }
        if recipientLabelSealed == nil { recipientLabel = recipientLabelPlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(createdAt),
            FieldLock.describe(wasSent),
            FieldLock.describe(recipientLabel),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && wasSentSealed != nil && wasSentPlain == Bool.lockedPlaceholder
            && recipientLabelSealed != nil && recipientLabelPlain.isEmpty
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
    var id: UUID = UUID()
    @Attribute(originalName: "name") var namePlain: String = ""
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    var sortOrder: Int = 0
    /// Patch SY1b-pre: optional, as CloudKit asks. Read and changed through `choiceList`, which is never nil.
    @Relationship(deleteRule: .cascade, inverse: \DecisionPresetChoice.category)
    var choices: [DecisionPresetChoice]? = []

    /// The choices in this group, never nil. Use this instead of `choices`.
    var choiceList: [DecisionPresetChoice] {
        get { choices ?? [] }
        set { choices = newValue }
    }

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
    var id: UUID = UUID()
    @Attribute(originalName: "name") var namePlain: String = ""
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    /// One step per line, same convention as GroundingTool.steps. Empty
    /// means this is just a flat option with no click-through sequence.
    @Attribute(originalName: "steps") var stepsPlain: String = ""
    /// The locked form of `steps`, empty until locking is turned on. Read and written through `steps` only.
    var stepsSealed: String? = nil
    var sortOrder: Int = 0
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
    var id: UUID = UUID()
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var sortOrder: Int = 0

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
    var id: UUID = UUID()
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var sortOrder: Int = 0

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
    var id: UUID = UUID()
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    @Attribute(originalName: "isDone") var isDonePlain: Bool = false
    /// The locked form of `isDone`, empty until locking is turned on. Read and written through `isDone` only.
    var isDoneSealed: String? = nil
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    var reminderIdentifier: String?

    init(id: UUID = UUID(), text: String, isDone: Bool = false, createdAt: Date = .now, reminderIdentifier: String? = nil) {
        self.id = id
        self.textPlain = text
        self.isDonePlain = isDone
        self.createdAtPlain = createdAt
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

    var isDone: Bool {
        get { FieldLock.readScalar(plain: isDonePlain, sealed: isDoneSealed, context: "NextHourItem.isDone") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "NextHourItem.isDone")
            isDonePlain = kept.plain
            isDoneSealed = kept.sealed
        }
    }

    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "NextHourItem.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "NextHourItem.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        isDone = isDonePlain
        createdAt = createdAtPlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if isDoneSealed == nil { isDone = isDonePlain }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(isDone),
            FieldLock.describe(createdAt),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        isDoneSealed != nil && isDonePlain == Bool.lockedPlaceholder
            && createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && textSealed != nil && textPlain.isEmpty
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
    var id: UUID = UUID()
    @Attribute(originalName: "title") var titlePlain: String = ""
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "notes") var notesPlain: String = ""
    /// The locked form of `notes`, empty until locking is turned on. Read and written through `notes` only.
    var notesSealed: String? = nil
    @Attribute(originalName: "isDone") var isDonePlain: Bool = false
    /// The locked form of `isDone`, empty until locking is turned on. Read and written through `isDone` only.
    var isDoneSealed: String? = nil
    @Attribute(originalName: "completedAt") var completedAtPlain: Date? = nil
    /// The locked form of `completedAt`, empty until locking is turned on. Read and written through `completedAt` only.
    var completedAtSealed: String? = nil
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date.now
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    var sortOrder: Int = 0
    var reminderIdentifier: String? = nil
    /// How the task is timed. `dueDate` holds the exact day for `.exact`, and
    /// the last moment of the day, week or month for those loose choices, so
    /// that a plan which has passed can be told apart from one still ahead.
    @Attribute(originalName: "dueKind") var dueKindPlain: TaskDueKind = TaskDueKind.noDate
    /// The locked form of `dueKind`, empty until locking is turned on. Read and written through `dueKind` only.
    var dueKindSealed: String? = nil
    @Attribute(originalName: "dueDate") var dueDatePlain: Date? = nil
    /// The locked form of `dueDate`, empty until locking is turned on. Read and written through `dueDate` only.
    var dueDateSealed: String? = nil
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
    @Attribute(originalName: "status") var statusPlain: TaskStatus = TaskStatus.notStarted
    /// The locked form of `status`, empty until locking is turned on. Read and written through `status` only.
    var statusSealed: String? = nil
    /// How much energy the task needs, if you have said. Only used to narrow
    /// the list on a low day; nothing is scored or compared.
    @Attribute(originalName: "energy") var energyPlain: TaskEnergy = TaskEnergy.unset
    /// The locked form of `energy`, empty until locking is turned on. Read and written through `energy` only.
    var energySealed: String? = nil
    /// The smallest way to begin, in a few words. Separate from steps so it
    /// can be a single line.
    @Attribute(originalName: "firstStep") var firstStepPlain: String = ""
    /// The locked form of `firstStep`, empty until locking is turned on. Read and written through `firstStep` only.
    var firstStepSealed: String? = nil
    /// How many focus sessions have run to the end on this task, and the
    /// minutes they added up to. A plain record: nothing is scored, compared
    /// or shown against a goal.
    @Attribute(originalName: "focusSessions") var focusSessionsPlain: Int = 0
    /// The locked form of `focusSessions`, empty until locking is turned on. Read and written through `focusSessions` only.
    var focusSessionsSealed: String? = nil
    @Attribute(originalName: "focusMinutes") var focusMinutesPlain: Int = 0
    /// The locked form of `focusMinutes`, empty until locking is turned on. Read and written through `focusMinutes` only.
    var focusMinutesSealed: String? = nil
    /// A rough guess at how long the task takes, in minutes. 0 means no
    /// estimate. Only used to add up a day's plan; nothing is checked against it.
    @Attribute(originalName: "estimateMinutes") var estimateMinutesPlain: Int = 0
    /// The locked form of `estimateMinutes`, empty until locking is turned on. Read and written through `estimateMinutes` only.
    var estimateMinutesSealed: String? = nil
    /// The Journal entry this task was made from, when a tool made it from one (Patch AI3; Tidy a braindump sets it,
    /// Patch AI4). Nothing reads the entry through it: it is only a trace back to the words the task came from,
    /// and the entry is never changed. A deleted entry leaves it pointing at nothing.
    var sourceEntryID: UUID? = nil

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
        estimateMinutes: Int = 0,
        sourceEntryID: UUID? = nil
    ) {
        self.id = id
        self.titlePlain = title
        self.notesPlain = notes
        self.isDonePlain = isDone
        self.completedAtPlain = completedAt
        self.createdAtPlain = createdAt
        self.sortOrder = sortOrder
        self.reminderIdentifier = reminderIdentifier
        self.dueKindPlain = dueKind
        self.dueDatePlain = dueDate
        self.parentID = parentID
        self.subtasksCollapsed = subtasksCollapsed
        self.blockedByIDs = blockedByIDs
        self.statusPlain = status
        self.energyPlain = energy
        self.firstStepPlain = firstStep
        self.focusSessionsPlain = focusSessions
        self.focusMinutesPlain = focusMinutes
        self.estimateMinutesPlain = estimateMinutes
        self.sourceEntryID = sourceEntryID
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

    var isDone: Bool {
        get { FieldLock.readScalar(plain: isDonePlain, sealed: isDoneSealed, context: "TaskItem.isDone") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TaskItem.isDone")
            isDonePlain = kept.plain
            isDoneSealed = kept.sealed
        }
    }

    var completedAt: Date? {
        get { FieldLock.readOptionalScalar(plain: completedAtPlain, sealed: completedAtSealed, context: "TaskItem.completedAt") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "TaskItem.completedAt")
            completedAtPlain = kept.plain
            completedAtSealed = kept.sealed
        }
    }

    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "TaskItem.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TaskItem.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }

    var dueKind: TaskDueKind {
        get { FieldLock.readChoice(plain: dueKindPlain, sealed: dueKindSealed, context: "TaskItem.dueKind") }
        set {
            let kept = FieldLock.storeChoice(newValue, context: "TaskItem.dueKind")
            dueKindPlain = kept.plain
            dueKindSealed = kept.sealed
        }
    }

    var dueDate: Date? {
        get { FieldLock.readOptionalScalar(plain: dueDatePlain, sealed: dueDateSealed, context: "TaskItem.dueDate") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "TaskItem.dueDate")
            dueDatePlain = kept.plain
            dueDateSealed = kept.sealed
        }
    }

    var status: TaskStatus {
        get { FieldLock.readChoice(plain: statusPlain, sealed: statusSealed, context: "TaskItem.status") }
        set {
            let kept = FieldLock.storeChoice(newValue, context: "TaskItem.status")
            statusPlain = kept.plain
            statusSealed = kept.sealed
        }
    }

    var energy: TaskEnergy {
        get { FieldLock.readChoice(plain: energyPlain, sealed: energySealed, context: "TaskItem.energy") }
        set {
            let kept = FieldLock.storeChoice(newValue, context: "TaskItem.energy")
            energyPlain = kept.plain
            energySealed = kept.sealed
        }
    }

    var focusSessions: Int {
        get { FieldLock.readScalar(plain: focusSessionsPlain, sealed: focusSessionsSealed, context: "TaskItem.focusSessions") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TaskItem.focusSessions")
            focusSessionsPlain = kept.plain
            focusSessionsSealed = kept.sealed
        }
    }

    var focusMinutes: Int {
        get { FieldLock.readScalar(plain: focusMinutesPlain, sealed: focusMinutesSealed, context: "TaskItem.focusMinutes") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TaskItem.focusMinutes")
            focusMinutesPlain = kept.plain
            focusMinutesSealed = kept.sealed
        }
    }

    var estimateMinutes: Int {
        get { FieldLock.readScalar(plain: estimateMinutesPlain, sealed: estimateMinutesSealed, context: "TaskItem.estimateMinutes") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "TaskItem.estimateMinutes")
            estimateMinutesPlain = kept.plain
            estimateMinutesSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        isDone = isDonePlain
        completedAt = completedAtPlain
        createdAt = createdAtPlain
        dueKind = dueKindPlain
        dueDate = dueDatePlain
        status = statusPlain
        energy = energyPlain
        focusSessions = focusSessionsPlain
        focusMinutes = focusMinutesPlain
        estimateMinutes = estimateMinutesPlain
        title = titlePlain
        notes = notesPlain
        firstStep = firstStepPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if isDoneSealed == nil { isDone = isDonePlain }
        if completedAtSealed == nil { completedAt = completedAtPlain }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if dueKindSealed == nil { dueKind = dueKindPlain }
        if dueDateSealed == nil { dueDate = dueDatePlain }
        if statusSealed == nil { status = statusPlain }
        if energySealed == nil { energy = energyPlain }
        if focusSessionsSealed == nil { focusSessions = focusSessionsPlain }
        if focusMinutesSealed == nil { focusMinutes = focusMinutesPlain }
        if estimateMinutesSealed == nil { estimateMinutes = estimateMinutesPlain }
        if titleSealed == nil { title = titlePlain }
        if notesSealed == nil { notes = notesPlain }
        if firstStepSealed == nil { firstStep = firstStepPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(isDone),
            FieldLock.describe(completedAt),
            FieldLock.describe(createdAt),
            FieldLock.describe(dueKind),
            FieldLock.describe(dueDate),
            FieldLock.describe(status),
            FieldLock.describe(energy),
            FieldLock.describe(focusSessions),
            FieldLock.describe(focusMinutes),
            FieldLock.describe(estimateMinutes),
            FieldLock.describe(title),
            FieldLock.describe(notes),
            FieldLock.describe(firstStep)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        isDoneSealed != nil && isDonePlain == Bool.lockedPlaceholder
            && completedAtSealed != nil && completedAtPlain == nil
            && createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && dueKindSealed != nil && dueKindPlain == TaskDueKind.lockedPlaceholder
            && dueDateSealed != nil && dueDatePlain == nil
            && statusSealed != nil && statusPlain == TaskStatus.lockedPlaceholder
            && energySealed != nil && energyPlain == TaskEnergy.lockedPlaceholder
            && focusSessionsSealed != nil && focusSessionsPlain == Int.lockedPlaceholder
            && focusMinutesSealed != nil && focusMinutesPlain == Int.lockedPlaceholder
            && estimateMinutesSealed != nil && estimateMinutesPlain == Int.lockedPlaceholder
            && titleSealed != nil && titlePlain.isEmpty
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
        // Sorted after the items are opened, because a locked date cannot be sorted by the database (Patch 35g3).
        guard let fetched = try? context.fetch(FetchDescriptor<NextHourItem>()) else { return }
        let old = fetched.sortedByKey { $0.createdAt }
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
    var id: UUID = UUID()
    @Attribute(originalName: "title") var titlePlain: String = ""
    /// The locked form of `title`, empty until locking is turned on. Read and written through `title` only.
    var titleSealed: String? = nil
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date.now
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    @Attribute(originalName: "items") var itemsPlain: [QuickListItem] = []
    /// The locked form of `items`, empty until locking is turned on. Read and written through `items` only.
    var itemsSealed: String? = nil
    /// Set when the last open item is ticked, and cleared again when one is
    /// unticked or a new item is added. nil while the list is still in use.
    @Attribute(originalName: "archivedAt") var archivedAtPlain: Date? = nil
    /// The locked form of `archivedAt`, empty until locking is turned on. Read and written through `archivedAt` only.
    var archivedAtSealed: String? = nil

    init(id: UUID = UUID(), title: String, createdAt: Date = .now,
         items: [QuickListItem] = [], archivedAt: Date? = nil) {
        self.id = id
        self.titlePlain = title
        self.createdAtPlain = createdAt
        self.itemsPlain = items
        self.archivedAtPlain = archivedAt
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

    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "QuickList.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "QuickList.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }

    var archivedAt: Date? {
        get { FieldLock.readOptionalScalar(plain: archivedAtPlain, sealed: archivedAtSealed, context: "QuickList.archivedAt") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "QuickList.archivedAt")
            archivedAtPlain = kept.plain
            archivedAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        createdAt = createdAtPlain
        archivedAt = archivedAtPlain
        title = titlePlain
        items = itemsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if archivedAtSealed == nil { archivedAt = archivedAtPlain }
        if titleSealed == nil { title = titlePlain }
        if itemsSealed == nil { items = itemsPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(createdAt),
            FieldLock.describe(archivedAt),
            FieldLock.describe(title),
            FieldLock.describe(items)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && archivedAtSealed != nil && archivedAtPlain == nil
            && titleSealed != nil && titlePlain.isEmpty
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
    var id: UUID = UUID()
    @Attribute(originalName: "name") var namePlain: String = ""
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date.now
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
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
        self.createdAtPlain = createdAt
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

    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "Routine.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "Routine.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        createdAt = createdAtPlain
        name = namePlain
        steps = stepsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if nameSealed == nil { name = namePlain }
        if stepsSealed == nil { steps = stepsPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(createdAt),
            FieldLock.describe(name),
            FieldLock.describe(steps)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && nameSealed != nil && namePlain.isEmpty
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
    var id: UUID = UUID()
    @Attribute(originalName: "name") var namePlain: String = ""
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date.now
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
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
        self.createdAtPlain = createdAt
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

    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "ItemList.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "ItemList.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        createdAt = createdAtPlain
        name = namePlain
        variables = variablesPlain
        items = itemsPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if nameSealed == nil { name = namePlain }
        if variablesSealed == nil { variables = variablesPlain }
        if itemsSealed == nil { items = itemsPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(createdAt),
            FieldLock.describe(name),
            FieldLock.describe(variables),
            FieldLock.describe(items)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && nameSealed != nil && namePlain.isEmpty
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
    var id: UUID = UUID()
    var trigger: MascotTrigger = MascotTrigger.appOpen
    var mood: MascotMood = MascotMood.gentle
    var text: String = ""
    var isUserAuthored: Bool = false   // false = shipped with the reviewed content pack

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
        // No model declares a unique id any more (Patch SY0), so a second row with the same id is kept and not merged.
        // Where Anchor adds rows from outside (the backup import), it skips an id it already has. See
        // scripts/check-no-unique-ids.mjs.
        // Local-first: CloudKit is switched off explicitly (cloudKitDatabase: .none), because the iCloud entitlement is now present and the default would otherwise try to sync and validate the schema (Patch FIX2). No sync service. Data moves
        // only through explicit export/import, never a required third-party cloud.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            applyDataProtection(at: configuration.url)
            return container
        } catch {
            openedPersistentStore = false
            let temporary = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
extension CheckIn: LockableModel {}
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
