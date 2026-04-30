#!/usr/bin/env python3
"""
v1.6.2: find UI strings in views that aren't in Localizable.xcstrings.

Walks Sources/SplynekCore/Views/*.swift, extracts every:
  - Text("...")            — SwiftUI auto-localizes string literals
  - .help("...")           — tooltip
  - .navigationTitle("...")
  - Label("...", systemImage:)
  - .accessibilityLabel("...")
  - LocalizedStringKey("...")

…then cross-references against the catalog's keys.  Reports strings
that aren't yet translated.

The output is meant for the maintainer to triage:
  - Genuinely user-visible? → add to Scripts/regenerate-localizations.py
  - Internal / debug? → mark as `# SKIP-L10N` next to the literal

Usage:
  python3 Scripts/find-missing-translations.py [--max <n>]
"""

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent
VIEWS_DIR = ROOT / "Sources" / "SplynekCore" / "Views"
CATALOG = ROOT / "Sources" / "SplynekCore" / "Localizable.xcstrings"

# Regex matching Swift string literals inside the calls we care about.
# We capture the string between quotes, allowing escaped quotes.
PATTERNS = [
    # Text("...") — most common
    re.compile(r'Text\(\s*"((?:[^"\\]|\\.)*)"\s*[,)]'),
    # Text("...", bundle:) etc
    re.compile(r'Text\(\s*"((?:[^"\\]|\\.)*)"\s*,'),
    # .help("...")
    re.compile(r'\.help\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
    # .navigationTitle("...")
    re.compile(r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
    # Label("...", systemImage:)
    re.compile(r'Label\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*systemImage:'),
    # Toggle("...", isOn:)
    re.compile(r'Toggle\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*isOn:'),
    # Picker("...", selection:)
    re.compile(r'Picker\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*selection:'),
    # Button("...", action:) or Button("...") { … }
    re.compile(r'Button\(\s*"((?:[^"\\]|\\.)*)"\s*[,)]'),
    # .accessibilityLabel("...")
    re.compile(r'\.accessibilityLabel\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
    # LocalizedStringKey("...")
    re.compile(r'LocalizedStringKey\(\s*"((?:[^"\\]|\\.)*)"\s*\)'),
]


def extract_strings(filepath: Path) -> set[str]:
    """Return every quoted string literal that's likely a localizable
    user-visible string in the file."""
    found = set()
    text = filepath.read_text()
    # Skip lines marked SKIP-L10N.
    lines = text.split("\n")
    for line in lines:
        if "SKIP-L10N" in line:
            continue
        for pat in PATTERNS:
            for m in pat.finditer(line):
                s = m.group(1)
                if not s.strip():
                    continue
                # Ignore strings that are mostly format specifiers.
                if re.fullmatch(r'[%@\s\d.]+', s):
                    continue
                # Ignore single-character punctuation/glyphs.
                if len(s) <= 2 and not s.isalnum():
                    continue
                # Ignore SF Symbols (no space, lowercase + dot).
                if re.fullmatch(r'[a-z0-9.]+', s) and len(s) < 30:
                    continue
                found.add(s)
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--max", type=int, default=200)
    args = parser.parse_args()

    catalog = json.loads(CATALOG.read_text())
    catalog_keys = set(catalog.get("strings", {}).keys())

    # Walk every Swift file in Views/.
    by_file = {}
    for swift in sorted(VIEWS_DIR.rglob("*.swift")):
        strings = extract_strings(swift)
        missing = strings - catalog_keys
        if missing:
            by_file[swift.relative_to(ROOT)] = sorted(missing)

    total_missing = sum(len(v) for v in by_file.values())
    print(f"Found {total_missing} unique strings missing from catalog "
          f"across {len(by_file)} files")
    print(f"Catalog currently has {len(catalog_keys)} strings\n")

    shown = 0
    for path, strings in by_file.items():
        if shown >= args.max:
            print(f"\n…(truncated; pass --max {total_missing} to see all)")
            return
        print(f"\n{path}:")
        for s in strings:
            if shown >= args.max:
                break
            # Truncate display of very long strings.
            display = s if len(s) < 120 else s[:117] + "..."
            print(f"  {display!r}")
            shown += 1


if __name__ == "__main__":
    main()
