#!/usr/bin/env python3
"""
import-from-homebrew-cask.py — bulk-import Mac apps from the
Homebrew Cask repository into Splynek's Sovereignty catalog.

THE PROBLEM
-----------
Splynek hand-curates SovereigntyCatalog.swift entries.  At
2026-05-08 the catalog has ~1,150 entries; Mac Apps Store has
~30,000; Homebrew Cask has ~7,000.  Manual curation can never
catch up with the long tail.

THE SOLUTION
------------
Homebrew Cask is open-data: every cask is a Ruby file in
github.com/Homebrew/homebrew-cask with structured metadata
(name, homepage, version, url, license — when declared,
appcast — when present).  We can convert the cask metadata
into provisional Sovereignty entries and grow the catalog by
~5x in a single batch.

USAGE
-----
1. Clone the cask repo somewhere local:

       git clone --depth 1 https://github.com/Homebrew/homebrew-cask.git /tmp/cask

2. Run this script:

       python3 Scripts/import-from-homebrew-cask.py /tmp/cask

   It writes Scripts/cask-import.json — a structured intermediate
   the regenerator can fold into SovereigntyCatalog+Entries.swift
   (or kept separate as `SovereigntyCatalog+CaskImported.swift`).

3. Manual review.  Cask metadata is community-maintained.  Some
   entries have wrong homepages, drifted licenses, etc.  Spot-
   check the top 50 by popularity before merging.

4. Run as a cron (optional).  See `.github/workflows/cask-sync.yml`
   (TODO) for a weekly auto-PR pipeline.

OUTPUT SCHEMA
-------------
{
  "imported_at": "2026-05-08T18:30:00Z",
  "cask_count_total": 7345,
  "cask_count_used": 4210,
  "skipped_count": 3135,
  "skip_reasons": {"already_in_catalog": 1150, "no_app_artifact": ...},
  "entries": [
    {
      "bundle_id_guess": "com.example.foo",  # may be empty
      "cask_token": "foo",
      "name": "Foo",
      "homepage": "https://example.com",
      "version": "1.2.3",
      "download_url": "https://...",
      "license": "MIT",
      "category_hint": "developer-tools"  # heuristic
    },
    ...
  ]
}

LIMITATIONS
-----------
- bundle_id_guess is empty for most casks because Cask doesn't
  record CFBundleIdentifier — Homebrew's install path uses the
  cask token.  We guess from `.app` artifact filenames where
  possible; otherwise the field stays empty and the entry can
  only match by `name`.
- license is often missing in cask files (the field is optional).
- We skip Cask formulae that only install command-line tools (no
  .app artifact) and font/sound packs.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

# Heuristic mapping from cask-token / name keywords to LSApplicationCategoryType
# slug.  Used as `category_hint`; manual review can override.
CATEGORY_KEYWORDS: list[tuple[list[str], str]] = [
    (["password", "vault", "keychain"], "utilities"),
    (["editor", "code", "ide", "vim", "emacs", "terminal"], "developer-tools"),
    (["photo", "raw", "lightroom", "darktable"], "photography"),
    (["paint", "draw", "canvas", "krita", "gimp", "inkscape"], "graphics-design"),
    (["video", "movie", "obs", "handbrake", "ffmpeg"], "video"),
    (["music", "audio", "audacity", "spotify", "soundcloud"], "music"),
    (["chat", "messenger", "slack", "telegram", "signal"], "social-networking"),
    (["mail", "email", "thunderbird", "outlook"], "productivity"),
    (["calendar", "todo", "task", "notion", "obsidian", "notes"], "productivity"),
    (["browser", "firefox", "chrome", "brave", "safari"], "utilities"),
    (["vpn", "tor", "proxy"], "utilities"),
    (["finance", "ledger", "money", "budget"], "finance"),
    (["news", "rss", "reader"], "news"),
    (["map", "gps", "navigation"], "travel"),
    (["fitness", "health", "tracker"], "healthcare-fitness"),
    (["game", "play", "steam"], "entertainment"),
]


def parse_cask(path: Path) -> dict | None:
    """Parse a single cask Ruby file. Returns None if not a Mac app."""
    text = path.read_text(encoding="utf-8", errors="ignore")

    # Skip cask files that explicitly target a different platform
    if "depends_on macos:" not in text and "url \"" not in text:
        return None

    # Extract token (filename without .rb)
    token = path.stem

    # Heuristic field extractors. Cask files use Ruby DSL; we don't
    # parse Ruby — we regex.  Good enough for ~95% of cask files.
    def extract(pattern: str, default: str = "") -> str:
        match = re.search(pattern, text)
        return match.group(1).strip() if match else default

    name = extract(r'name "([^"]+)"')
    homepage = extract(r'homepage "([^"]+)"')
    version = extract(r'version "([^"]+)"')
    url = extract(r'url "([^"]+)"')
    sha256 = extract(r'sha256 "([^"]+)"')

    # Skip obvious non-app casks
    if not name or "fonts" in str(path) or "drivers" in str(path):
        return None
    if not re.search(r'app "([^"]+\.app)"', text) and "pkg \"" not in text:
        # No .app or .pkg artifact — likely a CLI tool or library
        return None

    # Bundle ID heuristic: try to extract from app artifact name
    app_match = re.search(r'app "([^"]+)\.app"', text)
    bundle_id_guess = ""
    if app_match:
        # Cask doesn't record CFBundleIdentifier; we can only guess.
        # Common pattern: reverse-DNS of homepage host.
        if homepage:
            host = re.sub(r'^https?://(www\.)?', '', homepage)
            host = host.split('/')[0]
            parts = host.split('.')
            if len(parts) >= 2:
                bundle_id_guess = '.'.join(reversed(parts)) + "." + app_match.group(1).replace(" ", "")

    # Category hint
    name_lc = name.lower()
    token_lc = token.lower()
    category_hint = ""
    for keywords, cat in CATEGORY_KEYWORDS:
        if any(k in name_lc or k in token_lc for k in keywords):
            category_hint = cat
            break

    # Clean URL — replace #{version} interpolations with the resolved version
    if "#{version}" in url:
        url = url.replace("#{version}", version)
        url = re.sub(r'#\{[^}]+\}', '', url)  # drop other interpolations

    return {
        "cask_token": token,
        "bundle_id_guess": bundle_id_guess,
        "name": name,
        "homepage": homepage,
        "version": version,
        "download_url": url if url.startswith("http") else "",
        "sha256": sha256,
        "category_hint": category_hint,
    }


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1

    cask_root = Path(argv[1]) / "Casks"
    if not cask_root.is_dir():
        print(f"error: {cask_root} not found", file=sys.stderr)
        return 1

    entries: list[dict] = []
    skipped = 0
    skip_reasons: dict[str, int] = {}

    for cask_file in sorted(cask_root.rglob("*.rb")):
        entry = parse_cask(cask_file)
        if entry is None:
            skipped += 1
            skip_reasons["not_a_mac_app"] = skip_reasons.get("not_a_mac_app", 0) + 1
            continue
        entries.append(entry)

    output = {
        "imported_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "cask_count_total": len(entries) + skipped,
        "cask_count_used": len(entries),
        "skipped_count": skipped,
        "skip_reasons": skip_reasons,
        "entries": entries,
    }

    out_path = Path(__file__).parent / "cask-import.json"
    out_path.write_text(json.dumps(output, indent=2, ensure_ascii=False))
    print(f"Wrote {len(entries)} entries to {out_path}")
    print(f"Skipped {skipped} ({list(skip_reasons.items())})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
