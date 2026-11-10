//
//  OnePageSummary.swift
//  Anchor
//
//  A one-page layout (30r, D30, D32). It is a way of laying out what Session prep and
//  Export for someone already hold, on one page. It is not a new screen and it makes
//  nothing up: it holds the person's own words and plain facts (what they logged, plain
//  tallies, their notes) in the order described in D47, with no sentence about how they
//  have been and no score, label or reading.
//
//  To fit a page the print gets smaller, in steps, down to a floor. Nothing is cut to make
//  it fit. If it still would not fit, it says so and makes nothing, and the person leaves
//  something out or uses the full PDF.
//
//  Made on the phone and handed to the share sheet. Nothing is uploaded and nothing is kept.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - What goes on the page

/// One group of lines on the page. The first block of a section carries the section's heading.
struct OnePageBlock {
    var heading: String?
    var date: String?
    var title: String?
    var lines: [String]
    var note: String?
}

struct OnePageSummary {
    var title: String
    var details: [String]
    var coverNote: String
    var blocks: [OnePageBlock]
    var fileName: String

    var isEmpty: Bool { blocks.isEmpty }

    /// Every character that will be printed, used to see at a glance that something is far too long.
    var totalCharacters: Int {
        var total = title.count + coverNote.count
        for detail in details { total += detail.count }
        for block in blocks {
            total += (block.heading?.count ?? 0) + (block.date?.count ?? 0) + (block.title?.count ?? 0) + (block.note?.count ?? 0)
            for line in block.lines { total += line.count }
        }
        return total
    }

    /// "Anchor-one-page-for-Dr-Patel-2026-11-08.pdf". The name is cleaned the way the full PDF's is.
    static func makeFileName(start: String, name: String?, created: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: created)
        let cleaned = (name ?? "").filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }
            .split(separator: " ").joined(separator: "-")
        let short = String(cleaned.prefix(40))
        return short.isEmpty ? "\(start)-\(day).pdf" : "\(start)-\(short)-\(day).pdf"
    }

    /// Export for someone, laid out on one page: the same document the preview and the full PDF read.
    static func from(document: ExportDocument) -> OnePageSummary {
        var details = ["Prepared " + document.created.formatted(date: .abbreviated, time: .shortened)]
        if let range = document.rangeText { details.append(range) }
        var blocks: [OnePageBlock] = []
        for section in document.sections {
            for (index, entry) in section.entries.enumerated() {
                // A night of sleep names its date in its heading already.
                let dateText: String? = section.category == .sleep
                    ? nil
                    : entry.date.map { $0.formatted(date: .abbreviated, time: .shortened) }
                let sectionHeading: String? = index == 0 ? section.category.title : nil
                blocks.append(OnePageBlock(
                    heading: sectionHeading, date: dateText, title: entry.heading,
                    lines: entry.lines, note: entry.footnote
                ))
            }
        }
        return OnePageSummary(
            title: document.title, details: details, coverNote: document.coverNote, blocks: blocks,
            fileName: makeFileName(start: document.recipient == nil ? "Anchor-one-page" : "Anchor-one-page-for",
                               name: document.recipient, created: document.created)
        )
    }
}

// MARK: - Fitting and drawing

enum OnePageFit: Equatable {
    case fits
    case tooLong(pages: Int)
}

enum OnePagePDF {
    static let pageWidth: CGFloat = 612
    static let pageHeight: CGFloat = 792
    static let margin: CGFloat = 40

    /// Body sizes tried in turn, largest first. The last is the floor: below it the page is
    /// too long and nothing is made.
    static let bodySizes: [CGFloat] = [11, 10.5, 10, 9.5, 9, 8.5]

    /// More than this many characters cannot fit at the floor, so it is called too long
    /// without measuring. The number is generous; the measured pass decides the close cases.
    private static let characterCeiling = 9000
    private static let charactersPerPage = 6500

    /// Walks the page from the top. With `draw` off it only adds up heights, so what is
    /// measured is exactly what is drawn. Returns the y position after the last line.
    private static func flow(_ summary: OnePageSummary, body: CGFloat, draw: Bool) -> CGFloat {
        let textWidth = pageWidth - margin * 2
        let scale = body / 11
        let titleFont = UIFont.boldSystemFont(ofSize: 20 * scale)
        let headingFont = UIFont.boldSystemFont(ofSize: body + 2)
        let boldFont = UIFont.boldSystemFont(ofSize: body)
        let bodyFont = UIFont.systemFont(ofSize: body)
        let smallFont = UIFont.systemFont(ofSize: max(body - 2, 7.5))
        var y = margin

        func put(_ text: String, font: UIFont, color: UIColor = .black, after: CGFloat) {
            guard !text.isEmpty else { return }
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let height = ceil((text as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin, attributes: attributes, context: nil
            ).height)
            if draw {
                (text as NSString).draw(in: CGRect(x: margin, y: y, width: textWidth, height: height + 2), withAttributes: attributes)
            }
            y += height + after
        }

        put(summary.title, font: titleFont, after: 4 * scale)
        for detail in summary.details { put(detail, font: smallFont, color: .darkGray, after: 1) }
        y += 6 * scale
        if !summary.coverNote.isEmpty { put(summary.coverNote, font: bodyFont, after: 8 * scale) }

        for block in summary.blocks {
            if let heading = block.heading {
                y += 6 * scale
                put(heading, font: headingFont, after: 4 * scale)
            }
            if let date = block.date { put(date, font: smallFont, color: .gray, after: 1) }
            if let title = block.title { put(title, font: boldFont, after: 1) }
            for line in block.lines { put(line, font: bodyFont, after: 2) }
            if let footnote = block.note { put(footnote, font: smallFont, color: .gray, after: 2) }
            y += 4 * scale
        }
        return y
    }

    /// The largest body size at which everything fits on the page, or nil if none does.
    private static func largestFittingSize(_ summary: OnePageSummary) -> CGFloat? {
        if summary.totalCharacters > characterCeiling { return nil }
        for size in bodySizes where flow(summary, body: size, draw: false) <= pageHeight - margin {
            return size
        }
        return nil
    }

    static func fit(_ summary: OnePageSummary) -> OnePageFit {
        if summary.isEmpty || largestFittingSize(summary) != nil { return .fits }
        let characters = summary.totalCharacters
        if characters > characterCeiling {
            return .tooLong(pages: max(2, Int(ceil(Double(characters) / Double(charactersPerPage)))))
        }
        let floorHeight = flow(summary, body: bodySizes.last ?? 8.5, draw: false) - margin
        let pages = Int(ceil(floorHeight / (pageHeight - margin * 2)))
        return .tooLong(pages: max(2, pages))
    }

    /// Makes the one-page PDF, or nil when it does not fit or the file could not be written.
    static func makePDF(_ summary: OnePageSummary) -> URL? {
        guard let size = largestFittingSize(summary) else { return nil }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("anchor-export-\(UUID().uuidString)", isDirectory: true)
        let url = folder.appendingPathComponent(summary.fileName)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                _ = flow(summary, body: size, draw: true)
            }
            return url
        } catch {
            return nil
        }
    }

    /// The sentence shown when it does not fit, the same wherever it appears.
    static func tooLongText(pages: Int) -> String {
        "This is too long for one page, even in small print (about \(pages) pages). Leave some things out to use it. Nothing is cut to make it fit."
    }
}

/// The page as it will read, before any file is made.
struct OnePagePreview: View {
    let summary: OnePageSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(summary.title)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                ForEach(Array(summary.details.enumerated()), id: \.offset) { _, detail in
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !summary.coverNote.isEmpty { Text(summary.coverNote) }
                ForEach(Array(summary.blocks.enumerated()), id: \.offset) { _, block in
                    VStack(alignment: .leading, spacing: 3) {
                        if let heading = block.heading {
                            Text(heading)
                                .font(.system(.headline, design: .rounded))
                                .padding(.top, 8)
                        }
                        if let date = block.date {
                            Text(date).font(.caption).foregroundStyle(.secondary)
                        }
                        if let title = block.title {
                            Text(title).font(.subheadline.weight(.semibold))
                        }
                        ForEach(Array(block.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                        }
                        if let note = block.note {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Session prep, one page

/// Choose what goes on a one-page sheet for the next session, then make a PDF. What the
/// person wrote for this session (prep notes, what is waiting to be raised, what to bring) is
/// on to begin with. The looking back (Recovery, journal and check-in counts, sleep) is left
/// out until it is switched on, the same rule as Export for someone. The lines are the ones
/// the cards on Session prep already show, built by the same code.
struct SessionOnePageSheet: View {
    let seriesName: String
    let providerID: UUID
    let sessionDate: Date
    let prepNotes: String
    let toBring: [QuickListItem]
    let since: Date
    let sinceIsLastSession: Bool
    let excluding: Set<UUID>

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecoveryCounter.sortOrder) private var allCounters: [RecoveryCounter]
    @Query private var allUrges: [RecoveryUrge]
    @Query private var allEntries: [JournalEntry]
    @Query private var allCheckIns: [CheckIn]
    @Query private var allNightsStored: [SleepEntry]
    /// Sorted after the items are opened, because a locked nightDate cannot be sorted by the database (Patch 35g1b).
    private var allNights: [SleepEntry] { allNightsStored.sortedByKey(descending: true) { $0.nightDate } }
    @Query private var allItemsStored: [BridgeDraftItem]
    /// Sorted after the items are opened, because a locked createdAt cannot be sorted by the database (Patch 35g2).
    private var allItems: [BridgeDraftItem] { allItemsStored.sortedByKey { $0.createdAt } }
    @Query(sort: \AppointmentSeries.sortOrder) private var providers: [AppointmentSeries]

    /// In the order they are printed: what the person wrote first, then the plain tallies.
    enum Part: String, CaseIterable, Identifiable {
        case notes, raise, bring, recovery, journal, sleep
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .notes: return "list.bullet.clipboard.fill"
            case .raise: return "text.bubble.fill"
            case .bring: return "checklist"
            case .recovery: return "calendar.badge.checkmark"
            case .journal: return "book.closed.fill"
            case .sleep: return "moon.zzz.fill"
            }
        }
    }

    @State private var on: Set<Part> = [.notes, .raise, .bring]
    @State private var shareURL: IdentifiableURL?
    @State private var failed = false

    private func title(_ part: Part) -> String {
        switch part {
        case .notes: return "Prep notes"
        case .raise: return "Waiting to be raised"
        case .bring: return "To bring"
        case .recovery: return sinceIsLastSession ? "Recovery since your last session" : "Recovery lately"
        case .journal: return sinceIsLastSession ? "Journal and check-ins since your last session" : "Journal and check-ins lately"
        case .sleep: return sinceIsLastSession ? "Sleep since your last session" : "Sleep lately"
        }
    }

    private func dayText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    /// The blocks for one part, without a heading. Empty when there is nothing to show.
    private func content(for part: Part) -> [OnePageBlock] {
        switch part {
        case .notes:
            let text = prepNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? [] : [OnePageBlock(lines: [text])]
        case .raise:
            let items = RaiseSessionCard.waitingItems(in: allItems, providerID: providerID, providers: providers)
            if items.isEmpty { return [] }
            return [OnePageBlock(lines: items.map { ($0.isQuestion ? "- Question: " : "- ") + $0.text })]
        case .bring:
            if toBring.isEmpty { return [] }
            return [OnePageBlock(lines: toBring.map { $0.isDone ? "- \($0.text) (ticked)" : "- \($0.text)" })]
        case .recovery:
            let counters = allCounters.filter { !$0.isArchived }
            let window = min(since, .now)...Date.now
            return counters.map { counter in
                OnePageBlock(title: counter.name, lines: RecoverySummary.lines(for: counter, urges: allUrges, range: window))
            }
        case .journal:
            let entries = JournalSessionSummaryCard.eligibleEntries(in: allEntries, since: since, excluding: excluding)
            let checkIns = JournalSessionSummaryCard.checkInTally(in: allCheckIns, since: since)
            if entries.isEmpty && checkIns == 0 { return [] }
            let counts = JournalSessionSummaryCard.countsText(entries: entries, checkIns: checkIns)
            return [OnePageBlock(lines: ["Since \(dayText(since)): \(counts)."])]
        case .sleep:
            let nights = SleepSessionSummaryCard.nightsWritten(in: allNights, since: since)
            if nights.isEmpty { return [] }
            return [OnePageBlock(lines: SleepSessionSummaryCard.describingLines(nights: nights, since: since))]
        }
    }

    private var summary: OnePageSummary {
        var blocks: [OnePageBlock] = []
        for part in Part.allCases where on.contains(part) {
            var rows = content(for: part)
            if rows.isEmpty { continue }
            rows[0].heading = title(part)
            blocks.append(contentsOf: rows)
        }
        let now = Date.now
        return OnePageSummary(
            title: "Session with \(seriesName)",
            details: [
                sessionDate.formatted(date: .complete, time: .shortened),
                "Prepared " + now.formatted(date: .abbreviated, time: .shortened)
            ],
            coverNote: "",
            blocks: blocks,
            fileName: OnePageSummary.makeFileName(start: "Anchor-session-prep", name: seriesName, created: now)
        )
    }

    var body: some View {
        let summary = self.summary
        let fit = OnePagePDF.fit(summary)
        NavigationStack {
            Form {
                Section {
                    ForEach(Part.allCases) { part in
                        let has = !content(for: part).isEmpty
                        Toggle(isOn: Binding(
                            get: { on.contains(part) && has },
                            set: { newValue in
                                if newValue { on.insert(part) } else { on.remove(part) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(title(part), systemImage: part.icon)
                                if !has {
                                    Text("Nothing to show yet")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(Anchor.Theme.accent)
                        .disabled(!has)
                    }
                } header: {
                    Text("What goes on the page")
                } footer: {
                    Text("What you wrote for this session is on to begin with. Recovery, journal and check-in counts and sleep are left out unless you switch them on. Check-ins are only counted. Nothing is added for you.")
                }

                Section {
                    NavigationLink("Preview") {
                        OnePagePreview(summary: summary)
                    }
                    .disabled(summary.isEmpty)
                    Button {
                        if let url = OnePagePDF.makePDF(summary) {
                            shareURL = IdentifiableURL(url: url)
                        } else {
                            failed = true
                        }
                    } label: {
                        Label("Make a one-page PDF", systemImage: "doc.richtext")
                    }
                    .disabled(summary.isEmpty || fit != .fits)
                } header: {
                    Text("The page")
                } footer: {
                    switch fit {
                    case .fits:
                        Text("The print gets smaller to fit what you chose. Nothing is cut to make it fit. Nothing leaves this phone until you share the file.")
                    case .tooLong(let pages):
                        Text(OnePagePDF.tooLongText(pages: pages))
                    }
                }
            }
            .navigationTitle("One-page sheet")
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
}
