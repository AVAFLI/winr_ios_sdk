//
//  WINRError.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation

public enum WINRError: Error {
    case notConfigured
    case noPresentingViewController
    case network(Error)
    case invalidState
    case ineligibleToday
    case alreadyClaimed
    case invalidAPIKey
    case unauthorizedBundleId
    case giveawayNotActive
    case authenticationRequired
    /// The publisher's WINR account is suspended or its API key has been
    /// revoked (e.g. billing lapsed). The experience should silently degrade:
    /// default-UI integrations present nothing, custom-UI integrations can
    /// surface their own "unavailable" messaging.
    case serviceUnavailable
    /// The user has exercised their right to delete (RTD) and opted out of WINR.
    /// The experience must never be presented to them again.
    case optedOut
    case internalError(String)
}

extension WINRError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "WINR SDK is not configured. Call WINR.configure(_:) first."
        case .noPresentingViewController:
            return "No presenting view controller could be found."
        case .network(let error):
            return error.localizedDescription
        case .invalidState:
            return "The WINR experience is in an invalid state."
        case .ineligibleToday:
            return "You are not eligible to claim entries today."
        case .alreadyClaimed:
            return "You have already claimed your entries today."
        case .invalidAPIKey:
            return "The WINR API key is invalid."
        case .unauthorizedBundleId:
            return "This app's bundle identifier is not authorized for the provided WINR API key."
        case .giveawayNotActive:
            return "There is no active giveaway right now."
        case .authenticationRequired:
            return "Authentication is required."
        case .serviceUnavailable:
            return "This experience is currently unavailable."
        case .optedOut:
            return "This user has opted out of WINR."
        case .internalError(let message):
            return message
        }
    }
}
