# Splynek

**Native macOS download manager that aggregates every interface, cooperates across your LAN, and answers natural-language queries via your local LLM.**

Zero third-party dependencies. Pure Swift. No cloud, no telemetry, no
App Store entitlements.

---

## The headline

Paste a URL. Splynek downloads it over **every network interface you
have at once** — Wi-Fi, Ethernet, iPhone tether, Thunderbolt NIC —
verified byte-for-byte, resumable across reboots, and runs in the
background with a single menu-bar icon.

That's table stakes. Here's what makes it weird:

- **Your Mac talks to your other Macs.** Every Splynek on a LAN
  advertises itself over Bonjour. When you start a download, your
  other Macs can serve you the bytes they've already got — cooperative
  partial-chunk trading over gigabit. Same file gets downloaded from
  the internet exactly once, no matter how many Macs in the office
  want it.
- **Your phone is a remote control.** Scan a QR in *About →
  Web dashboard* with any phone, tablet, or another browser on the
  same network. Paste URLs from your iPhone's Safari share sheet;
  watch throughput tick up live.
- **Natural-language downloads.** If you have [Ollama](https://ollama.com/)
  installed (any model: llama3.2, gemma, phi, qwen), Splynek's
  Download view grows a sparkle row. Type *"the latest Ubuntu 24.04
  desktop ISO"* and the local LLM returns the direct URL. Type
  *"that docker ISO from last Tuesday"* in the History view and it
  finds the right history entry. All offline.
- **Scriptable.** The app hosts a documented REST API on a local
  port (see `/splynek/v1/openapi.yaml`). Ships with a CLI
  (`splynek download <url>`), a Raycast extension, an Alfred
  workflow, and Shortcuts / App Intents integration. Every surface
  hits the same ingest contract.
- **Integrity built in.** SHA-256 verification on every completed
  download. Per-chunk Merkle integrity when a `.splynek-manifest`
  sibling exists. BitTorrent v2 (BEP 52) support including hybrid
  torrents.

## In one image

```
   Wi-Fi      ═══════════▓▓▓▓▓▓▓▓░░░░  40 MB/s   │
   Ethernet   ═══════════▓▓▓▓▓▓▓▓▓▓▓▓  55 MB/s   │  Ubuntu ISO 5.2 GB
   iPhone USB ═══════════▓▓▓▓▓░░░░░░░  22 MB/s   │  ETA 47 s
   ─────────────────────────────────────         │  2.8× faster
   Aggregate  ═══════════▓▓▓▓▓▓▓▓▓▓▓▓ 117 MB/s   │  than best single-path
```

## Download

Splynek is ad-hoc signed (no €99 Apple Developer fee). On first
launch, right-click → **Open** so Gatekeeper lets it through.

- **Direct**: grab the DMG from the releases page and drag to
  `/Applications`.
- **Homebrew**: `brew install --cask splynek` (once the cask
  lands in homebrew-cask).
- **Build from source**: `./Scripts/build.sh`.

## Features

| Area                         | What Splynek does                                      |
| ---------------------------- | ------------------------------------------------------ |
| HTTP aggregation             | Every interface bound via `IP_BOUND_IF`, range GETs    |
| BitTorrent                   | BEP 3/6/9/10/11/52 — v1, v2, hybrid                    |
| LAN cooperation              | Bonjour fleet + content-addressed cache by SHA-256     |
| Integrity                    | SHA-256, per-chunk Merkle, Gatekeeper verdicts         |
| Smart enrichment             | Auto-detect `.torrent`/`.metalink`/`.sha256` siblings  |
| Duplicate detection          | Never re-download the same URL to the same path       |
| Background-first             | Menu-bar-only mode + login item + drag-to-icon         |
| Web dashboard                | Mobile-friendly, QR-scannable from iPhone              |
| Local AI                     | Ollama-backed URL resolution + history search          |
| CLI + REST API               | OpenAPI 3.1 spec + `splynek` binary + Raycast + Alfred |

## Tech stack

Pure Swift + AppKit + SwiftUI + Network.framework + CryptoKit. SPM
executable. ~11 k LOC across ~50 files. No third-party packages.
macOS 13 Ventura or later.

## License

MIT.
