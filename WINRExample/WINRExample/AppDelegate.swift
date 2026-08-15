//
//  AppDelegate.swift
//  WINRExample
//
//  Demonstrates how to configure the WINR SDK in your iOS app.
//  Copy this pattern into your own AppDelegate or App init.
//

import UIKit
import WINRSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ┌─────────────────────────────────────────────────┐
        // │  STEP 1: Configure the SDK with user identity   │
        // │                                                  │
        // │  Replace apiKey with the key from your           │
        // │  publisher dashboard at:                         │
        // │  https://winrmedia.com/sdk/dashboard    │
        // │                                                  │
        // │  environment is production-only.                 │
        // │                                                  │
        // │  Branding is configured server-side:             │
        // │  - Starter plan: white-label set by WINR team    │
        // │  - Growth/Enterprise: customizable via dashboard │
        // │  No branding config is needed in code.           │
        // │                                                  │
        // │  Pass a WINRUser with your app's user ID,        │
        // │  first name, and last name. You do NOT need to   │
        // │  pass email — the SDK collects it via the email  │
        // │  capture screen when the user first enters the   │
        // │  WINR experience.                                │
        // └─────────────────────────────────────────────────┘

        // In a real app, use YOUR authenticated user's ID here.
        // For this example, we generate a stable ID per device install.
        let userId = UserDefaults.standard.string(forKey: "winr_example_user_id") ?? {
            let id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: "winr_example_user_id")
            return id
        }()

        // The key below is the shared DEMO key: it belongs to the "WINR Test Account"
        // publisher and is server-side restricted to the example apps' bundle IDs, so
        // it is safe to ship in this sample. In YOUR app, load your real key from a
        // non-committed source (e.g. an .xcconfig build setting surfaced via
        // Info.plist, or your secrets manager) — never commit a live production key.
        let config = WINRConfiguration(
            apiKey: "winr_live_50b1b3b801a843d5e1f99593fcad4d14",
            environment: .production,
            bundleId: Bundle.main.bundleIdentifier ?? "com.avafli.winr.example",
            user: WINRUser(
                id: userId,
                firstName: "Demo",
                lastName: "User"
            ),
            options: WINROptions(
                logging: .debug,                                  // Use .error in production
            )
        )

        WINR.configure(config)

        return true
    }

    // MARK: - Push Notifications (Optional)
    //
    // Uncomment these to enable WINR streak reminders via APNs.
    // Also call WINR.registerForPushNotifications() after configure.

    // func application(_ application: UIApplication,
    //                  didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    //     WINR.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    // }
    //
    // func application(_ application: UIApplication,
    //                  didFailToRegisterForRemoteNotificationsWithError error: Error) {
    //     WINR.didFailToRegisterForRemoteNotifications(error: error)
    // }

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}
}
