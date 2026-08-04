# Changelog

All notable changes to the WINR SDK will be documented in this file.

## [2.0.0] - 2026-08-03

### Added
- **V2 experience** — full rebuild to the WINR-High-V2 Figma design: gunmetal bottom drawer over the host app (dim backdrop, rounded top corners, spring slide-up), bundled Inter/Oswald fonts, prize card with cash lockup / prize headline, horizontally scrolling streak rail with accelerator milestone tiles, come-back bar, and how-it-works screen
- **Auto-open** — the experience presents itself on the first app-open of each calendar day (launch + foreground), always on; respects the server kill switch (`sdkConfig.experience.autoOpenEnabled`), the unregistered impression cap (default 3), and RTD opt-out
- **Auto-claim** — daily entries are claimed automatically when the experience opens; a celebration modal (looping confetti, animated checkmark) confirms the grant
- **Winner announcements** — "WE HAVE A WINNER!" banner and winner dialog, driven by the giveaway's `latestWinner`
- **Visit mode** — `streakMode: "visit"` giveaways use a never-resetting streak with visit-based copy, for low-frequency apps
- **Ladder accelerators** — streak ladder math mirrors the backend exactly, including milestone accelerators beyond the explicit ladder
- **RTD opt-out** — new `WINR.optOut()` tombstones the person on the backend and permanently silences the experience on the device

### Changed
- Branding is server-driven and limited to logo, prize image, and primary color; the V1 theming/copy/media system is gone
- `WINR.present` is now optional — the default integration is `configure(_:)` only

### Removed (BREAKING)
- Rewarded-video/bonus entry flow (provider options, bonus claim UI)
- The `autoPresent` option — auto-open is always on (server kill switch replaces it)
- V1 server-driven copy/media theming

## [1.2.0] - 2026-02-18

### Added
- **Push Notifications**: `PushNotificationManager` with APNs token registration (no Firebase Messaging dependency), local notification fallback, `WINR.registerForPushNotifications()` public API
- **Streak Reminders**: `sendStreakReminders` scheduled Cloud Function — notifies users who claimed yesterday but not today
- **Winner Fulfillment**: Full winner lifecycle tracking — `winners` collection with status flow (selected → notified → claimed → fulfilled → expired), `updateWinnerStatus` and `getWinners` admin-only functions
- **Winner Notification**: `selectWinner` now creates winner doc and sends push notification to winner

### Backend
- New Cloud Functions: `registerPushToken`, `sendStreakReminders`, `updateWinnerStatus`, `getWinners`
- Total Cloud Functions: 13

## [1.1.0] - 2026-02-18

### Added
- **Milestone Badges**: Server-configurable streak milestones (5 days +10 bonus, 15 days +50 + Silver, 25 days +200 + Gold), badges tracked on user doc, `.milestoneCelebration` state in SDK
- **Anti-Spam/Anti-Cheat**: Rate limiting per IP hash (10 req/min) and per user (5 claims/min), claim velocity check (1s dedup), suspicious activity flags (ip_mismatch, timezone_drift), admin ban system (`isBanned` field)
- **Certificate Pinning Fix**: ASN.1 DER header prepending for correct SPKI hash verification, pin rotation support (array of current + backup pins), default enabled
- **Analytics Default Implementation**: `ConsoleAnalyticsAdapter` with `os_log`, `WINRAnalyticsEvent` constants for all key events, convenience extension methods on `AnalyticsAdapter` protocol
- **Developer Documentation**: Comprehensive `GETTING_STARTED.md`, `API_REFERENCE.md`, `CODE_EXAMPLES.md` (14 real-world examples)
- **Unit Tests**: 12 test files (~1,700 lines) covering registration, token refresh, streaks, prize capping, geo-fence, analytics, email validation, age gate, keychain, giveaway config

### Fixed
- **Weekly Reset**: Changed from Monday-based to Sunday midnight UTC per UX Runtime Spec
- **Prize Capping**: `maxTotalEntries`, `maxPrizesPerPeriod` + `prizePeriodDays` (rolling window), `maxPrizeValue` enforcement in `claimDailyEntries`

### Backend
- New Cloud Function: `antispam.ts` module with rate limiting and suspicious activity detection
- `antispam` Firestore collection for rate limit tracking with TTL
- `ipTracking` user subcollection for multi-IP detection
- Updated `selectWinner` with enhanced winner doc creation

## [1.0.0] - 2026-02-18

### Added
- Core SDK: device registration, email capture, daily entries, bonus entries
- Three-tier streak system (daily/weekly/monthly) with server-driven configuration
- Rewarded video integration via `RewardedVideoProvider` protocol
- Google AdMob reference adapter (`GoogleAdMobRewardedProvider`)
- 18+ age gate with inline email validation
- Official Rules & Privacy Policy links on registration screen
- AES-256-GCM encryption for all PII (email, name, phone)
- IDFA collection via ATT framework
- SHA-256 IP hashing (raw IP never stored)
- IP-to-state geo-fencing (US-only, NY/FL restricted)
- Token refresh flow (silent re-authentication)
- Certificate pinning (opt-in, Google Trust Services SPKI pins)
- Right-to-be-Forgotten: `WINR.deleteAccount()` endpoint
- White-label branding system with 7 preset themes
- Single entry point: `WINR.configure(WINRConfiguration)` + `WINR.present()`
- Full configuration API for advanced customization
- Keychain-based secure storage for tokens and UUID
- Offline fallback with local streak engine
- Swift Package Manager support
- CocoaPods support

### Backend
- 9 Cloud Functions: registerDevice, refreshToken, submitEmail, submitUserProfile, claimDailyEntries, claimBonusEntries, getActiveGiveaway, selectWinner, deleteUserData
- Firestore security rules scoped per-user with admin custom claim
- Gatekeeper: publisher validation, rate limiting, geo-fencing, PII encryption
- All 22 Master Field List fields captured and stored
