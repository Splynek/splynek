# Native-speaker review onramp

Splynek ships **3,120 translations** (624 strings × 5 locales) across
pt-PT, es, fr, de, it.  All are AI-generated and machine-validated
(catalog completeness + audit-script + CI guardrail enforcing 0
missing on every PR).  None have been reviewed by a native speaker.

This document is the contributor onramp for that pass.

**Catalog scope:** the catalog covers BOTH the public free-tier UI
(under `Sources/SplynekCore/`) AND the private Pro UI (under
`/Users/pcgm/splynek-pro/Sources/SplynekPro/` — Concierge, Recipes,
AI-assist surfaces).  In MAS builds the Pro views look up keys from
the same `Localizable.xcstrings` shipped in `SplynekCore`.  The audit
script scans both repos when the Pro repo is present as a sibling
checkout.  As a reviewer you'll see the Pro tab in your locale's
build only if you have access to the private Pro sources at archive
time — for the public DMG / SwiftPM debug build the Pro tab shows
the locked-state placeholder, which still goes through the catalog.

## Why this exists

AI-generated copy clears the "comprehensible" bar.  It does not always
clear the "sounds native" bar.  In Splynek's two highest-credibility
markets — **Germany** (privacy + sovereignty) and **France** (digital
sovereignty press is loudest) — sub-native-quality copy weakens the
positioning.  A 90-minute pass per locale by a fluent speaker is the
single highest-leverage contribution someone can make to the project
right now.

## What you're working with

Every user-facing string lives in **one file**:

```
Scripts/regenerate-localizations.py
```

Format: each English source key is a Python dict mapping to per-locale
translations.  Example:

```python
"Refresh": {
    "pt-PT": "Atualizar",
    "es": "Actualizar",
    "fr": "Actualiser",
    "de": "Aktualisieren",
    "it": "Aggiorna",
},
```

The `.xcstrings` JSON catalog is generated from this file.  **Never
edit the JSON directly** — the CI guardrail will fail your PR.

## Locale conventions to follow

These are baked into the existing translations and are the standard
the review should preserve:

### pt-PT — European Portuguese (NOT Brazilian)

- "ficheiro" (not "arquivo"), "ecrã" (not "tela"), "telemóvel" (not
  "celular"), "rato" (not "mouse"), "transferência" (not "download"
  for the noun, though "transferir" is fine as the verb).
- Imperative tense for buttons ("Procurar", "Repetir").
- Tu form for prose, not você ("Cola um URL", "Tens uma soma de
  controlo?").  Apple's macOS Portuguese conventions.
- Watch for false friends from pt-BR: "atual" (not "actual"),
  "ativo" (not "ativo" — same), "fato" (in pt-PT means *suit*, not
  *fact* — pt-BR uses it for *fact*; we use "facto").

### es — Castilian Spanish

- Tu form for prose ("Pega una URL", "Tu Mac").
- "ordenador" or "Mac" (not "computadora").
- "fichero" or "archivo" both acceptable; we lean "archivo" (Apple style).
- "descargar" (not "bajar").
- Imperative for buttons ("Iniciar descarga", "Reintentar").
- Avoid Latin-American constructions ("agregar" → use "añadir";
  "compartir" is fine).

### fr — French

- Vous form for prose ("Collez une URL", "votre Mac").
- Apple-style spaces around colons (`option :`) and "%" (`50 %`).
- Apostrophe elision before vowels ("d'attente", "l'authenticité").
- "téléchargement" (not "télécharger" for the noun).
- "fichier" / "ordinateur" / "navigateur" (not "browser").
- "Mo/s" for megabytes per second (not "MB/s").

### de — German

- Sie form for prose ("Fügen Sie", "Ihr Mac").
- Capitalise nouns ("Download", "Verbindung", "Datei").
- Avoid Anglicisms where a native term reads naturally ("Auflistung"
  not "Listing", "Schaltfläche" not "Button" for UI elements).
- Compound nouns are fine and idiomatic ("Mehrschnittstellen-
  Download").
- "MB/s" stays as-is (German convention).

### it — Italian

- Tu form for prose ("Incolla un URL", "il tuo Mac").
- "scaricare" / "file" / "rete" / "navigatore".
- Imperative for buttons ("Avvia download", "Riprova").
- Apostrophe elision before vowels ("l'autenticità", "all'app").

## How to review

### Setup (one-time)

```bash
git clone https://github.com/Splynek/splynek
cd splynek
swift build --product Splynek
SKIP_APP_INTENTS=1 ./Scripts/build.sh
```

### Run in your locale

```bash
# Replace `de` with your locale code: pt-PT / es / fr / de / it
build/Splynek.app/Contents/MacOS/Splynek -AppleLanguages '(de)' -AppleLocale de_DE
```

Walk every tab.  Hover every tooltip.  Click into Settings →
Programmability + Schedule + Trust weights.  Trigger the onboarding
sheet (delete `~/Library/Application Support/Splynek/onboarded` and
relaunch).

### What to flag

1. **Wrong meaning** — translation says something different from the
   English.  Highest priority.
2. **Unidiomatic** — technically correct but no native speaker would
   write it that way.
3. **Style mismatch** — uses formal Sie/vous when the rest of the app
   uses Du/tu (or vice versa).
4. **Apple convention drift** — diverges from how macOS itself
   localizes the same concept (compare against System Settings,
   Finder, Mail in your locale).
5. **Layout overflow** — the translation is so long it wraps awkwardly
   or truncates.  Note: the column widths and card layouts are
   constrained, so terser is usually better.
6. **Punctuation** — French spacing around colons + percent signs is
   a common AI miss.

### Submitting fixes

```bash
# Branch
git checkout -b l10n-de-review-yourname

# Edit Scripts/regenerate-localizations.py — change the de: value
# for any key you're correcting.

# Regenerate
python3 Scripts/regenerate-localizations.py

# Verify locally — both invariants must pass
python3 Scripts/find-missing-translations.py     # must report 0 missing
swift run splynek-test --filter Localizable      # must show all green

# Commit
git add Scripts/regenerate-localizations.py Sources/SplynekCore/Localizable.xcstrings
git commit -m "l10n(de): native-speaker pass — 12 corrections"

# PR against main
gh pr create --title "l10n(de): native-speaker review pass" \
  --body "Native-speaker review of all DE strings.  N corrections."
```

## What's already done

- [x] Six rounds (1 → 6) of catalog growth (56 → 387 strings) with
      Claude-generated translations across all five locales.
- [x] Round 7: 41 long-tail plain-string entries (387 → 428).
- [x] Round 8: 28 format-spec entries for interpolated strings
      (428 → 457).  Per-locale completeness verified by
      `LocalizableCatalogTests`.
- [x] v1.7.x audit-extension catch-up: extended `Scripts/find-missing-
      translations.py` with 6 component-builder regex patterns
      (`ContextCard.subtitle`, `TitledCard.title`, `EmptyStateView`
      title + message, `MetricView.caption`, `StatusPill.text`),
      surfacing 49 hidden strings the original audit was missing.
      Catalog 480 → 535.
- [x] 2026-05-05 full audit pass:
      - Switched audit script from per-line to whole-file regex
        scanning — surfaced 21 multi-line-component-arg strings that
        had been quietly missing for months.  Catalog 535 → 569.
      - Promoted `ProLockedView.featureTitle` and `summary` from
        `String` to `LocalizedStringKey` at the type level — SwiftUI's
        `Text(String)` doesn't auto-localize and existing pt-PT
        translations weren't being honoured.
      - Extended audit script to scan `splynek-pro/Sources/SplynekPro/`
        as well — surfaced 49 Pro-tier UI strings (Concierge tab,
        Recipes tab, AI-status messages) never covered.  Catalog
        569 → 618.
      - History timeline footer "X across N days" + MCP endpoint URL
        truthfulness (free tier displays 127.0.0.1 to match actual
        binding).
      - 2 ProLockedView regexes added to `find-missing-translations.py`
        so future Pro-gate placeholders get caught at PR time.
- [x] Visual sanity sweep across all 5 locales — pt-PT walked
      end-to-end through round 6; de / es / fr / it walked
      end-to-end 2026-05-05 (DE+FR pass caught 6 InstallView
      strings flipped to `LocalizedStringKey`).  No layout overflow,
      no obviously-wrong terms.  Pro-tier pt-PT walkthrough
      2026-05-05 against MAS build with dev-override; Concierge
      header subtitle + Recipes Objetivo/Ideias sections + Settings
      ProLockedView placeholders all confirmed in pt-PT.
- [x] CI guardrail (`.github/workflows/lint.yml`) prevents future
      regressions — every PR runs the audit script and fails on any
      new `Text("…")` literal not in the catalog.

## What's NOT done (review priority order)

- [ ] **DE — German** (priority 1).  Sovereignty + privacy press
      coverage is most credibility-sensitive here.
- [ ] **FR — French** (priority 1).  Digital-sovereignty press is
      loudest in France; AI typically misses Apple's space-before-colon
      convention.
- [ ] **PT-PT — Portuguese** (priority 2).  Primary author is
      bilingual pt-PT/en, so AI output has been spot-checked, but a
      cold-pass review by a different native speaker would surface
      blind spots.
- [ ] **ES — Spanish** (priority 3).  Castilian/Latin-American mix is
      the highest risk here.
- [ ] **IT — Italian** (priority 3).  Lowest market exposure for now.

## Compensation

Splynek is a one-person open-source project with a single revenue
stream (€29 one-time MAS purchase, not yet shipping at the time of
writing).  We can't pay for review at market rate.

What we **can** offer:

- Public credit in `CONTRIBUTORS.md`, the release notes, and
  (optionally) the App Store description.
- A free Pro license once StoreKit ships (worth €29).
- An honest signal-boost — if you're a working translator, the
  contribution is portfolio-grade and links to a published macOS app.

If the project starts paying for translation work later, native-speaker
review of a non-English locale will be the FIRST line item.

## Questions

`info@splynek.app` or open an issue at
`github.com/Splynek/splynek/issues` with the label `l10n`.
