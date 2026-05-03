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
    # v1.9.x: Splynek-specific component-builder patterns whose
    # `subtitle:` / `title:` / `message:` parameters are typed as
    # LocalizedStringKey but were invisible to the previous regex
    # set.  Visual sweeps in DE+FR caught three real catalog gaps
    # because of this — the audit was clean while the running app
    # showed English strings on a German locale.  These regexes
    # close the gap.
    #
    # ContextCard(systemImage: "x", subtitle: "...", tint: ...)
    re.compile(r'ContextCard\([^)]*?subtitle:\s*"((?:[^"\\]|\\.)*)"'),
    # TitledCard(title: "...", systemImage: ...) or
    # TitledCard(title: "...") { … }
    re.compile(r'TitledCard\(\s*title:\s*"((?:[^"\\]|\\.)*)"'),
    # EmptyStateView(title: "...", message: "...", ...) — both
    # title + message are LocalizedStringKey.
    re.compile(r'EmptyStateView\([^)]*?title:\s*"((?:[^"\\]|\\.)*)"'),
    re.compile(r'EmptyStateView\([^)]*?message:\s*"((?:[^"\\]|\\.)*)"'),
    # MetricView(caption: "...", ...) — same shape.
    re.compile(r'MetricView\([^)]*?caption:\s*"((?:[^"\\]|\\.)*)"'),
    # StatusPill(text: "...", style: ...)
    re.compile(r'StatusPill\(\s*text:\s*"((?:[^"\\]|\\.)*)"'),
]


def _decode_swift_unicode_escapes(s: str) -> str:
    """Resolve Swift `\\u{XXXX}` escapes to the actual Unicode codepoint
    so the captured source-literal matches what Swift renders at
    runtime (and what the catalog key stores).  Round-7 caught a false
    positive where SettingsView used `\\u{201C}` / `\\u{201D}` for curly
    quotes — Swift collapses those to U+201C / U+201D before lookup,
    but our regex captured the 6-character escape.  Without this pass,
    the audit reports a phantom "missing" key."""
    return re.sub(
        r'\\u\{([0-9A-Fa-f]+)\}',
        lambda m: chr(int(m.group(1), 16)),
        s,
    )


# Heuristic: which Swift expressions look numeric (→ %lld) vs string (→ %@).
# Conservative — when in doubt, treat as %@; the audit only uses this for
# membership checking, so over-broadening just means a key that's in the
# catalog won't be flagged.
_NUM_HINTS = re.compile(
    r'\b(?:count|length|capacity|size|n|num|points|value|version|port|days?|seconds?'
    r'|Int|UInt|Double|Float|CGFloat)\b|\.count\b|\* \d|\+ \d',
    re.IGNORECASE,
)


def _strip_swift_interps(s: str, replace_with=None):
    """Walk `s` left-to-right, find every `\\(...)` Swift interpolation
    using a paren-balanced scanner (handles arbitrary nesting depth —
    a regex can't), and either remove them (replace_with=None) or
    replace each with the result of `replace_with(expr_text, slot_num)`.

    Returns the rewritten string."""
    out = []
    i = 0
    slot = 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s) and s[i+1] == '(':
            # Found `\(`; walk forward maintaining paren depth until
            # we close the outer paren.
            depth = 1
            j = i + 2
            while j < len(s) and depth > 0:
                if s[j] == '(':
                    depth += 1
                elif s[j] == ')':
                    depth -= 1
                j += 1
            if depth == 0:
                expr = s[i+2 : j-1]
                slot += 1
                if replace_with is not None:
                    out.append(replace_with(expr, slot))
                # else: drop the interpolation entirely.
                i = j
                continue
        out.append(s[i])
        i += 1
    return "".join(out)


def _swift_interp_to_format_specs(s: str) -> str:
    """Normalize `\\(expr)` → `%@` / `%lld` so the captured literal can
    match a format-spec catalog key.  Round 8 catalog entries are keyed
    in format-spec form (Apple's convention for xcstrings); without this
    normalization the audit reports `'Open \\(host) in your browser'` as
    missing even though `'Open %@ in your browser'` is in the catalog.

    Heuristic: expressions matching the numeric-hint regex map to %lld;
    everything else maps to %@.  When the same line has multiple
    interpolations, we use positional %1$@ / %2$@ form so order is
    preserved and translators can rearrange."""
    # First pass: tag each interpolation's slot + spec.
    specs = []
    def _tag(expr, slot):
        is_num = bool(_NUM_HINTS.search(expr))
        specs.append("%lld" if is_num else "%@")
        return f"\x00SLOT{slot}\x00"
    placeholder = _strip_swift_interps(s, replace_with=_tag)

    if len(specs) <= 1:
        for spec in specs:
            placeholder = placeholder.replace("\x00SLOT1\x00", spec, 1)
        return placeholder

    # Multiple interpolations: use positional `%N$@` so translators can
    # rearrange.  Numeric specs become %N$lld.
    for i, spec in enumerate(specs, start=1):
        positional = f"%{i}$lld" if spec == "%lld" else f"%{i}$@"
        placeholder = placeholder.replace(f"\x00SLOT{i}\x00", positional, 1)
    return placeholder


def _is_pure_interpolation(s: str) -> bool:
    """Return True if the string is just `\\(...)` interpolations and
    optional surrounding whitespace/punctuation — i.e. nothing
    translatable.  Examples: `\\(count)`, `\\(n) days`, `v\\(version)`,
    `Port \\(seed.port)`.

    A pure-interpolation string with NO non-interpolation letters is
    runtime data, not UI copy, and shouldn't be flagged.  But strings
    like `\\(n) days` DO have translatable text ('days') and are NOT
    pure — those still need a catalog entry."""
    stripped = _strip_swift_interps(s)
    # Anything left over that's a letter (not just digit/punct/space)?
    return not re.search(r'[A-Za-zÀ-ÿ]', stripped)


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
                # v1.6.2: decode Swift `\u{XXXX}` escapes so the
                # captured literal matches the catalog key.
                s = _decode_swift_unicode_escapes(s)
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
                # v1.6.2: skip pure-interpolation strings — they're
                # runtime values (counts, versions, ports), not copy.
                if _is_pure_interpolation(s):
                    continue
                found.add(s)
    return found


def normalize_keys(s: str) -> set[str]:
    """Return every catalog-key form a captured literal might match.

    - The literal itself (covers exact-match keys).
    - The format-spec normalized form (`\\(...)` → `%@` / `%lld`) using
      the numeric-hint heuristic.
    - A "type-blind" wildcard form: emit BOTH the all-`%@` and all-`%lld`
      variants so a captured `Text("Clear \\(finishedTotal) finished")`
      matches either `"Clear %lld finished"` (the actual catalog key,
      since the value is Int) OR `"Clear %@ finished"`.  This is
      pragmatic — the audit's job is membership-testing, and we can't
      always type-infer from the expression text alone.  We accept some
      breadth in the audit so the catalog can be keyed accurately."""
    out = {s, _swift_interp_to_format_specs(s)}
    # Count interpolations using the balanced scanner.
    counter = [0]
    _strip_swift_interps(s, replace_with=lambda _e, _n: (counter.__setitem__(0, counter[0] + 1) or ""))
    interp_count = counter[0]
    if interp_count >= 1:
        for spec in ("%@", "%lld"):
            if interp_count == 1:
                out.add(_strip_swift_interps(s, replace_with=lambda _e, _n, sp=spec: sp))
            else:
                # Positional form for multi-arg.
                out.add(_strip_swift_interps(
                    s,
                    replace_with=lambda _e, n, sp=spec: f"%{n}${sp[1:]}",
                ))
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--max", type=int, default=200)
    args = parser.parse_args()

    catalog = json.loads(CATALOG.read_text())
    catalog_keys = set(catalog.get("strings", {}).keys())

    # Walk every Swift file in Views/.  A string is "missing" only if
    # NEITHER its literal source-form NOR its format-spec-normalized
    # form is a catalog key.  Round 8 caught this: existing keys like
    # `"Open %@ in your browser"` were being re-flagged from sources
    # like `Text("Open \(host) in your browser")`.
    by_file = {}
    for swift in sorted(VIEWS_DIR.rglob("*.swift")):
        strings = extract_strings(swift)
        missing = sorted(
            s for s in strings
            if not (normalize_keys(s) & catalog_keys)
        )
        if missing:
            by_file[swift.relative_to(ROOT)] = missing

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
