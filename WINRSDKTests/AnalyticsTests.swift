import XCTest
@testable import WINRSDK

// MARK: - Spy Analytics Adapter

final class SpyAnalyticsAdapter: AnalyticsAdapter {
    var trackedEvents: [(event: String, properties: [String: Any]?)] = []

    func track(event: String, properties: [String: Any]?) {
        trackedEvents.append((event: event, properties: properties))
    }

    var lastEvent: String? { trackedEvents.last?.event }
    var lastProperties: [String: Any]? { trackedEvents.last?.properties }
}

// MARK: - Analytics Tests

final class AnalyticsTests: XCTestCase {

    // MARK: - Event constants

    func testAnalyticsEventConstants() {
        XCTAssertEqual(WINRAnalyticsEvent.registration, "winr_registration")
        XCTAssertEqual(WINRAnalyticsEvent.experienceOpened, "winr_experience_opened")
        XCTAssertEqual(WINRAnalyticsEvent.experienceClosed, "winr_experience_closed")
        XCTAssertEqual(WINRAnalyticsEvent.dailyEntryClaimed, "winr_daily_entry_claimed")
        XCTAssertEqual(WINRAnalyticsEvent.bonusEntryClaimed, "winr_bonus_entry_claimed")
        XCTAssertEqual(WINRAnalyticsEvent.streakMilestone, "winr_streak_milestone")
        XCTAssertEqual(WINRAnalyticsEvent.prizeWon, "winr_prize_won")
    }

    func testLegacyAliases() {
        XCTAssertEqual(WINRAnalyticsEvent.experiencePresented, WINRAnalyticsEvent.experienceOpened)
        XCTAssertEqual(WINRAnalyticsEvent.dailyEntriesClaimed, WINRAnalyticsEvent.dailyEntryClaimed)
    }

    // MARK: - Spy adapter tracks events

    func testSpyAdapterTracksRegistration() {
        let spy = SpyAnalyticsAdapter()
        spy.trackRegistration(userId: "user-123")
        XCTAssertEqual(spy.lastEvent, "winr_registration")
        XCTAssertEqual(spy.lastProperties?["user_id"] as? String, "user-123")
    }

    func testSpyAdapterTracksExperienceOpened() {
        let spy = SpyAnalyticsAdapter()
        spy.trackExperienceOpened(giveawayId: "camp_1")
        XCTAssertEqual(spy.lastEvent, "winr_experience_opened")
        XCTAssertEqual(spy.lastProperties?["giveaway_id"] as? String, "camp_1")
    }

    func testSpyAdapterTracksExperienceOpenedNoGiveaway() {
        let spy = SpyAnalyticsAdapter()
        spy.trackExperienceOpened()
        XCTAssertEqual(spy.lastEvent, "winr_experience_opened")
        XCTAssertTrue(spy.lastProperties?.isEmpty ?? true)
    }

    func testSpyAdapterTracksExperienceClosed() {
        let spy = SpyAnalyticsAdapter()
        spy.trackExperienceClosed(giveawayId: "camp_2")
        XCTAssertEqual(spy.lastEvent, "winr_experience_closed")
    }

    func testSpyAdapterTracksDailyEntryClaimed() {
        let spy = SpyAnalyticsAdapter()
        spy.trackDailyEntryClaimed(day: 3, entries: 60)
        XCTAssertEqual(spy.lastEvent, "winr_daily_entry_claimed")
        XCTAssertEqual(spy.lastProperties?["day"] as? Int, 3)
        XCTAssertEqual(spy.lastProperties?["entries"] as? Int, 60)
    }

    func testSpyAdapterTracksBonusEntryClaimed() {
        let spy = SpyAnalyticsAdapter()
        spy.trackBonusEntryClaimed(source: "rewarded_video", entries: 60)
        XCTAssertEqual(spy.lastEvent, "winr_bonus_entry_claimed")
        XCTAssertEqual(spy.lastProperties?["source"] as? String, "rewarded_video")
    }

    func testSpyAdapterTracksStreakMilestone() {
        let spy = SpyAnalyticsAdapter()
        spy.trackStreakMilestone(day: 6, bonusEntries: 300)
        XCTAssertEqual(spy.lastEvent, "winr_streak_milestone")
        XCTAssertEqual(spy.lastProperties?["streak_day"] as? Int, 6)
        XCTAssertEqual(spy.lastProperties?["bonus_entries"] as? Int, 300)
    }

    func testSpyAdapterTracksPrizeWon() {
        let spy = SpyAnalyticsAdapter()
        spy.trackPrizeWon(prizeName: "$1000 Cash", prizeValue: "1000")
        XCTAssertEqual(spy.lastEvent, "winr_prize_won")
        XCTAssertEqual(spy.lastProperties?["prize_name"] as? String, "$1000 Cash")
        XCTAssertEqual(spy.lastProperties?["prize_value"] as? String, "1000")
    }

    func testSpyAdapterTracksPrizeWonWithoutValue() {
        let spy = SpyAnalyticsAdapter()
        spy.trackPrizeWon(prizeName: "Mystery Prize")
        XCTAssertNil(spy.lastProperties?["prize_value"])
    }

    func testMultipleEventsTracked() {
        let spy = SpyAnalyticsAdapter()
        spy.trackRegistration(userId: "u1")
        spy.trackExperienceOpened()
        spy.trackDailyEntryClaimed(day: 1, entries: 10)
        spy.trackExperienceClosed()
        XCTAssertEqual(spy.trackedEvents.count, 4)
    }

    // MARK: - ConsoleAnalyticsAdapter exists and conforms

    func testConsoleAnalyticsAdapterConformsToProtocol() {
        let adapter: AnalyticsAdapter = ConsoleAnalyticsAdapter()
        // Should not crash
        adapter.track(event: "test_event", properties: ["key": "value"])
        adapter.track(event: "test_event_no_props", properties: nil)
        adapter.track(event: "test_event_empty", properties: [:])
    }

    // MARK: - Default options use ConsoleAnalyticsAdapter

    func testDefaultOptionsUseConsoleAdapter() {
        let options = WINROptions()
        XCTAssertNotNil(options.analyticsAdapter)
        XCTAssertTrue(options.analyticsAdapter is ConsoleAnalyticsAdapter)
    }
}
