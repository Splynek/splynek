# Splynek handoff

Native macOS multi-interface download aggregator. Pure Swift, zero
third-party deps. Public free-tier repo (MIT) + private Pro-tier repo.
~12k LOC across ~55 files.

**Working directory:** `/Users/pcgm/Claude Code`
**Public repo:** [github.com/Splynek/splynek](https://github.com/Splynek/splynek) — MIT, remote is `origin`, tags `v0.31` + `v0.43` + `v0.44` pushed.
**Private repo:** [github.com/Splynek/splynek-pro](https://github.com/Splynek/splynek-pro) — closed-source, expected at `../splynek-pro` (sibling checkout).
**Live site:** [https://splynek.app](https://splynek.app) with `/pro`, `/support`, `/privacy`. HTTPS via Let's Encrypt (auto-renews); DNS at Cloudflare, Pages served by GitHub.
**Domain:** splynek.app (owned, CNAME'd via `docs/CNAME`).
**Build (DMG ad-hoc):** `./Scripts/build.sh` → `build/Splynek.app`
**Build (DMG Developer-ID, for notarisation):**
```
SIGN_IDENTITY="Developer ID Application: Paulo Moura (58C6YC5GB5)" \
  ENTITLEMENTS="Resources/Splynek.entitlements" ./Scripts/build.sh
./Scripts/dmg.sh
xcrun notarytool submit build/Splynek.dmg --keychain-profile AC_PASSWORD --wait
xcrun stapler staple build/Splynek.dmg
```
**Build (MAS):** `./Scripts/build-mas.sh` → `build/Splynek-MAS.xcarchive` + `build/Splynek-MAS-Export/Splynek.pkg`
**Tests:** `swift run splynek-test` (148 tests, all green)
**CLI:** `swift run splynek-cli version` (plus `sovereignty-dump` for catalog round-trip)

**Current version: v1.5.4 — shipped 2026-04-26.** v1.5.3 DMG live on GitHub Releases (notarised + stapled). v1.5.4 adds Trust score weights UI (Settings → 4 sliders), per-axis score breakdown in TrustView, Info.plist sync invariant test (caught real version-drift bug). Mac App Store v1.0 in re-review since 2026-04-26 (resubmitted with Resolution Center reply + edit-and-save touch). Full release history + download URLs under § Shipped releases below.

---

## ⚡ Session handoff — current state (2026-04-26)

**For a fresh session picking this up.** TL;DR: shipped a lot, everything green, marketing is staged but not deployed, waiting on Apple, three scheduled cron triggers + two repos cleanly committed.

### What's running

| Track | State | Where |
|---|---|---|
| **Apple App Store v1.0 review** | ⏳ Resubmitted 2026-04-26 with VPN-clarification Resolution Center reply + App Review Notes update + clicked "Atualizar revisão". Status: `A aguardar revisão`. ETA `In Review`: 24-72h. ETA decision: +24h. | App Store Connect |
| **Sovereignty cron trigger** | ⏳ First fire **2026-05-01 09:00 UTC**. Public repo only; drafts up to 20 catalog entries from `Scripts/sources/*.json`, opens PR. | https://claude.ai/code/scheduled/trig_01JEuDpurUC21nHkumwdEfaB |
| **Trust cron trigger** | ⏳ First fire **2026-05-15 09:00 UTC**. Refreshes catalog entries with `lastReviewed > 90 days`, checks NVD + HIBP for new findings, opens PR. | https://claude.ai/code/scheduled/trig_01VZNTUM4ikbYH5XBtpnn1ER |
| **Quarterly audit cron** | ⏳ First fire **2026-06-01 09:00 UTC**. Audits a rotating area (Q1=networking, Q2=views, Q3=scripts, Q4=build), opens GitHub issue with `audit` label. | https://claude.ai/code/scheduled/trig_0161CxCRWwnG5F48ynpTaspi |
| **GitHub Actions weekly** | ✅ Live — runs Sovereignty validator + URL liveness check every Monday. | `.github/workflows/sovereignty-weekly.yml` |
| **Homebrew tap** | ✅ Live at [`Splynek/homebrew-splynek`](https://github.com/Splynek/homebrew-splynek). Install: `brew install --cask Splynek/splynek/splynek`. | Self-hosted |
| **Upstream homebrew/cask** | ❌ PR #261294 auto-rejected (notability: 0 stars / 0 forks / 0 watchers vs ≥75 / ≥30 / ≥30 needed). Resubmit after Show HN drives stars. | https://github.com/Homebrew/homebrew-cask/pull/261294 |
| **splynek.app landing** | ⏸️ Still on v1.3 copy. New copy ready in `docs/index.v1.5.3.html.draft` (NOT live). Deploy: `mv docs/index.html docs/index.v1.4.previous.html && mv docs/index.v1.5.3.html.draft docs/index.html && git push` — **only after** v1.0 clears Apple. |
| **Press / Show HN / directory submissions** | ⏸️ All staged in `PRESS_KIT.md`, `SHOW_HN.md`, `DIRECTORIES.md`. Don't trigger before v1.0 clears (App reviewers may visit splynek.app and reject for marketing-vs-build inconsistency). |

### Repo state — both clean

| Repo | Branch | Latest commit | Status |
|---|---|---|---|
| `Splynek/splynek` (public) | `main` | will be at HEAD after this session's commit | clean working tree |
| `Splynek/splynek-pro` (private) | `main` | `893d5bc` (v1.5.3 ContextCard migration) | clean |
| `Splynek/homebrew-splynek` (tap) | `main` | initial v1.5.3 cask | clean |

### Latest release artifact

- **DMG**: [Splynek-1.5.3.dmg](https://github.com/Splynek/splynek/releases/tag/v1.5.3) — 3.8 MB
- **SHA-256**: `4fe61bab5ee2eb847d789c7f8b2245bf6b180936ec231241284f20b968c0e6cb`
- **Notarised + stapled**: ✅ Apple notary status `Accepted`
- **Signed**: Developer ID Application: Paulo Moura (58C6YC5GB5)

### Critical files (don't break / always update together)

- **Version sources** (must stay in sync — `InfoPlistSyncTests` enforces):
  - `Resources/Info.plist` → `CFBundleShortVersionString`
  - `project.yml` → `MARKETING_VERSION`
  - `Extensions/Alfred/Splynek.alfredworkflow/info.plist` → `CFBundleShortVersionString`
- **Catalog generators** — never edit the generated `+Entries.swift` files directly:
  - `Scripts/sovereignty-catalog.json` → `Scripts/regenerate-sovereignty-catalog.swift` → `Sources/SplynekCore/SovereigntyCatalog+Entries.swift`
  - `Scripts/trust-catalog.json` → `Scripts/regenerate-trust-catalog.swift` → `Sources/SplynekCore/TrustCatalog+Entries.swift`
- **Live website** — `docs/index.html` is what serves splynek.app. The `.draft` variant is staging.
- **Splynek.entitlements** — minimal entitlement set; do not add `NetworkExtension` (Apple reviewer specifically asked about VPN; we declared none).

### Common commands

```bash
# Build for testing
swift build --product Splynek                                 # debug, ~30s
.build/debug/Splynek                                          # run

# Build for release
SIGN_IDENTITY="Developer ID Application: Paulo Moura (58C6YC5GB5)" \
  ENTITLEMENTS="Resources/Splynek.entitlements" ./Scripts/build.sh
./Scripts/dmg.sh
xcrun notarytool submit build/Splynek.dmg --keychain-profile AC_PASSWORD --wait
xcrun stapler staple build/Splynek.dmg

# Tests + validators
swift run splynek-test                                        # 148 tests
swift Scripts/validate-catalog.swift                          # Sovereignty offline lint
swift Scripts/validate-trust-catalog.swift --strict           # Trust offline lint
swift Scripts/check-urls.swift --only-download                # online URL liveness (~3 min for 1155 entries)

# Catalog round-trip
swift run splynek-cli sovereignty-dump > Scripts/sovereignty-catalog.json   # Swift → JSON
swift Scripts/regenerate-sovereignty-catalog.swift                          # JSON → Swift
swift Scripts/regenerate-trust-catalog.swift

# Bump cask after a new release
git clone https://github.com/Splynek/homebrew-splynek /tmp/tap
cp Packaging/splynek.rb /tmp/tap/Casks/splynek.rb
cd /tmp/tap && git add . && git commit -m "splynek X.Y.Z" && git push

# Capture press screenshots
./Scripts/capture-screenshots.sh   # interactive — ~10 min for all 10
```

### When v1.0 clears Apple — the launch sequence

```bash
# 1. Update MAS version metadata → v1.5.3 (in App Store Connect, version page)

# 2. Upload v1.5.3 archive via Xcode Organizer → Distribute App → MAS

# 3. Deploy landing
cd "/Users/pcgm/Claude Code"
mv docs/index.html docs/index.v1.4.previous.html
mv docs/index.v1.5.3.html.draft docs/index.html
git add docs/ && git commit -m "landing: deploy v1.5.3" && git push

# 4. Capture screenshots (skipped this session — script ready)
./Scripts/capture-screenshots.sh

# 5. Wait for MAS Ready for Sale (~24h)

# 6. Show HN (Tuesday/Wednesday 14-16 UTC) — copy from SHOW_HN.md

# 7. Press emails in waves — templates in PRESS_KIT.md
#    Wave 1: EU sovereignty (Le Monde, Der Spiegel, El País, Repubblica, Politico EU, Heise)
#    Wave 2 (1h later): Privacy (Wired, FT, The Information, MIT TR, EFF, The Markup)
#    Wave 3 (1h later): Mac power-user (MacStories, 9to5Mac, Eclectic Light, MacRumors, Six Colors)

# 8. Directory submissions — pre-filled forms in DIRECTORIES.md (Tier 1 first)

# 9. Day 7: Product Hunt launch (Thursday)

# 10. After 75 stars on the upstream repo: resubmit homebrew/cask PR
```

### v1.6 candidates (next-bites queue)

After Apple v1.0 clears, these are unblocked. Priority is the maintainer's call:

- **A.** Resubmit upstream homebrew/cask PR (after Show HN reaches 75 stars)
- **B.** Stripe + Postmark direct channel (see `MONETIZATION.md`) — alternative to MAS for users who can't pay via App Store
- **C.** Localise remaining tabs (Concierge, Recipes, Downloads — currently English-only; Sovereignty + Trust are FR/DE/ES/IT)
- **D.** v1.6 features: shareable Trust-scan report (PDF / shareable PNG), Sovereignty CSV export, more Trust catalog entries (target 100 from current 30)
- **E.** S2 — Unbreakable Resume (HTTP Range + NWPathMonitor + curated mirror failover) — see `STRATEGY-2026.md`
- **F.** S5 — Splynek Accelerator (browser extension + HLS pre-buffer)
- **G.** iOS Companion (Share Extension + Live Activity)

### Pending tech debt (non-blocking)

- 85 lint warnings in Sovereignty catalog (mostly short notes <30 chars on bulk-seeded entries from v1.4 — would benefit from a long-form pass when there's time)
- `Marketing/screenshots/` and `Scripts/make-mas-screenshots.sh` are stale untracked files left from earlier sessions; safe to delete or just ignore
- `homebrew-cask` upstream PR can be reopened or new PR submitted; thread is at https://github.com/Homebrew/homebrew-cask/pull/261294
- 4 Trust catalog entries cite >18-month-old sources (Adobe 2013 breach, Evernote 2013 breach, Kaspersky CISA 2017, BIS 2024) — flagged by validator as info-only, no action needed but the next Trust cron run should re-verify the URLs still resolve

### Files added this session — quick reference

```
Sources/SplynekCore/Views/SettingsView.swift   ← Trust weights card (4 sliders + reset)
Sources/SplynekCore/Views/TrustView.swift      ← per-axis score breakdown
Sources/SplynekCore/ViewModel.swift            ← trustWeight* @Published + sanitised computed
Tests/SplynekTests/InfoPlistSyncTests.swift    ← version drift invariant
PRESS_KIT.md                                   ← refined cold-pass press kit
DIRECTORIES.md                                 ← pre-filled directory submission forms
Scripts/capture-screenshots.sh                 ← interactive screenshot capture (10 named shots)
Branding/v1.5.3/README.md                      ← screenshot conventions + post-capture pipeline
docs/index.v1.5.3.html.draft                   ← staged landing (deploy on Apple clear)
Packaging/splynek.rb                           ← v1.5.3 cask, brew-style clean
.github/workflows/sovereignty-weekly.yml       ← Mon cron: validate + URL liveness
```

### Things to NOT do without thinking

- **Don't push splynek.app changes** until v1.0 is `Ready for Sale` on App Store Connect.
- **Don't send press emails** until the landing matches what reviewers might see.
- **Don't merge cron-opened PRs blindly** — the agents draft, the maintainer approves.
- **Don't delete the upstream homebrew/cask PR** — closed is fine; the thread is the timestamp record.
- **Don't bump version in just one of the three plists** — InfoPlistSyncTests will fail.
- **Don't add `NetworkExtension` entitlement** — Apple already asked about VPN; we explicitly declared none.
- **Don't run cron triggers manually unless you understand they open PRs** — the dashboard has a "Run now" button; use it deliberately.

### How to ramp a fresh session in 5 minutes

```
1. Read HANDOFF.md (this file) top 250 lines
2. cd /Users/pcgm/Claude Code; git status (both repos must be clean)
3. swift run splynek-test (must show 148/148 — anything less is a regression)
4. Open https://claude.ai/code/scheduled and check the three triggers fired clean
5. Open https://appstoreconnect.apple.com → Splynek → Distribuição → check v1.0 status
```

If everything green → ask the user what to work on. The "v1.6 candidates" list above is the queue.

---

## Shipped releases (in order)

All Developer-ID-signed, notarised, stapled, and published at
<https://github.com/Splynek/splynek/releases>. SHA-256 hashes match the
release-notes bodies.

### v1.5 — Trust tab (2026-04-25)
- New tab in the sidebar Ask section (next to Sovereignty). Free-tier; no PRO gate.
- **Source allowlist (legal/MAS guarantee):** every concern cites Apple App Store privacy labels, EU DPA / FTC / SEC rulings, NVD CVE, HIBP breaches, vendor security advisories, or vendor's own privacy policy. Editorial words (`spies`, `untrustworthy`, `you are the product`, etc.) are rejected by the regenerator. See `TRUST-CONTRIBUTING.md`.
- **30 deeply-cited initial entries** in `Scripts/trust-catalog.json` covering the most-installed apps (Chrome, Messenger, WhatsApp, Slack, Zoom, Teams, Dropbox, LastPass, TikTok, WeChat, Yandex Browser, Kaspersky, Adobe, ChatGPT, …).
- `TrustScorer` produces 0–100 score + categorical level (Low/Moderate/High/Severe). Pure + deterministic + weight-aware. UI always shows score + level + cited concern labels — never the score alone.
- **Alternatives lookup chain:** Sovereignty catalog (EU/OSS) first → Trust's own `fallbackAlternatives` → "no curated alt yet, contribute one".
- Pipeline mirrors Sovereignty: `Scripts/trust-catalog.json` → `regenerate-trust-catalog.swift` → `Sources/SplynekCore/TrustCatalog+Entries.swift`. Validator at `Scripts/validate-trust-catalog.swift --strict`.
- 18 new tests in `TrustCatalogTests` + `TrustScorerTests` — banned-phrase guard, HTTPS-only, ID uniqueness, scorer bounds, level thresholds.
- FR/DE/ES/IT localisation for all Trust strings.

### v1.4 — Catalog pipeline (90→1167) + discovery/quality engines + AI hardening + FR/DE/ES/IT (2026-04-24)
- **DMG**: not yet cut (waiting for this session's work to land). After commit + tag, run the Developer-ID build + notarise flow from the top of this file.
- **Catalog grew 13×** (90 → 1167 entries — a full order of magnitude). New authoring flow: edit `Scripts/sovereignty-catalog.json`, run `swift Scripts/regenerate-sovereignty-catalog.swift`, commit both the JSON and the regenerated `Sources/SplynekCore/SovereigntyCatalog+Entries.swift`. See SOVEREIGNTY-CONTRIBUTING.md for the full pipeline. Compile-time type safety preserved; community can now PR via JSON diffs.
- **Discovery + quality engines** (v1.4 second pass — for indefinite catalog growth):
  - `Scripts/discover.swift` — finds new apps from external source files (`Scripts/sources/*.json`), local `/Applications/` (`--from-apps`), or display-name lists (`--from-file`); diffs against the catalog; emits `Scripts/candidates.json`.
  - `Scripts/ai-propose.swift` — drafts alt-sets for each candidate via local LLM (LM Studio, Ollama, OpenAI-compat). System prompt mirrors the FORBIDDEN PATTERNS block in `splynek-pro/AIAssistant.swift` to minimise US-leakage. Output: `Scripts/proposals.json`.
  - `Scripts/merge-proposals.swift` — reviewer-in-the-loop; interactive prompts (a/s/q) or `--auto-accept high` for trusted batches; validates against catalog invariants before merge.
  - `Scripts/validate-catalog.swift` — offline lint: bundle-ID format, dup IDs, short/long notes, non-https homepages, placeholder hosts. Errors are hard-fail; warnings flagged. `--strict` makes warnings fail too.
  - `Scripts/check-urls.swift` — concurrent online URL checker. Default 20 workers, 15s timeout per URL. `--json` for CI consumption, `--fail-on-rot` for non-zero exit.
  - `.github/workflows/sovereignty-weekly.yml` — weekly cron: lint + regen-roundtrip + URL health; opens a labeled GitHub issue if URLs rotted.
- New `splynek-cli sovereignty-dump` subcommand: reverse-exports the catalog back to JSON (for verifying round-trip, or reseeding the JSON if Swift gets edited directly).
- The v1.4 bulk-seed itself is in `Scripts/seed-sovereignty-bulk.swift` — category templates × target tuples; idempotent, re-runnable. Useful for future bulk imports from curated external lists (european-alternatives.eu, switching.software, awesome-euro-tech).
- New `splynek-cli sovereignty-dump` subcommand: reverse-exports the catalog back to JSON (for verifying round-trip, or reseeding the JSON if Swift gets edited directly).
- **AI fallback hardening.** System prompt gains a FORBIDDEN PATTERNS block listing Netflix/YouTube/Discord/Slack/Dropbox/ChatGPT/etc. as things the model must NEVER propose. On top of that, a `sovereigntyDenyList` post-filter on `SovereigntySuggestion` strips any model-emitted name whose normalised form matches a known US/CN/RU product — belt + suspenders against the 3B model's hallucinations.
- **Localisation — FR / DE / ES / IT.** Sovereignty tab's ~30 UI strings now localised. New `Sources/SplynekCore/Localizable.xcstrings`. Package.swift gains `defaultLocalization: "en"` and declares the xcstrings as a processed resource. PageHeader widened to `LocalizedStringKey` (forward-compat; existing English-only callers unchanged).
- **Catalog invariant tests.** `Tests/SplynekTests/SovereigntyCatalogTests.swift` locks in contributor rules: every target is non-EU; every alt is .europe/.oss/.europeAndOSS/.other (never US/CN/RU); every entry has ≥1 recommendable alt; IDs unique; ≥100 entries. Test count: 117 → 124.
- Related commits: `/Users/pcgm/Claude Code` @ (pending) — `/Users/pcgm/splynek-pro` @ (pending)

### v1.3 — Sovereignty catalog 2× + AI fallback (2026-04-24)
- **DMG**: [Splynek-1.3.dmg](https://github.com/Splynek/splynek/releases/download/v1.3/Splynek-1.3.dmg) — `d08ee9f5546aa96f1c66b1011508f76e2c6852f0275f66fe7e5817ec7d7c73d4`
- Sovereignty catalog 50 → 90 entries (new: Arc, Opera/CN, Superhuman, HEY, OmniFocus, TickTick/CN, Asana, Trello, Jira, Confluence, monday.com, Raycast, Magnet, Moom, Warp, Nova, Navicat/HK, Plex, Emby, NordVPN, ExpressVPN, Perplexity, Copilot, Steam + more)
- Thunderbird joins Firefox as one-click-Install alternatives
- **New: AI fallback for uncataloged apps.** Per-app Ask-AI button routes through the local LLM with a sovereignty-focused prompt. Results render inline. Gated on `vm.aiAvailable`.
- Related commits: `/Users/pcgm/Claude Code` @ `4c27964`, `/Users/pcgm/splynek-pro` @ `f62a2ed`

### v1.2 — Sovereignty tab (2026-04-24)
- **DMG**: [Splynek-1.2.dmg](https://github.com/Splynek/splynek/releases/download/v1.2/Splynek-1.2.dmg) — `e50cdf80366542300b300ea6708624edf660785f77291f04eb8f37cd2b8dc52d`
- New Sidebar tab **Sovereignty** (`shield.lefthalf.filled`, NEW badge) — scans installed apps locally and surfaces European or open-source alternatives
- Framing is explicitly **pro-EU-sovereignty, not anti-any-country.** Target apps show their origin as a neutral grey badge (US / CN / RU / OTHER); alternatives show EU / OSS / EU+OSS coloured badges. The `Origin.isRecommendable` property enforces that alternatives can only be European or OSS.
- 50-entry seed catalog covering common US/CN/RU/OTHER apps
- Filter chips: All alternatives / European only / Open-source only
- One-click "Install" button for alternatives with stable download URLs (Firefox v1.2; Thunderbird added v1.3)
- Community-contribution guide at [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md)
- Concierge regex short-circuit for cancel/pause commands (10–17 s → microseconds)
- Apple Intelligence `session.prewarm()` on input-focus
- Related commits: `/Users/pcgm/Claude Code` @ `e09d69a`, `/Users/pcgm/splynek-pro` @ `ca38159`

### v1.1.1 — Concierge blank-state hotfix (2026-04-23)
- **DMG**: [Splynek-1.1.1.dmg](https://github.com/Splynek/splynek/releases/download/v1.1.1/Splynek-1.1.1.dmg) — `f114345f690f30acbdc546f14da6d09999a82f93514a4f83122c0fa4501d3a79`
- v1.1 shipped with a **macOS 26 SwiftUI regression** that blanked the entire NavigationSplitView the instant a user clicked a Concierge suggestion chip. Fixed in v1.1.1 via **three combined changes** (all load-bearing; see POSTMORTEM).
- `@MainActor AppleIntelligenceDriver` enum wraps `LanguageModelSession` per Apple's WWDC25 session 286 canonical pattern — keeps `Observation.Observable` notifications on MainActor so SwiftUI narrows invalidation correctly.
- Dedicated `ConciergeState: ObservableObject` holds `chat` + `thinking`. Scopes re-renders to `ConciergeView` only — not Sidebar + RootView.
- `GeometryReader` + explicit `.frame(width: geo.size.width, height: geo.size.height)` in `ConciergeView.body`. Pins the detail column so `NavigationSplitView` can't shrink it below `min: 640` during a ViewBuilder branch swap.
- Plus Concierge upgrades: **probe-validator** (every AI-suggested URL runs through `Probe.run` before Concierge surfaces `.download` / `.queue`), **multi-candidate retry** (model returns `candidates: [String]` — we probe in order, first success wins), **solution-oriented fallback** (when every URL fails, render the model's `alternatives: [String]` project names instead of an error message), **tolerant JSON extractor** (handles markdown fences + prose-wrapped output).
- Full write-up in [POSTMORTEM-Concierge-Blank.md](POSTMORTEM-Concierge-Blank.md) — four dead-end debugging paths, the clinching diagnostic, six rules-of-thumb for `NavigationSplitView` detail panes on macOS 26. **Required reading for anyone touching the Concierge or adding a new detail view.**
- Related commits: `/Users/pcgm/Claude Code` @ `15b1645`/`17e2597`, `/Users/pcgm/splynek-pro` @ `eebc756`

### v1.1 — Apple Intelligence Concierge (2026-04-21)
- Apple Foundation Models as the primary AI provider on macOS 26+. Ollama + LM Studio remain as fallback / pre-macOS-26 path. `AIAssistant.detect()` probes Apple Intelligence first, then LM Studio, then Ollama — first ready wins.
- Zero-install on eligible Macs. Footer reads "Using Apple on-device model via Apple Intelligence".
- **Shipped with the blank-state bug** — superseded by v1.1.1.

### v1.0 — Launch (2026-04-21)
- First stable App Store candidate. Same binary as v0.50.4 with `MARKETING_VERSION` bumped to 1.0.
- Still in App Store review (v1.0 submitted; not yet Ready for Sale as of 2026-04-24).

### Pre-1.0 context

**v0.47** — P1+P2+P3 QA polish pass. 16 bugs fixed. Tooltips added to jargon controls. Queue Summary card redesigned.
**v0.46** — 6 P1 bugs fixed + 7 P2 polish items. Throughput clamped to 0.5 s min window.
**v0.45** — MAS build infrastructure. XcodeGen, sandbox entitlements, StoreKit 2.
**v0.44** — Public/private split. Pro modules moved to `splynek-pro`. Public ships stubs.
**v0.40** — BitTorrent v2, DHT, persistent resume.
**v0.30–0.43** — LAN fleet, Bonjour discovery, REST API, web dashboard, metalink, merkle.

---

## MAS submission status (as of 2026-04-24)

- Apple Developer Program enrolled (€99, Team ID `58C6YC5GB5`)
- App ID registered: `app.splynek.Splynek` with `In-App Purchase` capability
- Apple Distribution + Developer ID Application certs in keychain
- App Store Connect app record created (macOS app "Splynek", SKU `splynek-mac`)
- Paid Apps Agreement signed (19/04/2026 – 19/04/2027)
- Tax forms submitted + active (W-8BEN + U.S. Foreign Status)
- DSA (EU Digital Services Act) declaration filed as trader via `TraditioneForAll, Lda`
- ASC version page filled: subtitle, description, keywords, promo, URLs, copyright, review notes
- App Privacy card published: 14× Data Not Collected + privacy URL
- Age rating: 4+; Categories: Utilities (primary) + Productivity (secondary)
- `notarytool` keychain profile saved: `AC_PASSWORD`
- **v1.0 uploaded to ASC → still in review.** Once it clears to Ready for Sale, upload `build/Splynek-MAS.xcarchive` (currently v1.3) as the update via Xcode Organizer. Don't upload before v1.0 clears — it would invalidate the review.

**MAS_LISTING.md** holds the full listing copy and screenshot plan.

---

## Dev override for Pro features

```sh
defaults write app.splynek.Splynek splynekDevProUnlocked -bool YES
# Relaunch the MAS build — Concierge + Recipes tabs go from PRO-locked to unlocked.
defaults delete app.splynek.Splynek splynekDevProUnlocked
```

Short-circuits StoreKit. See `splynek-pro/Sources/SplynekPro/LicenseManager.swift::devOverrideKey`. Note: `vm.aiAvailable` is its own thing — it's true when any backend (Apple Intelligence / Ollama / LM Studio) is detected, regardless of Pro status.

**D1 split invariants (v0.44+):**
- Free-tier `isPro = false` is compile-time-enforced — it's a
  stubbed class, not a runtime-toggled flag (MAS build excludes the
  stubs and links splynek-pro's real implementations).
- New Pro functionality lands in `Splynek/splynek-pro`, NOT in the
  public repo. If it needs to compile in the free build, the stub
  in `ProStubs.swift` must also gain a corresponding API-compatible
  no-op.
- Views gate Pro tabs at the sidebar level (not inside the body).

**Architectural invariant (v0.43+):** Do NOT put a top-level
conditional `if/else` that returns structurally different view
subtrees inside a `some View` body used as a `NavigationSplitView`
destination. macOS 14's split-view layout fails in a way that
requires full-restart recovery. Gate at the sidebar level instead
(show/hide the tab) or use a fully stable outer shape.

---

## Start-of-session ritual

1. `Read HANDOFF.md` (this file)
2. `Read README.md` (top 200 lines covers the latest few releases)
3. Check `git status` + `git log --oneline -10` in BOTH repos:
   - `/Users/pcgm/Claude Code` (public)
   - `/Users/pcgm/splynek-pro` (private; sibling checkout)
4. Check ASC submission state if the task is MAS-related:
   `gh api /repos/Splynek/splynek/pages/builds/latest --jq .status`
   (Pages state — not the same as ASC review state).
5. Ask the user what to build. Don't invent work — the
   **Natural next bites** section below has an ordered queue.

---

## Architecture invariants

Load-bearing; don't break them without explicit intent.

1. **Interface binding.** Every outbound data socket is pinned to a
   `NWInterface` via `NWParameters.requiredInterface` (Apple's
   wrapper for `IP_BOUND_IF`). DoH for each lane optionally goes
   through the same interface via `DoHResolver` (Cloudflare
   1.1.1.1, JSON format). Tracker announces for torrents use
   `HTTPTrackerOverNW` so tracker DNS obeys the interface too.
2. **Zero third-party Swift dependencies.** `Package.swift` has
   no external products. BitTorrent, DHT, DoH, Metalink XML, the
   test harness, the SVG rasteriser, PNG generation — all
   hand-rolled against Foundation, Network.framework, CryptoKit,
   AppKit, CoreImage.
3. **ViewModel owns shared mutable state.** `SplynekViewModel`
   (`@MainActor ObservableObject`) holds `activeJobs`,
   `sharedBuckets`, `queue`, `history`, `torrentProgress`, Pro state
   (via stubs or real impl), fleet integration, and preferences.
   Engines publish to it via `@Published`; engines never touch
   `DockBadge` or UI directly.
4. **Session state** lives in `~/Library/Application Support/Splynek/`
   (DMG build) or `~/Library/Containers/app.splynek.Splynek/Data/Library/Application Support/Splynek/` (MAS build):
   - `history.json` — completed downloads (last 500, with SHA-256)
   - `queue.json` — persistent URL queue
   - `session.json` — jobs + last torrent snapshot
   - `dht-routing.json` — 200 most-recent DHT good nodes
   - `host-usage.json` — per-host bytes-today tally
   - `cellular-budget.json` — cellular daily budget
   - `fleet.json` — CLI/Raycast/Alfred discovery descriptor (port + token)
   - `schedule.json` — global download schedule (window + weekdays) [Pro]
   - `recipes.json` — recent agentic recipes (capped at 20) [Pro]
   - `host-usage-history.json` — frozen daily snapshots (v0.37+)
   - `cellular-budget-history.json` — frozen daily cellular totals (v0.37+)
   - Per-download: `<output>.splynek` sidecar
5. **`splynek://` is the one ingress.** Drag-drop, Shortcuts,
   browser extensions, menu-bar popover, Chrome extension, CLI,
   web dashboard — they ALL construct `splynek://` URLs or call
   the REST API. No parallel ingress points.
6. **Build.sh builds only the `Splynek` product.**
   `swift build -c release --product Splynek`. Tests live at
   `swift run splynek-test`. Don't revert this — building the
   whole package under `-c release` fails (test target's
   `@testable import SplynekCore` requires debug) and the old
   script silently shipped stale binaries.
7. **Tests** self-hosted. `Tests/SplynekTests/` runs via
   `swift run splynek-test`. No XCTest, no Swift Testing — both
   are flaky on Command Line Tools without Xcode. 60-LOC
   assertion harness (`TestHarness.suite`/`test`, `expect`/
   `expectEqual`). 117 tests (post-v0.44 split; 48 Pro-tests moved
   to `splynek-pro/Tests/SplynekProTests/`).
8. **Release builds use the live icon.** Hero views in About +
   Downloads strip load `Splynek.icns` directly from
   `Bundle.main.resourceURL.appendingPathComponent("Splynek.icns")`,
   bypassing `NSApp.applicationIconImage` which on recent macOS
   wraps icons in a generic-app white frame when LaunchServices
   is stale.
9. **MAS build excludes stubs + includes splynek-pro.** In
   `project.yml`, the `Splynek-MAS` target's `sources:` has
   `Sources/SplynekCore` with `excludes: [ProStubs.swift, Views/ConciergeView.swift, Views/RecipeView.swift, Views/ProLockedView.swift]` AND adds `../splynek-pro/Sources/SplynekPro`. Compiling both into
   the same target module means the Pro types internal-import
   freely; no cross-module public-access refactor needed.
10. **Throughput calc clamps min-window to 0.5 s (v0.46).** In
    `DownloadEngine.swift::LaneStats.record()`. Prior 0.001 s
    clamp produced fantasy "5 GB/s" on the first chunk landing.
11. **NavigationSplitView detail panes on macOS 26 need belt +
    suspenders sizing.** `GeometryReader { geo in … .frame(width:
    geo.size.width, height: geo.size.height) }` is mandatory, not
    optional, whenever a detail view's inner `@ViewBuilder`
    produces branches with different intrinsic widths (e.g.
    empty-state ↔ ScrollView). `.frame(maxWidth: .infinity)` alone
    is NOT enough — it's the accept-ceiling, not the report-up
    value. Related: chat/transcript state belongs in its own
    ObservableObject, not on the root VM, so sibling re-renders
    don't collide on a layout change. `LanguageModelSession` must
    be created on `@MainActor` per WWDC25 session 286. Full story
    in [POSTMORTEM-Concierge-Blank.md](POSTMORTEM-Concierge-Blank.md) — v1.1
    shipped without any of these three protections and the
    Concierge blanked the whole window on first chip click.
12. **Sovereignty tab privacy contract.** `SovereigntyScanner` uses
    `FileManager.contentsOfDirectory` + `Bundle(url:)` against
    `/Applications`, `/Applications/Utilities`, and `~/Applications`.
    Sandbox-legal, no entitlements, no Spotlight daemon access. The
    privacy invariants are audited at the top of
    `Sources/SplynekCore/SovereigntyScanner.swift` — enumeration only
    (no content reads), stays on-device (no network), opt-in
    one-shot (no background scans, no persistence), filters system
    apps. **Do not add NSMetadataQuery, network calls, caching, or
    background scanning.** The tab is a statement of values; any
    code that breaks the audit trail undermines the statement.
    `SovereigntyCatalog` invariants: targets never use European /
    OSS origins; alternatives never use US / CN / RU. Enforce via
    the `Origin.isRecommendable` property.

---

## Package / target layout

```
Package.swift                         # SPM: Splynek + splynek-cli + splynek-test + SplynekCore library
project.yml                           # XcodeGen spec → Splynek.xcodeproj (DMG + MAS targets)
Splynek.xcodeproj                     # generated; gitignored
Scripts/
  build.sh                            # SPM → .app → codesign (ad-hoc by default)
  dmg.sh                              # .app → compressed .dmg
  build-mas.sh                        # xcodegen + xcodebuild archive → .xcarchive (MAS)
  export-options-mas.plist            # -exportArchive plist for MAS pkg
  integration-test.sh / .py           # local HTTP server + REST API test
Sources/Splynek/main.swift            # 3-line shim w/ canImport(SplynekCore) guard
Sources/splynek-cli/main.swift        # CLI talking to live app via REST
Sources/SplynekCore/
  Bootstrap.swift                     # entry wrapper
  SplynekApp.swift                    # @App, AppDelegate, dock menu, scheme
  ContentView.swift                   # thin wrapper → RootView
  ViewModel.swift                     # shared mutable state (~1300 LOC)
  DownloadJob.swift                   # per-download lifecycle + snapshot
  DownloadEngine.swift                # HTTP engine + LaneStats + DownloadProgress
                                      # + Phase enum (Probing→Done)
  LaneConnection.swift                # keep-alive HTTP/1.1 + DoH + 416 handling
  Probe.swift                         # URLSession HEAD / ranged-GET
  InterfaceDiscovery.swift            # getifaddrs × NWPathMonitor (+ iPhoneUSB detection v0.46)
  Models.swift                        # shared types (+ .iPhoneUSB Kind v0.46)
  ProStubs.swift                      # v0.44: free-tier stubs (MAS excludes these)
  Sanitize.swift Quarantine.swift GatekeeperVerify.swift
  DownloadHistory.swift DownloadQueue.swift SessionStore.swift
  DownloadRecipe.swift                # stub (real impl in splynek-pro)
  DownloadSchedule.swift              # stub (real impl in splynek-pro)
  MerkleTree.swift Metalink.swift DoHResolver.swift LANPeer.swift
  Notifications.swift DockBadge.swift MenuBarController.swift
  GlobalHotkey.swift                  # #if !MAS_BUILD guarded
  UpdateChecker.swift                 # #if !MAS_BUILD guarded
  CurlExport.swift
  AppIntentsProvider.swift            # 7 intents: Download / Queue / Magnet /
                                      # GetProgress / CancelAll / PauseAll /
                                      # ListRecentHistory
  SplynekSpotlight.swift              # CoreSpotlight history indexing
  BenchmarkRunner.swift               # sequential single vs multi probe
  BenchmarkImage.swift                # shareable OG-size PNG
  FleetCoordinator.swift              # Bonjour + REST API server
                                      # (/status /fetch /content /api/* /ui*)
  WebDashboard.swift                  # embedded HTML dashboard
  OpenAPI.swift                       # embedded OpenAPI 3.1 spec
  QRCode.swift                        # CIQRCodeGenerator wrapper
  AIAssistant.swift                   # stub (real impl in splynek-pro)
  Enrichment.swift                    # sibling HEAD probes + duplicate match
  CellularBudget.swift HostUsage.swift
  BackgroundMode.swift                # menu-bar-only + login-item (SMAppService)
  WatchedFolder.swift                 # folder-drop ingestion (v0.34)
  UsageCSV.swift UsageTimeline.swift  # exports + chart data (v0.37/v0.38)
  Torrent/
    Bencode.swift TorrentFile.swift TorrentV2Verify.swift MagnetLink.swift
    TrackerClient.swift HTTPTrackerOverNW.swift UDPTracker.swift
    TorrentWriter.swift PeerWire.swift DHT.swift DHTServer.swift
    SeedingService.swift TorrentEngine.swift
    PieceVerifier.swift TorrentResume.swift  # v0.40 resume
  Views/
    RootView.swift Sidebar.swift
    DownloadView.swift TorrentView.swift QueueView.swift
    HistoryView.swift HistoryDetailSheet.swift
    FleetView.swift BenchmarkView.swift LiveView.swift
    ConciergeView.swift RecipeView.swift ProLockedView.swift  # STUBS — MAS excludes these
    SettingsView.swift LegalView.swift AboutView.swift
    UsageTimelineView.swift
    Components.swift InterfaceComponents.swift ThroughputChartView.swift
Tests/SplynekTests/
  Harness.swift main.swift (117 tests; 48 moved to splynek-pro v0.44)
Resources/
  Info.plist                          # scheme, doc types, CFBundleIconFile
  Splynek.icns                        # canonical app icon (from SVG)
  Splynek.entitlements                # DMG target's optional sandbox
  Splynek-MAS.entitlements            # v0.45 MAS sandbox + network.server + IAP
  Splynek.storekit                    # v0.45 local StoreKit test config
  Generated-Info.plist                # xcodegen output (gitignored)
  Generated-Info-MAS.plist            # xcodegen output (gitignored)
  Legal/
    EULA.md PRIVACY.md AUP.md         # bundled for offline viewing in LegalView
Packaging/
  splynek.rb                          # Homebrew cask template
Extensions/
  Chrome/                             # Manifest V3 extension
  Safari/bookmarklets.html            # drag-to-bookmarks-bar page
  Raycast/                            # TypeScript extension
  Alfred/Splynek.alfredworkflow/      # info.plist (w/ CFBundleIdentifier for MAS) + splynek.sh
Branding/
  Splynek-logo.svg                    # canonical vector source (user-designed)
  rasterize.swift generate_logo.py
  Splynek.icns icon.iconset/ flat/
docs/
  index.html                          # GitHub Pages landing
  pro.html                            # v0.45 Pro tier landing
  support.html                        # v0.45 support page
  privacy.html                        # v0.45 privacy policy (ASC-required)
  icon-256.png icon-1024.png
  CNAME                               # splynek.app binding
LICENSE                               # MIT
CONTRIBUTING.md                       # onramp + invariants + style
SHOW_HN.md                            # launch-post draft + pre-seeded replies
LANDING.md                            # long-form landing copy (pre-docs/)
MONETIZATION.md                       # tiers, pricing, distribution
SECURITY.md                           # threat model + controls (v0.28)
DESIGN_BRIEF.md                       # logo design spec (pre user SVG)
MAS_LISTING.md                        # v0.45 paste-ready App Store Connect material
CHANGELOG.md                          # condensed per-release log
.gitignore
```

Adjacent private repo layout (checkout at `../splynek-pro`):
```
splynek-pro/
  Package.swift                       # library target SplynekPro
  Sources/SplynekPro/
    LicenseManager.swift              # StoreKit 2 (v0.45+) + dev override (v0.47)
    AIAssistant.swift                 # Ollama client (real impl)
    AIConcierge.swift
    DownloadRecipe.swift
    DownloadSchedule.swift
    Views/ConciergeView.swift
    Views/RecipeView.swift
    Views/ProLockedView.swift         # real paywall UI
  Tests/SplynekProTests/              # 48 tests moved from public repo
  Scripts/gen-license.py              # obsolete HMAC issuer (kept for archaeology)
  SANDBOX_AUDIT.md                    # v0.44 MAS sandbox migration notes
```

---

## Declined items (engineering reasons)

- **uTP (BEP 29)** — LEDBAT congestion control, days of work, marginal value
- **MSE encryption** — weak RC4 key exchange, low ROI in 2026
- **HTTP/3 / QUIC** — `NWProtocolQUIC` public API too limited; QPACK
  implementation is weeks of work
- **Reed-Solomon erasure coding** — 20% bandwidth tax, solves a problem
  we don't have given origin servers always have full content
- **Public fleet / global P2P cache** — legal + moderation + operational
  exposure (DMCA, CSAM reporting, infrastructure). See SECURITY.md
  and MONETIZATION.md for the full argument.

## Apple Developer Program — DONE

Previously listed as "blocked on €99 spend." As of the v0.46 session
the full enrolment is complete; Team ID `58C6YC5GB5`, Paid Apps
Agreement active, tax forms submitted, ASC app record created, builds
uploaded. Notarisation + MAS distribution are unlocked. Safari App
Extension (.appex) and Apple Watch complication are still open as
future work — not blocked, just not prioritised.

---

## Natural next bites (ordered queue)

### A — Ship v1.3 to the MAS when v1.0 clears review

The MAS pipeline is locked; only the state transition is blocking.
1. Monitor App Store Connect for v1.0 → Ready for Sale (or rejection).
2. When it clears: open `/Users/pcgm/Claude Code/build/Splynek-MAS.xcarchive` in Xcode Organizer → Distribute App → App Store Connect → Upload.
3. On ASC version page: update Versão to `1.3`, attach build `1.3 (1300)`, click Submit.
4. If Apple rejects v1.0, iterate on review notes (they already pre-address network.server, Ollama, BitTorrent); resubmit with v1.3 once resolved.

### B — Sovereignty catalog growth (community + manual)

v1.4 shipped the JSON-backed pipeline and took the catalog from 90 → 869 entries. Further growth is now mostly a data-curation exercise, not a code exercise.
- **Continue bulk imports** via `Scripts/seed-sovereignty-bulk.swift`. Easiest wins: mine [european-alternatives.eu](https://european-alternatives.eu/), [switching.software](https://switching.software/) (CC-BY), [awesome-euro-tech](https://github.com/) lists. Script is idempotent — re-running skips existing bundle IDs.
- **More `downloadURL`s** for popular alternatives that have stable canonical URLs. Firefox + Thunderbird currently work via Mozilla's redirect. Research: Signal, VLC, Bitwarden's desktop-download redirect, LibreOffice stable mirror. One afternoon of careful URL-verification per batch — prone to 404 rot if the author isn't careful.
- **Accuracy passes** — some v1.4 bulk entries have best-guess bundle IDs. High-value regression: an installed-apps scan on several real Macs, note which expected entries don't match, correct the bundle ID in JSON, regenerate. That's how the catalog goes from "comprehensive by count" to "comprehensive by hit-rate."
- **Invariants are test-enforced** (`SovereigntyCatalogTests`): every target is non-EU, every alternative is .europe/.oss/.europeAndOSS/.other (never US/CN/RU), every entry has ≥1 recommendable pick, IDs unique, catalog ≥ 500 entries (regression floor).

### C — Sovereignty AI-fallback prompt tuning (v1.4 pass shipped — future work optional)

v1.4 shipped a FORBIDDEN PATTERNS block in the system prompt + a `sovereigntyDenyList` post-filter (in `splynek-pro/AIAssistant.swift`) that strips known US/CN/RU products from model output. Future improvements if the 3B model still misbehaves:
- **A/B test**: adapt the `/tmp/concierge-ab/` harness for the sovereignty prompt and measure deny-list hit-rates across prompt variants.
- **Homepage TLD check**: reject suggestions whose homepage host resolves to a US-registered domain. Brittle (CloudFlare / CDN hosts confuse this); parking it.
- **Extend the deny-list** with new mis-suggestions as they surface in production. The deny-list is intentionally short and high-signal — false positives drop legit suggestions silently.

### D — Localisation (v1.4 shipped FR/DE/ES/IT for Sovereignty; roll out to rest)

Sovereignty tab fully localised as of v1.4 (`Sources/SplynekCore/Localizable.xcstrings`, ~30 strings × 4 languages). Pattern to extend:
- **Next tab**: Concierge. `Sources/SplynekCore/Views/ConciergeView.swift` has ~40 localisable strings. Same xcstrings file, same `LocalizedStringKey` pattern.
- **After that**: Recipes, Downloads, Sidebar (tab names), Settings. ~200 strings total.
- **Native-speaker review**: current translations are Claude-generated. Before major marketing push, flag FR + DE for a native-speaker pass — those are the two markets where Sovereignty has the biggest credibility lift.
- **Arabic / ZH-HANS?** Only if Pro uptake in those markets warrants it. Not a priority.

### E — Monetization / marketing (unchanged from prior sessions)

- **Stripe + Postmark direct channel** — dual-channel revenue (see MONETIZATION.md). Not blocked; not started.
- **Show HN** — draft at `SHOW_HN.md`. Best done after MAS goes live. Rewrite around the Sovereignty angle: "Splynek — a Mac download manager that also helps you audit your software supply chain. All local, all private."
- **Product Hunt** — same timing.
- **Homebrew cask** — `Packaging/splynek.rb` is source-of-truth. v1.5.3 SHA: `4fe61bab5ee2eb847d789c7f8b2245bf6b180936ec231241284f20b968c0e6cb`. Two distribution paths:
  - **Splynek tap** ([github.com/Splynek/homebrew-splynek](https://github.com/Splynek/homebrew-splynek)) — live now. Install: `brew install --cask Splynek/splynek/splynek`. Bump for each release: clone the tap, copy the new `Packaging/splynek.rb` over `Casks/splynek.rb`, commit + push.
  - **Upstream homebrew/cask** — first submission (PR #261294, 2026-04-26) auto-rejected by `khipp` on notability heuristic (need ≥75 stars OR ≥30 forks OR ≥30 watchers; we had 0/0/0). Resubmit after MAS launch + Show HN coverage push the upstream repo across the bar. Reuse `Packaging/splynek.rb` placed at `Casks/s/splynek.rb` in a `homebrew-cask` fork.
- **EU press outreach** — Le Monde (FR), El País (ES), Der Spiegel (DE), Wired, FT. Hook: Sovereignty-tab scan video shot on a stock Mac. Co-ordinate with any MAS approval date to avoid review disruption.

### F — Future platform bets (scoped in STRATEGY-2026.md)

- **S2 — Unbreakable Resume** (HTTP Range + NWPathMonitor + curated mirror failover). Multi-week.
- **S5 — Splynek Accelerator** (browser extension + HLS pre-buffer). Multi-week.
- **iOS Companion** — Share Extension + Live Activity. Multi-week.

See [STRATEGY-2026.md](STRATEGY-2026.md) for the full frontier-memo.
Sovereignty itself was not in STRATEGY-2026.md's original six bets —
it emerged as a v1.2 side-bet after the user's framing-shift
conversation and turned out to be the most differentiating feature
Splynek now ships. Worth a strategic re-read.

---

## Working conventions

- Each feature pass ends with a `## What's new in v0.N` README
  section at the top of the reverse-chronological log.
- Build is verified with three paths:
  - `./Scripts/build.sh` → SPM DMG
  - `xcodebuild -project Splynek.xcodeproj -scheme Splynek build` → DMG via Xcode
  - `xcodebuild -project Splynek.xcodeproj -scheme Splynek-MAS build` → MAS
  - Plus `swift run splynek-test` (117 green).
- MAS archive + notarise verified before shipping an update:
  `./Scripts/build-mas.sh` for MAS + the Developer-ID flow above for DMG.
- Warnings treated as errors — aim for zero before shipping.
- `@MainActor` isolation is consistent; cross-actor work happens
  via `Task { @MainActor in … }` or explicit actor hops.
- SwiftUI views are ~200–700 LOC each, broken into Section cards
  backed by `TitledCard` + `StatusPill` + `MetricView` + `PageHeader`
  from `Views/Components.swift`.
- Swift 6 concurrency warnings are actively cleaned up — don't
  introduce captured-var mutations or non-Sendable closures.
- Commit messages: imperative, short, explain *why* over *what*.
  Co-authored-by tag reserved for actual human contributors, not
  tooling.
- Version bumps: update `project.yml` (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`) AND `Extensions/Alfred/Splynek.alfredworkflow/info.plist` (`CFBundleShortVersionString`) together. XcodeGen regenerates `Resources/Generated-Info*.plist` from the `project.yml`.

---

## If something looks off

- **App icon shows a generic white frame.** LaunchServices icon
  cache is stale. `killall Dock` after `lsregister -f build/Splynek.app`.
- **build/Splynek.app is outdated after a source change.** Check
  that `./Scripts/build.sh` used `--product Splynek` (it does since
  v0.27; see invariant #6).
- **Tests silently don't run.** Touch `Tests/SplynekTests/main.swift`
  to force SPM to rebuild the test target.
- **fleet.json not appearing in release builds.** Release-optimiser
  had a history of eliding the `stateUpdateHandler` callback.
  Fixed in v0.27 by calling `persistDescriptor()` from every VM
  `publishFleetState()` tick AND the listener-ready hook.
- **`Image(systemName:)` with `.foregroundStyle(.accentColor)`
  fails to compile.** Use `Color.accentColor` instead — the
  `ShapeStyle` case-access only works for some SF-symbol sites.
- **Xcode archive fails with "No Accounts".** Apple ID isn't in
  Xcode → Settings → Accounts. Re-add it; automatic signing picks
  up from there.
- **`xcodebuild archive` fails with "conflicting provisioning
  settings".** `project.yml` has `CODE_SIGN_IDENTITY` set manually
  but `CODE_SIGN_STYLE: Automatic`. Remove the identity override
  (automatic signing picks Apple Development for build, Apple
  Distribution for archive).
- **`altool --upload-package` says "Failed to find item
  AC_PASSWORD".** Expected — `altool` and `notarytool` use
  different keychain formats. Use Xcode Organizer's Upload button
  instead (signs in via Xcode's signed-in Apple ID directly), or
  set up an App Store Connect API Key (.p8) and use JWT auth.
- **Throughput briefly reads 0 MB/s after starting.** v0.46 clamps
  the sample window to 500 ms minimum to prevent 5 GB/s spikes;
  during the first 500 ms the reported throughput under-reads by
  up to 2× before converging. Intentional; don't "fix" by dropping
  the clamp.
- **MAS build Assistant + Recipes tabs missing.** Either (a)
  `splynekDevProUnlocked` isn't set (flip it with
  `defaults write app.splynek.Splynek splynekDevProUnlocked -bool YES`),
  or (b) the real StoreKit purchase hasn't completed / isn't
  visible — check `Transaction.currentEntitlements` with
  `xcrun storekit-test`.
- **iPhone tether shows as ETH instead of iPhone.** v0.46 fix
  relies on the 172.20.10.0/28 IP range. If the iPhone hands out
  a different range (rare), the detection misses. Extend the
  condition in `InterfaceDiscovery.swift` near the `// v0.46:
  iPhone USB Personal Hotspot` marker.
