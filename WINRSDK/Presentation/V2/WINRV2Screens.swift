//
//  WINRV2Screens.swift
//  WINRSDK
//
//  The V2 experience screens, matched to Joe's Figma flows (Solitaire / GLI /
//  Slice examples): new-user capture, return-user dashboard, celebration modal,
//  and how-it-works. Publisher can customize ONLY: logo, prize image, primary
//  color. Everything else is hardcoded to the design or derived from the prize.
//

import SwiftUI

// MARK: - Root router

struct WINRV2ExperienceRoot: View {
    @ObservedObject var viewModel: WINRExperienceViewModel

    private var accent: Color {
        WINRV2Accent(hex: viewModel.sdkConfig?.branding?.primaryColor).color
    }
    private var logoUrl: String? {
        viewModel.sdkConfig?.branding?.logoUrl
    }
    private var rulesUrl: String? {
        viewModel.activeGiveawayConfig?.rulesUrl ?? viewModel.sdkConfig?.rulesUrl
    }

    @State private var drawerAppeared = false
    @State private var showWinnerModal = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Dimmed host app behind the drawer.
                Color.black.opacity(drawerAppeared ? 0.45 : 0)
                    .ignoresSafeArea()
                drawerContent
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.90)
                    .background(WINRV2Color.gunmetal)
                    .clipShape(WINRV2TopRoundedShape(radius: 30))
                    .offset(y: drawerAppeared ? 0 : geo.size.height)

                if showWinnerModal, let winner = viewModel.activeGiveawayConfig?.latestWinner {
                    WINRV2WinnerModal(accent: accent, winner: winner) {
                        showWinnerModal = false
                    }
                    .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.9), value: drawerAppeared)
        }
        .ignoresSafeArea()
        .onAppear { drawerAppeared = true }
    }

    @ViewBuilder private var drawerContent: some View {
        ZStack {
            WINRV2Color.gunmetal

            switch viewModel.state {
            case .loading:
                loading
            case .noActiveGiveaway, .error:
                // Nothing to pitch (or opted out / errored) — quiet empty state.
                emptyState
            case .emailCapture:
                WINRV2CaptureView(
                    accent: accent,
                    logoUrl: logoUrl,
                    rulesUrl: rulesUrl,
                    giveaway: viewModel.activeGiveawayConfig,
                    isSubmitting: viewModel.isSubmittingEmail,
                    onSubmit: { email in viewModel.submitEmail(email, marketingConsent: true) },
                    onInfo: { viewModel.showHowItWorks() },
                    onClose: { viewModel.requestDismiss() }
                )
            case let .streak(streak, entriesToday, ladder):
                let preReveal = viewModel.pendingRevealGrant != nil && !viewModel.claimRevealed
                WINRV2DashboardView(
                    accent: accent,
                    logoUrl: logoUrl,
                    rulesUrl: rulesUrl,
                    giveaway: viewModel.activeGiveawayConfig,
                    streakDay: streak.currentDay,
                    totalEntries: preReveal
                        ? (viewModel.preClaimTotalEntries ?? streak.totalEntriesEarned)
                        : viewModel.displayTotalEntries,
                    entriesToday: entriesToday,
                    ladder: ladder,
                    claimedToday: viewModel.claimedToday,
                    onInfo: { viewModel.showHowItWorks() },
                    onClose: { viewModel.requestDismiss() },
                    onWinnerTap: { showWinnerModal = true },
                    pendingClaimEntries: viewModel.pendingRevealGrant.map { $0.baseEntries + $0.bonusEntries },
                    revealed: viewModel.claimRevealed,
                    onClaim: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            viewModel.revealClaim()
                        }
                    }
                )
            case let .dailyConfirmed(grant, totalEntries):
                // Dashboard behind + celebration modal on top.
                ZStack {
                    WINRV2DashboardView(
                        accent: accent,
                        logoUrl: logoUrl,
                        rulesUrl: rulesUrl,
                        giveaway: viewModel.activeGiveawayConfig,
                        streakDay: viewModel.displayStreakDay,
                        totalEntries: totalEntries,
                        entriesToday: grant.baseEntries,
                        ladder: viewModel.displayLadder,
                        claimedToday: true,
                        onInfo: { viewModel.showHowItWorks() },
                        onClose: { viewModel.requestDismiss() }
                    )
                    .blur(radius: 3)
                    WINRV2CelebrationModal(
                        accent: accent,
                        streakDay: viewModel.displayStreakDay,
                        earnedEntries: grant.baseEntries + grant.bonusEntries,
                        nextEntries: viewModel.displayNextEntries,
                        visitMode: viewModel.activeGiveawayConfig?.streakMode == "visit",
                        // Day-1 modal is the reveal for brand-new streaks; GOT IT
                        // closes the whole experience until the next day's open.
                        onDismiss: { viewModel.requestDismiss() }
                    )
                }
            case let .completed(grant):
                ZStack {
                    WINRV2DashboardView(
                        accent: accent,
                        logoUrl: logoUrl,
                        rulesUrl: rulesUrl,
                        giveaway: viewModel.activeGiveawayConfig,
                        streakDay: viewModel.displayStreakDay,
                        totalEntries: viewModel.displayTotalEntries,
                        entriesToday: grant.baseEntries,
                        ladder: viewModel.displayLadder,
                        claimedToday: true,
                        onInfo: { viewModel.showHowItWorks() },
                        onClose: { viewModel.requestDismiss() }
                    )
                }
            case .milestoneCelebration:
                // Milestones are parked (backend never sends them); fall back to dashboard.
                Color.clear.onAppear { viewModel.showDashboardAfterCelebration() }
            case .howItWorks:
                WINRV2HowItWorksView(
                    accent: accent,
                    logoUrl: logoUrl,
                    day1Entries: viewModel.displayLadder.first ?? 10,
                    visitMode: viewModel.activeGiveawayConfig?.streakMode == "visit",
                    onDone: { viewModel.hideHowItWorks() },
                    onClose: { viewModel.requestDismiss() }
                )
            }
        }
    }

    private var loading: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white)
            Text("Loading…")
                .font(WINRV2Font.inter(14))
                .foregroundColor(WINRV2Color.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Nothing to see here yet")
                .font(WINRV2Font.inter(20, .bold))
                .foregroundColor(.white)
            Text("Check back soon for your next chance to win!")
                .font(WINRV2Font.inter(14))
                .foregroundColor(WINRV2Color.textTertiary)
            WINRV2PillButton(accent: WINRV2Color.winrBlue, title: "CLOSE") {
                viewModel.requestDismiss()
            }
            .frame(width: 220)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - New-user capture ("VISIT. EARN. WIN.")

struct WINRV2CaptureView: View {
    let accent: Color
    let logoUrl: String?
    let rulesUrl: String?
    let giveaway: GiveawayConfig?
    let isSubmitting: Bool
    let onSubmit: (String) -> Void
    let onInfo: () -> Void
    let onClose: () -> Void

    @State private var email = ""
    @State private var isAdult = false

    private var day1Entries: Int { giveaway?.streakLadder.first ?? 10 }
    private var canSubmit: Bool {
        isAdult && email.contains("@") && email.contains(".")
    }

    var body: some View {
        ZStack(alignment: .top) {
            WINRV2TopGlow(accent: accent).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    WINRV2Header(logoUrl: logoUrl, onInfo: onInfo, onClose: onClose)
                        .padding(.top, 18)

                    VStack(spacing: 4) {
                        Text("VISIT. EARN. WIN.")
                            .font(WINRV2Font.inter(40, .black))
                            .kerning(-1.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("VISIT DAILY.  EARN ENTRIES.  WIN BIG!")
                            .font(WINRV2Font.inter(15, .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)

                    prizeStrip

                    VStack(spacing: 14) {
                        emailField

                        Button { isAdult.toggle() } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isAdult ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                Text("I confirm I am 18 years of age or older")
                                    .font(WINRV2Font.inter(14))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)

                        WINRV2PillButton(
                            accent: accent,
                            title: "CLAIM MY \(day1Entries) ENTRIES",
                            isLoading: isSubmitting
                        ) {
                            onSubmit(email.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        .opacity(canSubmit ? 1 : 0.5)
                        .disabled(!canSubmit || isSubmitting)
                    }
                    .padding(.horizontal, 22)

                    VStack(spacing: 3) {
                        Text("Your email lets us contact you if you win. By entering you agree to the Official Rules & Privacy Policy")
                            .font(WINRV2Font.inter(12))
                            .foregroundColor(WINRV2Color.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                        WINRV2LegalLinks(rulesUrl: rulesUrl, showPoweredBy: true)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
    }

    /// PRIZE-derived white strip (Joe's Day-1 examples):
    /// cash → "$1,000.00 CASH PRIZE"; other → "Win a $500 Amazon Gift Card" + value.
    private var prizeStrip: some View {
        let description = giveaway?.prizeDescription ?? ""
        let value = Int(giveaway?.prizeValue ?? 0)
        let isCash = description.isEmpty || description.lowercased().contains("cash")
        let article: String = {
            // Keyed off the LEADING token: "$500 Amazon..." reads "a five-hundred...",
            // so any non-letter start takes "a"; only a leading vowel sound takes "an".
            guard let first = description.trimmingCharacters(in: .whitespaces).first,
                  first.isLetter else { return "a" }
            return "AEIOU".contains(first.uppercased()) ? "an" : "a"
        }()
        return VStack(spacing: 0) {
            if isCash {
                Text("$\(value.formatted()).00 CASH PRIZE")
                    .font(WINRV2Font.inter(24, .black))
                    .kerning(-0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text("Win \(article) \(description)")
                    .font(WINRV2Font.inter(23, .black))
                    .kerning(-0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                // The value subtitle is redundant when the prize name already
                // states the amount ("$500 Amazon Gift Card").
                if value > 0 && !description.contains("$\(value.formatted())") && !description.contains("$\(value)") {
                    Text("$\(value.formatted()).00 Value!")
                        .font(WINRV2Font.inter(16))
                }
            }
        }
        .foregroundColor(WINRV2Color.gunmetal)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    private var emailField: some View {
        HStack(spacing: 10) {
            Image("winr-mail", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: 22, height: 18)
                .foregroundColor(WINRV2Color.gunmetal.opacity(0.6))
            TextField("Enter your email address", text: $email)
                .font(WINRV2Font.inter(16))
                .foregroundColor(WINRV2Color.gunmetal)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 20)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.75), lineWidth: 2))
        )
    }
}

// MARK: - Return-user dashboard (Day 2+ drawer)

struct WINRV2DashboardView: View {
    let accent: Color
    let logoUrl: String?
    let rulesUrl: String?
    let giveaway: GiveawayConfig?
    let streakDay: Int
    let totalEntries: Int
    let entriesToday: Int
    let ladder: [Int]
    let claimedToday: Bool
    let onInfo: () -> Void
    let onClose: () -> Void
    var onWinnerTap: (() -> Void)? = nil
    /// Reveal flow (Day 2+): the claim already succeeded server-side, but the UI
    /// holds yesterday's numbers until the user taps "CLAIM N ENTRIES" — that tap
    /// is the celebration (tile check + confetti + totals update), no modal.
    var pendingClaimEntries: Int? = nil
    var revealed = true
    var onClaim: (() -> Void)? = nil

    private var visitMode: Bool { giveaway?.streakMode == "visit" }
    private var preReveal: Bool { pendingClaimEntries != nil && !revealed }

    private func ladderValue(day: Int) -> Int {
        WINRV2Ladder.entries(day: day, ladder: ladder, milestones: giveaway?.milestones)
    }

    private var nextEntries: Int { ladderValue(day: streakDay + 1) }

    private var railEntries: [WINRV2RailEntry] {
        var entries: [WINRV2RailEntry] = []
        let maxDay = max(31, streakDay + 2)
        let milestoneDays: [Int: Int] = Dictionary(
            uniqueKeysWithValues: (giveaway?.milestones ?? []).map { ($0.day, $0.bonusEntries) }
        )
        for day in 1...maxDay {
            let state: WINRV2RailEntry.TileState =
                day < streakDay ? .completed :
                (day == streakDay ? (preReveal ? .ready : .active) : .locked)
            entries.append(.init(id: "day-\(day)", kind: .day(day: day, entries: ladderValue(day: day), state: state)))
            if let bonus = milestoneDays[day] {
                let label: String
                switch day {
                case 7: label = "1 WEEK"
                case 14: label = "2 WEEK"
                case 21: label = "3 WEEK"
                case 29, 30: label = "1 MONTH"
                default: label = "DAY \(day)"
                }
                let footnote = day == streakDay ? "STARTING TOMORROW" : "STARTING AT \(visitMode ? "VISIT" : "DAY") \(day + 1)"
                entries.append(.init(id: "power-\(day)", kind: .powerUp(label: label, bonus: bonus, footnote: footnote)))
            }
        }
        return entries
    }

    var body: some View {
        VStack(spacing: 15) {
            WINRV2TabGrabber().padding(.top, 15)
            WINRV2Header(logoUrl: logoUrl, onInfo: onInfo, onClose: onClose)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 15) {
                    if giveaway?.latestWinner != nil, let onWinnerTap {
                        WINRV2WinnerBanner(onTap: onWinnerTap)
                    }
                    WINRV2PrizeCard(
                        accent: accent,
                        streakDay: preReveal ? max(streakDay - 1, 1) : streakDay,
                        totalEntries: totalEntries,
                        prizeImageUrl: giveaway?.prizeImageUrl,
                        prizeValue: Int(giveaway?.prizeValue ?? 0),
                        prizeDescription: giveaway?.prizeDescription ?? "",
                        visitMode: visitMode
                    )
                    .padding(.horizontal, 22)

                    WINRV2StreakRail(
                        accent: accent,
                        entries: railEntries,
                        activeID: "day-\(streakDay)",
                        visitMode: visitMode
                    )

                    WINRV2ComeBackBar(accent: accent, nextEntries: nextEntries, visitMode: visitMode)

                    VStack(spacing: 6) {
                        if preReveal, let pending = pendingClaimEntries, let onClaim {
                            WINRV2PillButton(accent: accent, title: "CLAIM \(pending.formatted()) ENTRIES") { onClaim() }
                                .padding(.horizontal, 30)
                        } else {
                            WINRV2PillButton(accent: accent, title: "GOT IT") { onClose() }
                                .padding(.horizontal, 30)
                        }
                        WINRV2LegalLinks(rulesUrl: rulesUrl)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(WINRV2Color.gunmetal)
    }
}

// MARK: - Celebration modal (Day 1 "You're in!" / Day 2+ streak)

struct WINRV2CelebrationModal: View {
    let accent: Color
    let streakDay: Int
    let earnedEntries: Int
    let nextEntries: Int
    var visitMode = false
    let onDismiss: () -> Void

    @State private var appeared = false

    private var isFirstDay: Bool { streakDay <= 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                // Animated draw-on checkmark (the confetti flutter is an
                // overlay across the whole card, per Joe's modal GIF).
                WINRV2AnimatedCheckmark(lineWidth: 7)
                    .frame(width: 88, height: 88)
                    .padding(.top, 17)
                    .frame(height: 110)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .animation(.spring(response: 0.45, dampingFraction: 0.6), value: appeared)

                if isFirstDay {
                    Text("You’re in!")
                        .font(WINRV2Font.inter(14, .bold))
                        .foregroundColor(.white)
                    Text("\(earnedEntries) ENTRIES HAVE BEEN ADDED")
                        .font(WINRV2Font.inter(23, .black))
                        .foregroundColor(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 16)
                } else {
                    Text("YOU’RE ON A")
                        .font(WINRV2Font.inter(20, .bold))
                        .foregroundColor(.white)
                    Text("\(streakDay) \(visitMode ? "VISIT" : "DAY") STREAK!")
                        .font(WINRV2Font.inter(32, .black))
                        .kerning(-0.96)
                        .foregroundColor(accent)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)

                if isFirstDay {
                    Text(visitMode
                        ? "NEXT TIME YOU VISIT GET"
                        : "COME BACK TOMORROW TO KEEP\nYOUR STREAK GOING AND GET")
                        .font(WINRV2Font.inter(14, .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    bigNumber(nextEntries)
                } else {
                    Text("YOU EARNED")
                        .font(WINRV2Font.inter(20, .bold))
                        .foregroundColor(.white)
                    bigNumber(earnedEntries)
                    HStack(spacing: 14) {
                        Image("winr-calendar", bundle: .module)
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 26)
                            .foregroundColor(accent)
                        VStack(spacing: 1) {
                            Text(visitMode ? "Come back again for" : "Come back tomorrow for")
                                .font(WINRV2Font.inter(15))
                                .foregroundColor(.white)
                            Text("\(nextEntries.formatted()) ENTRIES")
                                .font(WINRV2Font.inter(20, .black))
                                .foregroundColor(accent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 71)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }

                WINRV2PillButton(accent: accent, title: "GOT IT") { onDismiss() }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
            .frame(width: 340)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(WINRV2Color.panel)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(WINRV2Color.panelBorder, lineWidth: 1))
            )
            .overlay(
                // Confetti flutters over the upper card, like Joe's GIF.
                WINRV2ConfettiView(style: .celebration, count: 34)
                    .frame(height: 330)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .allowsHitTesting(false),
                alignment: .top
            )
            .overlay(alignment: .topTrailing) {
                Button(action: onDismiss) {
                    Image("winr-close", bundle: .module)
                        .resizable().scaledToFit()
                        .frame(width: 11, height: 11)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(WINRV2Color.gunmetal))
                }
                .buttonStyle(.plain)
                .padding(12)
            }
        }
        .onAppear { appeared = true }
    }

    private func bigNumber(_ value: Int) -> some View {
        VStack(spacing: -14) {
            Text(value.formatted())
                .font(WINRV2Font.inter(96, .black))
                .kerning(-4.8)
                .foregroundColor(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 40)
            Text("ENTRIES")
                .font(WINRV2Font.inter(32, .black))
                .kerning(-0.96)
                .foregroundColor(.white)
        }
    }
}

// MARK: - How it works

struct WINRV2HowItWorksView: View {
    let accent: Color
    let logoUrl: String?
    let day1Entries: Int
    var visitMode = false
    let onDone: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            WINRV2Header(logoUrl: logoUrl, showsBack: true, onBack: onDone, onInfo: {}, onClose: onClose)
                .padding(.top, 18)

            Text("HOW IT WORKS")
                .font(WINRV2Font.inter(26, .black))
                .kerning(-0.78)
                .foregroundColor(WINRV2Color.gunmetal)
                .frame(maxWidth: .infinity)
                .frame(height: 39)
                .background(Color.white.opacity(0.5))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    item(number: "1", title: "ENTER ONCE",
                         body: "Submit your email to receive \(day1Entries) entries instantly and start your streak.")
                    item(number: "2", title: visitMode ? "KEEP VISITING" : "VISIT EVERY DAY",
                         body: visitMode
                            ? "Simply open the app whenever you like. Your entries are added automatically—no forms or extra steps."
                            : "Simply open the app each day. Your entries are added automatically—no forms or extra steps.")
                    item(number: "3", title: "KEEP YOUR STREAK GROWING",
                         body: visitMode
                            ? "Earn more entries with every visit. The more you come back, the bigger your rewards!"
                            : "Earn more entries with every consecutive visit. The longer your streak, the bigger your daily rewards!")
                }
                .padding(.horizontal, 26)

                Text(visitMode
                    ? "Every visit counts - your streak never resets."
                    : "Don’t miss a day - your streak resets if you do.")
                    .font(WINRV2Font.inter(20, .bold))
                    .kerning(-0.6)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 22)

                WINRV2PillButton(accent: accent, title: "GOT IT - START MY STREAK") { onDone() }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
            }
        }
        .background(WINRV2Color.panel.ignoresSafeArea())
    }

    private func item(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(number).")
                .font(WINRV2Font.inter(18, .black))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WINRV2Font.inter(18, .black))
                Text(body)
                    .font(WINRV2Font.inter(16))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundColor(.white)
    }
}
