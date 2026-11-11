//
//  TabWidgets.swift
//  Anchor
//
//  Widget building blocks for Plan, Bridge and Thread. Those tabs used to be
//  rows of icon tiles (an "app browser"); by default they are now widgets that
//  show live content you can use in place, like Now. The tile layout is kept
//  as the "Icons" option in Settings > Layout.
//
//  Every widget has a stable `id` (see `WidgetID`) so a later "Customise
//  widgets" phase can reorder/hide them per tab without reworking these views.
//

import SwiftUI
import SwiftData

/// Which layout Plan, Bridge and Thread use. Stored in `@AppStorage`.
enum TabLayoutStyle: String {
    case widgets
    case icons

    static let storageKey = "tabLayoutStyle"
}

/// Stable identifiers for every widget, grouped by tab. These are what the
/// saved order and the hidden set refer to (see WidgetCustomisation.swift),
/// so never rename a case once shipped.
enum WidgetID: String, CaseIterable, Identifiable {
    // Plan
    case safetyPlan, triggerWindows, appointments, contacts, deEscalation
    case grounding, decisionPresets, affirmations, recovery, motivations, tasks, sleep
    // Bridge
    case thingsToRaise, nextSession, reframing, feedbackLoops, nswLaw, personalGoals
    // Thread
    case messageLog, supportCalendar, futureNotes, unsentDrafts, boundaries, people
}

extension WidgetID {
    var id: String { rawValue }

    /// Half-width widgets sit two across when adjacent; a lone one goes full width.
    var isHalf: Bool {
        // Long titles ("Who I'm doing this for") would be squeezed in a half-width
        // card, so they always get the full width.
        guard title.count <= 16 else { return false }
        switch self {
        case .triggerWindows, .appointments, .recovery, .motivations, .sleep,
             .reframing, .feedbackLoops, .futureNotes, .unsentDrafts:
            return true
        default:
            return false
        }
    }

    var title: String {
        switch self {
        case .safetyPlan: return "Safety plan"
        case .triggerWindows: return "Trigger windows"
        case .appointments: return "Appointments"
        case .contacts: return "Contacts"
        case .deEscalation: return "De-escalation"
        case .grounding: return "Grounding tools"
        case .decisionPresets: return "Decision presets"
        case .affirmations: return "Affirmations"
        case .recovery: return "Recovery"
        case .motivations: return "Who I'm doing this for"
        case .tasks: return "Tasks"
        case .sleep: return "Sleep"
        case .thingsToRaise: return "Things to raise"
        case .nextSession: return "Next session"
        case .reframing: return "Reframing"
        case .feedbackLoops: return "Feedback loops"
        case .nswLaw: return "NSW mental health law"
        case .messageLog: return "Message log"
        case .supportCalendar: return "Support calendar"
        case .futureNotes: return "To future me"
        case .unsentDrafts: return "Things I haven't said"
        case .boundaries: return "Boundaries"
        case .personalGoals: return "Personal goals"
        case .people: return "People"
        }
    }

    var icon: String {
        switch self {
        case .safetyPlan: return "shield.fill"
        case .triggerWindows: return "clock.fill"
        case .appointments: return "calendar"
        case .contacts: return "person.2.fill"
        case .deEscalation: return "wind"
        case .grounding: return "leaf.fill"
        case .decisionPresets: return "checklist"
        case .affirmations: return "sparkles"
        case .recovery: return "calendar.badge.checkmark"
        case .motivations: return "heart.fill"
        case .tasks: return "checkmark.circle.fill"
        case .sleep: return "moon.zzz.fill"
        case .thingsToRaise: return "doc.text.fill"
        case .nextSession: return "calendar.badge.clock"
        case .reframing: return "arrow.triangle.2.circlepath"
        case .feedbackLoops: return "point.3.connected.trianglepath.dotted"
        case .nswLaw: return "building.columns.fill"
        case .messageLog: return "bubble.left.and.bubble.right.fill"
        case .supportCalendar: return "calendar.badge.clock"
        case .futureNotes: return "envelope.open.badge.clock"
        case .unsentDrafts: return "square.and.pencil"
        case .boundaries: return "hand.raised.fill"
        case .personalGoals: return "flag.fill"
        case .people: return "person.crop.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .triggerWindows, .appointments, .deEscalation, .grounding, .recovery,
             .reframing, .feedbackLoops, .futureNotes, .unsentDrafts, .boundaries, .personalGoals:
            return Anchor.Theme.sage
        default:
            return Anchor.Theme.accent
        }
    }
}


extension Anchor {
    /// A widget: a card whose header and body open a detail screen when
    /// tapped anywhere, with an optional footer of buttons/controls that act
    /// in place. The footer sits outside the tappable area so its buttons
    /// never compete with the card's own navigation.
    struct Widget<Destination: View, Content: View, Footer: View>: View {
        let icon: String
        let title: String
        var tint: Color = Theme.accent
        var fillsHeight = false
        @ViewBuilder var destination: () -> Destination
        @ViewBuilder var content: () -> Content
        @ViewBuilder var footer: () -> Footer

        var body: some View {
            Card(accentColor: tint, fillsHeight: fillsHeight) {
                VStack(alignment: .leading, spacing: 10) {
                    NavigationLink {
                        destination()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(tint.opacity(0.16)).frame(width: 26, height: 26)
                                    Image(systemName: icon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(tint)
                                }
                                Text(title)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.7)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            content()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    footer()
                }
            }
        }
    }

    /// Two half-width widgets side by side, matched to the same height.
    struct WidgetPair<Left: View, Right: View>: View {
        @ViewBuilder var left: () -> Left
        @ViewBuilder var right: () -> Right

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                left().frame(maxWidth: .infinity)
                right().frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Shared text styles so widget bodies look alike.
    struct WidgetBig: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    struct WidgetCaption: View {
        let text: String
        var lines = 3
        var body: some View {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(lines)
                .minimumScaleFactor(0.9)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension Anchor.Widget where Footer == EmptyView {
    init(
        icon: String,
        title: String,
        tint: Color = Anchor.Theme.accent,
        fillsHeight: Bool = false,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.tint = tint
        self.fillsHeight = fillsHeight
        self.destination = destination
        self.content = content
        self.footer = { EmptyView() }
    }
}

// MARK: - Plan widgets

struct SafetyPlanWidget: View {
    @Query(sort: \SafetyPlanSection.sortOrder) private var sections: [SafetyPlanSection]

    /// The first two shown sections that have something written in them, each
    /// with its first line.
    private var glance: [(title: String, line: String)] {
        let found = sections.filter { !$0.isHidden }.compactMap { section -> (title: String, line: String)? in
            guard let line = SafetyPlanSections.firstLine(section.text) else { return nil }
            return (section.title.isEmpty ? "Untitled" : section.title, line)
        }
        return Array(found.prefix(2))
    }

    var body: some View {
        let lines = glance
        Anchor.Widget(icon: "shield.fill", title: "Safety plan") {
            SafetyPlanView()
        } content: {
            if lines.isEmpty {
                Anchor.WidgetCaption(text: "Not filled in yet. Tap to write yours.")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.caption2).foregroundStyle(.secondary)
                            Text(item.line).font(.system(.subheadline, design: .rounded)).lineLimit(2)
                        }
                    }
                }
            }
        } footer: {
            NavigationLink { SafetyPlanView() } label: {
                Label("Open plan", systemImage: "shield")
            }
            .buttonStyle(Anchor.SecondaryButtonStyle())
        }
    }
}

struct TriggerWindowsWidget: View {
    @Query private var windows: [TriggerWindow]

    var body: some View {
        Anchor.Widget(icon: "clock.fill", title: "Trigger windows", tint: Anchor.Theme.sage, fillsHeight: true) {
            TriggerWindowListView()
        } content: {
            if let next = TimeWindowHelper.soonestUpcoming(among: windows) {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetBig(text: next.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    Anchor.WidgetCaption(text: next.window.label.isEmpty ? "Trigger window" : next.window.label)
                }
            } else {
                Anchor.WidgetCaption(text: windows.isEmpty ? "None yet. Tap to add one." : "Nothing coming up.")
            }
        }
    }
}

struct AppointmentsWidget: View {
    @Query private var allSeries: [AppointmentSeries]
    var fillsHeight = true

    private var next: (series: AppointmentSeries, occurrence: AppointmentOccurrence)? {
        allSeries
            .flatMap { s in s.occurrenceList.map { (s, $0) } }
            .filter { $0.1.scheduledDate > .now }
            .min { $0.1.scheduledDate < $1.1.scheduledDate }
    }

    private func daysUntil(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    var body: some View {
        Anchor.Widget(icon: "calendar", title: "Appointments", tint: Anchor.Theme.sage, fillsHeight: fillsHeight) {
            ProviderPageHost(page: .sessions, startingWith: next?.series.id)
        } content: {
            if let next {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetBig(text: next.occurrence.scheduledDate.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    Anchor.WidgetCaption(text: "\(next.series.displayName) · \(daysUntil(next.occurrence.scheduledDate))")
                }
            } else {
                Anchor.WidgetCaption(text: "Nothing scheduled. Tap to set one up.")
            }
        }
    }
}

struct ContactsWidget: View {
    let contacts: [TrustedContact]

    var body: some View {
        if contacts.isEmpty {
            Anchor.Widget(icon: "person.2.fill", title: "Contacts") {
                ContactsView()
            } content: {
                Anchor.WidgetCaption(text: "Add someone you trust. They'll show up here for one-tap messages.")
            }
        } else {
            Anchor.Card {
                VStack(alignment: .leading, spacing: 10) {
                    QuickContactsView(contacts: contacts)
                    NavigationLink { ContactsView() } label: {
                        Label("All contacts", systemImage: "person.2.fill")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle())
                }
            }
        }
    }
}

struct DeEscalationWidget: View {
    var body: some View {
        Anchor.Card(accentColor: Anchor.Theme.sage) {
            VStack(alignment: .leading, spacing: 10) {
                DeEscalationCardView()
                NavigationLink { DeEscalationScriptsView() } label: {
                    Label("All scripts", systemImage: "wind")
                }
                .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
            }
        }
    }
}

struct GroundingWidget: View {
    let tools: [GroundingTool]

    var body: some View {
        Anchor.Card(accentColor: Anchor.Theme.sage) {
            VStack(alignment: .leading, spacing: 10) {
                GroundingToolsView(allTools: tools)
                NavigationLink { GroundingToolsListView() } label: {
                    Label("All tools", systemImage: "leaf.fill")
                }
                .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
            }
        }
    }
}

struct AffirmationsWidget: View {
    var body: some View {
        Anchor.Card {
            VStack(alignment: .leading, spacing: 10) {
                AffirmationsCardView()
                NavigationLink { AffirmationsView() } label: {
                    Label("All affirmations", systemImage: "sparkles")
                }
                .buttonStyle(Anchor.SecondaryButtonStyle())
            }
        }
    }
}

struct RecoveryWidget: View {
    @Query(sort: \RecoveryCounter.sortOrder) private var allCounters: [RecoveryCounter]

    private var counter: RecoveryCounter? { allCounters.first { !$0.isArchived } }

    var body: some View {
        Anchor.Widget(
            icon: "calendar.badge.checkmark",
            title: "Recovery",
            tint: Anchor.Theme.sage,
            fillsHeight: true
        ) {
            RecoveryHomeView()
        } content: {
            if let counter {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetBig(text: counter.currentRunDays() >= 1 ? "Day \(counter.currentRunDays())" : counter.currentRunPhrase().prefix(1).uppercased() + counter.currentRunPhrase().dropFirst())
                    Anchor.WidgetCaption(text: counter.name, lines: 1)
                }
            } else {
                Anchor.WidgetCaption(text: "Start a counter whenever you're ready.")
            }
        } footer: {
            NavigationLink { CravingToolView() } label: {
                Text("Ride out urge").lineLimit(1)
            }
            .buttonStyle(Anchor.SecondaryButtonStyle(tint: Anchor.Theme.sage))
        }
    }
}

struct MotivationsWidget: View {
    @Query(sort: \RecoveryMotivation.sortOrder) private var motivations: [RecoveryMotivation]

    var body: some View {
        Anchor.Widget(icon: "heart.fill", title: "Who I'm doing this for", fillsHeight: true) {
            RecoveryMotivationsView()
        } content: {
            if let first = motivations.first {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetBig(text: "\(motivations.count) \(motivations.count == 1 ? "reason" : "reasons")")
                    Anchor.WidgetCaption(text: first.text)
                }
            } else {
                Anchor.WidgetCaption(text: "Add the people and reasons that matter.")
            }
        }
    }
}

struct TasksWidget: View {
    @Query(sort: \TaskItem.sortOrder) private var tasks: [TaskItem]

    private var open: [TaskItem] { TaskItem.listOrder(tasks, includeWaiting: false) }

    var body: some View {
        Anchor.Widget(icon: "checkmark.circle.fill", title: "Tasks", fillsHeight: true) {
            TasksView()
        } content: {
            if let first = open.first {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetBig(text: "\(open.count) to do")
                    Anchor.WidgetCaption(text: first.title, lines: 1)
                }
            } else {
                Anchor.WidgetCaption(text: tasks.isEmpty ? "Nothing here yet. Tap to add something small." : (TaskItem.listOrder(tasks).isEmpty ? "All ticked off." : "Nothing to do right now."), lines: 1)
            }
        }
    }
}

// MARK: - Bridge widgets

struct ThingsToRaiseWidget: View {
    @Query private var itemsStored: [BridgeDraftItem]
    /// Sorted after the items are opened, because a locked createdAt cannot be sorted by the database (Patch 35g2).
    private var items: [BridgeDraftItem] { itemsStored.sortedByKey(descending: true) { $0.createdAt } }
    private var open: [BridgeDraftItem] { items.filter { !$0.isResolved } }

    var body: some View {
        Anchor.Widget(icon: "doc.text.fill", title: "Things to raise") {
            BridgeDraftListView()
        } content: {
            Anchor.WidgetCaption(text: open.isEmpty ? "Nothing queued. Tap to add something for your next session." : "\(open.count) for your next session", lines: 1)
        } footer: {
            // Tick things off in place; the checkbox is the only action, the
            // text stays calm (no counts or streaks).
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(open.prefix(3))) { item in
                    Button {
                        item.isResolved.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: item.isResolved ? "checkmark.square.fill" : "square")
                                .foregroundStyle(Anchor.Theme.accent)
                            Text(item.text)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct NextSessionWidget: View {
    @Query private var allSeries: [AppointmentSeries]

    private var next: (series: AppointmentSeries, occurrence: AppointmentOccurrence)? {
        allSeries
            .flatMap { s in s.occurrenceList.map { (s, $0) } }
            .filter { $0.1.scheduledDate > .now }
            .min { $0.1.scheduledDate < $1.1.scheduledDate }
    }

    /// The provider of the most recent session so far, which is who After session opens on.
    private var lastPastSeries: AppointmentSeries? {
        let past = allSeries
            .flatMap { s in s.occurrenceList.map { (s, $0) } }
            .filter { $0.1.scheduledDate <= .now }
        return past.max { $0.1.scheduledDate < $1.1.scheduledDate }?.0
    }

    var body: some View {
        Anchor.Widget(icon: "calendar.badge.clock", title: "Next session") {
            ProviderPageHost(page: .sessions, startingWith: next?.series.id)
        } content: {
            if let next {
                Anchor.WidgetCaption(
                    text: "\(next.series.displayName) · \(next.occurrence.scheduledDate.formatted(date: .abbreviated, time: .shortened))",
                    lines: 1
                )
            } else {
                Anchor.WidgetCaption(text: "No session scheduled. You can still prep.", lines: 1)
            }
        } footer: {
            HStack(spacing: 8) {
                NavigationLink { ProviderPageHost(page: .prep, startingWith: next?.series.id) } label: {
                    Text("Session prep").lineLimit(1)
                }
                NavigationLink { ProviderPageHost(page: .afterSession, startingWith: (lastPastSeries ?? next?.series)?.id) } label: {
                    Text("After session").lineLimit(1)
                }
            }
            .buttonStyle(Anchor.SecondaryButtonStyle())
        }
    }
}

struct ReframingWidget: View {
    let onOpen: () -> Void

    var body: some View {
        Anchor.Card(accentColor: Anchor.Theme.sage, fillsHeight: true) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle().fill(Anchor.Theme.sage.opacity(0.16)).frame(width: 26, height: 26)
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Anchor.Theme.sage)
                        }
                        Text("Reframing")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    Anchor.WidgetCaption(text: "Stuck on a thought? Try a reframe.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

struct FeedbackLoopsWidget: View {
    @Query private var diagramsStored: [FeedbackLoopDiagram]
    /// Sorted after the items are opened, because a locked value cannot be sorted by the database (Patch 35g3).
    private var diagrams: [FeedbackLoopDiagram] { diagramsStored.sortedByKey(descending: true) { $0.lastEditedAt } }

    var body: some View {
        Anchor.Widget(icon: "point.3.connected.trianglepath.dotted", title: "Feedback loops", tint: Anchor.Theme.sage, fillsHeight: true) {
            FeedbackLoopDiagramListView()
        } content: {
            if let latest = diagrams.first {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetBig(text: "\(diagrams.count) \(diagrams.count == 1 ? "diagram" : "diagrams")")
                    Anchor.WidgetCaption(text: latest.title.isEmpty ? "Untitled" : latest.title, lines: 1)
                }
            } else {
                Anchor.WidgetCaption(text: "Map a pattern you keep seeing.")
            }
        }
    }
}

// MARK: - Thread widgets

struct MessageLogWidget: View {
    @Query private var messagesStored: [ThreadMessage]
    /// Sorted after the items are opened, because a locked timestamp cannot be sorted by the database (Patch 35g2).
    private var messages: [ThreadMessage] { messagesStored.sortedByKey(descending: true) { $0.timestamp } }
    @State private var composerRequest: MessageComposerRequest?

    var body: some View {
        Anchor.Widget(icon: "bubble.left.and.bubble.right.fill", title: "Message log") {
            ThreadMessagesView()
        } content: {
            if let last = messages.first {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetCaption(text: last.timestamp.formatted(date: .abbreviated, time: .shortened), lines: 1)
                    Text(last.text.isEmpty ? "Voice note" : last.text)
                        .font(.system(.subheadline, design: .rounded))
                        .lineLimit(2)
                }
            } else {
                Anchor.WidgetCaption(text: "Write to someone, or keep a note of what you've told them.")
            }
        } footer: {
            Button {
                composerRequest = MessageComposerRequest()
            } label: {
                Label("Write", systemImage: "square.and.pencil")
            }
            .buttonStyle(Anchor.SecondaryButtonStyle())
        }
        .sheet(item: $composerRequest) { request in
            ThreadMessageComposer(startingContactID: request.contactID)
        }
    }
}

struct SupportCalendarWidget: View {
    @Query private var entries: [SupportCalendarEntry]

    private var days: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? cal.startOfDay(for: .now)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        let cal = Calendar.current
        Anchor.Widget(icon: "calendar.badge.clock", title: "Support calendar") {
            SupportCalendarView()
        } content: {
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    let isToday = cal.isDateInToday(day)
                    let hasEntry = entries.contains { cal.isDate($0.date, inSameDayAs: day) }
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(isToday ? Color.white : Color.primary)
                            .frame(width: 26, height: 26)
                            .background(isToday ? Anchor.Theme.accent : Color.clear, in: Circle())
                        Circle()
                            .fill(hasEntry ? Anchor.Theme.sage : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct FutureNotesWidget: View {
    @Query private var notesStored: [FutureNote]
    /// Sorted after the items are opened, because a locked unlockDate cannot be sorted by the database (Patch 35g2).
    private var notes: [FutureNote] { notesStored.sortedByKey { $0.unlockDate } }
    var body: some View {
        let dated = notes.filter { !$0.isOpenWhenLetter }
        let ready = dated.filter { $0.unlockDate <= .now }.count
        let upcoming = dated.first { $0.unlockDate > .now }
        let letters = notes.count - dated.count
        Anchor.Widget(icon: "envelope.open.badge.clock", title: "To future me", tint: Anchor.Theme.sage, fillsHeight: true) {
            FutureNoteListView()
        } content: {
            if ready > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetBig(text: "\(ready) ready")
                    Anchor.WidgetCaption(text: "Tap to open")
                }
            } else if let upcoming {
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: upcoming.unlockDate)).day ?? 0
                Anchor.WidgetCaption(text: "Next unlocks in \(max(days, 1)) \(max(days, 1) == 1 ? "day" : "days")")
            } else if letters > 0 {
                Anchor.WidgetCaption(text: letters == 1 ? "1 letter to open when you choose." : "\(letters) letters to open when you choose.")
            } else {
                Anchor.WidgetCaption(text: "Write something for a later day.")
            }
        }
    }
}

struct PersonalGoalsWidget: View {
    @Query(sort: \PersonalGoal.sortOrder) private var goals: [PersonalGoal]

    private var working: [PersonalGoal] {
        goals.filter { $0.status == .active && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        Anchor.Widget(icon: "flag.fill", title: "Personal goals", tint: Anchor.Theme.sage) {
            PersonalGoalsView()
        } content: {
            if let first = working.first {
                VStack(alignment: .leading, spacing: 1) {
                    Text(first.title)
                        .font(.system(.subheadline, design: .rounded))
                        .lineLimit(2)
                    if working.count > 1 {
                        Text("and \(working.count - 1) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Anchor.WidgetCaption(text: "Your own goals, in your own words. Tap to add one.")
            }
        }
    }
}

struct BoundariesWidget: View {
    @Query(sort: \BoundarySection.sortOrder) private var sections: [BoundarySection]

    /// The first shown section that has words, with its first line.
    private var glance: (title: String, line: String)? {
        for section in sections where !section.isHidden {
            if let line = SafetyPlanSections.firstLine(section.text) {
                return (section.title.isEmpty ? "Untitled" : section.title, line)
            }
        }
        return nil
    }

    var body: some View {
        Anchor.Widget(icon: "hand.raised.fill", title: "Boundaries", tint: Anchor.Theme.sage) {
            BoundariesView()
        } content: {
            if let glance {
                VStack(alignment: .leading, spacing: 1) {
                    Text(glance.title).font(.caption2).foregroundStyle(.secondary)
                    Text(glance.line).font(.system(.subheadline, design: .rounded)).lineLimit(2)
                }
            } else {
                Anchor.WidgetCaption(text: "Not filled in yet. Tap to write yours.")
            }
        }
    }
}

struct PeopleWidget: View {
    @Query(sort: \TrustedContact.sortOrder) private var contacts: [TrustedContact]

    /// Who is there, by name. Never a count of messages or of anything done.
    private var caption: String {
        let names = contacts
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        switch names.count {
        case 0:
            return "Add people under Contacts in Plan. Each gets a page of their own."
        case 1...3:
            return ListFormatter.localizedString(byJoining: names)
        default:
            return names.prefix(2).joined(separator: ", ") + " and \(names.count - 2) more"
        }
    }

    var body: some View {
        Anchor.Widget(icon: "person.crop.circle.fill", title: "People") {
            PeopleView()
        } content: {
            Anchor.WidgetCaption(text: caption, lines: 2)
        }
    }
}

struct UnsentDraftsWidget: View {
    @Query private var drafts: [UnsentDraft]

    var body: some View {
        let count = drafts.filter { !$0.wasSent }.count
        Anchor.Widget(icon: "square.and.pencil", title: "Things I haven't said", tint: Anchor.Theme.sage, fillsHeight: true) {
            UnsentDraftsView()
        } content: {
            if count > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Anchor.WidgetBig(text: "\(count) \(count == 1 ? "draft" : "drafts")")
                    Anchor.WidgetCaption(text: "Private. For big things you might never send.")
                }
            } else {
                Anchor.WidgetCaption(text: "Private. For big things you might never send.")
            }
        }
    }
}
