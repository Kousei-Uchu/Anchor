//
//  ContentView.swift
//  Anchor
//
//  Root tab container. Now is the default/first tab per spec. Journal gets
//  its own tab (not just an embedded expansion) so it can be opened directly
//  as "just write."
//

import SwiftUI
import MessageUI

// MARK: - Shared design system
//
// Anchor.Theme centralizes the warm, low-stimulation look used across every
// screen: soft warm neutrals, a terracotta accent (matches AccentColor),
// generous rounded cards instead of stock grouped lists, and calm
// typography. Kept here (rather than a new file) so the whole visual
// system lives in one place without needing project-file surgery to add
// a dedicated file.
enum Anchor {
    enum Theme {
        // Warm, soft palette. Built from raw values (not relying on
        // additional asset-catalog colors) so no extra project files are
        // needed beyond the AccentColor already in Assets.xcassets.
        static let accent = Color(red: 0.792, green: 0.475, blue: 0.373)      // warm terracotta
        static let accentSoft = Color(red: 0.792, green: 0.475, blue: 0.373).opacity(0.16)
        static let sage = Color(red: 0.58, green: 0.66, blue: 0.55)          // secondary/calm accent
        static let sageSoft = Color(red: 0.58, green: 0.66, blue: 0.55).opacity(0.18)

        static func background(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.11, green: 0.10, blue: 0.10)
                : Color(red: 0.985, green: 0.965, blue: 0.945)
        }

        static func cardBackground(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.17, green: 0.155, blue: 0.15)
                : Color.white
        }

        // Settings surfaces get their own, quieter palette: a cooler,
        // slightly darker greige page with flat rows, so crossing from
        // "things to read and reach" into "things to configure" is felt.
        static func settingsBackground(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.085, green: 0.08, blue: 0.08)
                : Color(red: 0.94, green: 0.925, blue: 0.91)
        }

        static func settingsRowBackground(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.15, green: 0.14, blue: 0.135)
                : Color.white
        }

        static let cornerRadius: CGFloat = 20
        static let spacing: CGFloat = 16
    }

    // MARK: Settings surfaces
    //
    // The rule: every screen is either READ (cards, big rounded numerals,
    // tiles; only actions like Log urge or Share) or CONFIGURE (grouped
    // flat rows, toggles, pickers, footers). Configure screens are only
    // reached through `GearButton`, and no toggle or time picker appears on
    // a read screen. These pieces are the configure side of that split.

    /// The one toolbar button that opens a settings surface, wherever it
    /// appears in the app. Outline gear, so it never competes with content.
    struct GearButton: View {
        var label: String = "Settings"
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(label)
        }
    }

    // MARK: Browse vs. edit
    //
    // Every content screen is a READ screen first: cards, big rounded type,
    // calm empty states, no text fields or reorder handles. Changing the
    // content is a separate, deliberate step: one `EditToolbarButton` in the
    // toolbar opens the editor as a sheet (`EditorSheet`, settings look).
    // Quick, in-the-moment actions (log, check in, mark done, call, run a
    // tool) stay on the read screen; they aren't "editing".

    /// The one "Edit" button used on read screens. Text, not an icon, so
    /// it's clearly a mode switch and never confused with the settings gear.
    struct EditToolbarButton: View {
        var label: String = "Edit"
        let action: () -> Void

        var body: some View {
            Button(label, action: action)
        }
    }

    /// Wraps an editor (a `Form`/`List`) for presentation as a sheet:
    /// its own navigation bar with a Done button, on the settings
    /// background, so editing looks and feels like a different place from
    /// browsing.
    struct EditorSheet<Content: View>: View {
        @Environment(\.dismiss) private var dismiss
        let title: String
        var onDone: (() -> Void)? = nil
        @ViewBuilder var content: () -> Content

        var body: some View {
            NavigationStack {
                content()
                    .anchorSettingsStyle()
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                onDone?()
                                dismiss()
                            }
                        }
                    }
            }
        }
    }

    /// Friendly empty state for a read screen, with an optional prompt that
    /// opens the editor ("Add someone").
    struct EmptyState: View {
        let icon: String
        let title: String
        let message: String
        var actionTitle: String? = nil
        var tint: Color = Theme.sage
        var action: (() -> Void)? = nil

        var body: some View {
            Card(accentColor: tint) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(tint.opacity(0.16)).frame(width: 52, height: 52)
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(tint)
                    }
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .buttonStyle(SecondaryButtonStyle(tint: tint))
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Read-only card for a block of the user's own words (a safety-plan
    /// section, a note). Shows a muted placeholder when empty.
    struct TextCard: View {
        let icon: String
        let title: String
        let text: String
        var placeholder: String = "Nothing added yet."
        var tint: Color = Theme.accent

        var body: some View {
            Card(accentColor: tint) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(icon: icon, title: title, tint: tint)
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        Text(placeholder)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(trimmed)
                            .font(.system(.body, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// A titled group of settings rows with an optional caption footer.
    /// Use inside a `Form`/`List` that has `.anchorSettingsStyle()`.
    struct SettingsSection<Content: View>: View {
        @Environment(\.colorScheme) private var scheme
        let title: String?
        var footer: String? = nil
        @ViewBuilder var content: () -> Content

        var body: some View {
            Section {
                Group { content() }
                    .listRowBackground(Theme.settingsRowBackground(scheme))
            } header: {
                if let title {
                    Text(title)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                }
            } footer: {
                if let footer {
                    Text(footer).font(.caption)
                }
            }
        }
    }

    /// Standard on/off row for settings screens.
    struct SettingsToggle: View {
        let title: String
        @Binding var isOn: Bool

        var body: some View {
            Toggle(isOn: $isOn) {
                Text(title).font(.system(.subheadline, design: .rounded))
            }
            .tint(Theme.accent)
        }
    }

    /// Standard time-of-day row for settings screens.
    struct SettingsTimeRow: View {
        var title: String = "Time"
        @Binding var time: Date

        var body: some View {
            DatePicker(selection: $time, displayedComponents: .hourAndMinute) {
                Text(title).font(.system(.subheadline, design: .rounded))
            }
        }
    }

    /// Warm rounded card used everywhere in place of stock `List`/plain
    /// stacked content, so screens read as a calm space rather than a
    /// settings menu.
    struct Card<Content: View>: View {
        @Environment(\.colorScheme) private var scheme
        var accentColor: Color = Theme.accent
        @ViewBuilder var content: () -> Content

        var body: some View {
            content()
                .padding(Theme.spacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .fill(Theme.cardBackground(scheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(accentColor.opacity(0.12), lineWidth: 1)
                )
        }
    }

    /// A row header with an icon in a soft tinted circle — used at the top
    /// of every card so screens have visual rhythm instead of plain
    /// `.headline` text everywhere.
    struct SectionHeader: View {
        let icon: String
        let title: String
        var tint: Color = Theme.accent

        var body: some View {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint.opacity(0.16)).frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.system(.headline, design: .rounded))
                Spacer()
            }
        }
    }

    /// Reusable label for menu-style NavigationLinks (Plan/Bridge/Thread),
    /// so those screens read as a warm set of destinations rather than a
    /// stock Settings-app list.
    struct MenuRow: View {
        let icon: String
        let title: String
        var subtitle: String? = nil
        var tint: Color = Theme.accent

        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .rounded))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Square tile, used for sub-screen navigation on dashboard-style
    /// screens (Plan, Bridge, Thread) instead of a plain list row —
    /// per feedback, a list of NavigationLinks reads as a settings menu
    /// even when the destination is a feature you'd want quick access to
    /// (decision presets, grounding tools, etc.), not configuration. A
    /// horizontal-scrolling row of these, grouped by theme, is meant to
    /// read the way Now's cards do: a dashboard of things to reach, not
    /// a settings list. Pure label — wrap in NavigationLink like MenuRow.
    struct TileButtonLabel: View {
        let icon: String
        let title: String
        var tint: Color = Theme.accent

        var body: some View {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 32)
            }
            // Widened from 64 (icon width, no slack) to 88 so two- and
            // three-word titles like "Decision presets" or "NSW mental
            // health law" actually get room to wrap onto two lines instead
            // of being clipped/truncated under a tile sized to the icon.
            .frame(width: 88)
        }
    }

    /// A themed, horizontally-scrolling row of tiles with a small
    /// section label above it — the building block for the dashboard
    /// layout on Plan/Bridge/Thread.
    struct TileRow<Content: View>: View {
        let title: String
        @ViewBuilder var content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        content()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
            }
        }
    }

    /// Warm filled button for primary actions (contacting someone, saving
    /// a check-in). Rounded and soft, never a stock system blue button.
    struct PrimaryButtonStyle: ButtonStyle {
        var tint: Color = Theme.accent
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(tint.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
                .foregroundStyle(.white)
        }
    }

    /// Softer secondary/pill button for template messages, smaller actions.
    struct SecondaryButtonStyle: ButtonStyle {
        var tint: Color = Theme.accent
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(tint.opacity(configuration.isPressed ? 0.24 : 0.14), in: Capsule())
                .foregroundStyle(tint)
        }
    }
}

extension View {
    /// Applies the app's warm scroll background consistently.
    func anchorBackground() -> some View {
        modifier(AnchorBackgroundModifier())
    }
}

extension View {
    /// Styles a `Form`/`List` as a configure surface: the quieter settings
    /// background and sage-leaning accent, instead of the warm card canvas.
    func anchorSettingsStyle() -> some View {
        modifier(AnchorSettingsStyleModifier())
    }
}

private struct AnchorSettingsStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Anchor.Theme.settingsBackground(scheme).ignoresSafeArea())
            .tint(Anchor.Theme.accent)
    }
}

private struct AnchorBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Anchor.Theme.background(scheme).ignoresSafeArea())
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var pendingWidgetAction: WidgetAction?
    @State private var showSettingsFromLink = false
    @State private var showOnboardingTour = !OnboardingState.hasSeenTour
    @StateObject private var notificationDelegate = NotificationDelegate.shared

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Anchor.Theme.background(.light)).withAlphaComponent(0.98)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(Anchor.Theme.accent)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NowView(openCheckInSignal: $notificationDelegate.shouldOpenCheckIn)
                .tabItem { Label("Now", systemImage: "sun.max.fill") }
                .tag(0)

            PlanView()
                .tabItem { Label("Plan", systemImage: "map.fill") }
                .tag(1)

            JournalView()
                .tabItem { Label("Journal", systemImage: "pencil.and.outline") }
                .tag(2)

            BridgeView()
                .tabItem { Label("Bridge", systemImage: "arrow.left.arrow.right") }
                .tag(3)

            ThreadView()
                .tabItem { Label("Thread", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(4)
        }
        .tint(Anchor.Theme.accent)
        .onOpenURL { url in
            // Widget deep links: anchor://plan/... , anchor://now,
            // anchor://action/... (an action that needs confirming inside
            // the app rather than performed directly from widget content —
            // see WidgetActionConfirmationView for why).
            guard url.scheme == "anchor" else { return }
            if url.host == "plan" {
                selectedTab = 1
            } else if url.host == "now" {
                selectedTab = 0
            } else if url.host == "settings" {
                showSettingsFromLink = true
            } else if url.host == "action" {
                if url.path == "/call" {
                    pendingWidgetAction = .call
                }
            }
        }
        .sheet(item: $pendingWidgetAction) { action in
            WidgetActionConfirmationView(action: action)
        }
        .sheet(isPresented: $showSettingsFromLink) {
            SettingsView()
        }
        .sheet(isPresented: $showOnboardingTour, onDismiss: {
            OnboardingState.hasSeenTour = true
        }) {
            OnboardingTourView()
        }
        .onChange(of: notificationDelegate.shouldOpenCheckIn) { _, shouldOpen in
            if shouldOpen { selectedTab = 0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .anchorOpenContactsInPlan)) { _ in
            // Switches to the Plan tab. Doesn't drill into Contacts
            // specifically — PlanView's NavigationStack doesn't have a
            // bound path to target sub-screens programmatically yet.
            selectedTab = 1
        }
        .sheet(item: $notificationDelegate.contactMessagePrompt) { prompt in
            if MFMessageComposeViewController.canSendText() {
                MessageComposeView(recipient: prompt.phoneNumber, body: "Hey, just wanted to check in.")
            } else {
                Text("This device can't send text messages.")
                    .padding()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(AnchorSchema.makeContainer())
}
