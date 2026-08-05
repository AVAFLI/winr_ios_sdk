//
//  WINRConfiguration.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation
import SwiftUI

public enum WINRConstants {
    /// Single source of truth for the SDK version. MUST match `WINRSDK.podspec`
    /// (`s.version`) and the latest CHANGELOG entry. Format: `v<major>.<minor>.<patch>`.
    public static let sdkVersion = "2.4.0"
    public static let platformOS = "iOS"
    
    // Hardcoded legal URLs — consistent across all publishers
    static let rulesURL = "https://avafli-website.web.app/sdk/rules"
    static let privacyURL = "https://avafli-website.web.app/sdk/privacy"
}

public struct WINRConfiguration {
    public let apiKey: String
    public let environment: WINREnvironment
    public let bundleId: String
    public let user: WINRUser
    public let options: WINROptions

    public init(
        apiKey: String,
        environment: WINREnvironment,
        bundleId: String,
        user: WINRUser,
        options: WINROptions = .init()
    ) {
        self.apiKey = apiKey
        self.environment = environment
        self.bundleId = bundleId
        self.user = user
        self.options = options
    }
}
