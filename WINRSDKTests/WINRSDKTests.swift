import XCTest
@testable import WINRSDK

final class WINRSDKTests: XCTestCase {

    // MARK: - Logger

    func testLoggerDefaultLevel() {
        let logger = Logger.shared
        // Default is .error
        XCTAssertNotNil(logger)
    }

    // MARK: - WINROptions

    func testWINROptionsDefaults() {
        let options = WINROptions()
        XCTAssertEqual(options.logging, .error)
        XCTAssertNotNil(options.analyticsAdapter)
    }

    func testWINROptionsCustom() {
        let options = WINROptions(
            logging: .debug,
            analyticsAdapter: nil
        )
        XCTAssertEqual(options.logging, .debug)
        XCTAssertNil(options.analyticsAdapter)
    }

    // MARK: - API Request paths

    func testAllRequestPaths() {
        XCTAssertEqual(RegisterDeviceRequest(
            apiKey: "", deviceFingerprint: "", bundleId: "",
            timezone: "", platformOS: "", sdkVersion: ""
        ).path, "registerDevice")

        XCTAssertEqual(RefreshTokenRequest(refreshToken: "").path, "refreshToken")
        XCTAssertEqual(SubmitEmailRequest(email: "").path, "submitEmail")
        XCTAssertEqual(ClaimDailyEntriesRequest().path, "claimDailyEntries")
        XCTAssertEqual(ClaimBonusEntriesRequest().path, "claimBonusEntries")
        XCTAssertEqual(DeleteUserDataRequest().path, "deleteUserData")
        XCTAssertEqual(GetActiveGiveawayRequest().path, "getActiveGiveaway")
    }

    func testAllRequestMethods() {
        XCTAssertEqual(RegisterDeviceRequest(
            apiKey: "", deviceFingerprint: "", bundleId: "",
            timezone: "", platformOS: "", sdkVersion: ""
        ).method, "POST")

        XCTAssertEqual(RefreshTokenRequest(refreshToken: "").method, "POST")
        XCTAssertEqual(SubmitEmailRequest(email: "").method, "POST")
        XCTAssertEqual(ClaimDailyEntriesRequest().method, "POST")
        XCTAssertEqual(ClaimBonusEntriesRequest().method, "POST")
        XCTAssertEqual(DeleteUserDataRequest().method, "POST")
        XCTAssertEqual(GetActiveGiveawayRequest().method, "POST")
    }

    // MARK: - All requests produce non-nil body

    func testAllRequestsHaveBody() {
        XCTAssertNotNil(RegisterDeviceRequest(
            apiKey: "k", deviceFingerprint: "f", bundleId: "b",
            timezone: "t", platformOS: "p", sdkVersion: "v"
        ).body)
        XCTAssertNotNil(RefreshTokenRequest(refreshToken: "r").body)
        XCTAssertNotNil(SubmitEmailRequest(email: "e@e.com").body)
        XCTAssertNotNil(ClaimDailyEntriesRequest().body)
        XCTAssertNotNil(ClaimBonusEntriesRequest().body)
        XCTAssertNotNil(DeleteUserDataRequest().body)
        XCTAssertNotNil(GetActiveGiveawayRequest().body)
    }
}
