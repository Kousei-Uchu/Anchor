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
    var name: String

    /// What widgets and notifications call this counter, e.g. "Your counter".
    var discreetLabel: String
    var showNameOutsideApp: Bool

    var mode: DayCountMode

    /// JSON-encoded `[RecoveryRun]`. Stored as data so the schema stays simple.
    var runsData: Data

    var savingsAmount: Double
    var savingsPeriod: SavingsPeriod
    var currencyCode: String

    /// Milestones (in days) the user has already seen, so each is marked once.
    var acknowledgedMilestones: [Int]

    var sortOrder: Int
    var createdAt: Date
    var isArchived: Bool

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
        self.name = name
        self.discreetLabel = discreetLabel
        self.showNameOutsideApp = showNameOutsideApp
        self.mode = mode
        self.runsData = (try? JSONEncoder().encode([RecoveryRun(start: startDate, end: nil)])) ?? Data()
        self.savingsAmount = savingsAmount
        self.savingsPeriod = savingsPeriod
        self.currencyCode = currencyCode
        self.acknowledgedMilestones = []
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.isArchived = false
    }

    // MARK: Runs

    var runs: [RecoveryRun] {
        get { (try? JSONDecoder().decode([RecoveryRun].self, from: runsData)) ?? [] }
        set { runsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var currentRun: RecoveryRun? { runs.last(where: { $0.end == nil }) }

    static func wholeDays(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        let a = calendar.startOfDay(for: start)
        let b = calendar.startOfDay(for: end)
        return max(0, calendar.dateComponents([.day], from: a, to: b).day ?? 0)
    }

    func currentRunDays(now: Date = .now) -> Int {
        guard let run = currentRun else { return 0 }
        return RecoveryCounter.wholeDays(from: run.start, to: now)
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

// MARK: - Motivations

/// "Who I'm doing this for" and "why it matters", in the user's own words.
@Model
final class RecoveryMotivation {
    @Attribute(.unique) var id: UUID
    var kind: MotivationKind
    var text: String
    var sortOrder: Int
    var createdAt: Date

    init(id: UUID = UUID(), kind: MotivationKind, text: String, sortOrder: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.text = text
        self.sortOrder = sortOrder
        self.createdAt = createdAt
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
    var helped: String
    var hard: String
    var tomorrow: String

    init(id: UUID = UUID(), counterID: UUID, day: Date, pledgedAt: Date? = nil, reviewedAt: Date? = nil,
         helped: String = "", hard: String = "", tomorrow: String = "") {
        self.id = id
        self.counterID = counterID
        self.day = day
        self.pledgedAt = pledgedAt
        self.reviewedAt = reviewedAt
        self.helped = helped
        self.hard = hard
        self.tomorrow = tomorrow
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

    init(_ c: RecoveryCounter) {
        id = c.id; name = c.name; discreetLabel = c.discreetLabel; showNameOutsideApp = c.showNameOutsideApp
        mode = c.mode; runs = c.runs; savingsAmount = c.savingsAmount; savingsPeriod = c.savingsPeriod
        currencyCode = c.currencyCode; acknowledgedMilestones = c.acknowledgedMilestones
        sortOrder = c.sortOrder; createdAt = c.createdAt; isArchived = c.isArchived
    }

    func toModel() -> RecoveryCounter {
        let c = RecoveryCounter(id: id, name: name, discreetLabel: discreetLabel, showNameOutsideApp: showNameOutsideApp,
                                mode: mode, savingsAmount: savingsAmount, savingsPeriod: savingsPeriod,
                                currencyCode: currencyCode, sortOrder: sortOrder, createdAt: createdAt)
        c.runs = runs
        c.acknowledgedMilestones = acknowledgedMilestones
        c.isArchived = isArchived
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

    init(_ e: RecoveryDayEntry) {
        id = e.id; counterID = e.counterID; day = e.day; pledgedAt = e.pledgedAt; reviewedAt = e.reviewedAt
        helped = e.helped; hard = e.hard; tomorrow = e.tomorrow
    }

    func toModel() -> RecoveryDayEntry {
        RecoveryDayEntry(id: id, counterID: counterID, day: day, pledgedAt: pledgedAt, reviewedAt: reviewedAt,
                         helped: helped, hard: hard, tomorrow: tomorrow)
    }
}
