# Changelog

## [2.3.0] - 2026-08-04

### Added
- **Winner prize-claim flow (stepped, masked email)** — when the backend marks the user as the drawn winner (`prizeClaim.status == "pending"` on `getActiveGiveaway`), the drawer opens on the winner splash instead of the dashboard: CONGRATULATIONS! + prize strip → a 4-step claim form with a persistent header, "STEP N OF 4" label, and connected accent progress dots (1. TELL US ABOUT YOURSELF — name, the locked masked winning email from `prizeClaim.maskedEmail`, optional phone; 2. WHERE SHOULD WE SEND YOUR PRIZE? — address with 50-state picker; 3. SHOW OFF YOUR WIN! — optional photo; 4. PLEASE SHARE A LITTLE — optional story + social share row) → ALMOST DONE! review with three required consent checkboxes → `submitPrizeClaim` → confirmation with the gold OFFICIAL WINNER card and RETURN TO APP. Appears automatically; no integration work. The daily auto-claim still fires silently while the flow is up, and an already-submitted claim shows the normal dashboard.

### Changed
- **First-frame celebration beat** — on a claim-day open the dashboard mounts with a PREDICTED grant already staged from the pre-claim status (ladder math mirrors the backend), so the celebration is the first visible frame; the real claim runs in the background and reconciles totals/streak silently in place (no second celebration; failures settle back to server truth quietly). The 2.2.0 "CLAIM N ENTRIES" tap is gone — nothing to press, the pill reads GOT IT throughout, and only the Day-1 "You're in!" welcome modal remains.
- **Toast-first come-back bar, new copy** — on celebration opens the bar's first visible state is the "YOU'RE ON A ROLL! / Your {N} entries have been added automatically." toast; it holds ~2.5s, then slides once to the resting come-back pitch. Non-celebration opens rest on the pitch.
- **Reveal-beat tile: confetti-burst explosion + restored check/confetti** — the active day tile keeps the original drawn draw-on check, falling-confetti field, and glow, now topped by a one-shot confetti-burst GIF explosion that overflows the tile (the big-check tile-burst GIF was rejected and removed). The burst fires only on the reveal, never on a same-day reopen.
- **Count-up total with burst** — Total Entries counts up (ease-out, ~0.7s) and pops a confetti burst as it lands.
- **Prize card — the Delta A/B visuals** — dark and full-bleed: the prize image fills the whole card, the streak/total-entries stats sit in a solid black strip inside the top edge, and the headline overlays the bottom over a black→transparent scrim, in two layouts (A: right-aligned "WIN $1,000 / CASH PRIZE" for cash; B: centered "Win a {Prize}" + accent value line otherwise).

### Removed
- The `lottie-ios` dependency (nothing in the shipping V2 experience used it; it also broke `pod trunk push` at the link step), along with the dead `WINRLogo.lottie` / `.remoteLottie` cases.

## [2.2.0] - 2026-08-04

### Changed (BREAKING UX)
- Day 2+ reveal flow: the auto-claim still fires silently on open, but the UI
  now holds the previous day's numbers behind a "CLAIM N ENTRIES" pill; the tap
  reveals the celebration in place (tile check + confetti, streak/total advance)
  and the pill becomes GOT IT. No celebration modal for returning users.
- Day-1 celebration modal's GOT IT now closes the whole experience.
- Email-capture CTA renamed to "CLAIM MY N ENTRIES".

All notable changes to the WINR SDK will be documented in this file.

## [2.1.0] - 2026-08-04

### Removed (BREAKING)
- Manual `present()` / `present(from:)` and the public `isAvailable` check — the experience is exclusively auto-opened by the SDK (once per calendar day). `configure(_:)` is the entire integration; publishers can no longer launch the experience manually.
- `WINREnvironment.staging` and `.qa` — production-only; no staging/QA infrastructure exists (the removed cases silently pointed at production).

### Fixed
- Docs: push reminders are delivered via FCM (Firebase service account uploaded in the dashboard) with a local-notification fallback — not via an APNs certificate.

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
