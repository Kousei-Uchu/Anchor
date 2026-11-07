//
//  TriggerWindowEditorView.swift
//  Anchor
//
//  Deliberately has no location/map picker anywhere in this file. If a
//  location-based trigger is ever requested again, that decision belongs
//  to the user's psych, not a feature added here.
//

import SwiftUI
import SwiftData

/// Trigger windows as something to browse: a card per window, with whether
/// it's active shown as a label. Adding, deleting and changing windows
/// happens behind Edit.
struct TriggerWindowListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var windows: [TriggerWindow]
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if windows.isEmpty {
                    Anchor.EmptyState(
                        icon: "clock.fill",
                        title: "No trigger windows yet",
                        message: "Add the times of day that tend to be hard, and Anchor can check in with you then.",
                        actionTitle: "Add a window",
                        tint: Anchor.Theme.sage
                    ) { showingEditor = true }
                } else {
                    ForEach(windows) { window in
                        TriggerWindowCard(window: window)
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Trigger windows")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor, onDismiss: {
            NotificationScheduler.resyncTriggerWindows(using: modelContext)
        }) {
            Anchor.EditorSheet(title: "Edit trigger windows") {
                TriggerWindowsEditorList()
            }
        }
    }
}

private struct TriggerWindowCard: View {
    let window: TriggerWindow

    var body: some View {
        Anchor.Card(accentColor: window.isActive ? Anchor.Theme.accent : Anchor.Theme.sage) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(window.label.isEmpty ? "Untitled window" : window.label)
                        .font(.system(.headline, design: .rounded))
                    Spacer()
                    Label(window.isActive ? "Active" : "Paused",
                          systemImage: window.isActive ? "bell.fill" : "bell.slash")
                        .font(.caption)
                        .foregroundStyle(window.isActive ? Anchor.Theme.accent : .secondary)
                }
                Text(triggerWindowSummary(window))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(window.isActive ? 1 : 0.7)
        }
    }
}

/// "Mon Tue Wed · 07:00–09:00" — shared by the read cards and the editor list.
private func triggerWindowSummary(_ window: TriggerWindow) -> String {
    let dayNames = window.daysOfWeek.sorted().compactMap { weekday -> String? in
        let symbols = Calendar.current.shortWeekdaySymbols
        guard weekday >= 1 && weekday <= symbols.count else { return nil }
        return symbols[weekday - 1]
    }.joined(separator: " ")
    let start = String(format: "%02d:%02d", window.startTime.hour ?? 0, window.startTime.minute ?? 0)
    let end = String(format: "%02d:%02d", window.endTime.hour ?? 0, window.endTime.minute ?? 0)
    return "\(dayNames) · \(start)–\(end)"
}

/// The editable list: add, delete, and open a window's details. Presented
/// from `TriggerWindowListView` via Edit, never browsed to directly.
private struct TriggerWindowsEditorList: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var windows: [TriggerWindow]
    @State private var editingWindow: TriggerWindow?

    var body: some View {
        List {
            ForEach(windows) { window in
                Button {
                    editingWindow = window
                } label: {
                    VStack(alignment: .leading) {
                        Text(window.label).font(.headline)
                        Text(triggerWindowSummary(window))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(windows[index]) }
            }

            Button("Add trigger window") {
                let new = TriggerWindow(
                    label: "New window",
                    daysOfWeek: [2, 3, 4, 5, 6],
                    startTime: DateComponents(hour: 7, minute: 0),
                    endTime: DateComponents(hour: 9, minute: 0)
                )
                modelContext.insert(new)
                editingWindow = new
            }
        }
        .sheet(item: $editingWindow) { window in
            TriggerWindowEditorView(window: window)
        }
    }
}

/// Circle letter toggles for day-of-week selection — same visual pattern
/// as the sleep-schedule day picker in Apple's Health app, rather than a
/// tall list of individual toggles. Weekday numbering matches
/// TriggerWindow.daysOfWeek (1 = Sunday ... 7 = Saturday, Calendar-style).
struct WeekdayCirclePicker: View {
    @Binding var selectedDays: Set<Int>
    var tint: Color = Anchor.Theme.accent

    private let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { weekday in
                let isSelected = selectedDays.contains(weekday)
                Button {
                    withAnimation(.snappy) {
                        if isSelected { selectedDays.remove(weekday) } else { selectedDays.insert(weekday) }
                    }
                } label: {
                    Text(letters[weekday - 1])
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(isSelected ? tint : tint.opacity(0.12))
                        )
                        .foregroundStyle(isSelected ? .white : tint)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct TriggerWindowEditorView: View {
    @Bindable var window: TriggerWindow
    @Environment(\.dismiss) private var dismiss

    private var startBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: window.startTime) ?? .now },
            set: { window.startTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }
    private var endBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: window.endTime) ?? .now },
            set: { window.endTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label", text: $window.label)
                    Toggle("Active", isOn: $window.isActive)
                        .onChange(of: window.isActive) { _, isOn in
                            if isOn { NotificationScheduler.askForPermissionIfNeeded() }
                        }
                }
                Section("Days") {
                    WeekdayCirclePicker(selectedDays: Binding(
                        get: { Set(window.daysOfWeek) },
                        set: { window.daysOfWeek = Array($0) }
                    ))
                    .padding(.vertical, 6)
                }
                Section("Time of day") {
                    DatePicker("Start", selection: startBinding, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: endBinding, displayedComponents: .hourAndMinute)
                }
            }
            .anchorSettingsStyle()
            .navigationTitle("Trigger window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // New windows start active, so this is the first time the user commits to one.
                        if window.isActive { NotificationScheduler.askForPermissionIfNeeded() }
                        dismiss()
                    }
                }
            }
        }
    }
}
