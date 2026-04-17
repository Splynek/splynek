# Splynek — security & privacy

Splynek is a Mac-local download manager. It has no cloud backend, no
telemetry, no user accounts, and no outbound traffic beyond what the
user explicitly asks it to fetch. This document is a plain-English
threat model + what Splynek does about each threat.

## Network exposure

Splynek opens **one** local HTTP listener — the fleet coordinator —
on a random high port picked by the OS. By default it binds to **all
interfaces** so the mobile web dashboard (v0.24) can reach it from
your iPhone over LAN. The listener serves:

| Path | Method | Auth | What it does |
| --- | --- | --- | --- |
| `/splynek/v1/status`              | GET  | open  | Fleet peer state (filename, URL, sha256 of completed) |
| `/splynek/v1/openapi.yaml`        | GET  | open  | API spec |
| `/splynek/v1/fetch?url=<enc>`     | GET  | open  | Range-GET bytes of a file this Mac is serving |
| `/splynek/v1/content/<hex>`       | GET  | open  | Range-GET by content hash |
| `/splynek/v1/api/jobs`            | GET  | open  | Active downloads |
| `/splynek/v1/api/history`         | GET  | open  | Recent completions |
| `/splynek/v1/api/download`        | POST | token | Start a download |
| `/splynek/v1/api/queue`           | POST | token | Queue a URL |
| `/splynek/v1/api/cancel`          | POST | token | Cancel everything |
| `/splynek/v1/ui`                  | GET  | open  | Web dashboard HTML |
| `/splynek/v1/ui/state`            | GET  | open  | Dashboard JSON |
| `/splynek/v1/ui/submit?t=<token>` | POST | token | Dashboard submit |

**Read endpoints are open by design** — the LAN fleet protocol needs
them for cooperative caching (v0.20). Every write endpoint requires
the 16-byte random token from
`~/Library/Application Support/Splynek/fleet.json`.

## Threat model

### T1 — hostile LAN peer floods our listener with connections

Mitigation: per-remote-address sliding-window rate limiter. Cap 60
requests per 10-second window per IP. Overflow returns
`429 Too Many Requests` with a `Retry-After` header. GC prunes stale
entries when the table grows past 256 hosts.

### T2 — hostile LAN peer serves wrong bytes via the fleet cache

Mitigation: every byte Splynek accepts is verified against either a
user-supplied SHA-256 or a per-chunk Merkle manifest (`.splynek-manifest`
sibling). A fleet-served chunk that doesn't match the expected hash
is treated as a failed chunk and requeued to a different mirror.
A hostile fleet peer produces retries, not corrupted output.

### T3 — LAN peer enumerates what you've downloaded

Mitigation: **Privacy mode** (About → Security). When enabled, the
`/status` endpoint returns empty `active` + `completed` lists to
LAN peers. The web dashboard on this Mac still works; only external
reads are gated. Cooperative LAN cache is disabled while privacy
mode is on.

### T4 — attacker on a coffee-shop Wi-Fi reaches the web dashboard

Mitigation: **Loopback-only mode** (About → Security). When enabled,
the fleet listener binds to `127.0.0.1` instead of all interfaces.
The web dashboard + API become reachable only from this Mac. Takes
effect at next launch.

### T5 — token leaked via shared QR code / screenshot / git

Mitigation: **Regenerate token** button. Writes a new 16-byte secret
to UserDefaults and `fleet.json`. The old token stops working
immediately. Users need to re-scan the QR (or re-install extensions
that cached it) — the CLI picks up the new token on next call
because it re-reads the descriptor every time.

### T6 — token guessed / brute-forced over LAN

Analysis: 16-byte tokens = 2^128 keyspace. The rate-limiter caps
guesses at 60/10s = 6/s per IP = ~2^34 years for a 50% hit. Not a
realistic attack.

### T7 — path-traversal via `url` query parameter

Mitigation: the `url` param is used only to *look up* a URL in the
published state dictionary. Splynek doesn't `fopen` a user-supplied
path; it serves only paths that were registered by a local download
or completion. Server-supplied filenames are further sanitized via
`Sanitize.filename`, which strips `/`, `\`, null bytes, control
chars, and leading dots (see `Tests/SplynekTests/SanitizeTests.swift`
— 7 tests pin the sanitiser).

### T8 — malicious HTML served by the web dashboard

Analysis: the dashboard HTML is embedded in `WebDashboard.swift` as
a compile-time constant. No runtime user input reaches it. XSS via
filenames rendered into the DOM is prevented by
`escapeHTML(...)` in the dashboard JS.

### T9 — malicious download poses as a trusted binary

Mitigation: the engine runs every completed download through macOS
Gatekeeper (`spctl --assess`) and stamps `com.apple.quarantine` so
the OS shows the "Downloaded from the internet" dialog on first
run. The verdict is surfaced in the job card. For signed binaries
with a Merkle manifest, per-chunk verification catches corruption
in-flight.

### T10 — DoH lookup leaks hostname to the OS resolver

Mitigation: when `Per-interface DoH` is on, hostname resolution
happens via Cloudflare's DoH endpoint (1.1.1.1/dns-query) over the
same `NWConnection` as the payload, pinned to the chosen interface
via `NWParameters.requiredInterface`. The OS resolver is bypassed
for that lane's hostname.

## Auditable properties

- No third-party Swift dependencies (`Package.swift` has no
  `products` or external `.package` references).
- Everything except the embedded WebDashboard HTML is pure Swift
  against Foundation, Network.framework, SwiftUI, AppKit,
  CryptoKit, CoreImage.
- 54+ tests (`swift run splynek-test`) cover Merkle math, Bencode,
  BEP 52 verification, magnet parsing, duplicate detection,
  sanitization, web-dashboard HTML contract, OpenAPI spec shape,
  fleet descriptor round-trip.
- Source is inspectable; release binaries are stripped but built
  deterministically from `./Scripts/build.sh`.

## What we deliberately don't do

- **No usage analytics.** No `/collect` endpoint phoning home. No
  crash reporter, no UUID-that-follows-you, no product telemetry.
- **No silent auto-update.** v0.14 added an opt-in JSON feed check
  that only runs if you set `updateFeedURL` in UserDefaults.
- **No cloud sync of history / state.** Everything lives under
  `~/Library/Application Support/Splynek/`.
- **No DRM / subscription phone-home.** If a Pro tier ships
  (see [MONETIZATION.md](MONETIZATION.md)), license verification
  happens at purchase time only; nothing contacts a server on
  every launch.

## Reporting issues

Open an issue or email the maintainer directly. Security-sensitive
issues: don't file publicly — email first so a fix can land before
disclosure.
