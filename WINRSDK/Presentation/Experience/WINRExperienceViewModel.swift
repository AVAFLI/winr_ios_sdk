//
//  WINRExperienceViewModel.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation
import UIKit
import SwiftUI

/// The cache-first render decision, split out from the view model so it is
/// exercisable on its own: the drawer may paint the real dashboard from cached
/// values ONLY when every ingredient it needs is already on the device AND the
/// user has cleared the email gate.
enum WINRV2CacheRender {
    /// Whether `hydrateFromCache` may paint the dashboard immediately.
    ///
    /// - `isLoading`: false once a fresh network response has already resolved
    ///   the phase — never stomp fresher truth.
    /// - `hasEmailConsent`: Day 1 / unconsented users must land on email
    ///   capture, NEVER on a cached dashboard.
    static func canHydrate(
        giveaway: GiveawayConfig?,
        streak: StreakState?,
        hasEmailConsent: Bool,
        isLoading: Bool
    ) -> Bool {
        guard isLoading else { return false }
        guard giveaway != nil else { return false }
        guard hasEmailConsent else { return false }
        guard streak != nil else { return false }
        return true
    }
}

final class WINRExperienceViewModel: ObservableObject {

    /// Non-PII flag marking that the user completed the email-capture / consent
    /// flow. We persist this boolean instead of the raw email (PII-High) so the
    /// experience knows registration is complete without storing plaintext email.
    private var emailSubmittedKey: String {
        "winr.\(container.configuration.bundleId).user.\(container.user.id).emailSubmitted"
    }

    private var streakStorageKey: String {
        "winr.\(container.configuration.bundleId).user.\(container.user.id).streak"
    }

    private var giveawayCacheKey: String {
        "winr.\(container.configuration.bundleId).giveaway"
    }

    enum State {
        case loading
        case noActiveGiveaway
        case emailCapture
        case streak(StreakState, Int, [Int])
        case milestoneCelebration(MilestoneAward, DailyEntryGrant)
        /// Daily entries confirmation screen
        case dailyConfirmed(DailyEntryGrant, totalEntries: Int)
        case completed(DailyEntryGrant)
        case howItWorks
        /// This person is the drawn winner and hasn't submitted their claim yet
        /// — the drawer shows the winner splash → claim form → confirmation
        /// flow instead of the dashboard. Takes precedence on open.
        case winnerClaim(PrizeClaimBlock)
        case error(WINRError)
    }

    /// Sub-screen of the winner claim flow (`state == .winnerClaim`).
    enum WinnerClaimStep: Equatable {
        case splash
        case form
        case confirmation(claimNumber: String, submittedAt: String)
    }

    /// Whether the user has already claimed today's entry
    @Published var claimedToday: Bool = false

    /// Loading indicator for the daily claim button
    @Published var isClaimingDaily: Bool = false

    @Published private(set) var state: State = .loading

    private let container: DependencyContainer
    
    var activeGiveawayConfig: GiveawayConfig? { activeGiveaway }
    private weak var presentingViewController: UIViewController?
    private let completion: (Result<DailyEntryGrant, WINRError>) -> Void
    private let streakEngine: StreakEngineProtocol
    private var lastPrimaryState: State?
    private var activeGiveaway: GiveawayConfig?
    private var cachedBackendClaimedToday: Bool?
    private var cachedBackendStreakDay: Int?
    private var cachedBackendMonthlyCurrent: Int?
    private var cachedBackendWeeklyCurrent: Int?
    private var cachedBackendLifetimeCount: Int?
    private var cachedBackendTotalEntries: Int?
    /// One-shot guard for the "already claimed on another device" re-sync.
    private var didResyncAfterAlreadyClaimed = false

    // MARK: - Winner prize claim

    /// Which screen of the winner claim flow is showing.
    @Published var winnerClaimStep: WinnerClaimStep = .splash
    /// Spinner state for the claim form's SUBMIT pill.
    @Published var isSubmittingClaim = false
    /// Transport-level submit failure surfaced inline on the form ("Not the
    /// winner"/"Already submitted" instead fall back to the dashboard silently).
    @Published var claimSubmitError: String?
    /// The submitted form, kept for the confirmation screen's winner card.
    private(set) var submittedClaimForm: WINRPrizeClaimForm?
    /// Set after a "Not the winner"/"Already submitted" rejection so the next
    /// load skips the winner flow and lands on the normal dashboard.
    private var suppressWinnerClaim = false

    /// Prefill for the claim form (host-app-provided identity).
    var claimFormPrefill: WINRPrizeClaimForm {
        var form = WINRPrizeClaimForm()
        form.firstName = container.user.firstName
        form.lastName = container.user.lastName
        form.phone = container.user.phone ?? ""
        return form
    }

    /// Email pre-fill is no longer supported — the SDK captures email via its own consent flow
    var prefillEmail: String? { nil }

    /// Server-driven copy & branding config from admin/publisher dashboard
    var sdkConfig: SDKConfigResponse? { container.sdkConfig }

    // MARK: - V2 display accessors

    @Published var isSubmittingEmail = false

    // MARK: - V2 reveal flow (all days — Day 1 unified with Day 2+)
    //
    // The dashboard's FIRST VISIBLE FRAME is the celebration (the CTO's final
    // spec): toast bar, streak flip, counting total, and tile confetti all
    // fire in one beat at mount. Because the claim round-trip lands AFTER the
    // dashboard mounts, the grant is PREDICTED client-side from the pre-claim
    // status (WINRV2Ladder mirrors the backend's math exactly) and the real
    // response reconciles silently — identical numbers in the normal case.
    // The pill reads "GOT IT" the whole time — there is no claim tap.

    /// The grant staged for the celebration (nil when nothing is pending).
    /// Predicted at load; replaced by the real grant when the claim lands.
    @Published private(set) var pendingRevealGrant: DailyEntryGrant?
    /// Whether the in-place celebration has played.
    @Published private(set) var claimRevealed = false
    /// Total entries as of before today's claim, for the pre-reveal frame.
    private(set) var preClaimTotalEntries: Int?

    /// Tiny mount-settle delay before the celebration fires — just enough for
    /// SwiftUI to render the staged "before" frame so every transition and
    /// count has something to animate from. Visually imperceptible; the
    /// drawer's slide-up covers it.
    static let mountRevealDelay: TimeInterval = 0.15

    @MainActor
    func revealClaim() {
        guard pendingRevealGrant != nil, !claimRevealed else { return }
        claimRevealed = true
    }

    /// Fires the celebration one frame after the dashboard mounts, making the
    /// first visible frame the celebrating one. Idempotent — the guard in
    /// revealClaim() makes double-fires harmless.
    @MainActor
    func armCelebrationReveal() {
        guard pendingRevealGrant != nil, !claimRevealed else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.mountRevealDelay) { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.revealClaim()
            }
        }
    }

    /// Current streak day for display (backend truth, falling back to local).
    var displayStreakDay: Int {
        if let day = cachedBackendStreakDay { return day }
        let stored: StreakState? = try? container.storage.load(StreakState.self, for: streakStorageKey)
        return stored?.currentDay ?? 1
    }

    var displayTotalEntries: Int {
        // A staged celebration counts up to the PREDICTED post-claim total —
        // the real claim response reconciles these silently (normally a no-op).
        if let grant = pendingRevealGrant, let pre = preClaimTotalEntries {
            return pre + grant.baseEntries + grant.bonusEntries
        }
        return cachedBackendTotalEntries ?? lastClaimTotalEntries
    }

    /// The effective reward ladder (giveaway config, else engine defaults).
    var displayLadder: [Int] {
        if let ladder = activeGiveaway?.streakLadder, !ladder.isEmpty { return ladder }
        return (1...7).map { streakEngine.baseEntries(forDay: $0) }
    }

    /// Tomorrow's reward, for the come-back bar messaging.
    /// Uses the shared ladder math so accelerator milestones keep increasing it.
    var displayNextEntries: Int {
        WINRV2Ladder.entries(
            day: displayStreakDay + 1,
            ladder: displayLadder,
            milestones: activeGiveaway?.milestones
        )
    }

    /// V2: the celebration modal's GOT IT — settle onto the dashboard.
    @MainActor
    func showDashboardAfterCelebration() {
        Task {
            try? await computeStreakAndMoveToDashboard(
                backendClaimedToday: true,
                backendStreakDay: cachedBackendStreakDay
            )
        }
    }

    /// V2: close the whole experience (X buttons / GOT IT on the dashboard).
    func requestDismiss() {
        NotificationCenter.default.post(name: .winrCloseRequested, object: nil)
    }

    init(
        container: DependencyContainer,
        presentingViewController: UIViewController,
        streakEngine: StreakEngineProtocol = StreakEngine(),
        completion: @escaping (Result<DailyEntryGrant, WINRError>) -> Void
    ) {
        self.container = container
        self.presentingViewController = presentingViewController
        self.streakEngine = streakEngine
        self.completion = completion
        self.activeGiveaway = container.cachedGiveaway
        container.analytics?.trackExperienceOpened(giveawayId: activeGiveaway?.id)
        // Paint the dashboard from cache on the FIRST frames — before any
        // network call resolves — then let load() reconcile silently.
        hydrateFromCache()
        Task { await load() }
    }

    // MARK: - Cache-first render

    /// True once the dashboard has been painted from cached values, so the
    /// network reconcile knows it is updating a LIVE dashboard rather than
    /// replacing a loading screen.
    private(set) var hydratedFromCache = false

    /// Renders the dashboard IMMEDIATELY from cached state (giveaway config +
    /// persisted streak), skipping the loading phase entirely.
    ///
    /// The drawer used to sit on a spinner for as long as the sequential
    /// registerDevice → getActiveGiveaway → claim round-trips took (5s+ on a
    /// slow network) even when every value it needed was already on the device.
    /// Everything here is a LOCAL read, so it lands in the same runloop turn as
    /// the drawer's first frame; load() then reconciles the same way the
    /// celebration staging already does — silently, in place, with no
    /// re-animation (the reveal flags are untouched, so a staged celebration
    /// still fires exactly once).
    ///
    /// Bails out (leaving the skeleton up) when anything is missing — a
    /// first-ever open, an un-consented user who must see email capture first,
    /// or a cold cache all take the genuine loading path.
    private func hydrateFromCache() {
        let storage = container.storage
        let giveaway = activeGiveaway ?? (try? storage.load(GiveawayConfig.self, for: giveawayCacheKey))
        let stored: StreakState? = try? storage.load(StreakState.self, for: streakStorageKey)
        var isLoading = false
        if case .loading = state { isLoading = true }

        guard WINRV2CacheRender.canHydrate(
            giveaway: giveaway,
            streak: stored,
            hasEmailConsent: hasEmailConsent,
            isLoading: isLoading
        ), let giveaway, var display = stored else { return }

        let ladder = giveaway.streakLadder.isEmpty
            ? (1...7).map { streakEngine.baseEntries(forDay: $0) }
            : giveaway.streakLadder
        let day = container.cachedStreakDay ?? display.currentDay
        display.currentDay = day
        let dayIndex = min(max(day - 1, 0), ladder.count - 1)

        activeGiveaway = giveaway
        claimedToday = container.cachedClaimedToday ?? false
        // Seed the display caches from the persisted state, otherwise the
        // already-claimed readout falls through to `lastClaimTotalEntries` and
        // the card's first frame reads "0 Total Entries". The fresh response
        // overwrites both a moment later (normally with the same numbers).
        if cachedBackendTotalEntries == nil { cachedBackendTotalEntries = display.totalEntriesEarned }
        if cachedBackendStreakDay == nil { cachedBackendStreakDay = day }
        hydratedFromCache = true
        state = .streak(display, ladder[dayIndex], ladder)
    }

    // MARK: - State machine

    /// `claimBeforeDashboard` (email-capture path): AWAIT the daily claim
    /// before the dashboard state is ever set, so the capture view (spinner)
    /// stays up through the round-trip and the dashboard MOUNTS with the
    /// celebration staged from the REAL claim response — the new user's first
    /// dashboard frame is the celebration, exactly like Day 2+ (CTO spec:
    /// the streak page is never seen uncelebrated).
    @MainActor
    private func load(claimBeforeDashboard: Bool = false) async {
        do {
            let storage = container.storage

            // Always fetch fresh claim status from the backend.
            // The giveaway config may already be cached, but claimedToday can change
            // between experience opens (e.g., after the user already claimed).
            var backendClaimedToday: Bool? = container.cachedClaimedToday
            var backendStreakDay: Int? = container.cachedStreakDay
            var pendingPrizeClaim: PrizeClaimBlock?

            do {
                let response = try await container.network.send(GetActiveGiveawayRequest())

                // RTD: an opted-out person never sees the experience content.
                if response.optedOut == true {
                    state = .noActiveGiveaway
                    return
                }

                // Winner prize claim: a PENDING block takes precedence over the
                // dashboard on open (routed below, once the caches are synced).
                // A "submitted" block is ignored — the normal dashboard shows.
                if let claim = response.prizeClaim, claim.isPending, !suppressWinnerClaim {
                    pendingPrizeClaim = claim
                }

                // Check if backend returned no active giveaway. (A pending prize
                // claim can outlive its giveaway — the winner flow still shows.)
                if response.giveaway == nil && pendingPrizeClaim == nil {
                    // Clear cached giveaway and set state to no active giveaway
                    activeGiveaway = nil
                    try? storage.remove(for: giveawayCacheKey)
                    state = .noActiveGiveaway
                    return
                }

                if let giveaway = response.giveaway {
                    activeGiveaway = giveaway
                    // Cache the new giveaway
                    try? storage.save(giveaway, for: giveawayCacheKey)
                    // Keep the prize art warm across prize changes mid-session.
                    WINRV2ImageWarmer.prewarm(giveaway.prizeImageUrl)
                }
                backendClaimedToday = response.claimedToday
                backendStreakDay = response.streakDay
                cachedBackendMonthlyCurrent = response.monthlyCurrent
                cachedBackendWeeklyCurrent = response.weeklyCurrent
                cachedBackendLifetimeCount = response.lifetimeCount
                cachedBackendTotalEntries = response.totalEntries

                // Backend is the source of truth for email consent. If it confirms
                // an email on file, seed the local "submitted" flag so a user whose
                // local flag was lost (e.g. reinstall) isn't re-prompted for email.
                if response.emailConsentStatus == true {
                    try? storage.save(true, for: emailSubmittedKey)
                }
            } catch {
                // Offline fallback: use cached giveaway
                if activeGiveaway == nil {
                    activeGiveaway = try? storage.load(GiveawayConfig.self, for: giveawayCacheKey)
                }
                Logger.shared.log("Using cached giveaway (offline): \(error)", level: .debug)
            }

            cachedBackendClaimedToday = backendClaimedToday
            cachedBackendStreakDay = backendStreakDay

            // Winner prize claim takes precedence over auto-claim/dashboard on
            // open — but the daily auto-claim still fires silently in the
            // background so the winner's entries keep accruing.
            if let claim = pendingPrizeClaim {
                winnerClaimStep = .splash
                state = .winnerClaim(claim)
                container.analytics?.track(
                    event: "winr_winner_claim_shown",
                    properties: ["giveaway_id": claim.giveawayId]
                )
                if backendClaimedToday != true, hasEmailConsent {
                    silentDailyClaim()
                }
                return
            }

            // Email-capture gate: shown until the user completes the consent flow.
            // Raw email is never persisted in plaintext — we gate on a non-PII
            // "email submitted" flag plus the presence of user_uid in the Keychain
            // (the handshake identifier), not on a stored email value.
            if !hasEmailConsent {
                state = .emailCapture
                return
            }

            // Email path (Day 1): claim FIRST, while the capture view's spinner
            // is still up. On success the celebration is staged from the real
            // response (synchronous with the transition — no prediction needed)
            // and the caches below already reflect the claim, so the predicted
            // staging is naturally skipped. On failure this is a no-op and the
            // normal predict → auto-claim → reconcile path takes over.
            if claimBeforeDashboard, backendClaimedToday == false, hasEmailConsent {
                await claimAndStageBeforeDashboard()
                backendClaimedToday = cachedBackendClaimedToday
                backendStreakDay = cachedBackendStreakDay
            }

            // Auto-claim staging (Day 1 AND Day 2+): stage the PREDICTED grant
            // BEFORE the dashboard state is set, so the celebration is the
            // dashboard's first visible frame — the claim round-trip lands
            // later and reconciles silently. Day 1 celebrates in place exactly
            // like Day 2+ (the "You're in!" modal is gone); only the toast
            // headline differs.
            if backendClaimedToday == false, hasEmailConsent,
               let day = backendStreakDay, day >= 1,
               let preTotal = cachedBackendTotalEntries {
                let predicted = WINRV2Ladder.entries(
                    day: day,
                    ladder: displayLadder,
                    milestones: activeGiveaway?.milestones
                )
                pendingRevealGrant = DailyEntryGrant(baseEntries: predicted, bonusEntries: 0)
                claimRevealed = false
                preClaimTotalEntries = preTotal
            }

            try await computeStreakAndMoveToDashboard(backendClaimedToday: backendClaimedToday, backendStreakDay: backendStreakDay)

            // Cache-first render: the dashboard MOUNTED before this staging
            // landed, so its .onAppear already ran with nothing pending and
            // will not run again. Arm the reveal here instead — armCelebration
            // Reveal is guarded, so the celebration still fires exactly once.
            if hydratedFromCache, case .streak = state {
                armCelebrationReveal()
            }

            // V2 experience: entries are granted automatically when the drawer opens —
            // no tap required. Registered + consented + not-yet-claimed → claim now.
            // Failures are silent (the dashboard just shows the unclaimed state).
            if case .streak = state, claimedToday == false, hasEmailConsent {
                claimDailyEntries(auto: true)
            }
        } catch {
            // Already showing a cache-rendered dashboard: a local hiccup is not
            // worth replacing live content with an error screen.
            if !hydratedFromCache {
                state = .error(.internalError(error.localizedDescription))
            }
        }
    }

    @MainActor
    func primaryFromHowItWorks() {
        hideHowItWorks()
    }

    @MainActor
    func showHowItWorks() {
        lastPrimaryState = state
        state = .howItWorks
    }

    @MainActor
    func hideHowItWorks() {
        if let previous = lastPrimaryState {
            state = previous
        } else {
            state = .loading
            Task { await load() }
        }
    }

    @MainActor
    private func computeStreakAndMoveToDashboard(backendClaimedToday: Bool? = nil, backendStreakDay: Int? = nil) async throws {
        let storage = container.storage
        let stored: StreakState? = try storage.load(StreakState.self, for: streakStorageKey)
        let today = Date()

        // Use giveaway ladder if available, otherwise fall back to engine defaults
        let ladder: [Int]
        if let giveaway = activeGiveaway {
            ladder = giveaway.streakLadder
        } else {
            ladder = (1...7).map { streakEngine.baseEntries(forDay: $0) }
        }

        // ─── Backend is source of truth for claim status ───
        // If the backend told us whether the user claimed today, use that directly.
        if let backendClaimed = backendClaimedToday {
            let day = backendStreakDay ?? stored?.currentDay ?? 1
            let dayIndex = min(day - 1, ladder.count - 1)
            let entriesToday = ladder[max(0, dayIndex)]
            
            var displayState = stored ?? StreakState(
                currentDay: day,
                lastClaimedDate: backendClaimed ? today : nil,
                totalEntriesEarned: 0,
                weeklyCurrent: 1,
                weeklyStart: "",
                monthlyCurrent: 1,
                monthlyStart: "",
                lifetimeCount: 0
            )
            
            // Always sync with backend — backend is source of truth
            displayState.currentDay = day
            if let mc = cachedBackendMonthlyCurrent { displayState.monthlyCurrent = mc }
            if let wc = cachedBackendWeeklyCurrent { displayState.weeklyCurrent = wc }
            if let lc = cachedBackendLifetimeCount { displayState.lifetimeCount = lc }
            // Seed the running total from the backend (source of truth) so the
            // "current → after" reward pill and the Total-entries readout reflect
            // entries claimed on OTHER devices — otherwise this shows a stale local
            // total (e.g. 110 from a prior local claim while the backend is at 170).
            if let te = cachedBackendTotalEntries { displayState.totalEntriesEarned = te }
            
            // Sync local state with backend
            if backendClaimed && stored?.lastClaimedDate == nil {
                displayState.lastClaimedDate = today
            }
            try? storage.save(displayState, for: streakStorageKey)
            
            claimedToday = backendClaimed
            state = .streak(displayState, entriesToday, ladder)
            return
        }

        // ─── Offline fallback: use local StreakEngine ───
        let result = streakEngine.nextState(from: stored, on: today)
        switch result {
        case .failure(let error):
            if case .ineligibleToday = error, let stored = stored {
                claimedToday = true
                let dayIndex = min(stored.currentDay - 1, ladder.count - 1)
                let entriesToday = ladder[max(0, dayIndex)]
                state = .streak(stored, entriesToday, ladder)
            } else if !hydratedFromCache {
                state = .error(error)
            }
            // Already showing a cache-rendered dashboard: a local streak-engine
            // hiccup is not worth replacing it with an error screen.

        case .success(let newState):
            let dayIndex = min(newState.currentDay - 1, ladder.count - 1)
            let entriesToday = ladder[max(0, dayIndex)]
            claimedToday = false
            state = .streak(newState, entriesToday, ladder)
        }
    }

    // MARK: - Email capture

    @MainActor
    func submitEmail(_ email: String, ageConfirmed: Bool, marketingConsent: Bool) {
        guard !email.isEmpty else { return }

        // NOTE: We deliberately do NOT persist the raw email locally (PII-High).
        // The backend stores it AES-256-encrypted and returns a user_uid handshake;
        // registration state is derived from user_uid in the Keychain instead.
        do {
            try container.storage.save(true, for: emailSubmittedKey)
            try container.storage.save(marketingConsent, for: "winr_marketing_consent")
            Logger.shared.log("WINR email submitted (age confirmed: \(ageConfirmed), marketing consent: \(marketingConsent))", level: .info)
        } catch {
            Logger.shared.log("Failed to save email-submitted flag: \(error)", level: .error)
        }

        // Submit email to the backend, THEN advance. We await (rather than the old
        // fire-and-forget) because the backend consent gate blocks a claim until the
        // email is on file — advancing first would race into a failed claim.
        isSubmittingEmail = true
        Task { [weak self] in
            defer { Task { @MainActor in self?.isSubmittingEmail = false } }
            guard let self else { return }
            do {
                let response = try await container.network.send(
                    SubmitEmailRequest(email: email, ageConfirmed: ageConfirmed, marketingConsent: marketingConsent)
                )
                // Cross-device streak unification: if this email already belonged to
                // an existing user under this publisher (another device/SDK), the
                // backend hands back that canonical user's credentials. Switch to
                // them so the person keeps ONE streak per publisher across devices.
                if response.adopted == true, let token = response.token, let uuid = response.uuid {
                    container.keychain.saveToken(token)
                    if let refresh = response.refreshToken { container.keychain.saveRefreshToken(refresh) }
                    container.keychain.saveUUID(uuid)
                    Logger.shared.log("Adopted existing account — streak unified across devices", level: .info)
                }
                // The facade's cached consent flag is otherwise only refreshed
                // by getActiveGiveaway, so between this submit and the next
                // fetch the auto-present engine would still see this person as
                // unregistered and count them against the unregistered
                // impression cap. Harmless today (the once-per-day mark is
                // checked first), but correctness shouldn't depend on that
                // ordering — the backend has the email now, so record it.
                WINR.markEmailConsentGranted()
                Logger.shared.log("Email submitted to backend", level: .debug)
            } catch {
                Logger.shared.log("Email submit to backend failed (will retry later): \(error)", level: .error)
            }

            // Re-load so the (possibly switched) canonical user's authoritative
            // streak + claim status drive the UI. The Day-1 claim is awaited
            // INSIDE the load (capture spinner stays up) so the dashboard
            // mounts already celebrating — never an uncelebrated streak page.
            await load(claimBeforeDashboard: true)
        }
    }

    /// Email path (Day 1): awaited claim BEFORE the dashboard ever mounts. On
    /// success the celebration is staged from the real response, so the first
    /// dashboard frame counts 0 → N under the "YOU'RE IN!" toast. On failure
    /// this is a no-op — load() falls through to the predicted staging and the
    /// silent auto-claim retry, the same as any other open.
    @MainActor
    private func claimAndStageBeforeDashboard() async {
        do {
            let response = try await container.network.send(ClaimDailyEntriesRequest())
            var bonusEntries = 0
            if let weekly = response.weeklyBonusEntries { bonusEntries += weekly }
            if let monthly = response.monthlyBonusEntries { bonusEntries += monthly }
            if let milestone = response.milestone { bonusEntries += milestone.bonusEntries }
            if let monthlyMilestone = response.monthlyMilestone { bonusEntries += monthlyMilestone.bonusEntries }
            let grant = DailyEntryGrant(baseEntries: response.entries, bonusEntries: bonusEntries)

            lastClaimTotalEntries = response.totalEntries
            cachedBackendTotalEntries = response.totalEntries
            cachedBackendStreakDay = response.streakDay
            cachedBackendClaimedToday = true
            if let mc = response.monthlyCurrent { cachedBackendMonthlyCurrent = mc }
            if let wc = response.weeklyCurrent { cachedBackendWeeklyCurrent = wc }
            if let lc = response.lifetimeCount { cachedBackendLifetimeCount = lc }

            pendingRevealGrant = grant
            preClaimTotalEntries = response.totalEntries - (grant.baseEntries + grant.bonusEntries)
            claimRevealed = false

            container.analytics?.track(
                event: WINRAnalyticsEvent.dailyEntryClaimed,
                properties: ["day": response.streakDay, "entries": response.entries]
            )
        } catch {
            Logger.shared.log("Day-1 claim after email submit failed (dashboard will retry): \(error)", level: .info)
        }
    }

    @MainActor
    func skipEmailCapture() {
        // Email is mandatory — redirect back to email capture
        state = .emailCapture
    }

    // MARK: - Daily entries

    /// Whether the registration handshake produced a user_uid in the Keychain.
    private var hasRegistered: Bool {
        container.keychain.loadUUID() != nil
    }

    /// Whether the user has completed email capture (required before claiming).
    /// Gated on the non-PII "email submitted" flag — raw email is never stored.
    /// Requires the handshake user_uid to exist so the backend can attribute the
    /// entry; if registration hasn't completed yet we re-show the capture flow.
    var hasEmailConsent: Bool {
        let submitted: Bool = (try? container.storage.load(Bool.self, for: emailSubmittedKey)) ?? false
        return submitted && hasRegistered
    }

    @MainActor
    func claimDailyEntries(auto: Bool = false) {
        guard case let .streak(streak, entries, ladder) = state else { return }
        guard !isClaimingDaily else { return }

        // Email consent gate: must have email before claiming
        if !hasEmailConsent {
            state = .emailCapture
            return
        }

        isClaimingDaily = true

        // Claim from backend
        Task {
            do {
                let response = try await container.network.send(ClaimDailyEntriesRequest())
                
                // Handle bonus entries from all sources (milestones, weekly/monthly bonuses)
                var streakBonusEntries = 0
                if let weeklyBonus = response.weeklyBonusEntries {
                    streakBonusEntries += weeklyBonus
                }
                if let monthlyBonus = response.monthlyBonusEntries {
                    streakBonusEntries += monthlyBonus
                }
                if let milestone = response.milestone {
                    streakBonusEntries += milestone.bonusEntries
                }
                if let monthlyMilestone = response.monthlyMilestone {
                    streakBonusEntries += monthlyMilestone.bonusEntries
                }
                
                // Keep baseEntries as just the daily ladder amount;
                // streak bonuses (monthly/weekly/milestone) go into bonusEntries
                // so the UI can show a proper breakdown.
                let grant = DailyEntryGrant(baseEntries: response.entries, bonusEntries: streakBonusEntries)
                lastClaimTotalEntries = response.totalEntries
                // Keep the display caches in sync so the post-celebration dashboard
                // shows the fresh totals (not the pre-claim snapshot).
                cachedBackendTotalEntries = response.totalEntries
                cachedBackendStreakDay = response.streakDay
                cachedBackendClaimedToday = true

                // Update local streak cache — only NOW mark as claimed
                var updatedStreak = streak
                updatedStreak.currentDay = response.streakDay
                updatedStreak.lastClaimedDate = Date()
                updatedStreak.totalEntriesEarned = response.totalEntries
                if let mc = response.monthlyCurrent { updatedStreak.monthlyCurrent = mc }
                if let wc = response.weeklyCurrent { updatedStreak.weeklyCurrent = wc }
                if let lc = response.lifetimeCount { updatedStreak.lifetimeCount = lc }
                try? container.storage.save(updatedStreak, for: streakStorageKey)
                claimedToday = true

                // V2 auto-claim routing (Day 1 AND Day 2+, unified — the
                // celebration modal is gone): the celebration already played at
                // mount off the PREDICTED grant — reconcile the staged numbers
                // with the real response. In the normal case they're identical,
                // so nothing visibly changes; a mismatch silently corrects the
                // readouts. Day 1 only differs in the toast headline
                // ("YOU'RE IN!" instead of "YOU'RE ON A ROLL!").
                if auto {
                    pendingRevealGrant = grant
                    preClaimTotalEntries = response.totalEntries - (grant.baseEntries + grant.bonusEntries)
                    state = .streak(updatedStreak, response.entries, ladder)
                    // Safety net: if no prediction was staged pre-mount
                    // (e.g. the status fetch was offline), the dashboard's
                    // onAppear found nothing pending — fire the reveal now.
                    armCelebrationReveal()
                    isClaimingDaily = false
                    return
                }

                let celebrationMilestone = response.milestone ?? response.monthlyMilestone
                if let milestone = celebrationMilestone {
                    state = .milestoneCelebration(milestone, grant)
                    
                    // Track milestone analytics
                    container.analytics?.trackStreakMilestone(
                        day: milestone.day,
                        bonusEntries: milestone.bonusEntries
                    )
                    if let badge = milestone.badge {
                        container.analytics?.track(
                            event: "winr_badge_earned",
                            properties: [
                                "badge": badge,
                                "milestone_day": milestone.day,
                                "bonus_entries": milestone.bonusEntries
                            ]
                        )
                    }
                } else {
                    state = .dailyConfirmed(grant, totalEntries: response.totalEntries)
                }

                var analyticsProperties: [String: Any] = [
                    "day": response.streakDay,
                    "entries": response.entries
                ]
                if let weeklyBonus = response.weeklyBonusEntries {
                    analyticsProperties["weekly_bonus"] = weeklyBonus
                }
                if let monthlyBonus = response.monthlyBonusEntries {
                    analyticsProperties["monthly_bonus"] = monthlyBonus
                }
                if let milestone = response.milestone {
                    analyticsProperties["milestone_day"] = milestone.day
                    analyticsProperties["milestone_bonus"] = milestone.bonusEntries
                    if let badge = milestone.badge {
                        analyticsProperties["milestone_badge"] = badge
                    }
                }
                
                container.analytics?.track(
                    event: WINRAnalyticsEvent.dailyEntryClaimed,
                    properties: analyticsProperties
                )
            } catch {
                isClaimingDaily = false
                let errorMessage = "\(error)"
                
                // "Already claimed" means the user already got their entries today.
                // Treat this as a successful claim — update local state and show completed.
                if errorMessage.contains("Already claimed") {
                    Logger.shared.log("Already claimed today — updating local state", level: .info)
                    var updatedStreak = streak
                    updatedStreak.lastClaimedDate = Date()
                    try? container.storage.save(updatedStreak, for: streakStorageKey)
                    claimedToday = true

                    // For an auto-claim this isn't news worth celebrating — show the
                    // dashboard in its claimed state instead of the confirmation.
                    // "Already claimed" here means another device beat us between the
                    // status fetch and the claim, so our cached totals are one claim
                    // behind — re-load to pull the authoritative streak/total.
                    if auto {
                        // Roll back the predicted celebration NUMBERS — the
                        // prediction was built on a stale total. The reveal
                        // state itself stays (no animation replay); the
                        // re-load silently corrects the total readout.
                        pendingRevealGrant = nil
                        preClaimTotalEntries = nil
                        state = .streak(updatedStreak, entries, ladder)
                        // One-shot: never loop if status + claim keep disagreeing.
                        if !didResyncAfterAlreadyClaimed {
                            didResyncAfterAlreadyClaimed = true
                            Task { await load() }
                        }
                        return
                    }
                    let grant = DailyEntryGrant(baseEntries: entries)
                    let estimatedTotal = streak.totalEntriesEarned + entries
                    state = .dailyConfirmed(grant, totalEntries: estimatedTotal)
                    return
                }

                // Auto-claim failures are SILENT by design: the dashboard simply
                // shows the unclaimed state and the user can retry by tapping.
                // Never fake a local success for an auto-claim.
                if auto {
                    Logger.shared.log("Auto-claim declined: \(error)", level: .info)
                    claimedToday = false
                    // Roll back the predicted celebration — nothing was granted.
                    // The dashboard returns to the calm unclaimed state and the
                    // total readout reverts silently (no animation replay).
                    pendingRevealGrant = nil
                    preClaimTotalEntries = nil
                    claimRevealed = false
                    state = .streak(streak, entries, ladder)
                    return
                }

                // Manual claim, backend REJECTION (geo-block, consent, opt-out…):
                // surface the real error. Faking a local "claimed" here would show a
                // celebration for an entry that does not exist.
                if case WINRError.internalError = error {
                    state = .error((error as? WINRError) ?? .internalError(errorMessage))
                    return
                }

                // True transport failure — offline fallback: use local streak engine
                Logger.shared.log("Backend claim failed, using local: \(error)", level: .error)

                // Persist the claim locally so it can't be re-claimed
                var updatedStreak = streak
                updatedStreak.lastClaimedDate = Date()
                try? container.storage.save(updatedStreak, for: streakStorageKey)
                claimedToday = true

                let grant = DailyEntryGrant(baseEntries: entries)
                let estimatedTotal = streak.totalEntriesEarned + entries
                state = .dailyConfirmed(grant, totalEntries: estimatedTotal)

                container.analytics?.track(
                    event: WINRAnalyticsEvent.dailyEntryClaimed,
                    properties: [
                        "day": streak.currentDay,
                        "entries": grant.baseEntries,
                        "offline": true
                    ]
                )
            }
        }
    }

    /// The total entries from the last claim response (cached for dailyConfirmed screen)
    private var lastClaimTotalEntries: Int = 0

    /// Dismiss the milestone celebration and proceed to the confirmation screen
    @MainActor
    func dismissMilestoneCelebration() {
        guard case let .milestoneCelebration(_, grant) = state else { return }
        state = .dailyConfirmed(grant, totalEntries: lastClaimTotalEntries)
    }

    /// Dismiss the daily entries confirmation and close the SDK
    @MainActor
    func dismissDailyConfirmation() {
        guard case let .dailyConfirmed(grant, _) = state else { return }
        complete(with: grant)
    }

    // MARK: - Winner prize claim

    /// Fire-and-forget daily claim while the winner flow is on screen — the
    /// winner still accrues their streak entries, but nothing is revealed.
    @MainActor
    private func silentDailyClaim() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await container.network.send(ClaimDailyEntriesRequest())
                await MainActor.run {
                    self.cachedBackendClaimedToday = true
                    self.cachedBackendStreakDay = response.streakDay
                    self.cachedBackendTotalEntries = response.totalEntries
                    self.claimedToday = true
                }
                Logger.shared.log("Silent daily claim during winner flow: +\(response.entries)", level: .debug)
            } catch {
                Logger.shared.log("Silent daily claim declined during winner flow: \(error)", level: .debug)
            }
        }
    }

    /// Splash CONTINUE → the claim form.
    @MainActor
    func winnerClaimContinue() {
        guard case .winnerClaim = state else { return }
        winnerClaimStep = .form
    }

    /// SUBMIT on the claim form. Success → confirmation screen. A backend
    /// "Not the winner"/"Already submitted" rejection falls back to the normal
    /// dashboard silently (logged); transport failures surface inline.
    @MainActor
    func submitPrizeClaim(_ form: WINRPrizeClaimForm) {
        guard case let .winnerClaim(claim) = state, !isSubmittingClaim else { return }
        guard form.isValid else { return }
        claimSubmitError = nil
        isSubmittingClaim = true

        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await container.network.send(SubmitPrizeClaimRequest(
                    giveawayId: claim.giveawayId,
                    firstName: form.trimmed(\.firstName),
                    lastName: form.trimmed(\.lastName),
                    phone: form.trimmed(\.phone).isEmpty ? nil : form.trimmed(\.phone),
                    street: form.trimmed(\.street),
                    apt: form.trimmed(\.apt).isEmpty ? nil : form.trimmed(\.apt),
                    city: form.trimmed(\.city),
                    state: form.trimmed(\.state),
                    zip: form.trimmed(\.zip),
                    country: form.country,
                    photoBase64: form.photoBase64,
                    story: form.trimmed(\.story).isEmpty ? nil : form.trimmed(\.story)
                ))
                isSubmittingClaim = false
                submittedClaimForm = form
                winnerClaimStep = .confirmation(
                    claimNumber: response.claimNumber,
                    submittedAt: response.submittedAt
                )
                container.analytics?.track(
                    event: "winr_prize_claim_submitted",
                    properties: ["giveaway_id": claim.giveawayId, "claim_number": response.claimNumber]
                )
            } catch {
                isSubmittingClaim = false
                let message = "\(error)"
                if message.contains("Not the winner") || message.contains("Already submitted") {
                    // Stale/duplicate winner state — never trap the user in the
                    // claim flow. Fall back to the normal dashboard silently.
                    Logger.shared.log("Prize claim rejected (\(message)) — falling back to dashboard", level: .info)
                    suppressWinnerClaim = true
                    state = .loading
                    await load()
                    return
                }
                Logger.shared.log("Prize claim submit failed: \(error)", level: .error)
                claimSubmitError = "Something went wrong. Please check your connection and try again."
            }
        }
    }

    // MARK: - Completion

    @MainActor
    private func complete(with grant: DailyEntryGrant) {
        state = .completed(grant)
        container.analytics?.trackExperienceClosed(giveawayId: activeGiveaway?.id)
        completion(.success(grant))
    }
}
