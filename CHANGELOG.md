# Splynek changelog

A condensed one-line-per-release log. For details, see the relevant
`## What's new in v0.N` section in [README.md](README.md).

## v0.27 — Platform pass (2026-04-17)

- Documented REST API at `/splynek/v1/api/*` with embedded OpenAPI
  3.1 spec at `/splynek/v1/openapi.yaml`.
- `splynek` CLI binary (new SPM target `splynek-cli`) with
  `download`, `queue`, `status`, `history`, `cancel`, `openapi`,
  `version` subcommands.
- Raycast extension (`Extensions/Raycast/`) — three commands.
- Alfred workflow (`Extensions/Alfred/`) — `dl`, `dlq`, `dlstatus`.
- Three new App Intents: `CancelAllDownloads`, `PauseAllDownloads`,
  `ListRecentHistory`.
- AI history search — natural-language query via Ollama, ranks
  entries by relevance.
- Benchmark panel *Save image…* button — 1200×630 PNG OG-card.
- Distribution: `Scripts/dmg.sh` for DMG build; Homebrew cask
  template at `Packaging/splynek.rb`; `LANDING.md` + `CHANGELOG.md`.
- Fleet descriptor (`~/Library/Application Support/Splynek/fleet.json`)
  written on listener-bind so the CLI / Raycast / Alfred discover
  port + token without env-var plumbing.

## v0.26 — Credibility sprint

- Self-hosted test runner (no XCTest dep); 47 tests across Merkle,
  Bencode, magnet parsing, BEP 52 verification, duplicate
  detection, sanitization, web dashboard, QR codes.
- Package split into `SplynekCore` library + `Splynek` executable
  shim so tests can `@testable import`.

## v0.25 — Local-AI download assistant

- Ollama detection + natural-language URL resolution in the
  Download view.

## v0.24 — Web dashboard (the splash)

- Mobile-friendly HTML dashboard served from the fleet HTTP port.
- QR-code pairing via `About → Web dashboard`.
- `POST /splynek/v1/ui/submit?t=<token>` endpoint.

## v0.23 — Smart enrichment

- Pre-start duplicate detection.
- Seven parallel sibling HEAD probes (`.sha256`, `.asc`, `.sig`,
  `.torrent`, `.metalink`, `.meta4`, `.splynek-manifest`).
- Auto-apply `.metalink` + `.splynek-manifest` when found.

## v0.22 — Background-first

- Menu-bar-only mode (`NSApp.setActivationPolicy(.accessory)`).
- Launch at login via `SMAppService`.
- Menu-bar quick-drop popover + drag-to-icon.

## v0.21 — Browser-scale distribution

- Chrome extension (Manifest V3) + Safari bookmarklets.
- Bundled into `.app` + revealed from AboutView.

## v0.20 — LAN content cache

- Unconditional SHA-256 on completion.
- `/splynek/v1/content/<hex>` content-addressed endpoint.
- Cooperative partial-chunk trading between in-flight downloads.
- Engine handles 416 as per-mirror requeue (no lane health hit).

## v0.19 — BitTorrent v2 + fleet

- BEP 52 parser + SHA-256 Merkle piece verification.
- `urn:btmh:1220<hex>` magnet support.
- `FleetCoordinator` — Bonjour discovery + `/status` + `/fetch`.

## v0.18 — Benchmark panel

- Side-by-side single-path vs multi-path bar chart.

## v0.17 — "Flaky internet rescue"

- Lane auto-failover on healthScore decay.
- Per-download speedup report.
- Lifetime time-saved counter.
- Interface preference learning.
- Connection-path transparency.
- `.splynek-manifest` publisher.

## v0.16 — Per-host daily caps

- Editable GB-per-day caps per host; enforced at spawn time.

## v0.15 — Self-download for updates + per-host tally

## v0.14 — Quick Look + update check + BT tit-for-tat + cellular budget

## v0.13 — `GetDownloadProgress` intent + Spotlight + BT choking + torrent resume

## v0.12 — App Intents + per-lane RTT + seeding keepalives

## v0.11 — Session restore + queue export/import + ⌘L

## v0.10 — Shared per-interface bandwidth buckets

## v0.9 — Concurrent downloads

## v0.8 and earlier — foundational pass

- Multi-interface aggregation, NWConnection-bound lanes
- Chunked range GETs, keep-alive reuse
- Gatekeeper + quarantine
- HTTP + UDP trackers, DHT, PEX, magnet (BEP 3/6/9/10/11)
- Seeding service
- Metalink mirrors
- DoH per-lane
