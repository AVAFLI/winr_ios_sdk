//
//  WINRExperienceViewModel.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation
import UIKit

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
        case error(WINRError)
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

    /// Email pre-fill is no longer supported — the SDK captures email via its own consent flow
    var prefillEmail: String? { nil }

    /// Server-driven copy & branding config from admin/publisher dashboard
    var sdkConfig: SDKConfigResponse? { container.sdkConfig }

    // MARK: - V2 display accessors

    @Published var isSubmittingEmail = false

    // MARK: - V2 reveal flow (Day 2+)
    //
    // The auto-claim on open grants entries server-side immediately, but the UI
    // holds the previous day's numbers until the user taps "CLAIM N ENTRIES".
    // That tap flips `claimRevealed` — the day tile checks off with confetti,
    // the streak label and totals advance, and the pill becomes "GOT IT".

    /// The grant held back for the reveal (nil when nothing is pending).
    @Published private(set) var pendingRevealGrant: DailyEntryGrant?
    /// Whether the user has tapped CLAIM and seen the in-place celebration.
    @Published private(set) var claimRevealed = false
    /// Total entries as of before today's claim, for pre-reveal display.
    private(set) var preClaimTotalEntries: Int?

    @MainActor
    func revealClaim() {
        guard pendingRevealGrant != nil, !claimRevealed else { return }
        claimRevealed = true
    }

    /// Current streak day for display (backend truth, falling back to local).
    var displayStreakDay: Int {
        if let day = cachedBackendStreakDay { return day }
        let stored: StreakState? = try? container.storage.load(StreakState.self, for: streakStorageKey)
        return stored?.currentDay ?? 1
    }

    var displayTotalEntries: Int {
        cachedBackendTotalEntries ?? lastClaimTotalEntries
    }

    /// The effective reward ladder (giveaway config, else engine defaults).
    var displayLadder: [Int] {
        if let ladder = activeGiveaway?.streakLadder, !ladder.isEmpty { return ladder }
        return (1...7).map { streakEngine.baseEntries(forDay: $0) }
    }

    /// Tomorrow's reward, for the celebration modal + come-back messaging.
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
        Task { await load() }
    }

    // MARK: - State machine

    @MainActor
    private func load() async {
        do {
            let storage = container.storage

            // Always fetch fresh claim status from the backend.
            // The giveaway config may already be cached, but claimedToday can change
            // between experience opens (e.g., after the user already claimed).
            var backendClaimedToday: Bool? = container.cachedClaimedToday
            var backendStreakDay: Int? = container.cachedStreakDay
            
            do {
                let response = try await container.network.send(GetActiveGiveawayRequest())

                // RTD: an opted-out person never sees the experience content.
                if response.optedOut == true {
                    state = .noActiveGiveaway
                    return
                }

                // Check if backend returned no active giveaway
                if response.giveaway == nil {
                    // Clear cached giveaway and set state to no active giveaway
                    activeGiveaway = nil
                    try? storage.remove(for: giveawayCacheKey)
                    state = .noActiveGiveaway
                    return
                }
                
                activeGiveaway = response.giveaway
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
                
                // Cache the new giveaway
                try? storage.save(response.giveaway!, for: giveawayCacheKey)
            } catch {
                // Offline fallback: use cached giveaway
                if activeGiveaway == nil {
                    activeGiveaway = try? storage.load(GiveawayConfig.self, for: giveawayCacheKey)
                }
                Logger.shared.log("Using cached giveaway (offline): \(error)", level: .debug)
            }
            
            cachedBackendClaimedToday = backendClaimedToday
            cachedBackendStreakDay = backendStreakDay

            // Email-capture gate: shown until the user completes the consent flow.
            // Raw email is never persisted in plaintext — we gate on a non-PII
            // "email submitted" flag plus the presence of user_uid in the Keychain
            // (the handshake identifier), not on a stored email value.
            if !hasEmailConsent {
                state = .emailCapture
                return
            }

            try await computeStreakAndMoveToDashboard(backendClaimedToday: backendClaimedToday, backendStreakDay: backendStreakDay)

            // V2 experience: entries are granted automatically when the drawer opens —
            // no tap required. Registered + consented + not-yet-claimed → claim now.
            // Failures are silent (the dashboard just shows the unclaimed state).
            if case .streak = state, claimedToday == false, hasEmailConsent {
                claimDailyEntries(auto: true)
            }
        } catch {
            state = .error(.internalError(error.localizedDescription))
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
            } else {
                state = .error(error)
            }

        case .success(let newState):
            let dayIndex = min(newState.currentDay - 1, ladder.count - 1)
            let entriesToday = ladder[max(0, dayIndex)]
            claimedToday = false
            state = .streak(newState, entriesToday, ladder)
        }
    }

    // MARK: - Email capture

    @MainActor
    func submitEmail(_ email: String, marketingConsent: Bool = false) {
        guard !email.isEmpty else { return }

        // NOTE: We deliberately do NOT persist the raw email locally (PII-High).
        // The backend stores it AES-256-encrypted and returns a user_uid handshake;
        // registration state is derived from user_uid in the Keychain instead.
        do {
            try container.storage.save(true, for: emailSubmittedKey)
            try container.storage.save(marketingConsent, for: "winr_marketing_consent")
            Logger.shared.log("WINR email submitted (marketing consent: \(marketingConsent))", level: .info)
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
                let response = try await container.network.send(SubmitEmailRequest(email: email, marketingConsent: marketingConsent))
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
                Logger.shared.log("Email submitted to backend", level: .debug)
            } catch {
                Logger.shared.log("Email submit to backend failed (will retry later): \(error)", level: .error)
            }

            // Re-load so the (possibly switched) canonical user's authoritative
            // streak + claim status drive the UI.
            await load()
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

                // V2 auto-claim routing:
                // - Day 1 (brand-new or restarted streak, typically right after email
                //   capture): the "You're in!" celebration modal is the reveal.
                // - Day 2+: no modal. Land on the dashboard pinned to yesterday's
                //   numbers with a "CLAIM N ENTRIES" pill; the tap reveals the
                //   celebration in place (Joe's Slice Day 2+ flow).
                if auto {
                    if response.streakDay <= 1 {
                        state = .dailyConfirmed(grant, totalEntries: response.totalEntries)
                    } else {
                        pendingRevealGrant = grant
                        claimRevealed = false
                        preClaimTotalEntries = response.totalEntries - (grant.baseEntries + grant.bonusEntries)
                        state = .streak(updatedStreak, response.entries, ladder)
                    }
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

    // MARK: - Completion

    @MainActor
    private func complete(with grant: DailyEntryGrant) {
        state = .completed(grant)
        container.analytics?.trackExperienceClosed(giveawayId: activeGiveaway?.id)
        completion(.success(grant))
    }
}
