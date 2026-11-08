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
        case .people: PeopleWidget()
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
        case .people: Anchor.MoreTile(id: id) { PeopleView() }
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
                            NavigationLink { PeopleView() } label: {
                                Anchor.TileButtonLabel(icon: "person.crop.circle.fill", title: "People", tint: Anchor.Theme.accent)
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
                    .hiddenInShowcase()
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

// MARK: - People

extension PersonSection: CustomSectionRecord {}

private extension TrustedContact {
    /// Never empty, so a person added without a name still has a page to open.
    var pageName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Someone" : trimmed
    }
}

/// Everyone in Contacts, each with a page of their own. The list adds no one:
/// people come from Contacts in Plan. A page with nothing on it is just empty.
struct PeopleView: View {
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]
    @Query(sort: \PersonSection.sortOrder) private var sections: [PersonSection]

    /// The first words on a person's page, so a row says something.
    private func glance(for contact: TrustedContact) -> String? {
        for section in sections where section.contactID == contact.id && !section.isHidden {
            if let line = SafetyPlanSections.firstLine(section.text) { return line }
        }
        return nil
    }

    var body: some View {
        Group {
            if contacts.isEmpty {
                ScrollView {
                    Anchor.EmptyState(
                        icon: "person.2.fill",
                        title: "No one here yet",
                        message: "People you add under Contacts in Plan appear here, each with a page of their own.",
                        tint: Anchor.Theme.accent
                    )
                    .padding()
                }
            } else {
                List {
                    ForEach(contacts) { contact in
                        NavigationLink {
                            PersonPageView(contact: contact)
                        } label: {
                            Anchor.Card(accentColor: Anchor.Theme.accent) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Anchor.Theme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.pageName)
                                            .font(.system(.headline, design: .rounded))
                                        if let line = glance(for: contact) {
                                            Text(line)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .anchorCardRow()
                    }
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One person's page. Sections of your own at the top (you add, rename,
/// reorder, hide and delete them, the way the safety plan works), then the
/// last few messages in your log with them, then the support calendar days
/// you have shared with them. Nothing is counted, scored or inferred, and
/// nothing is sent to them from here.
struct PersonPageView: View {
    let contact: TrustedContact

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PersonSection.sortOrder) private var allSections: [PersonSection]
    @Query(sort: \ThreadMessage.timestamp, order: .reverse) private var allMessages: [ThreadMessage]
    @Query(sort: \SupportCalendarEntry.date) private var allEntries: [SupportCalendarEntry]

    @State private var editing: PersonSection?
    @State private var lastOpened: PersonSection?
    @State private var justAddedID: UUID?
    @State private var removing: PersonSection?
    @State private var confirmingRemove: PersonSection?

    private static let noteTitle = "Notes"

    private var sections: [PersonSection] { allSections.filter { $0.contactID == contact.id } }
    private var shown: [PersonSection] { sections.filter { !$0.isHidden } }
    private var hidden: [PersonSection] { sections.filter { $0.isHidden } }

    /// The last three messages with them, newest first.
    private var messages: [ThreadMessage] {
        Array(allMessages.filter { $0.withContactID == contact.id }.prefix(3))
    }

    /// Calendar days they can see: the ones still to come first, soonest
    /// first, then the most recent past ones, three at most.
    private var sharedEntries: [SupportCalendarEntry] {
        let mine = allEntries.filter { $0.visibleToContactIDs.contains(contact.id) }
        let today = Calendar.current.startOfDay(for: .now)
        let upcoming = mine.filter { $0.date >= today }
        let past = Array(mine.filter { $0.date < today }.reversed())
        return Array((upcoming + past).prefix(3))
    }

    var body: some View {
        List {
            if sections.isEmpty {
                Anchor.EmptyState(
                    icon: "person.text.rectangle.fill",
                    title: "Nothing written about \(contact.pageName) yet",
                    message: "Notes, what helps, things you have told them. Whatever you want to keep.",
                    actionTitle: "Add a note",
                    tint: Anchor.Theme.sage
                ) { addSection(title: Self.noteTitle) }
                .anchorCardRow()
            }

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
                        Image(systemName: "pencil")
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

            Section {
                if messages.isEmpty {
                    Text("Nothing in your message log with them yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(messages) { message in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preview(of: message))
                            .font(.system(.subheadline, design: .rounded))
                            .lineLimit(2)
                        Text(message.timestamp.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink("Open the message log") {
                    ThreadMessagesView(startingWith: contact.id)
                }
            } header: {
                Text("Messages")
            }
            .listRowBackground(Color.clear)

            Section {
                if sharedEntries.isEmpty {
                    Text("Nothing on your support calendar is shared with them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(sharedEntries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SafetyPlanSections.firstLine(entry.note) ?? "A support day")
                            .font(.system(.subheadline, design: .rounded))
                            .lineLimit(2)
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                NavigationLink("Open the support calendar") {
                    SupportCalendarView()
                }
            } header: {
                Text("Shared with \(contact.pageName)")
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .anchorBackground()
        .navigationTitle(contact.pageName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if shown.count > 1 {
                    Anchor.ReorderToolbarButton()
                }
                Anchor.AddToolbarButton(label: "Add a section") { addSection() }
            }
        }
        .sheet(item: $editing, onDismiss: finishEditing) { section in
            CustomSectionEditor(section: section, onDelete: { removing = section }) {
                EmptyView()
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

    private func preview(of message: ThreadMessage) -> String {
        let words = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !words.isEmpty { return words }
        return message.audioFileName == nil ? "Empty message" : "Voice note"
    }

    private func open(_ section: PersonSection) {
        lastOpened = section
        editing = section
    }

    private func nextOrder() -> Int {
        (sections.map(\.sortOrder).max() ?? -1) + 1
    }

    private func addSection(title: String = "") {
        let new = PersonSection(contactID: contact.id, title: title, sortOrder: nextOrder())
        modelContext.insert(new)
        justAddedID = new.id
        open(new)
    }

    private func show(_ section: PersonSection) {
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
    /// is already gone. A section just added and left with no words is dropped,
    /// including one that only got the suggested "Notes" name.
    private func finishEditing() {
        let deleting = removing
        removing = nil
        let opened = lastOpened
        lastOpened = nil
        let addedID = justAddedID
        justAddedID = nil
        if let deleting {
            modelContext.delete(deleting)
        } else if let opened {
            let title = opened.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let noWords = opened.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let onlySuggestedName = opened.id == addedID && title == Self.noteTitle
            if noWords && (title.isEmpty || onlySuggestedName) {
                modelContext.delete(opened)
            }
        }
    }
}
