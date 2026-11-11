//
//  RecoveryModels.swift
//  Anchor
//
//  The optional Recovery area (v2): day counters, motivations, a daily
//  pledge and an evening review.
//
//  This is a deliberate, opt-in exception to the rule at the top of
//  AnchorModels.swift. A counter is a date the user chose ("the day I
//  stopped"), not a grade. Anchor never scores it, ranks it, compares it or
//  sends it anywhere. Each counter has its own day-count mode, so a slip never
//  has to erase what someone has built, and widgets and notifications use a
//  discreet label unless the user opts in for that counter.
//

import Foundation
import SwiftData

// MARK: - Settings types

enum DayCountMode: String, Codable, CaseIterable, Identifiable {
    case runAndTotal
    case classicStreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runAndTotal: return "Current run and total days"
        case .classicStreak: return "Classic streak"
        }
    }

    var explanation: String {
        switch self {
        case .runAndTotal:
            return "Shows your current run and every day you have gathered in total. If you slip, a new run begins and your total stays."
        case .classicStreak:
            return "One number. If you slip, it starts again from zero."
        }
    }
}

enum SavingsPeriod: String, Codable, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "per day"
        case .week: return "per week"
        case .month: return "per month"
        }
    }

    var lengthInDays: Double {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30.4375
        }
    }
}

enum MotivationKind: String, Codable, CaseIterable, Identifiable {
    case person
    case reason

    var id: String { rawValue }

    var sectionTitle: String {
        switch self {
        case .person: return "Who I'm doing this for"
        case .reason: return "Why it matters to me"
        }
    }
}

/// One unbroken stretch. `end == nil` means it is the current run.
struct RecoveryRun: Codable, Hashable {
    var start: Date
    var end: Date?
}

enum RecoveryText {
    static func days(_ n: Int) -> String { "\(n) \(n == 1 ? "day" : "days")" }
}

// Patch 35g1a: the choices on these models can be sealed as their raw text (D44). The case named here is only what
// the plain property holds while the real choice is sealed; it says nothing about anyone.
extension DayCountMode: LockedChoice { static var lockedPlaceholder: DayCountMode { .runAndTotal } }
extension SavingsPeriod: LockedChoice { static var lockedPlaceholder: SavingsPeriod { .day } }
extension MotivationKind: LockedChoice { static var lockedPlaceholder: MotivationKind { .person } }
extension UrgeStrength: LockedChoice { static var lockedPlaceholder: UrgeStrength { .mild } }

// MARK: - Milestones

enum RecoveryMilestones {
    static let early: [Int] = [1, 3, 7, 14, 21, 30, 60, 90, 120, 180, 270, 365]

    /// The next milestone strictly after `days`. After the first year they are yearly.
    static func next(after days: Int) -> Int {
        if let found = early.first(where: { $0 > days }) { return found }
        return (days / 365 + 1) * 365
    }

    /// Every milestone reached at `days`, in ascending order.
    static func reached(_ days: Int) -> [Int] {
        var result = early.filter { $0 <= days }
        var year = 2
        while year * 365 <= days {
            result.append(year * 365)
            year += 1
        }
        return result
    }

    static func label(_ days: Int) -> String {
        if days >= 365, days % 365 == 0 {
            let years = days / 365
            return "\(years) \(years == 1 ? "year" : "years")"
        }
        return RecoveryText.days(days)
    }
}

// MARK: - Counter

@Model
final class RecoveryCounter {
    var id: UUID = UUID()

    /// The user's own words, shown only inside the app unless they opt in below.
    @Attribute(originalName: "name") var namePlain: String = ""
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil

    /// What widgets and notifications call this counter, e.g. "Your counter".
    @Attribute(originalName: "discreetLabel") var discreetLabelPlain: String = ""
    /// The locked form of `discreetLabel`, empty until locking is turned on. Read and written through `discreetLabel` only.
    var discreetLabelSealed: String? = nil
    var showNameOutsideApp: Bool = false

    @Attribute(originalName: "mode") var modePlain: DayCountMode = DayCountMode.lockedPlaceholder

    /// JSON-encoded `[RecoveryRun]`. Stored as data so the schema stays simple.
    /// The locked form of `mode`, empty until locking is turned on. Read and written through `mode` only.
    var modeSealed: String? = nil
    @Attribute(originalName: "runsData") var runsDataPlain: Data = Data()
    /// The locked form of `runsData`, empty until locking is turned on. Read and written through `runsData` only.
    var runsDataSealed: String? = nil

    @Attribute(originalName: "savingsAmount") var savingsAmountPlain: Double = 0
    /// The locked form of `savingsAmount`, empty until locking is turned on. Read and written through `savingsAmount` only.
    var savingsAmountSealed: String? = nil
    @Attribute(originalName: "savingsPeriod") var savingsPeriodPlain: SavingsPeriod = SavingsPeriod.lockedPlaceholder
    /// The locked form of `savingsPeriod`, empty until locking is turned on. Read and written through `savingsPeriod` only.
    var savingsPeriodSealed: String? = nil
    @Attribute(originalName: "currencyCode") var currencyCodePlain: String = ""

    /// Milestones (in days) the user has already seen, so each is marked once.
    /// The locked form of `currencyCode`, empty until locking is turned on. Read and written through `currencyCode` only.
    var currencyCodeSealed: String? = nil
    @Attribute(originalName: "acknowledgedMilestones") var acknowledgedMilestonesPlain: [Int] = []
    /// The locked form of `acknowledgedMilestones`, empty until locking is turned on. Read and written through `acknowledgedMilestones` only.
    var acknowledgedMilestonesSealed: String? = nil

    var sortOrder: Int = 0
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil
    var isArchived: Bool = false

    /// "Before tracking, on a typical day, how many times did it happen?" Just a reference note.
    @Attribute(originalName: "priorTimesPerDay") var priorTimesPerDayPlain: Int = 0
    /// The locked form of `priorTimesPerDay`, empty until locking is turned on. Read and written through `priorTimesPerDay` only.
    var priorTimesPerDaySealed: String? = nil

    static var defaultCurrencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    init(id: UUID = UUID(),
         name: String,
         discreetLabel: String = "Your counter",
         showNameOutsideApp: Bool = false,
         mode: DayCountMode = .runAndTotal,
         startDate: Date = .now,
         savingsAmount: Double = 0,
         savingsPeriod: SavingsPeriod = .week,
         currencyCode: String = RecoveryCounter.defaultCurrencyCode,
         sortOrder: Int = 0,
         createdAt: Date = .now) {
        self.id = id
        self.namePlain = name
        self.discreetLabelPlain = discreetLabel
        self.showNameOutsideApp = showNameOutsideApp
        self.modePlain = mode
        self.runsDataPlain = (try? JSONEncoder().encode([RecoveryRun(start: startDate, end: nil)])) ?? Data()
        self.savingsAmountPlain = savingsAmount
        self.savingsPeriodPlain = savingsPeriod
        self.currencyCodePlain = currencyCode
        self.acknowledgedMilestonesPlain = []
        self.sortOrder = sortOrder
        self.createdAtPlain = createdAt
        self.isArchived = false
        self.priorTimesPerDayPlain = 0
        lockNewValues()
    }

    // MARK: Runs

    var runs: [RecoveryRun] {
        get { (try? JSONDecoder().decode([RecoveryRun].self, from: runsData)) ?? [] }
        set { runsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var currentRun: RecoveryRun? { runs.last(where: { $0.end == nil }) }

    /// Whole elapsed days (like a stopwatch): 23 hours is 0 days, 25 hours is 1.
    static func wholeDays(from start: Date, to end: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    func currentRunDays(now: Date = .now) -> Int {
        guard let run = currentRun else { return 0 }
        return RecoveryCounter.wholeDays(from: run.start, to: now)
    }

    /// The current run as a big number plus unit, never "0 days".
    func currentRunReading(now: Date = .now) -> ElapsedFormat.Reading {
        guard let run = currentRun else { return ElapsedFormat.reading(from: now, to: now) }
        return ElapsedFormat.reading(from: run.start, to: now)
    }

    /// "12 days", "3 hours", "just started".
    func currentRunPhrase(now: Date = .now) -> String {
        guard let run = currentRun else { return "just started" }
        return ElapsedFormat.phrase(from: run.start, to: now)
    }

    /// "12 days in", "3 hours in", "just getting started".
    func currentRunPhraseIn(now: Date = .now) -> String {
        guard let run = currentRun else { return "just getting started" }
        return ElapsedFormat.phraseIn(from: run.start, to: now)
    }

    /// Days in runs that have ended (not counting the current run).
    var completedRunsDays: Int {
        runs.filter { $0.end != nil }
            .reduce(0) { $0 + RecoveryCounter.wholeDays(from: $1.start, to: $1.end ?? $1.start) }
    }

    func totalDays(now: Date = .now) -> Int { completedRunsDays + currentRunDays(now: now) }

    /// Savings follow the counter's own mode: total days, or the current run for a classic streak.
    func daysCountedForSavings(now: Date = .now) -> Int {
        mode == .runAndTotal ? totalDays(now: now) : currentRunDays(now: now)
    }

    func savedAmount(now: Date = .now) -> Double {
        guard savingsAmount > 0 else { return 0 }
        return savingsAmount / savingsPeriod.lengthInDays * Double(daysCountedForSavings(now: now))
    }

    /// A slip ends the current run and begins a new one. Nothing is deleted.
    func recordSlip(on slipDate: Date, restartAt restart: Date) {
        var updated = runs
        if let index = updated.lastIndex(where: { $0.end == nil }) {
            updated[index].end = slipDate
        }
        updated.append(RecoveryRun(start: max(restart, slipDate), end: nil))
        runs = updated
        acknowledgedMilestones = []
    }

    func setCurrentRunStart(_ date: Date) {
        var updated = runs
        if let index = updated.lastIndex(where: { $0.end == nil }) {
            updated[index].start = date
        } else {
            updated.append(RecoveryRun(start: date, end: nil))
        }
        runs = updated
    }

    func timeline(now: Date = .now) -> RecoveryTimeline { RecoveryTimeline(runs: runs, now: now) }

    // MARK: Milestones

    func unacknowledgedMilestone(now: Date = .now) -> Int? {
        RecoveryMilestones.reached(currentRunDays(now: now))
            .last(where: { !acknowledgedMilestones.contains($0) })
    }

    func acknowledgeMilestones(now: Date = .now) {
        let reached = RecoveryMilestones.reached(currentRunDays(now: now))
        acknowledgedMilestones = Array(Set(acknowledgedMilestones + reached)).sorted()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension RecoveryCounter {
    var name: String {
        get { FieldLock.read(plain: namePlain, sealed: nameSealed, context: "RecoveryCounter.name") }
        set {
            let kept = FieldLock.store(newValue, context: "RecoveryCounter.name")
            namePlain = kept.plain
            nameSealed = kept.sealed
        }
    }
    var discreetLabel: String {
        get { FieldLock.read(plain: discreetLabelPlain, sealed: discreetLabelSealed, context: "RecoveryCounter.discreetLabel") }
        set {
            let kept = FieldLock.store(newValue, context: "RecoveryCounter.discreetLabel")
            discreetLabelPlain = kept.plain
            discreetLabelSealed = kept.sealed
        }
    }
    var runsData: Data {
        get { FieldLock.readData(runsDataPlain, sealed: runsDataSealed, context: "RecoveryCounter.runsData") }
        set {
            let kept = FieldLock.storeData(newValue, context: "RecoveryCounter.runsData")
            runsDataPlain = kept.plain
            runsDataSealed = kept.sealed
        }
    }

    var mode: DayCountMode {
        get { FieldLock.readChoice(plain: modePlain, sealed: modeSealed, context: "RecoveryCounter.mode") }
        set {
            let kept = FieldLock.storeChoice(newValue, context: "RecoveryCounter.mode")
            modePlain = kept.plain
            modeSealed = kept.sealed
        }
    }
    var savingsAmount: Double {
        get { FieldLock.readScalar(plain: savingsAmountPlain, sealed: savingsAmountSealed, context: "RecoveryCounter.savingsAmount") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "RecoveryCounter.savingsAmount")
            savingsAmountPlain = kept.plain
            savingsAmountSealed = kept.sealed
        }
    }
    var savingsPeriod: SavingsPeriod {
        get { FieldLock.readChoice(plain: savingsPeriodPlain, sealed: savingsPeriodSealed, context: "RecoveryCounter.savingsPeriod") }
        set {
            let kept = FieldLock.storeChoice(newValue, context: "RecoveryCounter.savingsPeriod")
            savingsPeriodPlain = kept.plain
            savingsPeriodSealed = kept.sealed
        }
    }
    var currencyCode: String {
        get { FieldLock.read(plain: currencyCodePlain, sealed: currencyCodeSealed, context: "RecoveryCounter.currencyCode") }
        set {
            let kept = FieldLock.store(newValue, context: "RecoveryCounter.currencyCode")
            currencyCodePlain = kept.plain
            currencyCodeSealed = kept.sealed
        }
    }
    var acknowledgedMilestones: [Int] {
        get { FieldLock.readCoded(acknowledgedMilestonesPlain, sealed: acknowledgedMilestonesSealed, context: "RecoveryCounter.acknowledgedMilestones") }
        set {
            let kept = FieldLock.storeCoded(newValue, empty: [], context: "RecoveryCounter.acknowledgedMilestones")
            acknowledgedMilestonesPlain = kept.plain
            acknowledgedMilestonesSealed = kept.sealed
        }
    }
    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "RecoveryCounter.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "RecoveryCounter.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }
    var priorTimesPerDay: Int {
        get { FieldLock.readScalar(plain: priorTimesPerDayPlain, sealed: priorTimesPerDaySealed, context: "RecoveryCounter.priorTimesPerDay") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "RecoveryCounter.priorTimesPerDay")
            priorTimesPerDayPlain = kept.plain
            priorTimesPerDaySealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        mode = modePlain
        savingsAmount = savingsAmountPlain
        savingsPeriod = savingsPeriodPlain
        currencyCode = currencyCodePlain
        acknowledgedMilestones = acknowledgedMilestonesPlain
        createdAt = createdAtPlain
        priorTimesPerDay = priorTimesPerDayPlain
        name = namePlain
        discreetLabel = discreetLabelPlain
        runsData = runsDataPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if modeSealed == nil { mode = modePlain }
        if savingsAmountSealed == nil { savingsAmount = savingsAmountPlain }
        if savingsPeriodSealed == nil { savingsPeriod = savingsPeriodPlain }
        if currencyCodeSealed == nil { currencyCode = currencyCodePlain }
        if acknowledgedMilestonesSealed == nil { acknowledgedMilestones = acknowledgedMilestonesPlain }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if priorTimesPerDaySealed == nil { priorTimesPerDay = priorTimesPerDayPlain }
        if nameSealed == nil { name = namePlain }
        if discreetLabelSealed == nil { discreetLabel = discreetLabelPlain }
        if runsDataSealed == nil { runsData = runsDataPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(mode),
            FieldLock.describe(savingsAmount),
            FieldLock.describe(savingsPeriod),
            FieldLock.describe(currencyCode),
            FieldLock.describe(acknowledgedMilestones),
            FieldLock.describe(createdAt),
            FieldLock.describe(priorTimesPerDay),
            FieldLock.describe(name),
            FieldLock.describe(discreetLabel),
            FieldLock.describe(runsData)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        modeSealed != nil && modePlain == DayCountMode.lockedPlaceholder
            && savingsAmountSealed != nil && savingsAmountPlain == Double.lockedPlaceholder
            && savingsPeriodSealed != nil && savingsPeriodPlain == SavingsPeriod.lockedPlaceholder
            && currencyCodeSealed != nil && currencyCodePlain.isEmpty
            && acknowledgedMilestonesSealed != nil && acknowledgedMilestonesPlain.isEmpty
            && createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && priorTimesPerDaySealed != nil && priorTimesPerDayPlain == Int.lockedPlaceholder
            && nameSealed != nil && namePlain.isEmpty
            && discreetLabelSealed != nil && discreetLabelPlain.isEmpty
            && runsDataSealed != nil && runsDataPlain.isEmpty
    }
}

// MARK: - Motivations

/// "Who I'm doing this for" and "why it matters", in the user's own words.
@Model
final class RecoveryMotivation {
    var id: UUID = UUID()
    @Attribute(originalName: "kind") var kindPlain: MotivationKind = MotivationKind.lockedPlaceholder
    /// The locked form of `kind`, empty until locking is turned on. Read and written through `kind` only.
    var kindSealed: String? = nil
    @Attribute(originalName: "text") var textPlain: String = ""
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var sortOrder: Int = 0
    @Attribute(originalName: "createdAt") var createdAtPlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `createdAt`, empty until locking is turned on. Read and written through `createdAt` only.
    var createdAtSealed: String? = nil

    init(id: UUID = UUID(), kind: MotivationKind, text: String, sortOrder: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.kindPlain = kind
        self.textPlain = text
        self.sortOrder = sortOrder
        self.createdAtPlain = createdAt
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension RecoveryMotivation {
    var text: String {
        get { FieldLock.read(plain: textPlain, sealed: textSealed, context: "RecoveryMotivation.text") }
        set {
            let kept = FieldLock.store(newValue, context: "RecoveryMotivation.text")
            textPlain = kept.plain
            textSealed = kept.sealed
        }
    }

    var kind: MotivationKind {
        get { FieldLock.readChoice(plain: kindPlain, sealed: kindSealed, context: "RecoveryMotivation.kind") }
        set {
            let kept = FieldLock.storeChoice(newValue, context: "RecoveryMotivation.kind")
            kindPlain = kept.plain
            kindSealed = kept.sealed
        }
    }
    var createdAt: Date {
        get { FieldLock.readScalar(plain: createdAtPlain, sealed: createdAtSealed, context: "RecoveryMotivation.createdAt") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "RecoveryMotivation.createdAt")
            createdAtPlain = kept.plain
            createdAtSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        kind = kindPlain
        createdAt = createdAtPlain
        text = textPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if kindSealed == nil { kind = kindPlain }
        if createdAtSealed == nil { createdAt = createdAtPlain }
        if textSealed == nil { text = textPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(kind),
            FieldLock.describe(createdAt),
            FieldLock.describe(text)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        kindSealed != nil && kindPlain == MotivationKind.lockedPlaceholder
            && createdAtSealed != nil && createdAtPlain == Date.lockedPlaceholder
            && textSealed != nil && textPlain.isEmpty
    }
}

// MARK: - Daily pledge and review

/// One day for one counter. Free text only: no rating, no score.
@Model
final class RecoveryDayEntry {
    var id: UUID = UUID()
    var counterID: UUID = UUID()
    @Attribute(originalName: "day") var dayPlain: Date = Date(timeIntervalSinceReferenceDate: 0) // start of day
    /// The locked form of `day`, empty until locking is turned on. Read and written through `day` only.
    var daySealed: String? = nil
    @Attribute(originalName: "pledgedAt") var pledgedAtPlain: Date?
    /// The locked form of `pledgedAt`, empty until locking is turned on. Read and written through `pledgedAt` only.
    var pledgedAtSealed: String? = nil
    @Attribute(originalName: "reviewedAt") var reviewedAtPlain: Date?
    /// The locked form of `reviewedAt`, empty until locking is turned on. Read and written through `reviewedAt` only.
    var reviewedAtSealed: String? = nil
    @Attribute(originalName: "helped") var helpedPlain: String = ""
    /// The locked form of `helped`, empty until locking is turned on. Read and written through `helped` only.
    var helpedSealed: String? = nil
    @Attribute(originalName: "hard") var hardPlain: String = ""
    /// The locked form of `hard`, empty until locking is turned on. Read and written through `hard` only.
    var hardSealed: String? = nil
    @Attribute(originalName: "tomorrow") var tomorrowPlain: String = ""
    /// The locked form of `tomorrow`, empty until locking is turned on. Read and written through `tomorrow` only.
    var tomorrowSealed: String? = nil

    /// How many times a slip happened on this day (0 = none). Powers the "Times" list.
    @Attribute(originalName: "slipTimes") var slipTimesPlain: Int = 0
    /// The locked form of `slipTimes`, empty until locking is turned on. Read and written through `slipTimes` only.
    var slipTimesSealed: String? = nil

    init(id: UUID = UUID(), counterID: UUID, day: Date, pledgedAt: Date? = nil, reviewedAt: Date? = nil,
         helped: String = "", hard: String = "", tomorrow: String = "", slipTimes: Int = 0) {
        self.id = id
        self.counterID = counterID
        self.dayPlain = day
        self.pledgedAtPlain = pledgedAt
        self.reviewedAtPlain = reviewedAt
        self.helpedPlain = helped
        self.hardPlain = hard
        self.tomorrowPlain = tomorrow
        self.slipTimesPlain = slipTimes
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension RecoveryDayEntry {
    var helped: String {
        get { FieldLock.read(plain: helpedPlain, sealed: helpedSealed, context: "RecoveryDayEntry.helped") }
        set {
            let kept = FieldLock.store(newValue, context: "RecoveryDayEntry.helped")
            helpedPlain = kept.plain
            helpedSealed = kept.sealed
        }
    }
    var hard: String {
        get { FieldLock.read(plain: hardPlain, sealed: hardSealed, context: "RecoveryDayEntry.hard") }
        set {
            let kept = FieldLock.store(newValue, context: "RecoveryDayEntry.hard")
            hardPlain = kept.plain
            hardSealed = kept.sealed
        }
    }
    var tomorrow: String {
        get { FieldLock.read(plain: tomorrowPlain, sealed: tomorrowSealed, context: "RecoveryDayEntry.tomorrow") }
        set {
            let kept = FieldLock.store(newValue, context: "RecoveryDayEntry.tomorrow")
            tomorrowPlain = kept.plain
            tomorrowSealed = kept.sealed
        }
    }

    var day: Date {
        get { FieldLock.readScalar(plain: dayPlain, sealed: daySealed, context: "RecoveryDayEntry.day") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "RecoveryDayEntry.day")
            dayPlain = kept.plain
            daySealed = kept.sealed
        }
    }
    var pledgedAt: Date? {
        get { FieldLock.readOptionalScalar(plain: pledgedAtPlain, sealed: pledgedAtSealed, context: "RecoveryDayEntry.pledgedAt") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "RecoveryDayEntry.pledgedAt")
            pledgedAtPlain = kept.plain
            pledgedAtSealed = kept.sealed
        }
    }
    var reviewedAt: Date? {
        get { FieldLock.readOptionalScalar(plain: reviewedAtPlain, sealed: reviewedAtSealed, context: "RecoveryDayEntry.reviewedAt") }
        set {
            let kept = FieldLock.storeOptionalScalar(newValue, context: "RecoveryDayEntry.reviewedAt")
            reviewedAtPlain = kept.plain
            reviewedAtSealed = kept.sealed
        }
    }
    var slipTimes: Int {
        get { FieldLock.readScalar(plain: slipTimesPlain, sealed: slipTimesSealed, context: "RecoveryDayEntry.slipTimes") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "RecoveryDayEntry.slipTimes")
            slipTimesPlain = kept.plain
            slipTimesSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        day = dayPlain
        pledgedAt = pledgedAtPlain
        reviewedAt = reviewedAtPlain
        slipTimes = slipTimesPlain
        helped = helpedPlain
        hard = hardPlain
        tomorrow = tomorrowPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if daySealed == nil { day = dayPlain }
        if pledgedAtSealed == nil { pledgedAt = pledgedAtPlain }
        if reviewedAtSealed == nil { reviewedAt = reviewedAtPlain }
        if slipTimesSealed == nil { slipTimes = slipTimesPlain }
        if helpedSealed == nil { helped = helpedPlain }
        if hardSealed == nil { hard = hardPlain }
        if tomorrowSealed == nil { tomorrow = tomorrowPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(day),
            FieldLock.describe(pledgedAt),
            FieldLock.describe(reviewedAt),
            FieldLock.describe(slipTimes),
            FieldLock.describe(helped),
            FieldLock.describe(hard),
            FieldLock.describe(tomorrow)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        daySealed != nil && dayPlain == Date.lockedPlaceholder
            && pledgedAtSealed != nil && pledgedAtPlain == nil
            && reviewedAtSealed != nil && reviewedAtPlain == nil
            && slipTimesSealed != nil && slipTimesPlain == Int.lockedPlaceholder
            && helpedSealed != nil && helpedPlain.isEmpty
            && hardSealed != nil && hardPlain.isEmpty
            && tomorrowSealed != nil && tomorrowPlain.isEmpty
    }
}

// MARK: - Urges

enum UrgeStrength: String, Codable, CaseIterable, Identifiable {
    case mild, strong, intense
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mild: return "Mild"
        case .strong: return "Strong"
        case .intense: return "Intense"
        }
    }
}

/// A logged urge. How strong it felt is the user's own description, not a score.
@Model
final class RecoveryUrge {
    var id: UUID = UUID()
    var counterID: UUID = UUID()
    @Attribute(originalName: "date") var datePlain: Date = Date(timeIntervalSinceReferenceDate: 0)
    /// The locked form of `date`, empty until locking is turned on. Read and written through `date` only.
    var dateSealed: String? = nil
    @Attribute(originalName: "strength") var strengthPlain: UrgeStrength = UrgeStrength.lockedPlaceholder
    /// The locked form of `strength`, empty until locking is turned on. Read and written through `strength` only.
    var strengthSealed: String? = nil
    @Attribute(originalName: "note") var notePlain: String = ""
    /// The locked form of `note`, empty until locking is turned on. Read and written through `note` only.
    var noteSealed: String? = nil

    init(id: UUID = UUID(), counterID: UUID, date: Date = .now, strength: UrgeStrength = .strong, note: String = "") {
        self.id = id
        self.counterID = counterID
        self.datePlain = date
        self.strengthPlain = strength
        self.notePlain = note
        lockNewValues()
    }
}

// Patch 35b2: the old names, read and written through FieldLock so a locked value reads as its text.
extension RecoveryUrge {
    var note: String {
        get { FieldLock.read(plain: notePlain, sealed: noteSealed, context: "RecoveryUrge.note") }
        set {
            let kept = FieldLock.store(newValue, context: "RecoveryUrge.note")
            notePlain = kept.plain
            noteSealed = kept.sealed
        }
    }

    var date: Date {
        get { FieldLock.readScalar(plain: datePlain, sealed: dateSealed, context: "RecoveryUrge.date") }
        set {
            let kept = FieldLock.storeScalar(newValue, context: "RecoveryUrge.date")
            datePlain = kept.plain
            dateSealed = kept.sealed
        }
    }
    var strength: UrgeStrength {
        get { FieldLock.readChoice(plain: strengthPlain, sealed: strengthSealed, context: "RecoveryUrge.strength") }
        set {
            let kept = FieldLock.storeChoice(newValue, context: "RecoveryUrge.strength")
            strengthPlain = kept.plain
            strengthSealed = kept.sealed
        }
    }

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        date = datePlain
        strength = strengthPlain
        note = notePlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if dateSealed == nil { date = datePlain }
        if strengthSealed == nil { strength = strengthPlain }
        if noteSealed == nil { note = notePlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(date),
            FieldLock.describe(strength),
            FieldLock.describe(note)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        dateSealed != nil && datePlain == Date.lockedPlaceholder
            && strengthSealed != nil && strengthPlain == UrgeStrength.lockedPlaceholder
            && noteSealed != nil && notePlain.isEmpty
    }
}

// MARK: - Timeline (calendar, streaks and stats)

enum RecoveryDayStatus { case sober, slip, untracked }

struct RecoveryStreak: Identifiable {
    let id: Int
    let start: Date
    let end: Date?
    var isCurrent: Bool { end == nil }

    func length(now: Date) -> TimeInterval { max(0, (end ?? now).timeIntervalSince(start)) }
    func wholeDays(now: Date) -> Int { RecoveryCounter.wholeDays(from: start, to: end ?? now) }

    /// "4 day streak", "23 hour streak", "12 minute streak".
    func lengthText(now: Date) -> String {
        let days = wholeDays(now: now)
        if days >= 1 { return "\(days) day streak" }
        let hours = Int(length(now: now) / 3600)
        if hours >= 1 { return "\(hours) hour streak" }
        return "\(Int(length(now: now) / 60)) minute streak"
    }
}

/// Everything the calendar and statistics need, worked out once from the runs.
struct RecoveryTimeline {
    let runs: [RecoveryRun]
    let now: Date
    private(set) var soberDays: Set<Date> = []
    private(set) var slipDays: Set<Date> = []

    init(runs: [RecoveryRun], now: Date = .now) {
        self.runs = runs
        self.now = now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        for run in runs {
            let first = calendar.startOfDay(for: run.start)
            let last = min(calendar.startOfDay(for: run.end ?? now), today)
            if let end = run.end { slipDays.insert(calendar.startOfDay(for: end)) }
            var day = first
            var safety = 0
            while day <= last && safety < 20000 {
                soberDays.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                safety += 1
            }
        }
        soberDays.subtract(slipDays)
    }

    func status(_ day: Date) -> RecoveryDayStatus {
        let d = Calendar.current.startOfDay(for: day)
        if slipDays.contains(d) { return .slip }
        return soberDays.contains(d) ? .sober : .untracked
    }

    var streaks: [RecoveryStreak] {
        runs.enumerated().map { RecoveryStreak(id: $0.offset, start: $0.element.start, end: $0.element.end) }
    }
    var longestStreakDays: Int { streaks.map { $0.wholeDays(now: now) }.max() ?? 0 }

    /// The longest streak in its largest sensible unit ("5 hours", not "0 days").
    var longestStreakPhrase: String {
        guard let best = streaks.max(by: { $0.length(now: now) < $1.length(now: now) }) else { return "just started" }
        return ElapsedFormat.phrase(from: best.start, to: best.end ?? now)
    }
    var freshStarts: Int { max(0, runs.count - 1) }
    var originalStart: Date? { runs.first?.start }

    func soberDayCount(inMonthOf date: Date) -> Int {
        guard let interval = Calendar.current.dateInterval(of: .month, for: date) else { return 0 }
        return soberDays.filter { interval.contains($0) }.count
    }

    /// Weekends (Saturday and Sunday) that were fully inside a run and are already over.
    func wholeWeekends() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return soberDays.filter { day in
            guard calendar.component(.weekday, from: day) == 7 else { return false }
            guard let sunday = calendar.date(byAdding: .day, value: 1, to: day), sunday < today else { return false }
            return soberDays.contains(sunday)
        }.count
    }
}

// MARK: - Export / import

struct RecoveryCounterDTO: Codable {
    var id: UUID
    var name: String
    var discreetLabel: String
    var showNameOutsideApp: Bool
    var mode: DayCountMode
    var runs: [RecoveryRun]
    var savingsAmount: Double
    var savingsPeriod: SavingsPeriod
    var currencyCode: String
    var acknowledgedMilestones: [Int]
    var sortOrder: Int
    var createdAt: Date
    var isArchived: Bool
    var priorTimesPerDay: Int?

    init(_ c: RecoveryCounter) {
        id = c.id; name = c.name; discreetLabel = c.discreetLabel; showNameOutsideApp = c.showNameOutsideApp
        mode = c.mode; runs = c.runs; savingsAmount = c.savingsAmount; savingsPeriod = c.savingsPeriod
        currencyCode = c.currencyCode; acknowledgedMilestones = c.acknowledgedMilestones
        sortOrder = c.sortOrder; createdAt = c.createdAt; isArchived = c.isArchived
        priorTimesPerDay = c.priorTimesPerDay
    }

    func toModel() -> RecoveryCounter {
        let c = RecoveryCounter(id: id, name: name, discreetLabel: discreetLabel, showNameOutsideApp: showNameOutsideApp,
                                mode: mode, savingsAmount: savingsAmount, savingsPeriod: savingsPeriod,
                                currencyCode: currencyCode, sortOrder: sortOrder, createdAt: createdAt)
        c.runs = runs
        c.acknowledgedMilestones = acknowledgedMilestones
        c.isArchived = isArchived
        c.priorTimesPerDay = priorTimesPerDay ?? 0
        return c
    }
}

struct RecoveryMotivationDTO: Codable {
    var id: UUID
    var kind: MotivationKind
    var text: String
    var sortOrder: Int
    var createdAt: Date

    init(_ m: RecoveryMotivation) { id = m.id; kind = m.kind; text = m.text; sortOrder = m.sortOrder; createdAt = m.createdAt }
    func toModel() -> RecoveryMotivation { RecoveryMotivation(id: id, kind: kind, text: text, sortOrder: sortOrder, createdAt: createdAt) }
}

struct RecoveryDayEntryDTO: Codable {
    var id: UUID
    var counterID: UUID
    var day: Date
    var pledgedAt: Date?
    var reviewedAt: Date?
    var helped: String
    var hard: String
    var tomorrow: String
    var slipTimes: Int?

    init(_ e: RecoveryDayEntry) {
        id = e.id; counterID = e.counterID; day = e.day; pledgedAt = e.pledgedAt; reviewedAt = e.reviewedAt
        helped = e.helped; hard = e.hard; tomorrow = e.tomorrow
        slipTimes = e.slipTimes
    }

    func toModel() -> RecoveryDayEntry {
        RecoveryDayEntry(id: id, counterID: counterID, day: day, pledgedAt: pledgedAt, reviewedAt: reviewedAt,
                         helped: helped, hard: hard, tomorrow: tomorrow, slipTimes: slipTimes ?? 0)
    }
}

struct RecoveryUrgeDTO: Codable {
    var id: UUID
    var counterID: UUID
    var date: Date
    var strength: UrgeStrength
    var note: String

    init(_ u: RecoveryUrge) { id = u.id; counterID = u.counterID; date = u.date; strength = u.strength; note = u.note }
    func toModel() -> RecoveryUrge { RecoveryUrge(id: id, counterID: counterID, date: date, strength: strength, note: note) }
}

// Patch 35b3: every model with locked fields can be locked in place, and checked, by Lock my data.
extension RecoveryCounter: LockableModel {}
extension RecoveryMotivation: LockableModel {}
extension RecoveryDayEntry: LockableModel {}
extension RecoveryUrge: LockableModel {}
