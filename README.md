# WINR iOS SDK
**Drop-in sweepstakes, prizing, and gamification for your iOS app**

[![Platform](https://img.shields.io/badge/platform-iOS%2015.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-2.9.2-red.svg)](https://cocoapods.org/pods/WINRSDK)

---

## Overview

WINR lets you add daily-entry sweepstakes and prize experiences to your app in under 20 lines of code. The V2 experience is a bottom drawer that opens itself on the first app-open of each day, claims the user's daily entries automatically, and celebrates the result. You integrate once; prize configuration and branding are managed server-side from the WINR dashboard.

**Key capabilities:**
- **Daily entry sweepstakes** — Users earn entries every day they engage
- **V2 auto-open experience** — The bottom-drawer experience opens itself on the first app-open of each day and grants entries automatically
- **Daily streak ladder + auto-claim** — A simple +10-entries-per-day ladder, claimed automatically the moment the drawer opens
- **Email capture with explicit consent** — The SDK captures an email through its own screen, with an unchecked-by-default marketing-consent box and a publisher-configurable age gate
- **Cross-device verified adoption** — Typing an email that matches an existing WINR account requires a 6-digit code before the streak merges to the new device
- **"Verify your email" soft-verification** — A persistent chip on the dashboard lets users confirm a brand-new typed address; it never blocks daily play, only prize-draw eligibility
- **Winner announcements** — "WE HAVE A WINNER!" banner and winner dialog, driven by the giveaway's `latestWinner`
- **Visit mode** — A never-resetting streak variant for low-frequency apps
- **Push reminders** — Drive re-engagement with daily nudges (FCM, with local fallback)
- **Server-driven branding** — Logo, prize image, and primary color update without app releases
- **GDPR/CCPA compliant** — Built-in consent flows plus an RTD opt-out (`optOut()`) reachable in-app via Privacy choices → delete my data
- **Analytics forwarding** — Route SDK events to your existing analytics stack

## Quick Start

```swift
import WINRSDK

let config = WINRConfiguration(
    apiKey: "YOUR_API_KEY",  // debug builds: use your winr_test_ sandbox key
    bundleId: "com.example.myapp",
    user: WINRUser(
        id: "user_123",             // only id is required — pass whatever identity you have
        firstName: "Jane",
        lastName: "Doe",
        email: "jane@example.com"   // include it when you have it — pre-fills & locks the capture form (consent stays explicit)
    ),
    // Nobody signed in? use user: .guest
    options: WINROptions(
        logging: .error,            // use .debug while integrating
        enablePushReminders: true   // streak reminders via YOUR Firebase project (upload the key in your dashboard)
    )
)
WINR.configure(config)

// Done — the experience auto-opens once per day. No further calls needed.
// Push reminders: forward your FCM token so they can deliver:
//   WINR.didReceiveFCMToken(token)
```

> **Auto-open:** After `configure(_:)`, the SDK presents the experience automatically once per calendar day (on launch and whenever the app returns to the foreground on a new day). It can be disabled remotely via the dashboard's `experience.autoOpenEnabled` kill switch; unregistered users see at most 3 auto-opens until they submit an email, and RTD opted-out users never see it.

### Identity — pass what you have, the SDK captures the rest

Only `id` is required. Construct a `WINRUser` from whatever identity data you
already hold — even just an id — and the SDK fills in the gaps: it captures the
email through its own screen, and the name at prize-claim time if the user wins.
There are three cases:

**1. Signed-in user without an email (the common case, and WINR's main value).**
Pass the id plus whatever you have and OMIT `email`. The SDK shows its capture
screen and the user types their email — so you capture an address you didn't
have before:

```swift
user: WINRUser(id: "user_123", firstName: "Jane", lastName: "Doe")   // no email
```

Even just `WINRUser(id: "user_123")` is valid — name is collected later at
prize-claim, only if they win.

**2. Signed-in user with an email.** Pass `email` too and it pre-fills and
**locks** the capture field (consent is still an explicit tick inside the flow).
`email` is a plain `String`:

```swift
user: WINRUser(id: "user_123", firstName: "Jane", lastName: "Doe", email: "jane@example.com")
```

**3. No signed-in user at all.** Pass `WINRUser.guest`:

```swift
WINR.configure(WINRConfiguration(
    apiKey: "winr_live_…",
    environment: .production,  // optional — defaults to .production (2.8.0+)
    bundleId: Bundle.main.bundleIdentifier!,
    user: .guest
))
```

The SDK mints a stable per-install guest id (`winr_guest_…`) for attribution —
never fabricate placeholder ids yourself. The experience is fully functional
for guests. When the user signs in, call `configure` again with the real user:
attribution upgrades in place and the streak carries over automatically.

## Installation

WINR is distributed via **Swift Package Manager** and **CocoaPods**:

### Xcode

1. **File → Add Package Dependencies…**
2. Enter the repository URL: `https://github.com/AVAFLI/winr_ios_sdk.git`
3. Set dependency rule to **Up to Next Major Version** from `2.9.2`
4. Add the `WINR` library to your app target

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/AVAFLI/winr_ios_sdk.git", from: "2.9.2")
]
```

### CocoaPods

Add the pod to your `Podfile`:

```ruby
pod 'WINRSDK', '~> 2.9'
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
    environment: .production,  // optional — defaults to .production (2.8.0+)
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
| `id` | `String` | ✅ | Unique, stable user identifier (the only required field) |
| `firstName` | `String` | — | User's first name; captured at prize-claim if omitted |
| `lastName` | `String` | — | User's last name; captured at prize-claim if omitted |
| `phone` | `String?` | — | Phone number in E.164 format |
| `email` | `String?` | — | If passed, pre-fills and locks the capture field; if omitted, the SDK captures it |

> **Email:** Omit it and the SDK captures an address through its own opt-in
> screen (the common case). Pass it and that address pre-fills and locks —
> consent is still an explicit tick inside the flow. See the three identity
> cases above.

## Test in Development: Your Sandbox Key

Your publisher dashboard shows two API keys:

| Key | Use it in |
| --- | --------- |
| `winr_live_…` | Release builds — your real giveaway |
| `winr_test_…` | Debug/dev builds and CI — an isolated sandbox |

The sandbox key hits the **same production backend** with identical behavior —
registration, streaks, entries, the full experience — but every user and entry
lands in a separate sandbox tenant with its own always-active test giveaway.
That means:

- Your developers and testers **can never enter (or win) your real giveaway.**
- Sandbox usage **never counts toward your MAU** or your bill.
- Your registered bundle IDs work with both keys automatically.

Swap keys per build configuration and nothing else about your integration
changes.

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

Plus prize configuration (active giveaways and the daily entry ladder) and push reminder schedules.

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
- `winr_prize_won` — The user was selected as a winner

## GDPR / CCPA

Handle erasure requests with `optOut()`:

```swift
Task {
    do {
        try await WINR.optOut()
        print("User opted out; data erased.")
    } catch {
        print("Opt-out failed: \(error)")
    }
}
```

This is the complete Right-to-be-Forgotten path. It removes the person's personal
information everywhere it is held — including prize-claim records, which carry name,
address and phone — links their devices together so one call covers all of them, and
permanently silences the experience on the device so it survives a reinstall.

Users can also trigger this themselves without any wiring from you: the how-it-works
("?") screen has a **Privacy choices → delete my data** link that confirms and runs
the same opt-out.

De-identified entry records are deliberately retained. They are the evidence that a
drawing was fair and that a prize went to a real eligible person, which a sweepstakes
operator must be able to show; GDPR Art. 17(3) exempts data needed for legal claims.
The person is erased, the proof is kept.

> `optOut()` is the only erasure API. There is no hard-delete of entry records —
> that would both destroy the fairness evidence above and, leaving no tombstone,
> let delete-and-re-register farm unlimited entries.


## API Reference

### Core Methods

| Method | Returns | Description |
| ------ | ------- | ----------- |
| `WINR.configure(config)` | `Void` | Initialize the SDK; the experience auto-opens once per day |
| `WINR.optOut()` | `async throws` | RTD opt-out — permanently silence the experience |

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
