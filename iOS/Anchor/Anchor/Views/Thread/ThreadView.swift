//
//  ThreadView.swift
//  Anchor
//

import SwiftUI
import SwiftData

struct ThreadView: View {
    @AppStorage(TabLayoutStyle.storageKey) private var layoutRaw = TabLayoutStyle.widgets.rawValue

    private var usesWidgets: Bool { layoutRaw != TabLayoutStyle.icons.rawValue }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if usesWidgets {
                        widgetLayout
                    } else {
                        tileLayout
                    }
                }
                .padding(.vertical, 8)
            }
            .anchorBackground()
            .navigationTitle("Thread")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HelpToolbarButton(topic: .thread)
                }
            }
        }
    }

    // Widgets (default). Order and visibility come from the saved layout.
    private var widgetLayout: some View {
        Anchor.WidgetStack(tab: .thread) { id in
            threadWidget(id)
        } more: { id in
            threadMoreTile(id)
        }
        .padding(.horizontal)
    }

    @ViewBuilder private func threadWidget(_ id: WidgetID) -> some View {
        switch id {
        case .messageLog: MessageLogWidget()
        case .supportCalendar: SupportCalendarWidget()
        case .futureNotes: FutureNotesWidget()
        case .unsentDrafts: UnsentDraftsWidget()
        case .boundaries: BoundariesWidget()
        default: EmptyView()
        }
    }

    @ViewBuilder private func threadMoreTile(_ id: WidgetID) -> some View {
        switch id {
        case .messageLog: Anchor.MoreTile(id: id) { ThreadMessagesView() }
        case .supportCalendar: Anchor.MoreTile(id: id) { SupportCalendarView() }
        case .futureNotes: Anchor.MoreTile(id: id) { FutureNoteListView() }
        case .unsentDrafts: Anchor.MoreTile(id: id) { UnsentDraftsView() }
        case .boundaries: Anchor.MoreTile(id: id) { BoundariesView() }
        default: EmptyView()
        }
    }

    // Icons (classic): the original tile rows.
    private var tileLayout: some View {
                // Matches the tile-row dashboard used on Plan and Bridge,
                // rather than a stock settings-style List — Thread's
                // destinations (message log, support calendar, notes to
                // yourself) are places to reach, not configuration to dig
                // through.
        VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Anchor.TileRow(title: "With someone") {
                            NavigationLink { ThreadMessagesView() } label: {
                                Anchor.TileButtonLabel(icon: "bubble.left.and.bubble.right.fill", title: "Message log", tint: Anchor.Theme.accent)
                            }
                            NavigationLink { SupportCalendarView() } label: {
                                Anchor.TileButtonLabel(icon: "calendar.badge.clock", title: "Support calendar", tint: Anchor.Theme.accent)
                            }
                        }
                        Text("Message log is tied to a real contact and can actually send.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Anchor.TileRow(title: "Just for you") {
                            NavigationLink { FutureNoteListView() } label: {
                                Anchor.TileButtonLabel(icon: "envelope.open.badge.clock", title: "To future me", tint: Anchor.Theme.sage)
                            }
                            NavigationLink { UnsentDraftsView() } label: {
                                Anchor.TileButtonLabel(icon: "square.and.pencil", title: "Things I haven't said", tint: Anchor.Theme.sage)
                            }
                            NavigationLink { BoundariesView() } label: {
                                Anchor.TileButtonLabel(icon: "hand.raised.fill", title: "Boundaries", tint: Anchor.Theme.sage)
                            }
                        }
                        Text("\"Things I haven't said\" is for big things you might never send, to anyone.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
    }
}


// MARK: - Boundaries

extension BoundarySection: CustomSectionRecord {}

/// A short list of what the person would like others to know, what helps and
/// what does not, in sections they own. Each section can be marked shareable;
/// Share then hands only those sections to the system share sheet, and only
/// when the person taps it. Nothing is sent or shown to anyone otherwise.
struct BoundariesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BoundarySection.sortOrder) private var sections: [BoundarySection]

    @State private var editing: BoundarySection?
    @State private var lastOpened: BoundarySection?
    @State private var removing: BoundarySection?
    @State private var confirmingRemove: BoundarySection?

    private var shown: [BoundarySection] { sections.filter { !$0.isHidden } }
    private var hidden: [BoundarySection] { sections.filter { $0.isHidden } }
    private var shareText: String { BoundarySection.shareText(from: sections) }

    var body: some View {
        Group {
            if sections.isEmpty {
                emptyBody
            } else {
                listBody
            }
        }
        .anchorBackground()
        .navigationTitle("Boundaries")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !sections.isEmpty {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(shareText.isEmpty)
                    .accessibilityLabel("Share the sections marked Can be shared")
                }
                if shown.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Anchor.AddToolbarButton(label: "Add a section") { addSection() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { section in
            CustomSectionEditor(section: section, onDelete: { removing = section }) {
                Section {
                    Toggle("Can be shared", isOn: Binding(
                        get: { section.isShareable },
                        set: { section.isShareable = $0; section.lastEditedAt = .now }
                    ))
                } footer: {
                    Text("Only sections marked like this go out when you tap Share.")
                }
            }
        }
        .confirmationDialog(
            "Delete this section?",
            isPresented: Binding(get: { confirmingRemove != nil }, set: { if !$0 { confirmingRemove = nil } }),
            titleVisibility: .visible,
            presenting: confirmingRemove
        ) { section in
            Button("Delete section", role: .destructive) { modelContext.delete(section) }
            Button("Keep it", role: .cancel) {}
        } message: { _ in
            Text("What is written in it goes too.")
        }
    }

    private var emptyBody: some View {
        ScrollView {
            VStack(spacing: 12) {
                Anchor.EmptyState(
                    icon: "hand.raised.fill",
                    title: "Nothing here yet",
                    message: "A short list of what you would like people to know, what helps and what does not. Yours to write, and yours to share or keep.",
                    actionTitle: "Start with three headings",
                    tint: Anchor.Theme.sage
                ) { startWithThree() }
                Button("Or add your own section") { addSection() }
                    .font(.footnote)
            }
            .padding()
        }
    }

    private var listBody: some View {
        List {
            ForEach(shown) { section in
                Button {
                    open(section)
                } label: {
                    Anchor.TextCard(
                        icon: section.iconName,
                        title: section.title.isEmpty ? "Untitled" : section.title,
                        text: section.text,
                        tint: SectionTint.named(section.tintName).color
                    )
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 6) {
                            if section.isShareable {
                                Image(systemName: "square.and.arrow.up")
                                    .accessibilityLabel("Can be shared")
                            }
                            Image(systemName: "pencil")
                        }
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(14)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the editor")
                .swipeActions(edge: .leading) {
                    Button {
                        section.isHidden = true
                        section.lastEditedAt = .now
                    } label: {
                        Label("Hide", systemImage: "eye.slash")
                    }
                    .tint(.gray)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        confirmingRemove = section
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .anchorCardRow()
            }
            .onMove(perform: move)

            if !hidden.isEmpty {
                Section {
                    ForEach(hidden) { section in
                        Button {
                            show(section)
                        } label: {
                            Label(section.title.isEmpty ? "Untitled" : section.title, systemImage: "plus.circle")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityHint("Shows this section again")
                    }
                } header: {
                    Text("Hidden")
                }
                .listRowBackground(Color.clear)
            }

            if shareText.isEmpty {
                Text("To share some of this, open a section and turn on Can be shared.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }

    private func open(_ section: BoundarySection) {
        lastOpened = section
        editing = section
    }

    private func nextOrder() -> Int {
        (sections.map(\.sortOrder).max() ?? -1) + 1
    }

    private func addSection() {
        let new = BoundarySection(sortOrder: nextOrder())
        modelContext.insert(new)
        open(new)
    }

    private func startWithThree() {
        for section in BoundarySection.startingSections() { modelContext.insert(section) }
    }

    private func show(_ section: BoundarySection) {
        section.isHidden = false
        section.sortOrder = nextOrder()
        section.lastEditedAt = .now
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = shown
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, section) in (reordered + hidden).enumerated() { section.sortOrder = index }
    }

    /// Runs once the editor has closed, so a sheet never reads a section that
    /// is already gone. A section added and left blank is dropped.
    private func finishEditing() {
        let deleting = removing
        removing = nil
        let opened = lastOpened
        lastOpened = nil
        if let deleting {
            modelContext.delete(deleting)
        } else if let opened, opened.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  opened.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(opened)
        }
    }
}
