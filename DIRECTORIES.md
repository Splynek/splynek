# Directory submissions — pre-filled forms

Three categories of place to list Splynek.  All can ship **before**
v1.0 clears App Store review because they let us control the copy
(no auto-pulled feature claims; we describe the app generically).

This file has the **exact text to paste** into each form.  Submit at
your own pace.

---

## Tier 1 — Generic Mac-app directories (low risk, fast-listing)

These accept submissions immediately and don't require notability.

### alternativeto.net

**Add new app:** https://alternativeto.net/contact/?type=add_software

| Field | Paste |
|---|---|
| Name | `Splynek` |
| Description (short) | `Native macOS download manager that uses every network interface in parallel + audits your installed apps for safety and EU sovereignty.` |
| Description (long) | (see below) |
| Categories | `Network & Admin → Download Manager`, `Network & Admin → Network Tools` |
| URL | `https://splynek.app` |
| License | `MIT` (free tier) `Freemium` (Pro tier) |
| Platforms | `Mac` |
| Tags | `download-manager`, `bittorrent`, `multi-interface`, `privacy`, `local-llm`, `eu`, `open-source` |

**Long description:**

```
Splynek is a native macOS download manager built in pure Swift with
zero third-party dependencies.

Three things in one:

1. Multi-interface aggregation — pins outbound HTTP/BitTorrent
   sockets to every network interface you have (Wi-Fi + Ethernet +
   iPhone tether + Thunderbolt NIC) via the BSD socket option
   IP_BOUND_IF, and pulls files in parallel.  Reaches 2-3× single-
   path on flaky hotel Wi-Fi + 5G tether combos.

2. Sovereignty + Trust audit (new in v1.5) — two on-device tabs that
   cross-reference your installed apps against curated catalogs.
   Sovereignty maps 1,150+ apps to European or open-source
   alternatives.  Trust surfaces public-record concerns from Apple's
   App Store privacy labels, EU regulator decisions, NVD CVEs, and
   HIBP confirmed breaches.  Localised FR/DE/ES/IT.

3. LAN cooperation + local AI — other Splyneks on Bonjour cooperate
   over gigabit; local-LLM Concierge (Apple Intelligence on macOS
   26+, or Ollama / LM Studio) for natural-language URL resolution.

Plus: BitTorrent v1+v2 with hybrid torrents (BEP 3/6/9/10/11/52),
SHA-256 + per-chunk Merkle integrity, REST API + CLI + Raycast +
Alfred + Shortcuts integration, mobile QR-paired web dashboard.

Free tier is MIT-licensed.  $29 one-time IAP unlocks Pro features
(Concierge, Recipes, Schedule, web dashboard).  No subscription, no
telemetry, no analytics.  Notarised + stapled by Apple.  Mac App
Store launching imminently.
```

### macupdate.com

**Add new app:** https://www.macupdate.com/forms/new-app-submission

Same long description as above.  Category: `Internet Utilities → Download Managers`.

### producthunt.com

**Don't submit yet** — Product Hunt launches are time-bound (one big
day vs gradual visibility).  Save this for Day 7 of the press
calendar.  When the time comes:

- Title: `Splynek — Mac downloader + privacy audit`
- Tagline (60 chars max): `Use every network at once. Audit your apps. $29 one-time.`
- Categories: `Productivity`, `Mac`, `Open Source`, `Privacy`
- Maker comment (paste at launch):

```
Hey Product Hunt!  Splynek is a Mac download manager I built solo
over the past year.  Two unusual things:

→ It pulls files in parallel over every network interface you have
  (Wi-Fi + Ethernet + iPhone tether).  2-3× faster on flaky hotel
  Wi-Fi.  Pure-Swift implementation via the BSD socket option
  IP_BOUND_IF — no VPN, no kernel hooks.

→ Two new tabs (v1.5) audit your *other* installed apps for
  privacy + sovereignty, using only verifiable public records:
  Apple's own App Store privacy labels, EU regulator fines, NVD
  CVEs, HIBP breaches.  No tech-press citations, no subjective
  claims, no AI-generated risk scores.

12k lines of pure Swift, zero third-party deps, MIT-licensed core,
$29 one-time for Pro features (no subscription).  On the Mac App
Store.

Happy to answer technical questions — the multi-interface mechanism,
the Trust source allowlist as a defamation defence, the JSON-backed
catalog pipeline that takes community PRs.

— Paulo (paulocgm@gmail.com)
```

### slant.co (community-curated alternative comparisons)

Submit at relevant questions:
- "What are the best download managers for Mac?"
- "What are the best open-source Mac apps?"
- "What are the best Mac apps that respect your privacy?"

One-line tagline for each: `Multi-interface Mac download manager + on-device privacy audit of your other apps. Pure Swift, MIT core, $29 one-time IAP.`

---

## Tier 2 — Sovereignty-specific directories (perfect-fit listing)

These specifically catalog European or open-source software.  Splynek
matches their thesis exactly.

### european-alternatives.eu

**Suggest a new alternative:** https://european-alternatives.eu/suggest

This is the catalog Splynek's Sovereignty tab cites as inspiration.
Listing here is meta-recursive (we draw from them; they should know
about us).

| Field | Paste |
|---|---|
| Name | `Splynek` |
| Country | `Portugal` 🇵🇹 |
| Category | `Network → Download Manager` |
| Description | `Multi-interface download manager for macOS. Built in Portugal. Bundles a 1,150+-entry European-alternatives catalog and a public-record privacy audit.` |
| Website | `https://splynek.app` |
| Open-source | `Yes — MIT license (free tier)` |
| Pricing | `Freemium — $29 one-time IAP for Pro features` |

### switching.software

**Suggest:** https://switching.software/suggest/

Catalog of "ethical alternatives to popular software".  Splynek
should fit under the meta-tooling category.  Their format expects:

```yaml
name: Splynek
description: >
  Native macOS download manager with two on-device audit tabs
  (Sovereignty + Trust) that map your installed apps to European
  or open-source alternatives and surface public-record privacy
  concerns.  Built solo in Portugal.
homepage: https://splynek.app
source: https://github.com/Splynek/splynek
license: MIT (free tier)
platforms: [macOS]
contact: info@splynek.app
country: Portugal
ethical_alternatives_to: []  # We're a tool *for* finding alternatives, not an alternative to a specific app
```

### ossware.org / openalternative.co

Submit at: `https://openalternative.co/submit`

Same metadata as above.  These OSS-specific directories are useful
for the dev-tooling angle.

---

## Tier 3 — GitHub awesome-lists (community-driven, slow but free SEO)

Each awesome-list maintainer has different submission requirements;
you're effectively opening a PR adding a single bullet point.  These
are usually quick to land if the project fits.

### awesome-mac

**Repo:** https://github.com/jaywcjlove/awesome-mac

PR adds to `README.md` under `## Download Tools`:

```markdown
- [Splynek](https://splynek.app/) - Native macOS download manager that uses every network interface in parallel + audits your installed apps for safety and EU sovereignty. Pure Swift, MIT core, $29 one-time IAP for Pro features. ![Open-Source Software][OSS Icon] ![Freeware][Freeware Icon]
```

### awesome-macos

**Repo:** https://github.com/iCHAIT/awesome-macOS

Add under `## Network`:

```markdown
- [Splynek](https://splynek.app/) - Multi-interface Mac download manager + on-device privacy audit (Sovereignty + Trust tabs). Pure Swift, zero deps, MIT core.
```

### awesome-selfhosted (relevant for the LAN fleet feature)

**Repo:** https://github.com/awesome-selfhosted/awesome-selfhosted

Borderline fit (Splynek isn't a self-hosted server, but the LAN
fleet feature is self-hosting-adjacent).  Probably skip unless they
have a "Mac" category.

### awesome-european-tech

**Repo:** https://github.com/Kleinrotti/awesome-euro-tech (or similar
EU-focused awesome lists)

Add under appropriate category.  Description emphasises Portuguese
provenance + EU sovereignty angle.

### awesome-privacy

**Repo:** https://github.com/Lissy93/awesome-privacy

Add under `## macOS` if they have a section.  Description
emphasises the "Trust" tab's source-allowlist privacy-rights angle.

---

## Submission tracking

Use a quick spreadsheet (or just `~/Documents/splynek-listings.csv`)
with columns:

```
Directory, URL, Submitted, Status, Listed URL, Notes
```

Status values: `submitted` / `accepted` / `rejected` / `pending` / `live`.

Aim for 8-12 listings in the first month.  Don't blast all at once
— space them out 2-3 per week so you can respond to any feedback.

---

## What NOT to submit

- ❌ **Hacker News**: that's the Show HN, save for `SHOW_HN.md` flow
- ❌ **Reddit r/macapps before HN**: cross-post AFTER the HN thread
  is live so you can link comments back
- ❌ **LinkedIn**: not a tech-discovery channel; better used as
  follow-up after press lands
- ❌ **Personal Twitter/Mastodon**: helpful, but only after you
  have artifacts to point to (HN thread, press piece)
- ❌ **Paid review sites or app review-aggregator services**: most
  charge $300-2000 and produce low-conversion traffic; skip
