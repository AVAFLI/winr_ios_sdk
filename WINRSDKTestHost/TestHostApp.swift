//
//  TestHostApp.swift
//  WINRSDKTestHost
//
//  Minimal host application for the WINRSDKTests bundle. A host app is
//  required so the test process has an application identity — without one,
//  Keychain access on the iOS simulator fails with errSecMissingEntitlement
//  (-34018). Not shipped; test infrastructure only.
//

import SwiftUI

@main
struct TestHostApp: App {
    var body: some Scene {
        WindowGroup {
            Text("WINRSDK Test Host")
        }
    }
}
