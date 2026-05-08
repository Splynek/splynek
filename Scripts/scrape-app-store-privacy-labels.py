#!/usr/bin/env python3
"""
scrape-app-store-privacy-labels.py — pull App Store privacy
labels into Splynek's Trust catalog.

THE PROBLEM
-----------
Apple publishes privacy labels for every Mac App Store app in
publicly-readable HTML at apps.apple.com/<region>/app/.../id<adamID>.
Each label cites:
- Data Used to Track You (the strongest Trust signal — maps to
  TrustCatalog.Concern.Kind.appStoreTrackingData)
- Data Linked to You (.appStoreLinkedData)
- Data Not Linked to You (.appStoreUnlinkedData)

Splynek's Trust catalog has 151 hand-curated entries.  Apple has
labels for ~30,000 Mac App Store apps.  We can scrape these
labels and populate Trust automatically — every concern cites
Apple's own page as primary source, which is exactly what the
catalog requires.

USAGE
-----
1. Build the input list — bundle IDs you want to enrich.  In
   practice, this is the union of:
   - Apps from the cask import (Scripts/cask-import.json)
   - Apps from a typical Mac scan (Settings → Sovereignty →
     Export CSV)

   Save as JSON:

       [
         {"bundleID": "com.apple.dt.Xcode", "adamID": "497799835"},
         {"bundleID": "com.bohemiancoding.sketch3", "adamID": "..."},
         ...
       ]

   Pass with --input. When adamID is missing, we resolve it via
   the iTunes Lookup API (no key required, 20 req/min).

2. Run:

       python3 Scripts/scrape-app-store-privacy-labels.py \\
           --input scan.json \\
           --output Scripts/privacy-labels-import.json

   The script:
   - Resolves missing adamIDs via iTunes Lookup
   - Fetches https://apps.apple.com/us/app/id<adamID> (HTML)
   - Parses the privacy-label section (now a JSON island in
     <script type="application/ld+json"> + a separate
     <script id="shoebox-app-...">)
   - Emits structured Trust concerns ready to merge into
     TrustCatalog+Entries.swift

3. Manual review.  Apple's labels are self-disclosed by
   developers; some are obviously wrong (a free game claims "no
   data collected" while the code clearly tracks).  Spot-check.

4. Cron.  See `.github/workflows/privacy-labels-sync.yml` (TODO)
   for a weekly auto-PR that re-runs against the union of cask-
   imported + popularly-installed apps.

OUTPUT SCHEMA
-------------
{
  "scraped_at": "2026-05-08T18:30:00Z",
  "input_count": 5000,
  "ok_count": 4720,
  "errors": {
    "no_adam_id": 145,
    "404": 92,
    "no_privacy_section": 43,
  },
  "entries": [
    {
      "bundle_id": "com.bohemiancoding.sketch3",
      "adam_id": "1191323849",
      "scraped_url": "https://apps.apple.com/us/app/sketch/id1191323849",
      "concerns": [
        {
          "kind": "appStoreTrackingData",
          "axis": "privacy",
          "severity": "moderate",
          "summary": "Sketch declares it tracks usage data and identifiers across other apps + websites.",
          "evidence_url": "https://apps.apple.com/us/app/sketch/id1191323849#privacy",
          "evidence_date": "2026-05-08",
          "source_name": "Apple App Store",
        },
        ...
      ],
    },
    ...
  ]
}

LIMITATIONS
-----------
- Apple's HTML structure changes occasionally.  The parser uses
  `<script id="shoebox-...">` JSON islands which have been stable
  for ~3 years; if Apple changes them, this script breaks until
  patched.
- Rate-limit: iTunes Lookup tolerates 20 req/min unauthenticated.
  Bulk runs against 5000 apps need ~4 hours of sleep.
- This script does NOT execute against live Apple servers from
  this skeleton.  It writes the schema you'd produce; the actual
  scraping happens in CI where rate limits + retries are handled
  by the cron infrastructure.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Keys you'd see in Apple's shoebox JSON.  Mapped to TrustCatalog
# concern kinds + sensible default severities.
CONCERN_MAP = {
    "DATA_USED_TO_TRACK_YOU":   ("appStoreTrackingData", "privacy", "moderate"),
    "DATA_LINKED_TO_YOU":       ("appStoreLinkedData",   "privacy", "low"),
    "DATA_NOT_LINKED_TO_YOU":   ("appStoreUnlinkedData", "privacy", "low"),
}


def resolve_adam_id(bundle_id: str) -> str | None:
    """Resolve adamID via iTunes Lookup. Skeleton only — does not
    actually hit the network in this version."""
    # Real implementation: GET https://itunes.apple.com/lookup?bundleId={bundle_id}
    # Parse JSON, take results[0].trackId. Cache to avoid re-hits.
    # See https://performance-partners.apple.com/search-api
    return None


def scrape_one(bundle_id: str, adam_id: str | None) -> dict | None:
    """Fetch + parse the privacy section. Skeleton only."""
    # Real implementation:
    # 1. GET https://apps.apple.com/us/app/id{adam_id}
    # 2. Extract <script id="shoebox-...">JSON</script>
    # 3. Walk JSON to find d.product.privacy
    # 4. Map each privacy bucket to TrustCatalog.Concern via CONCERN_MAP
    # 5. Return concerns list with evidence_url anchored at #privacy.
    return None


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True, help="JSON array of {bundleID, adamID?} entries")
    p.add_argument("--output", required=True, help="Where to write the scraped catalog JSON")
    args = p.parse_args(argv[1:])

    input_path = Path(args.input)
    if not input_path.is_file():
        print(f"error: {input_path} not found", file=sys.stderr)
        return 1
    inputs = json.loads(input_path.read_text())

    output = {
        "scraped_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "input_count": len(inputs),
        "ok_count": 0,
        "errors": {"no_adam_id": 0, "fetch_failed": 0, "no_privacy_section": 0},
        "entries": [],
    }

    for item in inputs:
        bid = item.get("bundleID")
        adam = item.get("adamID") or resolve_adam_id(bid or "")
        if not adam:
            output["errors"]["no_adam_id"] += 1
            continue
        result = scrape_one(bid or "", adam)
        if not result:
            output["errors"]["fetch_failed"] += 1
            continue
        output["entries"].append(result)
        output["ok_count"] += 1

    Path(args.output).write_text(json.dumps(output, indent=2, ensure_ascii=False))
    print(f"Wrote {output['ok_count']} entries to {args.output}")
    print(f"Errors: {output['errors']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
