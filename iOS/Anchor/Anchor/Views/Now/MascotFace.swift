//
//  MascotFace.swift
//  Anchor
//

import SwiftUI

enum MascotExpression {
    case happy       // :D
    case smile       // :)
    case sad         // :(
    case cute        // :3
    case worried     // D:
    case playful     // :P
    case angry       // >:(
    case mischievous // >:)
    case unsure      // :/
    case concerned   // :,/
}

struct FaceParameters {
    var eyeHeight: CGFloat
    var eyeWidth: CGFloat
    var eyeRotation: Angle

    var browAngle: Angle
    var browHeight: CGFloat

    var mouthCurve: CGFloat
    var mouthWidth: CGFloat
    var mouthOpen: CGFloat
}

extension MascotExpression {
    var parameters: FaceParameters {
        switch self {

        case .happy:
            return FaceParameters(
                eyeHeight: 9,
                eyeWidth: 7,
                eyeRotation: .zero,
                browAngle: .degrees(-10),
                browHeight: -15,
                mouthCurve: 1,
                mouthWidth: 18,
                mouthOpen: 7
            )

        case .sad:
            return FaceParameters(
                eyeHeight: 7,
                eyeWidth: 7,
                eyeRotation: .degrees(8),
                browAngle: .degrees(15),
                browHeight: -14,
                mouthCurve: -1,
                mouthWidth: 15,
                mouthOpen: 0
            )

        case .cute:
            return FaceParameters(
                eyeHeight: 11,
                eyeWidth: 8,
                eyeRotation: .zero,
                browAngle: .degrees(-5),
                browHeight: -16,
                mouthCurve: 0.4,
                mouthWidth: 12,
                mouthOpen: 2
            )

        case .worried:
            return FaceParameters(
                eyeHeight: 11,
                eyeWidth: 7,
                eyeRotation: .zero,
                browAngle: .degrees(20),
                browHeight: -17,
                mouthCurve: -0.4,
                mouthWidth: 12,
                mouthOpen: 3
            )

        case .playful:
            return FaceParameters(
                eyeHeight: 8,
                eyeWidth: 7,
                eyeRotation: .zero,
                browAngle: .degrees(-15),
                browHeight: -15,
                mouthCurve: 0,
                mouthWidth: 14,
                mouthOpen: 5
            )

        case .angry:
            return FaceParameters(
                eyeHeight: 6,
                eyeWidth: 7,
                eyeRotation: .zero,
                browAngle: .degrees(-25),
                browHeight: -15,
                mouthCurve: -0.2,
                mouthWidth: 15,
                mouthOpen: 2
            )

        case .mischievous:
            return FaceParameters(
                eyeHeight: 8,
                eyeWidth: 7,
                eyeRotation: .degrees(-5),
                browAngle: .degrees(-15),
                browHeight: -16,
                mouthCurve: 0.8,
                mouthWidth: 16,
                mouthOpen: 3
            )

        case .unsure:
            return FaceParameters(
                eyeHeight: 8,
                eyeWidth: 7,
                eyeRotation: .degrees(5),
                browAngle: .degrees(5),
                browHeight: -15,
                mouthCurve: 0,
                mouthWidth: 10,
                mouthOpen: 0
            )

        case .concerned:
            return FaceParameters(
                eyeHeight: 8,
                eyeWidth: 7,
                eyeRotation: .degrees(5),
                browAngle: .degrees(15),
                browHeight: -15,
                mouthCurve: -0.2,
                mouthWidth: 13,
                mouthOpen: 1
            )

        case .smile:
            return FaceParameters(
                eyeHeight: 8,
                eyeWidth: 7,
                eyeRotation: .zero,
                browAngle: .degrees(-5),
                browHeight: -15,
                mouthCurve: 0.7,
                mouthWidth: 16,
                mouthOpen: 0
            )
        }
    }
}


struct MascotEye: View {
    let params: FaceParameters
    let blink: Bool

    var body: some View {
        Capsule()
            .fill(.white)
            .frame(
                width: params.eyeWidth,
                height: blink ? 1 : params.eyeHeight
            )
            .rotationEffect(params.eyeRotation)
            .animation(.spring(duration: 0.25), value: blink)
    }
}


struct MascotBrow: View {
    let params: FaceParameters

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.9))
            .frame(width: 10, height: 2)
            .rotationEffect(params.browAngle)
    }
}


struct MascotMouth: Shape {
    var curve: CGFloat
    var open: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            AnimatablePair(curve, open)
        }
        set {
            curve = newValue.first
            open = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if open > 1 {
            path.addRoundedRect(
                in: CGRect(
                    x: rect.minX,
                    y: rect.midY - open / 2,
                    width: rect.width,
                    height: open
                ),
                cornerSize: CGSize(
                    width: open,
                    height: open
                )
            )
        } else {
            path.move(
                to: CGPoint(
                    x: rect.minX,
                    y: rect.midY
                )
            )

            path.addQuadCurve(
                to: CGPoint(
                    x: rect.maxX,
                    y: rect.midY
                ),
                control: CGPoint(
                    x: rect.midX,
                    y: rect.midY + curve * 8
                )
            )
        }

        return path
    }
}
