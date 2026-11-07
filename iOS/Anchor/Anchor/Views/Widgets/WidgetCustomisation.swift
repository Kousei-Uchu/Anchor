//
//  WidgetCustomisation.swift
//  Anchor
//
//  Phase 2 of the widget layout: per-tab order and visibility for Plan,
//  Bridge and Thread. The saved layout is two small strings per tab in
//  @AppStorage (an ordered list of `WidgetID` raw values, and the hidden
//  ones). Anything hidden moves to a "More" row at the bottom of the tab, so
//  no feature ever becomes unreachable. Widgets added in a later version
//  that aren't in the saved order simply appear after the saved ones.
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

    /// The shipped order; also what "Reset" returns to.
    var defaultOrder: [WidgetID] {
        switch self {
        case .plan:
            return [.safetyPlan, .triggerWindows, .appointments, .contacts, .deEscalation,
                    .grounding, .decisionPresets, .affirmations, .recovery, .motivations]
        case .bridge:
            var ids: [WidgetID] = [.thingsToRaise, .nextSession, .reframing, .feedbackLoops]
            #if PERSONAL_BUILD
            ids.append(.nswLaw)
            #endif
            return ids
        case .thread:
            return [.messageLog, .supportCalendar, .futureNotes, .unsentDrafts]
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

    /// Lays out a tab's widgets from its saved order/visibility: adjacent
    /// half-width widgets pair up, a lone one goes full width, and hidden
    /// ones collect in a "More" row. Long-press a widget to move or hide it.
    struct WidgetStack<Content: View, More: View>: View {
        let tab: WidgetTab
        let content: (WidgetID) -> Content
        let more: (WidgetID) -> More

        @AppStorage private var orderRaw: String
        @AppStorage private var hiddenRaw: String
        @State private var showCustomise = false

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

        private var ordered: [WidgetID] { WidgetLayoutStore.ordering(for: tab, orderRaw: orderRaw) }
        private var hidden: Set<WidgetID> { Set(WidgetLayoutStore.decode(hiddenRaw)) }
        private var visible: [WidgetID] { ordered.filter { !hidden.contains($0) } }
        private var tucked: [WidgetID] { ordered.filter { hidden.contains($0) } }

        private var rows: [Row] {
            let ids = visible
            var result: [Row] = []
            var i = 0
            while i < ids.count {
                let a = ids[i]
                if !typeSize.isAccessibilitySize, a.isHalf, i + 1 < ids.count, ids[i + 1].isHalf {
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
            }
            .sheet(isPresented: $showCustomise) {
                NavigationStack {
                    CustomiseWidgetsView(initialTab: tab)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showCustomise = false }
                            }
                        }
                }
            }
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

        private func widget(_ id: WidgetID) -> some View {
            content(id)
                .contextMenu {
                    Button { move(id, by: -1) } label: { Label("Move up", systemImage: "arrow.up") }
                    Button { move(id, by: 1) } label: { Label("Move down", systemImage: "arrow.down") }
                    Button { hide(id) } label: { Label("Hide", systemImage: "eye.slash") }
                    Button { showCustomise = true } label: { Label("Customise widgets", systemImage: "slider.horizontal.3") }
                }
        }

        /// Swaps with the neighbouring *visible* widget; hidden ones keep their slots.
        private func move(_ id: WidgetID, by delta: Int) {
            var shown = visible
            guard let index = shown.firstIndex(of: id) else { return }
            let target = index + delta
            guard shown.indices.contains(target) else { return }
            shown.swapAt(index, target)
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

    init(tab: WidgetTab) {
        self.tab = tab
        _orderRaw = AppStorage(wrappedValue: "", tab.orderKey)
        _hiddenRaw = AppStorage(wrappedValue: "", tab.hiddenKey)
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
                }
                .font(.system(.subheadline, design: .rounded))
            }
        }
        .environment(\.editMode, .constant(.active))
        .anchorSettingsStyle()
    }
}
