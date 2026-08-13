# WINR SDK — API Reference

The [README](../README.md) is the canonical overview of the SDK; this page documents every public symbol in v2.

## Table of Contents

- [WINR (Static API)](#winr-static-api)
- [WINRConfiguration](#winrconfiguration)
- [WINROptions](#winroptions)
- [WINREnvironment](#winrenvironment)
- [WINRUser](#winruser)
- [WINRError](#winrerror)
- [DailyEntryGrant](#dailyentrygrant)
- [AnalyticsAdapter](#analyticsadapter)
- [WINRAnalyticsEvent](#winranalyticsevent)
- [WINRConstants](#winrconstants)

---

## WINR (Static API)

```swift
public enum WINR
```

The primary entry point for the SDK. All methods are static.

### `configure(_:)`

```swift
public static func configure(_ configuration: WINRConfiguration)
```

The single entry point — call once at app launch. Stores the configuration, sets the logging level, registers the device in the background, and fetches the active giveaway. After registration completes (and on each app foreground), the SDK presents the experience automatically at most once per calendar day — this is the only way the experience appears; there is no manual launch API. Auto-open can be disabled remotely via the dashboard; unregistered users see at most 3 auto-opens; opted-out users never see it.

---

### `optOut()`

```swift
public static func optOut() async throws
```

Right-to-Delete opt-out: tombstones the person on the backend (identity-wide, PII anonymized, email suppressed) and permanently silences the experience on this device. Wire this to the opt-out action in your privacy-policy flow.

**Throws:** `WINRError.notConfigured`, `WINRError.authenticationRequired`.

`optOut()` is the only erasure API — there is no hard-delete method. Users can
also invoke it themselves from the in-app **Privacy choices → delete my data**
link on the how-it-works ("?") screen.

---

### Push Notifications

```swift
public static func registerForPushNotifications()
```

Requests notification permission and registers for APNs. No-op if `WINROptions.enablePushReminders` is `false`.

```swift
public static func didRegisterForRemoteNotifications(deviceToken: Data)
```

Forward the APNs token from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.

```swift
public static func didReceiveFCMToken(_ token: String)
```

Forward the Firebase Messaging registration token from `MessagingDelegate.messaging(_:didReceiveRegistrationToken:)` so WINR's backend can send streak reminders through your Firebase project. Without it the SDK falls back to local reminders.

```swift
public static func didFailToRegisterForRemoteNotifications(error: Error)
```

Forward the APNs failure from `application(_:didFailToRegisterForRemoteNotificationsWithError:)`.

---

## WINRConfiguration

```swift
public struct WINRConfiguration {
    public init(
        apiKey: String,
        environment: WINREnvironment,
        bundleId: String,
        user: WINRUser,
        options: WINROptions = .init()
    )
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `apiKey` | `String` | ✅ | Your WINR API key from the dashboard |
| `environment` | `WINREnvironment` | ✅ | `.production` (the only environment) |
| `bundleId` | `String` | ✅ | App bundle ID (e.g. `com.example.myapp`) |
| `user` | `WINRUser` | ✅ | The authenticated user |
| `options` | `WINROptions` | — | Optional behavior toggles |

---

## WINROptions

```swift
public struct WINROptions {
    public init(
        logging: LoggingLevel = .error,
        analyticsAdapter: AnalyticsAdapter? = ConsoleAnalyticsAdapter(),
        enablePushReminders: Bool = true
    )
}
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `logging` | `LoggingLevel` | `.error` | `.none`, `.error`, `.info`, or `.debug` |
| `analyticsAdapter` | `AnalyticsAdapter?` | `ConsoleAnalyticsAdapter()` | Routes SDK events to your analytics stack |
| `enablePushReminders` | `Bool` | `true` | Enables streak reminder push notifications |

---

## WINREnvironment

```swift
public enum WINREnvironment {
    case production
}
```

Production-only — there is no staging or QA backend.

---

## WINRUser

```swift
public struct WINRUser {
    public init(
        id: String,
        firstName: String = "",
        lastName: String = "",
        phone: String? = nil,
        email: String? = nil
    )

    /// A guest session — the person is not signed in to your app (or your app
    /// has no accounts). The SDK mints a stable per-install `winr_guest_…` id.
    public static let guest: WINRUser
}
```

Only `id` is required; everything else is optional and the SDK captures what's
missing (email via its capture screen, name at prize-claim if the user wins).
Pass whatever identity you already hold — even just an id.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | `String` | ✅ | Your app's unique, stable user identifier (the only required field) |
| `firstName` | `String` | — | User's first name; captured at prize-claim if omitted |
| `lastName` | `String` | — | User's last name; captured at prize-claim if omitted |
| `phone` | `String?` | — | Phone number in E.164 format |
| `email` | `String?` | — | From your authenticated session. If passed, it pre-fills and **locks** the capture field; if omitted, the SDK captures it. A plain `String`. |

> **Email:** A supplied `email` never records consent — the user still ticks
> the age (and optionally marketing) boxes and submits inside the WINR flow. A
> malformed value is ignored and the field stays editable. For apps with no
> signed-in user, use `WINRUser.guest`.

---

## WINRError

```swift
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
    case serviceUnavailable   // publisher suspended / API key revoked
    case optedOut             // user exercised Right-to-Delete
    case internalError(String)
}
```

Conforms to `LocalizedError`; every case provides an `errorDescription`.

---

## DailyEntryGrant

```swift
public struct DailyEntryGrant {
    public let baseEntries: Int
    public let bonusEntries: Int
    public var total: Int { baseEntries + bonusEntries }
}
```

The entries granted during an auto-opened session. `baseEntries` is the daily streak-ladder amount (a simple +10 per day); `bonusEntries` defaults to `0` and holds any additional entries granted alongside the daily amount.

---

## AnalyticsAdapter

```swift
public protocol AnalyticsAdapter {
    func track(event: String, properties: [String: Any]?)
}
```

Implement to route WINR events to your analytics backend (Firebase Analytics, Amplitude, Mixpanel, …). The SDK ships with `ConsoleAnalyticsAdapter` (logs to the Xcode console) as the default.

Convenience helpers are provided as protocol extensions: `trackRegistration(userId:)`, `trackExperienceOpened(giveawayId:)`, `trackExperienceClosed(giveawayId:)`, `trackDailyEntryClaimed(day:entries:)`, `trackPrizeWon(prizeName:prizeValue:)`.

---

## WINRAnalyticsEvent

Event-name constants emitted by the SDK:

| Constant | Event name | When |
|----------|------------|------|
| `registration` | `winr_registration` | Device/user registered with WINR |
| `experienceOpened` | `winr_experience_opened` | The experience opened (once-per-day auto-open) |
| `experienceClosed` | `winr_experience_closed` | The experience was dismissed |
| `dailyEntryClaimed` | `winr_daily_entry_claimed` | Daily entries awarded (auto-claimed on open) |
| `prizeWon` | `winr_prize_won` | The user was selected as a winner |

---

## WINRConstants

```swift
public enum WINRConstants {
    public static let sdkVersion = "2.8.0"
    public static let platformOS = "iOS"
}
```
