# Splynek Accelerator (Strategy Bet S5) — design + status

> **Status: end-to-end functionally complete as of 2026-05-05
> (commit `e9e7002`).**  Chrome accelerator intercept (downloads),
> Safari WebExtension parity (xcodegen-built .appex), HLS+DASH
> pre-buffer with multi-interface bonded segment fetch — all
> shipping.  Off-by-default opt-in; user enables in extension popup.
> Next milestones (Firefox port, live testing on real Vimeo/Twitch,
> SOCKS proxy for non-browser apps) are smaller now that the
> infrastructure is in place.

## What's the bet

Extend Splynek's multi-interface engine from "downloads Splynek itself
initiates" to "any *big-volume* HTTP traffic in the user's browser" —
without a VPN, without a cloud relay, without a NetworkExtension
entitlement.

Strategic detail in [STRATEGY-2026.md § Bet S5](../../STRATEGY-2026.md).

## Why a browser extension (not a system VPN)

The cleanest path to "intercept big downloads on the Mac" *with*
Apple-store distribution + privacy posture intact is to NOT proxy
traffic at the network layer.  We watch Chrome's download stack
(`chrome.downloads.onCreated`, called the moment HTTP response
headers arrive) and offer to swap out Chrome's single-connection
fetch for Splynek's multi-interface bonded fetch.

Trade-offs:
- ✅ No VPN entitlement.  Apple's `NetworkExtension` is case-approved
  + would contradict our "no cloud, no VPN" wedge.
- ✅ No cloud relay (Speedify-style).  Bonding happens on the user's
  Mac in the standard Splynek engine.
- ✅ Per-file explicit consent, opt-in.  No surprise behaviour.
- ❌ Only works for downloads the browser initiates.  Apps that
  fetch their own bytes (Slack, Dropbox, Transmit, rsync) need the
  user to point them at the local SOCKS proxy explicitly (planned
  v3 — the "advanced" tier).
- ❌ Browser-specific: ships separately for Chrome / Safari /
  Firefox.  Manifest V3 is now Chrome's hard requirement;
  Safari WebExtension is Apple's; Firefox supports both.

## What's shipped (v0.23, 2026-05-05)

| Piece | File | Status |
|---|---|---|
| Manifest V3 with new permissions | `manifest.json` | Live |
| `downloads.onCreated` intercept | `background.js` | Live |
| Threshold check (default 50 MB, overridable) | `background.js` | Live |
| Per-host opt-out + always-on lists | `background.js` + `options.html` | Live (full UX) |
| User-facing toggle in popup | `popup.html` + `popup.js` | Live |
| Notification with Send / Keep buttons | `background.js` | Live |
| Notification right-click → openOptionsPage | `background.js` | Live (v0.23) |
| `splynek://download?url=...` hand-off | `background.js` | Live |
| **HLS+DASH manifest detection** | `background.js` (`looksLikeHLSManifest`) | Live |
| **`declarativeNetRequest` redirect** for HLS+DASH | `background.js` (per-tab session rules) | Live |
| **Splynek-side HLS+DASH proxy** | `Sources/SplynekCore/HLSProxyServer.swift` | Live |
| **Multi-interface bonded segment fetch** | `Sources/SplynekCore/BondedFetcher.swift` | Live |
| **Per-session ring buffer (256 MB LRU)** | `Sources/SplynekCore/HLSRingBuffer.swift` | Live |
| **DRM detection + pass-through** | `HLSManifest.hasDRM` + `DASHManifest.hasDRM` | Live |
| **Safari WebExtension** | `Extensions/Safari-WebExtension/` (xcodegen .appex) | Live |

## What's NOT shipped yet (next milestones — much smaller now)

### Milestone A — Live test on real streams (manual click-through)

The HLS+DASH proxy + BondedFetcher have green unit tests + clean
local builds.  The remaining unknown is real-world behaviour: open
a Vimeo-hosted DRM-free video on weak Wi-Fi + 5G tether with
Accelerator + HLS pre-buffer enabled, observe (a) playback start
latency, (b) buffering events, (c) network split between interfaces.
Compare against control (extension disabled).  Expected: instant
start, zero buffering, ~2× throughput on a fast multi-NIC setup.

### Milestone B — Firefox port (~3 days)

Same code as Safari with namespace shimming.  Firefox supports
MV3 fully; doesn't require a containing app bundle, so distribution
is trivial (firefox.com/addons listing).  Manifest field
differences: `browser_specific_settings.gecko` for extension ID,
slightly different `webRequest` event semantics.  Most JS stays
verbatim.

### Milestone C — SOCKS proxy for non-browser apps (advanced, ~1 week)

For the 5% of power users who want Slack / Transmit / rsync to also
bond.  Splynek exposes a SOCKS5 proxy on `127.0.0.1:1080`; users
point individual apps at it via per-app settings.

NOT a system-wide VPN.  NOT a default-on feature.  Power users only.

### Milestone D — App Store concerns for Safari extension

The Safari WebExtension's `<all_urls>` host permission for
`webRequest` may trigger App Review questions.  Mitigation: app's
review notes already explain Splynek is a download manager;
Accelerator intercept feature description fits the existing review
narrative.  Plan to ship the Safari extension AFTER v1.0 clears
+ submit v1.0.1 with extension included so reviewers can pattern-
match against an already-approved binary.

## Privacy + threat model

The Accelerator is observe-only.  When enabled:
- Reads: download URL, Content-Length, source tab's referrer (for
  the per-host store key).
- Writes: cancels Chrome downloads when user explicitly clicks Send;
  opens a `splynek://` URL.
- Phones home: never.  No telemetry, no analytics, no remote config.

The `host_permissions: <all_urls>` is required for `webRequest` to
see download URLs across all hosts.  We don't read any page content
(no content scripts).  Chrome enforces the permission scope.

The per-host opt-out / always lists live in `chrome.storage.sync`
which means they roam to other Chrome installs of the same user.
That's fine — these are user preferences, not privacy-sensitive
data.

## Why the default is OFF

Surprise downloads-redirected-to-Splynek would be a hostile UX for
users who didn't ask.  Enabling via the popup is one click; the
notification then lets them control per-file behaviour from there.

This matches the strategy memo's principle that Splynek never
silently changes user behaviour — every escalation is opt-in,
per-feature, with clear consent.
