# Contributing to the Trust catalog

The Trust tab in Splynek surfaces **public-record concerns** about
installed Mac apps — Apple's App Store privacy labels, regulatory
enforcement actions, CVEs, confirmed breaches, vendor security
advisories.  As of v1.5 the catalog ships ~30 deeply-cited entries
covering the most commonly-installed apps.

The source of truth is
[`Scripts/trust-catalog.json`](Scripts/trust-catalog.json); the Swift
in [`Sources/SplynekCore/TrustCatalog+Entries.swift`](Sources/SplynekCore/TrustCatalog+Entries.swift)
is **generated** from the JSON by
[`Scripts/regenerate-trust-catalog.swift`](Scripts/regenerate-trust-catalog.swift).

## The pipeline in 30 seconds

```
Scripts/trust-catalog.json
  |
  ├── swift Scripts/regenerate-trust-catalog.swift
  ├── swift Scripts/validate-trust-catalog.swift [--strict]
  |
  ▼
Sources/SplynekCore/TrustCatalog+Entries.swift
  |
  └── swift run splynek-test  ← validates invariants
```

## The MAS-safe source allowlist

**Every concern in the Trust catalog MUST cite one of these source
classes.**  This isn't a style preference — it's the legal and App
Review boundary that makes the tab shippable on the Mac App Store.

### Allowed sources

| Source                                | When to use                              | Example sourceName              |
|---------------------------------------|------------------------------------------|---------------------------------|
| **Apple App Store privacy label**     | Tracking / linked / unlinked data classes | `Apple App Store`               |
| **EU Data Protection Authorities**    | GDPR fines / decisions                   | `CNIL`, `Irish DPC`, `Garante per la protezione dei dati personali`, `ICO`, `AEPD`, `Bundeskartellamt`, `Datatilsynet` |
| **US Federal Trade Commission**       | Consent orders / fines                   | `FTC`                           |
| **US SEC**                            | Securities fraud / disclosure failures   | `SEC`                           |
| **State AGs (US)**                    | Multistate settlements                   | `California AG`                 |
| **US OFAC / BIS / CISA**              | Sanctions / federal-system bans          | `US OFAC`, `US BIS`, `US CISA`  |
| **Court records**                     | Final rulings (not complaints)           | dock + court name               |
| **NVD CVE database**                  | Documented vulnerabilities               | `NVD`                           |
| **Have I Been Pwned**                 | Confirmed breaches                       | `HIBP`                          |
| **Vendor security advisories**        | The developer's own CVE disclosure       | `Microsoft Security Response Center`, `Apple Security Notes`, `Google Project Zero`, `Adobe Security Bulletin`, `<Vendor> security advisory` |
| **Vendor's own privacy policy / ToS** | Self-disclosed business model            | `<Vendor> privacy policy`       |

### NOT allowed

- Tech press articles (TechCrunch, Verge, Wired, etc.) — opinion-shaped
- Wikipedia — not an official source
- ToS;DR — community ratings, subjective
- Mozilla *Privacy Not Included — review-shaped
- AI-generated risk assessments — hallucination risk
- Personal blog posts — even from security researchers
- Forum threads / GitHub issues — uncurated

If the most authoritative source for a concern is *only* available
via one of the disallowed channels, **do not file the concern.**
A weak claim is worse than no claim.

## Concern schema

```json
{
  "id": "<bundleID-slug>:<concern-slug>",
  "kind": "appStoreLinkedData",
  "axis": "privacy",
  "severity": "moderate",
  "summary": "App Store privacy label discloses linked data: …",
  "evidenceURL": "https://apps.apple.com/…",
  "evidenceDate": "2025-09-15",
  "sourceName": "Apple App Store"
}
```

| Field          | Required | Notes                                                          |
|----------------|----------|----------------------------------------------------------------|
| `id`           | yes      | unique across the whole catalog                                |
| `kind`         | yes      | one of the enum values in `TrustCatalog.Kind`                  |
| `axis`         | yes      | `privacy` / `security` / `trust` / `businessModel`             |
| `severity`     | yes      | `low` / `moderate` / `high` / `severe`                         |
| `summary`      | yes      | factual one-liner; no editorial words; cite the source phrasing |
| `evidenceURL`  | yes      | https only; must resolve at PR time                            |
| `evidenceDate` | yes      | ISO YYYY-MM-DD; no future dates                                |
| `sourceName`   | yes      | from the allowlist above                                       |

## Banned editorial words

The regenerator refuses to ship a summary containing any of:

```
spies / spying / spy on
untrustworthy / shady / sketchy
evil / malicious / predatory
scam / scammer / fraudster
"you are the product"
stealing / steals your
creepy
```

If you need one of these to make the point, the underlying citation
isn't strong enough.  Quote the source instead.

## Severity guidance

| Severity   | When                                                                    |
|------------|-------------------------------------------------------------------------|
| `low`      | App Store privacy label disclosure of `unlinked` data only; minor advisory |
| `moderate` | App Store linked-data disclosure; minor regulatory matter                 |
| `high`     | App Store tracking-data disclosure; published GDPR / FTC fine; confirmed breach affecting >1M users |
| `severe`   | Headline regulatory ruling (>€100M); active government sanction; catastrophic breach |

## Workflow

1. Edit `Scripts/trust-catalog.json`.  Copy an existing entry, adjust
   fields, save.
2. `swift Scripts/regenerate-trust-catalog.swift` — rejects the run
   if any concern cites non-https, has bad enums, contains banned
   words, or has a future date.
3. `swift Scripts/validate-trust-catalog.swift --strict` — soft lint
   (stale-source warnings, terse summaries, unrecognised sources).
4. `swift run splynek-test` — runtime invariants.
5. Commit **both** files (`trust-catalog.json` + the regenerated
   `TrustCatalog+Entries.swift`).

## Reviewing PRs

Before merging a Trust PR, verify:

- [ ] Every new `evidenceURL` resolves (open it, confirm relevance).
- [ ] `sourceName` matches the allowlist (no typos).
- [ ] Severity is justified — `severe` requires a >€100M fine, an
      active sanction, or a >1M-user catastrophic breach.
- [ ] Summary reads as factual reporting, not commentary.
- [ ] `lastReviewed` updated on the parent entry.
- [ ] No collisions in `id` or `targetBundleID`.

A strong PR cites the official source for every concern, uses the
source's own phrasing in the summary, and links directly to the page
that contains the cited fact (not the regulator's homepage).
