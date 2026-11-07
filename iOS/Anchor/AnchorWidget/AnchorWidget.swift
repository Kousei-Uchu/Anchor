//
//  AnchorWidget.swift
//  AnchorWidgetExtension
//
//  Lock-screen widget. Reads only WidgetDataStore's non-sensitive snapshot —
//  never touches SwiftData or anything from Journal/Bridge/Thread directly.
//  This works during restricted-mode/lock-screen hours because widgets are
//  a system surface independent of whether the app itself is unlocked.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct AnchorEntry: TimelineEntry {
    let date: Date
    let snapshot: AnchorWidgetSnapshot?
}

struct AnchorTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AnchorEntry {
        AnchorEntry(date: .now, snapshot: AnchorWidgetSnapshot(
            topContacts: [ContactWidgetSummary(name: "Contact", phoneNumber: "")],
            hasSafetyPlan: true,
            deEscalationScriptLine: "I need 10 minutes, then we can talk.",
            nextTriggerWindowLabel: "Weekday mornings · 7:30 AM",
            currentAffirmation: "This feeling is real, and it is not permanent."
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (AnchorEntry) -> Void) {
        completion(AnchorEntry(date: .now, snapshot: WidgetDataStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AnchorEntry>) -> Void) {
        let entry = AnchorEntry(date: .now, snapshot: WidgetDataStore.read())
        // Refresh periodically; content changes only when the user edits
        // contacts/safety plan in-app and calls WidgetDataStore.refresh.
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct AnchorWidgetEntryView: View {
    var entry: AnchorEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangularBody
                .containerBackground(.fill.tertiary, for: .widget)
        case .accessoryCircular:
            circularBody
                .containerBackground(.fill.tertiary, for: .widget)
        case .systemSmall:
            homeSmallBody
                .containerBackground(for: .widget) { homeBackground }
        case .systemMedium:
            homeMediumBody
                .containerBackground(for: .widget) { homeBackground }
        default:
            rectangularBody
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    private var homeBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.792, green: 0.475, blue: 0.373).opacity(0.16), Color.clear],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // Per feedback, widget taps were unreliable — the likely cause is
    // mixing `Link` elements with conditional `.widgetURL` fallbacks,
    // which puts multiple possible tap targets in play on a surface
    // that's most reliable with exactly one. Every family here now does
    // the same thing: plain, non-interactive content, with a single
    // `.widgetURL` on the whole view redirecting into the app. The actual
    // call happens from WidgetActionConfirmationView inside the app,
    // where a real Button is unambiguous — not from inside the widget.
    private var rectangularBody: some View {
        Group {
            if let contact = entry.snapshot?.topContacts.first {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(contact.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("Tap to call")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Anchor").font(.headline)
                    Text("Open app to add a contact").font(.caption2)
                }
            }
        }
        .widgetURL(URL(string: "anchor://action/call"))
    }

    private var circularBody: some View {
        Group {
            if entry.snapshot?.topContacts.first != nil {
                VStack(spacing: 1) {
                    Image(systemName: "phone.fill")
                    Text("Call")
                        .font(.caption2)
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "shield.fill")
                    if entry.snapshot?.hasSafetyPlan == true {
                        Text("Plan").font(.caption2)
                    }
                }
            }
        }
        .widgetURL(URL(string: "anchor://action/call"))
    }

    /// Home screen, small: same purpose as the lock screen version, just
    /// with room to breathe.
    private var homeSmallBody: some View {
        Group {
            if let contact = entry.snapshot?.topContacts.first {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "phone.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(red: 0.792, green: 0.475, blue: 0.373))
                    Spacer(minLength: 0)
                    Text(contact.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Tap to call")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "shield.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text("Anchor")
                        .font(.headline)
                    Text("Add a contact in Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(4)
        .widgetURL(URL(string: "anchor://action/call"))
    }

    /// Home screen, medium: contact + safety plan status + next trigger
    /// window at a glance. One tap target for the whole tile, same as
    /// everywhere else now — opens the call confirmation, since that's
    /// this widget's primary purpose; safety plan/next window are shown
    /// for context, not as separate tap targets.
    private var homeMediumBody: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label(entry.snapshot?.topContacts.first?.name ?? "No contact yet", systemImage: "person.fill")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(entry.snapshot?.hasSafetyPlan == true ? "Safety plan is set up" : "No safety plan yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Label("Next window", systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(entry.snapshot?.nextTriggerWindowLabel ?? "None set")
                    .font(.subheadline)
                    .lineLimit(2)
            }
        }
        .widgetURL(URL(string: "anchor://action/call"))
        .padding(4)
    }
}

struct AnchorWidget: Widget {
    let kind: String = "AnchorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnchorTimelineProvider()) { entry in
            AnchorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Anchor")
        .description("Your top contact and safety plan, one tap away.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall, .systemMedium])
    }
}

/// A second lock-screen widget: the de-escalation script, always visible
/// without needing to open the app or find a contact first. Kept as a
/// separate widget (rather than a mode of AnchorWidget) since someone adds
/// lock-screen widgets individually and may want the script without the
/// call widget, or both side by side.
struct AnchorDeEscalationEntryView: View {
    var entry: AnchorEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 1) {
                    Image(systemName: "wind")
                    Text("10 min").font(.caption2)
                }
                .widgetURL(URL(string: "anchor://now"))
            default: // accessoryRectangular and inline both read fine as plain text
                Text(entry.snapshot?.deEscalationScriptLine ?? "I need 10 minutes, then we can talk.")
                    .font(.caption)
                    .widgetURL(URL(string: "anchor://now"))
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct AnchorDeEscalationWidget: Widget {
    let kind: String = "AnchorDeEscalationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnchorTimelineProvider()) { entry in
            AnchorDeEscalationEntryView(entry: entry)
        }
        .configurationDisplayName("Anchor: De-escalation script")
        .description("Your script, always one glance away.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

/// A third lock-screen widget: the soonest upcoming trigger window, so
/// it's visible ahead of time rather than only when the notification
/// fires. Time/routine-based only, computed in TimeWindowHelper — never a
/// location trigger.
struct AnchorNextWindowEntryView: View {
    var entry: AnchorEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 1) {
                    Image(systemName: "clock.fill")
                    if let label = entry.snapshot?.nextTriggerWindowLabel {
                        Text(label).font(.system(size: 9)).lineLimit(1)
                    }
                }
            default:
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill").font(.caption2)
                    Text(entry.snapshot?.nextTriggerWindowLabel ?? "No windows set")
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .widgetURL(URL(string: "anchor://plan/trigger-windows"))
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct AnchorNextWindowWidget: Widget {
    let kind: String = "AnchorNextWindowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnchorTimelineProvider()) { entry in
            AnchorNextWindowEntryView(entry: entry)
        }
        .configurationDisplayName("Anchor: Next window")
        .description("When your next risk window starts.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

/// A fourth widget: the user's own current affirmation, front and center —
/// no tap target needed beyond opening the app, since there's nothing to
/// action here, just something to read.
struct AnchorAffirmationEntryView: View {
    var entry: AnchorEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "sparkles")
            case .systemSmall, .systemMedium:
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color(red: 0.792, green: 0.475, blue: 0.373))
                    Text(entry.snapshot?.currentAffirmation ?? "Add one in Plan.")
                        .font(.system(.footnote, design: .rounded))
                        .italic()
                        .lineLimit(family == .systemSmall ? 5 : 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                Text(entry.snapshot?.currentAffirmation ?? "Add one in Plan.")
                    .font(.caption2)
                    .italic()
                    .lineLimit(3)
            }
        }
        .widgetURL(URL(string: "anchor://now"))
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.792, green: 0.475, blue: 0.373).opacity(0.16), Color.clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

struct AnchorAffirmationWidget: Widget {
    let kind: String = "AnchorAffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnchorTimelineProvider()) { entry in
            AnchorAffirmationEntryView(entry: entry)
        }
        .configurationDisplayName("Anchor: Affirmation")
        .description("Something to hold onto, always in view.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall, .systemMedium])
    }
}

// MARK: - Recovery counter widget

struct CounterEntry: TimelineEntry {
    let date: Date
    let items: [CounterWidgetItem]
}

struct CounterTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CounterEntry {
        CounterEntry(date: .now, items: [CounterWidgetItem(
            label: "Your counter",
            runStart: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now,
            priorDays: 0, mode: "runAndTotal")])
    }

    func getSnapshot(in context: Context, completion: @escaping (CounterEntry) -> Void) {
        completion(CounterEntry(date: .now, items: CounterWidgetStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CounterEntry>) -> Void) {
        let entry = CounterEntry(date: .now, items: CounterWidgetStore.read())
        let next = ElapsedFormat.nextRefresh(runStarts: entry.items.map(\.runStart))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct AnchorCounterEntryView: View {
    var entry: CounterEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let item = entry.items.first {
                content(for: item)
            } else {
                Text("Add a counter in Plan, under Recovery.")
                    .font(.caption2)
            }
        }
        .widgetURL(URL(string: "anchor://now"))
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.58, green: 0.66, blue: 0.55).opacity(0.18), Color.clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func content(for item: CounterWidgetItem) -> some View {
        let days = item.runDays(now: entry.date)
        let reading = item.reading(now: entry.date)
        let total = item.totalDays(now: entry.date)
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(reading.number).font(.system(.title2, design: .rounded).weight(.semibold))
                Text(reading.label).font(.system(size: 9))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).font(.caption2)
                Text("\(reading.number) \(reading.label)").font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(reading.number)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.792, green: 0.475, blue: 0.373))
                Text(reading.label)
                    .font(.system(.footnote, design: .rounded))
                if item.mode == "runAndTotal", total != days {
                    Text("\(total) in total").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AnchorCounterWidget: Widget {
    let kind: String = "AnchorCounterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CounterTimelineProvider()) { entry in
            AnchorCounterEntryView(entry: entry)
        }
        .configurationDisplayName("Anchor: Counter")
        .description("A day count. It shows the discreet label you chose, never the counter's name, unless you opt in.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall, .systemMedium])
    }
}

// MARK: - Focus timer Live Activity

private func pomodoroClock(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded(.up))
    return String(format: "%d:%02d", total / 60, total % 60)
}

private struct PomodoroTime: View {
    let state: PomodoroActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale {
            Text("0:00")
        } else if state.isPaused {
            Text(pomodoroClock(state.pausedRemaining))
        } else {
            Text(timerInterval: state.startDate...state.endDate, countsDown: true, showsHours: false)
        }
    }
}

private struct PomodoroLockScreenView: View {
    let state: PomodoroActivityAttributes.ContentState
    let isStale: Bool

    private var subtitle: String {
        if isStale { return "Time is up" }
        return state.isPaused ? "Paused" : "Anchor"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.isBreak ? "cup.and.saucer" : "timer")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.phaseTitle)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            PomodoroTime(state: state, isStale: isStale)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .padding()
    }
}

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            PomodoroLockScreenView(state: context.state, isStale: context.isStale)
        } dynamicIsland: { context in
            let icon = context.state.isBreak ? "cup.and.saucer" : "timer"
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.phaseTitle, systemImage: icon)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PomodoroTime(state: context.state, isStale: context.isStale)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: 90, alignment: .trailing)
                }
            } compactLeading: {
                Image(systemName: icon)
            } compactTrailing: {
                PomodoroTime(state: context.state, isStale: context.isStale)
                    .monospacedDigit()
                    .frame(width: 46)
            } minimal: {
                Image(systemName: icon)
            }
        }
    }
}
