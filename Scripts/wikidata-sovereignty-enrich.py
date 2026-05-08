#!/usr/bin/env python3
"""
wikidata-sovereignty-enrich.py — enrich Splynek's Sovereignty
catalog with country-of-origin data via Wikidata SPARQL.

THE PROBLEM
-----------
SovereigntyCatalog needs to know each app's `targetOrigin`
(europe / oss / europeAndOSS / unitedStates / china / russia /
other).  We hand-curate this for ~1,150 apps; the Mac App Store
has ~30,000.  Hand-curation cannot scale.

THE SOLUTION
------------
Wikidata has structured infoboxes for tens of thousands of
software entries.  Properties of interest:
- P176 manufacturer (or P178 developer)
- P17 country
- P275 license (free / proprietary)

A SPARQL query against query.wikidata.org returns the structured
fields for any software item.  We can match Splynek's catalog
against Wikidata by (a) the homepage URL, (b) the app's
canonical name, then enrich.

USAGE
-----
1. Build the input list — apps that lack origin/license metadata:

       python3 Scripts/wikidata-sovereignty-enrich.py \\
           --input scan.json \\
           --output Scripts/wikidata-import.json

   Input is the same JSON shape as the cask-import pipeline.

2. The script:
   - Builds a SPARQL query for each app's name / homepage
   - POSTs to https://query.wikidata.org/sparql
   - Parses the JSON response
   - Maps Wikidata's country codes (Q183 = Germany, Q142 = France,
     etc.) to SovereigntyCatalog.Origin values
   - Emits a structured file to be merged into the catalog

3. Manual review.  Wikidata is community-edited and varies in
   completeness.  Some apps have wrong country (HQ vs founded
   in vs incorporated in vs developer's nationality — they don't
   always agree).

OUTPUT SCHEMA
-------------
{
  "queried_at": "2026-05-08T18:30:00Z",
  "input_count": 5000,
  "ok_count": 3120,
  "entries": [
    {
      "bundle_id": "com.bohemiancoding.sketch3",
      "wikidata_id": "Q1747559",
      "name": "Sketch",
      "country": "NL",       # ISO-3166-1 alpha-2
      "origin": "europe",    # Splynek's Origin enum
      "license": "Proprietary",
      "developer": "Bohemian Coding",
      "homepage": "https://www.sketch.com/",
    },
    ...
  ]
}

LIMITATIONS
-----------
- Wikidata coverage is patchy: ~20-30% match rate for typical
  Mac apps.  The remainder fall through to "unknown origin"
  status.
- Country-to-origin mapping is opinionated: we treat any EU/EEA
  country as `europe`; Switzerland + UK roll into `europe` per
  Splynek's "European tech ecosystem" definition.
- This skeleton does not actually run SPARQL.  See `query_one()`
  for the real query template.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# Wikidata Q-IDs of countries Splynek treats as "europe".
EU_PLUS_QIDS = {
    "Q183": "DE",  # Germany
    "Q142": "FR",  # France
    "Q38":  "IT",  # Italy
    "Q29":  "ES",  # Spain
    "Q45":  "PT",  # Portugal
    "Q31":  "BE",  # Belgium
    "Q55":  "NL",  # Netherlands
    "Q39":  "CH",  # Switzerland
    "Q40":  "AT",  # Austria
    "Q35":  "DK",  # Denmark
    "Q33":  "FI",  # Finland
    "Q34":  "SE",  # Sweden
    "Q20":  "NO",  # Norway
    "Q145": "GB",  # UK
    "Q27":  "IE",  # Ireland
    "Q41":  "GR",  # Greece
    "Q36":  "PL",  # Poland
    "Q213": "CZ",  # Czechia
    "Q214": "SK",  # Slovakia
    "Q28":  "HU",  # Hungary
    "Q37":  "LT",  # Lithuania
    "Q211": "LV",  # Latvia
    "Q191": "EE",  # Estonia
    "Q403": "RS",  # Serbia (non-EU but EU candidate)
    "Q224": "HR",  # Croatia
    "Q215": "SI",  # Slovenia
    "Q218": "RO",  # Romania
    "Q219": "BG",  # Bulgaria
    "Q229": "CY",  # Cyprus
    "Q233": "MT",  # Malta
    "Q32":  "LU",  # Luxembourg
    "Q189": "IS",  # Iceland
}
US_QID = "Q30"
CN_QID = "Q148"
RU_QID = "Q159"


SPARQL_TEMPLATE = """\
SELECT ?item ?itemLabel ?countryLabel ?country ?licenseLabel ?developerLabel ?homepage WHERE {{
  ?item rdfs:label "{name}"@en .
  OPTIONAL {{ ?item wdt:P17 ?country . }}
  OPTIONAL {{ ?item wdt:P275 ?license . }}
  OPTIONAL {{ ?item wdt:P178 ?developer . }}
  OPTIONAL {{ ?item wdt:P856 ?homepage . }}
  ?item wdt:P31/wdt:P279* wd:Q341 .   # subclass of "free software" — broad
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
}}
LIMIT 5
"""


def map_country_to_origin(country_qid: str) -> str:
    if country_qid in EU_PLUS_QIDS:
        return "europe"
    if country_qid == US_QID:
        return "unitedStates"
    if country_qid == CN_QID:
        return "china"
    if country_qid == RU_QID:
        return "russia"
    return "other"


def query_one(name: str) -> dict | None:
    """Run a SPARQL query for one app. Skeleton only."""
    # Real implementation:
    # 1. POST query to https://query.wikidata.org/sparql
    #    with Accept: application/sparql-results+json
    # 2. Parse the bindings
    # 3. Pick the first result with both country + license
    # 4. Map country → origin via map_country_to_origin
    # 5. Return enriched record
    return None


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    args = p.parse_args(argv[1:])

    inputs = json.loads(Path(args.input).read_text())
    output = {
        "queried_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "input_count": len(inputs),
        "ok_count": 0,
        "entries": [],
    }

    for item in inputs:
        result = query_one(item.get("name", ""))
        if result:
            output["entries"].append(result)
            output["ok_count"] += 1

    Path(args.output).write_text(json.dumps(output, indent=2, ensure_ascii=False))
    print(f"Wrote {output['ok_count']} entries to {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
