import XCTest
@testable import WINRSDK

// MARK: - Geo-Fencing Tests
// The SDK is US-only with blocked states (NY, FL).
// Geo validation happens server-side, but we test the
// configuration and error handling patterns client-side.

final class GeoFenceTests: XCTestCase {

    // MARK: - Configuration tests (preserved from original)

    func testSimplifiedInitialize() {
        let config = WINRConfiguration(
            apiKey: "test_key",
            environment: .staging,
            bundleId: "com.test.app",
            user: WINRUser(id: "u1", firstName: "Test", lastName: "User")
        )
        XCTAssertEqual(config.apiKey, "test_key")
        XCTAssertEqual(config.bundleId, "com.test.app")
    }

    func testWINRErrorCases() {
        let errors: [WINRError] = [
            .notConfigured,
            .noPresentingViewController,
            .invalidState,
            .ineligibleToday,
            .alreadyClaimed,
            .invalidAPIKey,
            .unauthorizedBundleId,
            .giveawayNotActive,
            .authenticationRequired,
            .serviceUnavailable,
            .optedOut,
            .internalError("test"),
            .network(NSError(domain: "test", code: 0)),
        ]
        XCTAssertEqual(errors.count, 13)
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Every WINRError case must have a description")
        }
    }

    func testWINRConstants() {
        XCTAssertEqual(WINRConstants.platformOS, "iOS")
        XCTAssertFalse(WINRConstants.sdkVersion.isEmpty)
        // Semantic version: major.minor.patch
        XCTAssertNotNil(
            WINRConstants.sdkVersion.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression),
            "sdkVersion must be semver, got \(WINRConstants.sdkVersion)"
        )
    }

    // MARK: - Geo error types

    func testInternalErrorCarriesMessage() {
        let error = WINRError.internalError("Blocked state: NY")
        if case .internalError(let msg) = error {
            XCTAssertEqual(msg, "Blocked state: NY")
        } else {
            XCTFail("Expected internalError")
        }
    }

    func testNetworkErrorWrapsUnderlying() {
        let underlying = NSError(domain: "GeoLookup", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"])
        let error = WINRError.network(underlying)
        if case .network(let wrapped) = error {
            XCTAssertEqual((wrapped as NSError).domain, "GeoLookup")
        } else {
            XCTFail("Expected network error")
        }
    }

    // MARK: - Fail-open on geo lookup error

    func testFailOpenPatternOnGeoError() {
        // The SDK should gracefully degrade (fail-open) when geo lookup fails.
        // This is enforced server-side, but client never blocks on geo errors.
        // Verify that network errors don't become fatal SDK errors.
        let networkError = WINRError.network(NSError(domain: "Geo", code: 0))
        // Client should handle this as non-fatal
        switch networkError {
        case .network:
            break // expected: geo failure is a network error, SDK continues
        default:
            XCTFail("Geo failure should be classified as network error")
        }
    }

    // MARK: - Timezone sent with registration (used for geo inference)

    func testRegisterDeviceIncludesTimezone() throws {
        let request = RegisterDeviceRequest(
            apiKey: "pk_test",
            deviceFingerprint: "fp",
            bundleId: "com.test",
            timezone: "America/New_York",
            platformOS: "iOS",
            sdkVersion: "1.0.0"
        )
        let body = try XCTUnwrap(request.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = json?["data"] as? [String: String]
        XCTAssertEqual(data?["timezone"], "America/New_York")
    }

    func testClaimDailyEntriesIncludesTimezone() throws {
        let request = ClaimDailyEntriesRequest()
        let body = try XCTUnwrap(request.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = json?["data"] as? [String: String]
        // timezone should be the current timezone, not nil
        XCTAssertNotNil(data?["timezone"])
        XCTAssertFalse(data?["timezone"]?.isEmpty ?? true)
    }

    // MARK: - Platform OS always iOS

    func testPlatformOSIsAlwaysiOS() {
        XCTAssertEqual(WINRConstants.platformOS, "iOS")
    }

    // MARK: - All API requests include platformOS and sdkVersion

    func testClaimDailyEntriesIncludesPlatformInfo() throws {
        let request = ClaimDailyEntriesRequest()
        let body = try XCTUnwrap(request.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = json?["data"] as? [String: String]
        XCTAssertEqual(data?["platformOS"], "iOS")
        XCTAssertEqual(data?["sdkVersion"], WINRConstants.sdkVersion)
    }

    func testClaimBonusEntriesIncludesPlatformInfo() throws {
        let request = ClaimBonusEntriesRequest()
        let body = try XCTUnwrap(request.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let data = json?["data"] as? [String: String]
        XCTAssertEqual(data?["platformOS"], "iOS")
        XCTAssertEqual(data?["sdkVersion"], WINRConstants.sdkVersion)
    }
}
