//
//  JournalVoice.swift
//  Anchor
//
//  The Voice note block (Patch VN2, docs/OPTIONAL_FEATURES.md, E2). A voice note kept while dictating sits in
//  the entry as one Markdown line, like a card or an AI Optimised block, so there is no model change. The line
//  holds only the name of the file; the sound itself is in the same folder as the voice notes on messages and
//  is locked, backed up and removed with them. An older build, or any Markdown reader, shows the line as plain
//  text and loses nothing.
//

import SwiftUI

/// The name of the voice note file a Journal entry carries.
struct JournalVoice: Equatable {
    var file: String

    static let label = "Voice note"
    private static let opening = "[\(label)](anchorvoice://v1?"

    private static let unreserved: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    /// The single Markdown line this block is stored as.
    var markdownLine: String {
        Self.opening + "f=\(file.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? ""))"
    }

    /// Reads a block back from a line, or nil when the line is anything else.
    init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(Self.opening), trimmed.hasSuffix(")") else { return nil }
        let query = trimmed.dropFirst(Self.opening.count).dropLast()
        for pair in query.split(separator: "&") {
            let keyValue = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard keyValue.count == 2, keyValue[0] == "f" else { continue }
            let name = String(keyValue[1]).removingPercentEncoding ?? ""
            // A file name only: nothing that could point outside the voice notes folder.
            guard !name.isEmpty, !name.contains("/"), !name.contains("..") else { return nil }
            self.file = name
            return
        }
        return nil
    }

    init(file: String) {
        self.file = file
    }

    static func isBlockLine(_ line: String) -> Bool {
        line.contains("](anchorvoice://")
    }
}

/// What the Journal editor remembers while the person chooses what to keep after a go of Dictate that also
/// kept a voice note. Nothing is applied until a button is tapped, and doing nothing keeps both.
struct DictationKeep: Equatable {
    let voiceBlockID: UUID
    let paragraphID: UUID
    /// What the paragraph held before dictating, and what dictating left in it.
    let base: String
    let written: String
}

extension JournalBlocks {
    /// The voice note files an entry carries.
    static func voiceNames(in text: String) -> [String] {
        parse(text).compactMap { block in
            if case .voice(let voice) = block.kind { return voice.file }
            return nil
        }
    }

    /// Removes the files of every voice note in an entry. Used when the entry itself is deleted.
    static func deleteVoiceFiles(in text: String) {
        for name in voiceNames(in: text) { VoiceNoteStore.delete(name) }
    }
}

/// A block on the page with Play and the length, in the look of the other blocks.
struct JournalVoiceView: View {
    let voice: JournalVoice
    /// Room on the right for the block's menu button while editing.
    var reserveMenuSpace: Bool = false
    @StateObject private var player = VoiceNotePlayer()
    @Environment(\.colorScheme) private var colorScheme

    private let tint = Anchor.Theme.accent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(JournalVoice.label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                VoiceNoteRow(fileName: voice.file, player: player)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .padding(.trailing, reserveMenuSpace ? 26 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Anchor.Theme.cardBackground(colorScheme), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.25), lineWidth: 1))
        .onDisappear { player.stop() }
    }
}

#if DEBUG
/// Checks, in a test build, that a Voice note block survives being stored: the name round trips through the
/// line, an entry with the block in it serialises back to exactly what was read, an older reader leaves the
/// line alone, a name that tries to leave the folder is refused, and a voice note alone never stands for an
/// entry in a list.
enum JournalVoiceSelfTest {
    private static var hasRun = false

    private static func check(_ condition: Bool, _ message: String) {
        if !condition { fatalError("Voice note block self-test: \(message)") }
    }

    static func run() {
        if hasRun { return }
        hasRun = true
        let voice = JournalVoice(file: "6F1E7C52-9C1A-4E27-8B53-0D2F4E9A1B77.m4a")
        let line = voice.markdownLine
        check(!line.contains("\n"), "the line must stay one line")
        check(JournalVoice(line: line) == voice, "the block must read back exactly")
        check(JournalCard(line: line) == nil, "an older reader must not take it for a card")
        check(JournalAssist(line: line) == nil, "it is not an AI Optimised block")
        check(JournalBlocks.imageName(in: line) == nil, "it is not a photo line")
        check(JournalVoice(line: "[Voice note](anchorvoice://v1?f=..%2Fsecret.m4a)") == nil, "a name outside the folder is refused")

        let entry = "First paragraph.\n" + line + "\n![](photo.jpg)\nLast words."
        let blocks = JournalBlocks.parse(entry)
        check(blocks.count == 4, "text, voice note, photo, text")
        check(JournalBlocks.serialize(blocks) == entry, "the entry must serialise back exactly")
        check(JournalBlocks.voiceNames(in: entry) == [voice.file], "the file name is found")
        check(JournalBlocks.previewLine(entry) == "First paragraph.", "the preview uses the writer's words")
        check(JournalBlocks.previewLine(line) == "Voice note", "a voice note alone is named, not shown as words")
        let shared = JournalBlocks.sharedText(entry, includeAssist: false)
        check(!shared.contains("anchorvoice") && shared.contains("First paragraph."), "left out of what is handed to someone")
    }
}
#endif
