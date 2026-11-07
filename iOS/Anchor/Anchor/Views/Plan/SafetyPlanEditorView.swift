//
//  SafetyPlanEditorView.swift
//  Anchor
//
//  Two screens: `SafetyPlanView` is what you read (in a hard moment, or just
//  to look at it); `SafetyPlanEditorView` is the form you write it in, only
//  reached from the Edit button.
//

import SwiftUI
import SwiftData

/// The safety plan as something to read: four calm cards, no text boxes.
struct SafetyPlanView: View {
    let plan: SafetyPlan
    @State private var showingEditor = false

    private var isEmpty: Bool {
        [plan.warningSignsText, plan.copingStrategiesText,
         plan.reasonsToKeepGoingText, plan.environmentSafetyStepsText]
            .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if isEmpty {
                    Anchor.EmptyState(
                        icon: "shield.fill",
                        title: "Your safety plan is empty",
                        message: "Write it once while you're calm, and it'll be here, ready to read, when you need it.",
                        actionTitle: "Start writing",
                        tint: Anchor.Theme.accent
                    ) { showingEditor = true }
                } else {
                    Anchor.TextCard(icon: "exclamationmark.triangle.fill", title: "Warning signs",
                                    text: plan.warningSignsText, tint: Anchor.Theme.accent)
                    Anchor.TextCard(icon: "leaf.fill", title: "Coping strategies",
                                    text: plan.copingStrategiesText, tint: Anchor.Theme.sage)
                    Anchor.TextCard(icon: "heart.fill", title: "Reasons to keep going",
                                    text: plan.reasonsToKeepGoingText, tint: Anchor.Theme.accent)
                    Anchor.TextCard(icon: "house.fill", title: "Making the environment safer",
                                    text: plan.environmentSafetyStepsText, tint: Anchor.Theme.sage)

                    Text("Last updated \(plan.lastEditedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Safety plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit safety plan") {
                SafetyPlanEditorView(plan: plan)
            }
        }
    }
}

struct SafetyPlanEditorView: View {
    @Bindable var plan: SafetyPlan

    var body: some View {
        Form {
            Section("Warning signs") {
                TextEditor(text: $plan.warningSignsText).frame(minHeight: 80)
            }
            Section("Coping strategies") {
                TextEditor(text: $plan.copingStrategiesText).frame(minHeight: 80)
            }
            Section {
                TextEditor(text: $plan.reasonsToKeepGoingText)
                    .frame(minHeight: 80)
            } header: {
                Text("Reasons to keep going")
            } footer: {
                Text("This is what your trigger-window notifications quote from. Always your own words, never generated.")
            }
            Section("Making the environment safer") {
                TextEditor(text: $plan.environmentSafetyStepsText).frame(minHeight: 80)
            }
        }
        .onChange(of: plan.warningSignsText) { _, _ in plan.lastEditedAt = .now }
        .onChange(of: plan.copingStrategiesText) { _, _ in plan.lastEditedAt = .now }
        .onChange(of: plan.reasonsToKeepGoingText) { _, _ in plan.lastEditedAt = .now }
        .onChange(of: plan.environmentSafetyStepsText) { _, _ in plan.lastEditedAt = .now }
    }
}
