# Native-speaker review onramp

Splynek ships **2,285 translations** across 5 non-English locales
(pt-PT, es, fr, de, it).  All are AI-generated and machine-validated
(catalog completeness + audit).  None have been reviewed by a native
speaker.

This document is the contributor onramp for that pass.

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
- [x] Visual sanity sweep across all 5 locales (no layout overflow,
      no obviously-wrong terms).
- [x] CI guardrail (`.github/workflows/lint.yml`) prevents future
      regressions.

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
