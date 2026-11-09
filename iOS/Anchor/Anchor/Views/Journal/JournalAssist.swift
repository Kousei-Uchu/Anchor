//
//  JournalAssist.swift
//  Anchor
//
//  The AI Optimised block (Patch AI2, docs/OPTIONAL_FEATURES.md, E3). A shorter version of a paragraph, kept
//  next to the words it came from. It is one Markdown line in the entry's own text, like a card, so there is
//  no model change: the rewrite and the original it was made from both travel with the entry through locking,
//  backup, export and import. An older build, or any Markdown reader, shows the line as plain text and loses
//  nothing. Nothing is kept until the person taps Keep.
//

import SwiftUI

/// The rewrite and the exact text it was made from.
struct JournalAssist: Equatable {
    var rewrite: String
    var original: String

    static let label = "AI Optimised"
    private static let opening = "[\(label)](anchorassist://v1?"

    private static let unreserved: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private static func encode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// The single Markdown line this block is stored as. Everything is percent-encoded, so line breaks in
    /// either text cannot split it.
    var markdownLine: String {
        Self.opening + "r=\(Self.encode(rewrite))&o=\(Self.encode(original)))"
    }

    /// Reads a block back from a line, or nil when the line is anything else.
    init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(Self.opening), trimmed.hasSuffix(")") else { return nil }
        let query = trimmed.dropFirst(Self.opening.count).dropLast()
        var values: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard keyValue.count == 2 else { continue }
            values[String(keyValue[0])] = String(keyValue[1]).removingPercentEncoding ?? ""
        }
        guard let rewrite = values["r"], let original = values["o"] else { return nil }
        self.rewrite = rewrite
        self.original = original
    }

    init(rewrite: String, original: String) {
        self.rewrite = rewrite
        self.original = original
    }

    /// A line is this kind of block (cheap test, for code that only needs to skip them).
    static func isBlockLine(_ line: String) -> Bool {
        line.contains("](anchorassist://")
    }
}

/// A shorter version waiting for Keep or Discard. It lives only on screen: nothing is in the entry until Keep.
struct JournalAssistDraft: Identifiable, Equatable {
    let id = UUID()
    /// The block it was made from, so it appears right after it.
    let after: UUID
    let assist: JournalAssist
}

/// A kept block: folded to begin with, the shorter version when opened, and the original one tap further.
struct JournalAssistView: View {
    let assist: JournalAssist
    /// Room on the right for the block's menu button while editing.
    var reserveMenuSpace: Bool = false
    @State private var open = false
    @State private var showOriginal = false

    var body: some View {
        JournalAssistFrame(reserveMenuSpace: reserveMenuSpace) {
            Button {
                withAnimation { open.toggle() }
            } label: {
                HStack {
                    JournalAssistHeading()
                    Spacer(minLength: 0)
                    Image(systemName: open ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("AI Optimised")
            .accessibilityValue(open ? "Open" : "Folded")
            .accessibilityHint(open ? "Folds it" : "Opens it")

            if open {
                JournalAssistBody(assist: assist, showOriginal: $showOriginal)
            }
        }
    }
}

/// A shorter version that has not been kept yet. It is open, so it is read before it is kept.
struct JournalAssistDraftView: View {
    let draft: JournalAssistDraft
    let onKeep: () -> Void
    let onDiscard: () -> Void
    @State private var showOriginal = false

    var body: some View {
        JournalAssistFrame(reserveMenuSpace: false) {
            JournalAssistHeading()
            JournalAssistBody(assist: draft.assist, showOriginal: $showOriginal)
            HStack(spacing: 12) {
                Button("Keep", action: onKeep)
                    .font(.subheadline.weight(.semibold))
                Button("Discard", role: .destructive, action: onDiscard)
                    .font(.subheadline)
            }
        }
    }
}

private struct JournalAssistHeading: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .foregroundStyle(Anchor.Theme.accent)
                .accessibilityHidden(true)
            Text(JournalAssist.label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Anchor.Theme.accent)
        }
    }
}

private struct JournalAssistBody: View {
    let assist: JournalAssist
    @Binding var showOriginal: Bool

    var body: some View {
        Text(assist.rewrite)
            .font(.system(.body, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
        Button {
            withAnimation { showOriginal.toggle() }
        } label: {
            Text(showOriginal ? "Hide original" : "Show original")
                .font(.subheadline)
        }
        if showOriginal {
            VStack(alignment: .leading, spacing: 4) {
                Text("Original")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(assist.original)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

/// The look shared by a kept block and a waiting one: a dashed outline, so it never reads as the person's own
/// paragraph.
private struct JournalAssistFrame<Content: View>: View {
    var reserveMenuSpace: Bool
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .padding(.trailing, reserveMenuSpace ? 26 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Anchor.Theme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Anchor.Theme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}

extension JournalBlocks {
    /// An entry as words for something handed to someone else. AI Optimised blocks are left out, so a rewrite
    /// is never passed off as the person's own words (D43). When they are ticked in, each is labelled.
    static func sharedText(_ text: String, includeAssist: Bool) -> String {
        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            if let assist = JournalAssist(line: line) {
                if includeAssist {
                    lines.append("[AI Optimised: a shorter version made by a tool, not the writer's own words]")
                    lines.append(assist.rewrite)
                }
            } else if JournalVoice.isBlockLine(line) {
                // Sound is never handed over in the words of an entry, only the file name would show.
                continue
            } else {
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }

    static func hasAssist(_ text: String) -> Bool {
        text.contains("](anchorassist://")
    }
}

#if DEBUG
/// Checks, in a test build, that an AI Optimised block survives being stored: any text round trips through the
/// line, an entry with the block in it serialises back to exactly what was read, an older reader (the card
/// parser) leaves the line alone, and leaving it out of a shared text leaves the writer's own words untouched.
enum JournalAssistSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("AI Optimised self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let tricky = "Line one\n\nLine \"two\" & (three) [four] #five 100% café 😀\n  indented"
        let assist = JournalAssist(rewrite: "Short & sweet (really)", original: tricky)
        let line = assist.markdownLine
        check(!line.contains("\n"), "the line must stay one line")
        check(JournalAssist(line: line) == assist, "the block must read back exactly")
        check(JournalCard(line: line) == nil, "an older reader must not take it for a card")
        check(JournalBlocks.imageName(in: line) == nil, "it is not a photo line")

        let entry = "First paragraph.\n" + line + "\n![](photo.jpg)\nLast words."
        let blocks = JournalBlocks.parse(entry)
        check(blocks.count == 4, "text, block, photo, text")
        check(JournalBlocks.serialize(blocks) == entry, "the entry must serialise back exactly")
        check(JournalBlocks.previewLine(entry) == "First paragraph.", "the preview uses the writer's words")
        check(JournalBlocks.previewLine(line) == nil, "a rewrite alone is never a preview")

        let left = JournalBlocks.sharedText(entry, includeAssist: false)
        check(!left.contains("anchorassist") && left.contains("First paragraph.") && left.contains("Last words."), "left out when not ticked")
        let kept = JournalBlocks.sharedText(entry, includeAssist: true)
        check(kept.contains("Short & sweet (really)") && kept.contains("not the writer's own words") && !kept.contains("anchorassist"), "labelled when ticked")
    }
}
#endif
