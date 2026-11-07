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
//  data, it's app content. Tasks are included.
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
    @Query private var planSections: [SafetyPlanSection]
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
    @Query private var tasks: [TaskItem]
    @Query private var quickLists: [QuickList]
    @Query private var routines: [Routine]
    @Query private var itemLists: [ItemList]
    @Query private var boundarySections: [BoundarySection]
    @Query private var messageStarters: [MessageStarter]
    @Query private var personalGoals: [PersonalGoal]
    @Query private var recoveryCounters: [RecoveryCounter]
    @Query private var recoveryMotivations: [RecoveryMotivation]
    @Query private var recoveryDayEntries: [RecoveryDayEntry]
    @Query private var recoveryUrges: [RecoveryUrge]

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
                countRow("Safety plan sections", planSections.count, icon: "shield.fill")
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
                countRow("Tasks", tasks.count, icon: "checkmark.circle.fill")
                countRow("Quick lists", quickLists.count, icon: "list.bullet.clipboard")
                countRow("Routines", routines.count, icon: "list.number")
                countRow("Item lists", itemLists.count, icon: "suitcase")
                countRow("Boundaries sections", boundarySections.count, icon: "hand.raised.fill")
                countRow("Message starters", messageStarters.count, icon: "text.bubble")
                countRow("Personal goals", personalGoals.count, icon: "flag.fill")
                countRow("Recovery counters", recoveryCounters.count, icon: "calendar.badge.checkmark")
                countRow("Urges logged", recoveryUrges.count, icon: "wind")
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
                                   subtitle: "Anchor JSON exports, including ones from earlier versions", tint: Anchor.Theme.sage)
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
        .anchorSettingsStyle()
        .navigationTitle("Your data")
        .sheet(item: $exportURL) { wrapped in
            ShareSheet(activityItems: [wrapped.url])
        }
        .sheet(item: $showDateRangeSheet) { kind in
            DateRangeExportSheet(kind: kind, hasRecovery: recoveryCounters.contains { !$0.isArchived }) { range, includeRecovery in
                switch kind {
                case .csv: exportCSV(range: range, includeRecovery: includeRecovery)
                case .pdf: exportPDF(range: range, includeRecovery: includeRecovery)
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText]) { result in
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
            safetySections: planSections.map(SafetyPlanSectionDTO.init),
            triggerWindows: triggerWindows.map(TriggerWindowDTO.init),
            bridgeDraftItems: bridgeDraftItems.map(BridgeDraftItemDTO.init),
            diagrams: diagrams.map(FeedbackLoopDiagramDTO.init),
            threadMessages: threadMessages.map(ThreadMessageDTO.init),
            supportCalendarEntries: supportCalendarEntries.map(SupportCalendarEntryDTO.init),
            futureNotes: futureNotes.map(FutureNoteDTO.init),
            unsentDrafts: unsentDrafts.map(UnsentDraftDTO.init),
            decisionCategories: decisionCategories.map(DecisionPresetCategoryDTO.init),
            deEscalationScripts: deEscalationScripts.map(DeEscalationScriptDTO.init),
            affirmations: affirmations.map(AffirmationDTO.init),
            recoveryCounters: recoveryCounters.map(RecoveryCounterDTO.init),
            recoveryMotivations: recoveryMotivations.map(RecoveryMotivationDTO.init),
            recoveryDayEntries: recoveryDayEntries.map(RecoveryDayEntryDTO.init),
            recoveryUrges: recoveryUrges.map(RecoveryUrgeDTO.init),
            tasks: tasks.map(TaskItemDTO.init),
            quickLists: quickLists.map(QuickListDTO.init),
            routines: routines.map(RoutineDTO.init),
            itemLists: itemLists.map(ItemListDTO.init),
            boundarySections: boundarySections.map(BoundarySectionDTO.init),
            messageStarters: messageStarters.map(MessageStarterDTO.init),
            personalGoals: personalGoals.map(PersonalGoalDTO.init)
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
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              !Set(object.keys).isDisjoint(with: AnchorDataExport.knownKeys),
              let export = try? JSONDecoder.anchorExport.decode(AnchorDataExport.self, from: data) else {
            importResultMessage = "That file doesn't look like an Anchor export."
            return
        }

        let existingJournalIDs = Set(journalEntries.map(\.id))
        let existingCheckInIDs = Set(checkIns.map(\.id))
        let existingContactIDs = Set(contacts.map(\.id))
        let existingToolIDs = Set(groundingTools.map(\.id))
        let existingSafetyPlanIDs = Set(safetyPlans.map(\.id))
        let existingSectionIDs = Set(planSections.map(\.id))
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
        let existingTaskIDs = Set(tasks.map(\.id))
        let existingQuickListIDs = Set(quickLists.map(\.id))
        let existingRoutineIDs = Set(routines.map(\.id))
        let existingItemListIDs = Set(itemLists.map(\.id))
        let existingBoundaryIDs = Set(boundarySections.map(\.id))
        let existingStarterIDs = Set(messageStarters.map(\.id))
        let existingGoalIDs = Set(personalGoals.map(\.id))

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
        for dto in export.safetySections ?? [] where !existingSectionIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        // A file made before sections existed carries only the four text
        // fields. If there are no sections here yet, copy them across once.
        if export.safetySections == nil, planSections.isEmpty,
           let old = export.safetyPlans.first(where: { dto in
               [dto.warningSignsText, dto.copingStrategiesText, dto.reasonsToKeepGoingText, dto.environmentSafetyStepsText]
                   .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
           }) {
            for section in SafetyPlanSections.makeSections(
                warningSigns: old.warningSignsText, copingStrategies: old.copingStrategiesText,
                reasons: old.reasonsToKeepGoingText, environment: old.environmentSafetyStepsText,
                edited: old.lastEditedAt
            ) {
                modelContext.insert(section); importedCount += 1
            }
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
        for dto in export.tasks ?? [] where !existingTaskIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.quickLists ?? [] where !existingQuickListIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.routines ?? [] where !existingRoutineIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.itemLists ?? [] where !existingItemListIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.boundarySections ?? [] where !existingBoundaryIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.messageStarters ?? [] where !existingStarterIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.personalGoals ?? [] where !existingGoalIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        // Recovery data is optional in the file, so exports from earlier versions still import.
        let existingCounterIDs = Set(recoveryCounters.map(\.id))
        let existingMotivationIDs = Set(recoveryMotivations.map(\.id))
        let existingDayEntryIDs = Set(recoveryDayEntries.map(\.id))
        let existingUrgeIDs = Set(recoveryUrges.map(\.id))
        for dto in export.recoveryCounters ?? [] where !existingCounterIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.recoveryMotivations ?? [] where !existingMotivationIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.recoveryDayEntries ?? [] where !existingDayEntryIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.recoveryUrges ?? [] where !existingUrgeIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        RecoveryNotifications.refresh(using: modelContext)
        RoutineReminders.refresh(using: modelContext)

        importResultMessage = importedCount == 0
            ? "Nothing new to import. Everything in that file is already here."
            : "Imported \(importedCount) item\(importedCount == 1 ? "" : "s")."
    }

    // MARK: - CSV / PDF (Journal + Check-ins only — the two things worth handing a psych)

    private func exportCSV(range: ClosedRange<Date>?, includeRecovery: Bool) {
        var lines = ["type,date,text_or_values"]
        for entry in filteredJournal(range) {
            let escaped = entry.text.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ")
            lines.append("journal,\(iso(entry.createdAt)),\"\(escaped)\"")
        }
        for checkIn in filteredCheckIns(range) {
            let values = "energy=\(fmt(checkIn.physicalEnergy)) clarity=\(fmt(1 - checkIn.cognitiveBurnout)) space=\(fmt(1 - checkIn.mentalLoad)) physicalEnergy=\(fmt(checkIn.physicalEnergy)) social=\(fmt(checkIn.socialEnergy))"
            lines.append("checkin,\(iso(checkIn.timestamp)),\"\(values)\"")
        }
        if includeRecovery {
            for counter in activeRecoveryCounters {
                let summary = RecoverySummary.lines(for: counter, urges: recoveryUrges, range: summaryRange(range))
                let escaped = "\(counter.name): " + summary.joined(separator: "; ")
                lines.append("recovery,\(iso(range?.upperBound ?? .now)),\"\(escaped.replacingOccurrences(of: "\"", with: "\"\""))\"")
            }
        }
        guard let data = lines.joined(separator: "\n").data(using: .utf8) else { return }
        writeAndShare(data: data, filename: "anchor-export-\(fileTimestamp()).csv")
    }

    private func exportPDF(range: ClosedRange<Date>?, includeRecovery: Bool) {
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
            if includeRecovery {
                draw("Recovery", font: headingFont)
                for counter in activeRecoveryCounters {
                    let summary = RecoverySummary.lines(for: counter, urges: recoveryUrges, range: summaryRange(range))
                    draw("\(counter.name)\n" + summary.joined(separator: "\n"), font: bodyFont)
                }
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

    private var activeRecoveryCounters: [RecoveryCounter] {
        recoveryCounters.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// All time when no range was chosen.
    private func summaryRange(_ range: ClosedRange<Date>?) -> ClosedRange<Date> {
        range ?? (Date.distantPast...Date.now)
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
        for item in planSections { modelContext.delete(item) }
        for item in triggerWindows { modelContext.delete(item) }
        for item in appointmentSeries { modelContext.delete(item) }
        for item in bridgeDraftItems { modelContext.delete(item) }
        for item in diagrams { modelContext.delete(item) }
        for item in threadMessages { modelContext.deleteMessage(item) }
        for item in supportCalendarEntries { modelContext.delete(item) }
        for item in futureNotes { modelContext.delete(item) }
        for item in unsentDrafts { modelContext.delete(item) }
        for item in decisionCategories { modelContext.delete(item) }
        for item in deEscalationScripts { modelContext.delete(item) }
        for item in affirmations { modelContext.delete(item) }
        for item in tasks { modelContext.delete(item) }
        for item in quickLists { modelContext.delete(item) }
        for item in routines { modelContext.delete(item) }
        for item in itemLists { modelContext.delete(item) }
        for item in boundarySections { modelContext.delete(item) }
        for item in messageStarters { modelContext.delete(item) }
        for item in personalGoals { modelContext.delete(item) }
        UserDefaults.standard.removeObject(forKey: DayPlan.key)
        for item in recoveryCounters { modelContext.delete(item) }
        for item in recoveryMotivations { modelContext.delete(item) }
        for item in recoveryDayEntries { modelContext.delete(item) }
        for item in recoveryUrges { modelContext.delete(item) }
        RecoveryNotifications.refresh(counters: [])
        RoutineReminders.refresh(routines: [])
        RecoveryWidgetSync.refresh(counters: [])
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
    let hasRecovery: Bool
    let onExport: (ClosedRange<Date>?, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var useRange = false
    @State private var start: Date = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
    @State private var end: Date = .now
    /// Deliberately not remembered: Recovery is left out of every export unless it is switched on for that export.
    @State private var includeRecovery = false

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Limit to a date range", isOn: $useRange)
                    .tint(Anchor.Theme.accent)
                if useRange {
                    DatePicker("From", selection: $start, displayedComponents: .date)
                    DatePicker("To", selection: $end, displayedComponents: .date)
                }
                if hasRecovery {
                    Section {
                        Toggle("Include Recovery summary", isOn: $includeRecovery)
                            .tint(Anchor.Theme.accent)
                    } footer: {
                        Text("Off unless you switch it on, every time. Adds each counter's name, days, urges logged and fresh starts. Never your urge notes, pledges, reviews or savings.")
                    }
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
                        onExport(useRange ? min(start, end)...max(start, end) : nil, hasRecovery && includeRecovery)
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
// and the retired NextHourItem (its rows become tasks on first launch) —
// see the file header.

private extension JSONEncoder {
    static var anchorExport: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }
}
private extension JSONDecoder {
    /// Accepts ISO 8601 with or without fractional seconds, and plain numeric
    /// timestamps, so exports written by older or hand-edited files still load.
    static var anchorExport: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                // Foundation's default Date encoding: seconds since 1 Jan 2001.
                return Date(timeIntervalSinceReferenceDate: seconds)
            }
            let text = try container.decode(String.self)
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: text) { return date }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognised date: \(text)")
        }
        return decoder
    }
}

/// Decodes one array element at a time, so a single unreadable record is
/// skipped instead of making the whole file fail to import.
private struct LossyElement<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

private extension KeyedDecodingContainer {
    /// `nil` when the key is missing (an older export); otherwise every element that could be read.
    func lossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T]? {
        guard let elements = try? decode([LossyElement<T>].self, forKey: key) else { return nil }
        return elements.compactMap(\.value)
    }
}

struct AnchorDataExport: Codable {
    var journalEntries: [JournalEntryDTO] = []
    var checkIns: [CheckInDTO] = []
    var contacts: [TrustedContactDTO] = []
    var groundingTools: [GroundingToolDTO] = []
    var safetyPlans: [SafetyPlanDTO] = []
    /// Optional so exports made before safety plan sections existed still import.
    var safetySections: [SafetyPlanSectionDTO]? = nil
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
    /// Optional so exports made before Recovery existed still decode and import.
    var recoveryCounters: [RecoveryCounterDTO]? = nil
    var recoveryMotivations: [RecoveryMotivationDTO]? = nil
    var recoveryDayEntries: [RecoveryDayEntryDTO]? = nil
    var recoveryUrges: [RecoveryUrgeDTO]? = nil
    var tasks: [TaskItemDTO]? = nil
    /// Optional so exports made before quick lists existed still import.
    var quickLists: [QuickListDTO]? = nil
    /// Optional so exports made before routines existed still import.
    var routines: [RoutineDTO]? = nil
    /// Optional so exports made before item lists existed still import.
    var itemLists: [ItemListDTO]? = nil
    /// Optional so exports made before the Boundaries list existed still import.
    var boundarySections: [BoundarySectionDTO]? = nil
    /// Optional so exports made before message starters existed still import.
    var messageStarters: [MessageStarterDTO]? = nil
    /// Optional so exports made before personal goals existed still import.
    var personalGoals: [PersonalGoalDTO]? = nil
}

/// Every section is optional in the file: an export from any earlier version,
/// or one missing a section, imports whatever it does contain.
extension AnchorDataExport {
    /// Top-level sections an Anchor export can hold. A file with none of them isn't an Anchor export.
    static let knownKeys: Set<String> = [
        "journalEntries", "checkIns", "contacts", "groundingTools", "safetyPlans", "triggerWindows",
        "bridgeDraftItems", "diagrams", "threadMessages", "supportCalendarEntries", "futureNotes",
        "unsentDrafts", "decisionCategories", "deEscalationScripts", "affirmations",
        "recoveryCounters", "recoveryMotivations", "recoveryDayEntries", "recoveryUrges", "tasks",
        "quickLists", "routines", "itemLists", "safetySections", "boundarySections", "messageStarters", "personalGoals"
    ]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        journalEntries = c.lossyArray(JournalEntryDTO.self, forKey: .journalEntries) ?? []
        checkIns = c.lossyArray(CheckInDTO.self, forKey: .checkIns) ?? []
        contacts = c.lossyArray(TrustedContactDTO.self, forKey: .contacts) ?? []
        groundingTools = c.lossyArray(GroundingToolDTO.self, forKey: .groundingTools) ?? []
        safetyPlans = c.lossyArray(SafetyPlanDTO.self, forKey: .safetyPlans) ?? []
        safetySections = c.lossyArray(SafetyPlanSectionDTO.self, forKey: .safetySections)
        triggerWindows = c.lossyArray(TriggerWindowDTO.self, forKey: .triggerWindows) ?? []
        bridgeDraftItems = c.lossyArray(BridgeDraftItemDTO.self, forKey: .bridgeDraftItems) ?? []
        diagrams = c.lossyArray(FeedbackLoopDiagramDTO.self, forKey: .diagrams) ?? []
        threadMessages = c.lossyArray(ThreadMessageDTO.self, forKey: .threadMessages) ?? []
        supportCalendarEntries = c.lossyArray(SupportCalendarEntryDTO.self, forKey: .supportCalendarEntries) ?? []
        futureNotes = c.lossyArray(FutureNoteDTO.self, forKey: .futureNotes) ?? []
        unsentDrafts = c.lossyArray(UnsentDraftDTO.self, forKey: .unsentDrafts) ?? []
        decisionCategories = c.lossyArray(DecisionPresetCategoryDTO.self, forKey: .decisionCategories) ?? []
        deEscalationScripts = c.lossyArray(DeEscalationScriptDTO.self, forKey: .deEscalationScripts) ?? []
        affirmations = c.lossyArray(AffirmationDTO.self, forKey: .affirmations) ?? []
        recoveryCounters = c.lossyArray(RecoveryCounterDTO.self, forKey: .recoveryCounters)
        recoveryMotivations = c.lossyArray(RecoveryMotivationDTO.self, forKey: .recoveryMotivations)
        recoveryDayEntries = c.lossyArray(RecoveryDayEntryDTO.self, forKey: .recoveryDayEntries)
        recoveryUrges = c.lossyArray(RecoveryUrgeDTO.self, forKey: .recoveryUrges)
        tasks = c.lossyArray(TaskItemDTO.self, forKey: .tasks)
        quickLists = c.lossyArray(QuickListDTO.self, forKey: .quickLists)
        routines = c.lossyArray(RoutineDTO.self, forKey: .routines)
        itemLists = c.lossyArray(ItemListDTO.self, forKey: .itemLists)
        boundarySections = c.lossyArray(BoundarySectionDTO.self, forKey: .boundarySections)
        messageStarters = c.lossyArray(MessageStarterDTO.self, forKey: .messageStarters)
        personalGoals = c.lossyArray(PersonalGoalDTO.self, forKey: .personalGoals)
    }
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

struct SafetyPlanSectionDTO: Codable {
    var id: UUID; var title: String; var text: String
    var iconName: String; var tintName: String
    var sortOrder: Int; var isHidden: Bool; var role: String; var lastEditedAt: Date
    init(_ m: SafetyPlanSection) {
        id = m.id; title = m.title; text = m.text; iconName = m.iconName; tintName = m.tintName
        sortOrder = m.sortOrder; isHidden = m.isHidden; role = m.role; lastEditedAt = m.lastEditedAt
    }
    func toModel() -> SafetyPlanSection {
        SafetyPlanSection(id: id, title: title, text: text, iconName: iconName, tintName: tintName,
                          sortOrder: sortOrder, isHidden: isHidden, role: role, lastEditedAt: lastEditedAt)
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
    /// Optional so exports made before questions existed still import.
    var isQuestion: Bool? = nil
    var answer: String? = nil
    init(_ m: BridgeDraftItem) {
        id = m.id; createdAt = m.createdAt; text = m.text; isResolved = m.isResolved
        isQuestion = m.isQuestion ? true : nil
        answer = m.answer.isEmpty ? nil : m.answer
    }
    func toModel() -> BridgeDraftItem {
        BridgeDraftItem(id: id, createdAt: createdAt, text: text, isResolved: isResolved,
                        isQuestion: isQuestion ?? false, answer: answer ?? "")
    }
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
    /// Optional so exports made before "Open when" letters existed still import.
    var openWhen: String? = nil
    init(_ m: FutureNote) {
        id = m.id; writtenAt = m.writtenAt; unlockDate = m.unlockDate; text = m.text
        openWhen = m.openWhen.isEmpty ? nil : m.openWhen
    }
    func toModel() -> FutureNote {
        FutureNote(id: id, writtenAt: writtenAt, unlockDate: unlockDate, text: text, openWhen: openWhen ?? "")
    }
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

struct TaskItemDTO: Codable {
    var id: UUID; var title: String; var notes: String; var isDone: Bool
    var completedAt: Date?; var createdAt: Date; var sortOrder: Int
    /// Optional so exports made before tasks had dates still import.
    var dueKind: String?; var dueDate: Date?
    /// Optional so exports made before tasks had steps still import.
    var parentID: UUID?; var subtasksCollapsed: Bool?
    /// Optional so exports made before tasks could wait on each other still import.
    var blockedByIDs: [UUID]?
    /// Optional so exports made before tasks had a status, energy or first step still import.
    var status: String?; var energy: String?; var firstStep: String?
    /// Optional so exports made before the focus timer still import.
    var focusSessions: Int?; var focusMinutes: Int?
    /// Optional so exports made before tasks had an estimate still import.
    var estimateMinutes: Int?
    init(_ m: TaskItem) {
        id = m.id; title = m.title; notes = m.notes; isDone = m.isDone
        completedAt = m.completedAt; createdAt = m.createdAt; sortOrder = m.sortOrder
        dueKind = m.dueKind.rawValue; dueDate = m.dueDate
        parentID = m.parentID; subtasksCollapsed = m.subtasksCollapsed
        blockedByIDs = m.blockedByIDs
        status = m.status.rawValue; energy = m.energy.rawValue; firstStep = m.firstStep
        focusSessions = m.focusSessions; focusMinutes = m.focusMinutes
        estimateMinutes = m.estimateMinutes
    }
    func toModel() -> TaskItem {
        TaskItem(id: id, title: title, notes: notes, isDone: isDone,
                 completedAt: completedAt, createdAt: createdAt, sortOrder: sortOrder,
                 dueKind: TaskDueKind(rawValue: dueKind ?? "") ?? .noDate, dueDate: dueDate,
                 parentID: parentID, subtasksCollapsed: subtasksCollapsed ?? false,
                 blockedByIDs: blockedByIDs ?? [],
                 status: TaskStatus(rawValue: status ?? "") ?? .notStarted,
                 energy: TaskEnergy(rawValue: energy ?? "") ?? .unset,
                 firstStep: firstStep ?? "",
                 focusSessions: focusSessions ?? 0, focusMinutes: focusMinutes ?? 0,
                 estimateMinutes: estimateMinutes ?? 0)
    }
}

struct QuickListDTO: Codable {
    var id: UUID; var title: String; var createdAt: Date
    var items: [QuickListItem]; var archivedAt: Date?
    init(_ m: QuickList) {
        id = m.id; title = m.title; createdAt = m.createdAt
        items = m.items; archivedAt = m.archivedAt
    }
    func toModel() -> QuickList {
        QuickList(id: id, title: title, createdAt: createdAt, items: items, archivedAt: archivedAt)
    }
}

struct RoutineDTO: Codable {
    var id: UUID; var name: String; var createdAt: Date
    var steps: [RoutineStep]
    /// Optional so exports made before routine reminders existed still import.
    var reminderEnabled: Bool?; var reminderDays: [Int]?
    var reminderHour: Int?; var reminderMinute: Int?
    init(_ m: Routine) {
        id = m.id; name = m.name; createdAt = m.createdAt; steps = m.steps
        reminderEnabled = m.reminderEnabled; reminderDays = m.reminderDays
        reminderHour = m.reminderHour; reminderMinute = m.reminderMinute
    }
    func toModel() -> Routine {
        Routine(id: id, name: name, createdAt: createdAt, steps: steps,
                reminderEnabled: reminderEnabled ?? false, reminderDays: reminderDays ?? [],
                reminderHour: reminderHour ?? 8, reminderMinute: reminderMinute ?? 0)
    }
}

struct BoundarySectionDTO: Codable {
    var id: UUID; var title: String; var text: String
    var iconName: String; var tintName: String
    var sortOrder: Int; var isHidden: Bool; var isShareable: Bool; var lastEditedAt: Date
    init(_ m: BoundarySection) {
        id = m.id; title = m.title; text = m.text; iconName = m.iconName; tintName = m.tintName
        sortOrder = m.sortOrder; isHidden = m.isHidden; isShareable = m.isShareable; lastEditedAt = m.lastEditedAt
    }
    func toModel() -> BoundarySection {
        BoundarySection(id: id, title: title, text: text, iconName: iconName, tintName: tintName,
                        sortOrder: sortOrder, isHidden: isHidden, isShareable: isShareable, lastEditedAt: lastEditedAt)
    }
}

struct MessageStarterDTO: Codable {
    var id: UUID; var text: String; var sortOrder: Int; var lastEditedAt: Date
    init(_ m: MessageStarter) {
        id = m.id; text = m.text; sortOrder = m.sortOrder; lastEditedAt = m.lastEditedAt
    }
    func toModel() -> MessageStarter {
        MessageStarter(id: id, text: text, sortOrder: sortOrder, lastEditedAt: lastEditedAt)
    }
}

struct PersonalGoalDTO: Codable {
    var id: UUID; var title: String; var why: String; var statusRaw: String
    var notes: [GoalNote]; var sortOrder: Int; var createdAt: Date; var lastEditedAt: Date
    init(_ m: PersonalGoal) {
        id = m.id; title = m.title; why = m.why; statusRaw = m.statusRaw; notes = m.notes
        sortOrder = m.sortOrder; createdAt = m.createdAt; lastEditedAt = m.lastEditedAt
    }
    func toModel() -> PersonalGoal {
        PersonalGoal(id: id, title: title, why: why, status: GoalStatus(rawValue: statusRaw) ?? .active,
                     notes: notes, sortOrder: sortOrder, createdAt: createdAt, lastEditedAt: lastEditedAt)
    }
}

struct ItemListDTO: Codable {
    var id: UUID; var name: String; var createdAt: Date
    var variables: [ListVariable]; var items: [ListItem]
    init(_ m: ItemList) {
        id = m.id; name = m.name; createdAt = m.createdAt
        variables = m.variables; items = m.items
    }
    func toModel() -> ItemList {
        ItemList(id: id, name: name, createdAt: createdAt, variables: variables, items: items)
    }
}

struct AffirmationDTO: Codable {
    var id: UUID; var text: String; var sortOrder: Int
    init(_ m: Affirmation) { id = m.id; text = m.text; sortOrder = m.sortOrder }
    func toModel() -> Affirmation { Affirmation(id: id, text: text, sortOrder: sortOrder) }
}
