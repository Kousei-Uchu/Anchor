//
//  TriggerWindowEditorView.swift
//  Anchor
//
//  Deliberately has no location/map picker anywhere in this file. If a
//  location-based trigger is ever requested again, that decision belongs
//  to the user's psych, not a feature added here.
//
//  Editing follows the app-wide pattern: tap a window to edit it, the plus
//  adds one, and Delete is in the editor and in the long-press menu.
//

import SwiftUI
import SwiftData

/// Trigger windows as cards, with whether each is active shown as a label.
/// Tap one to change it.
struct TriggerWindowListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var windows: [TriggerWindow]
    @State private var editingWindow: TriggerWindow?
    @State private var windowToDelete: TriggerWindow?

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
                    ) { startNewWindow() }
                } else {
                    ForEach(windows) { window in
                        Button {
                            editingWindow = window
                        } label: {
                            TriggerWindowCard(window: window)
                        }
                        .buttonStyle(.plain)
                        .anchorDeletable {
                            remove(window)
                            NotificationScheduler.resyncTriggerWindows(using: modelContext)
                        }
                    }
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Trigger windows")
        .guideButton("plan.trigger-windows", tab: .plan)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.AddToolbarButton(label: "Add a window") { startNewWindow() }
            }
        }
        .sheet(item: $editingWindow, onDismiss: finishEditing) { window in
            TriggerWindowEditorView(window: window, onDelete: { windowToDelete = window })
        }
    }

    private func startNewWindow() {
        let new = TriggerWindow(
            label: "New window",
            daysOfWeek: [2, 3, 4, 5, 6],
            startTime: DateComponents(hour: 7, minute: 0),
            endTime: DateComponents(hour: 9, minute: 0)
        )
        modelContext.insert(new)
        editingWindow = new
    }

    /// Takes a window's pending reminders away and deletes it, so a deleted
    /// window can't keep notifying. Saves straight away so the re-sync that
    /// follows doesn't see it.
    private func remove(_ window: TriggerWindow) {
        NotificationScheduler(context: modelContext).removeTriggerWindowNotifications(for: window)
        modelContext.delete(window)
        try? modelContext.save()
    }

    /// Runs once the editor has closed. Deleting here, not while the editor
    /// is still on screen, keeps the editor from reading a window that is
    /// already gone. Then reminders are brought in line with what is left.
    private func finishEditing() {
        if let window = windowToDelete {
            windowToDelete = nil
            remove(window)
        }
        NotificationScheduler.resyncTriggerWindows(using: modelContext)
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
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(triggerWindowSummary(window))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(window.isActive ? 1 : 0.7)
        }
    }
}

/// "Mon Tue Wed · 07:00–09:00"
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

/// One window in one sheet. Also opened from Recovery, where a new window is
/// suggested from the user's urge times; that caller passes no `onDelete`,
/// so no Delete button appears there.
struct TriggerWindowEditorView: View {
    @Bindable var window: TriggerWindow
    var onDelete: (() -> Void)? = nil

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
        Anchor.ItemEditorSheet(
            title: "Trigger window",
            onDelete: onDelete,
            deleteQuestion: "Delete this window?",
            onDone: {
                // New windows start active, so this is the first time the user commits to one.
                if window.isActive { NotificationScheduler.askForPermissionIfNeeded() }
            }
        ) {
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
        }
    }
}
