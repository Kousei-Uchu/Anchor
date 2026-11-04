//
//  ReframingPromptView.swift
//  Anchor
//
//  Entirely opt-in, entered deliberately from Bridge — never surfaced
//  automatically or during a check-in. A structured prompt, not an
//  analysis Anchor performs on the user's behalf: it asks the questions,
//  the user answers them in their own words.
//

import SwiftUI
import SwiftData

struct ReframingPromptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var thought = ""
    @State private var evidenceFor = ""
    @State private var evidenceAgainst = ""
    @State private var isFactOrPrediction = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("The thought") {
                    TextEditor(text: $thought).frame(minHeight: 60)
                }
                Section("Is this a fact (something you can verify happened or is true right now) or a prediction about what will happen?") {
                    Picker("", selection: $isFactOrPrediction) {
                        Text("Not sure yet").tag("")
                        Text("Fact").tag("Fact")
                        Text("Prediction").tag("Prediction")
                    }
                    .pickerStyle(.segmented)
                }
                Section("What supports it") {
                    TextEditor(text: $evidenceFor).frame(minHeight: 60)
                }
                Section("What doesn't fit it") {
                    TextEditor(text: $evidenceAgainst).frame(minHeight: 60)
                }
                Section {
                    Button("Save to Journal") {
                        let text = """
                        Reframing prompt
                        Thought: \(thought)
                        Fact or prediction: \(isFactOrPrediction.isEmpty ? "Not sure" : isFactOrPrediction)
                        Supports it: \(evidenceFor)
                        Doesn't fit: \(evidenceAgainst)
                        """
                        modelContext.insert(JournalEntry(text: text))
                        dismiss()
                    }
                    .disabled(thought.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Reframing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
