# Changelog

## 2.6.1 — 2026-08-11

In-experience privacy opt-out (delete my data); District of Columbia added to
the prize-claim form.

- **Privacy choices** — the how-it-works ("?") screen gains a muted "Privacy
  choices" link. It raises a destructive confirmation ("Delete my data & stop
  participating"); confirming performs the existing RTD opt-out
  (`WINR.optOut()`), shows "Your data has been deleted.", and dismisses the
  experience. Failure keeps the confirmation up with "Something went wrong.
  Please check your connection and try again." — never a pretended success.
- **District of Columbia** in the prize-claim state dropdown, per the official
  rules' "50 states and the District of Columbia".

## 2.6.0 — 2026-08-10

User-facing error messaging per the Master Field List; honest failure states —
no fabricated claim success.

- **Inline field validation** with mandated copy, centralized in
  `WINRV2Strings`:
  - Email capture: "Please enter a valid email address." under the field,
    shown only after the field is touched or a submit attempt — never while
    typing the first characters.
  - Winner claim step 1: "Please enter a valid first name." / "Please enter a
    valid last name." on a continue attempt (unicode letters, spaces,
    apostrophes, hyphens, periods; max 50).
  - Claim phone stays optional, but a non-blank value must be a valid US
    10-digit number ("Please enter a valid 10-digit mobile number."); the
    normalized 10 digits are what gets submitted.
- **No fabricated claim success** — a transport failure during the daily claim
  no longer fakes a local success and celebrates an entry that was never
  recorded. The dashboard shows the honest unclaimed state with "We couldn't
  record today's entry. Check your connection and try again." and a TRY AGAIN
  affordance.
- **Duplicate same-day entry** (claim rejected as already-claimed when local
  state didn't know, e.g. another device claimed first) now shows a transient
  dashboard notice: "You've already entered today. Come back tomorrow to keep
  your streak going!"
- **Geo-blocked** backend rejections render a dedicated "Not available in your
  location" state instead of the generic empty state.
- **Session expired** (silent token refresh failed) renders "Your session has
  expired. Please try again." with a RETRY button that re-registers and
  reloads — no longer collapsed into the empty state.
- **Failed email submits stay on the capture screen** with "Something went
  wrong sending your email. Please try again." and a retry; consent is now
  recorded only after a confirmed submit (previously it was persisted before
  the network call, so a failed submit skipped the capture screen forever).
- Raw `WINRError`/backend error text is never rendered to users; all other
  errors keep the friendly empty state.

## 2.5.1 — 2026-08-10

Consent correctness and cross-device security.

- **Marketing consent checkbox starts UNCHECKED** — consent is an affirmative
  act (pre-ticked boxes are invalid under GDPR and disfavored by US state
  regulators). Declining still blocks nothing.
- **Email pre-fill**: pass your signed-in user's email via `WINRUser.email` and
  the capture screen shows it read-only — the address the user consents for is
  always one they proved to you. Malformed values fall back to the editable
  field.
- **Guest sessions**: no account system, or the user is signed out? Use the
  guest sentinel (or omit the user on web). The SDK mints a stable per-install
  `winr_guest_…` id for attribution; re-configure with the real user later and
  the streak carries over.
- **Verified adoption**: typing an email that already belongs to an existing
  WINR account now requires a 6-digit code sent to that inbox before the
  streak transfers to the new device. Fresh signups and pre-filled partner
  emails never see it.

## [2.5.0] - 2026-08-06

### Breaking

`WINR.deleteAccount()` is **removed**. Use `WINR.optOut()`.

It called a backend hard-delete that wiped the user's entry records. Those
records are the evidence that a drawing was fair, and destroying them is not
what erasure requires — GDPR Art. 17(3) exempts data needed for legal claims.
It also left no tombstone, so delete-and-re-register farmed unlimited entries,
and it never touched prize-claim records, leaving a winner's name, address and
phone orphaned after the account pointing at them was gone.

`optOut()` is the complete path: identity-wide, scrubs prize-claim PII too,
tombstoned so it survives a reinstall, and it keeps de-identified records as
proof the prize went to a real eligible person.

### Removed

Dead rewarded-video client code. The backend endpoint it called was deleted —
it granted a second daily batch of entries and no SDK had invoked it since the
V2 rebuild.

## [2.4.0] - 2026-08-05

Consent capture. The 18+ checkbox has always been on the capture screen but its
value was never transmitted, and there was no way for a user to say whether the
publisher could market to them. Both are now real, transmitted, stored values.

### Added
- **A marketing-consent checkbox on the email-capture screen**, directly under
  the age gate. It governs one thing: whether the publisher may send this
  person marketing email. It is **pre-checked** — unlike the age box, which
  stays unchecked because confirming your age has to be an affirmative act.
  Copy comes from the publisher's `emailConsentText` config (nested
  `copy.emailCapture.emailConsentText`, then the flat legacy field), which the
  backend fills in with the publisher's own name — "I agree to receive
  marketing emails from Acme". The bundled fallback, used only before any
  config has been fetched, is "I agree to receive marketing emails from this
  app". Both checkboxes render through one shared builder, so their box size,
  tint, spacing and tap target cannot drift apart.
- **`submitEmail` now sends `ageConfirmed` and `marketingConsent`** carrying
  the real checkbox states. The backend stores both with timestamps, plus the
  consent-text version and the verbatim copy shown, so an audit can prove what
  was agreed to.

### Changed
- **Declining marketing changes nothing about the giveaway.** The submit button
  is gated on age + a valid email exactly as before; the marketing box is
  deliberately excluded from that check. A user can untick it and still enter
  every day — and if they win, they are still contacted, because winner contact
  is operational and no checkbox governs it.

## [2.3.3] - 2026-08-05

Load-experience defects found testing the SDK inside a real publisher app.

### Fixed
- **The drawer no longer sits on a spinner for seconds.** It auto-opens ahead
  of its sequential network calls (registerDevice → getActiveGiveaway →
  claim). When the device already has a cached giveaway and streak, the real
  dashboard now paints IMMEDIATELY from that cache and the fresh response
  reconciles silently in place — the same no-replay reconcile the celebration
  staging already used (a celebration staged after the cache render still
  fires exactly once; the come-back bar now accepts a late-arriving toast
  rather than missing it). A local streak-engine failure after a successful
  cache render no longer replaces the live dashboard with an error screen. The
  email-capture gate is unchanged: an unconsented user never sees a cached
  dashboard.
- **Cold start shows a skeleton, not a bare spinner.** With nothing cached to
  paint, the loading view is now a pulsing block-out of the real layout (grab
  handle, header, prize card, three streak tiles, come-back bar, CTA pill) in
  the drawer's own gunmetal instead of a centered `ProgressView` and
  "Loading…". One shared pulse, so it reads as a single surface breathing.
- **The prize image arrives with the card instead of popping in after it.**
  The publisher's `prizeImageUrl` (and logo) are now decoded into an image
  cache as soon as the SDK learns the giveaway config — at registration and on
  every giveaway refresh, alongside the existing confetti-GIF prewarm — so the
  card normally paints its art on its first frame. `AsyncImage` is replaced by
  a warmer-backed view that reads the cache synchronously: a cold URL fades in
  over ~200ms against the card's dark background rather than flashing, and a
  broken one falls back to the bundled cash hero. Warmed URLs are tracked so
  repeat refreshes are no-ops, and a failed URL is dropped so it can retry.
- **No "0 Total Entries" first frame.** With the dashboard mounting instantly,
  the stats strip's count-up (which seeded itself in `onAppear`) and the view
  model's display total (which fell through to a zero placeholder until the
  network landed) both painted a 0 for a frame. Both are now seeded from the
  persisted streak state.
- **Cached email-consent flag is set on a successful email submit**, not only
  by the next `getActiveGiveaway`, so the auto-present engine's unregistered
  impression cap can never briefly apply to someone who just registered.

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
