# Sources for the Sovereignty discovery pipeline

This directory holds JSON files that feed `Scripts/discover.swift`.
Each file represents one upstream catalog of apps — community lists,
ingester output from public datasets, or hand-curated batches.

## Schema

```json
{
  "source":  "human-readable label (e.g. 'switching.software-2026-04')",
  "license": "license / attribution string (e.g. 'CC-BY-4.0')",
  "url":     "https://… link back to the upstream",
  "entries": [
    {
      "displayName": "App Name",         // required
      "bundleID":    "com.example.app",  // optional, synthesised if missing
      "origin":      "unitedStates",     // optional — europe / oss / europeAndOSS / unitedStates / china / russia / other
      "category":    "chat-personal",    // optional — see ai-propose.swift for the full list
      "note":        "any free-form context"  // optional
    }
  ]
}
```

Only `displayName` is required.  When `bundleID` is missing,
discover.swift synthesises `app.unknown.<slug>` so AI/human review can
correct it later.  Origin and category are hints — the AI proposer
will draft them when missing, and the human reviewer always confirms.

## Suggested upstream sources (CC-BY-friendly)

- **switching.software** — community-curated alternatives directory
  (CC-BY-4.0).  Mirror with attribution.
- **european-alternatives.eu** — EU-focused list (license varies; check
  per-page).
- **awesome-euro-tech** GitHub awesome-lists — usually MIT, attribution
  required.
- **alternativeto.net** — commercial; respect ToS, manual scraping only.
- **Manual community batches** — write a JSON file, drop it here.

## Workflow

```
Scripts/sources/<your-batch>.json
  ↓
swift Scripts/discover.swift          → Scripts/candidates.json
  ↓
swift Scripts/ai-propose.swift        → Scripts/proposals.json   (LLM drafts)
  ↓
swift Scripts/merge-proposals.swift   → Scripts/sovereignty-catalog.json (human-reviewed)
  ↓
swift Scripts/regenerate-sovereignty-catalog.swift
  ↓
swift Scripts/validate-catalog.swift  → lint
  ↓
swift run splynek-test                → invariant tests
  ↓
git commit
```

Treat this directory as append-only history: new ingester runs become
new files, never overwrite an old one.  The pipeline dedupes by bundle
ID + display name, so the same app appearing in three sources is fine.
