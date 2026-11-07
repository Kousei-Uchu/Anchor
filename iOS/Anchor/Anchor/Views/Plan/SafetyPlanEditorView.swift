//
//  SafetyPlanEditorView.swift
//  Anchor
//
//  One screen. `SafetyPlanView` is what you read (in a hard moment, or just
//  to look at it), and each card on it opens its own section in a sheet when
//  tapped. There is no Edit button and no separate form: the plan has four
//  fixed sections, so there is nothing to add or delete, only words to change.
//

import SwiftUI
import SwiftData

/// The four sections of the plan, with how each one looks and where its text
/// is stored.
private enum SafetyPlanSection: String, Identifiable, CaseIterable {
    case warningSigns
    case copingStrategies
    case reasonsToKeepGoing
    case environmentSafety

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warningSigns: return "Warning signs"
        case .copingStrategies: return "Coping strategies"
        case .reasonsToKeepGoing: return "Reasons to keep going"
        case .environmentSafety: return "Making the environment safer"
        }
    }

    var icon: String {
        switch self {
        case .warningSigns: return "exclamationmark.triangle.fill"
        case .copingStrategies: return "leaf.fill"
        case .reasonsToKeepGoing: return "heart.fill"
        case .environmentSafety: return "house.fill"
        }
    }

    var tint: Color {
        switch self {
        case .warningSigns, .reasonsToKeepGoing: return Anchor.Theme.accent
        case .copingStrategies, .environmentSafety: return Anchor.Theme.sage
        }
    }

    var footer: String? {
        switch self {
        case .reasonsToKeepGoing:
            return "This is what your trigger-window notifications quote from. Always your own words, never generated."
        default:
            return nil
        }
    }

    var keyPath: ReferenceWritableKeyPath<SafetyPlan, String> {
        switch self {
        case .warningSigns: return \.warningSignsText
        case .copingStrategies: return \.copingStrategiesText
        case .reasonsToKeepGoing: return \.reasonsToKeepGoingText
        case .environmentSafety: return \.environmentSafetyStepsText
        }
    }
}

/// The safety plan as something to read: four calm cards. Tap one to change it.
struct SafetyPlanView: View {
    let plan: SafetyPlan
    @State private var editingSection: SafetyPlanSection?

    private var isEmpty: Bool {
        SafetyPlanSection.allCases.allSatisfy {
            plan[keyPath: $0.keyPath].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
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
                    ) { editingSection = .warningSigns }
                } else {
                    ForEach(SafetyPlanSection.allCases) { section in
                        Button {
                            editingSection = section
                        } label: {
                            Anchor.TextCard(icon: section.icon, title: section.title,
                                            text: plan[keyPath: section.keyPath], tint: section.tint)
                                .overlay(alignment: .topTrailing) {
                                    Image(systemName: "pencil")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                        .padding(14)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the editor")
                    }

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
        .sheet(item: $editingSection) { section in
            SafetyPlanSectionEditor(plan: plan, section: section)
        }
    }
}

/// One section of the plan, in one sheet.
private struct SafetyPlanSectionEditor: View {
    let plan: SafetyPlan
    let section: SafetyPlanSection

    var body: some View {
        Anchor.ItemEditorSheet(title: section.title) {
            Form {
                Section {
                    TextEditor(text: Binding(
                        get: { plan[keyPath: section.keyPath] },
                        set: { newText in
                            plan[keyPath: section.keyPath] = newText
                            plan.lastEditedAt = .now
                        }
                    ))
                    .frame(minHeight: 220)
                } footer: {
                    if let footer = section.footer {
                        Text(footer)
                    }
                }
            }
        }
    }
}
