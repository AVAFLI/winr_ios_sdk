//
//  WINRUser.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation

public struct WINRUser {
    /// Your app's unique user ID (Firebase UID, database ID, etc.)
    public let id: String

    /// User's first name (required for personalized experiences)
    public let firstName: String

    /// User's last name (required for sweepstakes eligibility)
    public let lastName: String

    /// User's phone number (optional, for SMS notifications)
    public var phone: String?

    /// Create a WINR user with required identity and optional contact info.
    /// Email is NOT accepted here — the SDK captures it via its own consent flow.
    public init(id: String, firstName: String, lastName: String, phone: String? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
    }
}
