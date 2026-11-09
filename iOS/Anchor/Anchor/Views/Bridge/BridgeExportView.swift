//
//  BridgeExportView.swift
//  Anchor
//
//  Export for someone else: a clinician, or a person you trust. The person
//  chooses what goes in (by kind, by date range and by individual item),
//  writes who it is for and an optional cover note, sees a live count and a
//  preview, and only then makes the file. It is built on-device and handed to
//  the system share sheet. Nothing is uploaded. Nothing is included unless it
//  is switched on for that export, and the choices are not remembered.
//
//  Everything is built into one `ExportDocument` first. The preview, the PDF
//  and the web page all read it, so they always agree.
//

import SwiftUI
import SwiftData
import UIKit
import CryptoKit
import CommonCrypto

// MARK: - The document

enum ExportCategory: String, CaseIterable, Identifiable {
    case thingsToRaise, journal, checkIns, sleep, recovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thingsToRaise: return "Things to raise"
        case .journal: return "Journal entries"
        case .checkIns: return "Check-ins"
        case .sleep: return "Sleep"
        case .recovery: return "Recovery summary"
        }
    }

    var icon: String {
        switch self {
        case .thingsToRaise: return "doc.text.fill"
        case .journal: return "text.quote"
        case .checkIns: return "circle.hexagongrid.fill"
        case .sleep: return "moon.zzz.fill"
        case .recovery: return "calendar.badge.checkmark"
        }
    }

    func noun(_ n: Int) -> String {
        switch self {
        case .thingsToRaise: return n == 1 ? "thing to raise" : "things to raise"
        case .journal: return n == 1 ? "journal entry" : "journal entries"
        case .checkIns: return n == 1 ? "check-in" : "check-ins"
        case .sleep: return n == 1 ? "night of sleep" : "nights of sleep"
        case .recovery: return n == 1 ? "recovery counter" : "recovery counters"
        }
    }
}

/// A number that can be drawn, such as one of a check-in's five values (0 to 1).
struct ExportValue {
    let label: String
    let number: Double
}

struct ExportEntry: Identifiable {
    let id: UUID
    var date: Date?
    var heading: String?
    var lines: [String]
    var footnote: String?
    var values: [ExportValue] = []
    /// For a night of sleep only: when it began and ended, for the CSV's own columns.
    var bedTime: Date? = nil
    var wakeTime: Date? = nil
}

struct ExportSection: Identifiable {
    let category: ExportCategory
    var entries: [ExportEntry]
    var id: String { category.rawValue }
}

struct ExportDocument {
    var title: String
    var recipient: String?
    var coverNote: String
    var created: Date
    var rangeText: String?
    var sections: [ExportSection]

    var isEmpty: Bool { sections.allSatisfy { $0.entries.isEmpty } }

    /// "12 journal entries, 3 check-ins and 2 things to raise".
    var summary: String {
        let parts = sections.filter { !$0.entries.isEmpty }.map { "\($0.entries.count) \($0.category.noun($0.entries.count))" }
        switch parts.count {
        case 0: return "Nothing is selected yet."
        case 1: return parts[0]
        default: return parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
    }
}

/// What the person chose. Never stored.
struct ExportSelection {
    var recipient = ""
    var coverNote = ""
    var providerID: UUID?
    var categories: Set<ExportCategory> = [.thingsToRaise]
    var range: ClosedRange<Date>?
    /// Individual items (or counters) left out, by id.
    var left: Set<UUID> = []
}

/// One thing that could go in, with how it would read.
struct ExportCandidate: Identifiable {
    let id: UUID
    let category: ExportCategory
    let headline: String
    let entry: ExportEntry
}

struct BridgeExportBuilder {
    let selection: ExportSelection
    let drafts: [BridgeDraftItem]
    let journal: [JournalEntry]
    let checkIns: [CheckIn]
    let sleep: [SleepEntry]
    let counters: [RecoveryCounter]
    let urges: [RecoveryUrge]
    let providers: [AppointmentSeries]

    private var chosenName: String? {
        providers.first { $0.id == selection.providerID }?.exportName
    }

    private func inRange(_ date: Date) -> Bool {
        selection.range?.contains(date) ?? true
    }

    private func fmt(_ value: Double) -> String { String(format: "%.2f", value) }

    /// Everything of one kind that falls in the date range (and, for Things to
    /// raise, that belongs to the person chosen), before individual items are
    /// left out.
    func candidates(_ category: ExportCategory) -> [ExportCandidate] {
        switch category {
        case .thingsToRaise:
            var items = drafts
            if let id = selection.providerID, chosenName != nil {
                items = items.filter { $0.isFor(id, in: providers) }
            }
            let labels = chosenName == nil
                ? Dictionary(providers.map { ($0.id, $0.exportName) }, uniquingKeysWith: { first, _ in first })
                : [:]
            return items.filter { inRange($0.createdAt) }.sorted { $0.createdAt < $1.createdAt }.map { item in
                let heading: String?
                if item.isQuestion {
                    heading = item.isResolved ? "Question (asked)" : "Question"
                } else {
                    heading = item.isResolved ? "Already discussed" : nil
                }
                var lines = [item.text]
                let answer = item.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                if item.isQuestion, !answer.isEmpty { lines.append("Answer: " + answer) }
                let footnote = item.providerID.flatMap { labels[$0] }.map { "For " + $0 }
                return ExportCandidate(
                    id: item.id, category: category,
                    headline: DataText.firstLine(item.text, "Empty item"),
                    entry: ExportEntry(id: item.id, date: item.createdAt, heading: heading, lines: lines, footnote: footnote)
                )
            }
        case .journal:
            return journal.filter { inRange($0.createdAt) }.sorted { $0.createdAt < $1.createdAt }.map { entry in
                var lines = [entry.text]
                if entry.audioFileName != nil { lines.append("(A voice note was recorded. It is not included.)") }
                return ExportCandidate(
                    id: entry.id, category: category,
                    headline: DataText.firstLine(entry.text, "Voice note"),
                    entry: ExportEntry(id: entry.id, date: entry.createdAt, heading: nil, lines: lines, footnote: nil)
                )
            }
        case .checkIns:
            return checkIns.filter { inRange($0.timestamp) }.sorted { $0.timestamp < $1.timestamp }.map { check in
                // Each value is read back to the slider the person moved. Three are stored turned
                // over (as exhaustion, burnout and load); physicalEnergy is the Moving slider.
                let line = "Energy \(fmt(1 - check.physicalExhaustion)), clarity \(fmt(1 - check.cognitiveBurnout)), room in head \(fmt(1 - check.mentalLoad)), moving \(fmt(check.physicalEnergy)), social energy \(fmt(check.socialEnergy))"
                return ExportCandidate(
                    id: check.id, category: category,
                    headline: check.timestamp.formatted(date: .abbreviated, time: .shortened),
                    entry: ExportEntry(
                        id: check.id, date: check.timestamp, heading: nil, lines: [line], footnote: nil,
                        values: [
                            ExportValue(label: "Energy", number: 1 - check.physicalExhaustion),
                            ExportValue(label: "Clarity", number: 1 - check.cognitiveBurnout),
                            ExportValue(label: "Room in head", number: 1 - check.mentalLoad),
                            ExportValue(label: "Moving", number: check.physicalEnergy),
                            ExportValue(label: "Social energy", number: check.socialEnergy)
                        ]
                    )
                )
            }
        case .sleep:
            return sleep.filter { !$0.isBlank && inRange($0.nightDate) }.sorted { $0.nightDate < $1.nightDate }.map { night in
                var lines: [String] = []
                if let bed = night.bedTime, let wake = night.wakeTime {
                    lines.append("In bed " + bed.formatted(date: .omitted, time: .shortened) + ", up " + wake.formatted(date: .omitted, time: .shortened))
                }
                if let minutes = night.shownMinutes { lines.append("Asleep about " + SleepEntry.describe(minutes: minutes)) }
                let note = night.note.trimmingCharacters(in: .whitespacesAndNewlines)
                if !note.isEmpty { lines.append(note) }
                let name = "Night of " + night.nightDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                return ExportCandidate(
                    id: night.id, category: category, headline: name,
                    entry: ExportEntry(
                        id: night.id, date: night.nightDate, heading: name, lines: lines, footnote: nil,
                        values: night.shownMinutes.map { [ExportValue(label: "Time asleep", number: Double($0))] } ?? [],
                        bedTime: night.bedTime, wakeTime: night.wakeTime
                    )
                )
            }
        case .recovery:
            let window = selection.range ?? (Date.distantPast...Date.now)
            return counters.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }.map { counter in
                ExportCandidate(
                    id: counter.id, category: category, headline: counter.name,
                    entry: ExportEntry(
                        id: counter.id, date: nil, heading: counter.name,
                        lines: RecoverySummary.lines(for: counter, urges: urges, range: window), footnote: nil
                    )
                )
            }
        }
    }

    /// What is actually included: the chosen kinds, less the items left out.
    func included(_ category: ExportCategory) -> [ExportCandidate] {
        guard selection.categories.contains(category) else { return [] }
        return candidates(category).filter { !selection.left.contains($0.id) }
    }

    func document(now: Date = .now) -> ExportDocument {
        let name = selection.recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        var rangeText: String?
        if let range = selection.range {
            rangeText = range.lowerBound.formatted(date: .abbreviated, time: .omitted) + " to " + range.upperBound.formatted(date: .abbreviated, time: .omitted)
        }
        return ExportDocument(
            title: name.isEmpty ? "Notes from my Anchor" : "For " + name,
            recipient: name.isEmpty ? nil : name,
            coverNote: selection.coverNote.trimmingCharacters(in: .whitespacesAndNewlines),
            created: now,
            rangeText: rangeText,
            sections: ExportCategory.allCases.compactMap { category in
                let rows = included(category)
                return rows.isEmpty ? nil : ExportSection(category: category, entries: rows.map(\.entry))
            }
        )
    }
}

// MARK: - The screen

struct BridgeExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AppointmentSeries.sortOrder) private var providers: [AppointmentSeries]
    @Query private var drafts: [BridgeDraftItem]
    @Query private var journal: [JournalEntry]
    @Query private var checkIns: [CheckIn]
    @Query private var sleep: [SleepEntry]
    @Query private var counters: [RecoveryCounter]
    @Query private var urges: [RecoveryUrge]

    @State private var selection = ExportSelection()
    @State private var useRange = false
    @State private var start: Date = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var end: Date = .now
    @State private var shareURL: IdentifiableURL?
    @State private var failed = false
    @State private var password = ""
    @State private var makingPage = false

    private var passwordTooShort: Bool { !password.isEmpty && password.count < 8 }

    private var builder: BridgeExportBuilder {
        var chosen = selection
        if useRange {
            // Whole days: from the start of the first to the end of the last.
            let cal = Calendar.current
            let first = cal.startOfDay(for: min(start, end))
            let last = cal.date(byAdding: DateComponents(day: 1, second: -1), to: cal.startOfDay(for: max(start, end))) ?? max(start, end)
            chosen.range = first...last
        } else {
            chosen.range = nil
        }
        return BridgeExportBuilder(
            selection: chosen, drafts: drafts, journal: journal, checkIns: checkIns,
            sleep: sleep, counters: counters, urges: urges, providers: providers
        )
    }

    var body: some View {
        let builder = self.builder
        let document = builder.document()
        NavigationStack {
            Form {
                Section {
                    TextField("A name, such as Dr Patel", text: $selection.recipient)
                        .textInputAutocapitalization(.words)
                    if !providers.isEmpty {
                        Picker("Notes for", selection: $selection.providerID) {
                            Text("No one in particular").tag(UUID?.none)
                            ForEach(providers) { provider in
                                Text(provider.exportName).tag(UUID?.some(provider.id))
                            }
                        }
                        .onChange(of: selection.providerID) { _, new in
                            let name = providers.first { $0.id == new }?.exportName
                            if let name, selection.recipient.trimmingCharacters(in: .whitespaces).isEmpty {
                                selection.recipient = name
                            }
                        }
                    }
                    TextField("A note at the top (optional)", text: $selection.coverNote, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Who it is for")
                } footer: {
                    Text(providers.isEmpty
                         ? "The name goes in the file name and at the top. Nothing leaves this phone until you share the file."
                         : "The name goes in the file name and at the top. Notes for also leaves out things you marked as for someone else. Nothing leaves this phone until you share the file.")
                }

                Section {
                    ForEach(ExportCategory.allCases) { category in
                        categoryRow(category, builder: builder)
                    }
                } header: {
                    Text("What to include")
                } footer: {
                    Text("Only Things to raise is on to begin with, every time. Everything else is left out unless you switch it on here.")
                }

                Section {
                    Toggle("Limit to a date range", isOn: $useRange)
                        .tint(Anchor.Theme.accent)
                    if useRange {
                        DatePicker("From", selection: $start, displayedComponents: .date)
                        DatePicker("To", selection: $end, displayedComponents: .date)
                    }
                } footer: {
                    if selection.categories.contains(.recovery) {
                        Text("The Recovery summary has each counter's name, days, urges logged and fresh starts. Never urge notes, pledges, reviews or savings.")
                    }
                }

                Section {
                    SecureField("Password (optional)", text: $password)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Web page password")
                } footer: {
                    Text(passwordTooShort
                         ? "Use at least 8 characters, or leave it empty for no password."
                         : "Only for the web page. With one, what is in the file is scrambled, and whoever has the file needs the password to read it. Tell them the password another way, not in the same message. Anchor does not keep it and cannot get it back.")
                }

                Section {
                    Text(document.summary)
                        .font(.subheadline)
                    NavigationLink("Preview") {
                        BridgeExportPreview(document: document)
                    }
                    .disabled(document.isEmpty)
                    Button {
                        if let url = BridgeExporter.makePDF(document: document) {
                            shareURL = IdentifiableURL(url: url)
                        } else {
                            failed = true
                        }
                    } label: {
                        Label("Make a PDF to share", systemImage: "doc.richtext")
                    }
                    .disabled(document.isEmpty || makingPage)
                    Button {
                        makingPage = true
                        let secret: String? = password.isEmpty ? nil : password
                        Task {
                            let url = await Task.detached(priority: .userInitiated) {
                                BridgeHTMLExporter.makeHTML(document: document, password: secret)
                            }.value
                            makingPage = false
                            if let url { shareURL = IdentifiableURL(url: url) } else { failed = true }
                        }
                    } label: {
                        Label(makingPage ? "Making the web page..." : "Make a web page to share", systemImage: "safari")
                    }
                    .disabled(document.isEmpty || makingPage || passwordTooShort)
                } header: {
                    Text("What it holds")
                } footer: {
                    Text("The web page opens in any browser, with search, a timeline and buttons to print or save a PDF, or to download a CSV or a Word file. It works on its own, and nothing in it is sent anywhere. Some mail apps block web page attachments, so a PDF is the safer thing to send.")
                }
            }
            .navigationTitle("Export for someone")
            .navigationBarTitleDisplayMode(.inline)
            .guideButton("bridge.export", tab: .bridge)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $shareURL) { wrapped in
                ShareSheet(activityItems: [wrapped.url])
            }
            .alert("Could not make the file", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func categoryRow(_ category: ExportCategory, builder: BridgeExportBuilder) -> some View {
        let on = selection.categories.contains(category)
        let available = builder.candidates(category)
        let count = builder.included(category).count
        Toggle(isOn: Binding(
            get: { on },
            set: { newValue in
                if newValue { selection.categories.insert(category) } else { selection.categories.remove(category) }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Label(category.title, systemImage: category.icon)
                Text(on ? "\(count) of \(available.count) included" : "\(available.count) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(Anchor.Theme.accent)
        if on, !available.isEmpty {
            NavigationLink("Choose which") {
                BridgeExportItemPicker(title: category.title, rows: available, left: $selection.left)
            }
            .font(.subheadline)
        }
    }
}

/// Tick or untick individual items for one kind.
private struct BridgeExportItemPicker: View {
    let title: String
    let rows: [ExportCandidate]
    @Binding var left: Set<UUID>

    var body: some View {
        List {
            Section {
                Button("Include all") { left.subtract(rows.map(\.id)) }
                Button("Leave all out") { left.formUnion(rows.map(\.id)) }
            }
            Section {
                ForEach(rows) { row in
                    Button {
                        if left.contains(row.id) { left.remove(row.id) } else { left.insert(row.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: left.contains(row.id) ? "circle" : "checkmark.circle.fill")
                                .foregroundStyle(left.contains(row.id) ? Color.secondary : Anchor.Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                if let date = row.entry.date {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .accessibilityAddTraits(left.contains(row.id) ? [] : .isSelected)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The document as it will read, before any file is made.
private struct BridgeExportPreview: View {
    let document: ExportDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(document.title)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text("Prepared " + document.created.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let range = document.rangeText {
                    Text(range)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !document.coverNote.isEmpty {
                    Text(document.coverNote)
                }
                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.category.title)
                            .font(.system(.headline, design: .rounded))
                        ForEach(section.entries) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                if let date = entry.date {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let heading = entry.heading {
                                    Text(heading).font(.subheadline.weight(.semibold))
                                }
                                ForEach(Array(entry.lines.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                }
                                if let footnote = entry.footnote {
                                    Text(footnote)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - The PDF

enum BridgeExporter {
    /// "Anchor-for-Dr-Patel-2026-11-08.pdf", or "Anchor-export-2026-11-08.pdf" with no name.
    static func fileName(for document: ExportDocument, ext: String = "pdf") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: document.created)
        guard let name = document.recipient else { return "Anchor-export-\(day).\(ext)" }
        let cleaned = name.filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
            .split(separator: " ").joined(separator: "-")
        let short = String(cleaned.prefix(40))
        return short.isEmpty ? "Anchor-export-\(day).\(ext)" : "Anchor-for-\(short)-\(day).\(ext)"
    }

    static func makePDF(document: ExportDocument) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let textWidth = pageWidth - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("anchor-export-\(UUID().uuidString)", isDirectory: true)
        let url = folder.appendingPathComponent(fileName(for: document))

        let titleFont = UIFont.boldSystemFont(ofSize: 22)
        let headingFont = UIFont.boldSystemFont(ofSize: 15)
        let boldFont = UIFont.boldSystemFont(ofSize: 12)
        let bodyFont = UIFont.systemFont(ofSize: 12)
        let smallFont = UIFont.systemFont(ofSize: 10)

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y: CGFloat = margin

                /// Draws one block of text, starting a new page when it will not fit.
                func draw(_ text: String, font: UIFont, color: UIColor = .black, after: CGFloat = 6) {
                    for piece in chunks(text) {
                        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                        let height = (piece as NSString).boundingRect(
                            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                            options: .usesLineFragmentOrigin, attributes: attributes, context: nil
                        ).height
                        if y + height > pageHeight - margin {
                            context.beginPage()
                            y = margin
                        }
                        (piece as NSString).draw(in: CGRect(x: margin, y: y, width: textWidth, height: height + 2), withAttributes: attributes)
                        y += height + after
                    }
                }

                draw(document.title, font: titleFont, after: 8)
                draw("Prepared " + document.created.formatted(date: .abbreviated, time: .shortened), font: smallFont, color: .darkGray, after: 2)
                if let range = document.rangeText { draw(range, font: smallFont, color: .darkGray, after: 2) }
                y += 10
                if !document.coverNote.isEmpty { draw(document.coverNote, font: bodyFont, after: 14) }

                for section in document.sections {
                    y += 8
                    // Keep a heading with at least a little of what follows.
                    if y > pageHeight - margin - 90 {
                        context.beginPage()
                        y = margin
                    }
                    draw(section.category.title, font: headingFont, after: 8)
                    if section.category == .sleep {
                        let nights = SleepPDFChart.nights(from: section.entries)
                        if nights.count >= 2 {
                            if y + SleepPDFChart.height > pageHeight - margin {
                                context.beginPage()
                                y = margin
                            }
                            SleepPDFChart.draw(nights: nights, in: CGRect(x: margin, y: y, width: textWidth, height: SleepPDFChart.height))
                            y += SleepPDFChart.height + 10
                        }
                    }
                    for entry in section.entries {
                        if let date = entry.date {
                            draw(date.formatted(date: .abbreviated, time: .shortened), font: smallFont, color: .gray, after: 1)
                        }
                        if let heading = entry.heading { draw(heading, font: boldFont, after: 2) }
                        for line in entry.lines { draw(line, font: bodyFont, after: 3) }
                        if let footnote = entry.footnote { draw(footnote, font: smallFont, color: .gray, after: 3) }
                        y += 8
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    /// Splits very long text at spaces so no block is taller than a page.
    private static func chunks(_ text: String, limit: Int = 1600) -> [String] {
        guard text.count > limit else { return [text] }
        var result: [String] = []
        var current = ""
        for word in text.split(separator: " ", omittingEmptySubsequences: false) {
            if current.count + word.count + 1 > limit, !current.isEmpty {
                result.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : " ") + word
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

/// The plain line of time asleep drawn into the PDFs, the same rule as the web page:
/// 0 h at the bottom, the next whole hour above the longest night at the top, no
/// target line, and nothing drawn unless two nights have a time.
enum SleepPDFChart {
    struct Night {
        let date: Date
        let minutes: Int
    }

    static let height: CGFloat = 130

    /// Nights that have a time asleep, oldest first.
    static func nights(from entries: [ExportEntry]) -> [Night] {
        entries.compactMap { entry -> Night? in
            guard let date = entry.date,
                  let value = entry.values.first(where: { $0.label == "Time asleep" }) else { return nil }
            return Night(date: date, minutes: Int(value.number))
        }.sorted { $0.date < $1.date }
    }

    /// The top of the chart in minutes: a whole hour, never under one.
    static func top(of nights: [Night]) -> Int {
        let most = nights.map(\.minutes).max() ?? 0
        return max(60, Int((Double(most) / 60).rounded(.up)) * 60)
    }

    static func draw(nights: [Night], in rect: CGRect) {
        guard nights.count >= 2, let first = nights.first, let last = nights.last else { return }
        let ceiling = SleepPDFChart.top(of: nights)
        let small = UIFont.systemFont(ofSize: 10)
        let boldSmall = UIFont.boldSystemFont(ofSize: 10)

        ("Time asleep" as NSString).draw(at: CGPoint(x: rect.minX, y: rect.minY), withAttributes: [.font: boldSmall, .foregroundColor: UIColor.black])

        let noteY = rect.maxY - 14
        let plot = CGRect(x: rect.minX + 30, y: rect.minY + 20, width: rect.width - 40, height: noteY - rect.minY - 30)
        let gray: [NSAttributedString.Key: Any] = [.font: small, .foregroundColor: UIColor.gray]
        ("0 h" as NSString).draw(at: CGPoint(x: rect.minX, y: plot.maxY - 6), withAttributes: gray)
        ("\(ceiling / 60) h" as NSString).draw(at: CGPoint(x: rect.minX, y: plot.minY - 6), withAttributes: gray)

        let axis = UIBezierPath()
        axis.move(to: CGPoint(x: plot.minX, y: plot.maxY))
        axis.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        UIColor.lightGray.setStroke()
        axis.lineWidth = 0.5
        axis.stroke()

        // Spaced evenly, one step for each night, as the web page does.
        func point(_ night: Night, index: Int) -> CGPoint {
            let across = Double(index) / Double(max(nights.count - 1, 1))
            let up = min(1, max(0, Double(night.minutes) / Double(ceiling)))
            return CGPoint(x: plot.minX + plot.width * CGFloat(across), y: plot.maxY - plot.height * CGFloat(up))
        }

        let line = UIBezierPath()
        for (index, night) in nights.enumerated() {
            let p = point(night, index: index)
            if index == 0 { line.move(to: p) } else { line.addLine(to: p) }
        }
        UIColor.darkGray.setStroke()
        line.lineWidth = 1.5
        line.lineJoinStyle = .round
        line.stroke()

        UIColor.darkGray.setFill()
        for (index, night) in nights.enumerated() {
            let p = point(night, index: index)
            UIBezierPath(ovalIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)).fill()
        }

        let from = first.date.formatted(date: .abbreviated, time: .omitted)
        let to = last.date.formatted(date: .abbreviated, time: .omitted)
        ("\(from) to \(to). Nights with no time are left out." as NSString).draw(at: CGPoint(x: rect.minX, y: noteY), withAttributes: gray)
    }
}

// MARK: - The web page

/// A single .html file with the document inside it and a small viewer: search,
/// a timeline, charts of check-ins, a print stylesheet and buttons for CSV and Word. It has
/// no network access of its own (a strict content security policy pins the one
/// script by its hash) and everything is drawn with textContent, so what was
/// written can never run as code. With a password the document is AES-256-GCM
/// encrypted with a key from PBKDF2-SHA256 (600,000 rounds), and the page
/// decrypts it in the browser with WebCrypto.
enum BridgeHTMLExporter {
    private struct ValueDTO: Encodable { let label: String; let number: Double }
    private struct EntryDTO: Encodable {
        let date: String?
        let dateText: String?
        let heading: String?
        let lines: [String]
        let footnote: String?
        let values: [ValueDTO]
        let bed: String?
        let up: String?
    }
    /// "fraction" values run from 0 to 1 (check-ins); "minutes" is time asleep.
    private struct SectionDTO: Encodable { let key: String; let title: String; let unit: String; let entries: [EntryDTO] }
    private struct DocDTO: Encodable {
        let title: String
        let note: String
        let created: String
        let range: String?
        let fileBase: String
        let sections: [SectionDTO]
    }
    private struct PlainPayload: Encodable {
        let v = 1
        let enc = false
        let doc: DocDTO
    }
    private struct LockedPayload: Encodable {
        let v = 1
        let enc = true
        let salt: String
        let iv: String
        let ct: String
        let iter: Int
    }

    static let iterations = 600_000

    static func makeHTML(document: ExportDocument, password: String?) -> URL? {
        let iso = ISO8601DateFormatter()
        let fileName = BridgeExporter.fileName(for: document, ext: "html")
        let dto = DocDTO(
            title: document.title,
            note: document.coverNote,
            created: document.created.formatted(date: .abbreviated, time: .shortened),
            range: document.rangeText,
            fileBase: String(fileName.dropLast(5)),
            sections: document.sections.map { section in
                SectionDTO(key: section.category.rawValue, title: section.category.title, unit: section.category == .sleep ? "minutes" : "fraction", entries: section.entries.map { entry in
                    EntryDTO(
                        date: entry.date.map { iso.string(from: $0) },
                        dateText: entry.date.map { $0.formatted(date: .abbreviated, time: .shortened) },
                        heading: entry.heading, lines: entry.lines, footnote: entry.footnote,
                        values: entry.values.map { ValueDTO(label: $0.label, number: $0.number) },
                        bed: entry.bedTime.map { iso.string(from: $0) },
                        up: entry.wakeTime.map { iso.string(from: $0) }
                    )
                })
            }
        )

        let encoder = JSONEncoder()
        let json: Data
        do {
            if let password, !password.isEmpty {
                guard let locked = lock(try encoder.encode(dto), password: password) else { return nil }
                json = try encoder.encode(locked)
            } else {
                json = try encoder.encode(PlainPayload(doc: dto))
            }
        } catch {
            return nil
        }
        // "<" can never appear inside the data block, so nothing in it can close the tag.
        let payload = String(decoding: json, as: UTF8.self).replacingOccurrences(of: "<", with: "\\u003c")

        let hash = Data(SHA256.hash(data: Data(viewerScript.utf8))).base64EncodedString()
        let policy = "default-src 'none'; script-src 'sha256-\(hash)'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'"
        let title = document.title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        var page = "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">"
        page += "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        page += "<meta http-equiv=\"Content-Security-Policy\" content=\"\(policy)\">"
        page += "<meta name=\"referrer\" content=\"no-referrer\"><meta name=\"robots\" content=\"noindex\">"
        page += "<title>\(title)</title><style>\(viewerStyle)</style></head><body>"
        page += "<div id=\"app\"><noscript>This page needs JavaScript to show its contents. Ask for the PDF instead.</noscript></div>"
        page += "<script type=\"application/json\" id=\"payload\">\(payload)</script>"
        page += "<script>\(viewerScript)</script></body></html>\n"

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("anchor-export-\(UUID().uuidString)", isDirectory: true)
        let url = folder.appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try page.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func lock(_ plain: Data, password: String) -> LockedPayload? {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess,
              let key = deriveKey(password: password, salt: salt),
              let box = try? AES.GCM.seal(plain, using: key) else { return nil }
        // WebCrypto expects the tag straight after the ciphertext.
        return LockedPayload(
            salt: salt.base64EncodedString(),
            iv: Data(box.nonce).base64EncodedString(),
            ct: (box.ciphertext + box.tag).base64EncodedString(),
            iter: iterations
        )
    }

    private static func deriveKey(password: String, salt: Data) -> SymmetricKey? {
        let secret = Array(password.precomposedStringWithCanonicalMapping.utf8)
        guard !secret.isEmpty else { return nil }
        var derived = [UInt8](repeating: 0, count: 32)
        let status = secret.withUnsafeBufferPointer { secretBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    UnsafeRawPointer(secretBytes.baseAddress!).assumingMemoryBound(to: Int8.self), secret.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress!, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                    &derived, derived.count
                )
            }
        }
        return status == kCCSuccess ? SymmetricKey(data: derived) : nil
    }

    private static let viewerStyle = #"""
:root{--bg:#faf7f2;--fg:#2b2622;--muted:#6f6760;--card:#fff;--line:#e4ddd3;--accent:#b5603c;color-scheme:light dark}
@media (prefers-color-scheme:dark){:root{--bg:#1d1b19;--fg:#ece6df;--muted:#a69d94;--card:#262320;--line:#3a3530;--accent:#e08a63}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
#app{max-width:760px;margin:0 auto;padding:24px 18px 60px}
h1{font-size:1.7rem;margin:0 0 4px}
h2{font-size:1.15rem;margin:28px 0 10px;padding-bottom:6px;border-bottom:1px solid var(--line)}
h3{font-size:1rem;margin:2px 0 4px}
.meta,.date,.foot,.note,.footer,.badge{color:var(--muted);font-size:.85rem}
.cover{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 14px;white-space:pre-wrap}
.toolbar{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0 6px;align-items:center}
.toolbar input[type=search]{flex:1 1 180px;padding:9px 12px;border:1px solid var(--line);border-radius:10px;background:var(--card);color:var(--fg);font:inherit}
button{font:inherit;padding:8px 12px;border:1px solid var(--line);border-radius:10px;background:var(--card);color:var(--fg);cursor:pointer}
button:hover{border-color:var(--accent)}
button:focus-visible,input:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
button.primary{background:var(--accent);border-color:var(--accent);color:#fff}
.seg{display:flex}.seg button{border-radius:0}.seg button:first-child{border-radius:10px 0 0 10px}.seg button:last-child{border-radius:0 10px 10px 0;border-left:0}
.seg button.on{background:var(--accent);border-color:var(--accent);color:#fff}
.entry{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 14px;margin:8px 0}
.entry p{margin:4px 0;white-space:pre-wrap;overflow-wrap:anywhere}
.badge{text-transform:uppercase;letter-spacing:.04em;font-size:.7rem}
.charts{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:10px;margin-bottom:10px}
.chart{margin:0;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px 10px}
.chart figcaption{font-size:.85rem;color:var(--muted)}
.chart svg{width:100%;height:auto;display:block}
.axis{stroke:var(--line);stroke-width:1}
.plot{fill:none;stroke:var(--accent);stroke-width:2.5;stroke-linejoin:round;stroke-linecap:round}
.unlock{max-width:380px;margin:12vh auto 0;display:flex;flex-direction:column;gap:10px}
.unlock input{padding:10px 12px;border:1px solid var(--line);border-radius:10px;background:var(--card);color:var(--fg);font:inherit}
.msg{min-height:1.4em;color:var(--accent)}
.footer{margin-top:36px;text-align:center}
@media print{
  :root{--bg:#fff;--fg:#000;--muted:#444;--card:#fff;--line:#bbb;--accent:#000}
  .toolbar,.footer{display:none}
  #app{max-width:none;padding:0}
  .entry,.chart{break-inside:avoid}
  h2{break-after:avoid}
  .cover{border-color:#999}
}
"""#

    private static let viewerScript = #"""
(function () {
  "use strict";
  var payload = JSON.parse(document.getElementById("payload").textContent);
  var app = document.getElementById("app");
  var doc = null;
  var query = "";
  var mode = "sections";

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = text;
    return e;
  }
  function b64(s) {
    var bin = atob(s), out = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  }

  // ---------- locked pages ----------
  function showUnlock() {
    app.textContent = "";
    var box = el("form", "unlock");
    box.appendChild(el("h1", null, "This page is locked"));
    box.appendChild(el("p", null, "Enter the password you were given. It is checked here in your browser and is never sent anywhere."));
    var label = el("label", null, "Password");
    var input = el("input");
    input.type = "password";
    input.autocomplete = "off";
    input.id = "pw";
    label.htmlFor = "pw";
    var button = el("button", "primary", "Unlock");
    button.type = "submit";
    var msg = el("p", "msg");
    msg.setAttribute("role", "alert");
    box.appendChild(label); box.appendChild(input); box.appendChild(button); box.appendChild(msg);
    box.addEventListener("submit", function (ev) {
      ev.preventDefault();
      msg.textContent = "";
      if (!(window.crypto && window.crypto.subtle)) {
        msg.textContent = "This browser cannot unlock the page from a file. Try opening it in Safari, Chrome or Firefox, or ask for the PDF instead.";
        return;
      }
      button.disabled = true;
      msg.textContent = "Unlocking...";
      decrypt(input.value).then(function (d) {
        doc = d;
        render();
      }).catch(function () {
        button.disabled = false;
        msg.textContent = "That password did not work.";
      });
    });
    app.appendChild(box);
    input.focus();
  }

  function decrypt(password) {
    var enc = new TextEncoder();
    return crypto.subtle.importKey("raw", enc.encode(password.normalize("NFC")), "PBKDF2", false, ["deriveKey"]).then(function (base) {
      return crypto.subtle.deriveKey(
        { name: "PBKDF2", salt: b64(payload.salt), iterations: payload.iter, hash: "SHA-256" },
        base, { name: "AES-GCM", length: 256 }, false, ["decrypt"]);
    }).then(function (key) {
      return crypto.subtle.decrypt({ name: "AES-GCM", iv: b64(payload.iv) }, key, b64(payload.ct));
    }).then(function (plain) {
      return JSON.parse(new TextDecoder().decode(plain));
    });
  }

  // ---------- the document ----------
  function matches(entry) {
    if (!query) return true;
    var hay = [entry.heading || "", entry.lines.join(" "), entry.footnote || "", entry.dateText || ""].join(" ").toLowerCase();
    return hay.indexOf(query) !== -1;
  }

  function entryNode(entry, sectionTitle) {
    var card = el("article", "entry");
    if (sectionTitle) card.appendChild(el("div", "badge", sectionTitle));
    if (entry.dateText) card.appendChild(el("div", "date", entry.dateText));
    if (entry.heading) card.appendChild(el("h3", null, entry.heading));
    entry.lines.forEach(function (line) { card.appendChild(el("p", null, line)); });
    if (entry.footnote) card.appendChild(el("div", "foot", entry.footnote));
    return card;
  }

  var SVGNS = "http://www.w3.org/2000/svg";
  function chartFor(section) {
    var rows = section.entries.filter(function (e) { return e.values && e.values.length && e.date; })
      .sort(function (a, b) { return a.date < b.date ? -1 : 1; });
    if (rows.length < 2) return null;
    var wrap = el("div", "charts");
    var minutes = section.unit === "minutes";
    var top = 1;
    if (minutes) {
      var most = 0;
      rows.forEach(function (r) { r.values.forEach(function (x) { if (x.number > most) most = x.number; }); });
      top = Math.max(60, Math.ceil(most / 60) * 60);
    }
    var labels = [];
    rows[0].values.forEach(function (v) { labels.push(v.label); });
    labels.forEach(function (label) {
      var W = 600, H = 110, P = 8;
      var svg = document.createElementNS(SVGNS, "svg");
      svg.setAttribute("viewBox", "0 0 " + W + " " + H);
      svg.setAttribute("role", "img");
      svg.setAttribute("aria-label", label + " over time, from " + rows[0].dateText + " to " + rows[rows.length - 1].dateText);
      var pts = rows.map(function (r, i) {
        var v = 0;
        r.values.forEach(function (x) { if (x.label === label) v = x.number; });
        var x = P + (W - 2 * P) * (rows.length === 1 ? 0 : i / (rows.length - 1));
        var y = H - P - (H - 2 * P) * Math.max(0, Math.min(1, v / top));
        return x.toFixed(1) + "," + y.toFixed(1);
      });
      var base = document.createElementNS(SVGNS, "line");
      base.setAttribute("x1", P); base.setAttribute("x2", W - P);
      base.setAttribute("y1", H - P); base.setAttribute("y2", H - P);
      base.setAttribute("class", "axis");
      svg.appendChild(base);
      var line = document.createElementNS(SVGNS, "polyline");
      line.setAttribute("points", pts.join(" "));
      line.setAttribute("class", "plot");
      svg.appendChild(line);
      var box = el("figure", "chart");
      box.appendChild(el("figcaption", null, label));
      box.appendChild(svg);
      wrap.appendChild(box);
    });
    var span = rows[0].dateText + " to " + rows[rows.length - 1].dateText + ".";
    wrap.appendChild(el("p", "note", (minutes
      ? "Each line shows time asleep from 0 h (bottom) to " + (top / 60) + " h (top). "
      : "Each line runs from empty (bottom) to full (top). ") + span));
    return wrap;
  }

  function csvCell(value) {
    var s = String(value === undefined || value === null ? "" : value).replace(/\r?\n/g, " ");
    if (/^[=+\-@\t]/.test(s)) s = "'" + s;
    return '"' + s.replace(/"/g, '""') + '"';
  }
  function downloadCSV() {
    var rows = [["section", "date", "heading", "text", "note", "in_bed", "up", "minutes_asleep"]];
    doc.sections.forEach(function (s) {
      s.entries.forEach(function (e) {
        var asleep = "";
        if (s.unit === "minutes") {
          (e.values || []).forEach(function (x) { if (x.label === "Time asleep") asleep = x.number; });
        }
        rows.push([s.title, e.date || "", e.heading || "", e.lines.join(" | "), e.footnote || "", e.bed || "", e.up || "", asleep]);
      });
    });
    var text = "\uFEFF" + rows.map(function (r) { return r.map(csvCell).join(","); }).join("\r\n");
    saveBlob(new Blob([text], { type: "text/csv;charset=utf-8" }), ".csv");
  }
  function saveBlob(blob, ext) {
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = (doc.fileBase || "anchor-export") + ext;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 4000);
  }

  // ---------- Word (.docx), made here with no library ----------
  var crcTable = null;
  function crc32(bytes) {
    if (!crcTable) {
      crcTable = new Uint32Array(256);
      for (var n = 0; n < 256; n++) {
        var c = n;
        for (var k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
        crcTable[n] = c >>> 0;
      }
    }
    var crc = 0xFFFFFFFF;
    for (var i = 0; i < bytes.length; i++) crc = crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >>> 8);
    return (crc ^ 0xFFFFFFFF) >>> 0;
  }
  function u16(v) { return [v & 255, (v >>> 8) & 255]; }
  function u32(v) { return [v & 255, (v >>> 8) & 255, (v >>> 16) & 255, (v >>> 24) & 255]; }
  function joinBytes(parts) {
    var total = 0;
    parts.forEach(function (p) { total += p.length; });
    var out = new Uint8Array(total), at = 0;
    parts.forEach(function (p) { out.set(p, at); at += p.length; });
    return out;
  }
  // A zip with every file stored as it is. A .docx opens fine this way.
  function zipStored(files) {
    var enc = new TextEncoder();
    var now = new Date();
    var year = Math.max(1980, now.getFullYear());
    var dosTime = (now.getHours() << 11) | (now.getMinutes() << 5) | (now.getSeconds() >> 1);
    var dosDate = ((year - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();
    var body = [], central = [], offset = 0;
    files.forEach(function (f) {
      var name = enc.encode(f.name);
      var data = enc.encode(f.text);
      var crc = crc32(data);
      var head = new Uint8Array([].concat(
        u32(0x04034b50), u16(20), u16(0x0800), u16(0), u16(dosTime), u16(dosDate),
        u32(crc), u32(data.length), u32(data.length), u16(name.length), u16(0)));
      body.push(head, name, data);
      central.push(new Uint8Array([].concat(
        u32(0x02014b50), u16(20), u16(20), u16(0x0800), u16(0), u16(dosTime), u16(dosDate),
        u32(crc), u32(data.length), u32(data.length), u16(name.length),
        u16(0), u16(0), u16(0), u16(0), u32(0), u32(offset))), name);
      offset += head.length + name.length + data.length;
    });
    var centralBytes = joinBytes(central);
    var end = new Uint8Array([].concat(
      u32(0x06054b50), u16(0), u16(0), u16(files.length), u16(files.length),
      u32(centralBytes.length), u32(offset), u16(0)));
    return joinBytes(body.concat([centralBytes, end]));
  }

  function xmlText(s) {
    return String(s === undefined || s === null ? "" : s)
      .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\uFFFE\uFFFF]/g, "")
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }
  function wPara(style, text, before) {
    var props = "";
    if (style || before) {
      props = "<w:pPr>" + (style ? '<w:pStyle w:val="' + style + '"/>' : "") +
        (before ? '<w:spacing w:before="' + before + '"/>' : "") + "</w:pPr>";
    }
    var runs = String(text === undefined || text === null ? "" : text).split(/\r\n|\r|\n/).map(function (part, i) {
      return (i ? "<w:r><w:br/></w:r>" : "") + '<w:r><w:t xml:space="preserve">' + xmlText(part) + "</w:t></w:r>";
    }).join("");
    return "<w:p>" + props + runs + "</w:p>";
  }
  function wordParts() {
    var parts = [wPara("Title", doc.title)];
    parts.push(wPara("Small", "Prepared " + doc.created + (doc.range ? " | " + doc.range : "")));
    if (doc.note) parts.push(wPara("Note", doc.note, 160));
    doc.sections.forEach(function (s) {
      if (!s.entries.length) return;
      parts.push(wPara("Heading1", s.title + " (" + s.entries.length + ")"));
      s.entries.forEach(function (e) {
        var first = true;
        function next(style, text) {
          parts.push(wPara(style, text, first ? 200 : 0));
          first = false;
        }
        if (e.dateText) next("Small", e.dateText);
        if (e.heading) next("Heading2", e.heading);
        e.lines.forEach(function (line) { next("", line); });
        if (e.footnote) next("Small", e.footnote);
        if (first) next("", "");
      });
    });
    return parts;
  }
  function wordFile() {
    var usLetter = /-(US|CA|MX|PH)$/i.test(navigator.language || "");
    var page = usLetter ? 'w:w="12240" w:h="15840"' : 'w:w="11906" w:h="16838"';
    var ns = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
    var head = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    var documentXml = head + "<w:document " + ns + "><w:body>" + wordParts().join("") +
      "<w:sectPr><w:pgSz " + page + '/><w:pgMar w:top="1300" w:right="1300" w:bottom="1300" w:left="1300" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>';
    function style(id, name, based, ppr, rpr) {
      return '<w:style w:type="paragraph" w:styleId="' + id + '"><w:name w:val="' + name + '"/>' +
        (based ? '<w:basedOn w:val="Normal"/>' : "") + "<w:qFormat/>" +
        (ppr ? "<w:pPr>" + ppr + "</w:pPr>" : "") + (rpr ? "<w:rPr>" + rpr + "</w:rPr>" : "") + "</w:style>";
    }
    var stylesXml = head + "<w:styles " + ns + '><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-AU"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="100" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>' +
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>' +
      style("Title", "Title", true, '<w:spacing w:after="60"/>', '<w:b/><w:sz w:val="40"/><w:szCs w:val="40"/>') +
      style("Heading1", "heading 1", true, '<w:keepNext/><w:pBdr><w:bottom w:val="single" w:sz="4" w:space="3" w:color="BBBBBB"/></w:pBdr><w:spacing w:before="360" w:after="120"/><w:outlineLvl w:val="0"/>', '<w:b/><w:sz w:val="30"/><w:szCs w:val="30"/>') +
      style("Heading2", "heading 2", true, '<w:keepNext/><w:spacing w:after="40"/><w:outlineLvl w:val="1"/>', '<w:b/><w:sz w:val="24"/><w:szCs w:val="24"/>') +
      style("Small", "Small", true, '<w:spacing w:after="40"/>', '<w:color w:val="6F6760"/><w:sz w:val="18"/><w:szCs w:val="18"/>') +
      style("Note", "Note", true, '<w:pBdr><w:left w:val="single" w:sz="18" w:space="8" w:color="B5603C"/></w:pBdr><w:ind w:left="200"/><w:spacing w:after="160"/>', "") +
      "</w:styles>";
    var types = head + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>';
    var rels = head + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>';
    var docRels = head + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>';
    return zipStored([
      { name: "[Content_Types].xml", text: types },
      { name: "_rels/.rels", text: rels },
      { name: "word/document.xml", text: documentXml },
      { name: "word/_rels/document.xml.rels", text: docRels },
      { name: "word/styles.xml", text: stylesXml }
    ]);
  }
  function downloadWord() {
    saveBlob(new Blob([wordFile()], { type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }), ".docx");
  }


  function render() {
    app.textContent = "";
    var head = el("header", "head");
    head.appendChild(el("h1", null, doc.title));
    head.appendChild(el("p", "meta", "Prepared " + doc.created + (doc.range ? " | " + doc.range : "")));
    if (doc.note) head.appendChild(el("p", "cover", doc.note));
    app.appendChild(head);

    var bar = el("div", "toolbar");
    var search = el("input");
    search.type = "search";
    search.placeholder = "Search";
    search.setAttribute("aria-label", "Search");
    search.value = query;
    search.addEventListener("input", function () { query = search.value.trim().toLowerCase(); renderBody(); });
    bar.appendChild(search);

    var group = el("div", "seg");
    [["sections", "By section"], ["timeline", "Timeline"]].forEach(function (m) {
      var b = el("button", mode === m[0] ? "on" : "", m[1]);
      b.type = "button";
      b.addEventListener("click", function () { mode = m[0]; render(); });
      group.appendChild(b);
    });
    bar.appendChild(group);

    var print = el("button", null, "Print or save as PDF");
    print.type = "button";
    print.addEventListener("click", function () { window.print(); });
    bar.appendChild(print);
    var csv = el("button", null, "Download CSV");
    csv.type = "button";
    csv.addEventListener("click", downloadCSV);
    bar.appendChild(csv);
    var word = el("button", null, "Download Word file");
    word.type = "button";
    word.addEventListener("click", downloadWord);
    bar.appendChild(word);
    app.appendChild(bar);

    var body = el("main");
    body.id = "body";
    app.appendChild(body);
    app.appendChild(el("p", "footer", "This page works entirely in your browser. Nothing in it is sent anywhere."));
    renderBody();
    if (document.activeElement !== search && query) search.focus();
  }

  function renderBody() {
    var body = document.getElementById("body");
    body.textContent = "";
    var shown = 0;
    if (mode === "timeline") {
      var all = [];
      doc.sections.forEach(function (s) { s.entries.forEach(function (e) { all.push({ s: s, e: e }); }); });
      all.sort(function (a, b) {
        if (a.e.date && b.e.date) return a.e.date < b.e.date ? -1 : 1;
        if (a.e.date) return -1;
        if (b.e.date) return 1;
        return 0;
      });
      all.filter(function (x) { return matches(x.e); }).forEach(function (x) {
        body.appendChild(entryNode(x.e, x.s.title));
        shown++;
      });
    } else {
      doc.sections.forEach(function (s) {
        var list = s.entries.filter(matches);
        if (!list.length) return;
        var sec = el("section", "section");
        sec.appendChild(el("h2", null, s.title + " (" + list.length + (list.length !== s.entries.length ? " of " + s.entries.length : "") + ")"));
        if (!query) {
          var chart = chartFor(s);
          if (chart) sec.appendChild(chart);
        }
        list.forEach(function (e) { sec.appendChild(entryNode(e)); shown++; });
        body.appendChild(sec);
      });
    }
    if (!shown) body.appendChild(el("p", "empty", query ? "Nothing matches that." : "Nothing here."));
  }

  if (payload.enc) { showUnlock(); } else { doc = payload.doc; render(); }
})();
"""#
}
