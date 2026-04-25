# Contributing to the Sovereignty catalog

The Sovereignty tab in Splynek maps installed Mac apps to European
or open-source alternatives.  As of v1.4 the catalog has ~1170
entries and the source-of-truth lives in
[`Scripts/sovereignty-catalog.json`](Scripts/sovereignty-catalog.json);
the Swift file
[`Sources/SplynekCore/SovereigntyCatalog+Entries.swift`](Sources/SplynekCore/SovereigntyCatalog+Entries.swift)
is **generated** from the JSON by
[`Scripts/regenerate-sovereignty-catalog.swift`](Scripts/regenerate-sovereignty-catalog.swift).

This guide is for anyone who wants to add, correct, or expand an
entry.  It's deliberately short.

## The pipeline in 30 seconds

```
   ┌────────────── DISCOVERY ───────────────┐
   Scripts/sources/*.json   /Applications/   manual list
        └──────────────┬──────────────────┘
                       ▼
        swift Scripts/discover.swift
                       ▼
              Scripts/candidates.json
                       ▼
        swift Scripts/ai-propose.swift   ← needs LM Studio / OpenAI-compat endpoint
                       ▼
              Scripts/proposals.json     ← LLM-drafted, never auto-merged
                       ▼
        swift Scripts/merge-proposals.swift   ← human-in-the-loop review
                       ▼
   ┌──────────────── AUTHORING ─────────────┐
   Scripts/sovereignty-catalog.json   ← source of truth
                       ▼
        swift Scripts/regenerate-sovereignty-catalog.swift
                       ▼
   Sources/SplynekCore/SovereigntyCatalog+Entries.swift   ← generated Swift (commit both)
                       ▼
   ┌──────────────── QUALITY ───────────────┐
        swift Scripts/validate-catalog.swift   ← offline lint
        swift Scripts/check-urls.swift         ← online liveness check
        swift run splynek-test                 ← invariant tests
                       ▼
                   git commit
```

### Quick contributor flow (single entry)

1. Edit `Scripts/sovereignty-catalog.json`.  Copy an existing entry,
   adjust fields, save.
2. `swift Scripts/regenerate-sovereignty-catalog.swift` — refreshes
   the generated Swift; validates URLs, origins, duplicate IDs.
3. `swift Scripts/validate-catalog.swift` — lint (short notes,
   non-https homepages, etc.).
4. `swift run splynek-test` — invariant tests.
5. Commit **both** the JSON and the regenerated Swift.

### Bulk-import flow (curated batch)

1. Drop a JSON file into `Scripts/sources/` matching the schema
   in [`Scripts/sources/README.md`](Scripts/sources/README.md).
2. `swift Scripts/discover.swift` — diffs against the catalog,
   writes `Scripts/candidates.json`.
3. `swift Scripts/ai-propose.swift` — LLM drafts alternatives for
   each candidate.  Defaults to LM Studio at `localhost:1234`; set
   `OPENAI_COMPAT_URL` + `OPENAI_API_KEY` for cloud APIs.
4. `swift Scripts/merge-proposals.swift` — interactive review.  Use
   `--auto-accept high` for the trusted bulk-flow path.
5. Regenerate + lint + test (steps 2-4 from the quick flow).

### Discovery from a real Mac

`swift Scripts/discover.swift --from-apps` enumerates `/Applications/`,
`/Applications/Utilities/`, `~/Applications/` and emits any apps not
already in the catalog as candidates — cheap way to find genuinely
common Mac apps that have slipped through.

### Reverse: refresh JSON from Swift

If the generated Swift was hand-edited by accident:
`swift run splynek-cli sovereignty-dump > Scripts/sovereignty-catalog.json`.

### Weekly health check (CI)

`.github/workflows/sovereignty-weekly.yml` runs every Monday:
- Validates the catalog (offline lint).
- Verifies the regenerator round-trips cleanly.
- HEAD-checks every homepage + downloadURL; opens a labeled issue if
  any rotted.

Manual trigger: Actions tab → "Sovereignty catalog — weekly health
check" → Run workflow.

## What the Sovereignty tab is, and isn't

**What it is.**  A local-only scan of your installed apps that shows
each app's country-of-origin and suggests European or open-source
alternatives where they exist.  Framing: *pro-EU-sovereignty*, not
anti-any-country.

**What it isn't.**  A political tool, a boycott list, or a ranking
of "good" vs "bad" apps.  The goal is to give European users visible
ownership over their software supply chain.  We don't shame
installed apps; we inform, and we let the user decide.

## How the catalog works

Each **Entry** represents one non-European app (US / CN / RU / other).
The Splynek app already knows if you have it installed via a
sandbox-legal Spotlight-adjacent scan (see
[`SovereigntyScanner.swift`](Sources/SplynekCore/SovereigntyScanner.swift)
for the audit trail).

Each Entry has:

- `targetBundleID` — exact bundle ID match, e.g. `com.google.Chrome`.
  (We never match by display name; that false-positives too easily.)
- `targetDisplayName` — as shown in Finder.
- `targetOrigin` — where the vendor's control sits.  One of:
  - `.unitedStates` — US
  - `.china` — CN
  - `.russia` — RU
  - `.other` — anywhere else (Canada, Japan, Australia…)
  - **Do not use** `.europe`, `.oss`, or `.europeAndOSS` for a
    target — apps that are already sovereign don't need alternatives.
- `alternatives` — an ordered list of suggested replacements.  Each
  alternative has:
  - `origin` — preferably `.europe`, `.oss`, or `.europeAndOSS`.
    `.other` is tolerated as a *secondary* pick (e.g. DaVinci Resolve
    (Australia) for pro video editing, TablePlus (Singapore) for SQL)
    when no strong European commercial option exists and the OSS pick
    is already listed.  **Never** use `.unitedStates`, `.china`, or
    `.russia` — those are precisely the origins users come here to
    step away from.  The `SovereigntyCatalogTests` suite enforces
    this at test time.
  - Every entry must contain **at least one** `.europe` / `.oss` /
    `.europeAndOSS` alternative so the European-only and OSS-only
    filters never come up empty.
  - `name` — the project's common name.
  - `homepage` — canonical homepage URL.
  - `note` — one-line summary.  Always mention country + license.
  - `downloadURL` — *optional*, direct-download URL for one-click
    install via Splynek.  Only populate this when the URL is stable
    (e.g. Mozilla's redirect service `download.mozilla.org/?product=
    firefox-latest…`).  If the URL has a version in it (e.g.
    `…v2.7.9/KeePassXC-2.7.9.dmg`), **leave it nil** — the UI will
    fall back to a homepage "Visit" button.

## Design principles for new entries

1. **Alternatives must be real and shippable.**  No vapourware.
   Homepage must return a real page today.
2. **European ecosystem = EU member state + EEA + UK + Switzerland.**
   Pragmatic definition.  Call out the country in the note:
   "Mullvad (Sweden)", "Proton (Switzerland)".
3. **OSS = genuinely open-source, usable license.**  GPL / MIT /
   BSD / MPL / Apache / AGPL.  "Source-available," "commons clause,"
   or "free tier only" don't count.
4. **One or two alternatives per target.**  Choice paralysis kills
   action.  If there are ten good options, pick the two most widely
   used.
5. **Don't shame.**  Tone is "here's a door out if you want one,"
   not "here's what you should feel bad about."  Notes should be
   factual, not rhetorical.
6. **Origin-neutral targeting.**  US apps are the biggest single
   category but they are not the only category.  Chinese,
   Russian, and other-jurisdiction apps all count.  Treat them
   equally.

## Adding an entry — the minimal diff

```swift
Entry(targetBundleID: "com.example.TargetApp",
      targetDisplayName: "Target App",
      targetOrigin: .unitedStates,
      alternatives: [
        .init(id: "target:european-alt", origin: .europe,
              name: "European Alt",
              homepage: URL(string: "https://european-alt.example")!,
              note: "European Alt Ltd (Germany). MPL. Free for personal use."),
        .init(id: "target:oss-alt", origin: .oss,
              name: "OSS Alt",
              homepage: URL(string: "https://oss-alt.example")!,
              note: "MIT-licensed, self-hostable."),
      ]),
```

Put the entry in the appropriate category section (Browsers,
Communication, Productivity, Creative, Dev, etc. — the comments
in `entries` mark them).  Within a category, order doesn't matter
— the UI sorts alphabetically at render time.

## Testing your entry

1. Install the app whose bundle ID you just added.
2. Build Splynek:

   ```
   xcodebuild -project Splynek.xcodeproj -scheme Splynek-MAS \
     -configuration Release build
   ```

3. Launch, click **Sovereignty** → **Scan my Mac**.
4. Your app should appear with its origin badge + your suggested
   alternatives.
5. Click the **Install** or **Visit** button on one alternative.
   Make sure it does what you expect.

## Submitting the PR

- Small PRs preferred — 1–5 entries per PR, so reviews are fast.
- One-line PR title: `Sovereignty: add <category> entries`.
- PR body: state WHY these alternatives are appropriate.  If the
  origin is non-obvious ("why is Shiny Frog Italian?"), link the
  source.
- No commit signing or CLA required.

## Finding good candidates

If you're stuck for ideas, these lists are public-domain-adjacent
starting points.  Re-verify each entry before adding — lists go
stale fast.

- <https://european-alternatives.eu> — CC-licensed list of
  EU-headquartered SaaS.
- <https://github.com/awesome-selfhosted/awesome-selfhosted> — MIT
  list of open-source self-hosted alternatives.
- <https://www.privacytools.io> — privacy-focused alts, mostly OSS.
- <https://european-alternatives.eu/category> — category index.

Many of these are broader than Splynek's scope (web services, SaaS,
browser extensions).  We only catalog native Mac apps for now.
Bundle IDs are what the match is on.

## Questions?

Open a discussion on [github.com/Splynek/splynek/discussions](https://github.com/Splynek/splynek/discussions).
