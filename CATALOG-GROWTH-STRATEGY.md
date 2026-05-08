# Splynek catalog growth strategy

> Why three catalogs (Sovereignty, Trust, AppPricing) keep struggling
> with coverage, and the eight tactics we're shipping to fix it.
>
> Last updated 2026-05-08.

## The problem

Splynek's three "Ask" tabs depend on hand-curated data:

| Catalog              | 2026-05-08 size | Mac App Store size |
|----------------------|-----------------|--------------------|
| `SovereigntyCatalog` | 1,155 entries   | ~30,000            |
| `TrustCatalog`       | 151 entries     | ~30,000            |
| `AppPricing`         | 119 paid apps   | ~5,000 paid        |

A typical Mac has 100–300 installed apps, of which only ~50% land
in our hand-curated tables.  The other 50% used to silently
disappear from Sovereignty, Trust, and Savings.  Hand curation
cannot scale with the long tail.

## The eight tactics

### #1 Categorical fallback (shipped 2026-05-08)

**File**: `Sources/SplynekCore/SovereigntyCategoryChampions.swift`

When a specific bundleID isn't in the catalog, fall back to
"free champions" for the app's `LSApplicationCategoryType`.

- LibreOffice / OnlyOffice / Joplin for `productivity`
- GIMP / Inkscape / Krita for `graphics-design`
- HandBrake / OBS / DaVinci Resolve for `video`
- KeePassXC / Bitwarden for password categories
- Audacity / Strawberry for `music`
- darktable / RawTherapee / GIMP for `photography`
- VSCode / VSCodium / Zed for `developer-tools`
- VLC / IINA for `entertainment`
- Signal / Element for `social-networking`

**Result**: coverage jumps from ~50% → ~95% without curating
each bundleID individually.  Each champion list is 3–5 entries
to avoid choice paralysis.

### #5 + #8 "Contribute this app" + "We don't know yet" (shipped 2026-05-08)

**File**: `Sources/SplynekCore/Views/SovereigntyView.swift`

Apps that have neither a specific entry nor a category match
land in a new disclosure section "Apps we don't know yet".  Each
row carries a one-click `Contribute` button that opens a GitHub
issue with the app's metadata pre-filled (bundleID, name,
version, category, link to the homepage to fill in).  Crowdsource
the long tail at the moment of friction.

Makes the gap **visible** AND **actionable** instead of silently
hiding apps we can't classify.

### #2 Homebrew Cask bulk import (script shipped 2026-05-08)

**File**: `Scripts/import-from-homebrew-cask.py`

Homebrew's [`homebrew-cask`](https://github.com/Homebrew/homebrew-cask)
repository has structured metadata for ~7,000 Mac apps:

- `name`, `homepage`, `version`, `url`, `sha256`
- License (when declared)
- App artifact name (helps guess CFBundleIdentifier)

The script clones the cask repo, parses each `.rb` file via
regex, and emits `Scripts/cask-import.json` — a structured
intermediate the catalog regenerator can fold into
`SovereigntyCatalog+CaskImported.swift`.

**Result**: catalog grows ~5×.  Spot-check the top-50 by
popularity before merging.  Future: weekly GitHub Action that
re-runs + opens auto-PR.

### #4 App Store privacy labels scraper (script shipped 2026-05-08)

**File**: `Scripts/scrape-app-store-privacy-labels.py`

Apple publishes privacy labels for every Mac App Store app in
publicly-readable HTML at `apps.apple.com/<region>/app/.../id<adamID>`.
The labels cite:

- Data Used to Track You (→ `TrustCatalog.Concern.Kind.appStoreTrackingData`)
- Data Linked to You (→ `appStoreLinkedData`)
- Data Not Linked to You (→ `appStoreUnlinkedData`)

Scraping these is straightforward: each app's page has a
`<script type="application/ld+json">` block + a
`<script id="shoebox-app-...">` JSON island with the structured
privacy disclosures.  Map to TrustCatalog concerns; cite Apple's
own page as primary source (which is exactly what the catalog
requires).

**Result**: TrustCatalog grows from 151 → ~5,000 entries in one
batch with primary-source citations.  Limitations: labels are
self-disclosed by developers; some are obviously inaccurate.
Manual review still matters.

### #7 Wikidata SPARQL enrichment (script shipped 2026-05-08)

**File**: `Scripts/wikidata-sovereignty-enrich.py`

Wikidata has structured infoboxes for tens of thousands of
software entries.  Properties of interest:

- `P176` manufacturer
- `P178` developer
- `P17` country (origin)
- `P275` license

A SPARQL query against `query.wikidata.org/sparql` returns
country + license for any software item.  Map country Q-IDs to
`SovereigntyCatalog.Origin` (Q183 Germany → europe; Q30 USA →
unitedStates; etc.).

**Result**: ~20–30% match rate against typical Mac apps —
modest but free coverage.  Best run as an enrichment pass over
the cask-import output (those entries already have the canonical
homepage URL Wikidata can match against).

### #3 AI-suggested entries (foundation 2026-05-08)

**Existing**: `SovereigntyView.uncatalogedSection` (Pro-gated)
already pipes uncatalogued bundleIDs through the local LLM
(LM Studio / Ollama) to generate suggestions on demand.

**Future improvements**:

- **Persistence**: cache AI suggestions to `~/Library/Application
  Support/Splynek/ai-catalog-suggestions.json` so the user's
  next launch sees the suggestions immediately (no re-prompt).
- **Badge**: render AI-suggested rows with an explicit "AI ·
  not yet verified" pill; visually distinct from hand-curated
  catalog entries so the user knows what they're looking at.
- **Confirm + open PR**: add a "Confirm" button that opens a
  GitHub PR with the AI-suggested entry pre-filled.  Closes the
  loop: every Pro user becomes a catalog contributor without
  doing any extra work.

The infrastructure for the live LLM call exists in `splynek-pro`;
the persistence + badge + PR-flow are the next iteration.

### #6 Federated popularity census (foundation 2026-05-08)

**File**: `Sources/SplynekCore/Fleet/PopularityCensus.swift`

Splynek already has Fleet (Mac-to-Mac LAN announcements).
PopularityCensus extends the protocol with anonymous bundleID
hashes — every record is the SHA-256 prefix of the bundleID
(96 bits, collision-safe for low-millions-distinct), the version
hash, and the LSApplicationCategoryType.  No bundleID in plain
text leaves the LAN.

**Result**: a Splynek peer can SUBSCRIBE to the LAN's census,
accumulating the union of hashes seen by all peers on the same
network.  Sample-of-one becomes sample-of-many.  A future
opt-in publishing flow lets the catalog maintainers see "these
50 hashes are most common but not in the catalog → curate next."

The foundation is shipped; the announcement protocol + Settings
toggle land when the rest of Fleet's privacy-mode flag is
extended to cover the census.

## Coverage timeline

| Catalog              | 2026-05-08 | After #1 (today) | After #2 + #4 (week 1) | After #6 (steady-state) |
|----------------------|------------|-------------------|------------------------|-------------------------|
| Sovereignty (specific)| 1,155     | 1,155             | ~6,000                 | ~6,000 + ongoing        |
| Sovereignty (cat)    | 0          | ~95% of installed | ~95% of installed      | ~95% of installed       |
| Trust                | 151        | 151               | ~5,000                 | ~5,000 + ongoing        |
| AppPricing           | 119        | 119               | ~119 (no Cask price)   | revisit per #4 + #7     |

## Operational principles

1. **Coverage > polish.**  Better to have an entry with "country
   inferred from Wikidata, license unknown" than no entry.  We
   can refine; we can't conjure data.
2. **Cite primary sources.**  Every Trust concern carries an
   `evidence_url`.  AI-generated suggestions are explicitly
   badged so the user can distinguish.
3. **Crowdsource visibly.**  Every contribution path opens a
   pre-filled GitHub issue / PR — the user sees what they're
   sending.  No silent telemetry.
4. **Maintainer review at the merge.**  Auto-PRs from cron + AI
   suggestions are PROPOSED, not merged.  Maintainer reviews
   batch.  Quality stays high; throughput stays high.

## Status legend

| Symbol | Meaning |
|---|---|
| ✅ | Shipped in main, working |
| 🚧 | Foundation shipped, runtime gated |
| 📅 | Script shipped, needs cron infra |

| # | Tactic | Status |
|---|---|---|
| #1 | Categorical fallback | ✅ |
| #2 | Homebrew Cask import | ✅ (4,088 hints live as JSON resource since 2026-05-08 evening) |
| #3 | AI-suggested entries | 🚧 |
| #4 | App Store privacy labels | 📅 |
| #5 | Contribute button | ✅ |
| #6 | Federated popularity census | 🚧 |
| #7 | Wikidata SPARQL | 📅 |
| #8 | "We don't know yet" graceful state | ✅ |

## Picking up this work in a future session

Read `SESSION-LOG.md → 2026-05-08 evening` first — it's the
narrative companion to this strategic doc.  Then walk this list,
top to bottom:

### Quick wins (≤ 1 hour each)

1. **Refresh the cask snapshot.**  Homebrew Cask gets ~50
   PRs / week.  Re-run the pipeline to pick up new apps:

       cd "/Users/pcgm/Claude Code"
       cd /tmp/cask && git pull --depth 1 origin master && cd -
       python3 Scripts/import-from-homebrew-cask.py /tmp/cask
       python3 Scripts/emit-cask-swift.py
       swift build && swift run splynek-test

   Expect `Sources/SplynekCore/Resources/cask-hints.json` to
   grow by ~50-100 entries per refresh.

2. **Promote OSS-confirmed cask entries to first-class
   Sovereignty.**  Filter `cask-hints.json` to entries whose
   `cask_token` matches a known-OSS allowlist (extracted from
   the `license:` field in the original cask Ruby — needs an
   import-script extension to capture it; currently dropped).
   Then emit a `SovereigntyCatalog+CaskOSS.swift` that registers
   those entries as real `SovereigntyCatalog.Entry` instances
   with `targetOrigin = .oss`.

3. **Run #4 (privacy labels) against installed apps.**  The
   skeleton in `Scripts/scrape-app-store-privacy-labels.py`
   needs the network calls fleshed out.  Input list = the union
   of:

   - `cask-hints.json` entries with adamID-resolvable bundle IDs
   - Apps from a typical Mac scan (Settings → Sovereignty →
     Export CSV)

   First batch: 500 apps × ~3 sec/lookup × retries = ~30 min
   wall time.  Output: a TrustCatalog augmentation JSON; merge
   manually after spot-checking.

4. **Run #7 (Wikidata) against the same set.**  Network-bound,
   ~30 min for 500 apps.  Output: origin/license enrichment.

### Bigger pieces (≥ 1 day each)

5. **AI-suggested entries with persistence + PR flow** (#3).
   The `SovereigntyView.uncatalogedSection` already pipes
   uncatalogued bundleIDs through the local LLM.  Next:

   - Cache LLM responses to `~/Library/Application Support/Splynek/
     ai-catalog-suggestions.json` so re-launches don't re-prompt.
   - Add `Confirm + open PR` button on each suggestion that
     opens a GitHub PR with the AI-drafted catalog entry.
   - Render an `AI · not yet verified` pill so users can
     distinguish hand-curated from AI-drafted at a glance.

   Lives in `splynek-pro` (the live LLM call requires the Pro
   build).  Free-tier sees the foundation but not the LLM
   round-trip.

6. **Fleet popularity announcement protocol** (#6).
   `PopularityCensus.swift` captures the local snapshot.  Next:

   - Settings → Fleet → "Share popularity census with LAN peers"
     toggle (off by default).
   - Extend `FleetCoordinator`'s announcement loop to publish
     the local census every 6 hours when the toggle is on.
   - Subscribe protocol on the receiving side; aggregate the
     union into a per-LAN view.

   Privacy invariant: every record carries SHA-256 prefix
   hashes (96-bit), never plain bundleIDs.  Tests should pin
   that no plain-text bundleID ever appears in the over-the-
   wire payload.

7. **CI cron for #2 + #4 + #7.**  Each script is currently
   a manual one-shot.  GitHub Actions versions:

   - `cask-sync.yml` — weekly clone+import+emit+PR
   - `privacy-labels-sync.yml` — weekly batch run against the
     top-500 most-popular apps (driven by #6 once it has
     enough data; manual list until then)
   - `wikidata-enrich.yml` — monthly enrichment pass

   Each opens an auto-PR; maintainer reviews + merges in batch.

### Strategic checkpoints

- **Sovereignty coverage**: 95% on typical Macs is the floor.
  Worth tracking what the bottom 5% looks like — those are
  prime contribute-button targets.
- **Trust coverage**: 151 → ~5,000 after #4 cron runs.
  Manual review burden grows linearly; consider a "trust
  triage" UI where the maintainer can pre-filter low-quality
  Apple-label scrapes before they hit the catalog.
- **AppPricing**: still 119 entries.  No tactic above directly
  grows it — pricing data is uniquely hard to scrape because
  prices change weekly + are localized.  Consider exposing the
  catalog as a CSV that paying users (Pro tier) can extend
  collaboratively.
