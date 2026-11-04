//
//  DataControlView.swift
//  Anchor
//
//  Everything the user asked for on data control in one place: see what's
//  stored and roughly how much, export it (full JSON round-trip, or
//  CSV/PDF scoped to Journal + Check-ins specifically — the two things
//  actually meaningful to hand a psych — either all-time or a chosen date
//  range), import a previous Anchor export back in, and clear everything
//  outright. Internal-only data (the mascot's pre-written line pool) is
//  deliberately excluded from export/import/counts — it isn't the user's
//  data, it's app content. Next Hour items are excluded too since they're
//  designed to self-clear and were never meant to be a durable record.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataControlView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var journalEntries: [JournalEntry]
    @Query private var checkIns: [CheckIn]
    @Query private var contacts: [TrustedContact]
    @Query private var groundingTools: [GroundingTool]
    @Query private var safetyPlans: [SafetyPlan]
    @Query private var triggerWindows: [TriggerWindow]
    @Query private var appointmentSeries: [AppointmentSeries]
    @Query private var bridgeDraftItems: [BridgeDraftItem]
    @Query private var diagrams: [FeedbackLoopDiagram]
    @Query private var threadMessages: [ThreadMessage]
    @Query private var supportCalendarEntries: [SupportCalendarEntry]
    @Query private var futureNotes: [FutureNote]
    @Query private var unsentDrafts: [UnsentDraft]
    @Query private var decisionCategories: [DecisionPresetCategory]
    @Query private var deEscalationScripts: [DeEscalationScript]
    @Query private var affirmations: [Affirmation]

    @State private var exportURL: IdentifiableURL?
    @State private var showDateRangeSheet: DateRangeExportKind?
    @State private var showImporter = false
    @State private var importResultMessage: String?
    @State private var showClearConfirm = false
    @State private var showClearedAlert = false

    enum DateRangeExportKind: Identifiable {
        case csv, pdf
        var id: Self { self }
    }

    var body: some View {
        List {
            Section {
                Text("Everything Anchor stores about you, and full control over it: what's kept, what leaves, and the option to clear it all.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            Section("What's stored") {
                countRow("Journal entries", journalEntries.count, icon: "text.quote")
                countRow("Check-ins", checkIns.count, icon: "circle.hexagongrid.fill")
                countRow("Trusted contacts", contacts.count, icon: "person.2.fill")
                countRow("Grounding tools", groundingTools.count, icon: "leaf.fill")
                countRow("Safety plans", safetyPlans.count, icon: "shield.fill")
                countRow("Trigger windows", triggerWindows.count, icon: "clock.fill")
                countRow("Appointment series", appointmentSeries.count, icon: "calendar")
                countRow("Bridge draft items", bridgeDraftItems.count, icon: "doc.text.fill")
                countRow("Feedback-loop diagrams", diagrams.count, icon: "point.3.connected.trianglepath.dotted")
                countRow("Thread messages", threadMessages.count, icon: "bubble.left.and.bubble.right.fill")
                countRow("Support calendar entries", supportCalendarEntries.count, icon: "calendar.badge.clock")
                countRow("Notes to future you", futureNotes.count, icon: "envelope.open.badge.clock")
                countRow("Unsent drafts", unsentDrafts.count, icon: "square.and.pencil")
                countRow("Decision-preset categories", decisionCategories.count, icon: "checklist")
                countRow("De-escalation scripts", deEscalationScripts.count, icon: "wind")
                countRow("Affirmations", affirmations.count, icon: "sparkles")
            }

            Section {
                Button {
                    exportFullJSON()
                } label: {
                    Anchor.MenuRow(icon: "doc.zipper", title: "Export everything (JSON)",
                                   subtitle: "A full backup you can import back in later", tint: Anchor.Theme.accent)
                }
                Button {
                    showDateRangeSheet = .csv
                } label: {
                    Anchor.MenuRow(icon: "tablecells", title: "Export Journal & Check-ins (CSV)",
                                   subtitle: "For spreadsheets, or to hand to your psych", tint: Anchor.Theme.accent)
                }
                Button {
                    showDateRangeSheet = .pdf
                } label: {
                    Anchor.MenuRow(icon: "doc.richtext", title: "Export Journal & Check-ins (PDF)",
                                   subtitle: "Readable printout, all-time or a date range", tint: Anchor.Theme.accent)
                }
            } header: {
                Text("Export")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    Anchor.MenuRow(icon: "square.and.arrow.down", title: "Import from a previous export",
                                   subtitle: "Anchor JSON export files only", tint: Anchor.Theme.sage)
                }
                if let importResultMessage {
                    Text(importResultMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Import")
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Anchor.MenuRow(icon: "trash.fill", title: "Clear all data", tint: .red)
                }
            } header: {
                Text("Danger zone")
            } footer: {
                Text("Deletes everything listed above from this device. This can't be undone, so export first if you want a copy.")
            }
        }
        .navigationTitle("Your data")
        .sheet(item: $exportURL) { wrapped in
            ShareSheet(activityItems: [wrapped.url])
        }
        .sheet(item: $showDateRangeSheet) { kind in
            DateRangeExportSheet(kind: kind) { range in
                switch kind {
                case .csv: exportCSV(range: range)
                case .pdf: exportPDF(range: range)
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .confirmationDialog("Clear all Anchor data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear everything", role: .destructive) { clearAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes everything on this device. Export first if you want to keep a copy.")
        }
        .alert("Data cleared", isPresented: $showClearedAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func countRow(_ label: String, _ count: Int, icon: String) -> some View {
        HStack {
            Anchor.MenuRow(icon: icon, title: label, tint: Anchor.Theme.sage)
            Spacer()
            Text("\(count)")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Full JSON export/import

    private func exportFullJSON() {
        let export = AnchorDataExport(
            journalEntries: journalEntries.map(JournalEntryDTO.init),
            checkIns: checkIns.map(CheckInDTO.init),
            contacts: contacts.map(TrustedContactDTO.init),
            groundingTools: groundingTools.map(GroundingToolDTO.init),
            safetyPlans: safetyPlans.map(SafetyPlanDTO.init),
            triggerWindows: triggerWindows.map(TriggerWindowDTO.init),
            bridgeDraftItems: bridgeDraftItems.map(BridgeDraftItemDTO.init),
            diagrams: diagrams.map(FeedbackLoopDiagramDTO.init),
            threadMessages: threadMessages.map(ThreadMessageDTO.init),
            supportCalendarEntries: supportCalendarEntries.map(SupportCalendarEntryDTO.init),
            futureNotes: futureNotes.map(FutureNoteDTO.init),
            unsentDrafts: unsentDrafts.map(UnsentDraftDTO.init),
            decisionCategories: decisionCategories.map(DecisionPresetCategoryDTO.init),
            deEscalationScripts: deEscalationScripts.map(DeEscalationScriptDTO.init),
            affirmations: affirmations.map(AffirmationDTO.init)
        )
        guard let data = try? JSONEncoder.anchorExport.encode(export) else { return }
        writeAndShare(data: data, filename: "anchor-export-\(fileTimestamp()).json")
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            importResultMessage = "Import didn't complete."
            return
        }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let export = try? JSONDecoder.anchorExport.decode(AnchorDataExport.self, from: data) else {
            importResultMessage = "That file doesn't look like an Anchor export."
            return
        }

        let existingJournalIDs = Set(journalEntries.map(\.id))
        let existingCheckInIDs = Set(checkIns.map(\.id))
        let existingContactIDs = Set(contacts.map(\.id))
        let existingToolIDs = Set(groundingTools.map(\.id))
        let existingSafetyPlanIDs = Set(safetyPlans.map(\.id))
        let existingWindowIDs = Set(triggerWindows.map(\.id))
        let existingBridgeIDs = Set(bridgeDraftItems.map(\.id))
        let existingDiagramIDs = Set(diagrams.map(\.id))
        let existingThreadIDs = Set(threadMessages.map(\.id))
        let existingSupportCalendarIDs = Set(supportCalendarEntries.map(\.id))
        let existingFutureNoteIDs = Set(futureNotes.map(\.id))
        let existingDraftIDs = Set(unsentDrafts.map(\.id))
        let existingCategoryIDs = Set(decisionCategories.map(\.id))
        let existingScriptIDs = Set(deEscalationScripts.map(\.id))
        let existingAffirmationIDs = Set(affirmations.map(\.id))

        var importedCount = 0
        for dto in export.journalEntries where !existingJournalIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.checkIns where !existingCheckInIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.contacts where !existingContactIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.groundingTools where !existingToolIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.safetyPlans where !existingSafetyPlanIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.triggerWindows where !existingWindowIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.bridgeDraftItems where !existingBridgeIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.diagrams where !existingDiagramIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.threadMessages where !existingThreadIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.supportCalendarEntries where !existingSupportCalendarIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.futureNotes where !existingFutureNoteIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.unsentDrafts where !existingDraftIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.decisionCategories where !existingCategoryIDs.contains(dto.id) {
            let category = dto.toModel()
            modelContext.insert(category)
            for choice in category.choices { modelContext.insert(choice) }
            importedCount += 1
        }
        for dto in export.deEscalationScripts where !existingScriptIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.affirmations where !existingAffirmationIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }

        importResultMessage = importedCount == 0
            ? "Nothing new to import. Everything in that file is already here."
            : "Imported \(importedCount) item\(importedCount == 1 ? "" : "s")."
    }

    // MARK: - CSV / PDF (Journal + Check-ins only — the two things worth handing a psych)

    private func exportCSV(range: ClosedRange<Date>?) {
        var lines = ["type,date,text_or_values"]
        for entry in filteredJournal(range) {
            let escaped = entry.text.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ")
            lines.append("journal,\(iso(entry.createdAt)),\"\(escaped)\"")
        }
        for checkIn in filteredCheckIns(range) {
            let values = "energy=\(fmt(checkIn.physicalEnergy)) clarity=\(fmt(1 - checkIn.cognitiveBurnout)) space=\(fmt(1 - checkIn.mentalLoad)) physicalEnergy=\(fmt(checkIn.physicalEnergy)) social=\(fmt(checkIn.socialEnergy))"
            lines.append("checkin,\(iso(checkIn.timestamp)),\"\(values)\"")
        }
        guard let data = lines.joined(separator: "\n").data(using: .utf8) else { return }
        writeAndShare(data: data, filename: "anchor-export-\(fileTimestamp()).csv")
    }

    private func exportPDF(range: ClosedRange<Date>?) {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let headingFont = UIFont.boldSystemFont(ofSize: 13)
            let bodyFont = UIFont.systemFont(ofSize: 11)

            func draw(_ text: String, font: UIFont, indent: CGFloat = 40) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                let maxWidth = pageRect.width - indent - 40
                let bounding = (text as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin, attributes: attributes, context: nil
                )
                if y + bounding.height > pageRect.height - 40 {
                    context.beginPage()
                    y = 40
                }
                (text as NSString).draw(in: CGRect(x: indent, y: y, width: maxWidth, height: bounding.height), withAttributes: attributes)
                y += bounding.height + 10
            }

            draw("Anchor export", font: titleFont, indent: 40)
            draw("Journal entries", font: headingFont)
            for entry in filteredJournal(range) {
                draw("\(entry.createdAt.formatted(date: .abbreviated, time: .shortened))\n\(entry.text)", font: bodyFont)
            }
            draw("Check-ins", font: headingFont)
            for checkIn in filteredCheckIns(range) {
                draw("\(checkIn.timestamp.formatted(date: .abbreviated, time: .shortened)): energy \(fmt(checkIn.physicalEnergy)), clarity \(fmt(1 - checkIn.cognitiveBurnout)), room in head \(fmt(1 - checkIn.mentalLoad)), physical energy \(fmt(checkIn.physicalEnergy)), social \(fmt(checkIn.socialEnergy))", font: bodyFont)
            }
        }
        writeAndShare(data: data, filename: "anchor-export-\(fileTimestamp()).pdf")
    }

    private func filteredJournal(_ range: ClosedRange<Date>?) -> [JournalEntry] {
        journalEntries.filter { range?.contains($0.createdAt) ?? true }.sorted { $0.createdAt < $1.createdAt }
    }
    private func filteredCheckIns(_ range: ClosedRange<Date>?) -> [CheckIn] {
        checkIns.filter { range?.contains($0.timestamp) ?? true }.sorted { $0.timestamp < $1.timestamp }
    }

    private func fmt(_ value: Double) -> String { String(format: "%.2f", value) }
    private func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    private func fileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: .now)
    }

    private func writeAndShare(data: Data, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            exportURL = IdentifiableURL(url: url)
        } catch {
            importResultMessage = "Couldn't create the export file."
        }
    }

    // MARK: - Clear everything

    private func clearAllData() {
        for entry in journalEntries { modelContext.delete(entry) }
        for item in checkIns { modelContext.delete(item) }
        for item in contacts { modelContext.delete(item) }
        for item in groundingTools { modelContext.delete(item) }
        for item in safetyPlans { modelContext.delete(item) }
        for item in triggerWindows { modelContext.delete(item) }
        for item in appointmentSeries { modelContext.delete(item) }
        for item in bridgeDraftItems { modelContext.delete(item) }
        for item in diagrams { modelContext.delete(item) }
        for item in threadMessages { modelContext.delete(item) }
        for item in supportCalendarEntries { modelContext.delete(item) }
        for item in futureNotes { modelContext.delete(item) }
        for item in unsentDrafts { modelContext.delete(item) }
        for item in decisionCategories { modelContext.delete(item) }
        for item in deEscalationScripts { modelContext.delete(item) }
        for item in affirmations { modelContext.delete(item) }
        clearJournalAttachments()
        showClearedAlert = true
    }

    /// Image attachments (photos/drawings inserted into Journal entries)
    /// are plain files in a local folder, not SwiftData objects — deleting
    /// JournalEntry rows above doesn't touch them. Cleared here explicitly
    /// so "clear all data" actually means all of it.
    private func clearJournalAttachments() {
        let folder = JournalAttachmentStore.folderURL
        guard let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return }
        for fileURL in contents {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// Date-range picker shown before a CSV/PDF export — "all data or just
/// data between psych sessions" per the request.
private struct DateRangeExportSheet: View {
    let kind: DataControlView.DateRangeExportKind
    let onExport: (ClosedRange<Date>?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var useRange = false
    @State private var start: Date = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
    @State private var end: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Limit to a date range", isOn: $useRange)
                    .tint(Anchor.Theme.accent)
                if useRange {
                    DatePicker("From", selection: $start, displayedComponents: .date)
                    DatePicker("To", selection: $end, displayedComponents: .date)
                }
            }
            .navigationTitle(kind == .csv ? "Export CSV" : "Export PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        onExport(useRange ? start...end : nil)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Codable DTOs for full JSON export/import
//
// SwiftData @Model classes aren't directly Codable, so each exportable
// type gets a small Codable mirror plus a way back to a live model.
// Deliberately excludes MascotLine (internal app content, not user data)
// and NextHourItem (designed to self-clear, not meant to be a durable
// record) — see the file header.

private extension JSONEncoder {
    static var anchorExport: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }
}
private extension JSONDecoder {
    static var anchorExport: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

struct AnchorDataExport: Codable {
    var journalEntries: [JournalEntryDTO] = []
    var checkIns: [CheckInDTO] = []
    var contacts: [TrustedContactDTO] = []
    var groundingTools: [GroundingToolDTO] = []
    var safetyPlans: [SafetyPlanDTO] = []
    var triggerWindows: [TriggerWindowDTO] = []
    var bridgeDraftItems: [BridgeDraftItemDTO] = []
    var diagrams: [FeedbackLoopDiagramDTO] = []
    var threadMessages: [ThreadMessageDTO] = []
    var supportCalendarEntries: [SupportCalendarEntryDTO] = []
    var futureNotes: [FutureNoteDTO] = []
    var unsentDrafts: [UnsentDraftDTO] = []
    var decisionCategories: [DecisionPresetCategoryDTO] = []
    var deEscalationScripts: [DeEscalationScriptDTO] = []
    var affirmations: [AffirmationDTO] = []
}

struct JournalEntryDTO: Codable {
    var id: UUID; var createdAt: Date; var text: String; var isFavorited: Bool
    var linkedContext: String?; var audioFileName: String?
    init(_ m: JournalEntry) {
        id = m.id; createdAt = m.createdAt; text = m.text; isFavorited = m.isFavorited
        linkedContext = m.linkedContext?.rawValue; audioFileName = m.audioFileName
    }
    func toModel() -> JournalEntry {
        let m = JournalEntry(id: id, createdAt: createdAt, text: text,
                              linkedContext: linkedContext.flatMap(EntryOrigin.init(rawValue:)),
                              audioFileName: audioFileName)
        m.isFavorited = isFavorited
        return m
    }
}

struct CheckInDTO: Codable {
    var id: UUID; var timestamp: Date
    var physicalExhaustion: Double; var cognitiveBurnout: Double; var mentalLoad: Double
    var physicalEnergy: Double; var socialEnergy: Double; var expandedEntryID: UUID?
    init(_ m: CheckIn) {
        id = m.id; timestamp = m.timestamp
        physicalExhaustion = m.physicalExhaustion; cognitiveBurnout = m.cognitiveBurnout; mentalLoad = m.mentalLoad
        physicalEnergy = m.physicalEnergy; socialEnergy = m.socialEnergy; expandedEntryID = m.expandedEntryID
    }
    func toModel() -> CheckIn {
        CheckIn(id: id, timestamp: timestamp, physicalExhaustion: physicalExhaustion,
                cognitiveBurnout: cognitiveBurnout, mentalLoad: mentalLoad,
                physicalEnergy: physicalEnergy, socialEnergy: socialEnergy, expandedEntryID: expandedEntryID)
    }
}

struct TrustedContactDTO: Codable {
    var id: UUID; var name: String; var phoneNumber: String; var sortOrder: Int
    var escalationEnabled: Bool; var escalationWindowMinutes: Int?; var messageTemplates: [MessageTemplate]
    var contactMethod: String; var discordUserID: String?
    var timeZoneIdentifier: String?
    var availableFromHour: Int?; var availableFromMinute: Int?
    var availableToHour: Int?; var availableToMinute: Int?
    init(_ m: TrustedContact) {
        id = m.id; name = m.name; phoneNumber = m.phoneNumber; sortOrder = m.sortOrder
        escalationEnabled = m.escalationEnabled; escalationWindowMinutes = m.escalationWindowMinutes
        messageTemplates = m.messageTemplates
        contactMethod = m.contactMethod.rawValue; discordUserID = m.discordUserID
        timeZoneIdentifier = m.timeZoneIdentifier
        availableFromHour = m.availableFromHour; availableFromMinute = m.availableFromMinute
        availableToHour = m.availableToHour; availableToMinute = m.availableToMinute
    }
    func toModel() -> TrustedContact {
        TrustedContact(id: id, name: name, phoneNumber: phoneNumber, sortOrder: sortOrder,
                        escalationEnabled: escalationEnabled, escalationWindowMinutes: escalationWindowMinutes,
                        messageTemplates: messageTemplates,
                        contactMethod: ContactMethod(rawValue: contactMethod) ?? .phone, discordUserID: discordUserID,
                        timeZoneIdentifier: timeZoneIdentifier,
                        availableFromHour: availableFromHour, availableFromMinute: availableFromMinute,
                        availableToHour: availableToHour, availableToMinute: availableToMinute)
    }
}

struct GroundingToolDTO: Codable {
    var id: UUID; var title: String; var kindRaw: String; var steps: String?
    var deepLink: DeepLinkDestination?; var sortOrder: Int; var relevantTimeWindows: [TimeWindowTag]
    init(_ m: GroundingTool) {
        id = m.id; title = m.title; kindRaw = m.kind.rawValue; steps = m.steps
        deepLink = m.deepLink; sortOrder = m.sortOrder; relevantTimeWindows = m.relevantTimeWindows
    }
    func toModel() -> GroundingTool {
        GroundingTool(id: id, title: title, kind: GroundingToolKind(rawValue: kindRaw) ?? .physicalAction,
                      steps: steps, deepLink: deepLink, sortOrder: sortOrder, relevantTimeWindows: relevantTimeWindows)
    }
}

struct SafetyPlanDTO: Codable {
    var id: UUID; var lastEditedAt: Date
    var warningSignsText: String; var copingStrategiesText: String
    var reasonsToKeepGoingText: String; var environmentSafetyStepsText: String
    init(_ m: SafetyPlan) {
        id = m.id; lastEditedAt = m.lastEditedAt
        warningSignsText = m.warningSignsText; copingStrategiesText = m.copingStrategiesText
        reasonsToKeepGoingText = m.reasonsToKeepGoingText; environmentSafetyStepsText = m.environmentSafetyStepsText
    }
    func toModel() -> SafetyPlan {
        SafetyPlan(id: id, lastEditedAt: lastEditedAt, warningSignsText: warningSignsText,
                   copingStrategiesText: copingStrategiesText, reasonsToKeepGoingText: reasonsToKeepGoingText,
                   environmentSafetyStepsText: environmentSafetyStepsText)
    }
}

struct TriggerWindowDTO: Codable {
    var id: UUID; var label: String; var daysOfWeek: [Int]
    var startHour: Int; var startMinute: Int; var endHour: Int; var endMinute: Int; var isActive: Bool
    init(_ m: TriggerWindow) {
        id = m.id; label = m.label; daysOfWeek = m.daysOfWeek
        startHour = m.startHour; startMinute = m.startMinute; endHour = m.endHour; endMinute = m.endMinute
        isActive = m.isActive
    }
    func toModel() -> TriggerWindow {
        TriggerWindow(id: id, label: label, daysOfWeek: daysOfWeek,
                       startTime: DateComponents(hour: startHour, minute: startMinute),
                       endTime: DateComponents(hour: endHour, minute: endMinute), isActive: isActive)
    }
}

struct BridgeDraftItemDTO: Codable {
    var id: UUID; var createdAt: Date; var text: String; var isResolved: Bool
    init(_ m: BridgeDraftItem) { id = m.id; createdAt = m.createdAt; text = m.text; isResolved = m.isResolved }
    func toModel() -> BridgeDraftItem { BridgeDraftItem(id: id, createdAt: createdAt, text: text, isResolved: isResolved) }
}

struct FeedbackLoopDiagramDTO: Codable {
    var id: UUID; var title: String; var lastEditedAt: Date; var graphJSON: Data
    init(_ m: FeedbackLoopDiagram) { id = m.id; title = m.title; lastEditedAt = m.lastEditedAt; graphJSON = m.graphJSON }
    func toModel() -> FeedbackLoopDiagram { FeedbackLoopDiagram(id: id, title: title, lastEditedAt: lastEditedAt, graphJSON: graphJSON) }
}

struct ThreadMessageDTO: Codable {
    var id: UUID; var timestamp: Date; var text: String; var audioFileName: String?; var withContactID: UUID?
    init(_ m: ThreadMessage) {
        id = m.id; timestamp = m.timestamp; text = m.text
        audioFileName = m.audioFileName; withContactID = m.withContactID
    }
    func toModel() -> ThreadMessage {
        ThreadMessage(id: id, timestamp: timestamp, text: text, audioFileName: audioFileName, withContactID: withContactID)
    }
}

struct SupportCalendarEntryDTO: Codable {
    var id: UUID; var date: Date; var note: String; var visibleToContactIDs: [UUID]
    init(_ m: SupportCalendarEntry) { id = m.id; date = m.date; note = m.note; visibleToContactIDs = m.visibleToContactIDs }
    func toModel() -> SupportCalendarEntry { SupportCalendarEntry(id: id, date: date, note: note, visibleToContactIDs: visibleToContactIDs) }
}

struct FutureNoteDTO: Codable {
    var id: UUID; var writtenAt: Date; var unlockDate: Date; var text: String
    init(_ m: FutureNote) { id = m.id; writtenAt = m.writtenAt; unlockDate = m.unlockDate; text = m.text }
    func toModel() -> FutureNote { FutureNote(id: id, writtenAt: writtenAt, unlockDate: unlockDate, text: text) }
}

struct UnsentDraftDTO: Codable {
    var id: UUID; var createdAt: Date; var recipientLabel: String; var text: String; var wasSent: Bool
    init(_ m: UnsentDraft) { id = m.id; createdAt = m.createdAt; recipientLabel = m.recipientLabel; text = m.text; wasSent = m.wasSent }
    func toModel() -> UnsentDraft { UnsentDraft(id: id, createdAt: createdAt, recipientLabel: recipientLabel, text: text, wasSent: wasSent) }
}

struct DecisionPresetChoiceDTO: Codable {
    var id: UUID; var name: String; var steps: String; var sortOrder: Int
    init(_ m: DecisionPresetChoice) { id = m.id; name = m.name; steps = m.steps; sortOrder = m.sortOrder }
    func toModel() -> DecisionPresetChoice { DecisionPresetChoice(id: id, name: name, steps: steps, sortOrder: sortOrder) }
}

struct DecisionPresetCategoryDTO: Codable {
    var id: UUID; var name: String; var sortOrder: Int; var choices: [DecisionPresetChoiceDTO]
    init(_ m: DecisionPresetCategory) {
        id = m.id; name = m.name; sortOrder = m.sortOrder
        choices = m.choices.map(DecisionPresetChoiceDTO.init)
    }
    func toModel() -> DecisionPresetCategory {
        let category = DecisionPresetCategory(id: id, name: name, sortOrder: sortOrder)
        category.choices = choices.map { choiceDTO in
            let choice = choiceDTO.toModel()
            choice.category = category
            return choice
        }
        return category
    }
}

struct DeEscalationScriptDTO: Codable {
    var id: UUID; var text: String; var sortOrder: Int
    init(_ m: DeEscalationScript) { id = m.id; text = m.text; sortOrder = m.sortOrder }
    func toModel() -> DeEscalationScript { DeEscalationScript(id: id, text: text, sortOrder: sortOrder) }
}

struct AffirmationDTO: Codable {
    var id: UUID; var text: String; var sortOrder: Int
    init(_ m: Affirmation) { id = m.id; text = m.text; sortOrder = m.sortOrder }
    func toModel() -> Affirmation { Affirmation(id: id, text: text, sortOrder: sortOrder) }
}
