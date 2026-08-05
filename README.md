# WINR iOS SDK
**Drop-in sweepstakes, prizing, and gamification for your iOS app**

[![Platform](https://img.shields.io/badge/platform-iOS%2015.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-2.4.0-red.svg)](https://cocoapods.org/pods/WINRSDK)

---

## Overview

WINR lets you add daily-entry sweepstakes and prize experiences to your app in under 20 lines of code. The V2 experience is a bottom drawer that opens itself on the first app-open of each day, claims the user's daily entries automatically, and celebrates the result. You integrate once; prize configuration and branding are managed server-side from the WINR dashboard.

**Key capabilities:**
- **Daily entry sweepstakes** — Users earn entries every day they engage
- **V2 auto-open experience** — The bottom-drawer experience opens itself on the first app-open of each day and grants entries automatically
- **Streak ladder + milestone accelerators** — Escalating daily entry rewards, with server-configurable milestone bonuses
- **Winner announcements** — "WE HAVE A WINNER!" banner and winner dialog, driven by the giveaway's `latestWinner`
- **Visit mode** — A never-resetting streak variant for low-frequency apps
- **Push reminders** — Drive re-engagement with daily nudges (FCM, with local fallback)
- **Server-driven branding** — Logo, prize image, and primary color update without app releases
- **GDPR/CCPA compliant** — Built-in consent flows, RTD opt-out, and user data deletion
- **Analytics forwarding** — Route SDK events to your existing analytics stack

## Quick Start

```swift
import WINRSDK

// 1. Configure the SDK — call once at app launch
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

// 2. That's it — one call, and the experience opens itself
//    once per day on the first app-open of the day.
```

> **Auto-open:** After `configure(_:)`, the SDK presents the experience automatically once per calendar day (on launch and whenever the app returns to the foreground on a new day). It can be disabled remotely via the dashboard's `experience.autoOpenEnabled` kill switch; unregistered users see at most 3 auto-opens until they submit an email, and RTD opted-out users never see it.

## Installation

WINR is distributed via **Swift Package Manager** and **CocoaPods**:

### Xcode

1. **File → Add Package Dependencies…**
2. Enter the repository URL: `https://github.com/AVAFLI/winr_ios_sdk.git`
3. Set dependency rule to **Up to Next Major Version** from `2.4.0`
4. Add the `WINR` library to your app target

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/AVAFLI/winr_ios_sdk.git", from: "2.4.0")
]
```

### CocoaPods

Add the pod to your `Podfile`:

```ruby
pod 'WINRSDK', '~> 2.3'
```

Then run:

```bash
pod install
```

> **Note:** Contact [AVAFLI](https://avafli-website.web.app/sdk/pricing) to obtain an API key.

## Configuration

Initialize the SDK with your user and environment settings:

```swift
let config = WINRConfiguration(
    apiKey: "winr_live_xxxxxxxxxx",
    environment: .production,
    bundleId: "com.example.myapp",
    user: WINRUser(
        id: "user_abc123",
        firstName: "Jane",
        lastName: "Doe",
        phone: "+15551234567"  // optional
    ),
    options: WINROptions(
        logging: .info,
        analyticsAdapter: myAnalyticsAdapter,
        enablePushReminders: true
    )
)

WINR.configure(config)
```

### WINRConfiguration

| Parameter | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `apiKey` | `String` | ✅ | Your WINR API key from the dashboard |
| `environment` | `WINREnvironment` | ✅ | `.production` (the only environment) |
| `bundleId` | `String` | ✅ | App bundle ID (e.g., com.example.myapp) |
| `user` | `WINRUser` | ✅ | The authenticated user |
| `options` | `WINROptions?` | — | Optional behavior toggles |

### WINROptions

| Parameter | Type | Default | Description |
| --------- | ---- | ------- | ----------- |
| `logging` | `LoggingLevel` | `.error` | `.none`, `.error`, `.info`, or `.debug` |
| `analyticsAdapter` | `AnalyticsAdapter?` | `ConsoleAnalyticsAdapter()` | Routes SDK events to your analytics stack |
| `enablePushReminders` | `Bool` | `true` | Enables streak reminder push notifications |

### WINRUser

| Parameter | Type | Required | Description |
| --------- | ---- | -------- | ----------- |
| `id` | `String` | ✅ | Unique, stable user identifier |
| `firstName` | `String` | ✅ | User's first name |
| `lastName` | `String` | ✅ | User's last name |
| `phone` | `String?` | — | Phone number in E.164 format |

> **Email:** The SDK captures email through its own opt-in UI. Do not pass email via `WINRUser`.

## The Experience Opens Itself

The V2 experience presents itself automatically once per calendar day (first app-open of the day). Entries are claimed automatically when it opens, and the celebration is the first thing the user sees: the dashboard opens with today's grant already showing — the day tile checks off with a confetti burst, the total counts up and pops, and the bar leads with a "YOU'RE ON A ROLL!" toast before settling into the come-back message. There is no button to tap to collect entries (the pill just reads GOT IT and closes), and no manual launch API — `configure(_:)` is the entire integration, and the SDK handles everything else. Brand-new users first submit their email, then get a one-time "You're in!" welcome modal.

## Winner Experience

When one of your users is drawn as a giveaway winner, the drawer automatically opens on a winner splash instead of the dashboard, then walks them through a stepped prize-claim form with progress dots (name, shipping address, optional photo and story) plus a review-and-agree screen, ending in a confirmation with their claim number on the OFFICIAL WINNER card. The winning email is never re-entered — a backend-masked address is shown for recognition and the claim is keyed to the account server-side. This requires no integration work — the flow appears only for the drawn winner and disappears once their claim is submitted.

## Push Notifications

Drive re-engagement with daily streak reminders. The SDK handles permission and APNs registration; you forward the token from your `AppDelegate`:

### 1. Register for Notifications

```swift
// After WINR.configure() — requests permission and registers for APNs.
// No-op if WINROptions.enablePushReminders is false.
WINR.registerForPushNotifications()
```

### 2. Forward Tokens

Server-sent reminders are delivered through Firebase Cloud Messaging using the
Firebase service account your team uploads in the WINR publisher dashboard. If
your app uses Firebase Messaging, forward the FCM registration token:

```swift
// MessagingDelegate
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let fcmToken { WINR.didReceiveFCMToken(fcmToken) }
}
```

Also forward the standard APNs callbacks from your `AppDelegate`:

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    WINR.didRegisterForRemoteNotifications(deviceToken: deviceToken)
}

func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
) {
    WINR.didFailToRegisterForRemoteNotifications(error: error)
}
```

Apps without Firebase Messaging still get engagement nudges: the SDK schedules
a daily **local** streak reminder as a fallback whenever no FCM token is
available (or notification permission is denied).

### 3. Upload Firebase Service Account Key

Upload your Firebase service account key via the [WINR Dashboard](https://avafli-website.web.app/sdk/dashboard) — server-sent reminders go through your own Firebase project. Reminder schedules and messaging are configured server-side from the dashboard.

## Customization

The V2 experience is hardcoded to the WINR design; publishers customize exactly three things through the [WINR Dashboard](https://avafli-website.web.app/sdk/dashboard):

- **Logo** — Shown in the drawer header
- **Prize image** — Art for the dashboard prize card
- **Primary color** — Accent for CTAs, streak tiles, and highlights

Plus prize configuration (active giveaways, ladder, milestones) and push reminder schedules.

Changes apply instantly across all app installations without requiring an app update.

## Analytics

Forward WINR events to your existing analytics stack:

```swift
class MyAnalyticsAdapter: AnalyticsAdapter {
    func track(event: String, properties: [String: Any]?) {
        // Forward to Mixpanel, Amplitude, Segment, etc.
        Analytics.shared.track(event, properties: properties)
    }
}

// Pass during configuration
let options = WINROptions(
    logging: .info,
    analyticsAdapter: MyAnalyticsAdapter(),
    enablePushReminders: true
)
```

**Events emitted by the SDK** (constants on `WINRAnalyticsEvent`):
- `winr_registration` — Device/user registered with WINR
- `winr_experience_opened` — The WINR experience opened (once-per-day auto-open)
- `winr_experience_closed` — The WINR experience was dismissed
- `winr_daily_entry_claimed` — Daily entries awarded (auto-claimed on open)
- `winr_bonus_entry_claimed` — Bonus entries granted (e.g., streak accelerators)
- `winr_streak_milestone` — A streak milestone was reached
- `winr_prize_won` — The user was selected as a winner

## GDPR / CCPA

Support deletion requests with `deleteAccount` (Right-to-be-Forgotten):

```swift
Task {
    do {
        try await WINR.deleteAccount()
        print("User data deleted successfully.")
    } catch {
        print("Deletion failed: \(error)")
    }
}
```

This permanently removes all user data, entries, preferences, and consent records from WINR servers.

For Right-to-Delete opt-outs (user asks to never see WINR again), call `WINR.optOut()` — it tombstones the person on the backend and permanently silences the experience on the device.

## API Reference

### Core Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `WINR.configure(config)` | `Void` | Initialize the SDK; the experience auto-opens once per day |
| `WINR.optOut()` | `async throws` | RTD opt-out — permanently silence the experience |
| `WINR.deleteAccount()` | `async throws` | Permanently delete all user data |

### Push Notifications

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `WINR.registerForPushNotifications()` | `Void` | Request permission and register for APNs |
| `WINR.didRegisterForRemoteNotifications(deviceToken:)` | `Void` | Forward APNs token to WINR |
| `WINR.didFailToRegisterForRemoteNotifications(error:)` | `Void` | Forward APNs registration failure to WINR |

For detailed API documentation, see the [WINR Docs](https://avafli-website.web.app/sdk/ios).

## Links

- **Dashboard:** [https://avafli-website.web.app/sdk/dashboard](https://avafli-website.web.app/sdk/dashboard)
- **Documentation:** [https://avafli-website.web.app/sdk/ios](https://avafli-website.web.app/sdk/ios)
- **Support:** [info@avafli.com](mailto:info@avafli.com)

---

© 2026 Avafli. All Rights Reserved.
