# Splynek

**Native macOS download manager that aggregates every interface,
cooperates across your LAN, audits your other apps for safety and
sovereignty, and answers natural-language queries via your local LLM.**

Pure Swift. Zero third-party dependencies. No cloud, no telemetry.
Notarised + stapled. Mac App Store soon.

---

## Three things at once

Splynek is unusual because it does three things in one menu-bar app:

### 1. Use every network, at once

Paste a URL. Splynek pins outbound sockets to **every network interface
you have** — Wi-Fi, Ethernet, iPhone tether, Thunderbolt NIC — and pulls
the same file in parallel via HTTP byte-range requests. BitTorrent v1+v2.
2-3× faster than single-path on flaky hotel Wi-Fi + 5G tether combos.

```
   Wi-Fi      ═══════════▓▓▓▓▓▓▓▓░░░░  40 MB/s   │
   Ethernet   ═══════════▓▓▓▓▓▓▓▓▓▓▓▓  55 MB/s   │  Ubuntu ISO 5.2 GB
   iPhone USB ═══════════▓▓▓▓▓░░░░░░░  22 MB/s   │  ETA 47 s
   ─────────────────────────────────────         │  2.8× faster
   Aggregate  ═══════════▓▓▓▓▓▓▓▓▓▓▓▓ 117 MB/s   │  than best single-path
```

### 2. Audit your other apps  *(new in v1.5)*

Two new tabs cross-reference your installed Mac apps against public
records and surface what's known about them:

- **Sovereignty** — 1,150+ catalogued apps with their country-of-origin
  + curated European or open-source alternatives. Click "Install" to
  download the alternative through Splynek's engine. Localised
  FR / DE / ES / IT.
- **Trust** — public-record audit using **only verifiable primary
  sources**: Apple App Store privacy labels, EU DPA / FTC / SEC rulings,
  NVD CVE database, HIBP confirmed breaches, vendor security advisories.
  Every concern shown links to its source with a date — we surface
  public record, never opinion. 0–100 risk score paired with the cited
  evidence; never the score in isolation.

Both tabs are MAS-safe, fully local, opt-in, and zero-network. The
catalogs grow automatically via a JSON-backed pipeline + monthly
scheduled agents that propose new entries for human review.

### 3. Cooperate, locally and intelligently

- **Your Mac talks to your other Macs.** Every Splynek on a LAN
  advertises itself over Bonjour. Same file gets downloaded from the
  internet exactly once, no matter how many Macs in the office want it.
- **Your phone is a remote control.** Scan a QR in *About → Web
  dashboard* with any phone or tablet on the same network. Paste URLs
  from your iPhone's Safari share sheet.
- **Natural-language downloads.** With a local LLM (Apple Intelligence
  on macOS 26+, or Ollama / LM Studio), Splynek's Concierge resolves
  *"the latest Ubuntu 24.04 desktop ISO"* to a direct URL. Type
  *"that docker ISO from last Tuesday"* in History and the right
  entry surfaces. All offline.
- **Scriptable.** Documented REST API on a local port. Ships with a
  CLI (`splynek download <url>`), Raycast extension, Alfred workflow,
  Shortcuts / App Intents. Every surface hits the same ingress
  contract.
- **Integrity built in.** SHA-256 verification on every completed
  download. Per-chunk Merkle integrity when a `.splynek-manifest`
  sibling exists. BitTorrent v2 (BEP 52) with hybrid torrents.

## Download

Notarised + stapled by Apple. First launch opens cleanly via Gatekeeper.

- **Direct DMG**: [Splynek-1.5.3.dmg](https://github.com/Splynek/splynek/releases/download/v1.5.3/Splynek-1.5.3.dmg)
  · `SHA-256: 4fe61bab5ee2eb847d789c7f8b2245bf6b180936ec231241284f20b968c0e6cb`
- **Homebrew**: `brew install --cask Splynek/splynek/splynek` *(via the [official Splynek tap](https://github.com/Splynek/homebrew-splynek); upstream `homebrew/cask` once we hit notability)*
- **Mac App Store**: in review *(v1.0 awaiting Apple; v1.5.3 follows)*
- **Build from source**: `./Scripts/build.sh`

## Splynek Pro

One-time **$29** in-app purchase unlocks:

- **Concierge** — natural-language downloads + actions
- **Recipes** — multi-step download plans (e.g. "all Linux ISOs above 4 GB
  released this month"), reviewable + queueable
- **Schedule** — global download window (only download nights / weekends)
- **Web dashboard** — LAN-exposed QR pairing for cross-device control

Free tier is everything else, forever. No subscription, no telemetry,
no upsell pop-ups. Sovereignty + Trust are free-tier — they're statements
of values before they're features, and gating them behind payment would
undermine that.

## Features

| Area                         | What Splynek does                                          |
| ---------------------------- | ---------------------------------------------------------- |
| HTTP aggregation             | Every interface bound via `IP_BOUND_IF`, range GETs        |
| BitTorrent                   | BEP 3/6/9/10/11/52 — v1, v2, hybrid                        |
| LAN cooperation              | Bonjour fleet + content-addressed cache by SHA-256         |
| Integrity                    | SHA-256, per-chunk Merkle, Gatekeeper verdicts             |
| **Sovereignty audit**        | **1,150+ apps mapped to EU / OSS alternatives**            |
| **Trust audit**              | **Public-record concerns from Apple, regulators, NVD, HIBP** |
| Smart enrichment             | Auto-detect `.torrent` / `.metalink` / `.sha256` siblings  |
| Duplicate detection          | Never re-download the same URL to the same path           |
| Background-first             | Menu-bar mode + login item + drag-to-icon                  |
| Web dashboard                | Mobile-friendly, QR-scannable from iPhone                  |
| Local AI                     | Apple Intelligence + Ollama + LM Studio backends           |
| CLI + REST API               | OpenAPI 3.1 spec + `splynek` binary + Raycast + Alfred     |
| **Localisation**             | **English + FR / DE / ES / IT for Sovereignty + Trust**    |

## Tech stack

Pure Swift + AppKit + SwiftUI + Network.framework + CryptoKit. SPM
executable. ~12 k LOC across ~55 files. No third-party packages. macOS
13 Ventura or later (Apple Intelligence requires macOS 26+).

## Privacy

- No accounts. No telemetry. No analytics. No crash reports.
- The Sovereignty + Trust scans run **on-device only** — your installed-
  app list never leaves your Mac.
- The local AI runs locally. Cloud LLM API keys are not supported by
  design.
- Published [App Privacy Label](https://apps.apple.com/...) declares
  14× *Data Not Collected*.

## License

MIT (free tier). Pro modules in a closed-source companion repo.
