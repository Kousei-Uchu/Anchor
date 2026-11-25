//
//  SafetyPlanEditorView.swift
//  Anchor
//
//  The safety plan as a list of sections you own. Each section is a card with
//  a title, your own words, an icon and a colour. Tap a card to change it, use
//  the plus to add one, hide one you do not want to see (it keeps its words),
//  reorder with the labelled button, and delete from inside a section or by
//  swiping. There is no Edit button and no separate form.
//
//  The pieces below the plan screen (`CustomSectionRecord`, `CustomSectionStyle`
//  and `CustomSectionEditor`) do not know anything about the safety plan, so
//  the Boundaries list and Person pages can use the same editor with their
//  own model.
//

import SwiftUI
import SwiftData

// MARK: - Reusable sections

/// What the shared section editor needs from a model. Any class that keeps a
/// title, some text, an icon, a colour name and a hidden flag can use it.
protocol CustomSectionRecord: AnyObject, Observable {
    var title: String { get set }
    var text: String { get set }
    var iconName: String { get set }
    var tintName: String { get set }
    var isHidden: Bool { get set }
    var lastEditedAt: Date { get set }
}

extension SafetyPlanSection: CustomSectionRecord {}

/// The colours a section can have, stored by name.
enum SectionTint: String, CaseIterable, Identifiable {
    case accent, sage, sky, amber, lilac, rose, stone

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .accent: return Anchor.Theme.accent
        case .sage: return Anchor.Theme.sage
        case .sky: return Color(red: 0.30, green: 0.60, blue: 0.88)
        case .amber: return Color(red: 0.93, green: 0.66, blue: 0.20)
        case .lilac: return Color(red: 0.62, green: 0.48, blue: 0.85)
        case .rose: return Color(red: 0.86, green: 0.40, blue: 0.48)
        case .stone: return Color.gray
        }
    }

    static func named(_ name: String) -> SectionTint {
        SectionTint(rawValue: name) ?? .sage
    }
}

enum CustomSectionStyle {
    struct Icon: Identifiable {
        let symbol: String
        let name: String
        var id: String { symbol }
    }

    static let icons: [Icon] = [
        Icon(symbol: "doc.text.fill", name: "Page"),
        Icon(symbol: "exclamationmark.triangle.fill", name: "Warning"),
        Icon(symbol: "leaf.fill", name: "Leaf"),
        Icon(symbol: "heart.fill", name: "Heart"),
        Icon(symbol: "house.fill", name: "Home"),
        Icon(symbol: "star.fill", name: "Star"),
        Icon(symbol: "person.2.fill", name: "People"),
        Icon(symbol: "phone.fill", name: "Phone"),
        Icon(symbol: "lightbulb.fill", name: "Idea"),
        Icon(symbol: "moon.fill", name: "Moon"),
        Icon(symbol: "sun.max.fill", name: "Sun"),
        Icon(symbol: "hand.raised.fill", name: "Hand"),
        Icon(symbol: "book.fill", name: "Book"),
        Icon(symbol: "music.note", name: "Music"),
        Icon(symbol: "figure.walk", name: "Walk"),
        Icon(symbol: "cup.and.saucer.fill", name: "Cup"),
        Icon(symbol: "shield.fill", name: "Shield"),
        Icon(symbol: "cross.case.fill", name: "First aid"),
        Icon(symbol: "bandage.fill", name: "Care"),
        Icon(symbol: "bubble.left.fill", name: "Talk"),
        Icon(symbol: "message.fill", name: "Message"),
        Icon(symbol: "envelope.fill", name: "Letter"),
        Icon(symbol: "bell.fill", name: "Bell"),
        Icon(symbol: "clock.fill", name: "Time"),
        Icon(symbol: "calendar", name: "Calendar"),
        Icon(symbol: "map.fill", name: "Map"),
        Icon(symbol: "location.fill", name: "Place"),
        Icon(symbol: "car.fill", name: "Car"),
        Icon(symbol: "bed.double.fill", name: "Bed"),
        Icon(symbol: "bolt.fill", name: "Energy"),
        Icon(symbol: "flame.fill", name: "Flame"),
        Icon(symbol: "drop.fill", name: "Water"),
        Icon(symbol: "wind", name: "Breath"),
        Icon(symbol: "cloud.fill", name: "Cloud"),
        Icon(symbol: "tree.fill", name: "Tree"),
        Icon(symbol: "pawprint.fill", name: "Pet"),
        Icon(symbol: "fork.knife", name: "Food"),
        Icon(symbol: "pills.fill", name: "Medicine"),
        Icon(symbol: "stethoscope", name: "Doctor"),
        Icon(symbol: "brain.head.profile", name: "Mind"),
        Icon(symbol: "figure.mind.and.body", name: "Calm"),
        Icon(symbol: "hands.sparkles.fill", name: "Care hands"),
        Icon(symbol: "lock.fill", name: "Lock"),
        Icon(symbol: "key.fill", name: "Key"),
        Icon(symbol: "flag.fill", name: "Flag"),
        Icon(symbol: "target", name: "Goal"),
        Icon(symbol: "list.bullet", name: "List"),
        Icon(symbol: "checkmark.circle.fill", name: "Done"),
        Icon(symbol: "pencil", name: "Write"),
        Icon(symbol: "camera.fill", name: "Photo"),
        Icon(symbol: "headphones", name: "Listen"),
        Icon(symbol: "paintbrush.fill", name: "Create"),
        Icon(symbol: "gamecontroller.fill", name: "Play"),
        Icon(symbol: "globe", name: "World")
    ]
}

/// One section in one sheet: its name, its words, how it looks, and whether it
/// shows. Delete sits under the form and asks first. Anything specific to a
/// screen goes in `extra`, as more rows in the form.
struct CustomSectionEditor<S: CustomSectionRecord, Extra: View>: View {
    let section: S
    var deleteQuestion: String = "Delete this section? What is written in it goes too."
    var onDelete: () -> Void
    @ViewBuilder var extra: () -> Extra

    private func edited<V>(_ get: @escaping () -> V, _ set: @escaping (V) -> Void) -> Binding<V> {
        Binding(get: get, set: { newValue in
            set(newValue)
            section.lastEditedAt = .now
        })
    }

    var body: some View {
        Anchor.ItemEditorSheet(
            title: section.title.isEmpty ? "New section" : section.title,
            onDelete: onDelete,
            deleteTitle: "Delete section",
            deleteQuestion: deleteQuestion
        ) {
            Form {
                Section("Name") {
                    TextField("Name this section", text: edited({ section.title }, { section.title = $0 }))
                }
                Section {
                    TextEditor(text: edited({ section.text }, { section.text = $0 }))
                        .frame(minHeight: 200)
                }
                Section("Look") {
                    Picker("Icon", selection: edited({ section.iconName }, { section.iconName = $0 })) {
                        ForEach(CustomSectionStyle.icons) { icon in
                            Label(icon.name, systemImage: icon.symbol).tag(icon.symbol)
                        }
                    }
                    Picker("Colour", selection: edited({ section.tintName }, { section.tintName = $0 })) {
                        ForEach(SectionTint.allCases) { tint in
                            Text(tint.name).tag(tint.rawValue)
                        }
                    }
                }
                Section {
                    Toggle("Show this section", isOn: edited({ !section.isHidden }, { section.isHidden = !$0 }))
                }
                extra()
            }
        }
    }
}

// MARK: - The safety plan

/// The safety plan as something to read: calm cards, in your order. Tap one
/// to change it.
struct SafetyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SafetyPlanSection.sortOrder) private var sections: [SafetyPlanSection]

    @State private var editing: SafetyPlanSection?
    @State private var lastOpened: SafetyPlanSection?
    @State private var removing: SafetyPlanSection?
    @State private var confirmingRemove: SafetyPlanSection?

    /// Sections that are not under another one that still exists. A section whose parent is gone shows as its own card.
    private var topLevel: [SafetyPlanSection] {
        let ids = Set(sections.map(\.id))
        return sections.filter { $0.parentID == nil || !ids.contains($0.parentID!) }
    }
    private var shown: [SafetyPlanSection] { topLevel.filter { !$0.isHidden } }
    private var hidden: [SafetyPlanSection] { sections.filter { $0.isHidden } }

    /// What sits directly under a section, in order, leaving out hidden ones.
    private func shownChildren(of parent: SafetyPlanSection) -> [SafetyPlanSection] {
        sections.filter { $0.parentID == parent.id && !$0.isHidden }
    }

    /// Everything under a section, at any depth.
    private func descendants(of parent: SafetyPlanSection) -> [SafetyPlanSection] {
        let direct = sections.filter { $0.parentID == parent.id }
        return direct + direct.flatMap { descendants(of: $0) }
    }

    /// How many levels a section is down: 0 for a card of its own.
    private func depth(of section: SafetyPlanSection) -> Int {
        var depth = 0
        var current = section
        while let parentID = current.parentID, let parent = sections.first(where: { $0.id == parentID }), depth < 10 {
            depth += 1
            current = parent
        }
        return depth
    }

    /// Where a section can go: not itself, not anything under it, and no deeper than a sub-subheading.
    private func parentChoices(for section: SafetyPlanSection) -> [SafetyPlanSection] {
        let blocked = Set(descendants(of: section).map(\.id) + [section.id])
        return sections.filter { !blocked.contains($0.id) && depth(of: $0) < 2 }
    }

    /// True when no shown section is marked for reminder quotes, which also
    /// covers the marked one being hidden or deleted.
    private var quotesAreOff: Bool {
        !sections.contains { $0.role == SafetyPlanSection.reasonsRole && !$0.isHidden }
    }

    var body: some View {
        Group {
            if sections.isEmpty {
                emptyBody
            } else {
                listBody
            }
        }
        .anchorBackground()
        .navigationTitle("Safety plan")
        .guideButton("plan.safety-plan", tab: .plan)
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
            CustomSectionEditor(
                section: section,
                deleteQuestion: deleteQuestion(for: section),
                onDelete: { removing = section }
            ) {
                Section("Subtitle") {
                    TextField("A line under the title (optional)", text: Binding(
                        get: { section.subtitle },
                        set: { section.subtitle = $0; section.lastEditedAt = .now }
                    ))
                }
                Section {
                    Picker("Sits under", selection: Binding(
                        get: { section.parentID },
                        set: { section.parentID = $0; section.lastEditedAt = .now }
                    )) {
                        Text("Nothing: its own card").tag(UUID?.none)
                        ForEach(parentChoices(for: section)) { choice in
                            Text(choice.title.isEmpty ? "Untitled" : choice.title).tag(Optional(choice.id))
                        }
                    }
                } footer: {
                    Text("Put this under another section to show it as a subheading inside that card.")
                }
                Section {
                    Toggle("Use this for reminder quotes", isOn: Binding(
                        get: { section.role == SafetyPlanSection.reasonsRole },
                        set: { setQuoteSource(section, $0) }
                    ))
                } footer: {
                    Text("Trigger window reminders can quote a line from here. Always your own words.")
                }
            }
        }
        .confirmationDialog(
            "Delete this section?",
            isPresented: Binding(get: { confirmingRemove != nil }, set: { if !$0 { confirmingRemove = nil } }),
            titleVisibility: .visible,
            presenting: confirmingRemove
        ) { section in
            Button("Delete section", role: .destructive) {
                deleteWithChildren(section)
                syncReminders()
            }
            Button("Keep it", role: .cancel) {}
        } message: { section in
            Text(deleteQuestion(for: section))
        }
    }

    // MARK: Screens

    private var emptyBody: some View {
        ScrollView {
            VStack(spacing: 12) {
                Anchor.EmptyState(
                    icon: "shield.fill",
                    title: "Your safety plan is empty",
                    message: "Write it once while you're calm, and it'll be here, ready to read, when you need it.",
                    actionTitle: "Start with four sections",
                    tint: Anchor.Theme.accent
                ) { startWithFour() }
                Button("Or add your own section") { addSection() }
                    .font(.footnote)
            }
            .padding()
        }
    }

    private var listBody: some View {
        List {
            ForEach(shown) { section in
                SafetyPlanCardView(
                    section: section,
                    childrenOf: { shownChildren(of: $0) },
                    onOpen: { open($0) }
                )
                .contextMenu {
                    Button {
                        addSubheading(under: section)
                    } label: {
                        Label("Add a subheading", systemImage: "text.append")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        section.isHidden = true
                        section.lastEditedAt = .now
                        syncReminders()
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

            VStack(spacing: 6) {
                if quotesAreOff {
                    Text("Reminder quotes are off. Open a section and turn on Use this for reminder quotes.")
                        .multilineTextAlignment(.center)
                }
                if let latest = sections.map(\.lastEditedAt).max() {
                    Text("Last updated \(latest.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    // MARK: Actions

    private func open(_ section: SafetyPlanSection) {
        lastOpened = section
        editing = section
    }

    private func nextOrder() -> Int {
        (sections.map(\.sortOrder).max() ?? -1) + 1
    }

    private func addSection() {
        let new = SafetyPlanSection(sortOrder: nextOrder())
        modelContext.insert(new)
        open(new)
    }

    /// A new section that sits under another, shown as a subheading inside its card.
    private func addSubheading(under parent: SafetyPlanSection) {
        let new = SafetyPlanSection(iconName: parent.iconName, tintName: parent.tintName,
                                    sortOrder: nextOrder(), parentID: parent.id)
        modelContext.insert(new)
        open(new)
    }

    /// A section goes with everything that sits under it.
    private func deleteWithChildren(_ section: SafetyPlanSection) {
        for child in descendants(of: section) { modelContext.delete(child) }
        modelContext.delete(section)
    }

    private func startWithFour() {
        for section in SafetyPlanSections.makeSections() { modelContext.insert(section) }
    }

    private func show(_ section: SafetyPlanSection) {
        section.isHidden = false
        section.sortOrder = nextOrder()
        section.lastEditedAt = .now
        syncReminders()
    }

    /// Reordering moves the shown sections; hidden ones stay after them.
    private func move(from offsets: IndexSet, to destination: Int) {
        var reordered = shown
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, section) in (reordered + hidden).enumerated() { section.sortOrder = index }
    }

    /// Only one section can be the source of reminder quotes, so choosing one
    /// clears the mark from the others.
    private func setQuoteSource(_ section: SafetyPlanSection, _ on: Bool) {
        if on {
            for other in sections where other.role == SafetyPlanSection.reasonsRole { other.role = "" }
            section.role = SafetyPlanSection.reasonsRole
        } else {
            section.role = ""
        }
        section.lastEditedAt = .now
    }

    private func deleteQuestion(for section: SafetyPlanSection) -> String {
        let under = descendants(of: section).isEmpty ? "" : " Everything under it goes too."
        if section.role == SafetyPlanSection.reasonsRole {
            return "Delete this section? What is written in it goes too, and reminder quotes will be off until you choose another section." + under
        }
        return "Delete this section? What is written in it goes too." + under
    }

    /// Runs once the editor has closed, so a sheet never reads a section that
    /// is already gone. A section added and left with no name and no words is
    /// dropped.
    private func finishEditing() {
        let deleting = removing
        removing = nil
        let opened = lastOpened
        lastOpened = nil
        if let deleting {
            deleteWithChildren(deleting)
        } else if let opened, opened.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  opened.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  opened.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            modelContext.delete(opened)
        }
        syncReminders()
    }

    /// Reminder quotes come from one section, so any change to which one
    /// (or to what it says) is passed on to the scheduled reminders.
    private func syncReminders() {
        NotificationScheduler.resyncTriggerWindows(using: modelContext)
    }
}


/// One section as a card: its heading, subtitle and words, then anything that sits under it as subheadings, each with its
/// own subtitle and words, to any depth. Tap the heading area of any of them to change that one.
struct SafetyPlanCardView: View {
    let section: SafetyPlanSection
    let childrenOf: (SafetyPlanSection) -> [SafetyPlanSection]
    let onOpen: (SafetyPlanSection) -> Void

    var body: some View {
        let tint = SectionTint.named(section.tintName).color
        Anchor.Card(accentColor: tint) {
            SafetyPlanBlockView(section: section, depth: 0, tint: tint, childrenOf: childrenOf, onOpen: onOpen)
        }
    }
}

private struct SafetyPlanBlockView: View {
    let section: SafetyPlanSection
    let depth: Int
    let tint: Color
    let childrenOf: (SafetyPlanSection) -> [SafetyPlanSection]
    let onOpen: (SafetyPlanSection) -> Void

    var body: some View {
        let children = childrenOf(section)
        let words = section.text.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: 10) {
            Button { onOpen(section) } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        if depth == 0 {
                            Anchor.SectionHeader(icon: section.iconName, title: section.title.isEmpty ? "Untitled" : section.title, tint: tint)
                        } else {
                            Label(section.title.isEmpty ? "Untitled" : section.title, systemImage: section.iconName)
                                .font(.system(depth == 1 ? .subheadline : .footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(tint)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "pencil")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    if !section.subtitle.isEmpty {
                        Text(section.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !words.isEmpty {
                        Text(words)
                            .font(.system(depth == 0 ? .body : .subheadline, design: .rounded))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if depth == 0 && children.isEmpty {
                        Text("Nothing added yet.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the editor")

            ForEach(children) { child in
                AnyView(
                    SafetyPlanBlockView(section: child, depth: depth + 1, tint: tint, childrenOf: childrenOf, onOpen: onOpen)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(tint.opacity(0.35)).frame(width: 2)
                        }
                )
            }
        }
    }
}
