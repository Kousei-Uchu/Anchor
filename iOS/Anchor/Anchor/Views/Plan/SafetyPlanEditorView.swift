//
//  SafetyPlanEditorView.swift
//  Anchor
//

import SwiftUI
import SwiftData

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
        .navigationTitle("Safety plan")
        .onChange(of: plan.warningSignsText) { _, _ in plan.lastEditedAt = .now }
        .onChange(of: plan.copingStrategiesText) { _, _ in plan.lastEditedAt = .now }
        .onChange(of: plan.reasonsToKeepGoingText) { _, _ in plan.lastEditedAt = .now }
        .onChange(of: plan.environmentSafetyStepsText) { _, _ in plan.lastEditedAt = .now }
    }
}
