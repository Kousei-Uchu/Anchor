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
import CryptoKit
import CommonCrypto
import WidgetKit

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
    @Query private var personSections: [PersonSection]
    @Query private var sleepEntries: [SleepEntry]
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
    @State private var showBackupSheet = false
    @State private var readyBackup: URL?
    @State private var pendingRestore: IdentifiableURL?
    @State private var restoreCopy: URL?

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

            Section {
                NavigationLink {
                    DataViewerGate { DataViewerHome() }
                } label: {
                    Anchor.MenuRow(icon: "list.bullet.rectangle", title: "Look at what's stored",
                                   subtitle: "\(totalItems) items. Read only, and it asks for your lock first.", tint: Anchor.Theme.sage)
                }
            } header: {
                Text("What's stored")
            }

            if ShowcaseMode.isOn {
                Section {
                    Text("Exporting, importing and clearing are switched off while showcase mode is on.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Button {
                        exportFullJSON()
                    } label: {
                        Anchor.MenuRow(icon: "doc.zipper", title: "Export everything (JSON)",
                                       subtitle: "Plain text, without photos or voice notes. Anyone with the file can read it", tint: Anchor.Theme.accent)
                    }
                    Button {
                        showBackupSheet = true
                    } label: {
                        Anchor.MenuRow(icon: "lock.doc", title: "Make an encrypted backup",
                                       subtitle: "Everything, with photos and voice notes, locked with a password you choose", tint: Anchor.Theme.accent)
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
                                       subtitle: "Encrypted backups and JSON exports, including ones from earlier versions", tint: Anchor.Theme.sage)
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
                    Text("Deletes everything Anchor stores from this device. This can't be undone, so export first if you want a copy.")
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Your data")
        .guideButton("plan.your-data", tab: .plan)
        .onAppear {
            #if DEBUG
            BackupSelfTest.run()
            #endif
        }
        .sheet(item: $exportURL) { wrapped in
            ShareSheet(activityItems: [wrapped.url])
        }
        .sheet(isPresented: $showBackupSheet, onDismiss: {
            if let url = readyBackup {
                readyBackup = nil
                exportURL = IdentifiableURL(url: url)
            }
        }) {
            BackupPasswordSheet(
                title: "Encrypted backup",
                message: "At least 8 characters. If you lose this password, nobody can open the backup, so keep it somewhere safe.",
                buttonTitle: "Make the backup",
                asksTwice: true
            ) { password in
                await makeEncryptedBackup(password: password)
            }
        }
        .sheet(item: $pendingRestore, onDismiss: {
            if let copy = restoreCopy {
                try? FileManager.default.removeItem(at: copy)
                restoreCopy = nil
            }
        }) { pending in
            BackupPasswordSheet(
                title: "Open a backup",
                message: "Type the password you chose when you made this backup.",
                buttonTitle: "Restore",
                asksTwice: false
            ) { password in
                await restoreBackup(from: pending.url, password: password)
            }
        }
        .sheet(item: $showDateRangeSheet) { kind in
            DateRangeExportSheet(kind: kind, hasRecovery: recoveryCounters.contains { !$0.isArchived }) { range, includeRecovery in
                switch kind {
                case .csv: exportCSV(range: range, includeRecovery: includeRecovery)
                case .pdf: exportPDF(range: range, includeRecovery: includeRecovery)
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText, .data]) { result in
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

    private var totalItems: Int {
        journalEntries.count + checkIns.count + contacts.count + groundingTools.count + safetyPlans.count
            + planSections.count + triggerWindows.count + appointmentSeries.count + bridgeDraftItems.count
            + diagrams.count + threadMessages.count + supportCalendarEntries.count + futureNotes.count
            + unsentDrafts.count + decisionCategories.count + deEscalationScripts.count + affirmations.count
            + tasks.count + quickLists.count + routines.count + itemLists.count + boundarySections.count
            + personSections.count + sleepEntries.count + messageStarters.count + personalGoals.count
            + recoveryCounters.count + recoveryMotivations.count + recoveryDayEntries.count + recoveryUrges.count
    }

    // MARK: - Full JSON export/import

    private func buildExport() -> AnchorDataExport {
        AnchorDataExport(
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
            personalGoals: personalGoals.map(PersonalGoalDTO.init),
            appointmentSeries: appointmentSeries.map(AppointmentSeriesDTO.init),
            personSections: personSections.map(PersonSectionDTO.init),
            sleepEntries: sleepEntries.map(SleepEntryDTO.init)
        )
    }

    private func exportFullJSON() {
        guard let data = try? JSONEncoder.anchorExport.encode(buildExport()) else { return }
        writeAndShare(data: data, filename: "anchor-export-\(fileTimestamp()).json")
    }

    // MARK: - Encrypted backup

    /// Makes the .anchorbackup in the background and hands it to the share
    /// sheet once the password sheet has closed. Returns text to show if it
    /// could not be made, and nil when it worked.
    private func makeEncryptedBackup(password: String) async -> String? {
        guard let json = try? JSONEncoder.anchorExport.encode(buildExport()) else {
            return BackupError.io.message
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("anchor-backup-\(fileTimestamp()).anchorbackup")
        let failure: String? = await Task.detached(priority: .userInitiated) { () -> String? in
            do {
                try BackupArchive.write(json: json, to: url, password: password)
                return nil
            } catch {
                try? FileManager.default.removeItem(at: url)
                return (error as? BackupError)?.message ?? BackupError.io.message
            }
        }.value
        if failure == nil { readyBackup = url }
        return failure
    }

    /// Opens a backup in a temporary folder first, so a wrong password or a
    /// damaged file changes nothing. Only when the whole file has checked out
    /// is anything added: the records, then each photo or voice note whose
    /// name is not already on this device.
    private func restoreBackup(from url: URL, password: String) async -> String? {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let opened: Result<BackupContents, BackupError> = await Task.detached(priority: .userInitiated) { () -> Result<BackupContents, BackupError> in
            do {
                return .success(try BackupArchive.open(url: url, password: password, staging: staging))
            } catch let error as BackupError {
                return .failure(error)
            } catch {
                return .failure(.io)
            }
        }.value
        switch opened {
        case .failure(let error):
            return error.message
        case .success(let contents):
            guard let export = try? JSONDecoder.anchorExport.decode(AnchorDataExport.self, from: contents.json) else {
                return BackupError.damaged.message
            }
            let restored = BackupArchive.restoreFiles(contents)
            importExport(export, restoredFiles: restored)
            return nil
        }
    }

    private func isBackupFile(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let first = try? handle.read(upToCount: BackupFormat.magic.count)
        return first == BackupFormat.magic
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            importResultMessage = "Import didn't complete."
            return
        }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        if isBackupFile(url) {
            // The chosen file is only readable while access is open, so work from a copy.
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("restore-\(UUID().uuidString).anchorbackup")
            do {
                try FileManager.default.copyItem(at: url, to: copy)
                restoreCopy = copy
                pendingRestore = IdentifiableURL(url: copy)
            } catch {
                importResultMessage = "Couldn't read that file."
            }
            return
        }

        guard let data = try? Data(contentsOf: url),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              !Set(object.keys).isDisjoint(with: AnchorDataExport.knownKeys),
              let export = try? JSONDecoder.anchorExport.decode(AnchorDataExport.self, from: data) else {
            importResultMessage = "That file doesn't look like an Anchor export."
            return
        }

        importExport(export)
    }

    /// Adds everything in a decoded export that isn't here yet, and says how much.
    private func importExport(_ export: AnchorDataExport, restoredFiles: Int = 0) {
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
        let existingPersonSectionIDs = Set(personSections.map(\.id))
        let existingSleepIDs = Set(sleepEntries.map(\.id))
        let existingStarterIDs = Set(messageStarters.map(\.id))
        let existingGoalIDs = Set(personalGoals.map(\.id))
        let existingProviderIDs = Set(appointmentSeries.map(\.id))

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
        // A person's page only comes in when that person is here, either already
        // on this device or in the same file, so nothing arrives that cannot be seen.
        let knownContactIDs = Set(contacts.map(\.id)).union(export.contacts.map(\.id))
        for dto in export.personSections ?? []
        where !existingPersonSectionIDs.contains(dto.id) && knownContactIDs.contains(dto.contactID) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.sleepEntries ?? [] where !existingSleepIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.messageStarters ?? [] where !existingStarterIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.personalGoals ?? [] where !existingGoalIDs.contains(dto.id) {
            modelContext.insert(dto.toModel()); importedCount += 1
        }
        for dto in export.appointmentSeries ?? [] where !existingProviderIDs.contains(dto.id) {
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
        AppointmentReminders.refresh(using: modelContext)

        if importedCount == 0 && restoredFiles == 0 {
            importResultMessage = "Nothing new to import. Everything in that file is already here."
        } else {
            var message = importedCount == 0
                ? "Nothing new to import."
                : "Imported \(importedCount) item\(importedCount == 1 ? "" : "s")."
            if restoredFiles > 0 {
                message += " Restored \(restoredFiles) photo or voice note file\(restoredFiles == 1 ? "" : "s")."
            }
            importResultMessage = message
        }
    }

    // MARK: - CSV / PDF (Journal + Check-ins only — the two things worth handing a psych)

    private func exportCSV(range: ClosedRange<Date>?, includeRecovery: Bool) {
        var lines = ["type,date,text_or_values"]
        for entry in filteredJournal(range) {
            let escaped = entry.text.replacingOccurrences(of: "\"", with: "\"\"").replacingOccurrences(of: "\n", with: " ")
            lines.append("journal,\(iso(entry.createdAt)),\"\(escaped)\"")
        }
        for checkIn in filteredCheckIns(range) {
            let values = "energy=\(fmt(1 - checkIn.physicalExhaustion)) clarity=\(fmt(1 - checkIn.cognitiveBurnout)) space=\(fmt(1 - checkIn.mentalLoad)) moving=\(fmt(checkIn.physicalEnergy)) social=\(fmt(checkIn.socialEnergy))"
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
                draw("\(checkIn.timestamp.formatted(date: .abbreviated, time: .shortened)): energy \(fmt(1 - checkIn.physicalExhaustion)), clarity \(fmt(1 - checkIn.cognitiveBurnout)), room in head \(fmt(1 - checkIn.mentalLoad)), moving \(fmt(checkIn.physicalEnergy)), social energy \(fmt(checkIn.socialEnergy))", font: bodyFont)
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
        for item in personSections { modelContext.delete(item) }
        for item in sleepEntries { modelContext.delete(item) }
        SleepHealthReader.shared.disconnect()
        Task { await SleepHealthWriter.shared.removeAllSaved() }
        UserDefaults.standard.removeObject(forKey: SleepHealthSettings.lastSyncKey)
        for item in messageStarters { modelContext.delete(item) }
        for item in personalGoals { modelContext.delete(item) }
        UserDefaults.standard.removeObject(forKey: DayPlan.key)
        for item in recoveryCounters { modelContext.delete(item) }
        for item in recoveryMotivations { modelContext.delete(item) }
        for item in recoveryDayEntries { modelContext.delete(item) }
        for item in recoveryUrges { modelContext.delete(item) }
        RecoveryNotifications.refresh(counters: [])
        RoutineReminders.refresh(routines: [])
        AppointmentReminders.refresh(sessions: [])
        RecoveryWidgetSync.refresh(counters: [])
        WidgetSealing.removeEverything()
        ShowcasePasscode.remove()
        WidgetCenter.shared.reloadAllTimelines()
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

// MARK: - Encrypted backup (.anchorbackup)
//
// The format is written down in docs/BACKUP.md, and scripts/anchorbackup.py
// reads it without the app. In short: a 33 byte header, then chunks of up to
// 1 MiB, each sealed with AES-256-GCM under a key from PBKDF2-SHA256, so a
// large backup is never held in memory whole. Inside is the same JSON as the
// plain export plus the photo and voice note files.

enum BackupError: Error {
    case wrongPassword, damaged, newer, notABackup, io

    var message: String {
        switch self {
        case .wrongPassword: return "That password didn't work, or the file was changed."
        case .damaged: return "This backup is damaged or incomplete, so nothing was restored."
        case .newer: return "This backup was made by a newer version of Anchor. Update Anchor and try again."
        case .notABackup: return "That file isn't an Anchor backup."
        case .io: return "Couldn't read or write the file."
        }
    }
}

enum BackupFormat {
    static let magic = Data("ANCHORBK".utf8)
    static let version: UInt8 = 1
    static let headerLength = 33
    static let chunkSize = 1 << 20
    static let sliceSize = 262_144
    static let iterations: UInt32 = 600_000
    static let minIterations: UInt32 = 100_000
    static let maxIterations: UInt32 = 5_000_000
    static let archiveMagic = Data("AP01".utf8)
    static let maxJSON = 256 * 1024 * 1024
    static let maxFiles: UInt64 = 1_000_000

    static func bigEndian(_ value: UInt64, bytes: Int) -> Data {
        Data((0..<bytes).map { UInt8((value >> UInt64(8 * (bytes - 1 - $0))) & 0xff) })
    }

    static func number(_ data: Data) -> UInt64 {
        data.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    static func deriveKey(password: String, salt: Data, iterations: UInt32) -> SymmetricKey? {
        let secret = password.precomposedStringWithCanonicalMapping
        let saltBytes = [UInt8](salt)
        guard !secret.isEmpty else { return nil }
        var derived = [UInt8](repeating: 0, count: 32)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            secret, secret.utf8.count,
            saltBytes, saltBytes.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
            &derived, derived.count
        )
        return status == kCCSuccess ? SymmetricKey(data: derived) : nil
    }
}

/// Seals what it is given into chunks and writes them to a file as it goes.
final class BackupWriter {
    private let handle: FileHandle
    private let key: SymmetricKey
    private let header: Data
    private let prefix: Data
    private var buffer = Data()
    private var index: UInt64 = 0

    init(url: URL, password: String) throws {
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        let prefix = Data((0..<4).map { _ in UInt8.random(in: 0...255) })
        var header = BackupFormat.magic
        header.append(BackupFormat.version)
        header.append(BackupFormat.bigEndian(UInt64(BackupFormat.iterations), bytes: 4))
        header.append(salt)
        header.append(prefix)
        guard let key = BackupFormat.deriveKey(password: password, salt: salt, iterations: BackupFormat.iterations) else {
            throw BackupError.io
        }
        FileManager.default.createFile(
            atPath: url.path, contents: nil,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        guard let handle = try? FileHandle(forWritingTo: url) else { throw BackupError.io }
        self.handle = handle
        self.key = key
        self.header = header
        self.prefix = prefix
        try handle.write(contentsOf: header)
    }

    func write(_ data: Data) throws {
        buffer.append(data)
        // Keep at least one byte back, so the last chunk is never empty.
        while buffer.count > BackupFormat.chunkSize {
            try seal(Data(buffer.prefix(BackupFormat.chunkSize)), last: false)
            buffer = Data(buffer.dropFirst(BackupFormat.chunkSize))
        }
    }

    func finish() throws {
        try seal(buffer, last: true)
        buffer = Data()
        try handle.close()
    }

    private func seal(_ plain: Data, last: Bool) throws {
        let flag: UInt8 = last ? 1 : 0
        let nonce = try AES.GCM.Nonce(data: prefix + BackupFormat.bigEndian(index, bytes: 8))
        let box = try AES.GCM.seal(plain, using: key, nonce: nonce, authenticating: header + Data([flag]))
        let sealed = box.ciphertext + box.tag
        var out = Data([flag])
        out.append(BackupFormat.bigEndian(UInt64(sealed.count), bytes: 4))
        out.append(sealed)
        try handle.write(contentsOf: out)
        index += 1
    }
}

/// Opens one chunk at a time and hands the plain bytes out in the order they
/// were written. A wrong password shows up on the first chunk; a missing,
/// changed, reordered or extra chunk shows up as damage.
final class BackupReader {
    private let handle: FileHandle
    private let key: SymmetricKey
    private let header: Data
    private let prefix: Data
    private var buffer = Data()
    private var position = 0
    private var index: UInt64 = 0
    private var finished = false

    init(url: URL, password: String) throws {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw BackupError.io }
        guard let header = try? handle.read(upToCount: BackupFormat.headerLength),
              header.count == BackupFormat.headerLength,
              header.prefix(BackupFormat.magic.count) == BackupFormat.magic else {
            throw BackupError.notABackup
        }
        let version = header.subdata(in: 8..<9)[0]
        if version > BackupFormat.version { throw BackupError.newer }
        guard version == BackupFormat.version else { throw BackupError.damaged }
        let iterations = UInt32(BackupFormat.number(header.subdata(in: 9..<13)))
        guard iterations >= BackupFormat.minIterations, iterations <= BackupFormat.maxIterations else {
            throw BackupError.damaged
        }
        let salt = header.subdata(in: 13..<29)
        guard let key = BackupFormat.deriveKey(password: password, salt: salt, iterations: iterations) else {
            throw BackupError.wrongPassword
        }
        self.handle = handle
        self.header = header
        self.prefix = header.subdata(in: 29..<33)
        self.key = key
    }

    deinit { try? handle.close() }

    private var available: Int { buffer.count - position }

    /// Opens the next chunk into the buffer. False when there are no more.
    private func fill() throws -> Bool {
        if finished { return false }
        guard let head = try? handle.read(upToCount: 5), head.count == 5 else { throw BackupError.damaged }
        let flag = head.subdata(in: 0..<1)[0]
        let length = Int(BackupFormat.number(head.subdata(in: 1..<5)))
        guard flag <= 1, length >= 16, length <= BackupFormat.chunkSize + 16 else { throw BackupError.damaged }
        guard let body = try? handle.read(upToCount: length), body.count == length else { throw BackupError.damaged }
        do {
            let nonce = try AES.GCM.Nonce(data: prefix + BackupFormat.bigEndian(index, bytes: 8))
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: body.prefix(length - 16), tag: body.suffix(16))
            buffer = try AES.GCM.open(box, using: key, authenticating: header + Data([flag]))
        } catch {
            throw index == 0 ? BackupError.wrongPassword : BackupError.damaged
        }
        position = 0
        index += 1
        if flag == 1 {
            finished = true
            // Nothing may follow the last chunk.
            if let extra = try? handle.read(upToCount: 1), !extra.isEmpty { throw BackupError.damaged }
        }
        return true
    }

    /// Up to `count` bytes; empty only at the very end.
    func read(upTo count: Int) throws -> Data {
        if available == 0 {
            guard try fill() else { return Data() }
        }
        let take = min(count, available)
        let start = buffer.startIndex + position
        position += take
        return Data(buffer[start..<(start + take)])
    }

    func read(exactly count: Int) throws -> Data {
        var out = Data()
        while out.count < count {
            let piece = try read(upTo: count - out.count)
            if piece.isEmpty { throw BackupError.damaged }
            out.append(piece)
        }
        return out
    }

    /// Call when everything expected has been read: the last chunk must have
    /// been seen and nothing may be left over.
    func finish() throws {
        if available > 0 { throw BackupError.damaged }
        while !finished {
            guard try fill() else { throw BackupError.damaged }
            if available > 0 { throw BackupError.damaged }
        }
    }
}

struct BackupContents {
    let json: Data
    let staging: URL
    let files: [(folder: UInt8, name: String)]
}

enum BackupArchive {
    static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 255 && !name.contains("/") && !name.contains("\\")
            && !name.contains("\0") && !name.hasPrefix(".")
    }

    private static func folderURL(_ folder: UInt8) -> URL {
        folder == 0 ? JournalAttachmentStore.folderURL : VoiceNoteStore.folder
    }

    /// Writes the JSON and then every photo and voice note file, one slice at a time.
    static func write(json: Data, to url: URL, password: String) throws {
        guard json.count <= BackupFormat.maxJSON else { throw BackupError.io }
        let writer = try BackupWriter(url: url, password: password)
        let manager = FileManager.default
        var entries: [(folder: UInt8, url: URL, name: String, size: UInt64)] = []
        let folders: [(UInt8, URL)] = [(0, JournalAttachmentStore.folderURL), (1, VoiceNoteStore.folder)]
        for (folder, directory) in folders {
            let urls = (try? manager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
            )) ?? []
            for fileURL in urls {
                let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                let name = fileURL.lastPathComponent
                guard values?.isRegularFile == true, let size = values?.fileSize, isSafeName(name) else { continue }
                entries.append((folder, fileURL, name, UInt64(size)))
            }
        }
        try writer.write(BackupFormat.archiveMagic)
        try writer.write(BackupFormat.bigEndian(UInt64(json.count), bytes: 4))
        try writer.write(json)
        try writer.write(BackupFormat.bigEndian(UInt64(entries.count), bytes: 4))
        for entry in entries {
            let nameData = Data(entry.name.utf8)
            var head = Data([entry.folder])
            head.append(BackupFormat.bigEndian(UInt64(nameData.count), bytes: 2))
            head.append(nameData)
            head.append(BackupFormat.bigEndian(entry.size, bytes: 8))
            try writer.write(head)
            let input = try FileHandle(forReadingFrom: entry.url)
            defer { try? input.close() }
            var remaining = entry.size
            while remaining > 0 {
                let want = Int(min(remaining, UInt64(BackupFormat.sliceSize)))
                guard let piece = try input.read(upToCount: want), !piece.isEmpty else { throw BackupError.io }
                try writer.write(piece)
                remaining -= UInt64(piece.count)
            }
        }
        try writer.finish()
    }

    /// Reads and checks the whole file, putting the photos and voice notes in a
    /// temporary folder. Nothing in the app changes here.
    static func open(url: URL, password: String, staging: URL) throws -> BackupContents {
        let reader = try BackupReader(url: url, password: password)
        guard try reader.read(exactly: 4) == BackupFormat.archiveMagic else { throw BackupError.damaged }
        let jsonLength = Int(BackupFormat.number(try reader.read(exactly: 4)))
        guard jsonLength <= BackupFormat.maxJSON else { throw BackupError.damaged }
        let json = try reader.read(exactly: jsonLength)
        let count = BackupFormat.number(try reader.read(exactly: 4))
        guard count <= BackupFormat.maxFiles else { throw BackupError.damaged }

        let manager = FileManager.default
        var seen = Set<String>()
        var files: [(folder: UInt8, name: String)] = []
        for _ in 0..<count {
            let folder = try reader.read(exactly: 1).subdata(in: 0..<1)[0]
            let nameLength = Int(BackupFormat.number(try reader.read(exactly: 2)))
            let nameData = try reader.read(exactly: nameLength)
            guard folder <= 1, let name = String(data: nameData, encoding: .utf8), isSafeName(name),
                  seen.insert("\(folder)/\(name)").inserted else { throw BackupError.damaged }
            var remaining = BackupFormat.number(try reader.read(exactly: 8))

            let directory = staging.appendingPathComponent("\(folder)", isDirectory: true)
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appendingPathComponent(name)
            guard manager.createFile(atPath: target.path, contents: nil),
                  let output = try? FileHandle(forWritingTo: target) else { throw BackupError.io }
            defer { try? output.close() }
            while remaining > 0 {
                let piece = try reader.read(upTo: Int(min(remaining, UInt64(BackupFormat.sliceSize))))
                guard !piece.isEmpty else { throw BackupError.damaged }
                try output.write(contentsOf: piece)
                remaining -= UInt64(piece.count)
            }
            files.append((folder, name))
        }
        try reader.finish()
        return BackupContents(json: json, staging: staging, files: files)
    }

    /// Moves each checked file into place unless that name is already there.
    /// Returns how many were added.
    static func restoreFiles(_ contents: BackupContents) -> Int {
        let manager = FileManager.default
        var added = 0
        for file in contents.files {
            let source = contents.staging
                .appendingPathComponent("\(file.folder)", isDirectory: true)
                .appendingPathComponent(file.name)
            let destination = folderURL(file.folder).appendingPathComponent(file.name)
            if manager.fileExists(atPath: destination.path) { continue }
            if (try? manager.moveItem(at: source, to: destination)) != nil { added += 1 }
        }
        return added
    }
}

#if DEBUG
/// Opens a small backup made by scripts/anchorbackup.py, so a debug build proves
/// this code and the reference tool agree on the format. It stops the app with a
/// message if they do not. Only compiled into debug builds.
enum BackupSelfTest {
    private static let vector = "414e43484f52424b01000186a0000102030405060708090a0b0c0d0e0f01020304010000003193396be10fb430f75e7bcd6757dd024c83df701cb5a5dde00af6f6be949da5781c2f2f0aae4ba0c18d63c33281fa59cd13"

    private static var hasRun = false

    static func run() {
        if hasRun { return }
        hasRun = true
        let bytes = stride(from: 0, to: vector.count, by: 2).compactMap { offset -> UInt8? in
            let start = vector.index(vector.startIndex, offsetBy: offset)
            return UInt8(vector[start..<vector.index(start, offsetBy: 2)], radix: 16)
        }
        let id = UUID().uuidString
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("selftest-\(id).anchorbackup")
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("selftest-\(id)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: staging)
        }
        do {
            try Data(bytes).write(to: file)
            let contents = try BackupArchive.open(url: file, password: "anchor test password", staging: staging)
            let voice = staging.appendingPathComponent("1", isDirectory: true).appendingPathComponent("v.m4a")
            let good = contents.json == Data("{}".utf8) && contents.files.count == 1
                && contents.files[0].folder == 1 && contents.files[0].name == "v.m4a"
                && (try? Data(contentsOf: voice)) == Data("abc".utf8)
            if !good { fatalError("Backup self-test: the file opened but its contents are wrong.") }
            do {
                _ = try BackupArchive.open(url: file, password: "not the password", staging: staging.appendingPathComponent("x"))
                fatalError("Backup self-test: a wrong password was accepted.")
            } catch BackupError.wrongPassword {
            }
        } catch {
            fatalError("Backup self-test failed: \(error)")
        }
    }
}
#endif

/// Asks for a password, either to make a backup (twice, at least 8 characters)
/// or to open one. The action returns text to show when it fails, or nil when
/// it worked and the sheet can close.
private struct BackupPasswordSheet: View {
    let title: String
    let message: String
    let buttonTitle: String
    let asksTwice: Bool
    let action: (String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var again = ""
    @State private var working = false
    @State private var errorText: String?

    private var canGo: Bool {
        guard !working else { return false }
        return asksTwice ? (password.count >= 8 && password == again) : !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    if asksTwice {
                        SecureField("Type it again", text: $again)
                            .textContentType(.password)
                    }
                } footer: {
                    Text(message)
                }
                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        working = true
                        errorText = nil
                        Task {
                            let failure = await action(password)
                            working = false
                            if let failure { errorText = failure } else { dismiss() }
                        }
                    } label: {
                        Text(working ? "Working..." : buttonTitle)
                    }
                    .disabled(!canGo)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(working)
                }
            }
            .interactiveDismissDisabled(working)
        }
    }
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
    /// Providers with their sessions. Optional so exports made before this one still import.
    var appointmentSeries: [AppointmentSeriesDTO]? = nil
    /// The sections on each person's page. Optional so exports made before person pages still import.
    var personSections: [PersonSectionDTO]? = nil
    /// The sleep journal, one per night. Optional so exports made before it existed still import.
    var sleepEntries: [SleepEntryDTO]? = nil
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
        "quickLists", "routines", "itemLists", "safetySections", "boundarySections", "messageStarters", "personalGoals", "appointmentSeries", "personSections", "sleepEntries"
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
        appointmentSeries = c.lossyArray(AppointmentSeriesDTO.self, forKey: .appointmentSeries)
        personSections = c.lossyArray(PersonSectionDTO.self, forKey: .personSections)
        sleepEntries = c.lossyArray(SleepEntryDTO.self, forKey: .sleepEntries)
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
    /// The provider (an appointmentSeries id) the item is for. Missing means
    /// anyone, so exports made before providers had their own items still import.
    var providerID: UUID? = nil
    init(_ m: BridgeDraftItem) {
        id = m.id; createdAt = m.createdAt; text = m.text; isResolved = m.isResolved
        isQuestion = m.isQuestion ? true : nil
        answer = m.answer.isEmpty ? nil : m.answer
        providerID = m.providerID
    }
    func toModel() -> BridgeDraftItem {
        BridgeDraftItem(id: id, createdAt: createdAt, text: text, isResolved: isResolved,
                        isQuestion: isQuestion ?? false, answer: answer ?? "", providerID: providerID)
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

struct PersonSectionDTO: Codable {
    var id: UUID; var contactID: UUID; var title: String; var text: String
    var iconName: String; var tintName: String
    var sortOrder: Int; var isHidden: Bool; var lastEditedAt: Date
    init(_ m: PersonSection) {
        id = m.id; contactID = m.contactID; title = m.title; text = m.text
        iconName = m.iconName; tintName = m.tintName
        sortOrder = m.sortOrder; isHidden = m.isHidden; lastEditedAt = m.lastEditedAt
    }
    func toModel() -> PersonSection {
        PersonSection(id: id, contactID: contactID, title: title, text: text, iconName: iconName,
                      tintName: tintName, sortOrder: sortOrder, isHidden: isHidden, lastEditedAt: lastEditedAt)
    }
}

struct SleepEntryDTO: Codable {
    var id: UUID; var nightDate: Date
    var bedTime: Date?; var wakeTime: Date?; var minutesAsleep: Int?; var feel: Int?
    var note: String; var sourceRaw: String; var externalID: String?
    var createdAt: Date; var lastEditedAt: Date
    init(_ m: SleepEntry) {
        id = m.id; nightDate = m.nightDate
        bedTime = m.bedTime; wakeTime = m.wakeTime; minutesAsleep = m.minutesAsleep; feel = m.feel
        note = m.note; sourceRaw = m.sourceRaw; externalID = m.externalID
        createdAt = m.createdAt; lastEditedAt = m.lastEditedAt
    }
    func toModel() -> SleepEntry {
        SleepEntry(id: id, nightDate: nightDate, bedTime: bedTime, wakeTime: wakeTime,
                   minutesAsleep: minutesAsleep, feel: feel, note: note, sourceRaw: sourceRaw,
                   externalID: externalID, createdAt: createdAt, lastEditedAt: lastEditedAt)
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
    /// Optional so exports made before the SMART frame existed still import.
    var usesSMART: Bool?; var smartSpecific: String?; var smartMeasurable: String?
    var smartAchievable: String?; var smartTimeBound: String?
    init(_ m: PersonalGoal) {
        id = m.id; title = m.title; why = m.why; statusRaw = m.statusRaw; notes = m.notes
        sortOrder = m.sortOrder; createdAt = m.createdAt; lastEditedAt = m.lastEditedAt
        usesSMART = m.usesSMART; smartSpecific = m.smartSpecific; smartMeasurable = m.smartMeasurable
        smartAchievable = m.smartAchievable; smartTimeBound = m.smartTimeBound
    }
    func toModel() -> PersonalGoal {
        PersonalGoal(id: id, title: title, why: why, status: GoalStatus(rawValue: statusRaw) ?? .active,
                     notes: notes, sortOrder: sortOrder, createdAt: createdAt, lastEditedAt: lastEditedAt,
                     usesSMART: usesSMART ?? false, smartSpecific: smartSpecific ?? "",
                     smartMeasurable: smartMeasurable ?? "", smartAchievable: smartAchievable ?? "",
                     smartTimeBound: smartTimeBound ?? "")
    }
}

struct AppointmentOccurrenceDTO: Codable {
    var id: UUID; var scheduledDate: Date; var wasMoved: Bool
    var prepNoteEntryID: UUID?; var postSessionNoteEntryID: UUID?
    /// Optional so exports made before session checklists existed still import.
    var prepChecklist: [QuickListItem]?
    init(_ m: AppointmentOccurrence) {
        id = m.id; scheduledDate = m.scheduledDate; wasMoved = m.wasMoved
        prepNoteEntryID = m.prepNoteEntryID; postSessionNoteEntryID = m.postSessionNoteEntryID
        prepChecklist = m.prepChecklist.isEmpty ? nil : m.prepChecklist
    }
    func toModel() -> AppointmentOccurrence {
        AppointmentOccurrence(id: id, scheduledDate: scheduledDate, wasMoved: wasMoved,
                              prepNoteEntryID: prepNoteEntryID, postSessionNoteEntryID: postSessionNoteEntryID,
                              prepChecklist: prepChecklist ?? [])
    }
}

/// A provider with their sessions. The Journal entries that hold a session's
/// prep and after-session notes are in the journal part of the file.
struct AppointmentSeriesDTO: Codable {
    var id: UUID; var clinicianLabel: String; var role: String; var exportLabel: String; var notes: String
    var typicalDayOfWeek: Int?; var typicalHour: Int?; var typicalMinute: Int?
    var typicalCadenceDays: Int; var sortOrder: Int
    var occurrences: [AppointmentOccurrenceDTO]
    init(_ m: AppointmentSeries) {
        id = m.id; clinicianLabel = m.clinicianLabel; role = m.role; exportLabel = m.exportLabel; notes = m.notes
        typicalDayOfWeek = m.typicalDayOfWeek; typicalHour = m.typicalHour; typicalMinute = m.typicalMinute
        typicalCadenceDays = m.typicalCadenceDays; sortOrder = m.sortOrder
        occurrences = m.occurrences.map(AppointmentOccurrenceDTO.init)
    }
    func toModel() -> AppointmentSeries {
        var time: DateComponents?
        if let typicalHour, let typicalMinute { time = DateComponents(hour: typicalHour, minute: typicalMinute) }
        return AppointmentSeries(
            id: id, clinicianLabel: clinicianLabel, typicalDayOfWeek: typicalDayOfWeek, typicalTime: time,
            typicalCadenceDays: typicalCadenceDays, occurrences: occurrences.map { $0.toModel() },
            role: role, exportLabel: exportLabel, notes: notes, sortOrder: sortOrder
        )
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

// MARK: - Data viewer

/// One thing Anchor stores, shown in plain language. The viewer is read only:
/// nothing here can be changed, and app lock settings, keys and raw files are
/// never shown (a file is only ever described as stored data and its size).
struct BrowseField: Identifiable {
    let id = UUID()
    let label: String
    /// Empty means nothing is set, which the viewer says plainly.
    let value: String

    static func text(_ label: String, _ value: String?) -> BrowseField {
        BrowseField(label: label, value: value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
    static func yesNo(_ label: String, _ value: Bool) -> BrowseField {
        BrowseField(label: label, value: value ? "Yes" : "No")
    }
    static func number(_ label: String, _ value: Int?) -> BrowseField {
        BrowseField(label: label, value: value.map(String.init) ?? "")
    }
    static func decimal(_ label: String, _ value: Double) -> BrowseField {
        BrowseField(label: label, value: value.formatted(.number.precision(.fractionLength(0...2))))
    }
    static func date(_ label: String, _ value: Date?) -> BrowseField {
        BrowseField(label: label, value: value?.formatted(date: .abbreviated, time: .shortened) ?? "")
    }
    static func linked(_ label: String, _ value: UUID?) -> BrowseField {
        BrowseField(label: label, value: value == nil ? "" : "Linked")
    }
    static func size(_ label: String, _ value: Data?) -> BrowseField {
        guard let value, !value.isEmpty else { return BrowseField(label: label, value: "") }
        return BrowseField(label: label, value: "Stored data, " + ByteCountFormatter.string(fromByteCount: Int64(value.count), countStyle: .file))
    }
    static func lines(_ label: String, _ values: [String]) -> BrowseField {
        BrowseField(label: label, value: values.joined(separator: "\n"))
    }
    static func count(_ label: String, _ n: Int, _ one: String, _ many: String) -> BrowseField {
        BrowseField(label: label, value: n == 0 ? "" : "\(n) " + (n == 1 ? one : many))
    }
    static func weekdays(_ label: String, _ days: [Int]) -> BrowseField {
        let names = Calendar.current.weekdaySymbols
        let shown = days.sorted().compactMap { names.indices.contains($0 - 1) ? names[$0 - 1] : nil }
        return BrowseField(label: label, value: shown.joined(separator: ", "))
    }
    static func choice(_ label: String, _ value: Any?) -> BrowseField {
        guard let value else { return BrowseField(label: label, value: "") }
        return BrowseField(label: label, value: DataText.humanise(String(describing: value)))
    }
}

enum DataText {
    /// The first non-empty line, shortened.
    static func firstLine(_ text: String, _ fallback: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        if line.isEmpty { return fallback }
        return line.count > 90 ? String(line.prefix(90)) + "..." : line
    }

    /// "physicalAction" becomes "Physical action". Text that already has
    /// brackets or spaces in it is left as it is.
    static func humanise(_ raw: String) -> String {
        if raw.contains("(") || raw.contains(" ") || raw.isEmpty { return raw }
        var out = ""
        for (index, ch) in raw.enumerated() {
            if ch.isUppercase && index > 0 { out.append(" ") }
            out.append(index == 0 ? Character(ch.uppercased()) : Character(ch.lowercased()))
        }
        return out
    }
}

/// A model the data viewer can show. Adopt it, add the type to
/// `DataViewerKinds.all`, and it appears in the viewer.
protocol DataBrowsable {
    static var browseTitle: String { get }
    static var browseSingular: String { get }
    static var browseIcon: String { get }
    var browseHeadline: String { get }
    var browseSubtitle: String? { get }
    var browseDate: Date? { get }
    var browseFields: [BrowseField] { get }
}

/// One row of a list, copied out of the store so the lists themselves need
/// nothing generic.
struct DataRecord: Identifiable {
    let id = UUID()
    let headline: String
    let subtitle: String?
    let date: Date?
    let fields: [BrowseField]
    let searchText: String

    init<M: DataBrowsable>(_ model: M) {
        headline = model.browseHeadline
        subtitle = model.browseSubtitle
        date = model.browseDate
        fields = model.browseFields
        searchText = ([model.browseHeadline] + model.browseFields.map { $0.label + " " + $0.value })
            .joined(separator: "\n")
    }
}

struct DataKind: Identifiable {
    let id: String
    let title: String
    let icon: String
    let count: (ModelContext) -> Int
    let list: () -> AnyView

    static func of<M: PersistentModel & DataBrowsable>(_ type: M.Type) -> DataKind {
        DataKind(
            id: String(describing: M.self),
            title: M.browseTitle,
            icon: M.browseIcon,
            count: { (try? $0.fetchCount(FetchDescriptor<M>())) ?? 0 },
            list: { AnyView(DataKindListView<M>()) }
        )
    }
}

enum DataViewerKinds {
    static let all: [DataKind] = [
        .of(JournalEntry.self), .of(CheckIn.self), .of(SleepEntry.self),
        .of(RecoveryCounter.self), .of(RecoveryDayEntry.self), .of(RecoveryUrge.self), .of(RecoveryMotivation.self),
        .of(SafetyPlanSection.self), .of(SafetyPlan.self), .of(TrustedContact.self), .of(GroundingTool.self),
        .of(TriggerWindow.self), .of(AppointmentSeries.self), .of(TaskItem.self), .of(QuickList.self),
        .of(Routine.self), .of(ItemList.self), .of(DecisionPresetCategory.self), .of(DeEscalationScript.self),
        .of(Affirmation.self), .of(BridgeDraftItem.self), .of(FeedbackLoopDiagram.self), .of(PersonalGoal.self),
        .of(BoundarySection.self), .of(PersonSection.self), .of(ThreadMessage.self), .of(MessageStarter.self),
        .of(SupportCalendarEntry.self), .of(FutureNote.self), .of(UnsentDraft.self)
    ]

    /// Stored kinds that are deliberately not listed: app content, a retired
    /// list, and children that show inside their parent.
    static let leftOut: Set<String> = ["MascotLine", "NextHourItem", "AppointmentOccurrence", "DecisionPresetChoice"]

    /// Names of stored kinds the viewer does not know about. A debug build
    /// stops on this, so a new model cannot be forgotten.
    static var missing: [String] {
        let known = Set(all.map(\.id)).union(leftOut)
        return AnchorSchema.models.map { String(describing: $0) }.filter { !known.contains($0) }
    }
}

/// Asks for Face ID or the passcode again each time the viewer is opened, when
/// the app lock is on. With the lock off, or no way to ask, it opens.
struct DataViewerGate<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var opened = false
    @State private var asking = false

    var body: some View {
        Group {
            if opened {
                content()
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("Unlock to look at your data")
                        .font(.system(.headline, design: .rounded))
                    Button("Unlock") { Task { await unlock() } }
                        .buttonStyle(Anchor.PrimaryButtonStyle())
                        .disabled(asking)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .anchorBackground()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await unlock() }
    }

    private func unlock() async {
        guard !opened, !asking else { return }
        asking = true
        opened = await AppLock.shared.confirmPresence(reason: "Unlock to look at what Anchor has stored.")
        asking = false
    }
}

struct DataViewerHome: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("anchor.dataViewer.blur") private var blur = false
    @State private var counts: [String: Int] = [:]

    var body: some View {
        List {
            Section {
                Text("Everything here is read only. Nothing can be changed from this screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            Section {
                ForEach(DataViewerKinds.all) { kind in
                    NavigationLink {
                        kind.list()
                    } label: {
                        HStack {
                            Anchor.MenuRow(icon: kind.icon, title: kind.title, tint: Anchor.Theme.sage)
                            Spacer()
                            Text("\(counts[kind.id] ?? 0)")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("What's stored")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Blur what is written", isOn: $blur)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .task {
            #if DEBUG
            assert(DataViewerKinds.missing.isEmpty, "Not in the data viewer: \(DataViewerKinds.missing)")
            #endif
            var found: [String: Int] = [:]
            for kind in DataViewerKinds.all { found[kind.id] = kind.count(modelContext) }
            counts = found
        }
    }
}

/// Fetches one kind, copies it out as records and hands them to the list.
struct DataKindListView<M: PersistentModel & DataBrowsable>: View {
    @Environment(\.modelContext) private var modelContext
    @State private var records: [DataRecord] = []
    @State private var loaded = false

    var body: some View {
        DataRecordList(title: M.browseTitle, singular: M.browseSingular, records: records, loaded: loaded)
            .task {
                let items = (try? modelContext.fetch(FetchDescriptor<M>())) ?? []
                records = items.map { DataRecord($0) }.sorted {
                    switch ($0.date, $1.date) {
                    case let (a?, b?): return a > b
                    case (_?, nil): return true
                    case (nil, _?): return false
                    default: return $0.headline.localizedCaseInsensitiveCompare($1.headline) == .orderedAscending
                    }
                }
                loaded = true
            }
    }
}

struct DataRecordList: View {
    let title: String
    let singular: String
    let records: [DataRecord]
    let loaded: Bool

    @AppStorage("anchor.dataViewer.blur") private var blur = false
    @State private var search = ""

    private var shown: [DataRecord] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return records }
        return records.filter { $0.searchText.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            if loaded && records.isEmpty {
                Text("Nothing stored here.")
                    .foregroundStyle(.secondary)
            } else if loaded && shown.isEmpty {
                Text("Nothing matches that.")
                    .foregroundStyle(.secondary)
            }
            ForEach(shown) { record in
                NavigationLink {
                    DataRecordDetail(singular: singular, record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.headline)
                            .font(.system(.body, design: .rounded))
                            .lineLimit(2)
                        if let subtitle = record.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let date = record.date {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .blur(radius: blur ? 6 : 0)
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search")
    }
}

struct DataRecordDetail: View {
    let singular: String
    let record: DataRecord

    @AppStorage("anchor.dataViewer.blur") private var blur = false
    @State private var revealed = false

    private var hidden: Bool { blur && !revealed }

    var body: some View {
        List {
            if blur {
                Section {
                    Button(revealed ? "Hide again" : "Show what is written") { revealed.toggle() }
                }
            }
            Section {
                ForEach(record.fields) { field in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(field.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if field.value.isEmpty {
                            Text("Not set")
                                .foregroundStyle(.tertiary)
                        } else {
                            Text(field.value)
                                .textSelection(.enabled)
                                .blur(radius: hidden ? 6 : 0)
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } footer: {
                Text("Read only.")
            }
        }
        .anchorSettingsStyle()
        .navigationTitle(singular)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - What each kind shows

extension JournalEntry: DataBrowsable {
    static var browseTitle: String { "Journal entries" }
    static var browseSingular: String { "Journal entry" }
    static var browseIcon: String { "text.quote" }
    var browseHeadline: String { DataText.firstLine(text, "Empty entry") }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .date("Created", createdAt),
            .text("Text", text),
            .yesNo("Favourite", isFavorited),
            .choice("Where it was written from", linkedContext),
            .yesNo("Voice note", audioFileName != nil)
        ]
    }
}

extension CheckIn: DataBrowsable {
    static var browseTitle: String { "Check-ins" }
    static var browseSingular: String { "Check-in" }
    static var browseIcon: String { "circle.hexagongrid.fill" }
    var browseHeadline: String { "Check-in" }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { timestamp }
    var browseFields: [BrowseField] {
        [
            .date("Timestamp", timestamp),
            // Named for the five sliders as the check-in asks them, with the value the person left
            // them at. Three are stored turned over, so they are turned back here.
            .decimal("Physical energy", 1 - physicalExhaustion),
            .decimal("Mental clarity", 1 - cognitiveBurnout),
            .decimal("Room in your head", 1 - mentalLoad),
            .decimal("Physical energy to move", physicalEnergy),
            .decimal("Social energy", socialEnergy),
            .linked("Journal entry written from this", expandedEntryID)
        ]
    }
}

extension TrustedContact: DataBrowsable {
    static var browseTitle: String { "Trusted contacts" }
    static var browseSingular: String { "Contact" }
    static var browseIcon: String { "person.2.fill" }
    var browseHeadline: String { name.isEmpty ? "Unnamed contact" : name }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { nil }
    var browseFields: [BrowseField] {
        [
            .text("Name", name),
            .text("Phone number", phoneNumber),
            .number("Position in the list", sortOrder),
            .yesNo("Escalation on", escalationEnabled),
            .number("Escalation window (minutes)", escalationWindowMinutes),
            .lines("Message templates", messageTemplates.map { ($0.isCustom ? "Your own: " : "") + $0.label + ": " + $0.body }),
            .choice("Contact method", contactMethod),
            .text("Discord user", discordUserID),
            .text("Time zone", timeZoneIdentifier),
            .number("Available from (hour)", availableFromHour),
            .number("Available from (minute)", availableFromMinute),
            .number("Available to (hour)", availableToHour),
            .number("Available to (minute)", availableToMinute)
        ]
    }
}

extension GroundingTool: DataBrowsable {
    static var browseTitle: String { "Grounding tools" }
    static var browseSingular: String { "Grounding tool" }
    static var browseIcon: String { "leaf.fill" }
    var browseHeadline: String { title.isEmpty ? "Untitled tool" : title }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { nil }
    var browseFields: [BrowseField] {
        [
            .text("Title", title),
            .choice("Kind", kind),
            .text("Steps", steps),
            .text("Opens", deepLink.map { String(describing: $0) }),
            .number("Position in the list", sortOrder),
            .lines("Useful at", relevantTimeWindows.map { DataText.humanise(String(describing: $0)) })
        ]
    }
}

extension SafetyPlan: DataBrowsable {
    static var browseTitle: String { "Safety plan (older form)" }
    static var browseSingular: String { "Safety plan" }
    static var browseIcon: String { "shield.fill" }
    var browseHeadline: String { "Safety plan" }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { lastEditedAt }
    var browseFields: [BrowseField] {
        [
            .date("Last edited", lastEditedAt),
            .text("Warning signs text", warningSignsText),
            .text("Coping strategies text", copingStrategiesText),
            .text("Reasons to keep going text", reasonsToKeepGoingText),
            .text("Environment safety steps text", environmentSafetyStepsText)
        ]
    }
}

extension SafetyPlanSection: DataBrowsable {
    static var browseTitle: String { "Safety plan sections" }
    static var browseSingular: String { "Safety plan section" }
    static var browseIcon: String { "shield.fill" }
    var browseHeadline: String { title.isEmpty ? "Untitled section" : title }
    var browseSubtitle: String? { DataText.firstLine(text, "") }
    var browseDate: Date? { lastEditedAt }
    var browseFields: [BrowseField] {
        [
            .text("Title", title),
            .text("Text", text),
            .text("Icon", iconName),
            .text("Colour", tintName),
            .number("Position in the list", sortOrder),
            .yesNo("Hidden", isHidden),
            .text("Role", role),
            .date("Last edited", lastEditedAt)
        ]
    }
}

extension BoundarySection: DataBrowsable {
    static var browseTitle: String { "Boundaries sections" }
    static var browseSingular: String { "Boundaries section" }
    static var browseIcon: String { "hand.raised.fill" }
    var browseHeadline: String { title.isEmpty ? "Untitled section" : title }
    var browseSubtitle: String? { DataText.firstLine(text, "") }
    var browseDate: Date? { lastEditedAt }
    var browseFields: [BrowseField] {
        [
            .text("Title", title),
            .text("Text", text),
            .text("Icon", iconName),
            .text("Colour", tintName),
            .number("Position in the list", sortOrder),
            .yesNo("Hidden", isHidden),
            .yesNo("Can be shared", isShareable),
            .date("Last edited", lastEditedAt)
        ]
    }
}

extension PersonSection: DataBrowsable {
    static var browseTitle: String { "Person page sections" }
    static var browseSingular: String { "Person page section" }
    static var browseIcon: String { "person.crop.circle.fill" }
    var browseHeadline: String { title.isEmpty ? "Untitled section" : title }
    var browseSubtitle: String? { DataText.firstLine(text, "") }
    var browseDate: Date? { lastEditedAt }
    var browseFields: [BrowseField] {
        [
            .linked("Contact", contactID),
            .text("Title", title),
            .text("Text", text),
            .text("Icon", iconName),
            .text("Colour", tintName),
            .number("Position in the list", sortOrder),
            .yesNo("Hidden", isHidden),
            .date("Last edited", lastEditedAt)
        ]
    }
}

extension SleepEntry: DataBrowsable {
    static var browseTitle: String { "Sleep nights" }
    static var browseSingular: String { "Sleep night" }
    static var browseIcon: String { "moon.zzz.fill" }
    var browseHeadline: String { "Night of " + nightDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
    var browseSubtitle: String? { shownMinutes.map { SleepEntry.describe(minutes: $0) } }
    var browseDate: Date? { nightDate }
    var browseFields: [BrowseField] {
        [
            .date("Night date", nightDate),
            .date("Bed time", bedTime),
            .date("Wake time", wakeTime),
            .number("Time asleep typed (minutes)", minutesAsleep),
            .number("How it felt (0 to 2)", feel),
            .text("Note", note),
            .text("Source", sourceRaw),
            .text("Source id", externalID),
            .date("Created", createdAt),
            .date("Last edited", lastEditedAt)
        ]
    }
}

extension PersonalGoal: DataBrowsable {
    static var browseTitle: String { "Personal goals" }
    static var browseSingular: String { "Personal goal" }
    static var browseIcon: String { "flag.fill" }
    var browseHeadline: String { title.isEmpty ? "Untitled goal" : title }
    var browseSubtitle: String? { DataText.humanise(statusRaw) }
    var browseDate: Date? { lastEditedAt }
    var browseFields: [BrowseField] {
        [
            .text("Title", title),
            .text("Why", why),
            .text("Status", statusRaw),
            .lines("Notes", notes.map { $0.date.formatted(date: .abbreviated, time: .omitted) + ": " + $0.text }),
            .number("Position in the list", sortOrder),
            .date("Created", createdAt),
            .date("Last edited", lastEditedAt)
        ]
    }
}

extension MessageStarter: DataBrowsable {
    static var browseTitle: String { "Message starters" }
    static var browseSingular: String { "Message starter" }
    static var browseIcon: String { "text.bubble" }
    var browseHeadline: String { text }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { lastEditedAt }
    var browseFields: [BrowseField] {
        [
            .text("Text", text),
            .number("Position in the list", sortOrder),
            .date("Last edited", lastEditedAt)
        ]
    }
}

extension TriggerWindow: DataBrowsable {
    static var browseTitle: String { "Trigger windows" }
    static var browseSingular: String { "Trigger window" }
    static var browseIcon: String { "clock.fill" }
    var browseHeadline: String { label.isEmpty ? "Trigger window" : label }
    var browseSubtitle: String? { String(format: "%d:%02d to %d:%02d", startHour, startMinute, endHour, endMinute) }
    var browseDate: Date? { nil }
    var browseFields: [BrowseField] {
        [
            .text("Label", label),
            .weekdays("Days", daysOfWeek),
            .number("Starts (hour)", startHour),
            .number("Starts (minute)", startMinute),
            .number("Ends (hour)", endHour),
            .number("Ends (minute)", endMinute),
            .yesNo("On", isActive)
        ]
    }
}

extension AppointmentSeries: DataBrowsable {
    static var browseTitle: String { "Providers" }
    static var browseSingular: String { "Provider" }
    static var browseIcon: String { "calendar" }
    var browseHeadline: String { clinicianLabel.isEmpty ? "Provider" : clinicianLabel }
    var browseSubtitle: String? { role.isEmpty ? nil : role }
    var browseDate: Date? { nil }
    var browseFields: [BrowseField] {
        [
            .text("Name", clinicianLabel),
            .weekdays("Usual day", typicalDayOfWeek.map { [$0] } ?? []),
            .number("Usual hour", typicalHour),
            .number("Usual minute", typicalMinute),
            .number("Usual gap (days)", typicalCadenceDays),
            .text("Role", role),
            .text("Name on exports", exportLabel),
            .text("Notes", notes),
            .number("Position in the list", sortOrder),
            .lines("Sessions", occurrences.sorted { $0.scheduledDate < $1.scheduledDate }.map { $0.scheduledDate.formatted(date: .abbreviated, time: .shortened) + ($0.wasMoved ? " (moved)" : "") })
        ]
    }
}

extension BridgeDraftItem: DataBrowsable {
    static var browseTitle: String { "Things to raise" }
    static var browseSingular: String { "Thing to raise" }
    static var browseIcon: String { "doc.text.fill" }
    var browseHeadline: String { text }
    var browseSubtitle: String? { isQuestion ? "Question" : nil }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .date("Created", createdAt),
            .text("Text", text),
            .yesNo("Already brought up", isResolved),
            .yesNo("A question", isQuestion),
            .text("Answer", answer),
            .linked("Provider", providerID)
        ]
    }
}

extension FeedbackLoopDiagram: DataBrowsable {
    static var browseTitle: String { "Feedback-loop diagrams" }
    static var browseSingular: String { "Diagram" }
    static var browseIcon: String { "point.3.connected.trianglepath.dotted" }
    var browseHeadline: String { title.isEmpty ? "Untitled diagram" : title }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { lastEditedAt }
    var browseFields: [BrowseField] {
        [
            .text("Title", title),
            .date("Last edited", lastEditedAt),
            .size("Diagram data", graphJSON)
        ]
    }
}

extension ThreadMessage: DataBrowsable {
    static var browseTitle: String { "Thread messages" }
    static var browseSingular: String { "Message" }
    static var browseIcon: String { "bubble.left.and.bubble.right.fill" }
    var browseHeadline: String { text.isEmpty ? "Voice note" : DataText.firstLine(text, "Message") }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { timestamp }
    var browseFields: [BrowseField] {
        [
            .date("Timestamp", timestamp),
            .text("Text", text),
            .yesNo("Voice note", audioFileName != nil),
            .linked("With contact", withContactID)
        ]
    }
}

extension SupportCalendarEntry: DataBrowsable {
    static var browseTitle: String { "Support calendar entries" }
    static var browseSingular: String { "Support calendar entry" }
    static var browseIcon: String { "calendar.badge.clock" }
    var browseHeadline: String { date.formatted(date: .abbreviated, time: .omitted) }
    var browseSubtitle: String? { DataText.firstLine(note, "") }
    var browseDate: Date? { date }
    var browseFields: [BrowseField] {
        [
            .date("Date", date),
            .text("Note", note),
            .count("Shared with", visibleToContactIDs.count, "person", "people")
        ]
    }
}

extension FutureNote: DataBrowsable {
    static var browseTitle: String { "Notes to future you" }
    static var browseSingular: String { "Note to future you" }
    static var browseIcon: String { "envelope.open.badge.clock" }
    var browseHeadline: String { DataText.firstLine(text, "Empty note") }
    var browseSubtitle: String? { openWhen.isEmpty ? "Opens " + unlockDate.formatted(date: .abbreviated, time: .omitted) : "Open when " + openWhen }
    var browseDate: Date? { writtenAt }
    var browseFields: [BrowseField] {
        [
            .date("Written", writtenAt),
            .date("Unlock date", unlockDate),
            .text("Text", text),
            .yesNo("Unlocked", isUnlocked),
            .text("Open when", openWhen)
        ]
    }
}

extension UnsentDraft: DataBrowsable {
    static var browseTitle: String { "Unsent drafts" }
    static var browseSingular: String { "Unsent draft" }
    static var browseIcon: String { "square.and.pencil" }
    var browseHeadline: String { recipientLabel.isEmpty ? "Draft" : recipientLabel }
    var browseSubtitle: String? { DataText.firstLine(text, "") }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .date("Created", createdAt),
            .text("Recipient label", recipientLabel),
            .text("Text", text),
            .yesNo("Sent", wasSent)
        ]
    }
}

extension DecisionPresetCategory: DataBrowsable {
    static var browseTitle: String { "Decision-preset categories" }
    static var browseSingular: String { "Decision-preset category" }
    static var browseIcon: String { "checklist" }
    var browseHeadline: String { name.isEmpty ? "Category" : name }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { nil }
    var browseFields: [BrowseField] {
        [
            .text("Name", name),
            .number("Position in the list", sortOrder),
            .lines("Options", choices.sorted { $0.sortOrder < $1.sortOrder }.map { $0.name + ($0.steps.isEmpty ? "" : ": " + $0.steps) })
        ]
    }
}

extension DeEscalationScript: DataBrowsable {
    static var browseTitle: String { "De-escalation scripts" }
    static var browseSingular: String { "De-escalation script" }
    static var browseIcon: String { "wind" }
    var browseHeadline: String { text }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { nil }
    var browseFields: [BrowseField] {
        [
            .text("Text", text),
            .number("Position in the list", sortOrder)
        ]
    }
}

extension Affirmation: DataBrowsable {
    static var browseTitle: String { "Affirmations" }
    static var browseSingular: String { "Affirmation" }
    static var browseIcon: String { "sparkles" }
    var browseHeadline: String { text }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { nil }
    var browseFields: [BrowseField] {
        [
            .text("Text", text),
            .number("Position in the list", sortOrder)
        ]
    }
}

extension TaskItem: DataBrowsable {
    static var browseTitle: String { "Tasks" }
    static var browseSingular: String { "Task" }
    static var browseIcon: String { "checkmark.circle.fill" }
    var browseHeadline: String { title.isEmpty ? "Untitled task" : title }
    var browseSubtitle: String? { isDone ? "Done" : nil }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .text("Title", title),
            .text("Notes", notes),
            .yesNo("Done", isDone),
            .date("Completed", completedAt),
            .date("Created", createdAt),
            .number("Position in the list", sortOrder),
            .yesNo("Linked to a Reminders item", reminderIdentifier != nil),
            .choice("Due kind", dueKind),
            .date("Due date", dueDate),
            .linked("Step of another task", parentID),
            .yesNo("Steps folded away", subtasksCollapsed),
            .count("Waiting on", blockedByIDs.count, "task", "tasks"),
            .choice("Status", status),
            .choice("Energy", energy),
            .text("First step", firstStep),
            .number("Focus sessions", focusSessions),
            .number("Focus minutes", focusMinutes),
            .number("Estimate (minutes)", estimateMinutes)
        ]
    }
}

extension QuickList: DataBrowsable {
    static var browseTitle: String { "Quick lists" }
    static var browseSingular: String { "Quick list" }
    static var browseIcon: String { "list.bullet.clipboard" }
    var browseHeadline: String { title.isEmpty ? "Quick list" : title }
    var browseSubtitle: String? { archivedAt == nil ? nil : "In the archive" }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .text("Title", title),
            .date("Created", createdAt),
            .lines("Items", items.map { ($0.isDone ? "[ticked] " : "") + $0.text }),
            .date("Archived", archivedAt)
        ]
    }
}

extension Routine: DataBrowsable {
    static var browseTitle: String { "Routines" }
    static var browseSingular: String { "Routine" }
    static var browseIcon: String { "list.number" }
    var browseHeadline: String { name.isEmpty ? "Routine" : name }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .text("Name", name),
            .date("Created", createdAt),
            .lines("Steps", steps.map { $0.text + ($0.minutes > 0 ? " (\($0.minutes) min)" : "") }),
            .yesNo("Reminder on", reminderEnabled),
            .weekdays("Reminder days", reminderDays),
            .number("Reminder hour", reminderHour),
            .number("Reminder minute", reminderMinute)
        ]
    }
}

extension ItemList: DataBrowsable {
    static var browseTitle: String { "Item lists" }
    static var browseSingular: String { "Item list" }
    static var browseIcon: String { "suitcase" }
    var browseHeadline: String { name.isEmpty ? "List" : name }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .text("Name", name),
            .date("Created", createdAt),
            .lines("Numbers", variables.map { "\($0.name): \($0.value)" }),
            .lines("Items", items.map { ($0.isDone ? "[ticked] " : "") + $0.name + ($0.category.isEmpty ? "" : " (" + $0.category + ")") + ($0.rule.variableID == nil ? " x" + String($0.rule.fixed) : " (follows a number)") })
        ]
    }
}

extension RecoveryCounter: DataBrowsable {
    static var browseTitle: String { "Recovery counters" }
    static var browseSingular: String { "Recovery counter" }
    static var browseIcon: String { "calendar.badge.checkmark" }
    var browseHeadline: String { name.isEmpty ? "Counter" : name }
    var browseSubtitle: String? { isArchived ? "Archived" : nil }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .text("Name", name),
            .text("Name shown outside the app", discreetLabel),
            .yesNo("Name shown outside the app", showNameOutsideApp),
            .choice("Mode", mode),
            .size("Runs (stored data)", runsData),
            .decimal("Savings amount", savingsAmount),
            .choice("Savings period", savingsPeriod),
            .text("Currency code", currencyCode),
            .lines("Milestones already seen (days)", [acknowledgedMilestones.map(String.init).joined(separator: ", ")].filter { !$0.isEmpty }),
            .number("Position in the list", sortOrder),
            .date("Created", createdAt),
            .yesNo("Archived", isArchived),
            .number("Times per day before tracking", priorTimesPerDay)
        ]
    }
}

extension RecoveryMotivation: DataBrowsable {
    static var browseTitle: String { "Recovery reasons" }
    static var browseSingular: String { "Recovery reason" }
    static var browseIcon: String { "heart.fill" }
    var browseHeadline: String { text }
    var browseSubtitle: String? { DataText.humanise(String(describing: kind)) }
    var browseDate: Date? { createdAt }
    var browseFields: [BrowseField] {
        [
            .choice("Kind", kind),
            .text("Text", text),
            .number("Position in the list", sortOrder),
            .date("Created", createdAt)
        ]
    }
}

extension RecoveryDayEntry: DataBrowsable {
    static var browseTitle: String { "Recovery day entries" }
    static var browseSingular: String { "Recovery day entry" }
    static var browseIcon: String { "sun.max.fill" }
    var browseHeadline: String { day.formatted(date: .abbreviated, time: .omitted) }
    var browseSubtitle: String? { nil }
    var browseDate: Date? { day }
    var browseFields: [BrowseField] {
        [
            .linked("Counter", counterID),
            .date("Day", day),
            .date("Pledged", pledgedAt),
            .date("Reviewed", reviewedAt),
            .text("Helped", helped),
            .text("Hard", hard),
            .text("Tomorrow", tomorrow),
            .number("Slip times", slipTimes)
        ]
    }
}

extension RecoveryUrge: DataBrowsable {
    static var browseTitle: String { "Urges logged" }
    static var browseSingular: String { "Urge" }
    static var browseIcon: String { "wind" }
    var browseHeadline: String { DataText.firstLine(note, "Urge") }
    var browseSubtitle: String? { DataText.humanise(String(describing: strength)) }
    var browseDate: Date? { date }
    var browseFields: [BrowseField] {
        [
            .linked("Counter", counterID),
            .date("Date", date),
            .choice("Strength", strength),
            .text("Note", note)
        ]
    }
}
