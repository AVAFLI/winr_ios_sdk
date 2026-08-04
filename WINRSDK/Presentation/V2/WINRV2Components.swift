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
        if let logoUrl, let url = URL(string: logoUrl) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Color.clear
                }
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

/// Day 2+ prize card: white stats strip (streak + total entries) over the prize
/// image. The image is publisher-configurable (prizeImageUrl); default is the
/// bundled cash pile with "WIN $X,XXX" overlaid.
struct WINRV2PrizeCard: View {
    let accent: Color
    let streakDay: Int
    let totalEntries: Int
    let prizeImageUrl: String?
    let prizeValue: Int
    let prizeDescription: String
    var visitMode = false

    /// Cash prizes render Joe's right-aligned "WIN $1,000 / CASH PRIZE" lockup;
    /// other prizes render "WIN A/AN {PRIZE}" + "$X.00 Value!".
    private var isCashPrize: Bool {
        prizeDescription.isEmpty || prizeDescription.lowercased().contains("cash")
    }
    private var article: String {
        guard let first = prizeDescription.trimmingCharacters(in: .whitespaces).first,
              first.isLetter else { return "A" }
        return "AEIOU".contains(first.uppercased()) ? "AN" : "A"
    }

    var body: some View {
        VStack(spacing: 0) {
            statsStrip
            promo
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

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
                    Text("Keep it going!")
                        .font(WINRV2Font.inter(12, .medium))
                        .foregroundColor(WINRV2Color.gunmetal)
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
                    Text(totalEntries.formatted())
                        .font(WINRV2Font.inter(15, .black))
                        .kerning(-0.3)
                        .foregroundColor(accent)
                    Text("Total Entries")
                        .font(WINRV2Font.inter(12, .medium))
                        .foregroundColor(WINRV2Color.gunmetal)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 46)
        .background(Color.white)
    }

    @ViewBuilder private var promo: some View {
        Group {
            if let prizeImageUrl, let url = URL(string: prizeImageUrl) {
                // Publisher-supplied prize art fills the card as-is.
                Color.clear
                    .frame(height: 150)
                    .background(
                        AsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                WINRV2Color.gunmetal
                            }
                        }
                    )
                    .clipped()
            } else {
                // Default: bundled cash pile fading up into white, with the
                // prize-derived headline over the fade (Figma cash card).
                Color.clear
                    .frame(height: 150)
                    .background(
                        WINRV2Asset.cashHero
                            .resizable()
                            .scaledToFill()
                            .offset(y: 14)
                    )
                    .clipped()
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: 0),
                                .init(color: .white.opacity(0.55), location: 0.3),
                                .init(color: .white.opacity(0), location: 0.62),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .top) {
                        if isCashPrize {
                            // Figma cash lockup: "WIN $1,000" (Black 54) over
                            // "CASH PRIZE" (Black 19), right-aligned.
                            VStack(alignment: .trailing, spacing: -6) {
                                Text("WIN $\(prizeValue.formatted())")
                                    .font(WINRV2Font.inter(54, .black))
                                    .kerning(-2.7)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                Text("CASH PRIZE")
                                    .font(WINRV2Font.inter(19, .black))
                                    .kerning(-0.57)
                            }
                            .foregroundColor(WINRV2Color.gunmetal)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 14)
                            .padding(.top, 4)
                        } else {
                            // "WIN A $500 AMAZON GIFT CARD" + "$500.00 Value!"
                            VStack(spacing: 0) {
                                Text("WIN \(article) \(prizeDescription.uppercased())")
                                    .font(WINRV2Font.inter(30, .black))
                                    .kerning(-1.1)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.55)
                                    .multilineTextAlignment(.center)
                                if prizeValue > 0
                                    && !prizeDescription.contains("$\(prizeValue.formatted())")
                                    && !prizeDescription.contains("$\(prizeValue)") {
                                    Text("$\(prizeValue.formatted()).00 Value!")
                                        .font(WINRV2Font.inter(15, .bold))
                                }
                            }
                            .foregroundColor(WINRV2Color.gunmetal)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                        }
                    }
            }
        }
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

    private var noun: String { visitMode ? "VISIT" : "DAY" }

    var body: some View {
        switch state {
        case .active:
            // Joe's active-tile motion: breathing glow + confetti specks
            // scattered around the tile.
            card
                .winrPulseGlow(accent)
                .background(
                    WINRV2ConfettiView(style: .celebration, count: 12, speed: 0.7)
                        .frame(width: 152, height: 176)
                )
        case .ready:
            // Pre-reveal: glow draws the eye to CLAIM, but the confetti and
            // checkmark are saved for the reveal moment.
            card.winrPulseGlow(accent)
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
            Image("winr-flame", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: 16, height: 20)
                .foregroundColor(.white)
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

    var body: some View {
        HStack(spacing: 14) {
            Image("winr-calendar", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: 26, height: 28)
                .foregroundColor(accent)
            VStack(spacing: 1) {
                (visitMode
                    ? Text("Come back again to receive:").font(WINRV2Font.inter(12))
                    : Text("Come back tomorrow to").font(WINRV2Font.inter(12))
                      + Text("\nkeep your streak alive and receive:").font(WINRV2Font.inter(12)))
                Text("\(nextEntries.formatted()) ENTRIES")
                    .font(WINRV2Font.inter(16, .black))
                    .foregroundColor(accent)
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 71)
        .background(Color.black)
        // Joe's toast has celebratory sprinkles drifting over the reward line.
        .overlay(WINRV2ConfettiView(style: .celebration, count: 10, speed: 0.55).clipped())
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
