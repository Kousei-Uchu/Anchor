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
        Icon(symbol: "cup.and.saucer.fill", name: "Cup")
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

    private var shown: [SafetyPlanSection] { sections.filter { !$0.isHidden } }
    private var hidden: [SafetyPlanSection] { sections.filter { $0.isHidden } }

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
                modelContext.delete(section)
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
        if section.role == SafetyPlanSection.reasonsRole {
            return "Delete this section? What is written in it goes too, and reminder quotes will be off until you choose another section."
        }
        return "Delete this section? What is written in it goes too."
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
            modelContext.delete(deleting)
        } else if let opened, opened.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  opened.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
