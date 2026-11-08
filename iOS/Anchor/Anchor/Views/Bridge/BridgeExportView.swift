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
//  Everything is built into one `ExportDocument` first. The preview and the
//  PDF both read it, so they always agree, and other formats can read it too.
//

import SwiftUI
import SwiftData
import UIKit

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

struct ExportEntry: Identifiable {
    let id: UUID
    var date: Date?
    var heading: String?
    var lines: [String]
    var footnote: String?
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
                let line = "Energy \(fmt(check.physicalEnergy)), clarity \(fmt(1 - check.cognitiveBurnout)), room in head \(fmt(1 - check.mentalLoad)), social \(fmt(check.socialEnergy))"
                return ExportCandidate(
                    id: check.id, category: category,
                    headline: check.timestamp.formatted(date: .abbreviated, time: .shortened),
                    entry: ExportEntry(id: check.id, date: check.timestamp, heading: nil, lines: [line], footnote: nil)
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
                    entry: ExportEntry(id: night.id, date: night.nightDate, heading: name, lines: lines, footnote: nil)
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
                        Label("Make a PDF to share", systemImage: "square.and.arrow.up")
                    }
                    .disabled(document.isEmpty)
                } header: {
                    Text("What it holds")
                }
            }
            .navigationTitle("Export for someone")
            .navigationBarTitleDisplayMode(.inline)
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
    static func fileName(for document: ExportDocument) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: document.created)
        guard let name = document.recipient else { return "Anchor-export-\(day).pdf" }
        let cleaned = name.filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
            .split(separator: " ").joined(separator: "-")
        let short = String(cleaned.prefix(40))
        return short.isEmpty ? "Anchor-export-\(day).pdf" : "Anchor-for-\(short)-\(day).pdf"
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
