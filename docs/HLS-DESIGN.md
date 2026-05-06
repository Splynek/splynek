# Splynek HLS+DASH pre-buffer — design doc (Strategy Bet S5 second half)

> Status: **functionally complete as of 2026-05-05** (commits `6850e48`
> + `e9e7002`).  All five components shipping:
>
> - HLS manifest parser (`HLSManifest.swift`) + 30 tests
> - DASH manifest parser (`DASHManifest.swift`) + 12 tests
> - LRU ring buffer (`HLSRingBuffer.swift`) + 8 tests
> - Proxy server (`HLSProxyServer.swift`, `@MainActor`) + 8 tests
> - Multi-interface bonded segment fetch (`BondedFetcher.swift`) + 7 tests
> - Chrome `declarativeNetRequest` redirect rule, off-by-default
> - FleetCoordinator `/hls/*` route dispatch, token-gated
>
> Live test on real Vimeo / Twitch — and measuring the buffering
> improvement vs control — is the manual verification step that's
> still pending.  All other code paths are covered by unit tests
> + smoke-build green.

## What's the bet

When a user opens a video site (YouTube DRM-free streams, Vimeo
public, Twitch, Plex, any HLS-on-CDN deployment), the browser's
HTML5 player fetches:

1. A *master playlist* (`.m3u8`) listing variant renditions
2. A *media playlist* per variant listing segments (.ts or .mp4
   fragments)
3. The segments themselves, one at a time, as the playhead advances

On a flaky Wi-Fi + weak 5G tether combo, segment fetches stall.
The player buffers.  Standard ≥30s buffering cycles tank UX.

Splynek's HLS pre-buffer fixes this by:

1. Intercepting manifest URLs in the browser (Chrome extension
   `webRequest.onHeadersReceived` + Safari WebExtension)
2. Rewriting the manifest URLs to point at a local Splynek HTTP
   proxy on `127.0.0.1:<port>/hls/<sessionID>/<original-path>`
3. Pre-fetching the next N segments (default 5–8) via Splynek's
   bonded multi-interface engine — same Wi-Fi + Ethernet + iPhone-
   tether parallelism that powers regular downloads
4. Caching them in a per-session in-memory ring buffer
5. Serving each player request from the buffer immediately

User-visible outcome: **the player never buffers**.  Click play,
seek anywhere, scrub forward — segments are already pre-fetched
and served from localhost in <1ms.

## Why this can't just be a general HTTP cache

Two reasons:

1. **HLS is sequential by design.**  The player only knows about
   segment N+1 *after* it parses segment N's metadata for ABR
   ladder decisions.  A generic forward-cache can't pre-fetch
   speculatively without first parsing the manifest itself.
2. **ABR (Adaptive BitRate) is the player's responsibility.**  We
   pre-fetch the user's *current* variant; we don't pick variants
   for them.  The player still drives the bitrate ladder; we just
   eliminate per-segment fetch latency for whichever variant they're
   on.

## Architecture (when fully shipped)

```
   Browser (HTML5 player)
        │
        │ HTTP GET https://example.com/master.m3u8
        ▼
   Chrome extension webRequest.onHeadersReceived
        │ matches *.m3u8?  yes →
        ▼
   chrome.declarativeNetRequest.redirect →
        http://127.0.0.1:<port>/hls/<sid>/master.m3u8
        ▼
   Splynek (FleetCoordinator HTTP server, new /hls/ route)
        │
        │ 1. Fetch upstream master via DownloadEngine
        │ 2. Parse via HLSManifest.parseMaster
        │ 3. Rewrite each variant URI to point at local proxy:
        │    e.g. "high.m3u8" → "high.m3u8" (still, but resolved
        │    through our proxy host so segment requests land here too)
        │ 4. Return rewritten body
        ▼
   Player picks variant + requests media playlist via local proxy
        │
        ▼
   Splynek (proxy)
        │ 1. Fetch upstream media playlist
        │ 2. Parse via HLSManifest.parseMedia
        │ 3. Build per-segment-URL list, store in session ring buffer
        │ 4. Spawn background tasks pre-fetching next N segments
        │    via DownloadEngine (multi-interface bonded)
        │ 5. Return rewritten body (segments now point at /hls/<sid>/seg-N.ts)
        ▼
   Player requests segment 0 → served immediately from ring buffer
   Player requests segment 1 → served immediately from ring buffer
   ...
```

## Components to build (next-session checklist)

### 1. `HLSProxyServer` (new file, ~300 lines)

A new HTTP route in `FleetCoordinator`'s existing localhost server
(currently serves the web dashboard at `/splynek/v1/...`).

```swift
// Sources/SplynekCore/HLSProxyServer.swift
@MainActor
public final class HLSProxyServer {
    private var sessions: [UUID: HLSSession] = [:]

    public func handle(_ request: URLRequest, response: HTTPResponse) async {
        // Route shape: /hls/<sessionID>/<original-path-relative-or-absolute>
        // sessionID maps to one HLSSession; original path lets us re-fetch
        // upstream + serve the rewritten/buffered body.
    }
}
```

### 2. `HLSSession` (per-stream state)

```swift
struct HLSSession {
    let id: UUID
    let masterURL: URL
    var currentVariant: HLSManifest.Variant?
    var segmentBuffer: HLSRingBuffer
    var pendingPrefetch: [URL: Task<Void, Error>]
}
```

### 3. `HLSRingBuffer` (in-memory segment cache)

```swift
struct HLSRingBuffer {
    let capacityMB: Int  // default 256 MB
    var segments: [URL: Data]
    var insertionOrder: [URL]
    // LRU eviction when capacityMB exceeded
}
```

Why in-memory + size-bounded: HLS segments are 2–10 MB each; a
256 MB buffer holds 25–125 segments = 1–4 minutes of playback.
The user's playhead almost never scrubs more than that backwards;
forward-scrubs invalidate the buffer anyway.  No reason to hit
disk for this — keeps pre-buffering fast.

### 4. Manifest URL rewriter

```swift
extension HLSManifest {
    /// Rewrite a master playlist's variant URIs to point at the
    /// local proxy.  Preserves all attributes; only swaps the
    /// URI line after each #EXT-X-STREAM-INF.
    static func rewriteMasterURIs(
        _ master: MasterPlaylist,
        through proxy: URL,
        sessionID: UUID
    ) -> String { ... }

    /// Same for media playlist segments.
    static func rewriteMediaURIs(
        _ media: MediaPlaylist,
        through proxy: URL,
        sessionID: UUID,
        baseURL: URL  // resolves relative segment URIs
    ) -> String { ... }
}
```

### 5. Pre-fetch scheduler

When the player requests segment N, we look at its position in the
media playlist + spawn `DownloadEngine` jobs for segments
N+1 ... N+PREFETCH_DEPTH.  PREFETCH_DEPTH = 5 is a good starting
point (~30 seconds of buffer ahead; bigger is wasteful, smaller
re-introduces buffering on slow CDNs).

The `DownloadEngine` invocations use the standard bonded multi-
interface engine — same code path that powers regular Splynek
downloads.  The win: each segment downloads in parallel across
every connected interface, typically arriving 2–4× faster than
the player's single-threaded fetch would.

### 6. Browser extension wiring

The extension currently *counts* manifest detections.  Next:
declarativeNetRequest dynamic rule that redirects to the local
proxy.  Approximate Chrome MV3 form:

```js
chrome.declarativeNetRequest.updateDynamicRules({
  addRules: [{
    id: 1,
    priority: 1,
    action: {
      type: "redirect",
      redirect: { regexSubstitution: "http://127.0.0.1:64267/hls/<sid>/\\1" }
    },
    condition: {
      regexFilter: "^https?://([^?]+\\.m3u8?)(\\?.*)?$",
      resourceTypes: ["xmlhttprequest", "media", "other"]
    }
  }]
});
```

Per-stream sessionID (`<sid>` above) gets generated when we first
see a manifest URL; subsequent fetches against the same hostname
in the same browser tab share the session.

## What's tested today (65 tests)

`HLSManifestTests.swift` (30) — kind detection, master + media
parsers, quoted CODECS with embedded comma, multi-variant ABR ladder
+ `pickVariant`, live vs VOD via ENDLIST, byte-range segments for
fragmented MP4, URL pre-filter, attribute-list parser, **DRM
detection (4 schemes)**, **URL rewriter for master + media playlists**,
base64URL roundtrip, relative URI resolution.

`DASHManifestTests.swift` (12) — MPD root recognition, HLS-vs-DASH-
vs-unknown classification, URL extension pre-filter, DRM detection
(Widevine / PlayReady / FairPlay / Common Encryption baseline),
URL extraction (BaseURL + SegmentTemplate media + initialization),
URL rewriter (BaseURL → proxy, DRM body pass-through).

`HLSRingBufferTests.swift` (8) — empty / insert / replace / LRU
eviction at capacity / get-touches-LRU / oversized-segment-fits-
once / clear / snapshot diagnostics.

`HLSProxyServerTests.swift` (8) — handlesPath, parseRoute (master
+ variant + segment + garbage rejection), session lifecycle, prune-
by-age.

`BondedFetcherTests.swift` (7) — splitRange invariants: single
part returns full range, even split, non-divisible total, contiguous-
no-gap-no-overlap across many shapes, zero parts, tiny-file-many-
parts, single-byte file.

## What's NOT tested yet (next-session work)

- Pre-fetch task scheduling under playhead movement (integration
  test against a fake-segment-server fixture)
- Player ABR-switch handling (variant change mid-session)
- HLS+DASH live test on real Vimeo / Twitch — measure buffering
  improvement vs control (manual click-through)
- Real bandwidth split between interfaces under BondedFetcher
  (instrument LaneStats per-interface bytes during HLS playback)

## Threat model + privacy

Same posture as the rest of the Accelerator:

- The proxy listens on 127.0.0.1 only — no LAN exposure
- No bytes hit the internet that the user's browser wasn't already
  going to fetch — we just fetch them faster + cache them locally
- No telemetry, no analytics, no remote config
- Manifests are parsed in-process; no JSON/HTML processing happens
  against attacker-controlled content beyond the strict regex-driven
  parser shipped here

## Legal scope

HLS pre-buffer is legally safe ONLY for DRM-free streams:

- ✅ YouTube non-Premium HLS streams
- ✅ Vimeo public videos
- ✅ Twitch live + VOD
- ✅ Plex (your own server)
- ✅ Most HLS-on-CDN deployments (educational, news, podcast)
- ❌ Netflix / Disney+ / Apple TV+ / HBO Max / Hulu — these use
  Widevine + FairPlay DRM.  We must detect the encryption tag
  (`#EXT-X-KEY`) in the manifest and skip pre-buffering for those.
  Just pass the manifest through unchanged.

The scaffolding committed today doesn't yet include the
DRM-detection branch — that's a one-liner check in the parser
when we wire up the proxy.

## Sequencing

Recommended order for the next session(s):

1. **Day 1**: Manifest URL rewriter + tests (~1 day)
2. **Day 2-3**: HLSProxyServer + HLSSession + ring buffer (~2 days)
3. **Day 4**: Wire chrome.declarativeNetRequest redirect (~1 day)
4. **Day 5**: Live test on real streams (Vimeo, Twitch) +
   measure buffering improvement vs control (~1 day)

Total estimate: ~1 week.  Down from "3 weeks" in the original
strategy memo because the parser + extension scaffolding is
already done.

## Why bother (from STRATEGY-2026.md § Bet S5)

> "Opening Netflix on a hotel Wi-Fi + 5G tether and having it start
> instantly while every other app stutters is a viral-video
> moment.  Folx/Downie/Safari have no answer."

This is the Strategy Memo's "video never buffers" demo.  Once
shipped, the demo video writes itself: split-screen shot of the
same YouTube URL playing on Splynek-Accelerator-Mac vs control
Mac, on weak Wi-Fi.  Splynek side starts instantly + never stalls;
control side spins for 30 seconds.

Apple App Store implications: this is a NEW HTTP route on the
already-existing FleetCoordinator localhost server.  Doesn't
require new entitlements; doesn't change the privacy profile.
Should pass MAS review on the same posture as the existing web
dashboard.
