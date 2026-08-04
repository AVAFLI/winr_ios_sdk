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

Uses `ConsoleAnalyticsAdapter` (logs to Xcode console) by default. Branding is server-driven — nothing to configure in code.

---

## 2. Manual Entry Point

Open the experience from your own UI at any time:

```swift
@IBAction func enterSweepstakesTapped(_ sender: Any) {
    let presented = WINR.present { result in
        switch result {
        case .success(let grant):
            print("Base: \(grant.baseEntries), Bonus: \(grant.bonusEntries), Total: \(grant.total)")
        case .failure(let error):
            print("WINR error: \(error.localizedDescription)")
        }
    }
    if !presented {
        // SDK not configured, publisher suspended, or user opted out
    }
}
```

Gate your own entry-point UI on availability:

```swift
enterButton.isHidden = !WINR.isAvailable
```

---

## 3. SwiftUI App Integration

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

The auto-open flow needs no further wiring. For a manual button in SwiftUI:

```swift
Button("Enter today's giveaway") {
    WINR.present()
}
```

---

## 4. Push Notification Wiring

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

## 5. Custom Analytics Adapter

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

## 6. GDPR / CCPA Flows

Right-to-be-Forgotten (delete all data):

```swift
Task {
    do {
        try await WINR.deleteAccount()
        print("WINR data deleted.")
    } catch {
        print("Deletion failed: \(error)")
    }
}
```

Right-to-Delete opt-out (never show WINR again):

```swift
Task {
    do {
        try await WINR.optOut()
        print("User opted out — WINR experience permanently silenced.")
    } catch {
        print("Opt-out failed: \(error)")
    }
}
```

---

## 7. Environments

```swift
#if DEBUG
let environment: WINREnvironment = .staging
#else
let environment: WINREnvironment = .production
#endif
```
