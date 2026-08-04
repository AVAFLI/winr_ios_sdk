//
//  WINRLogo.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation

public enum WINRLogo: Equatable {
    case asset(name: String)      // static image in asset catalog
    case remote(url: URL)         // remote static image
    case lottie(name: String)     // bundled Lottie JSON (e.g. "amazon-gift-card")
    case remoteLottie(url: URL)   // remote Lottie JSON from server
    case system(String)           // SF Symbol name (e.g. "gift.fill")
    case bundled(name: String)    // image bundled in app (e.g. "avafli-logo")
}
