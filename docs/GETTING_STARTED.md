# WINR SDK — Getting Started Guide

## Overview

WINR SDK enables app publishers to instantly add sweepstakes and prizing functionality to their iOS apps. Users earn daily entries with escalating streak rewards and server-configurable milestone bonuses. The SDK handles device registration, token management, email capture, streak tracking, and entry submission behind a fully managed UI.

The V2 experience is a bottom drawer that opens itself on the first app-open of each day, claims the user's daily entries automatically, and celebrates the result. You integrate once; prize configuration and branding are managed server-side from the WINR dashboard.

> This guide is a condensed walkthrough. The [README](../README.md) is the canonical reference for the current API surface.

---

## Requirements

| Requirement | Minimum Version |
|-------------|----------------|
| iOS | 15.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| Publisher API Key | Contact team@avafli.com |

The SDK uses SwiftUI for its presentation layer and requires a UIKit host app (UIViewController-based presentation).

---

## Installation

### Swift Package Manager (Recommended)

1. In Xcode, go to **File → Add Package Dependencies**
2. Enter the repository URL:
   ```
   https://github.com/AVAFLI/winr_ios_sdk.git
   ```
3. Set the dependency rule to **Up to Next Major Version** from `2.3.0`
4. Add the `WINRSDK` library to your app target

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AVAFLI/winr_ios_sdk.git", from: "2.3.0")
]
```

### CocoaPods

Add the pod to your `Podfile` and install:

```ruby
pod 'WINRSDK', '~> 2.3'
```

```bash
pod install
```

---

## Configure the SDK

Call `WINR.configure(_:)` once at app launch:

```swift
import WINRSDK

let config = WINRConfiguration(
    apiKey: "YOUR_API_KEY",
    environment: .production,
    bundleId: "com.example.myapp",
    user: WINRUser(
        id: "user_123",
        firstName: "Jane",
        lastName: "Doe"
    )
)
WINR.configure(config)
```

That's it. Configuration registers the device in the background and fetches the active giveaway. The experience then **auto-opens once per calendar day** — on launch and whenever the app returns to the foreground on a new day. Entries are claimed automatically when the drawer opens.

Auto-open behavior:

- It can be disabled remotely from the dashboard (`experience.autoOpenEnabled`).
- Unregistered users (no confirmed email) see at most 3 auto-opens, then the SDK goes quiet until they register.
- Users who opted out (Right-to-Delete) never see the experience again.

The auto-open is the only way the experience appears — there is no manual launch API. One call, and the experience opens itself once per day.

> **Email:** The SDK captures email through its own opt-in consent UI. Do not pass email via `WINRUser`.

---

## Push Reminders

The SDK can nudge users to keep their streak alive. After configuring:

```swift
WINR.registerForPushNotifications()  // no-op if WINROptions.enablePushReminders is false
```

Forward the APNs callbacks from your `AppDelegate`:

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    WINR.didRegisterForRemoteNotifications(deviceToken: deviceToken)
}

func application(_ application: UIApplication,
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
    WINR.didFailToRegisterForRemoteNotifications(error: error)
}
```

If your app uses Firebase Messaging, also forward the FCM registration token so WINR's backend can send server-driven reminders through your Firebase project:

```swift
// MessagingDelegate
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let fcmToken { WINR.didReceiveFCMToken(fcmToken) }
}
```

Without an FCM token (or if notification permission is denied), the SDK falls back to a daily **local** reminder.

---

## Branding

The V2 experience is server-driven: logo, prize image, and primary accent color are configured in the [WINR Dashboard](https://avafli-website.web.app/sdk/dashboard) and update without an app release. There is nothing to configure in code.

---

## Analytics

Route SDK events to your analytics stack by passing an `AnalyticsAdapter` in `WINROptions` — see [CODE_EXAMPLES.md](CODE_EXAMPLES.md) and the [README's Analytics section](../README.md#analytics) for the event list.

---

## Privacy (GDPR / CCPA)

- `try await WINR.deleteAccount()` — Right-to-be-Forgotten: permanently deletes all user data from WINR servers and clears local storage.
- `try await WINR.optOut()` — Right-to-Delete opt-out: tombstones the person on the backend and permanently silences the experience on this device.

---

## Next Steps

- [API Reference](API_REFERENCE.md) — every public type and method
- [Code Examples](CODE_EXAMPLES.md) — copy-paste integration recipes
- [README](../README.md) — canonical overview and API tables
