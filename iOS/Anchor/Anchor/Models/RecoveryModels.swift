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
    @Attribute(.unique) var id: UUID

    /// The user's own words, shown only inside the app unless they opt in below.
    @Attribute(originalName: "name") var namePlain: String
    /// The locked form of `name`, empty until locking is turned on. Read and written through `name` only.
    var nameSealed: String? = nil

    /// What widgets and notifications call this counter, e.g. "Your counter".
    @Attribute(originalName: "discreetLabel") var discreetLabelPlain: String
    /// The locked form of `discreetLabel`, empty until locking is turned on. Read and written through `discreetLabel` only.
    var discreetLabelSealed: String? = nil
    var showNameOutsideApp: Bool

    var mode: DayCountMode

    /// JSON-encoded `[RecoveryRun]`. Stored as data so the schema stays simple.
    @Attribute(originalName: "runsData") var runsDataPlain: Data
    /// The locked form of `runsData`, empty until locking is turned on. Read and written through `runsData` only.
    var runsDataSealed: String? = nil

    var savingsAmount: Double
    var savingsPeriod: SavingsPeriod
    var currencyCode: String

    /// Milestones (in days) the user has already seen, so each is marked once.
    var acknowledgedMilestones: [Int]

    var sortOrder: Int
    var createdAt: Date
    var isArchived: Bool

    /// "Before tracking, on a typical day, how many times did it happen?" Just a reference note.
    var priorTimesPerDay: Int = 0

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
        self.mode = mode
        self.runsDataPlain = (try? JSONEncoder().encode([RecoveryRun(start: startDate, end: nil)])) ?? Data()
        self.savingsAmount = savingsAmount
        self.savingsPeriod = savingsPeriod
        self.currencyCode = currencyCode
        self.acknowledgedMilestones = []
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isArchived = false
        self.priorTimesPerDay = 0
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

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        name = namePlain
        discreetLabel = discreetLabelPlain
        runsData = runsDataPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if nameSealed == nil { name = namePlain }
        if discreetLabelSealed == nil { discreetLabel = discreetLabelPlain }
        if runsDataSealed == nil { runsData = runsDataPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(name),
            FieldLock.describe(discreetLabel),
            FieldLock.describe(runsData)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        nameSealed != nil && namePlain.isEmpty
            && discreetLabelSealed != nil && discreetLabelPlain.isEmpty
            && runsDataSealed != nil && runsDataPlain.isEmpty
    }
}

// MARK: - Motivations

/// "Who I'm doing this for" and "why it matters", in the user's own words.
@Model
final class RecoveryMotivation {
    @Attribute(.unique) var id: UUID
    var kind: MotivationKind
    @Attribute(originalName: "text") var textPlain: String
    /// The locked form of `text`, empty until locking is turned on. Read and written through `text` only.
    var textSealed: String? = nil
    var sortOrder: Int
    var createdAt: Date

    init(id: UUID = UUID(), kind: MotivationKind, text: String, sortOrder: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.textPlain = text
        self.sortOrder = sortOrder
        self.createdAt = createdAt
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

// MARK: - Daily pledge and review

/// One day for one counter. Free text only: no rating, no score.
@Model
final class RecoveryDayEntry {
    @Attribute(.unique) var id: UUID
    var counterID: UUID
    var day: Date               // start of day
    var pledgedAt: Date?
    var reviewedAt: Date?
    @Attribute(originalName: "helped") var helpedPlain: String
    /// The locked form of `helped`, empty until locking is turned on. Read and written through `helped` only.
    var helpedSealed: String? = nil
    @Attribute(originalName: "hard") var hardPlain: String
    /// The locked form of `hard`, empty until locking is turned on. Read and written through `hard` only.
    var hardSealed: String? = nil
    @Attribute(originalName: "tomorrow") var tomorrowPlain: String
    /// The locked form of `tomorrow`, empty until locking is turned on. Read and written through `tomorrow` only.
    var tomorrowSealed: String? = nil

    /// How many times a slip happened on this day (0 = none). Powers the "Times" list.
    var slipTimes: Int = 0

    init(id: UUID = UUID(), counterID: UUID, day: Date, pledgedAt: Date? = nil, reviewedAt: Date? = nil,
         helped: String = "", hard: String = "", tomorrow: String = "", slipTimes: Int = 0) {
        self.id = id
        self.counterID = counterID
        self.day = day
        self.pledgedAt = pledgedAt
        self.reviewedAt = reviewedAt
        self.helpedPlain = helped
        self.hardPlain = hard
        self.tomorrowPlain = tomorrow
        self.slipTimes = slipTimes
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

    /// Seals the fields of a value that was only just made, when locking is on. It is for a new value, which holds
    /// nothing sealed yet, and does nothing while locking is off.
    func lockNewValues() {
        guard FieldLock.isOn else { return }
        helped = helpedPlain
        hard = hardPlain
        tomorrow = tomorrowPlain
    }

    /// Patch 35b3: seals what is stored plain and leaves anything already sealed alone, so it is safe to run
    /// again. It does nothing while locking is off.
    func lockExistingValues() {
        guard FieldLock.isOn else { return }
        if helpedSealed == nil { helped = helpedPlain }
        if hardSealed == nil { hard = hardPlain }
        if tomorrowSealed == nil { tomorrow = tomorrowPlain }
    }

    /// What every locked field reads as, joined into one piece of text, so the Lock my data check can compare it
    /// before and after. It reads through the old names, so a sealed value is compared as its text.
    func lockedSnapshot() -> String {
        FieldLock.join([
            FieldLock.describe(helped),
            FieldLock.describe(hard),
            FieldLock.describe(tomorrow)
        ])
    }

    /// True when every locked field is held sealed, with nothing left in the plain property.
    func lockedFieldsAreSealed() -> Bool {
        helpedSealed != nil && helpedPlain.isEmpty
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
    @Attribute(.unique) var id: UUID
    var counterID: UUID
    var date: Date
    var strength: UrgeStrength
    @Attribute(originalName: "note") var notePlain: String
    /// The locked form of `note`, empty until locking is turned on. Read and written through `note` only.
    var noteSealed: String? = nil

    init(id: UUID = UUID(), counterID: UUID, date: Date = .now, strength: UrgeStrength = .strong, note: String = "") {
        self.id = id
        self.counterID = counterID
        self.date = date
        self.strength = strength
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
