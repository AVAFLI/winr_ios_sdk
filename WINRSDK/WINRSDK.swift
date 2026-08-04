//
//  WINRSDK.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation

#if !SWIFT_PACKAGE
// SwiftPM synthesizes `Bundle.module` for resource access. When the SDK is
// built from WINRSDK.xcodeproj (framework target, e.g. for the unit tests),
// no such accessor exists — provide an equivalent that resolves to the
// framework's own bundle.
private final class WINRSDKBundleAnchor {}

extension Bundle {
    static let module: Bundle = Bundle(for: WINRSDKBundleAnchor.self)
}
#endif
