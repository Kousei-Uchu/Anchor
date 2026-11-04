//
//  MascotPresenceView.swift
//  Anchor
//
//  Purely a renderer. If MascotEngine returns nil (empty pool), the
//  character still shows (so it never reads as "broken" or empty-state),
//  it just has nothing to say. All dialogue text still comes only from
//  MascotEngine's pre-written pool — this file only draws the character
//  and the speech bubble, it never composes or alters what's said.
//
//  The character itself is drawn entirely with SwiftUI shapes/gradients
//  (no image asset needed, so nothing to add to the asset catalog or
//  project file). It's a soft rounded "anchor buddy" — a blob body with a
//  small anchor-shaped mark, big soft eyes, and a gentle idle breathing
//  animation so the screen doesn't feel static or like talking into
//  empty space.
//

import SwiftUI

struct MascotPresenceView: View {
    let line: MascotLine?
    var mood: MascotMood = .neutral

    @State private var breathe = false
    @State private var blink = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            MascotCharacterView(mood: mood, breathe: breathe, blink: blink)
                .frame(width: 64, height: 64)

            if let line {
                SpeechBubble {
                    Text(line.text)
                        .font(.system(.callout, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
            scheduleBlinks()
        }
    }

    private func scheduleBlinks() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: UInt64.random(in: 3_000_000_000...6_000_000_000))
                withAnimation(.easeInOut(duration: 0.12)) { blink = true }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeInOut(duration: 0.12)) { blink = false }
            }
        }
    }
}

/// The drawn character. A soft rounded body that gently "breathes" (scales
/// very slightly), two blinking eyes, and a small anchor glyph on its
/// chest so it reads as *Anchor's* companion specifically, not a generic
/// blob.
struct MascotCharacterView: View {
    var mood: MascotMood
    var breathe: Bool = false
    var blink: Bool = false

    private var bodyColor: Color {
        switch mood {
        case .gentle: return Anchor.Theme.sage
        case .quietDay: return Anchor.Theme.accent.opacity(0.7)
        case .encouragingNotPerformative: return Anchor.Theme.accent
        case .neutral: return Anchor.Theme.accent
        }
    }

    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [bodyColor.opacity(0.9), bodyColor.opacity(0.65)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .scaleEffect(breathe ? 1.04 : 0.98)

            // Two soft eyes
            HStack(spacing: 14) {
                eye
                eye
            }
            .offset(y: -4)

            // Small anchor glyph "chest mark"
            Image(systemName: "anchor")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .offset(y: 16)
        }
        .compositingGroup()
        .shadow(color: bodyColor.opacity(0.25), radius: 6, y: 4)
    }

    private var eye: some View {
        Capsule()
            .fill(.white)
            .frame(width: 7, height: blink ? 1.5 : 9)
    }
}

/// A simple speech-bubble container with a tail pointing toward the
/// mascot, so a line of text reads as *said by someone* rather than a
/// floating caption.
struct SpeechBubble<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                BubbleShape()
                    .fill(Anchor.Theme.cardBackground(scheme))
            )
            .overlay(
                BubbleShape()
                    .stroke(Anchor.Theme.accent.opacity(0.15), lineWidth: 1)
            )
    }
}

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 8
        var path = Path()
        let bubbleRect = CGRect(x: tailSize, y: 0, width: rect.width - tailSize, height: rect.height)
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: radius, height: radius))

        // Tail pointing left, roughly at vertical center-bottom (toward the
        // mascot character sitting to the left of the bubble).
        let tailY = rect.height * 0.72
        path.move(to: CGPoint(x: tailSize, y: tailY - 6))
        path.addLine(to: CGPoint(x: 0, y: tailY))
        path.addLine(to: CGPoint(x: tailSize, y: tailY + 6))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        MascotPresenceView(line: MascotLine(trigger: .appOpen, mood: .neutral, text: "Hey. I'm here."))
        MascotCharacterView(mood: .gentle)
            .frame(width: 100, height: 100)
    }
    .padding()
}
