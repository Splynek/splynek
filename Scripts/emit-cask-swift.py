#!/usr/bin/env python3
"""
emit-cask-swift.py — convert Scripts/cask-import.json into a Swift
file that the SovereigntyView contribute flow consults.

The 4731-entry cask catalog is too unverified to promote into
SovereigntyCatalog (the hand-curated table) — many are proprietary,
some have wrong bundle-ID guesses, license metadata isn't extracted.

But the data IS useful for:

1. Pre-filling the "Contribute this app" GitHub issue body with
   real metadata Splynek already has — homepage, downloadURL,
   category hint.  Less typing for the contributor.
2. Enriching the "We don't know yet" disclosure: when the cask
   table HAS the app, we can show its real name + homepage + a
   "Has Homebrew Cask data, license unverified" badge.

This script emits Sources/SplynekCore/SovereigntyCatalog+CaskHints.swift
with a static lookup table keyed by bundleID.  Only entries that
have BOTH a bundle-ID guess AND a download URL are kept (~86%).

USAGE
-----
After running import-from-homebrew-cask.py:

    python3 Scripts/emit-cask-swift.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def escape(value: str) -> str:
    """Swift string-literal escape."""
    return (value
            .replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\r", "\\r"))


def main() -> int:
    repo = Path(__file__).parent.parent
    src = repo / "Scripts" / "cask-import.json"
    if not src.is_file():
        print(f"error: {src} not found — run import-from-homebrew-cask.py first", file=sys.stderr)
        return 1

    data = json.loads(src.read_text())
    entries = data["entries"]
    # Keep only entries with both a bundle-ID guess + a download URL.
    # Without bundle ID we can't match against scanner output;
    # without a download URL the contribute flow gets no extra value.
    keep = [
        e for e in entries
        if e.get("bundle_id_guess") and e.get("download_url")
        and e["download_url"].startswith("http")
    ]

    print(f"  Total cask entries:       {len(entries)}")
    print(f"  After bundle+URL filter:  {len(keep)}")

    # Sort by bundleID for stable diffs.
    keep.sort(key=lambda e: e["bundle_id_guess"].lower())

    # 2026-05-08 v3: emit JSON resource, NOT a Swift literal.
    # Reason: 4088-entry Swift array literals OOM swiftc's
    # constraint solver (200 GB RAM during compile).  Same data as
    # JSON parses in <50ms at first access.
    json_out = repo / "Sources" / "SplynekCore" / "Resources" / "cask-hints.json"
    json_out.parent.mkdir(parents=True, exist_ok=True)
    json_payload = {
        "schemaVersion": 1,
        "generatedAt": data.get("imported_at", ""),
        "caskCountTotal": data.get("cask_count_total", 0),
        "hints": [
            {
                "bundleID": e["bundle_id_guess"],
                "caskToken": e["cask_token"],
                "name": e["name"],
                "homepage": e["homepage"],
                "downloadURL": e["download_url"],
                "categoryHint": e.get("category_hint") or None,
            }
            for e in keep
            if e.get("homepage", "").startswith("http")
        ],
    }
    json_out.write_text(json.dumps(json_payload, indent=2, ensure_ascii=False))
    print(f"  Wrote {json_out}")
    print(f"  JSON hints:  {len(json_payload['hints'])}")

    # The thin runtime loader.  No embedded data — reads + parses
    # cask-hints.json from the SwiftPM resource bundle on first call.
    loader = repo / "Sources" / "SplynekCore" / "SovereigntyCatalog+CaskHints.swift"
    loader_src = """// Copyright © 2026 Splynek. MIT.
//
// SovereigntyCatalog+CaskHints — runtime loader for the auto-imported
// Homebrew Cask metadata.
//
// Storage: Resources/cask-hints.json, processed by SwiftPM via
// `.process("Resources/cask-hints.json")` in Package.swift.  The
// embedded JSON file is the single source of truth — regenerate with
// `python3 Scripts/emit-cask-swift.py` after refreshing the cask
// snapshot.
//
// Why JSON, not a Swift literal?  Two prior attempts at a
// `static let caskHints: [CaskHint] = [...]` literal blew up swiftc's
// constraint solver: 4088 entries triggered exponential type-check
// paths and OOM'd at 200 GB during compile.  JSON parses in <50ms on
// first access; the compiler does no work on the data.
//
// Architectural note: this is NOT promoted to SovereigntyCatalog
// because cask metadata is community-maintained + license info isn't
// extracted.  These hints power the Contribute flow + the "We don't
// know yet" disclosure — they help the user, not the catalog itself.

import Foundation

/// One auto-imported metadata record from Homebrew Cask.
struct CaskHint: Hashable, Sendable, Codable {
    let bundleID: String
    let caskToken: String
    let name: String
    let homepageString: String
    let downloadURLString: String
    let categoryHint: String?

    var homepage: URL? { URL(string: homepageString) }
    var downloadURL: URL? { URL(string: downloadURLString) }

    enum CodingKeys: String, CodingKey {
        case bundleID, caskToken, name
        case homepageString = "homepage"
        case downloadURLString = "downloadURL"
        case categoryHint
    }
}

extension SovereigntyCatalog {

    /// Look up Homebrew Cask metadata for a bundle ID, when available.
    /// Returns nil for apps not in the cask snapshot.  O(1) after the
    /// one-time index build on first call.
    static func caskHint(forBundleID bundleID: String) -> CaskHint? {
        caskHintsIndex[bundleID]
    }

    /// Number of cask hints loaded.  Surfaced in the Sovereignty
    /// empty-state copy so users see the magnitude of the gap-filler.
    static var caskHintCount: Int { caskHints.count }

    /// Flat array of every cask-imported hint.  Loaded lazily from
    /// the resource JSON on first access.  Empty if the resource is
    /// missing or the JSON is malformed (defensive — we never crash
    /// at startup over an optional enrichment dataset).
    static let caskHints: [CaskHint] = {
        struct Envelope: Decodable {
            let schemaVersion: Int
            let hints: [CaskHint]
        }
        // Cross-build-system lookup mirroring Splynek's .splynekCore
        // pattern.  In SwiftPM builds the resource lives under the
        // generated Splynek_SplynekCore.bundle; in Xcode-managed MAS
        // builds it's bundled at the .app's main Resources/.
        let candidates: [Bundle] = [
            .splynekCore,
            .main,
        ]
        for bundle in candidates {
            if let url = bundle.url(forResource: "cask-hints",
                                    withExtension: "json")
                ?? bundle.url(forResource: "cask-hints",
                              withExtension: "json",
                              subdirectory: "Resources"),
               let data = try? Data(contentsOf: url),
               let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
               envelope.schemaVersion <= 1
            {
                return envelope.hints
            }
        }
        return []
    }()

    /// Lazy bundleID-keyed index.  Built once on first access via a
    /// for-loop over `caskHints` — Dictionary literal would hit the
    /// same exponential path that broke the all-Swift attempt.
    private static let caskHintsIndex: [String: CaskHint] = {
        var dict = [String: CaskHint](minimumCapacity: caskHints.count)
        for hint in caskHints { dict[hint.bundleID] = hint }
        return dict
    }()
}
"""
    loader.write_text(loader_src)
    print(f"  Wrote {loader}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
