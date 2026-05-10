# SMOKE-TEST sign-off — 2026-05-10

> Reference: `SMOKE-TEST-RUNBOOK.md`
> Branch: `rollup/2026-05-08` at commit `f7758bd`
> Run by: Claude Code session (programmatic checks only —
> manual UI/UX checks remain pending the maintainer)

This file records the partial sign-off for the smoke-test
runbook.  Items in **PROGRAMMATIC** sections were verified from
this Claude Code session via build / test / xcodebuild / audit
commands.  Items in **MANUAL** sections require the maintainer
on real hardware (Mac UI clicks, paired iPhone, Watch
hardware, Raycast app installed, geo-fence walking outside).

---

## ✅ Section 11 — Build sanity (PROGRAMMATIC, all green)

- [x] **`swift build`** clean — `Build complete! (0.13s)`, 0 errors, 0 warnings against the cached DerivedData (a fresh-DerivedData rebuild was last verified 2026-05-08 and noted in HANDOFF).
- [x] **`swift run splynek-test`** → **820/820 tests pass.** No regression vs Sprint 5 baseline.
- [x] **`xcodebuild -scheme SplynekCompanion CODE_SIGNING_ALLOWED=NO build`** → **BUILD SUCCEEDED.** iOS Companion + Share Extension + Widgets all compile.
- [ ] **`xcodebuild -scheme SplynekWatch CODE_SIGNING_ALLOWED=NO build`** → **MAINTAINER**: requires watchOS SDK install (Xcode → Settings → Components → watchOS).  Reproducer is in `aec950d`'s commit message.
- [x] **`python3 Scripts/find-missing-translations.py`** → **25 missing across 9 files**, 812 catalog strings.  Down from 79 pre-Sprint-1; targeted for L10n round 4 (Sprint 7).
- [x] **`python3 Scripts/regenerate-localizations.py`** → **812/812 across all 5 locales (de/es/fr/it/pt-PT) at 100%**.  Catalog regen is deterministic.

---

## ✅ Section ad-hoc — Sprint 5/6 client extensions (PROGRAMMATIC)

- [x] **CLI bash wrapper** (`Extensions/CLI/bin/splynek`): `bash -n` syntax check passes.  `splynek help` runs and prints expected usage.
- [x] **Raycast extension** files present (`Extensions/Raycast/splynek/src/`): all 6 `.ts` / `.tsx` files exist (api.ts, submit-url.tsx, active-downloads.tsx, sovereignty-score.tsx, pause-all.tsx, resume-all.tsx).  `package.json` declares 5 commands.  Compile-verify pending `npm install` on a Raycast-enabled Mac (maintainer step — `cd Extensions/Raycast/splynek && npm install && npm run dev`).

---

## ⏳ Section 1 — Mac Trust Watcher (MANUAL)

- [ ] Pro license active.  **Maintainer**: requires StoreKit purchase or DMG-signed dev license.
- [ ] Trust Watcher card visible at top of TrustView with `WATCHING N` pill.
- [ ] **Run now** → sweep + alerts.
- [ ] Per-alert View page / Dismiss / Clear all interactions.
- [ ] Pro toggle ↔ free flips card to ProLockedView and back.

> **Why we can't verify this from a Claude session**: Pro features are gated on `vm.license.isPro` which requires StoreKit-validated receipt.  Visual confirmation requires the Mac app running with a paid license.

## ⏳ Section 2 — Mac Sovereignty Migrate Wizard (MANUAL)

- [ ] Per-alternative Migrate button shows on rows.
- [ ] Wizard sheet step-by-step with `confirmationPrompt` alerts.
- [ ] **Mark for review** writes to `~/Library/Application Support/Splynek/migrate-review-list.json`.
- [ ] After 7 days, Sovereignty review banner surfaces stale entries.

> **Programmatic spot-check**: I confirmed the disk path + JSON shape via `SovereigntyMigrateReviewList` round-trip tests (see `SovereigntyMigrateReviewListTests.swift`).  The 6 tests cover insert / dedup / remove / `entriesOlderThan(days:)` / disk store. Visual confirmation of the banner appearing requires real Mac time-passage or manual JSON injection.

## ⏳ Section 3 — Mac Concierge migrate digest (MANUAL)

- [ ] Concierge prompt → picks `migrate_review_digest` tool.
- [ ] `.text` card shows count + names + stale-week nudge.

> **Programmatic spot-check**: 4 tests in `ConciergeMigrateDigestTests.swift` cover empty-list / populated-list / stale-trigger / tool-registry-presence.  Live LLM invocation is in splynek-pro (private repo).

## ⏳ Section 4 — Mac pricing telemetry + Trust+ upsell (MANUAL)

- [ ] Engagement viewer card shows three groups with non-zero counters after smoke runs.
- [ ] **Show JSON file** opens Finder to `engagement.json`.
- [ ] Trust+ upsell appears only when `EngagementGate.shouldOfferTrustPlus` fires (≥20 events).

> **Programmatic spot-check**: 7 tests in `EngagementCountersTests.swift` cover gate threshold + Migrate-counters-don't-trigger-Trust+ + disk round-trip + sticky firstRecordedAt.

## ⏳ Section 5 — Mac API tokens (MANUAL)

- [ ] Mint / Show / Copy / Revoke flows.
- [ ] Read-only token returns 401 on POST endpoints.
- [ ] `curl` against the running Mac listener with the minted token returns 200.

> **Programmatic spot-check**: 12 tests in `APITokenTests.swift` cover secret generation / scope / store mutation / validator decision branches / disk round-trip.  Real curl-against-running-Mac requires the app launched with networking enabled.

## ⏳ Section 6 — iPhone Companion (MANUAL — paired iPhone required)

- [ ] Insights tab renders 4 cards.
- [ ] Pull-to-refresh.
- [ ] Hey Siri intents fire.
- [ ] Home-screen Widget renders.
- [ ] Geo-fence enables + locks home + pauses on physical exit.
- [ ] PairingSheet token-section copy ranks API tokens above session tokens.

> **Programmatic spot-check**: iOS xcodebuild SUCCEEDED.  `RelaySummary` types pass Codable round-trip tests.  PairingSheet copy change is a one-file diff visually verifiable in the source (`iOS/SplynekCompanion/PairingSheet.swift`).

## ⏳ Section 7 — iPhone push notifications (MANUAL — CloudKit + iPhone required)

- [ ] CloudKit container `iCloud.app.splynek.companion` provisioned.
- [ ] Schema `SplynekTrustWatchAlert` promoted to Production.
- [ ] iPhone receives UNNotification on Mac-side trigger.

> **Maintainer-only**: depends on Apple Developer Program access + CloudKit Dashboard schema work.  See HANDOFF.md "remaining work" section.

## ⏳ Section 8 — Apple Watch (MANUAL — paired Watch required)

- [ ] Watch app reads paired Mac from App Group plist.
- [ ] Pause / Resume haptic on success.
- [ ] Sovereignty score row.
- [ ] Watch-face complications: 3 families render.

> **Maintainer-only**: requires watchOS SDK install + paired hardware.  Code is committed in `aec950d` + `85d6e4f` (complications target).

## ⏳ Section 9 — Raycast extension (MANUAL — Raycast app required)

- [ ] Raycast preferences accept host/port/API token.
- [ ] All 5 commands work against a running Mac.
- [ ] Read-only token returns 401 on Submit / Pause / Resume.

> **Programmatic spot-check**: `package.json` + 6 source files all present.  TypeScript compile-verify pending `npm install + npm run dev` on a Raycast-enabled Mac.

## ⏳ Section 10 — Settings Decentralization sanity (MANUAL — visual)

- [ ] Confiança weights DisclosureGroup at top.
- [ ] Fila schedule + watched-folder cards.
- [ ] Frota household swarm token + security card.
- [ ] Agentes web dashboard + iPhone pairing QR.
- [ ] Sidebar brand footer at bottom.

> **Programmatic spot-check**: every relocation is a single source-file diff visible in commits `57fb6cb` / `b494a2b` / `f944b09` / `52e9249` / `2b3a87f`.  Each card's `fileprivate` extension is grep-verifiable.

---

## Sign-off

| What | Status |
|---|---|
| Programmatic checks (build + test + iOS xcodebuild + audit + regen + ext-files) | **✅ PASS** |
| MANUAL checks (UI/UX, Pro license, paired iPhone, Watch, Raycast, geo-fence, push) | **⏳ PENDING** |
| Maintainer-only out-of-band steps (CloudKit, watchOS SDK, Provisioning, Stripe, MAS review) | **⏳ PENDING** |

**Programmatic verdict**: every check that doesn't require a
running Mac UI or paired hardware is green.  No regressions
vs Sprint 5 baseline.  Build + tests pass; iOS compiles; CLI
script runs; Raycast files present; catalog at 100% across
5 locales.

**Tag readiness**: NOT YET READY to tag v2.0.0 from a Claude
session — the manual sections above + maintainer steps must
walk first.  Once the maintainer ticks the manual boxes, this
file (or its successor) can flip the sign-off to APPROVED.

**Suggested next steps for the maintainer**:

1. Install watchOS SDK + verify SplynekWatch + SplynekWatchComplications builds.
2. Provision CloudKit `SplynekTrustWatchAlert` schema in App Store Connect → CloudKit Dashboard.
3. Boot the Mac app + walk Sections 1-5 of the runbook + tick the boxes.
4. Pair the iPhone + walk Sections 6-7 (push will silently no-op until step 2 lands; that's fine — local UI still works).
5. (Optional) Pair Watch + walk Section 8.
6. (Optional) Install Raycast + run `npm install + npm run dev` in `Extensions/Raycast/splynek/` + walk Section 9.
7. Once 1-5 (minimum) tick: tag `v2.0.0` from `rollup/2026-05-08` and proceed with the LANDING-V2-DRAFT publish gating in the press kit.

---

## Files of record

- `SMOKE-TEST-RUNBOOK.md` — the runbook itself (Sprint 5)
- `SMOKE-TEST-SIGNOFF-2026-05-10.md` — this file (Sprint 7)
- `LANDING-V2-DRAFT.md` — announcement copy gated on full sign-off (Sprint 6)
- `STRATEGY-2026-PRO-PLUS-IPHONE.md` — strategic context (Sprint 1)
- `HANDOFF.md` — overall handoff state
- `SESSION-LOG.md` — per-commit narrative

> **If a future Claude session re-runs the programmatic
> checks and they fail**: do NOT remove this file.  Add a new
> dated sign-off file alongside it (`SMOKE-TEST-SIGNOFF-YYYY-MM-DD.md`)
> so the audit trail compounds rather than overwriting.
