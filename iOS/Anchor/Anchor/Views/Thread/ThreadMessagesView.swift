//
//  ThreadMessagesView.swift
//  Anchor
//
//  The message log is tied to a real TrustedContact and can actually send
//  (via Messages or Discord). "Things I haven't said" (UnsentDraftsView) is
//  the other one: a free-text label, never sent, for bigger things.
//
//  Three jobs, all on this screen:
//  - Quick sending: a "Write to" row at the top opens the composer already
//    pointed at that person, so it is one tap from the log to writing.
//  - Per-person history: the log can be narrowed to one person.
//  - Voice notes: a message can carry a short recording, kept on this
//    device. Sent through Messages it goes as an attachment.
//
//  The text of a logged message is not editable, since it is a record of
//  what was said. Tapping one opens it, with Send again, Copy and Delete.
//

import SwiftUI
import SwiftData
import MessageUI
import AVFoundation

// MARK: - Voice note storage

/// Voice notes live in Application Support/VoiceNotes, one .m4a per message.
/// The message keeps only the file name, so a file that is missing (an
/// imported backup, for example) is handled as "not on this device".
enum VoiceNoteStore {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("VoiceNotes", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        }
        return dir
    }

    static func url(for name: String) -> URL { folder.appendingPathComponent(name) }
    static func newFileName() -> String { UUID().uuidString + ".m4a" }
    static func exists(_ name: String?) -> Bool {
        guard let name else { return false }
        return FileManager.default.fileExists(atPath: url(for: name).path)
    }
    static func delete(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: url(for: name))
    }
    static func duration(of name: String) -> TimeInterval {
        guard let player = try? AVAudioPlayer(contentsOf: url(for: name)) else { return 0 }
        return player.duration
    }
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

extension ModelContext {
    /// Deleting a message also removes its voice note file.
    func deleteMessage(_ message: ThreadMessage) {
        VoiceNoteStore.delete(message.audioFileName)
        delete(message)
    }
}

@MainActor
final class VoiceNoteRecorder: NSObject, ObservableObject {
    static let maxSeconds: TimeInterval = 300

    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var micDenied = false
    @Published private(set) var fileName: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?

    func start() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { micDenied = true; return }
        VoiceNoteStore.delete(fileName)
        fileName = nil
        let name = VoiceNoteStore.newFileName()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let rec = try AVAudioRecorder(url: VoiceNoteStore.url(for: name), settings: settings)
            guard rec.record() else { return }
            recorder = rec
            fileName = name
            elapsed = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch {
            VoiceNoteStore.delete(name)
        }
    }

    private func tick() {
        guard let recorder, isRecording else { return }
        elapsed = recorder.currentTime
        if elapsed >= Self.maxSeconds { stop() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // A recording with nothing in it is not worth keeping.
        if let name = fileName, VoiceNoteStore.duration(of: name) < 0.5 {
            VoiceNoteStore.delete(name)
            fileName = nil
        }
    }

    /// Hands the recording over to a saved message; the recorder forgets it.
    func take() -> String? {
        let name = fileName
        fileName = nil
        return name
    }

    func discard() {
        if isRecording { stop() }
        VoiceNoteStore.delete(fileName)
        fileName = nil
    }
}

@MainActor
final class VoiceNotePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingName: String?
    private var player: AVAudioPlayer?

    func toggle(_ name: String) {
        if playingName == name { stop(); return }
        stop()
        guard VoiceNoteStore.exists(name) else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: VoiceNoteStore.url(for: name))
            p.delegate = self
            guard p.play() else { return }
            player = p
            playingName = name
        } catch {
            playingName = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingName = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playingName = nil }
    }
}

/// Play or stop one voice note, with its length.
private struct VoiceNoteRow: View {
    let fileName: String
    @ObservedObject var player: VoiceNotePlayer

    var body: some View {
        if VoiceNoteStore.exists(fileName) {
            let playing = player.playingName == fileName
            Button {
                player.toggle(fileName)
            } label: {
                Label(
                    playing ? "Stop" : "Play voice note  \(VoiceNoteStore.clock(VoiceNoteStore.duration(of: fileName)))",
                    systemImage: playing ? "stop.circle.fill" : "play.circle.fill"
                )
                .font(.system(.subheadline, design: .rounded).weight(.medium))
            }
            .buttonStyle(.borderless)
            .tint(Anchor.Theme.accent)
        } else {
            Label("Voice note is not on this device", systemImage: "waveform.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - The log

/// Names the person the composer should start with, if any.
struct MessageComposerRequest: Identifiable {
    let id = UUID()
    var contactID: UUID?
}

struct ThreadMessagesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ThreadMessage.timestamp, order: .reverse) private var messages: [ThreadMessage]
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]

    @StateObject private var player = VoiceNotePlayer()
    @State private var composerRequest: MessageComposerRequest?
    @State private var openedMessage: ThreadMessage?
    @State private var messageToDelete: ThreadMessage?
    @State private var filterContactID: UUID?

    /// Opens the log already narrowed to one person, as from their page.
    /// With no one given it shows everyone, as before.
    init(startingWith contactID: UUID? = nil) {
        _filterContactID = State(initialValue: contactID)
    }

    private var shownMessages: [ThreadMessage] {
        guard let filterContactID else { return messages }
        return messages.filter { $0.withContactID == filterContactID }
    }

    /// Only people who actually have something in the log are offered as a filter.
    private var contactsWithMessages: [TrustedContact] {
        let ids = Set(messages.compactMap(\.withContactID))
        return contacts.filter { ids.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                Text("Quick notes tied to a real contact. Sent right away if you want, or just saved as a log of what you've told them over time. For bigger things you might never send, that's \"Things I haven't said\" instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !contacts.isEmpty {
                    writeToRow
                }

                if messages.isEmpty {
                    Anchor.EmptyState(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "No messages yet",
                        message: "Write a quick note to someone, record a voice note, or just save it privately as a record of what you've told them.",
                        actionTitle: "Write something",
                        tint: Anchor.Theme.accent
                    ) { composerRequest = MessageComposerRequest() }
                } else {
                    if contactsWithMessages.count > 0 {
                        filterMenu
                    }
                    if shownMessages.isEmpty {
                        Text("Nothing here yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(shownMessages) { message in
                        messageCard(message)
                            .anchorDeletable { modelContext.deleteMessage(message) }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Message log")
        .guideButton("thread.messages", tab: .thread)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                NavigationLink {
                    MessageStartersView()
                } label: {
                    Image(systemName: "text.bubble")
                }
                .accessibilityLabel("Your message starters")
                Anchor.AddToolbarButton(label: "Write something") {
                    composerRequest = MessageComposerRequest(contactID: filterContactID)
                }
            }
        }
        .sheet(item: $composerRequest) { request in
            ThreadMessageComposer(startingContactID: request.contactID)
        }
        .sheet(item: $openedMessage, onDismiss: finishViewing) { message in
            ThreadMessageSheet(
                message: message,
                contact: contact(for: message),
                player: player
            ) {
                messageToDelete = message
            }
        }
        .onDisappear { player.stop() }
    }

    /// One tap from the log to writing to a particular person.
    private var writeToRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Write to")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(contacts) { contact in
                        Button {
                            composerRequest = MessageComposerRequest(contactID: contact.id)
                        } label: {
                            Label(contact.name, systemImage: "square.and.pencil")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Anchor.Theme.accentSoft))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Anchor.Theme.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterMenu: some View {
        HStack {
            Menu {
                Picker("Show", selection: $filterContactID) {
                    Text("Everyone").tag(UUID?.none)
                    ForEach(contactsWithMessages) { contact in
                        Text(contact.name).tag(Optional(contact.id))
                    }
                }
            } label: {
                Label(
                    filterContactID.flatMap { id in contacts.first(where: { $0.id == id })?.name } ?? "Everyone",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .font(.system(.subheadline, design: .rounded).weight(.medium))
            }
            Spacer()
        }
    }

    private func messageCard(_ message: ThreadMessage) -> some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    openedMessage = message
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = contact(for: message)?.name {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !message.text.isEmpty {
                                Text(message.text)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let audio = message.audioFileName {
                    VoiceNoteRow(fileName: audio, player: player)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func contact(for message: ThreadMessage) -> TrustedContact? {
        guard let contactID = message.withContactID else { return nil }
        return contacts.first(where: { $0.id == contactID })
    }

    /// Deleting waits until the sheet has closed, so the sheet never reads
    /// a message that is already gone.
    private func finishViewing() {
        player.stop()
        if let message = messageToDelete {
            modelContext.deleteMessage(message)
            messageToDelete = nil
        }
    }
}

// MARK: - One message

private struct SendRequest: Identifiable {
    let id = UUID()
    let recipient: String
    let body: String
    let attachment: URL?
}

/// One logged message, with Send again, Copy and Delete.
private struct ThreadMessageSheet: View {
    let message: ThreadMessage
    let contact: TrustedContact?
    @ObservedObject var player: VoiceNotePlayer
    let onDelete: () -> Void

    @State private var sendRequest: SendRequest?
    @State private var discordFailureMessage: String?
    @State private var copied = false

    private var hasVoice: Bool { VoiceNoteStore.exists(message.audioFileName) }

    var body: some View {
        Anchor.ItemEditorSheet(title: "Message", onDelete: onDelete, deleteQuestion: "Delete this message?") {
            Form {
                if let contact {
                    Section("About") { Text(contact.name) }
                }
                if !message.text.isEmpty {
                    Section("Message") { Text(message.text) }
                }
                if let audio = message.audioFileName {
                    Section("Voice note") {
                        VoiceNoteRow(fileName: audio, player: player)
                        if hasVoice {
                            ShareLink(item: VoiceNoteStore.url(for: audio)) {
                                Label("Share voice note", systemImage: "square.and.arrow.up")
                            }
                            .hiddenInShowcase()
                        }
                    }
                }
                Section("Written") {
                    Text(message.timestamp.formatted(date: .complete, time: .shortened))
                }
                Section {
                    if let contact {
                        switch contact.contactMethod {
                        case .phone:
                            Button("Send again via Messages") {
                                sendRequest = SendRequest(
                                    recipient: contact.phoneNumber,
                                    body: message.text,
                                    attachment: hasVoice ? message.audioFileName.map(VoiceNoteStore.url(for:)) : nil
                                )
                            }
                        case .discord:
                            Button("Open Discord") {
                                DiscordOpener.openUser(contact.discordUserID) { discordFailureMessage = $0 }
                            }
                        }
                    }
                    if !message.text.isEmpty {
                        Button(copied ? "Copied" : "Copy text") {
                            UIPasteboard.general.string = message.text
                            copied = true
                        }
                    }
                }
            }
            .sheet(item: $sendRequest) { request in
                if MFMessageComposeViewController.canSendText() {
                    MessageComposeView(recipient: request.recipient, body: request.body, attachmentURL: request.attachment)
                } else {
                    Text("This device can't send text messages.")
                        .padding()
                }
            }
            .alert("Couldn't open Discord", isPresented: Binding(
                get: { discordFailureMessage != nil },
                set: { if !$0 { discordFailureMessage = nil } }
            )) {
                Button("OK", role: .cancel) { discordFailureMessage = nil }
            } message: {
                Text(discordFailureMessage ?? "")
            }
        }
    }
}

// MARK: - Writing

/// Compose a new log entry: pick who it's about, write it or record it,
/// then either save it privately or save and send.
struct ThreadMessageComposer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]
    @Query(sort: \MessageStarter.sortOrder) private var starters: [MessageStarter]

    @StateObject private var recorder = VoiceNoteRecorder()
    @StateObject private var player = VoiceNotePlayer()
    @FocusState private var textFocused: Bool

    @State private var newMessageText = ""
    @State private var selectedContactID: UUID?
    @State private var sendRequest: SendRequest?
    @State private var discordFailureMessage: String?

    init(startingContactID: UUID? = nil) {
        _selectedContactID = State(initialValue: startingContactID)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !contacts.isEmpty {
                    Section("About") {
                        Picker("About", selection: $selectedContactID) {
                            Text("No one in particular").tag(UUID?.none)
                            ForEach(contacts) { contact in
                                Text(contact.name).tag(Optional(contact.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Message") {
                    TextField("Write something…", text: $newMessageText, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($textFocused)
                }

                Section {
                    ForEach(usableStarters) { starter in
                        Button {
                            newMessageText = MessageStarter.adding(starter.text, to: newMessageText)
                            textFocused = true
                        } label: {
                            Text(starter.text)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    NavigationLink {
                        MessageStartersView()
                    } label: {
                        Text(usableStarters.isEmpty ? "Write a starter you can reuse" : "Change your starters")
                    }
                } header: {
                    if !usableStarters.isEmpty { Text("Starters") }
                }

                Section("Voice note") {
                    voiceSection
                }

                Section {
                    Button("Save privately") {
                        _ = saveOnly()
                        dismiss()
                    }
                    .disabled(!canSave)

                    if let contactID = selectedContactID, let contact = contacts.first(where: { $0.id == contactID }) {
                        switch contact.contactMethod {
                        case .phone:
                            Button("Save & send via Messages") {
                                let body = newMessageTrimmed
                                let attachment = recorder.fileName.map(VoiceNoteStore.url(for:))
                                _ = saveOnly()
                                sendRequest = SendRequest(recipient: contact.phoneNumber, body: body, attachment: attachment)
                            }
                            .disabled(!canSave)
                        case .discord:
                            Button("Save & open Discord") {
                                _ = saveOnly()
                                DiscordOpener.openUser(contact.discordUserID) { message in
                                    discordFailureMessage = message
                                }
                            }
                            .disabled(!canSave)
                        }
                    }
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Write something")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        recorder.discard()
                        dismiss()
                    }
                }
            }
            .onAppear { textFocused = true }
            .onDisappear {
                // Anything recorded but never saved is not kept.
                recorder.discard()
                player.stop()
            }
            .sheet(item: $sendRequest, onDismiss: { dismiss() }) { request in
                if MFMessageComposeViewController.canSendText() {
                    MessageComposeView(recipient: request.recipient, body: request.body, attachmentURL: request.attachment)
                } else {
                    Text("This device can't send text messages.")
                        .padding()
                }
            }
            .alert("Couldn't open Discord", isPresented: Binding(
                get: { discordFailureMessage != nil },
                set: { if !$0 { discordFailureMessage = nil } }
            )) {
                Button("OK", role: .cancel) { discordFailureMessage = nil }
            } message: {
                Text(discordFailureMessage ?? "")
            }
            .alert("Microphone is off for Anchor", isPresented: $recorder.micDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("You can turn it on in Settings if you want to record voice notes.")
            }
        }
    }

    @ViewBuilder
    private var voiceSection: some View {
        if recorder.isRecording {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(Anchor.Theme.accent)
                Text("Recording  \(VoiceNoteStore.clock(recorder.elapsed))")
                Spacer()
                Button("Stop") { recorder.stop() }
                    .buttonStyle(.borderless)
            }
        } else if let name = recorder.fileName {
            VoiceNoteRow(fileName: name, player: player)
            Button("Record again") {
                player.stop()
                Task { await recorder.start() }
            }
            Button("Remove voice note", role: .destructive) {
                player.stop()
                recorder.discard()
            }
        } else {
            Button {
                textFocused = false
                Task { await recorder.start() }
            } label: {
                Label("Record a voice note", systemImage: "mic.fill")
            }
        }
    }

    private var usableStarters: [MessageStarter] {
        starters.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var canSave: Bool {
        !recorder.isRecording && (!newMessageTrimmed.isEmpty || recorder.fileName != nil)
    }

    private var newMessageTrimmed: String {
        newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The recording is handed to the saved message, so closing the sheet
    /// afterwards does not delete it.
    @discardableResult
    private func saveOnly() -> Bool {
        let trimmed = newMessageTrimmed
        let audio = recorder.take()
        guard !trimmed.isEmpty || audio != nil else { return false }
        modelContext.insert(ThreadMessage(text: trimmed, audioFileName: audio, withContactID: selectedContactID))
        newMessageText = ""
        return true
    }
}


// MARK: - Message starters

/// The person's own short lines for starting a message on a hard day. The list
/// starts empty and nothing is written for them. Tap a card to reword it, the
/// plus adds one, Delete is in the editor and in the card's long-press menu,
/// and Reorder shows with two or more because the order is the order they are
/// offered in. A starter only ever goes into the message box or the Messages
/// sheet, where it can be changed, and nothing is sent unless they send it.
struct MessageStartersView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MessageStarter.sortOrder) private var starters: [MessageStarter]
    @State private var editing: MessageStarter?
    @State private var toDelete: MessageStarter?

    var body: some View {
        Group {
            if starters.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "text.bubble",
                        title: "Nothing here yet",
                        message: "Short lines of your own for starting a message when talking is hard. They are there to tap, and you can change them before anything is sent.",
                        actionTitle: "Write one",
                        tint: Anchor.Theme.sage
                    ) { startNew() }
                    .padding()
                }
            } else {
                List {
                    ForEach(starters) { starter in
                        Anchor.Card {
                            Button { editing = starter } label: {
                                Text(starter.text.isEmpty ? "Untitled" : starter.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the editor")
                        }
                        .anchorDeletable { modelContext.delete(starter) }
                        .anchorCardRow()
                    }
                    .onMove(perform: move)
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Message starters")
        .guideButton("thread.message-starters", tab: .thread)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if starters.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Anchor.AddToolbarButton(label: "Write a starter") { startNew() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { starter in
            MessageStarterEditorSheet(starter: starter) { toDelete = starter }
        }
    }

    private func startNew() {
        let new = MessageStarter(text: "", sortOrder: (starters.map(\.sortOrder).max() ?? -1) + 1)
        modelContext.insert(new)
        editing = new
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = starters
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in reordered.enumerated() { item.sortOrder = index }
    }

    /// Runs once the editor has closed, so the editor never reads a starter
    /// that is already gone. One added and left blank is dropped.
    private func finishEditing() {
        let deleting = toDelete
        toDelete = nil
        if let deleting { modelContext.delete(deleting) }
        for item in starters where item !== deleting
            && item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(item)
        }
    }
}

private struct MessageStarterEditorSheet: View {
    @Bindable var starter: MessageStarter
    let onDelete: () -> Void

    var body: some View {
        Anchor.ItemEditorSheet(
            title: starter.text.isEmpty ? "New starter" : "Starter",
            onDelete: onDelete,
            deleteQuestion: "Delete this starter?"
        ) {
            Form {
                Section {
                    TextField("Something short you could send", text: $starter.text, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .onChange(of: starter.text) { _, _ in starter.lastEditedAt = .now }
        }
    }
}
