//
//  AnalyticsAdapter.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation

// MARK: - Protocol

/// A protocol that publishers implement to route WINR SDK analytics events
/// to their analytics backend (Firebase Analytics, Amplitude, Mixpanel, etc.).
///
/// The SDK ships with ``ConsoleAnalyticsAdapter`` as the default so it works
/// out of the box without any wiring.
public protocol AnalyticsAdapter {
    func track(event: String, properties: [String: Any]?)
}

// MARK: - Event Constants

public enum WINRAnalyticsEvent {
    public static let registration              = "winr_registration"
    public static let experienceOpened           = "winr_experience_opened"
    public static let experienceClosed           = "winr_experience_closed"
    public static let dailyEntryClaimed          = "winr_daily_entry_claimed"
    public static let bonusEntryClaimed          = "winr_bonus_entry_claimed"
    public static let streakMilestone            = "winr_streak_milestone"
    public static let prizeWon                   = "winr_prize_won"

    // Legacy aliases kept for backwards compatibility
    public static let experiencePresented        = experienceOpened
    public static let dailyEntriesClaimed        = dailyEntryClaimed
}

// MARK: - Convenience helpers

public extension AnalyticsAdapter {

    func trackRegistration(userId: String) {
        track(event: WINRAnalyticsEvent.registration, properties: ["user_id": userId])
    }

    func trackExperienceOpened(giveawayId: String? = nil) {
        var props: [String: Any] = [:]
        if let id = giveawayId { props["giveaway_id"] = id }
        track(event: WINRAnalyticsEvent.experienceOpened, properties: props)
    }

    func trackExperienceClosed(giveawayId: String? = nil) {
        var props: [String: Any] = [:]
        if let id = giveawayId { props["giveaway_id"] = id }
        track(event: WINRAnalyticsEvent.experienceClosed, properties: props)
    }

    func trackDailyEntryClaimed(day: Int, entries: Int) {
        track(event: WINRAnalyticsEvent.dailyEntryClaimed, properties: [
            "day": day,
            "entries": entries
        ])
    }

    func trackBonusEntryClaimed(source: String, entries: Int) {
        track(event: WINRAnalyticsEvent.bonusEntryClaimed, properties: [
            "source": source,
            "entries": entries
        ])
    }

    func trackStreakMilestone(day: Int, bonusEntries: Int) {
        track(event: WINRAnalyticsEvent.streakMilestone, properties: [
            "streak_day": day,
            "bonus_entries": bonusEntries
        ])
    }

    func trackPrizeWon(prizeName: String, prizeValue: String? = nil) {
        var props: [String: Any] = ["prize_name": prizeName]
        if let value = prizeValue { props["prize_value"] = value }
        track(event: WINRAnalyticsEvent.prizeWon, properties: props)
    }
}
