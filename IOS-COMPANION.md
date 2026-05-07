# Splynek iOS Companion — Strategy Bet S4

> Status: **foundation + phase 2 + phase 3 + Settings polish all
> landed 2026-05-07.**  Builds clean, 642 tests green (+90 over the
> pre-S4 baseline).  Not yet TestFlight'd — held behind Apple v1.0
> macOS clearance.

A free iPhone app that pairs with Splynek-Mac and submits URLs from
anywhere — same Wi-Fi or cellular.  Six features now live:

1. **Bonjour discovery** — finds Macs running Splynek on the same Wi-Fi
   automatically (`_splynek-fleet._tcp`).
2. **QR-code pairing** *(phase 2)* — Mac's *Settings → Web dashboard*
   shows a `splynek://pair?host=…&port=…&token=…&name=…` QR; iOS
   PairingSheet opens the camera, scans, auto-fills, auto-submits.
3. **Token-paste pairing** — fallback when the iPhone can't see the
   Mac's screen (e.g. headless Mac mini in a closet).
4. **Send to Splynek** — Share Extension entry point from Safari /
   Twitter / Mail / etc.; tap → URL queues on the paired Mac.
5. **Live Activity for in-progress downloads** *(phase 2)* — lock
   screen + Dynamic Island progress.  **Because macOS 26 mirrors
   paired-iPhone Live Activities into the Mac menu bar, this single
   ActivityKit implementation lights up BOTH surfaces** — no separate
   Mac menu-bar widget code required.
6. **CloudKit over-cellular relay** *(phase 3)* — when the iPhone
   isn't on the same Wi-Fi as the Mac, the Share Extension
   transparently falls back to writing the URL to the user's
   *private* CloudKit database; the Mac polls every 60s and ingests
   pending records.  No APNs, no server we run.  User-toggle in
   PairedMacStore (default-on); falls through to "Couldn't reach
   the Mac" if the user disabled it or has no iCloud account.

*(plus type-or-paste fallback inside the main app for Submit URL)*

What's **not** yet shipped:

- **TestFlight rollout** — foundation + phase 2 + phase 3 are fully
  buildable; gated on Apple v1.0 macOS clearance to avoid fragmenting
  App Review attention.
- **CKContainer provisioning** — `iCloud.app.splynek.companion`
  container must be created in App Store Connect, with the
  `SplynekRelayJob` schema published in CloudKit Dashboard for both
  Development + Production environments.  Maintainer-only step;
  see "Phase 3 provisioning runbook" below.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  iPhone                                                              │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐ │
│  │ SplynekCompanion │  │ Send-to-Splynek  │  │ SplynekCompanion-  │ │
│  │    app (main)    │  │   share-ext      │  │   Widgets (ext.)   │ │
│  │   QRScannerView  │  │  ShareViewCtl    │  │ DownloadActivity-  │ │
│  │ LiveActivityDrvr │  │  ShareSheetView  │  │   Widget (Live Act)│ │
│  └────────┬─────────┘  └────────┬─────────┘  └─────────┬──────────┘ │
│           │                     │                      │            │
│           │ SplynekCompanionCore (shared SPM lib + dual-target)     │
│           │   PairedMac / PairedMacStore / PairedMacClient          │
│           │   ShareExtractor / SplynekBonjourBrowser                │
│           │   SplynekPairURL / DownloadActivityAttributes           │
│           │   LiveActivityCoordinator                               │
│           ▼                     ▼                      ▼            │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ App Group: group.app.splynek.companion                        │  │
│  │   plist: paired-Macs metadata                                 │  │
│  │   keychain: per-Mac auth tokens                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────┬─────────────────────────────────────────┘
                             │ Bonjour: _splynek-fleet._tcp
                             │ HTTP:    http://<host>:<port>/splynek/v1/...
                             ▼
                ┌───────────────────────────────────────┐
                │ Mac running Splynek                   │
                │  FleetCoordinator                     │
                │   advertises Bonjour                  │
                │   serves /api/queue                   │
                │   serves /api/jobs                    │
                │   serves /api/status                  │
                │   iPhonePairingURLString() → QR text  │
                │   (NEW 2026-05-07 phase 2)            │
                └───────────────────┬───────────────────┘
                                    │ macOS 26 Continuity
                                    │ Live-Activity passthrough
                                    ▼
                ┌──────────────────────────────────────┐
                │ Mac menu bar — no Mac code required  │
                │ (mirrors iPhone Live Activity)       │
                └──────────────────────────────────────┘
```

The Mac side change is **one new method** on `FleetCoordinator`:
`iPhonePairingURLString()` returns the canonical pair-URL for QR
generation.  Plus a new SettingsView card showing the QR.  Everything
else (Bonjour, REST endpoints, token storage) was already in place.

### Layout on disk

```
iOS/
├── SplynekCompanion/                  main app (UIKit + SwiftUI)
│   ├── SplynekCompanionApp.swift          @main
│   ├── ContentView.swift                  Tab root (Macs / Submit / Settings)
│   ├── PairedMacsView.swift               list + Bonjour discoveries
│   ├── PairingSheet.swift                 add-Mac flow + QR launch
│   ├── QRScannerView.swift                AVFoundation QR scanner (phase 2)
│   ├── JobsView.swift                     per-Mac active-jobs list
│   ├── LiveActivityDriver.swift           ActivityKit lifecycle (phase 2)
│   ├── SubmitURLView.swift                type-or-paste fallback
│   ├── SettingsView.swift                 relay toggle + per-Mac health
│   │                                       + Test-pairing probe (polish)
│   └── Info.plist                         + NSSupportsLiveActivities
│                                          + NSCameraUsageDescription
├── SplynekShareExtension/             Share Extension target
│   ├── ShareViewController.swift          UIKit lifecycle + URL extraction
│   │                                       + LAN-first / CloudKit-fallback
│   │                                       (phase 3)
│   ├── ShareSheetView.swift               SwiftUI body
│   └── Info.plist
├── SplynekCompanionWidgets/           Widget Extension (phase 2)
│   ├── SplynekCompanionWidgetBundle.swift @main widget bundle
│   ├── DownloadActivityWidget.swift       Live Activity views
│   │                                       (lock screen + Dynamic Island
│   │                                        compact / minimal / expanded)
│   └── Info.plist
├── Shared/                            dual-compiled + SwiftPM library
│   ├── PairedMac.swift                    Codable model
│   ├── PairedMacStore.swift               App Group plist + keychain +
│   │                                       cloudKitRelayEnabled toggle (p3)
│   ├── PairedMacClient.swift              HTTP actor (queue / jobs / ping +
│   │                                       submitWithRelay LAN→CK fallback p3)
│   ├── ShareExtractor.swift               URL extraction + canonicalization
│   ├── SplynekBonjourBrowser.swift        NWBrowser wrapper + TXT decoder
│   ├── SplynekPairURL.swift               splynek://pair encode + decode (p2)
│   ├── DownloadActivityAttributes.swift   ActivityAttributes (iOS-gated, p2)
│   ├── LiveActivityCoordinator.swift      pure decide/project (p2)
│   ├── RelayPolicy.swift                  pure LAN/CK fallback decision (p3)
│   ├── CloudKitRelayRecord.swift          schema + CKRecord round-trip (p3)
│   ├── CloudKitRelaySubmitter.swift       iOS CKContainer writer (p3)
│   └── PairingHealth.swift                online/recent/stale classifier (polish)
└── Resources/
    ├── SplynekCompanion.entitlements        App Group + keychain + iCloud (p3)
    ├── SplynekShareExtension.entitlements   App Group + keychain + iCloud (p3)
    └── SplynekCompanionWidgets.entitlements App Group (p2)
```

Mac side adds (Sources/SplynekCore/):

- `CloudKitRelayReceiver.swift` — 60s polling actor that fetches
  pending SplynekRelayJob records targeting this Mac's deviceUUID,
  hands them to the existing `onWebIngest` callback, marks
  consumed.  Started by FleetCoordinator in `start()`; stopped in
  `stop()`.  Skipped entirely when loopback-only is on.

### Build

```sh
xcodegen generate
xcodebuild -project Splynek.xcodeproj \
  -scheme SplynekCompanion \
  -destination 'generic/platform=iOS' archive
```

The `SplynekCompanion` scheme (added to `project.yml` 2026-05-07)
builds the main app + embeds the Share Extension automatically.

### Test

```sh
swift run splynek-test       # 579 passing, includes 27 iOS-companion tests
```

The shared core (`SplynekCompanionCore` SwiftPM library) is platform-
portable, so the macOS test harness exercises it directly without an
iOS Simulator.  UIKit / SwiftUI surfaces aren't unit-tested here —
they live in the iOS app/extension targets and require the Simulator.

## Pairing flow (phase 2 — QR-code primary path)

1. **Mac side**: Splynek's *Settings → Web dashboard* card shows
   two QR codes:
   - The existing browser-dashboard QR (encodes
     `http://host:port/splynek/v1/ui?t=<token>` — for the phone-as-
     web-client flow).
   - **New:** the iPhone-pair QR (encodes
     `splynek://pair?host=…&port=…&token=…&name=<Mac display name>`
     — for the iOS Splynek Companion app).
   `FleetCoordinator.iPhonePairingURLString()` produces the string;
   the existing `QRCode.image(for:size:)` helper renders it.  The
   pair QR is hidden when the listener is loopback-only (phones
   on a different network can't reach 127.0.0.1).
2. **Phone side, primary path**:
   - User opens Splynek Companion on iPhone, taps +.
   - PairingSheet shows a "Scan QR from Mac" prominent button.
   - Tap → AVCaptureSession opens the rear camera.
   - User points at the Mac's screen → QR resolves →
     `SplynekPairURL.decode(...)` parses → form auto-fills →
     auto-submits.
3. **Phone side, fallback path** (Mac mini in a closet, etc.):
   - Bonjour browser still surfaces the Mac on the "Macs" tab.
   - PairingSheet's manual host/port/token fields remain available
     below the Scan QR button.

## Submission flow (Share Extension)

1. User on iPhone shares a URL (Safari, Twitter, Reddit, Mail, etc.).
2. iOS shows the share sheet; "Send to Splynek" is in the list.
3. Tap → SplynekShareExtension presents a sheet showing the URL
   preview + paired-Mac picker (pre-selecting the most-recently-seen
   Mac).
4. Tap "Send" → Share Extension POSTs to
   `/splynek/v1/api/queue?t=<token>` with body `{"url": "..."}`.
   Mac returns 202 Accepted; extension dismisses.

The Share Extension talks to the Mac directly — no detour through
the host app — so latency is two HTTP round-trips at most.

## Live Activity flow (phase 2)

1. User opens the Companion app, taps a paired Mac → JobsView.
2. JobsView creates a `LiveActivityDriver(mac:)` on appear.
3. Every 2s, JobsView polls `/api/jobs` and passes the snapshot
   to `liveActivities.sync(currentJobs:)`.
4. `LiveActivityDriver.sync(...)` calls the pure
   `LiveActivityCoordinator.decide(previous:current:)` to compute
   the diff (start / update / end), then applies it via
   ActivityKit's `Activity.request(...) / .update(...) / .end(...)`.
5. Each running download surfaces as a Live Activity with the
   filename, throughput, and progress bar.
6. **macOS 26 mirrors active iPhone Live Activities into the Mac
   menu bar automatically** (Continuity feature) — so the same
   `DownloadActivityWidget` lights up the iPhone lock screen +
   Dynamic Island AND a Mac menu-bar chip simultaneously.
7. When the user navigates away from JobsView (or the job leaves
   the active list), `endAll()` settles every Activity with a
   "finished" final-state for the dismissal animation.

The pure `LiveActivityCoordinator` is exercised by 18 unit tests
on macOS — diffing logic, multi-step chains, phase filtering.
ActivityKit calls themselves (`LiveActivityDriver`) are
device-only and are exercised manually on the Simulator + a paired
device.

## Storage + security model

- **App Group** `group.app.splynek.companion` holds the paired-Mac
  list (uuid / displayName / lastKnownHost / lastKnownPort /
  lastSeen).  Plist serialised; `UserDefaults(suiteName:)` is the
  storage.
- **Keychain** holds the auth token per Mac, keyed on the Mac's
  uuid, with `kSecAttrAccessGroup` set to the App Group identifier
  so both targets can read / write.  `kSecAttrAccessibleAfterFirstUnlock`
  so the Share Extension can fetch the token while the device is
  locked-but-unlocked-since-boot (Apple's recommended posture for
  background-class secrets).
- **No telemetry**: the iOS app makes ZERO outbound requests except
  to paired Macs.  No analytics, no crash reporters, no remote
  config.  Fits the rest of the Splynek posture.

## Phase 3 provisioning runbook (maintainer-only)

The CloudKit code is wired + tested, but the runtime path needs
infrastructure that lives in App Store Connect / CloudKit Dashboard
— Claude can't provision these from a session.

1. **App Store Connect → Identifiers → iCloud Containers** → New →
   `iCloud.app.splynek.companion` (developer-friendly name
   "Splynek Companion Relay").
2. **App ID configuration** (both iOS app + macOS app + Share
   Extension): Capabilities → iCloud → CloudKit → check the new
   container.
3. **CloudKit Dashboard** → Schema → Record Types → New Record
   Type "SplynekRelayJob".  Fields:
   - `url` String, queryable, sortable
   - `submittedAt` Date/Time, queryable, sortable
   - `senderDevice` String, queryable
   - `targetMacUUID` String, queryable, **searchable** (the Mac's
     poll predicate filters on this)
   - `status` String, queryable, **searchable**
4. **CloudKit Dashboard** → Schema → Indexes → ensure
   `(targetMacUUID, status)` is a queryable index for performance.
5. Promote schema to Production environment.
6. Re-archive both iOS + macOS apps with the iCloud entitlement
   freshly verified by Xcode's automatic signing.

Until step 6 lands, the receiver runs on the Mac but its first
`accountStatus` check returns `.couldNotDetermine` (no container
linked) and `pollOnce()` returns 0.  Loopback-only safe: the
receiver isn't even started when the user has LAN sharing off.

## Phase 4 work (not yet shipped)

- [ ] **TestFlight**: needs an iOS App ID + provisioning profile
  workflow.  Foundation + phase 2 + phase 3 are fully buildable;
  gated on Apple v1.0 macOS clearance so we don't fragment review
  attention.
- [ ] **Native-language strings**: the iOS UI is English-only for
  v0.1.  Localization-catalog workflow used by Splynek-Mac (5
  locales, audit-script enforced) extends here once the UI
  surface stabilises.
### Already shipped (phase 1 + phase 2 + phase 3 + polish)

- [x] **Foundation skeleton (2026-05-07)** — iOS app + Share
  Extension + shared core + 27 tests.
- [x] **Live Activity for in-progress downloads (2026-05-07 phase 2)**
  — Widget Extension target, ActivityKit integration in JobsView,
  macOS-26 menu-bar mirror via Continuity passthrough, 18 unit
  tests on the pure transition logic.
- [x] **QR-code pairing (2026-05-07 phase 2)** — Mac-side
  generator (`FleetCoordinator.iPhonePairingURLString()` + Settings
  card with second QR), iOS-side AVFoundation scanner, shared
  `SplynekPairURL` encode/decode, 14 unit tests.
- [x] **CloudKit over-cellular relay (2026-05-07 phase 3)** —
  `CloudKitRelayRecord` schema + `CloudKitRelaySubmitter` (iOS) +
  `CloudKitRelayReceiver` (Mac, polls every 60s) + `RelayPolicy`
  pure LAN/CK fallback decision + Share-Extension switch from
  raw `queue(...)` to `submitWithRelay(...)` + iCloud entitlements
  on Mac + iOS apps + Share Extension; 19 unit tests across pure
  encode/decode round-trip + every policy decision branch.
- [x] **Settings tab + diagnostics (2026-05-07 polish)** — third
  tab in `ContentView` exposing the `cloudKitRelayEnabled` toggle
  (was hidden in code), per-Mac health row with three tiers
  (`online` Bonjour-visible / `recent` ≤24h since last contact /
  `stale` > 24h), "Test pairing" probe button that round-trips
  `/splynek/v1/status` and surfaces latency or failure reason
  inline, About section with version + build + splynek.app link.
  12 new tests across `PairingHealthEvaluator` + the relay-toggle
  default-on invariant.

## Why we shipped phase 2 immediately

The strategy memo (`STRATEGY-2026.md` Bet S4) framed phase 2 as
multi-week work.  In practice the foundation layout (pure
shared core + iOS-only thin wrappers) made phase 2 a one-day
addition: the existing `JobsView` poll loop is the natural
place to drive Live Activity lifecycle, and the existing QR-
generator on the Mac just needed a second QR with a different
payload format.

What's left for phase 3 (CloudKit relay, TestFlight) is genuinely
multi-day per item — CloudKit needs Mac-side subscription handling
+ idempotency, TestFlight needs Apple Developer Program iOS
provisioning + test-user invites + privacy-nutrition-label review.
