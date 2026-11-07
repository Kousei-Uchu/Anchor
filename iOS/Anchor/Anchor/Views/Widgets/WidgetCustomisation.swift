//
//  WidgetCustomisation.swift
//  Anchor
//
//  Phase 2 of the widget layout: per-tab order, visibility and width for
//  Plan, Bridge and Thread. The saved layout is three small strings per tab
//  in @AppStorage (an ordered list of `WidgetID` raw values, the hidden ones,
//  and the half-width widgets that have been made full width). Anything
//  hidden moves to a "More" row at the bottom of the tab, so no feature ever
//  becomes unreachable. Widgets added in a later version that aren't in the
//  saved order simply appear after the saved ones.
//
//  Editing happens on the tab itself: the Customise button under the widgets
//  (or a long-press on one) makes the cards wiggle. Drag a card onto another
//  to move it, tap the minus to hide it, add hidden ones back from the tray,
//  and use the resize button to make a half-width widget full width. The
//  older list in Settings > Layout does the same job for people who prefer it.
//

import SwiftUI

enum WidgetTab: String, CaseIterable, Identifiable {
    case plan, bridge, thread

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan: return "Plan"
        case .bridge: return "Bridge"
        case .thread: return "Thread"
        }
    }

    var orderKey: String { "widgetOrder.\(rawValue)" }
    var hiddenKey: String { "widgetHidden.\(rawValue)" }
    /// Widgets that are half width by default but have been made full width.
    var fullKey: String { "widgetFull.\(rawValue)" }

    /// The shipped order; also what "Reset" returns to.
    var defaultOrder: [WidgetID] {
        switch self {
        case .plan:
            return [.safetyPlan, .triggerWindows, .appointments, .tasks, .contacts, .deEscalation,
                    .grounding, .decisionPresets, .affirmations, .recovery, .motivations]
        case .bridge:
            var ids: [WidgetID] = [.thingsToRaise, .nextSession, .reframing, .feedbackLoops]
            #if PERSONAL_BUILD
            ids.append(.nswLaw)
            #endif
            return ids
        case .thread:
            return [.messageLog, .supportCalendar, .futureNotes, .unsentDrafts, .boundaries]
        }
    }
}

enum WidgetLayoutStore {
    static func decode(_ raw: String) -> [WidgetID] {
        raw.split(separator: ",").compactMap { WidgetID(rawValue: String($0)) }
    }

    static func encode(_ ids: [WidgetID]) -> String {
        ids.map(\.rawValue).joined(separator: ",")
    }

    /// Every widget for the tab, in saved order. Unknown or duplicate ids are
    /// dropped; widgets missing from the saved order go on the end.
    static func ordering(for tab: WidgetTab, orderRaw: String) -> [WidgetID] {
        let valid = Set(tab.defaultOrder)
        var seen = Set<WidgetID>()
        var result: [WidgetID] = []
        for id in decode(orderRaw) where valid.contains(id) && !seen.contains(id) {
            result.append(id)
            seen.insert(id)
        }
        for id in tab.defaultOrder where !seen.contains(id) {
            result.append(id)
        }
        return result
    }
}

extension Anchor {
    /// A tile in a tab's "More" row: where a hidden widget still lives.
    struct MoreTile<Destination: View>: View {
        let id: WidgetID
        @ViewBuilder var destination: () -> Destination

        var body: some View {
            NavigationLink {
                destination()
            } label: {
                TileButtonLabel(icon: id.icon, title: id.title, tint: id.tint)
            }
            .buttonStyle(.plain)
        }
    }

    /// Lays out a tab's widgets from its saved order, visibility and width:
    /// adjacent half-width widgets pair up, a lone one goes full width, and
    /// hidden ones collect in a "More" row. The Customise button under them
    /// (or a long-press on a widget) starts editing right here.
    struct WidgetStack<Content: View, More: View>: View {
        let tab: WidgetTab
        let content: (WidgetID) -> Content
        let more: (WidgetID) -> More

        @AppStorage private var orderRaw: String
        @AppStorage private var hiddenRaw: String
        @AppStorage private var fullRaw: String
        @State private var editing = false
        @State private var targeted: WidgetID?
        @State private var confirmingReset = false

        init(
            tab: WidgetTab,
            @ViewBuilder content: @escaping (WidgetID) -> Content,
            @ViewBuilder more: @escaping (WidgetID) -> More
        ) {
            self.tab = tab
            self.content = content
            self.more = more
            _orderRaw = AppStorage(wrappedValue: "", tab.orderKey)
            _hiddenRaw = AppStorage(wrappedValue: "", tab.hiddenKey)
            _fullRaw = AppStorage(wrappedValue: "", tab.fullKey)
        }

        private enum Row: Identifiable {
            case single(WidgetID)
            case pair(WidgetID, WidgetID)

            var id: String {
                switch self {
                case .single(let a): return a.rawValue
                case .pair(let a, let b): return a.rawValue + "+" + b.rawValue
                }
            }
        }

        @Environment(\.dynamicTypeSize) private var typeSize
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var ordered: [WidgetID] { WidgetLayoutStore.ordering(for: tab, orderRaw: orderRaw) }
        private var hidden: Set<WidgetID> { Set(WidgetLayoutStore.decode(hiddenRaw)) }
        private var fullWidth: Set<WidgetID> { Set(WidgetLayoutStore.decode(fullRaw)) }
        private var visible: [WidgetID] { ordered.filter { !hidden.contains($0) } }
        private var tucked: [WidgetID] { ordered.filter { hidden.contains($0) } }

        /// Everything is full width at accessibility text sizes, and a widget
        /// that can be half width is only half width until it is made full.
        private func isHalfWidth(_ id: WidgetID) -> Bool {
            !typeSize.isAccessibilitySize && id.isHalf && !fullWidth.contains(id)
        }

        private var rows: [Row] {
            let ids = visible
            var result: [Row] = []
            var i = 0
            while i < ids.count {
                let a = ids[i]
                if isHalfWidth(a), i + 1 < ids.count, isHalfWidth(ids[i + 1]) {
                    result.append(.pair(a, ids[i + 1]))
                    i += 2
                } else {
                    result.append(.single(a))
                    i += 1
                }
            }
            return result
        }

        var body: some View {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                ForEach(rows) { row in
                    rowView(row)
                }

                if editing {
                    editingFooter
                } else {
                    if !tucked.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("More")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 14) {
                                    ForEach(tucked) { id in
                                        more(id)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                        }
                    }
                    Button(action: startEditing) {
                        Label("Customise", systemImage: "slider.horizontal.3")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbar {
                if editing {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done", action: stopEditing)
                    }
                }
            }
            .onDisappear { editing = false }
            .sensoryFeedback(.selection, trigger: orderRaw)
            .sensoryFeedback(.impact(weight: .light), trigger: editing)
        }

        @ViewBuilder
        private func rowView(_ row: Row) -> some View {
            switch row {
            case .single(let id):
                widget(id)
            case .pair(let a, let b):
                HStack(alignment: .top, spacing: 12) {
                    widget(a).frame(maxWidth: .infinity)
                    widget(b).frame(maxWidth: .infinity)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        @ViewBuilder
        private func widget(_ id: WidgetID) -> some View {
            if editing {
                editableCell(id)
            } else {
                content(id)
                    .contextMenu {
                        Button { move(id, by: -1) } label: { Label("Move up", systemImage: "arrow.up") }
                        Button { move(id, by: 1) } label: { Label("Move down", systemImage: "arrow.down") }
                        Button { hide(id) } label: { Label("Hide", systemImage: "eye.slash") }
                        Button(action: startEditing) { Label("Customise", systemImage: "slider.horizontal.3") }
                    }
            }
        }

        // MARK: Editing

        /// A widget while editing: its content is dimmed and cannot be opened,
        /// the whole card can be dragged, and the controls sit on top of it.
        private func editableCell(_ id: WidgetID) -> some View {
            content(id)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .opacity(0.35)
                .overlay { Color.clear.contentShape(Rectangle()) }
                .overlay {
                    HStack(spacing: 12) {
                        cellButton("minus", label: "Hide \(id.title)") { hide(id) }
                        if id.isHalf && !typeSize.isAccessibilitySize {
                            let isFull = fullWidth.contains(id)
                            cellButton(isFull ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                       label: isFull ? "Make \(id.title) half width" : "Make \(id.title) full width") {
                                toggleFull(id)
                            }
                        }
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .overlay {
                    if targeted == id {
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .strokeBorder(Theme.accent, lineWidth: 2)
                    }
                }
                .modifier(WiggleModifier(active: !reduceMotion))
                .draggable(id.rawValue)
                .dropDestination(for: String.self) { items, _ in
                    targeted = nil
                    guard let raw = items.first else { return false }
                    withAnimation(.snappy) { drop(raw, onto: id) }
                    return true
                } isTargeted: { isOver in
                    if isOver { targeted = id } else if targeted == id { targeted = nil }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(id.title)
                .accessibilityAction(named: "Move up") { move(id, by: -1) }
                .accessibilityAction(named: "Move down") { move(id, by: 1) }
        }

        private func cellButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
            Button {
                withAnimation(.snappy, action)
            } label: {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }

        /// Hidden widgets to add back, then Reset and Done. Shown in place of
        /// the More row while editing.
        private var editingFooter: some View {
            VStack(alignment: .leading, spacing: 12) {
                if !tucked.isEmpty {
                    Text("Hidden")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(tucked) { id in
                                Button {
                                    withAnimation(.snappy) { show(id) }
                                } label: {
                                    Label(id.title, systemImage: "plus.circle.fill")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Capsule().fill(id.tint.opacity(0.16)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Show \(id.title)")
                            }
                        }
                    }
                }
                HStack {
                    Button("Reset") { confirmingReset = true }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Done", action: stopEditing)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .confirmationDialog("Put \(tab.title) back the way it started?",
                                isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset \(tab.title)", role: .destructive) {
                    withAnimation(.snappy) { reset() }
                }
                Button("Keep my layout", role: .cancel) {}
            }
        }

        private func startEditing() {
            withAnimation(.snappy) { editing = true }
        }

        private func stopEditing() {
            targeted = nil
            withAnimation(.snappy) { editing = false }
        }

        // MARK: Changing the layout

        /// Moves the dragged widget to where the one it was dropped on sits:
        /// after it when dragging down, before it when dragging up.
        private func drop(_ raw: String, onto target: WidgetID) {
            guard let dragged = WidgetID(rawValue: raw), dragged != target else { return }
            var shown = visible
            guard let from = shown.firstIndex(of: dragged), let to = shown.firstIndex(of: target) else { return }
            shown.remove(at: from)
            shown.insert(dragged, at: to)
            apply(visibleOrder: shown)
        }

        /// Swaps with the neighbouring *visible* widget; hidden ones keep their slots.
        private func move(_ id: WidgetID, by delta: Int) {
            var shown = visible
            guard let index = shown.firstIndex(of: id) else { return }
            let target = index + delta
            guard shown.indices.contains(target) else { return }
            shown.swapAt(index, target)
            apply(visibleOrder: shown)
        }

        /// Writes a new order for the visible widgets into the slots they
        /// already occupy, so hidden widgets keep theirs.
        private func apply(visibleOrder shown: [WidgetID]) {
            var full = ordered
            let hiddenSet = hidden
            let slots = full.indices.filter { !hiddenSet.contains(full[$0]) }
            for (slot, newID) in zip(slots, shown) { full[slot] = newID }
            orderRaw = WidgetLayoutStore.encode(full)
        }

        private func hide(_ id: WidgetID) {
            var set = hidden
            set.insert(id)
            hiddenRaw = WidgetLayoutStore.encode(ordered.filter { set.contains($0) })
        }

        private func show(_ id: WidgetID) {
            var set = hidden
            set.remove(id)
            hiddenRaw = WidgetLayoutStore.encode(ordered.filter { set.contains($0) })
        }

        private func toggleFull(_ id: WidgetID) {
            var set = fullWidth
            if set.contains(id) { set.remove(id) } else { set.insert(id) }
            fullRaw = WidgetLayoutStore.encode(ordered.filter { set.contains($0) })
        }

        private func reset() {
            orderRaw = ""
            hiddenRaw = ""
            fullRaw = ""
        }
    }

    /// A very small tilt back and forth, the way icons wiggle on the Home
    /// Screen. Off when Reduce Motion is on.
    private struct WiggleModifier: ViewModifier {
        let active: Bool
        @State private var tilt = false

        func body(content: Content) -> some View {
            content
                .rotationEffect(.degrees(active ? (tilt ? 0.5 : -0.5) : 0))
                .animation(active ? Animation.easeInOut(duration: 0.16).repeatForever(autoreverses: true) : nil, value: tilt)
                .onAppear { if active { tilt.toggle() } }
        }
    }
}

// MARK: - Customise screen

/// Reorder and show/hide widgets for each tab. A configure surface, so it
/// uses the settings look and is reached from Settings > Layout (or a
/// widget's long-press menu).
struct CustomiseWidgetsView: View {
    @State private var tab: WidgetTab

    init(initialTab: WidgetTab = .plan) {
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $tab) {
                ForEach(WidgetTab.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            CustomiseWidgetsList(tab: tab)
                .id(tab)
        }
        .background(Anchor.Theme.settingsBackground(scheme).ignoresSafeArea())
        .navigationTitle("Customise widgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    @Environment(\.colorScheme) private var scheme
}

private struct CustomiseWidgetsList: View {
    let tab: WidgetTab
    @AppStorage private var orderRaw: String
    @AppStorage private var hiddenRaw: String
    @AppStorage private var fullRaw: String

    init(tab: WidgetTab) {
        self.tab = tab
        _orderRaw = AppStorage(wrappedValue: "", tab.orderKey)
        _hiddenRaw = AppStorage(wrappedValue: "", tab.hiddenKey)
        _fullRaw = AppStorage(wrappedValue: "", tab.fullKey)
    }

    private func visibleBinding(_ id: WidgetID) -> Binding<Bool> {
        Binding(
            get: { !WidgetLayoutStore.decode(hiddenRaw).contains(id) },
            set: { isOn in
                var set = Set(WidgetLayoutStore.decode(hiddenRaw))
                if isOn { set.remove(id) } else { set.insert(id) }
                let ordered = WidgetLayoutStore.ordering(for: tab, orderRaw: orderRaw)
                hiddenRaw = WidgetLayoutStore.encode(ordered.filter { set.contains($0) })
            }
        )
    }

    var body: some View {
        let ordered = WidgetLayoutStore.ordering(for: tab, orderRaw: orderRaw)

        List {
            Anchor.SettingsSection(
                title: "\(tab.title) widgets",
                footer: "Drag to reorder. Hidden widgets move to a More row at the bottom of the tab, so nothing is lost."
            ) {
                ForEach(ordered) { id in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(id.tint.opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: id.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(id.tint)
                        }
                        Text(id.title)
                            .font(.system(.subheadline, design: .rounded))
                        Spacer()
                        Toggle("Show \(id.title)", isOn: visibleBinding(id))
                            .labelsHidden()
                            .tint(Anchor.Theme.accent)
                    }
                }
                .onMove { source, destination in
                    var ids = ordered
                    ids.move(fromOffsets: source, toOffset: destination)
                    orderRaw = WidgetLayoutStore.encode(ids)
                }
            }

            Anchor.SettingsSection(title: nil) {
                Button("Reset \(tab.title) to default", role: .destructive) {
                    orderRaw = ""
                    hiddenRaw = ""
                    fullRaw = ""
                }
                .font(.system(.subheadline, design: .rounded))
            }
        }
        .environment(\.editMode, .constant(.active))
        .anchorSettingsStyle()
    }
}
