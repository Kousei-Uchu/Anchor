//
//  JournalEntryEditorView.swift
//  Anchor
//
//  Rebuilt as a real Markdown editor per feedback ("full rich text like
//  Apple Notes, GitHub MD syntax, with UI buttons for anyone who doesn't
//  know markdown"). The entry's `text` field stays the single source of
//  truth (it's just Markdown source now, still a plain String — no
//  SwiftData schema change needed), rendered live via a Write/Preview
//  toggle. Images and drawings insert as standard `![](filename)` Markdown
//  image syntax, with the actual files kept in a local attachments folder
//  and referenced by name — the same "store a filename, not a blob"
//  pattern already used for voice memos elsewhere in this model.
//
//  Formatting uses a UITextView wrapper (MarkdownTextView, below) rather
//  than SwiftUI's plain TextEditor, specifically so toolbar buttons can
//  read and replace the actual selected range (UITextView.selectedRange
//  is well-established, reliable API) instead of only being able to
//  append to the end of the text.
//

import SwiftUI
import SwiftData
import PhotosUI
import PencilKit

struct JournalEntryEditorView: View {
    @Bindable var entry: JournalEntry
    /// When set (editing from the read view), Done hands control back to the
    /// caller instead of dismissing, so the user lands back on the rendered
    /// entry. An empty entry is still deleted and the sheet dismissed.
    var onFinish: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var promptLine: MascotLine?
    @State private var pendingCommand: MarkdownFormatCommand?
    @State private var isPreviewing = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showDrawingCanvas = false
    @State private var showContextSuggestions = false
    @Query(sort: \RecoveryCounter.sortOrder) private var recoveryCounters: [RecoveryCounter]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                RecoveryDayChips(date: entry.createdAt, counters: recoveryCounters, topPadding: 6)
                    .padding(.horizontal)

                if entry.text.isEmpty && !isPreviewing {
                    MascotPresenceView(line: promptLine, mood: .gentle)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    HStack {
                        Button("Give me something to write about") {
                            offerPrompt()
                        }
                        .buttonStyle(Anchor.SecondaryButtonStyle())
                        if promptLine != nil {
                            Button("Use this") {
                                if let text = promptLine?.text {
                                    entry.text = text + "\n\n"
                                }
                            }
                            .buttonStyle(Anchor.PrimaryButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                if isPreviewing {
                    MarkdownPreviewView(markdown: entry.text)
                } else {
                    MarkdownToolbar(
                        pendingCommand: $pendingCommand,
                        onInsertImage: { showPhotoPicker = true },
                        onInsertDrawing: { showDrawingCanvas = true },
                        onAddContext: { showContextSuggestions = true }
                    )
                    MarkdownTextView(text: $entry.text, pendingCommand: $pendingCommand)
                        .padding(.horizontal, 4)
                }
            }
            .navigationTitle(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isPreviewing ? "Edit" : "Preview") {
                        isPreviewing.toggle()
                    }
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
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        insertImageAttachment(data: data)
                    }
                    photoPickerItem = nil
                }
            }
            .sheet(isPresented: $showDrawingCanvas) {
                DrawingCanvasSheet { imageData in
                    insertImageAttachment(data: imageData)
                }
            }
            .sheet(isPresented: $showContextSuggestions) {
                JournalContextSuggestionsView(day: entry.createdAt) { insertion in
                    entry.text += (entry.text.isEmpty ? "" : "\n") + insertion + "\n"
                }
            }
        }
    }

    private func offerPrompt() {
        let engine = MascotEngine(context: modelContext)
        promptLine = engine.line(for: .journalPrompt, mood: .neutral)
    }

    private func insertImageAttachment(data: Data) {
        guard let filename = JournalAttachmentStore.save(imageData: data) else { return }
        let insertion = "\n![](\(filename))\n"
        entry.text += insertion
    }
}

/// One shared folder for every image the Journal ever attaches (photos
/// picked, drawings made, images pulled from context suggestions) —
/// referenced from entry text by filename only, same pattern as
/// JournalEntry.audioFileName elsewhere in the model.
enum JournalAttachmentStore {
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
        let url = folderURL.appendingPathComponent(filename)
        do {
            try imageData.write(to: url)
            return filename
        } catch {
            return nil
        }
    }

    static func image(named filename: String) -> UIImage? {
        UIImage(contentsOfFile: folderURL.appendingPathComponent(filename).path)
    }
}

// MARK: - Markdown formatting toolbar

enum MarkdownFormatCommand: Equatable {
    case bold, italic, heading, bulletList, numberedList, checklist, link
    case insertText(String)
}

struct MarkdownToolbar: View {
    @Binding var pendingCommand: MarkdownFormatCommand?
    var onInsertImage: () -> Void
    var onInsertDrawing: () -> Void
    var onAddContext: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                button("bold", .bold)
                button("italic", .italic)
                button("textformat.size", .heading)
                button("list.bullet", .bulletList)
                button("list.number", .numberedList)
                button("checklist", .checklist)
                button("link", .link)
                Divider().frame(height: 18)
                Button(action: onInsertImage) { Image(systemName: "photo") }
                Button(action: onInsertDrawing) { Image(systemName: "pencil.tip.crop.circle") }
                Button(action: onAddContext) { Image(systemName: "calendar.badge.plus") }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(Anchor.Theme.accent)
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.thinMaterial)
    }

    private func button(_ icon: String, _ command: MarkdownFormatCommand) -> some View {
        Button {
            pendingCommand = command
        } label: {
            Image(systemName: icon)
        }
    }
}

// MARK: - UITextView wrapper (selection-aware formatting)

struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var pendingCommand: MarkdownFormatCommand?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if let command = pendingCommand {
            apply(command, to: uiView)
            DispatchQueue.main.async { pendingCommand = nil }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
        }
    }

    private func apply(_ command: MarkdownFormatCommand, to textView: UITextView) {
        let selectedRange = textView.selectedRange
        let nsText = textView.text as NSString

        func wrap(_ prefix: String, _ suffix: String, placeholder: String) {
            let selectedText = nsText.substring(with: selectedRange)
            let content = selectedText.isEmpty ? placeholder : selectedText
            let replacement = "\(prefix)\(content)\(suffix)"
            let newText = nsText.replacingCharacters(in: selectedRange, with: replacement)
            textView.text = newText
            $text.wrappedValue = newText
            let newCursor = selectedRange.location + (replacement as NSString).length
            textView.selectedRange = NSRange(location: newCursor, length: 0)
        }

        func prefixLines(_ linePrefix: String) {
            let lineRange = nsText.lineRange(for: selectedRange)
            let lineText = nsText.substring(with: lineRange)
            let lines = lineText.components(separatedBy: "\n")
            let prefixed = lines.enumerated().map { index, line -> String in
                if index == lines.count - 1 && line.isEmpty { return line }
                return "\(linePrefix)\(line)"
            }.joined(separator: "\n")
            let newText = nsText.replacingCharacters(in: lineRange, with: prefixed)
            textView.text = newText
            $text.wrappedValue = newText
            let delta = (prefixed as NSString).length - (lineText as NSString).length
            textView.selectedRange = NSRange(location: selectedRange.location + delta, length: 0)
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
            let newText = nsText.replacingCharacters(in: selectedRange, with: string)
            textView.text = newText
            $text.wrappedValue = newText
            let newCursor = selectedRange.location + (string as NSString).length
            textView.selectedRange = NSRange(location: newCursor, length: 0)
        }
    }
}

// MARK: - Preview (read-only rendered Markdown + inline images)

struct MarkdownPreviewView: View {
    let markdown: String

    private enum Block { case text(String), image(String) }

    private var blocks: [Block] {
        guard let pattern = try? NSRegularExpression(pattern: "!\\[[^\\]]*\\]\\(([^)]+)\\)") else {
            return [.text(markdown)]
        }
        var result: [Block] = []
        let full = markdown as NSString
        var lastEnd = 0
        let matches = pattern.matches(in: markdown, range: NSRange(location: 0, length: full.length))
        for match in matches {
            let before = full.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
            if !before.isEmpty { result.append(.text(before)) }
            let filename = full.substring(with: match.range(at: 1))
            result.append(.image(filename))
            lastEnd = match.range.location + match.range.length
        }
        let remainder = full.substring(from: lastEnd)
        if !remainder.isEmpty { result.append(.text(remainder)) }
        if result.isEmpty { result.append(.text(markdown)) }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .text(let string):
                        if let attributed = try? AttributedString(markdown: string, options: .init(interpretedSyntax: .full)) {
                            Text(attributed)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(string)
                        }
                    case .image(let filename):
                        if let uiImage = JournalAttachmentStore.image(named: filename) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                if markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Nothing to preview yet.").foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
