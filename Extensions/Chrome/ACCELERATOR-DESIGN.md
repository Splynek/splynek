# Splynek Accelerator (Strategy Bet S5) — design + status

> **Status: scaffolding shipped 2026-05-05 in commit `bf9d3a0`+.**  The
> Chrome extension's accelerator intercept is live (off by default).
> HLS pre-buffer + Safari/Firefox parity + advanced UX (Never-for-site
> button, in-extension dashboard) are the next milestones.

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

## What's shipped (v0.22)

| Piece | File | Status |
|---|---|---|
| Manifest V3 with new permissions | `manifest.json` | Live |
| `downloads.onCreated` intercept | `background.js` | Live |
| Threshold check (default 50 MB, overridable) | `background.js` | Live |
| Per-host opt-out + always-on lists | `background.js` (read), TODO buttons | Read-side live |
| User-facing toggle in popup | `popup.html` + `popup.js` | Live |
| Notification with Send / Keep buttons | `background.js` | Live |
| `splynek://download?url=...` hand-off | `background.js` (existing) | Live |

## What's NOT shipped yet (next milestones)

### Milestone 1 — Notification UX completion (v0.23, ~half-day)

The intercept notification currently only has Send / Keep buttons.
Need:
- "Never for this site" → adds host to `accel.optOutHosts`
- "Always for this site" → adds host to `accel.alwaysHosts`,
  silences future prompts for that host

Also: dedicated options page (`options.html`) for editing the host
lists after-the-fact.  Right now once you've added a host you can't
remove it without devtools.

### Milestone 2 — Safari WebExtension parity (~1 week)

Apple's Safari WebExtensions are MV3-compatible with shape changes:
- `browser` namespace instead of `chrome` (most APIs identical)
- Safari requires the extension to be packaged inside a Mac app
  bundle (`.appex`).  The Splynek app already builds via xcodegen;
  add a target for `Splynek-Safari-Extension.appex`.
- `chrome.notifications` doesn't exist in Safari; use the in-page
  toast surface from a content script + page action.

The dispatch logic + threshold + storage all carry over unchanged.

### Milestone 3 — Firefox MV2/MV3 hybrid (~3 days)

Firefox supports MV3 fully but with a different `browser` namespace
+ slightly different webRequest semantics.  Same code as Safari with
namespace shimming.  Firefox doesn't require a containing app
bundle, so distribution is trivial (firefox.com/addons listing).

### Milestone 4 — HLS pre-buffer (the harder piece, ~3 weeks)

This is the strategy memo's "video streams that never buffer" demo
moment.  When the extension sees an `m3u8` master playlist or
`mpd` MPEG-DASH manifest:

1. Mark the URL as a streaming session.
2. Open a local HTTP proxy port (Splynek's existing one on
   `127.0.0.1:<port>` — we'd add a new route specifically for
   manifest-rewriting).
3. Rewrite the manifest to point to the local proxy.
4. The proxy fetches each segment via Splynek's bonded engine,
   stores 30–60s ahead in a temp ring buffer, serves them to the
   browser's HTML5 player on demand.

Requires (a) a manifest-rewriter that handles HLS variant negotiation
+ DASH adaptation set selection without breaking the player's ABR
ladder, and (b) a proxy that can hit each segment in ≤200ms (most
servers don't do bonded multi-connect on small files; the win comes
from pre-fetch buffering, not within-segment bonding).

Legally safe: HLS pre-buffer applies only to DRM-free streams (YouTube
non-Premium, Vimeo public, Twitch, Plex).  Widevine / FairPlay
streams (Netflix, Disney+, Apple TV+) are off-limits — we wouldn't
intercept them even if technically possible.

### Milestone 5 — SOCKS proxy for non-browser apps (advanced, ~1 week)

For the 5% of power users who want Slack / Transmit / rsync to also
bond.  Splynek exposes a SOCKS5 proxy on `127.0.0.1:1080`; users
point individual apps at it via per-app settings.

NOT a system-wide VPN.  NOT a default-on feature.  Power users only.

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
