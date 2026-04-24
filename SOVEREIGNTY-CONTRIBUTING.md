# Contributing to the Sovereignty catalog

The Sovereignty tab in Splynek maps installed Mac apps to European
or open-source alternatives.  The catalog at
[`Sources/SplynekCore/SovereigntyCatalog.swift`](Sources/SplynekCore/SovereigntyCatalog.swift)
is handwritten seed data — community PRs are how it grows.

This guide is for anyone who wants to add, correct, or expand an
entry.  It's deliberately short.

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
  - `origin` — one of `.europe`, `.oss`, `.europeAndOSS`.  **Do not**
    suggest a US alternative to another US app; it wouldn't reduce
    non-EU dependence.
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
