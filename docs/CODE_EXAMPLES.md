# WINR SDK — Code Examples

Real-world integration examples for common use cases. See the [README](../README.md) for the canonical API overview.

---

## 1. Minimal Integration

Configure once at launch — the experience auto-opens on the first app-open of each day and claims entries automatically:

```swift
import WINRSDK

// AppDelegate.swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    let config = WINRConfiguration(
        apiKey: "YOUR_API_KEY",
        environment: .production,
        bundleId: Bundle.main.bundleIdentifier ?? "",
        user: WINRUser(
            id: "user_123",
            firstName: "Jane",
            lastName: "Doe"
        )
    )
    WINR.configure(config)
    return true
}
```

Uses `ConsoleAnalyticsAdapter` (logs to Xcode console) by default. Branding is server-driven — nothing to configure in code. The experience is exclusively auto-opened by the SDK; there is no manual launch API.

---

## 2. SwiftUI App Integration

```swift
import SwiftUI
import WINRSDK

@main
struct MyApp: App {
    init() {
        WINR.configure(WINRConfiguration(
            apiKey: "YOUR_API_KEY",
            environment: .production,
            bundleId: Bundle.main.bundleIdentifier ?? "",
            user: WINRUser(id: "user_123", firstName: "Jane", lastName: "Doe")
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

The auto-open flow needs no further wiring — the experience opens itself once per day.

---

## 3. Push Notification Wiring

```swift
import WINRSDK
import FirebaseMessaging

// After WINR.configure(...)
WINR.registerForPushNotifications()

// AppDelegate
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    WINR.didRegisterForRemoteNotifications(deviceToken: deviceToken)
}

func application(_ application: UIApplication,
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
    WINR.didFailToRegisterForRemoteNotifications(error: error)
}

// MessagingDelegate — required for server-sent reminders
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let fcmToken { WINR.didReceiveFCMToken(fcmToken) }
}
```

Apps without Firebase Messaging still get a daily **local** streak reminder as a fallback.

---

## 4. Custom Analytics Adapter

```swift
import WINRSDK

final class SegmentAnalyticsAdapter: AnalyticsAdapter {
    func track(event: String, properties: [String: Any]?) {
        Analytics.shared().track(event, properties: properties)
    }
}

let config = WINRConfiguration(
    apiKey: "YOUR_API_KEY",
    environment: .production,
    bundleId: Bundle.main.bundleIdentifier ?? "",
    user: WINRUser(id: "user_123", firstName: "Jane", lastName: "Doe"),
    options: WINROptions(
        logging: .info,
        analyticsAdapter: SegmentAnalyticsAdapter(),
        enablePushReminders: true
    )
)
WINR.configure(config)
```

See the [event list](API_REFERENCE.md#winranalyticsevent) for everything the SDK emits.

---

## 5. GDPR / CCPA Flows

Right-to-be-Forgotten — `optOut()` is the single, complete erasure path. It
scrubs the person's PII everywhere (including prize-claim records), links their
devices so one call covers all of them, tombstones so it survives a reinstall,
and permanently silences the experience:

```swift
Task {
    do {
        try await WINR.optOut()
        print("User opted out — data erased, WINR experience permanently silenced.")
    } catch {
        print("Opt-out failed: \(error)")
    }
}
```

Users can also run the same opt-out themselves, no wiring required: the
Privacy Policy opens in an in-app webview from any legal link, and its
**Delete my data & stop participating** section confirms and runs it.

---

## 6. Environments

```swift
let environment: WINREnvironment = .production  // production-only
```
