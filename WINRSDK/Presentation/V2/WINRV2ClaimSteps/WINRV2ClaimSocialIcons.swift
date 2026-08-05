//
//  WINRV2ClaimSocialIcons.swift
//  WINRSDK
//
//  Simple white vector glyphs for the step-4 "Share on Social Media:" row
//  (Instagram / Facebook / X / Snapchat / TikTok), drawn in-code so the SDK
//  ships no third-party brand assets.
//

import SwiftUI

struct WINRSocialGlyph: View {
    enum Kind: CaseIterable {
        case instagram, facebook, x, snapchat, tiktok

        var displayName: String {
            switch self {
            case .instagram: return "Instagram"
            case .facebook: return "Facebook"
            case .x: return "X"
            case .snapchat: return "Snapchat"
            case .tiktok: return "TikTok"
            }
        }
    }

    let kind: Kind

    var body: some View {
        ZStack {
            switch kind {
            case .instagram: instagram
            case .facebook: facebook
            case .x: xGlyph
            case .snapchat: snapchat
            case .tiktok: tiktok
            }
        }
        .foregroundColor(.white)
    }

    /// Rounded square + lens + dot.
    private var instagram: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 3.2)
                .frame(width: 40, height: 40)
            Circle()
                .stroke(Color.white, lineWidth: 3.2)
                .frame(width: 19, height: 19)
            Circle()
                .fill(Color.white)
                .frame(width: 4.5, height: 4.5)
                .offset(x: 11.5, y: -11.5)
        }
    }

    /// White disc with the dark lowercase f.
    private var facebook: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
            Text("f")
                .font(.system(size: 33, weight: .bold, design: .rounded))
                .foregroundColor(WINRV2Color.deepCharcoal)
                .offset(x: 2, y: 4)
        }
        .clipShape(Circle().scale(44.0 / 48.0))
    }

    /// The sharp X wordmark, approximated with the system black weight.
    private var xGlyph: some View {
        Text("X")
            .font(.system(size: 40, weight: .black))
            .scaleEffect(x: 1.05, y: 0.95)
    }

    /// Ghost outline.
    private var snapchat: some View {
        WINRGhostShape()
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            .frame(width: 38, height: 38)
    }

    /// Musical note.
    private var tiktok: some View {
        Image(systemName: "music.note")
            .font(.system(size: 38, weight: .bold))
    }
}

/// A simplified Snapchat-style ghost: dome head, straight sides flaring into
/// little "arms", and a three-bump scalloped bottom.
struct WINRGhostShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        // Dome head.
        p.move(to: CGPoint(x: 0.18 * w, y: 0.42 * h))
        p.addQuadCurve(
            to: CGPoint(x: 0.82 * w, y: 0.42 * h),
            control: CGPoint(x: 0.5 * w, y: -0.28 * h)
        )
        // Right side down, flaring out.
        p.addLine(to: CGPoint(x: 0.82 * w, y: 0.62 * h))
        p.addQuadCurve(
            to: CGPoint(x: 0.97 * w, y: 0.86 * h),
            control: CGPoint(x: 0.86 * w, y: 0.78 * h)
        )
        // Scalloped bottom (three bumps).
        p.addQuadCurve(
            to: CGPoint(x: 0.66 * w, y: 0.88 * h),
            control: CGPoint(x: 0.82 * w, y: 0.98 * h)
        )
        p.addQuadCurve(
            to: CGPoint(x: 0.34 * w, y: 0.88 * h),
            control: CGPoint(x: 0.5 * w, y: 1.02 * h)
        )
        p.addQuadCurve(
            to: CGPoint(x: 0.03 * w, y: 0.86 * h),
            control: CGPoint(x: 0.18 * w, y: 0.98 * h)
        )
        // Left flare back up.
        p.addQuadCurve(
            to: CGPoint(x: 0.18 * w, y: 0.62 * h),
            control: CGPoint(x: 0.14 * w, y: 0.78 * h)
        )
        p.closeSubpath()
        return p
    }
}
