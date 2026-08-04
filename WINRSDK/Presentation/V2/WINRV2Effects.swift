//
//  WINRV2Effects.swift
//  WINRSDK
//
//  Motion for the V2 experience, matched to Joe's Figma prototype GIFs:
//  confetti fields/bursts, the draw-on white checkmark, and the pulsing
//  glow on the active streak tile. Everything is native SwiftUI (no GIFs)
//  so it stays crisp at any scale and respects the publisher accent.
//

import SwiftUI

// MARK: - Confetti

/// A looping confetti field. `style` picks the palette: `.celebration` is the
/// multicolor sprinkle from the claim/celebration modals and streak tiles;
/// `.gold` is the winner-modal gold sparkle.
struct WINRV2ConfettiView: View {
    enum Style { case celebration, gold }

    var style: Style = .celebration
    var count: Int = 42
    /// Continuous drift when true (dashboard accents); one-shot-feel flutter
    /// stays looping either way — Joe's GIFs loop too.
    var speed: Double = 1

    private static let celebrationPalette: [Color] = [
        Color(red: 0.96, green: 0.31, blue: 0.28), // red
        Color(red: 0.35, green: 0.78, blue: 0.42), // green
        Color(red: 0.30, green: 0.62, blue: 0.99), // blue
        Color(red: 0.99, green: 0.80, blue: 0.28), // yellow
        Color(red: 0.72, green: 0.52, blue: 0.96), // purple
    ]
    private static let goldPalette: [Color] = [
        Color(red: 1.00, green: 0.84, blue: 0.35),
        Color(red: 0.94, green: 0.70, blue: 0.18),
        Color(red: 1.00, green: 0.93, blue: 0.66),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate * speed
                let palette = style == .celebration ? Self.celebrationPalette : Self.goldPalette
                for i in 0..<count {
                    // Deterministic per-particle parameters (no Math.random —
                    // stable across frames).
                    let seed = Double(i)
                    let fx = fract(seed * 0.61803398875)          // 0..1 x anchor
                    let fall = 8.0 + fract(seed * 0.7548776662) * 7.0   // fall period s
                    let phase = fract(seed * 0.2928932188)
                    let progress = fract(t / fall + phase)        // 0..1 down screen
                    let sway = sin((t * 1.7) + seed * 1.3) * 9.0
                    let x = fx * size.width + sway
                    let y = progress * (size.height + 24) - 12
                    let rotation = Angle.radians(t * 2.1 + seed)
                    let w = 4.0 + fract(seed * 0.833) * 4.0
                    let h = w * (0.55 + fract(seed * 0.377) * 0.5)
                    let alpha = style == .gold ? 0.55 + fract(seed * 0.51) * 0.45 : 0.9

                    var particle = context
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: rotation)
                    // Flutter: squash on one axis as the piece "tumbles".
                    let squash = 0.35 + abs(sin(t * 2.6 + seed * 2.0)) * 0.65
                    particle.scaleBy(x: 1, y: squash)
                    particle.opacity = alpha
                    particle.fill(
                        Path(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: 1),
                        with: .color(palette[i % palette.count])
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func fract(_ v: Double) -> Double { v - v.rounded(.down) }
}

// MARK: - Animated checkmark (draw-on)

/// The white circle-check from Joe's modals: the circle sweeps in, then the
/// check strokes on. Replaces the static GIF frame.
struct WINRV2AnimatedCheckmark: View {
    var lineWidth: CGFloat = 7
    @State private var circleProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            CheckShape()
                .trim(from: 0, to: checkProgress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) { circleProgress = 1 }
            withAnimation(.easeOut(duration: 0.35).delay(0.4)) { checkProgress = 1 }
        }
    }

    /// Check glyph matching the design: starts left-center, dips to the low
    /// point, kicks up past the circle's top-right edge.
    private struct CheckShape: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.width * 0.26, y: rect.height * 0.54))
            p.addLine(to: CGPoint(x: rect.width * 0.45, y: rect.height * 0.72))
            p.addLine(to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.22))
            return p
        }
    }
}

// MARK: - Pulsing glow (active streak tile)

struct WINRV2PulseGlow: ViewModifier {
    let accent: Color
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .shadow(color: accent.opacity(pulsing ? 0.95 : 0.55), radius: pulsing ? 14 : 7)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

extension View {
    /// Joe's active-tile treatment: the accent glow breathes.
    func winrPulseGlow(_ accent: Color) -> some View {
        modifier(WINRV2PulseGlow(accent: accent))
    }
}
