//
//  WINRV2Components.swift
//  WINRSDK
//
//  Reusable pieces of the V2 experience, matched to Joe's Figma components:
//  TOP UI header, Cash/Prize tile, STREAK STEP rail, CONFIRMATION bar, CTA.
//

import SwiftUI

// MARK: - Drawer chrome

/// The little grab handle at the top of the drawer (Figma "TAB").
struct WINRV2TabGrabber: View {
    var body: some View {
        Capsule()
            .fill(Color.white.opacity(0.4))
            .frame(width: 51, height: 5)
    }
}

/// TOP UI: "?" circle • publisher logo • "X" circle.
/// The logo is one of the three publisher-configurable elements.
struct WINRV2Header: View {
    let logoUrl: String?
    var showsBack = false
    var onBack: () -> Void = {}
    let onInfo: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            circleButton(action: showsBack ? onBack : onInfo) {
                if showsBack {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                } else {
                    Text("?")
                        .font(WINRV2Font.inter(16))
                        .foregroundColor(.white)
                }
            }
            Spacer()
            logo
                .frame(height: 60)
                .frame(maxWidth: 210)
            Spacer()
            circleButton(action: onClose) {
                Image("winr-close", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var logo: some View {
        if let logoUrl, !logoUrl.isEmpty, URL(string: logoUrl) != nil {
            // Normally already decoded by WINRV2ImageWarmer (warmed the moment
            // the SDK learned the branding config), so it paints with the rest
            // of the header. Placeholder is CLEAR here — the header sits on
            // gunmetal and a dark block would read as a missing logo.
            WINRV2RemoteImage(url: logoUrl, contentMode: .fit, placeholderColor: .clear) {
                Color.clear
            }
        } else {
            Text("WINR")
                .font(WINRV2Font.inter(28, .black))
                .foregroundColor(.white)
        }
    }

    private func circleButton<Content: View>(action: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        Button(action: action) {
            content()
                .frame(width: 36, height: 36)
                .background(Circle().fill(WINRV2Color.deepCharcoal))
        }
        .buttonStyle(.plain)
    }
}

/// The radial primary-color glow that bleeds from the top of the drawer into gunmetal.
struct WINRV2TopGlow: View {
    let accent: Color
    var body: some View {
        RadialGradient(
            stops: [
                .init(color: accent, location: 0),
                .init(color: accent.opacity(0.55), location: 0.35),
                .init(color: WINRV2Color.gunmetal.opacity(0.9), location: 0.8),
                .init(color: WINRV2Color.gunmetal, location: 1),
            ],
            center: .top,
            startRadius: 0,
            endRadius: 440
        )
        .opacity(0.9)
    }
}

// MARK: - Prize presentation

/// Day 2+ prize card (Joe's Aug-2026 dark full-bleed revision): the prize art
/// fills the WHOLE card, a solid black stats strip (streak + total entries)
/// sits inside the top edge, and the prize-derived headline rides the bottom
/// over a black→transparent scrim. The image is publisher-configurable
/// (prizeImageUrl); default is the bundled cash pile.
struct WINRV2PrizeCard: View {
    let accent: Color
    let streakDay: Int
    let totalEntries: Int
    let prizeImageUrl: String?
    let prizeValue: Int
    let prizeDescription: String
    var visitMode = false

    /// Cash prizes render Joe's right-aligned "WIN $1,000 / CASH PRIZE" lockup;
    /// other prizes render "Win a {Prize}" + "$X.00 VALUE!".
    private var isCashPrize: Bool {
        WINRV2PrizeText.isCash(description: prizeDescription)
    }

    var body: some View {
        Color.clear
            .frame(height: 200)
            .background(hero)
            .clipped()
            .overlay(alignment: .top) { statsStrip }
            .overlay(alignment: .bottom) { headline }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var hero: some View {
        if let prizeImageUrl, !prizeImageUrl.isEmpty, URL(string: prizeImageUrl) != nil {
            // Normally already decoded by WINRV2ImageWarmer (warmed the moment
            // the SDK learned the giveaway config), so it paints with the rest
            // of the card. A cold URL fades in over the card's dark background
            // instead of popping, and a broken one falls back to the bundled
            // cash hero.
            WINRV2RemoteImage(
                url: prizeImageUrl,
                contentMode: .fill,
                placeholderColor: WINRV2Color.deepCharcoal
            ) {
                bundledHero
            }
        } else {
            bundledHero
        }
    }

    private var bundledHero: some View {
        WINRV2Asset.cashHero
            .resizable()
            .scaledToFill()
    }

    /// Solid black strip inside the top of the card: accent title + white sub.
    private var statsStrip: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image("winr-flame", bundle: .module)
                    .resizable().scaledToFit()
                    .frame(width: 18, height: 22)
                    .foregroundColor(accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(streakDay) \(visitMode ? "VISIT" : "DAY") STREAK")
                        .font(WINRV2Font.inter(15, .black))
                        .kerning(-0.3)
                        .foregroundColor(accent)
                        // The reveal beat runs inside a spring transaction,
                        // which would CROSSFADE this label ("1 DAY" ghosting
                        // over "2 DAY" for a quarter second while the total is
                        // already counting). The flip must be hard — one beat.
                        .transaction { $0.animation = nil }
                    Text("Keep it going!")
                        .font(WINRV2Font.inter(12, .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Image("winr-ticket", bundle: .module)
                    .resizable().scaledToFit()
                    .frame(width: 22, height: 15)
                    .rotationEffect(.degrees(-25))
                    .foregroundColor(accent)
                VStack(alignment: .leading, spacing: 0) {
                    WINRV2CountUpText(value: totalEntries, accent: accent)
                    Text("Total Entries")
                        .font(WINRV2Font.inter(12, .medium))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 46)
        .background(Color.black)
    }

    /// Prize headline over the bottom scrim.
    private var headline: some View {
        Group {
            if isCashPrize {
                // "WIN $1,000" (Black 44) over "CASH PRIZE" (Black 19), right-aligned.
                VStack(alignment: .trailing, spacing: -5) {
                    Text("WIN $\(prizeValue.formatted())")
                        .font(WINRV2Font.inter(44, .black))
                        .kerning(-2.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("CASH PRIZE")
                        .font(WINRV2Font.inter(19, .black))
                        .kerning(-0.57)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                // Centered "Win a {Prize}" + accent "$X.00 VALUE!".
                VStack(spacing: 0) {
                    Text("Win \(WINRV2PrizeText.article(for: prizeDescription)) \(prizeDescription)")
                        .font(WINRV2Font.inter(28, .black))
                        .kerning(-1.0)
                        .lineLimit(2)
                        .minimumScaleFactor(0.55)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    if WINRV2PrizeText.showsValueLine(description: prizeDescription, value: prizeValue) {
                        Text("$\(prizeValue.formatted()).00 VALUE!")
                            .font(WINRV2Font.inter(15, .black))
                            .foregroundColor(accent)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 34)
        .padding(.bottom, 10)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0),
                    .init(color: .black.opacity(0.55), location: 0.45),
                    .init(color: .black.opacity(0.9), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

// MARK: - Streak rail (STREAK STEP + MILESTONE tiles)

struct WINRV2RailEntry: Identifiable {
    enum Kind {
        case day(day: Int, entries: Int, state: TileState)
        case powerUp(label: String, bonus: Int, footnote: String)
    }
    /// `ready` = today's tile before the user taps CLAIM (claim already granted
    /// server-side, reveal withheld): glows like `active` but shows no checkmark.
    enum TileState { case completed, active, ready, locked }
    let id: String
    let kind: Kind
}

struct WINRV2StreakRail: View {
    let accent: Color
    let entries: [WINRV2RailEntry]
    let activeID: String?
    var visitMode = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(entries) { entry in
                        // The "DAILY PROGRESS ▾" pointer rides ABOVE the current
                        // tile (Joe's Progress Pointer) and scrolls with it.
                        VStack(spacing: 0) {
                            pointer(visible: entry.id == activeID)
                            tile(for: entry)
                        }
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .onAppear {
                guard let activeID else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(activeID, anchor: .center)
                    }
                }
            }
        }
    }

    private func pointer(visible: Bool) -> some View {
        VStack(spacing: -6) {
            Text(visitMode ? "PROGRESS" : "DAILY PROGRESS")
                .font(WINRV2Font.oswald(12))
                .foregroundColor(.white)
                .fixedSize()
            Image("winr-arrow-down", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: 10, height: 6)
                .foregroundColor(.white)
                .padding(.top, 8)
        }
        .padding(.bottom, 8)
        .opacity(visible ? 1 : 0)
    }

    @ViewBuilder private func tile(for entry: WINRV2RailEntry) -> some View {
        switch entry.kind {
        case let .day(day, entries, state):
            WINRV2StreakTile(accent: accent, day: day, entries: entries, state: state, visitMode: visitMode)
        case let .powerUp(label, bonus, footnote):
            WINRV2PowerUpTile(accent: accent, label: label, bonus: bonus, footnote: footnote)
        }
    }
}

struct WINRV2StreakTile: View {
    let accent: Color
    let day: Int
    let entries: Int
    let state: WINRV2RailEntry.TileState
    var visitMode = false

    /// One-shot: the confetti-burst GIF plays over the tile when it flips
    /// .ready → .active at the reveal beat, then removes itself. A tile that
    /// MOUNTS as .active (already-claimed reopen) never bursts.
    @State private var bursting = false

    private var noun: String { visitMode ? "VISIT" : "DAY" }

    var body: some View {
        tileBody
            .onChange(of: state) { newState in
                if newState == .active { bursting = true }
            }
    }

    @ViewBuilder private var tileBody: some View {
        switch state {
        case .active:
            // Joe's settled active tile: breathing glow, drifting confetti
            // field, and the small check drawing into the icon slot. At the
            // reveal beat the confetti-burst GIF explodes once on top,
            // overflowing the tile, then is removed (see `bursting`).
            card
                .winrPulseGlow(accent)
                .background(
                    WINRV2ConfettiView(style: .celebration, count: 12, speed: 0.7)
                        .frame(width: 152, height: 176)
                )
                .overlay {
                    if bursting {
                        WINRV2GifView("confetti-burst", onFinished: { bursting = false })
                            .frame(width: 200, height: 200)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
        case .ready:
            // Pre-reveal the tile is CALM — a static glow only. Every moving
            // element (pulse, confetti, check draw) is saved for the single
            // celebration moment so nothing animates early.
            card.shadow(color: accent.opacity(0.75), radius: 10)
        default:
            card
        }
    }

    private var card: some View {
        VStack(spacing: 4) {
            Text(day >= 31 ? "\(noun) 31 +" : "\(noun) \(day)")
                .font(WINRV2Font.inter(12, .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black))
            VStack(spacing: -2) {
                Text(entries.formatted())
                    .font(WINRV2Font.inter(30, .black))
                    .kerning(-1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(numberColor)
                Text("ENTRIES")
                    .font(WINRV2Font.inter(15, .bold))
                    .foregroundColor(labelColor)
            }
            iconView
                .frame(width: 24, height: 24)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 3)
        .frame(width: 106, height: 134)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent, lineWidth: 2)
        )
        .cornerRadius(10)
    }

    private var numberColor: Color {
        switch state {
        case .completed: return accent
        case .active, .ready: return .white
        case .locked: return WINRV2Color.foregroundSecondary
        }
    }

    private var labelColor: Color {
        state == .locked ? WINRV2Color.foregroundSecondary : .white
    }

    @ViewBuilder private var background: some View {
        if state == .active || state == .ready {
            RadialGradient(
                stops: [
                    .init(color: accent, location: 0),
                    .init(color: accent.opacity(0.45), location: 0.45),
                    .init(color: WINRV2Color.gunmetal, location: 1),
                ],
                center: .top, startRadius: 0, endRadius: 150
            )
        } else {
            WINRV2Color.gunmetal
        }
    }

    @ViewBuilder private var iconView: some View {
        switch state {
        case .completed:
            WINRV2Asset.checkTileCompleted.resizable().scaledToFit().frame(width: 20, height: 20)
        case .active:
            WINRV2AnimatedCheckmark(lineWidth: 2.5)
                .frame(width: 20, height: 20)
        case .ready:
            // Joe's frames: the current tile pre-check shows ONLY the glowing
            // number — no icon. The slot keeps its height so the check can
            // draw into place without the card resizing.
            Color.clear.frame(width: 20, height: 20)
        case .locked:
            Image("winr-lock", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: 16, height: 20)
                .foregroundColor(labelColor)
        }
    }
}

/// The joined "STREAK BONUS!" accelerator tile (Figma MILESTONE TILE right half).
struct WINRV2PowerUpTile: View {
    let accent: Color
    let label: String       // e.g. "1 WEEK"
    let bonus: Int          // e.g. 25
    let footnote: String    // e.g. "STARTING TOMORROW"

    var body: some View {
        VStack(spacing: 0) {
            Image("winr-flame", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: 18, height: 24)
                .foregroundColor(.white)
            Spacer(minLength: 4)
            VStack(spacing: 7) {
                Text("\(label)\nSTREAK BONUS!")
                    .font(WINRV2Font.inter(9, .bold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(0)
                VStack(spacing: -2) {
                    Text("+\(bonus)")
                        .font(WINRV2Font.inter(26, .black))
                        .kerning(-0.8)
                    Text("EVERY DAY!")
                        .font(WINRV2Font.inter(14, .black))
                }
                Text(footnote)
                    .font(WINRV2Font.oswald(8, bold: true))
            }
            .foregroundColor(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 3)
        .frame(width: 106, height: 134)
        .background(accent)
        .cornerRadius(10)
    }
}

// MARK: - Confirmation ("come back tomorrow") bar

struct WINRV2ComeBackBar: View {
    let accent: Color
    let nextEntries: Int
    var visitMode = false
    /// Celebration open (auto-claim, any day): the bar's FIRST visible frame
    /// is the toast — "YOU'RE IN!" on Day 1, "YOU'RE ON A ROLL!" on Day 2+.
    /// It holds ~2.5s, then slides ONCE (carousel: out left, in from right) to
    /// the resting pitch — the pitch is NEVER visible before the toast on a
    /// celebration open. Non-celebration opens (already-claimed reopen, no
    /// grant) rest on the pitch, no toast.
    let celebrating: Bool
    /// Day 1 (brand-new or restarted streak): the toast headline reads
    /// "YOU'RE IN!"; the subline is identical across days.
    let firstDay: Bool
    let claimedEntries: Int

    private enum Phase { case toast, pitch }
    @State private var phase: Phase
    /// One-shot guard: the toast plays exactly once per bar, whether it was
    /// seeded at init or arrived late.
    @State private var toastPlayed = false

    init(
        accent: Color,
        nextEntries: Int,
        visitMode: Bool = false,
        celebrating: Bool = false,
        firstDay: Bool = false,
        claimedEntries: Int = 0
    ) {
        self.accent = accent
        self.nextEntries = nextEntries
        self.visitMode = visitMode
        self.celebrating = celebrating
        self.firstDay = firstDay
        self.claimedEntries = claimedEntries
        // The toast must be the bar's first frame — no pitch flash, no
        // slide-in. Only the toast → pitch handoff ever animates.
        _phase = State(initialValue: celebrating ? .toast : .pitch)
    }

    var body: some View {
        ZStack {
            // Carousel: the outgoing state slides OUT to the left, the
            // incoming one IN from the right — one forward direction.
            switch phase {
            case .toast:
                toastContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            case .pitch:
                comeBackContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 71)
        .background(Color.black)
        .clipped()
        // Joe's toast has celebratory sprinkles drifting over the reward line.
        .overlay(WINRV2ConfettiView(style: .celebration, count: 10, speed: 0.55).clipped())
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: phase)
        .onAppear {
            guard phase == .toast, !toastPlayed else { return }
            startHold()
        }
        .onChange(of: celebrating) { nowCelebrating in
            // Cache-first render: the dashboard now paints from cached values
            // while the network resolves, so the bar can MOUNT before the claim
            // has been staged. When the celebration arrives a moment later the
            // toast slides in from the right (the carousel's normal forward
            // direction) instead of being missed entirely — and, via
            // `toastPlayed`, never twice.
            guard nowCelebrating, !toastPlayed else { return }
            phase = .toast
            startHold()
        }
    }

    /// Hold the toast a beat, then slide once to the resting pitch.
    private func startHold() {
        toastPlayed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            phase = .pitch
        }
    }

    private var comeBackContent: some View {
        HStack(spacing: 14) {
            Image("winr-calendar", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: 26, height: 28)
                .foregroundColor(accent)
            VStack(spacing: 1) {
                // "Come back tomorrow"/"Come back again" is BOLD, the rest
                // regular — per Joe's banner lockup.
                (visitMode
                    ? Text("Come back again").font(WINRV2Font.inter(12, .bold))
                      + Text(" to receive:").font(WINRV2Font.inter(12))
                    : Text("Come back tomorrow").font(WINRV2Font.inter(12, .bold))
                      + Text(" to\nkeep your streak alive and receive:").font(WINRV2Font.inter(12)))
                Text("\(nextEntries.formatted()) ENTRIES")
                    .font(WINRV2Font.inter(16, .black))
                    .foregroundColor(accent)
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
        }
    }

    private var toastContent: some View {
        HStack(spacing: 16) {
            WINRV2AnimatedCheckmark(lineWidth: 3.5)
                .frame(width: 38, height: 38)
            VStack(spacing: 0) {
                Text(firstDay ? "YOU’RE IN!" : "YOU’RE ON A ROLL!")
                    .font(WINRV2Font.inter(20, .black))
                    .kerning(-0.6)
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Your \(claimedEntries.formatted()) entries have been added automatically.")
                    .font(WINRV2Font.inter(13, .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - CTA + legal

struct WINRV2PillButton: View {
    let accent: Color
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(WINRV2Font.inter(24, .heavy))
                        .kerning(-0.72)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Capsule().fill(accent))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

struct WINRV2LegalLinks: View {
    let rulesUrl: String?
    var showPoweredBy = false

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 8) {
                link("OFFICIAL RULES", url: rulesUrl)
                Circle().fill(WINRV2Color.textSecondary).frame(width: 4, height: 4)
                link("PRIVACY POLICY", url: rulesUrl)
            }
            if showPoweredBy {
                Text("Powered by © WINR Media")
                    .font(WINRV2Font.inter(12))
                    .foregroundColor(WINRV2Color.textTertiary)
            }
        }
    }

    @ViewBuilder private func link(_ title: String, url: String?) -> some View {
        Button {
            if let url, let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            Text(title)
                .font(WINRV2Font.inter(12))
                .foregroundColor(WINRV2Color.textSecondary)
        }
        .buttonStyle(.plain)
    }
}


/// Rounds only the TOP corners — the V2 drawer sits flush against the screen's
/// bottom and sides (a true bottom sheet, unlike iOS 26's floating sheets).
struct WINRV2TopRoundedShape: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}

// MARK: - Counting total readout

/// The stats-strip total: counts up smoothly when the value increases and
/// pops a brief star burst as it lands on the new total.
struct WINRV2CountUpText: View {
    let value: Int
    let accent: Color

    @State private var shown: Int
    @State private var burst = false

    init(value: Int, accent: Color) {
        self.value = value
        self.accent = accent
        // Seeded at init, not in onAppear: with the cache-first render the
        // dashboard now mounts on the drawer's first frame, and a `shown`
        // starting at 0 painted a "0 Total Entries" frame before onAppear
        // corrected it.
        _shown = State(initialValue: value)
    }

    var body: some View {
        Text(shown.formatted())
            .font(WINRV2Font.inter(15, .black))
            .kerning(-0.3)
            .foregroundColor(accent)
            .overlay(
                Group {
                    if burst {
                        // Joe's Figma confetti burst: one-shot GIF shown as
                        // the count lands, removed once it finishes.
                        WINRV2GifView("confetti-burst", onFinished: {
                            withAnimation(.easeOut(duration: 0.3)) { burst = false }
                        })
                        .frame(width: 54, height: 44)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
            )
            .onAppear { shown = value }
            .onChange(of: value) { newValue in
                guard newValue != shown else { return }
                let from = shown, steps = 20
                let delta = newValue - from
                for i in 1...steps {
                    // Ease-out ramp over ~0.7s.
                    let t = Double(i) / Double(steps)
                    let eased = 1 - pow(1 - t, 3)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7 * t) {
                        shown = from + Int((Double(delta) * eased).rounded())
                        if i == steps {
                            // The GIF's onFinished removes the burst overlay.
                            withAnimation(.easeOut(duration: 0.2)) { burst = true }
                        }
                    }
                }
            }
    }
}
