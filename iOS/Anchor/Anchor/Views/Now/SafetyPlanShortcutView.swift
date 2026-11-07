//
//  SafetyPlanShortcutView.swift
//  Anchor
//
//  One-tap route into the safety plan from Now — in a hard moment, this
//  shouldn't require remembering it lives under Plan → Safety plan.
//

import SwiftUI
import SwiftData

struct SafetyPlanShortcutView: View {
    var body: some View {
        NavigationLink {
            SafetyPlanView()
        } label: {
            Anchor.Card {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Anchor.Theme.accent.opacity(0.16)).frame(width: 34, height: 34)
                        Image(systemName: "shield.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Anchor.Theme.accent)
                    }
                    Text("Open my safety plan")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
