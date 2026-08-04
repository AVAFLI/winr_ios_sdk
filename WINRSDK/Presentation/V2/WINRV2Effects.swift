//
//  WINRV2Effects.swift
//  WINRSDK
//
//  Motion for the V2 experience: Joe's ACTUAL Figma animation files (bundled
//  GIFs, played via WINRV2GifView) for the Day 2+ reveal beat, plus native
//  SwiftUI confetti/checkmark/glow used by the modals and toast bar.
//

import SwiftUI
import ImageIO

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

// MARK: - Bundled GIF playback (Joe's Figma animation files)

/// A decoded, downsampled GIF: frames + the per-frame start times from the
/// file's own delay table. Decoding a 1500×1500 47-frame GIF takes hundreds
/// of milliseconds, so assets are cached and can be prewarmed off-main
/// BEFORE the reveal beat needs them.
final class WINRV2GifAsset {
    let frames: [UIImage]
    /// Cumulative start time (seconds) of each frame.
    let starts: [Double]
    let duration: Double

    private init?(url: URL, maxPixelSize: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        var frames: [UIImage] = []
        var starts: [Double] = []
        var t: Double = 0
        for index in 0..<count {
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { continue }
            frames.append(UIImage(cgImage: cg))
            starts.append(t)
            t += Self.delay(source: source, index: index)
        }
        guard !frames.isEmpty else { return nil }
        self.frames = frames
        self.starts = starts
        self.duration = t
    }

    /// Frame for `time` seconds into playback. Past the end: the LAST frame
    /// (one-shot playback freezes on it) unless `loops`.
    func frame(at time: Double, loops: Bool) -> UIImage {
        var t = time
        if loops, duration > 0 { t = t.truncatingRemainder(dividingBy: duration) }
        guard t < duration else { return frames[frames.count - 1] }
        var index = 0
        for (i, start) in starts.enumerated() where start <= t { index = i }
        return frames[index]
    }

    private static func delay(source: CGImageSource, index: Int) -> Double {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? 0
        let d = unclamped > 0.011 ? unclamped : (gif[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1)
        return max(d, 0.02)
    }

    // MARK: Cache

    private static let lock = NSLock()
    private static var cache: [String: WINRV2GifAsset] = [:]
    private static let decodeQueue = DispatchQueue(label: "com.winr.gif-decode", qos: .userInitiated)

    static func cached(_ name: String) -> WINRV2GifAsset? {
        lock.lock(); defer { lock.unlock() }
        return cache[name]
    }

    /// Decode into the cache off-main so a later mount plays instantly.
    static func prewarm(_ name: String) {
        decodeQueue.async { _ = load(name) }
    }

    /// Cached load; decodes synchronously on a miss.
    static func load(_ name: String) -> WINRV2GifAsset? {
        if let hit = cached(name) { return hit }
        guard let url = Bundle.module.url(forResource: name, withExtension: "gif"),
              let asset = WINRV2GifAsset(url: url, maxPixelSize: 600) else { return nil }
        lock.lock(); cache[name] = asset; lock.unlock()
        return asset
    }
}

/// Plays a bundled GIF ONCE, starting exactly when the view mounts, honoring
/// the file's own per-frame delays. After the last frame it HOLDS there
/// (frozen, still rendered) — it does not disappear. `loops: true` opts into
/// continuous looping instead.
struct WINRV2GifView: View {
    let name: String
    var loops: Bool = false
    var onFinished: (() -> Void)? = nil

    @State private var asset: WINRV2GifAsset?
    @State private var startDate = Date()
    @State private var finished = false

    init(_ name: String, loops: Bool = false, onFinished: (() -> Void)? = nil) {
        self.name = name
        self.loops = loops
        self.onFinished = onFinished
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: finished)) { context in
            Group {
                if let asset {
                    Image(uiImage: asset.frame(at: context.date.timeIntervalSince(startDate), loops: loops))
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
        }
        .onAppear {
            // Mount IS the beat: the playback clock starts now, even if the
            // frames are still decoding (prewarming makes that a non-event).
            startDate = Date()
            if let hit = WINRV2GifAsset.cached(name) {
                begin(with: hit)
            } else {
                DispatchQueue.global(qos: .userInitiated).async {
                    let loaded = WINRV2GifAsset.load(name)
                    DispatchQueue.main.async {
                        guard let loaded, asset == nil else { return }
                        begin(with: loaded)
                    }
                }
            }
        }
    }

    private func begin(with loaded: WINRV2GifAsset) {
        asset = loaded
        guard !loops else { return }
        // Freeze the timeline on the held last frame once playback completes,
        // measured against the mount clock so a slow decode can't stretch it.
        let remaining = max(0, loaded.duration - Date().timeIntervalSince(startDate))
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
            finished = true
            onFinished?()
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
