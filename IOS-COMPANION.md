# Splynek iOS Companion — Strategy Bet S4 (foundations)

> Status: **foundation skeleton landed 2026-05-07** (commit pending).
> Builds; tests green (579 passing, +27 new); not yet TestFlight'd.
> No App Store submission yet — held behind Apple v1.0 macOS clearance.

A free iPhone app that pairs with Splynek-Mac over the LAN.  Three
features in this first cut:

1. **Bonjour discovery** — finds Macs running Splynek on the same Wi-Fi
   automatically (`_splynek-fleet._tcp`).
2. **Token-paste pairing** — one-time setup; the Mac shows a token in
   Settings → Sharing, the user pastes it on the phone.
3. **Send to Splynek** — Share Extension entry point from Safari /
   Twitter / Mail / etc.; tap → URL queues on the paired Mac.
4. *(plus type-or-paste fallback inside the main app)*

What's **not** in the foundation skeleton (planned for phase 2):

- **Live Activity** for download progress on the lock screen + Dynamic
  Island, with macOS 26 menu-bar mirroring.  Needs APNS push tokens +
  a Mac-side token store + a notification provider — multi-day work.
- **QR-code pairing** as an alternative to manual token paste.
- **CloudKit relay** for over-cellular submission (when the phone
  isn't on the same Wi-Fi as the Mac).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  iPhone                                                      │
│                                                              │
│   ┌──────────────────────┐   ┌──────────────────────────┐    │
│   │ SplynekCompanion app │   │ Send-to-Splynek share ext│    │
│   │  (main app target)   │   │ (app-extension target)   │    │
│   └──────────┬───────────┘   └────────────┬─────────────┘    │
│              │                            │                  │
│              │     SplynekCompanionCore (shared SPM lib)     │
│              │       PairedMac, PairedMacStore (keychain),   │
│              │       PairedMacClient, ShareExtractor,        │
│              │       SplynekBonjourBrowser, SplynekTXTRecord │
│              ▼                            ▼                  │
│   ┌──────────────────────────────────────────────────┐       │
│   │ App Group: group.app.splynek.companion           │       │
│   │   plist: paired-Macs metadata                    │       │
│   │   keychain: per-Mac auth tokens                  │       │
│   └──────────────────────────────────────────────────┘       │
└──────────────────────────┬───────────────────────────────────┘
                           │ Bonjour: _splynek-fleet._tcp
                           │ HTTP:    http://<host>:<port>/splynek/v1/...
                           ▼
              ┌───────────────────────────┐
              │ Mac running Splynek       │
              │  FleetCoordinator         │
              │   advertises Bonjour      │
              │   serves /api/queue       │
              │   serves /api/jobs        │
              │   serves /api/status      │
              └───────────────────────────┘
```

The macOS side **needs no code change**.  The iOS companion only
consumes endpoints `FleetCoordinator` already exposes.

### Layout on disk

```
iOS/
├── SplynekCompanion/           main app (UIKit + SwiftUI)
│   ├── SplynekCompanionApp.swift   @main
│   ├── ContentView.swift           Tab root (Macs / Submit)
│   ├── PairedMacsView.swift        list + Bonjour discoveries
│   ├── PairingSheet.swift          add-Mac flow
│   ├── JobsView.swift              per-Mac active-jobs list
│   ├── SubmitURLView.swift         type-or-paste fallback
│   └── Info.plist
├── SplynekShareExtension/      Share Extension target
│   ├── ShareViewController.swift   UIKit lifecycle + URL extraction
│   ├── ShareSheetView.swift        SwiftUI body
│   └── Info.plist
├── Shared/                     compiled into BOTH targets +
│   │                              also exposed as SwiftPM lib so
│   │                              `swift run splynek-test` can hit it
│   ├── PairedMac.swift             Codable model
│   ├── PairedMacStore.swift        App Group plist + keychain
│   ├── PairedMacClient.swift       HTTP actor (queue / jobs / ping)
│   ├── ShareExtractor.swift        URL extraction + canonicalization
│   └── SplynekBonjourBrowser.swift NWBrowser wrapper + TXT decoder
└── Resources/
    ├── SplynekCompanion.entitlements        App Group + keychain
    └── SplynekShareExtension.entitlements   App Group + keychain
```

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

## Pairing flow

1. **Mac side**: Splynek already shows the LAN web token in *Settings
   → Sharing* (see `FleetCoordinator.webToken`).  No new Mac UI is
   needed for v1.  *(A "pair iPhone" QR-code button would be a nice
   v2 addition — but the LAN dashboard route already exposes the
   token.)*
2. **Phone side**:
   - User opens Splynek Companion on iPhone.
   - The app's "Macs" tab auto-shows any Splynek-Macs on the
     current Wi-Fi (Bonjour, requires `NSLocalNetworkUsageDescription`
     + `NSBonjourServices = ["_splynek-fleet._tcp"]` in Info.plist).
   - User taps a discovered Mac OR taps + and types the
     hostname/IP manually.
   - User pastes the token; Splynek-on-phone hits
     `GET /splynek/v1/status` (token-gated by adding `?t=<token>`
     to authenticated endpoints; status itself is open) and the
     paired Mac is saved to the App Group.

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

## Known phase-2 work

Tracked in HANDOFF.md "Open positions":

- [ ] **Live Activity (ActivityKit)** for the download-in-progress
  experience.  Requires a Mac-side push-token registry +
  `ActivityKit.Activity.update(...)` calls from the FleetCoordinator
  job-progress hook.  macOS 26 then mirrors the Live Activity into
  the Mac menu bar for free.
- [ ] **QR-code pairing**: the Mac's *Settings → Sharing* tab gains
  a "Show QR" button that encodes
  `splynek://pair?host=<host>&port=<port>&token=<token>`.  iOS app's
  pairing sheet gets a "Scan QR" alternative.
- [ ] **CloudKit relay** for over-cellular submission.  Phone writes
  to a private CloudKit zone; Mac subscribes via `CKDatabaseSubscription`.
  Offline-capable because CloudKit handles retry.
- [ ] **TestFlight**: needs an iOS App ID + provisioning profile
  workflow.  Foundation is in place; gated on Apple v1.0 macOS
  clearance so we don't fragment review attention.

## Why this is foundation, not ship

The strategy memo (`STRATEGY-2026.md` Bet S4) puts the iPhone
Companion at "Week 8-16, alongside Pro+ tier launch."  This commit
lands the **foundation skeleton** so:

- The macOS team can keep evolving `FleetCoordinator` knowing
  there's an iOS consumer for the same REST surface.
- The build system (`project.yml` + `Package.swift`) compiles all
  three targets on every CI run, catching API breakages early.
- The shared core is unit-tested at PR time — URL extraction,
  TXT decoding, store CRUD all have suite coverage.

Live Activity, QR pairing, and CloudKit relay are the "ship" cut.
Each is multi-day work and worth its own commit arc.
