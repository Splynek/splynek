# Splynek strategy — v1.7 → v1.9

> Three-release roadmap building on the v1.6.2 foundation (catalog
> hardening, MCP/Spotlight/App Intents, full localization).
>
> Author: Paulo Graça Moura, sole developer.  Last updated: 2026-04-30.
> Successor to STRATEGY-2026.md (which still defines the bigger
> "S2 / S5 / iOS Companion" frontier bets, none of which are scheduled
> for the next 3 releases).

## Why these three, in this order

The v1.6.x sprint shipped a *credible* download manager.  v1.5.3's
positioning — "macOS multi-interface aggregator + Sovereignty audit" —
is correct but undersells what's actually in the binary by 2026-04.
The MCP server, the App Intents, the Trust catalog, the local-LLM
Concierge, and `GatekeeperVerify` together describe an app that's
**something more than a downloader** — but the marketing copy still
reads like one.

v1.7 → v1.9 closes that gap by shipping three features that turn
existing infrastructure into a coherent product story:

| Release | Feature | Story |
|---|---|---|
| **v1.7** | Concierge as Mac Assistant | "Apple Intelligence wrapper that's actually useful — grounds itself in your data, never sends a byte to the cloud." |
| **v1.8** | Verified Installer | "The first Mac installer that respects your sovereignty AND your network — Homebrew Cask × Little Snitch × Sparkle, in one app." |
| **v1.9** | Fleet 2.0 — LAN Peer Cache | "Multi-Mac household? One Mac downloads, every Mac gets it at gigabit." |

Each release is independently shippable and independently MAS-safe
(none requires `NetworkExtension` or any entitlement Apple hasn't
already granted us in v1.0/v1.5.3).  Each has a specific Pro hook so
$29 buys are concrete, not aspirational.

## Honest non-goals

These came up in strategic discussion but **are not on this roadmap**
because the macOS App Store sandbox makes them either impossible
or sales-killing:

- **Browser-traffic acceleration** — needs `NetworkExtension`/MITM.
  Apple denied the VPN entitlement equivalent.  Closest feasible
  thing (DNS-over-HTTPS racing) lands as a v1.7 free-tier nicety,
  documented honestly.
- **Generic system-wide network proxy** — same blocker.
- **iPhone/iPad app as a network engine** — iOS sandboxes don't expose
  `IP_BOUND_IF`.  Companion app is feasible (remote control + Live
  Activity + Share Extension), but it's a $4.99 add-on, not a
  standalone product, and it makes no sense to ship before Mac
  Splynek has clear pull.  Parked in STRATEGY-2026.md as bet S5.
- **Vibe-coding-style agentic behaviour** — Apple's 2026 enforcement
  of guideline 2.5.2 makes this a rejection vector.  See
  MAS-2.5.2-COMPLIANCE.md.  Splynek's AI stays a *URL classifier*
  and a *tool dispatcher* — never a code generator.

---

## v1.7 — Concierge as Mac Assistant

**Pitch:** "Splynek's Concierge becomes a Mac assistant.  Same chat
box, broader surface.  It can search your download history, list
disk hogs, summarize a PDF, scan your /Applications folder for
Sovereignty alternatives, and yes — still find you the latest
Ubuntu ISO.  Local LLM only.  Zero cloud round-trips."

### Architecture

The Concierge LLM doesn't get free rein.  It picks among a
**fixed, compile-time tool registry** — same architectural pattern
as MCPTools.swift, same 2.5.2 compliance.  Output is structured
JSON: `{tool: "search_history", args: {query: "taxes"}}`.  The
dispatcher invokes the matching Swift handler.  The result renders
as a chat card.

**New tool registry — `ConciergeToolRegistry` (8 tools):**

| Tool | What it does | Reads | Writes |
|---|---|---|---|
| `download_by_goal` | Existing concierge: English → URL → review-and-download sheet | LLM | nothing without user click |
| `search_history` | Substring + token search over DownloadHistory; ranks by recency × relevance | history.json | — |
| `disk_usage` | Top N space-takers under user-selected folder (sandbox-safe) | filesystem (user-picked) | — |
| `installed_apps` | List from `/Applications` via `SovereigntyScanner` plumbing | filesystem | — |
| `sovereignty_report` | Top N apps with recommendable EU/OSS alternatives, ranked by user prominence | catalogs + scan | — |
| `trust_report` | Top N apps with non-trivial Trust concerns, ranked by severity | catalogs + scan | — |
| `summarize_pdf` | Extract text from a user-picked PDF, run through the local LLM, return a paragraph | user-picked file | — |
| `recent_activity` | Last 24h of Splynek activity (downloads, queue events, fleet shares) | history.json + queue | — |

Three of the eight (`download_by_goal`, `summarize_pdf`,
`disk_usage`) require the user to pick a target (URL, file, folder)
inline.  No ambient access to the user's filesystem.

### Files (public repo)

```
Sources/SplynekCore/ConciergeTools.swift       ← tool registry + dispatch types
Sources/SplynekCore/HistorySearch.swift         ← tokenized + ranked history search
Sources/SplynekCore/DiskUsageScanner.swift      ← top-N space-takers
Sources/SplynekCore/PDFSummarizer.swift         ← PDFKit extraction + LLM-prep
Sources/SplynekCore/AppIntentsProvider.swift    ← +3 intents wired to the tools
Tests/SplynekTests/ConciergeToolsTests.swift    ← registry shape, dispatch
Tests/SplynekTests/HistorySearchTests.swift     ← ranking, edge cases
Tests/SplynekTests/DiskUsageScannerTests.swift  ← sandbox-safe enumeration
```

### Files (private Pro repo, splynek-pro)

```
splynek-pro/Sources/SplynekPro/AIAssistant.swift            ← extend with tool-pick prompt + dispatcher
splynek-pro/Sources/SplynekPro/AIConcierge.swift            ← wire to ConciergeToolRegistry
splynek-pro/Sources/SplynekPro/Views/ConciergeView.swift    ← chat with multi-card output
```

### Pro hooks

The 8-tool dispatcher is **Pro-gated** as a whole.  Free tier keeps
the existing pitch view (the upsell card) but adds DNS-over-HTTPS
racing as a free quality-of-life win so free-tier users see *some*
new value in v1.7.  $29 unlocks the assistant.

### App Store risk

Low.  Tool registry is compile-time and identical in shape to the
MCP registry that already passed Apple review (network.server
entitlement granted in v1.0 review).  AI never generates code; the
prompt template + the structured-output decode path are
2.5.2-compliant by construction.

---

## v1.8 — Verified Installer

**Pitch:** "Install any Mac app via Splynek.  We pull it 2-5x faster
across all your network paths.  Verify the publisher's signature.
Show the Trust score *before* launch ('Cursor sends your code to
OpenAI').  Offer the Sovereignty alternative ('Want Vivaldi
instead of Chrome?').  Auto-update on a schedule you control."

### Architecture

The installer is a **pipeline**:

```
1. Resolve(name|url|cask) → InstallSpec       // catalog lookup or URL-direct
2. PreFlightTrustCheck(spec)                  // show Trust score, prompt
3. PreFlightSovereigntyCheck(spec)            // offer EU/OSS alt, optional skip
4. Download(spec) via existing engine         // multi-interface, all the trick
5. Verify(downloaded) via GatekeeperVerify    // signature + notarization + sha
6. Install(verified)                          // .pkg → /Applications, .dmg → mount + copy
7. Register(installed) in InstalledAppRegistry  // for future auto-update
```

Each stage is a free function that returns a result; the UI walks
them in sequence so the user can pause/cancel at any point.

The `InstalledAppRegistry` persists what Splynek installed and where
(canonical bundle path + version + timestamp + source URL + sha).
Auto-update reads from this on its schedule and fires the same
pipeline with the new version.

### Catalog of installable apps

Bootstrap from existing curated sources we already trust:
- **Sovereignty catalog** — every alt with a `downloadURL` is
  installable (Firefox, Thunderbird, LibreOffice, Bitwarden, Signal,
  VLC, etc.).  ~150 candidates already vetted.
- **Trust catalog targets** with a known direct-download URL
  (Cursor, Notion, Slack, Discord, etc.) — opt-in only, since
  installing them carries a Trust warning.
- **Homebrew Cask** as a *read-only* index for "what's available"
  — we don't shell out to brew, but we can mirror the cask URL +
  sha index for ~7000 popular Mac apps as an opt-in feature.

### Files (public repo)

```
Sources/SplynekCore/Installer/InstallerEngine.swift            ← pipeline orchestrator
Sources/SplynekCore/Installer/InstallSpec.swift                ← parsed spec types
Sources/SplynekCore/Installer/InstalledAppRegistry.swift       ← persistence + queries
Sources/SplynekCore/Installer/InstallVerification.swift        ← reuses GatekeeperVerify
Sources/SplynekCore/Installer/PkgInstaller.swift               ← .pkg via Apple's installer
Sources/SplynekCore/Installer/DmgInstaller.swift               ← .dmg mount + copy + unmount
Sources/SplynekCore/Installer/AppMover.swift                   ← .app drag-target install
Sources/SplynekCore/Views/InstallView.swift                    ← new "Install" sidebar tab
Sources/SplynekCore/Views/InstalledAppsView.swift              ← "Installed via Splynek" tab
Tests/SplynekTests/InstallerEngineTests.swift                  ← pipeline contracts + invariants
Tests/SplynekTests/InstalledAppRegistryTests.swift             ← persistence round-trip
```

### Pro hooks

Free tier: install + verify, one-app-at-a-time, no auto-update.
Pro tier: bulk install (multiple apps at once), auto-update with
schedule, "find me an alternative to X" via Concierge integration,
Homebrew Cask index integration.

### App Store risk

Medium.  `.pkg` install needs admin auth (standard Apple
`Authorization` framework) — well-trodden, not flagged by 2.5.2
because the .pkg's payload is signed by Apple-recognized identities
and we ship no scripts of our own.  `.dmg` mount + copy is the same
pattern Sparkle uses.  Risk to mitigate: making sure we never
auto-launch the installed binary (only copy it; user double-clicks
to launch).  Document this in the v1.8 review notes update.

---

## v1.9 — Fleet 2.0 (LAN Peer Cache for In-Flight Downloads)

**Pitch:** "Got more than one Mac on your home network?  When one of
them downloads a 5 GB game update, the others get the bytes off the
LAN at gigabit speed instead of re-downloading from the internet.
Shared bandwidth contribution, automatic peer discovery, all
encrypted, all opt-in per file."

### Architecture

Today's Fleet shares **completed** downloads.  v1.9 extends the
protocol so peers can join a **live in-flight job** and contribute /
benefit.

**New wire verbs (extending FleetCoordinator's existing REST API):**

| Verb | Direction | Purpose |
|---|---|---|
| `POST /fleet/swarm/announce` | seeder → peer | "I'm downloading job X, you have free bandwidth — want to help?" |
| `GET /fleet/swarm/{job}/manifest` | peer → seeder | get the chunk list (size, sha, range) |
| `GET /fleet/swarm/{job}/chunks/{n}` | peer → seeder | pull chunk N from a peer who already has it |
| `POST /fleet/swarm/{job}/contribute` | peer → seeder | "I'll fetch chunks {a, b, c} on my own ISP path; please skip them" |
| `POST /fleet/swarm/{job}/leave` | peer → seeder | clean exit |

The protocol is a **lightweight torrent-but-on-LAN-only**, with
trust assumptions Bonjour can underwrite.  No tracker, no DHT — the
seeder is the rendezvous point.  Encrypted via the existing fleet
token.

### Use cases beyond downloads

The same chunk-share protocol can underpin:
- **Time Machine network targets** — chunks of a backup snapshot
  shared across peers
- **Photos library bootstrap** — new Mac joins the household, pulls
  shared photos from the LAN cache instead of re-downloading from
  iCloud
- **Steam library mirror** — game updates fan across all gaming
  Macs in the home

These are stretch goals for v1.9.  The chunk-share protocol is the
v1.9 deliverable; the application layers on top can each be a
follow-up.

### Files (public repo)

```
Sources/SplynekCore/Fleet/FleetChunkSwarm.swift        ← protocol types
Sources/SplynekCore/Fleet/SwarmCoordinator.swift       ← seeder side
Sources/SplynekCore/Fleet/SwarmParticipant.swift       ← peer side
Sources/SplynekCore/Fleet/SwarmRPC.swift               ← wire encode/decode
Sources/SplynekCore/FleetCoordinator.swift             ← gain new endpoints
Tests/SplynekTests/FleetChunkSwarmTests.swift          ← wire-format invariants
Tests/SplynekTests/SwarmCoordinatorTests.swift         ← contribution math
```

### Pro hooks

Free tier: receive shared chunks (passive participant, gets the
speed-up).  Pro tier: contribute chunks (active seeder for other
Macs in the household), schedule LAN-share windows (only share
during off-hours), bandwidth-cap per peer, "household admin"
view across all Splynek instances.

### App Store risk

Low.  Builds on existing Fleet infrastructure that already shipped
in v1.5.x.  No new entitlements; LAN peers are the same
Bonjour-discovered endpoints we've been talking to since v0.30.
Document in the v1.9 review notes that the protocol is
LAN-restricted (rejects connections from non-RFC1918 origins) for
clarity.

---

## Cross-cutting infrastructure

Three things every release in this roadmap should land:

1. **Localization parity** — every new user-visible string lands in
   `Scripts/regenerate-localizations.py` simultaneously across all 5
   non-English locales.  The CI guardrail (`.github/workflows/lint.yml`)
   already enforces this; just don't fight it.

2. **Test coverage** — every new public type gets a test file.  The
   `LocalizableCatalogTests` invariant (every key × every locale) is
   the model: write the invariant, let the test refuse drift.  Target
   for end of v1.9: 220+ tests (from the v1.6.2 baseline of 170).

3. **2.5.2 invariant comments** — any new file that touches AI,
   external command execution, or dynamic dispatch gets the
   "ARCHITECTURAL INVARIANT" header (see `MCPTools.swift`,
   `Probe.swift` for the template).  This is documentation, but it's
   reviewer-facing documentation — exactly the kind that turns "this
   looks like a vibe-coding tool" into "this is clearly not a
   vibe-coding tool" in 30 seconds.

## Release-cadence assumptions

| Release | Code work | Testing + i18n | Apple review buffer | Total wall-clock |
|---|---:|---:|---:|---:|
| v1.7 | 2 weeks | 1 week | 1 week | **~4 weeks** |
| v1.8 | 4 weeks | 2 weeks | 2 weeks | **~8 weeks** |
| v1.9 | 2 weeks | 1 week | 1 week | **~4 weeks** |

This assumes Apple's v1.0 re-review unblocks within the next 1-7
days.  All three releases are **gated** on v1.0 clearing first;
shipping any of them via DMG-only is fine while we wait, but the
MAS submission queue must clear before the marketing-press wave
begins.

## What ships in this commit (THIS session)

- This document.
- Full v1.7 implementation: 4 new Swift types + 3 new App Intents +
  3 new test suites.  Compiles + tests pass.
- v1.8 architectural skeleton: type definitions only, no UI work.
- v1.9 wire-format types only, no live participant code.
- Plus the localization round to cover every new user-visible string.

This sets up the next session to focus on the Pro-side Concierge
view + AI dispatcher (in `splynek-pro`), then v1.8 UI, then v1.9
participant code.
