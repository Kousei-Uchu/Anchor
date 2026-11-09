//
//  JournalEntryEditorView.swift
//  Anchor
//
//  The journal page, laid out like Apple's Journal: a date heading, then the
//  entry as a stack of blocks (paragraphs you type into, photos, and cards for
//  events, songs, places and suggestions), with one slim row of tools at the
//  bottom. The entry's `text` is still the single source of truth and is still
//  plain Markdown, so there is no schema change and older entries open as they
//  were:
//    - a line that is only `![](file)` is a photo block;
//    - a line that is only `[Title](anchorcard://kind?t=..&d=..&x=..)` is a card
//      block. An older build, or any Markdown reader, shows it as a link with
//      the card's title, so nothing is lost;
//    - a line that is only `[AI Optimised](anchorassist://v1?r=..&o=..)` is an AI Optimised block (a shorter
//      version and the original it came from, see JournalAssist.swift);
//    - everything else is text, kept exactly as typed.
//  Images stay as files in a local attachments folder, referenced by name.
//

import SwiftUI
import SwiftData
import PhotosUI
import PencilKit

// MARK: - Blocks

/// A card for something pulled in from the day: a calendar event, a song, a
/// place, or one of Apple's journaling suggestions.
struct JournalCard: Equatable {
    enum Kind: String {
        case event, song, place, suggestion

        var icon: String {
            switch self {
            case .event: return "calendar"
            case .song: return "music.note"
            case .place: return "mappin.and.ellipse"
            case .suggestion: return "sparkles"
            }
        }

        var caption: String {
            switch self {
            case .event: return "Event"
            case .song: return "Song"
            case .place: return "Place"
            case .suggestion: return "Suggestion"
            }
        }

        var tint: Color {
            switch self {
            case .event: return Anchor.Theme.accent
            case .song: return Color(red: 0.55, green: 0.46, blue: 0.72)
            case .place: return Anchor.Theme.sage
            case .suggestion: return Anchor.Theme.accent
            }
        }
    }

    var kind: Kind
    var title: String
    var detail: String = ""
    var extra: String = ""
}

extension JournalCard {
    private static let unreserved: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private static func encode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// The single Markdown line this card is stored as.
    var markdownLine: String {
        let label = title
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
        let query = "t=\(Self.encode(title))&d=\(Self.encode(detail))&x=\(Self.encode(extra))"
        return "[\(label)](anchorcard://\(kind.rawValue)?\(query))"
    }

    /// Reads a card back from a line, or nil when the line is anything else.
    init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix(")"),
              let marker = trimmed.range(of: "](anchorcard://") else { return nil }
        let rest = trimmed[marker.upperBound...].dropLast()
        let parts = rest.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let kind = Kind(rawValue: String(parts[0])) else { return nil }
        var values: [String: String] = [:]
        for pair in parts[1].split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard keyValue.count == 2 else { continue }
            values[String(keyValue[0])] = String(keyValue[1]).removingPercentEncoding ?? ""
        }
        self.init(kind: kind, title: values["t"] ?? "", detail: values["d"] ?? "", extra: values["x"] ?? "")
    }
}

struct JournalBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case text(String)
        case image(String)
        case card(JournalCard)
        case assist(JournalAssist)
    }

    let id: UUID
    var kind: Kind

    init(_ kind: Kind, id: UUID = UUID()) {
        self.id = id
        self.kind = kind
    }

    var isText: Bool {
        if case .text = kind { return true }
        return false
    }

    var text: String {
        get {
            if case .text(let string) = kind { return string }
            return ""
        }
        set { kind = .text(newValue) }
    }
}

enum JournalBlocks {
    /// Splits Markdown into blocks without losing anything: text between photo
    /// and card lines is kept exactly, so `serialize(parse(x)) == x`.
    static func parse(_ text: String) -> [JournalBlock] {
        var blocks: [JournalBlock] = []
        var pending: [String] = []
        var hasPending = false

        func flush() {
            if hasPending {
                blocks.append(JournalBlock(.text(pending.joined(separator: "\n"))))
                pending = []
                hasPending = false
            }
        }

        for line in text.components(separatedBy: "\n") {
            if let name = imageName(in: line) {
                flush()
                blocks.append(JournalBlock(.image(name)))
            } else if let card = JournalCard(line: line) {
                flush()
                blocks.append(JournalBlock(.card(card)))
            } else if let assist = JournalAssist(line: line) {
                flush()
                blocks.append(JournalBlock(.assist(assist)))
            } else {
                pending.append(line)
                hasPending = true
            }
        }
        flush()
        return blocks
    }

    static func serialize(_ blocks: [JournalBlock]) -> String {
        blocks.map { block -> String in
            switch block.kind {
            case .text(let string): return string
            case .image(let name): return "![](\(name))"
            case .card(let card): return card.markdownLine
            case .assist(let assist): return assist.markdownLine
            }
        }
        .joined(separator: "\n")
    }

    /// The blocks the editor shows: always at least one paragraph, and always
    /// a paragraph at the end so there is somewhere to keep writing.
    static func editable(_ text: String) -> [JournalBlock] {
        var blocks = parse(text)
        if blocks.isEmpty || !(blocks.last?.isText ?? false) {
            blocks.append(JournalBlock(.text("")))
        }
        return blocks
    }

    /// Joins paragraphs that end up side by side after a block is removed or moved.
    static func merged(_ blocks: [JournalBlock]) -> [JournalBlock] {
        var output: [JournalBlock] = []
        for block in blocks {
            if case .text(let next) = block.kind,
               let last = output.last, case .text(let previous) = last.kind {
                output[output.count - 1].kind = .text(previous + "\n" + next)
            } else {
                output.append(block)
            }
        }
        return output
    }

    static func imageName(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("!["), trimmed.hasSuffix(")"),
              let marker = trimmed.range(of: "](") else { return nil }
        let name = trimmed[marker.upperBound...].dropLast()
        guard !name.isEmpty, !name.contains(" "), !name.contains("("), !name.contains(")") else { return nil }
        return String(name)
    }

    /// One line to stand for an entry in a list: its first words, else the title
    /// of its first card, else a note that it has a photo.
    static func previewLine(_ text: String) -> String? {
        let blocks = parse(text)
        for block in blocks {
            switch block.kind {
            case .text(let string):
                let marks = CharacterSet(charactersIn: "#>*-").union(.whitespaces)
                if let line = string.components(separatedBy: "\n")
                    .map({ $0.trimmingCharacters(in: marks) })
                    .first(where: { !$0.isEmpty }) {
                    return line
                }
            case .card(let card):
                if !card.title.isEmpty { return card.title }
            case .image, .assist:
                // A rewrite is never what stands for an entry in a list.
                break
            }
        }
        let hasImage = blocks.contains { block in
            if case .image = block.kind { return true }
            return false
        }
        return hasImage ? "Photo" : nil
    }

    static func imageNames(in text: String) -> [String] {
        parse(text).compactMap { block in
            if case .image(let name) = block.kind { return name }
            return nil
        }
    }
}

// MARK: - Page header and blocks on screen

struct JournalPageHeader: View {
    let date: Date
    var bookmarked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Spacer(minLength: 0)
                if bookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(Anchor.Theme.accent)
                        .accessibilityLabel("Bookmarked")
                }
            }
            Text("\(date.formatted(.dateTime.year())), \(date.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// A widget-style block for an event, song, place or suggestion.
struct JournalCardView: View {
    let card: JournalCard
    /// Room on the right for the block's menu button while editing.
    var reserveMenuSpace: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: card.kind.icon)
                .font(.title3)
                .foregroundStyle(card.kind.tint)
                .frame(width: 44, height: 44)
                .background(card.kind.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(card.kind.caption.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(card.kind.tint)
                Text(card.title.isEmpty ? card.kind.caption : card.title)
                    .font(.system(.headline, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                if !card.detail.isEmpty {
                    Text(card.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !card.extra.isEmpty {
                    Text(card.extra)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .padding(.trailing, reserveMenuSpace ? 26 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Anchor.Theme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(card.kind.tint.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

struct JournalImageView: View {
    let filename: String

    var body: some View {
        if let image = JournalAttachmentStore.image(named: filename) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityLabel("Photo")
        } else {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.secondary.opacity(0.12))
                .frame(height: 120)
                .overlay(Text("Photo not on this device").font(.footnote).foregroundStyle(.secondary))
        }
    }
}

/// A few small pictures from an entry, for lists.
struct JournalThumbnailStrip: View {
    let filenames: [String]
    private let shown = 3

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(filenames.prefix(shown).enumerated()), id: \.offset) { _, name in
                if let image = JournalAttachmentStore.image(named: name) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                }
            }
            if filenames.count > shown {
                Text("+\(filenames.count - shown)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Editor

struct JournalEntryEditorView: View {
    @Bindable var entry: JournalEntry
    /// When set (editing from the read view), Done hands control back to the
    /// caller instead of dismissing, so the user lands back on the rendered
    /// entry. An empty entry is still deleted and the sheet dismissed.
    var onFinish: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var blocks: [JournalBlock]
    @State private var activeID: UUID?
    @State private var focusRequest: UUID?
    @State private var pendingCommand: MarkdownFormatCommand?
    @State private var showFormatting = false
    @State private var promptLine: MascotLine?
    @State private var showPhotoPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showDrawingCanvas = false
    @State private var showContextSuggestions = false
    @State private var addedToBridge = false
    @State private var showGuide = false
    @StateObject private var ask = AIAsk()
    @State private var assistDraft: JournalAssistDraft?
    @State private var assistMessage: String?
    @State private var braindump: BraindumpDraft?
    @Query(sort: \RecoveryCounter.sortOrder) private var recoveryCounters: [RecoveryCounter]

    init(entry: JournalEntry, onFinish: (() -> Void)? = nil) {
        self.entry = entry
        self.onFinish = onFinish
        _blocks = State(initialValue: JournalBlocks.editable(entry.text))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        JournalPageHeader(date: entry.createdAt, bookmarked: entry.isBookmarked)

                        RecoveryDayChips(date: entry.createdAt, counters: recoveryCounters, topPadding: 0)

                        if let promptLine {
                            promptBlock(promptLine)
                        }

                        if ask.isWorking && ask.pending == nil {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Making a shorter version")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let assistMessage {
                            HStack(alignment: .top, spacing: 10) {
                                Text(assistMessage)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Button {
                                    self.assistMessage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .accessibilityLabel("Dismiss")
                            }
                            .padding(12)
                            .background(Anchor.Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                        }

                        ForEach($blocks) { $block in
                            VStack(alignment: .leading, spacing: 14) {
                                blockView($block)
                                if let draft = assistDraft, draft.after == block.id {
                                    JournalAssistDraftView(draft: draft, onKeep: { keep(draft) }, onDiscard: { assistDraft = nil })
                                        .id("assistDraft")
                                }
                            }
                            .id(block.id)
                        }

                        // Tapping the empty space below the page carries on writing.
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 160)
                            .contentShape(Rectangle())
                            .onTapGesture { focusLastParagraph() }
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: assistDraft?.id) { _, newValue in
                    if newValue != nil {
                        withAnimation { proxy.scrollTo("assistDraft", anchor: .center) }
                    }
                }
                .onChange(of: blocks.count) { oldCount, newCount in
                    // A block added at the end (photo, card) scrolls into view.
                    if newCount > oldCount, let last = blocks.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .anchorBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            entry.isBookmarked.toggle()
                        } label: {
                            Label(entry.isBookmarked ? "Remove bookmark" : "Bookmark",
                                  systemImage: entry.isBookmarked ? "bookmark.slash" : "bookmark")
                        }
                        Button {
                            if let item = BridgeDraftItem.raising(fromJournal: entry.text) {
                                modelContext.insert(item)
                                addedToBridge = true
                            }
                        } label: {
                            Label("Add to things to raise", systemImage: "doc.text")
                        }
                        .disabled(BridgeDraftItem.raising(fromJournal: entry.text) == nil)
                        if AIGate.isEnabled {
                            Menu {
                                Button("This paragraph") { makeShorter(wholeEntry: false) }
                                    .disabled(activeParagraph == nil)
                                Button("Whole entry") { makeShorter(wholeEntry: true) }
                                    .disabled(wholeEntryText == nil)
                            } label: {
                                Label(AIFeature.makeShorter.title, systemImage: "text.alignleft")
                            }
                            .disabled(ask.isWorking)
                            Menu {
                                Button("This paragraph") { startBraindump(wholeEntry: false) }
                                    .disabled(activeParagraph == nil)
                                Button("Whole entry") { startBraindump(wholeEntry: true) }
                                    .disabled(wholeEntryText == nil)
                            } label: {
                                Label("Tidy a braindump", systemImage: "list.bullet.clipboard")
                            }
                            .disabled(ask.isWorking)
                        }
                        Button {
                            showGuide = true
                        } label: {
                            Label("Help for this page", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            modelContext.delete(entry)
                            dismiss()
                        } else if let onFinish {
                            onFinish()
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: blocks) { _, newBlocks in
                let serialized = JournalBlocks.serialize(newBlocks)
                if entry.text != serialized { entry.text = serialized }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItems,
                          maxSelectionCount: 10, matching: .images)
            .onChange(of: photoPickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var names: [String] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let name = JournalAttachmentStore.save(imageData: data) {
                            names.append(name)
                        }
                    }
                    await MainActor.run {
                        insert(names.map { .image($0) })
                        photoPickerItems = []
                    }
                }
            }
            .sheet(isPresented: $showDrawingCanvas) {
                DrawingCanvasSheet { imageData in
                    if let name = JournalAttachmentStore.save(imageData: imageData) {
                        insert([.image(name)])
                    }
                }
            }
            .sheet(isPresented: $showContextSuggestions) {
                JournalContextSuggestionsView(day: entry.createdAt) { kinds in
                    insert(kinds)
                }
            }
            .sheet(isPresented: $showGuide) {
                GuideSheetView(entry: Guide.entry(for: "journal.editor", tab: .journal))
            }
            .sheet(item: $braindump) { draft in
                AIBraindumpSheet(text: draft.text, canEdit: false, destinations: BraindumpDestination.allCases,
                                 sourceEntryID: entry.id)
            }
            .aiAsk(ask)
            .onReceive(NotificationCenter.default.publisher(for: .aiToolsTurnedOff)) { _ in
                // Anything half done is dropped. A block already kept stays, as the person's own entry.
                assistDraft = nil
                assistMessage = nil
                braindump = nil
            }
            .alert("Added to Things to raise", isPresented: $addedToBridge) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can reword it in Bridge. The journal entry is unchanged.")
            }
        }
    }

    // MARK: Blocks

    @ViewBuilder
    private func blockView(_ block: Binding<JournalBlock>) -> some View {
        let value = block.wrappedValue
        switch value.kind {
        case .text:
            AutoGrowTextView(
                text: block.text,
                blockID: value.id,
                activeID: $activeID,
                focusRequest: $focusRequest,
                pendingCommand: $pendingCommand,
                placeholder: blocks.count == 1 ? "Start writing" : ""
            )
        case .image(let name):
            JournalImageView(filename: name)
                .overlay(alignment: .topTrailing) { menuButton(for: value.id) }
                .contextMenu { blockActions(for: value.id) }
        case .card(let card):
            JournalCardView(card: card, reserveMenuSpace: true)
                .overlay(alignment: .topTrailing) { menuButton(for: value.id) }
                .contextMenu { blockActions(for: value.id) }
        case .assist(let assist):
            JournalAssistView(assist: assist, reserveMenuSpace: true)
                .overlay(alignment: .topTrailing) { menuButton(for: value.id) }
                .contextMenu { blockActions(for: value.id) }
        }
    }

    private func menuButton(for id: UUID) -> some View {
        Menu {
            blockActions(for: id)
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(0.45))
                .padding(8)
        }
        .accessibilityLabel("Options for this block")
    }

    @ViewBuilder
    private func blockActions(for id: UUID) -> some View {
        Button { move(id, by: -1) } label: { Label("Move up", systemImage: "arrow.up") }
        Button { move(id, by: 1) } label: { Label("Move down", systemImage: "arrow.down") }
        if let index = blocks.firstIndex(where: { $0.id == id }), case .assist = blocks[index].kind {
            Button { useOriginal(id) } label: { Label("Use the original text", systemImage: "arrow.uturn.backward") }
        }
        Button(role: .destructive) { remove(id) } label: { Label("Remove", systemImage: "trash") }
    }

    /// Adds blocks after the paragraph being written in (or at the end), and
    /// makes sure a paragraph follows them.
    private func insert(_ kinds: [JournalBlock.Kind]) {
        guard !kinds.isEmpty else { return }
        var index = blocks.count
        if let id = activeID, let found = blocks.firstIndex(where: { $0.id == id }) {
            index = found + 1
        }
        let added = kinds.map { JournalBlock($0) }
        blocks.insert(contentsOf: added, at: index)
        let after = index + added.count
        if after >= blocks.count || !blocks[after].isText {
            blocks.insert(JournalBlock(.text("")), at: after)
        }
    }

    private func remove(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        withAnimation {
            blocks.remove(at: index)
            blocks = tidy(JournalBlocks.merged(blocks))
        }
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard blocks.indices.contains(target) else { return }
        withAnimation {
            blocks.swapAt(index, target)
            blocks = tidy(JournalBlocks.merged(blocks))
        }
    }

    // MARK: AI Optimised

    /// The paragraph being written in, when it has words.
    private var activeParagraph: (id: UUID, text: String)? {
        guard let id = activeID, let block = blocks.first(where: { $0.id == id }), block.isText else { return nil }
        let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : (id, text)
    }

    /// Every paragraph of the entry, with photos, cards and kept AI Optimised blocks left out.
    private var wholeEntryText: (after: UUID, text: String)? {
        let paragraphs = blocks.filter { $0.isText && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let last = paragraphs.last else { return nil }
        let text = paragraphs.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n\n")
        return (last.id, text)
    }

    /// Asks for a shorter version of the chosen words. It goes through `AIAsk`, so the switch is checked and the
    /// person sees exactly what is sent first. The answer waits for Keep or Discard and is not in the entry yet.
    private func makeShorter(wholeEntry: Bool) {
        guard AIGate.isEnabled, !ask.isWorking else { return }
        guard let source = wholeEntry ? wholeEntryText.map({ ($0.after, $0.text) }) : activeParagraph.map({ ($0.id, $0.text) }) else { return }
        let (after, text) = source
        assistMessage = nil
        assistDraft = nil
        Task {
            do {
                let answer = try await ask.run(.makeShorter, on: text)
                let rewrite = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    guard AIGate.isEnabled else { return }
                    assistDraft = JournalAssistDraft(after: after, assist: JournalAssist(rewrite: rewrite, original: text))
                }
            } catch let error as AIError {
                await MainActor.run { assistMessage = error.plainText }
            } catch {
                await MainActor.run { assistMessage = AIError.failed.plainText }
            }
        }
    }

    /// Opens Tidy a braindump on the chosen words. Nothing is sent until a button on that sheet is tapped, and
    /// the entry is not changed by it.
    private func startBraindump(wholeEntry: Bool) {
        guard AIGate.isEnabled else { return }
        let words: String? = wholeEntry ? wholeEntryText?.text : activeParagraph?.text
        guard let words else { return }
        braindump = BraindumpDraft(text: words)
    }

    /// Keep: only now does the block become part of the entry.
    private func keep(_ draft: JournalAssistDraft) {
        let index = blocks.firstIndex(where: { $0.id == draft.after }).map { $0 + 1 } ?? blocks.count
        withAnimation {
            blocks.insert(JournalBlock(.assist(draft.assist)), at: index)
            blocks = tidy(blocks)
            assistDraft = nil
        }
    }

    /// Puts the words the block was made from back as an ordinary paragraph and removes the rewrite.
    private func useOriginal(_ id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), case .assist(let assist) = blocks[index].kind else { return }
        withAnimation {
            blocks[index].kind = .text(assist.original)
            blocks = tidy(JournalBlocks.merged(blocks))
        }
    }

    /// Keeps a paragraph at the end of the page.
    private func tidy(_ list: [JournalBlock]) -> [JournalBlock] {
        var result = list
        if result.isEmpty || !(result.last?.isText ?? false) {
            result.append(JournalBlock(.text("")))
        }
        return result
    }

    private func focusLastParagraph() {
        if let last = blocks.last(where: { $0.isText }) {
            focusRequest = last.id
        }
    }

    // MARK: Prompt

    private func promptBlock(_ line: MascotLine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Anchor.Theme.accent)
                Text(line.text)
                    .font(.system(.body, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    promptLine = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss prompt")
            }
            HStack(spacing: 12) {
                Button("Use this") { usePrompt(line.text) }
                    .font(.subheadline.weight(.semibold))
                Button("Another one") { offerPrompt() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Anchor.Theme.accentSoft, in: RoundedRectangle(cornerRadius: 18))
    }

    private func usePrompt(_ text: String) {
        if let index = blocks.lastIndex(where: { $0.isText }) {
            let existing = blocks[index].text
            blocks[index].text = (existing.isEmpty ? "" : existing + "\n\n") + text + "\n\n"
            focusRequest = blocks[index].id
        }
        promptLine = nil
    }

    private func offerPrompt() {
        let engine = MascotEngine(context: modelContext)
        promptLine = engine.line(for: .journalPrompt, mood: .neutral)
    }

    // MARK: Tools

    /// The only chrome on the page: one slim row of tools above the keyboard.
    private var bottomBar: some View {
        VStack(spacing: 0) {
            if showFormatting {
                MarkdownToolbar(pendingCommand: $pendingCommand)
            }
            HStack(spacing: 0) {
                toolButton("sparkles", "Journaling Suggestions") { showContextSuggestions = true }
                toolButton("photo.on.rectangle", "Photos") { showPhotoPicker = true }
                toolButton("pencil.tip.crop.circle", "Drawing") { showDrawingCanvas = true }
                toolButton("lightbulb", "Writing prompt") { offerPrompt() }
                toolButton("textformat", "Formatting", highlighted: showFormatting) {
                    withAnimation { showFormatting.toggle() }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(.bar)
    }

    private func toolButton(_ icon: String, _ label: String, highlighted: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(highlighted ? Color.white : Anchor.Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(highlighted ? Anchor.Theme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One shared folder for every image the Journal ever attaches (photos
/// picked, drawings made, images pulled from context suggestions) —
/// referenced from entry text by filename only, same pattern as
/// JournalEntry.audioFileName elsewhere in the model.
/// Once photos are locked (Patch 35d) a file here is sealed, so it is read and written only through `StoredFiles`.
enum JournalAttachmentStore {
    private static let cache = NSCache<NSString, UIImage>()

    static var folderURL: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JournalAttachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    @discardableResult
    static func save(imageData: Data) -> String? {
        let filename = "\(UUID().uuidString).jpg"
        do {
            try StoredFiles.write(imageData, .journalPhotos, filename)
            return filename
        } catch {
            return nil
        }
    }

    static func image(named filename: String) -> UIImage? {
        if let cached = cache.object(forKey: filename as NSString) { return cached }
        guard let data = StoredFiles.read(.journalPhotos, filename), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: filename as NSString)
        return image
    }
}

// MARK: - Markdown formatting toolbar

enum MarkdownFormatCommand: Equatable {
    case bold, italic, heading, bulletList, numberedList, checklist, link
    case insertText(String)
}

struct MarkdownToolbar: View {
    @Binding var pendingCommand: MarkdownFormatCommand?

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    button("bold", "Bold", .bold)
                    button("italic", "Italic", .italic)
                    button("textformat.size", "Heading", .heading)
                    button("list.bullet", "Bulleted list", .bulletList)
                    button("list.number", "Numbered list", .numberedList)
                    button("checklist", "Checklist", .checklist)
                    button("link", "Link", .link)
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Anchor.Theme.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }

    private func button(_ icon: String, _ label: String, _ command: MarkdownFormatCommand) -> some View {
        Button {
            pendingCommand = command
        } label: {
            Image(systemName: icon)
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Paragraph editor (grows with its text, selection-aware formatting)

/// Light styling for Markdown as it is typed: headings larger, bold and italic
/// shown, the marks themselves dimmed. The text stays plain Markdown.
enum MarkdownStyler {
    static func apply(to textView: UITextView) {
        guard textView.markedTextRange == nil else { return }
        let storage = textView.textStorage
        let full = NSRange(location: 0, length: storage.length)
        let base = UIFont.preferredFont(forTextStyle: .body)

        storage.beginEditing()
        storage.setAttributes([.font: base, .foregroundColor: UIColor.label], range: full)
        let string = storage.string as NSString

        string.enumerateSubstrings(in: full, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = string.substring(with: lineRange)
            var level = 0
            for character in line {
                if character == "#" { level += 1 } else { break }
            }
            guard (1...3).contains(level), line.count > level,
                  line.dropFirst(level).first == " " else { return }
            let style: UIFont.TextStyle = level == 1 ? .title2 : .title3
            storage.addAttribute(.font, value: withTrait(UIFont.preferredFont(forTextStyle: style), .traitBold), range: lineRange)
            storage.addAttribute(.foregroundColor, value: UIColor.tertiaryLabel,
                                 range: NSRange(location: lineRange.location, length: level + 1))
        }

        style(storage, pattern: "\\*\\*(?=\\S)(.+?)(?<=\\S)\\*\\*", markerLength: 2, trait: .traitBold, base: base)
        style(storage, pattern: "(?<![\\w_])_(?=\\S)(.+?)(?<=\\S)_(?![\\w_])", markerLength: 1, trait: .traitItalic, base: base)
        storage.endEditing()

        textView.typingAttributes = [.font: base, .foregroundColor: UIColor.label]
    }

    private static func style(_ storage: NSTextStorage, pattern: String, markerLength: Int,
                              trait: UIFontDescriptor.SymbolicTraits, base: UIFont) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let full = NSRange(location: 0, length: storage.length)
        for match in regex.matches(in: storage.string, range: full) {
            let inner = match.range(at: 1)
            guard inner.length > 0 else { continue }
            let current = storage.attribute(.font, at: inner.location, effectiveRange: nil) as? UIFont ?? base
            storage.addAttribute(.font, value: withTrait(current, trait), range: inner)
            let marker = UIColor.tertiaryLabel
            storage.addAttribute(.foregroundColor, value: marker,
                                 range: NSRange(location: match.range.location, length: markerLength))
            storage.addAttribute(.foregroundColor, value: marker,
                                 range: NSRange(location: match.range.location + match.range.length - markerLength, length: markerLength))
        }
    }

    private static func withTrait(_ font: UIFont, _ trait: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let traits = font.fontDescriptor.symbolicTraits.union(trait)
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
}

struct AutoGrowTextView: View {
    @Binding var text: String
    let blockID: UUID
    @Binding var activeID: UUID?
    @Binding var focusRequest: UUID?
    @Binding var pendingCommand: MarkdownFormatCommand?
    var placeholder: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty && !placeholder.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .allowsHitTesting(false)
            }
            ParagraphTextView(text: $text, blockID: blockID, activeID: $activeID,
                              focusRequest: $focusRequest, pendingCommand: $pendingCommand)
        }
    }
}

struct ParagraphTextView: UIViewRepresentable {
    @Binding var text: String
    let blockID: UUID
    @Binding var activeID: UUID?
    @Binding var focusRequest: UUID?
    @Binding var pendingCommand: MarkdownFormatCommand?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.text = text
        MarkdownStyler.apply(to: textView)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
            MarkdownStyler.apply(to: uiView)
        }

        if focusRequest == blockID {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                uiView.selectedRange = NSRange(location: (uiView.text as NSString).length, length: 0)
                focusRequest = nil
            }
        }

        if let command = pendingCommand, activeID == blockID, !coordinator.applying {
            coordinator.applying = true
            coordinator.apply(command, to: uiView)
            DispatchQueue.main.async {
                pendingCommand = nil
                coordinator.applying = false
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: max(size.height, 30))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ParagraphTextView
        var applying = false

        init(_ parent: ParagraphTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.activeID = parent.blockID
        }

        func textViewDidChange(_ textView: UITextView) {
            sync(textView)
        }

        func sync(_ textView: UITextView) {
            parent.text = textView.text
            MarkdownStyler.apply(to: textView)
        }

        /// Return carries a list on: a new bullet, number or checkbox, and an
        /// empty one ends the list, the way Notes and Journal do.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            guard replacement == "\n", textView.markedTextRange == nil else { return true }
            let string = textView.text as NSString
            let lineRange = string.lineRange(for: NSRange(location: range.location, length: 0))
            let line = string.substring(with: lineRange).trimmingCharacters(in: .newlines)
            guard let (prefix, next) = Self.listPrefix(of: line) else { return true }

            if line == prefix.trimmingCharacters(in: .whitespaces) || line == prefix {
                let itemRange = NSRange(location: lineRange.location, length: (line as NSString).length)
                textView.textStorage.replaceCharacters(in: itemRange, with: "")
                textView.selectedRange = NSRange(location: lineRange.location, length: 0)
            } else {
                let insertion = "\n" + next
                textView.textStorage.replaceCharacters(in: range, with: insertion)
                textView.selectedRange = NSRange(location: range.location + (insertion as NSString).length, length: 0)
            }
            sync(textView)
            return false
        }

        static func listPrefix(of line: String) -> (String, String)? {
            for checklist in ["- [ ] ", "- [x] ", "- [X] "] where line.hasPrefix(checklist) {
                return (checklist, "- [ ] ")
            }
            for bullet in ["- ", "* "] where line.hasPrefix(bullet) {
                return (bullet, bullet)
            }
            if let dot = line.firstIndex(of: "."),
               let number = Int(line[line.startIndex..<dot]),
               line[line.index(after: dot)...].hasPrefix(" ") {
                return ("\(number). ", "\(number + 1). ")
            }
            return nil
        }

        func apply(_ command: MarkdownFormatCommand, to textView: UITextView) {
            let selectedRange = textView.selectedRange
            let nsText = textView.text as NSString

            func replace(_ range: NSRange, with string: String, cursor: Int) {
                textView.textStorage.replaceCharacters(in: range, with: string)
                textView.selectedRange = NSRange(location: cursor, length: 0)
                sync(textView)
            }

            func wrap(_ prefix: String, _ suffix: String, placeholder: String) {
                let selectedText = nsText.substring(with: selectedRange)
                let content = selectedText.isEmpty ? placeholder : selectedText
                let replacement = "\(prefix)\(content)\(suffix)"
                replace(selectedRange, with: replacement,
                        cursor: selectedRange.location + (replacement as NSString).length)
            }

            func prefixLines(_ linePrefix: String) {
                let lineRange = nsText.lineRange(for: selectedRange)
                let lineText = nsText.substring(with: lineRange)
                let lines = lineText.components(separatedBy: "\n")
                let prefixed = lines.enumerated().map { index, line -> String in
                    if index == lines.count - 1 && line.isEmpty { return line }
                    return "\(linePrefix)\(line)"
                }.joined(separator: "\n")
                let delta = (prefixed as NSString).length - (lineText as NSString).length
                replace(lineRange, with: prefixed, cursor: selectedRange.location + delta)
            }

            switch command {
            case .bold: wrap("**", "**", placeholder: "bold text")
            case .italic: wrap("_", "_", placeholder: "italic text")
            case .heading: prefixLines("## ")
            case .bulletList: prefixLines("- ")
            case .numberedList: prefixLines("1. ")
            case .checklist: prefixLines("- [ ] ")
            case .link: wrap("[", "](https://)", placeholder: "link text")
            case .insertText(let string):
                replace(selectedRange, with: string,
                        cursor: selectedRange.location + (string as NSString).length)
            }
        }
    }
}

// MARK: - Reading view (rendered blocks)

/// An entry shown as the page it is: formatted paragraphs, photos in a grid
/// when there are several, and cards. The header, if given, scrolls with it.
struct MarkdownPreviewView<Header: View>: View {
    let markdown: String
    let header: Header

    init(markdown: String, @ViewBuilder header: () -> Header) {
        self.markdown = markdown
        self.header = header()
    }

    private enum Item {
        case text(String)
        case images([String])
        case card(JournalCard)
        case assist(JournalAssist)
    }

    private var items: [Item] {
        var result: [Item] = []
        var images: [String] = []

        func flushImages() {
            if !images.isEmpty {
                result.append(.images(images))
                images = []
            }
        }

        for block in JournalBlocks.parse(markdown) {
            switch block.kind {
            case .text(let string):
                flushImages()
                if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.append(.text(string))
                }
            case .image(let name):
                images.append(name)
            case .card(let card):
                flushImages()
                result.append(.card(card))
            case .assist(let assist):
                flushImages()
                result.append(.assist(assist))
            }
        }
        flushImages()
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case .text(let string):
                        MarkdownLinesView(text: string)
                    case .images(let names):
                        if names.count == 1, let name = names.first {
                            JournalImageView(filename: name)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                                ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                                    if let image = JournalAttachmentStore.image(named: name) {
                                        Color.clear
                                            .aspectRatio(1, contentMode: .fit)
                                            .overlay(
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .accessibilityLabel("Photo")
                                    }
                                }
                            }
                        }
                    case .card(let card):
                        JournalCardView(card: card)
                    case .assist(let assist):
                        JournalAssistView(assist: assist)
                    }
                }
                if items.isEmpty {
                    Text("Nothing written yet.").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension MarkdownPreviewView where Header == EmptyView {
    init(markdown: String) {
        self.init(markdown: markdown) { EmptyView() }
    }
}

/// Renders a paragraph's Markdown line by line: headings, lists, checklists,
/// quotes, and bold, italic and links inside a line.
struct MarkdownLinesView: View {
    let text: String

    private func inline(_ string: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: string, options: options)) ?? AttributedString(string)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Color.clear.frame(height: 8)
        } else if let heading = heading(in: trimmed) {
            Text(inline(heading.text))
                .font(.system(heading.level == 1 ? .title2 : .title3, design: .rounded).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
        } else if trimmed.hasPrefix("- [ ] ") || trimmed.lowercased().hasPrefix("- [x] ") {
            let done = !trimmed.hasPrefix("- [ ] ")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? Anchor.Theme.accent : .secondary)
                Text(inline(String(trimmed.dropFirst(6))))
            }
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\u{2022}")
                Text(inline(String(trimmed.dropFirst(2))))
            }
        } else if let numbered = numbered(in: trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(numbered.number).")
                Text(inline(numbered.text))
            }
        } else if trimmed.hasPrefix("> ") {
            HStack(spacing: 10) {
                Rectangle().fill(Anchor.Theme.accent.opacity(0.5)).frame(width: 3)
                Text(inline(String(trimmed.dropFirst(2)))).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(inline(line))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func heading(in line: String) -> (level: Int, text: String)? {
        var level = 0
        for character in line {
            if character == "#" { level += 1 } else { break }
        }
        guard (1...3).contains(level), line.dropFirst(level).first == " " else { return nil }
        return (level, String(line.dropFirst(level + 1)))
    }

    private func numbered(in line: String) -> (number: Int, text: String)? {
        guard let dot = line.firstIndex(of: "."),
              let number = Int(line[line.startIndex..<dot]) else { return nil }
        let rest = line[line.index(after: dot)...]
        guard rest.hasPrefix(" ") else { return nil }
        return (number, String(rest.dropFirst()))
    }
}

// MARK: - Drawing attachment (PencilKit)

struct DrawingCanvasSheet: View {
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()

    var body: some View {
        NavigationStack {
            PencilCanvasRepresentable(canvasView: $canvasView)
                .navigationTitle("Drawing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            let bounds = canvasView.drawing.bounds.isEmpty
                                ? CGRect(x: 0, y: 0, width: 400, height: 300)
                                : canvasView.drawing.bounds.insetBy(dx: -10, dy: -10)
                            let image = canvasView.drawing.image(from: bounds, scale: UIScreen.main.scale)
                            if let data = image.jpegData(compressionQuality: 0.9) {
                                onSave(data)
                            }
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct PencilCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 4)
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first {
            let toolPicker = PKToolPicker.shared(for: window)
            toolPicker?.setVisible(true, forFirstResponder: canvasView)
            toolPicker?.addObserver(canvasView)
            canvasView.becomeFirstResponder()
        }
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
