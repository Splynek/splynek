import Foundation

/// v1.6.2: catalog completeness invariant.  Catches the entire class of
/// future-regression where a contributor adds a new key to
/// `Localizable.xcstrings` (directly or via `Scripts/regenerate-
/// localizations.py`) but forgets to fill in one of the locales.  Without
/// this guard, the missing locale silently falls back to English at
/// runtime — easy to ship, hard to spot, embarrassing in a market we
/// claim to support natively.
///
/// What this checks:
///   - Every key present in the catalog has a translation entry for
///     every required locale (en + pt-PT + es + fr + de + it).
///   - The translation string is non-empty.
///   - Source-locale (en) is implicit via the key itself; if a key has
///     no `localizations.{locale}.stringUnit.value`, that's the bug.
///
/// What this does NOT check:
///   - Translation quality (Claude-generated; native-speaker review is
///     a separate human pass — see NATIVE-REVIEW.md if it exists).
///   - That every Swift `Text("...")` literal has a matching catalog
///     key.  That's `Scripts/find-missing-translations.py` — runs in CI
///     via the lint workflow, not here.
enum LocalizableCatalogTests {

    /// The locales Splynek commits to shipping at v1.6+.  Adding a new
    /// locale: append it here AND grow the catalog data in
    /// `Scripts/regenerate-localizations.py`.  Removing a locale: drop
    /// it from BOTH places (and from `Package.swift`'s
    /// `defaultLocalization` list if applicable).
    static let requiredLocales: Set<String> = ["pt-PT", "es", "fr", "de", "it"]

    static func run() {
        TestHarness.suite("Localizable.xcstrings completeness") {
            guard let catalog = loadCatalog() else {
                TestHarness.test("Catalog is loadable") {
                    try expect(false, "Could not load Localizable.xcstrings — wrong working dir or file missing.")
                }
                return
            }

            TestHarness.test("Catalog has at least 400 entries (regression floor)") {
                try expect(
                    catalog.count >= 400,
                    "Catalog shrank below 400 entries (\(catalog.count)) — round-7 floor.  Did someone delete keys?"
                )
            }

            TestHarness.test("Every key has all required locales filled") {
                var missing: [String: [String]] = [:]
                for (key, entry) in catalog {
                    let present = entry.locales
                    let absent = requiredLocales.subtracting(present)
                    if !absent.isEmpty {
                        missing[key] = absent.sorted()
                    }
                }
                if !missing.isEmpty {
                    let preview = missing
                        .sorted { $0.key < $1.key }
                        .prefix(10)
                        .map { "  \"\(truncate($0.key))\" → missing: \($0.value.joined(separator: ", "))" }
                        .joined(separator: "\n")
                    try expect(
                        false,
                        "\(missing.count) catalog key(s) miss one or more required locales:\n\(preview)\n…regenerate via Scripts/regenerate-localizations.py."
                    )
                }
            }

            TestHarness.test("No translation value is empty or whitespace-only") {
                var empty: [String] = []
                for (key, entry) in catalog {
                    for (loc, val) in entry.values {
                        if val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            empty.append("  \"\(truncate(key))\" [\(loc)]")
                            if empty.count > 10 { break }
                        }
                    }
                    if empty.count > 10 { break }
                }
                if !empty.isEmpty {
                    try expect(
                        false,
                        "Empty / whitespace-only translation values:\n\(empty.joined(separator: "\n"))"
                    )
                }
            }

            TestHarness.test("Every required locale ships ≥ 95% of total keys") {
                // Belt-and-braces with the per-key check: catches mass
                // omission like "I forgot to add `it` to a whole batch."
                var counts: [String: Int] = [:]
                for entry in catalog.values {
                    for loc in entry.locales {
                        counts[loc, default: 0] += 1
                    }
                }
                let total = catalog.count
                let floor = Int(Double(total) * 0.95)
                for loc in requiredLocales {
                    let n = counts[loc] ?? 0
                    try expect(
                        n >= floor,
                        "Locale \(loc) ships \(n)/\(total) (\(percent(n, total))%) — below 95% floor."
                    )
                }
            }
        }
    }

    // MARK: – Catalog loading + value extraction

    /// Per-key view: which locales are present, and the actual values.
    fileprivate struct Entry {
        let locales: Set<String>
        let values: [(loc: String, val: String)]
    }

    fileprivate static func loadCatalog() -> [String: Entry]? {
        let candidates: [URL] = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/SplynekCore/Localizable.xcstrings"),
            // Fallback for in-tree test runs from arbitrary cwd.
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/SplynekCore/Localizable.xcstrings"),
        ]
        var url: URL?
        for c in candidates where FileManager.default.fileExists(atPath: c.path) {
            url = c
            break
        }
        guard let found = url,
              let data = try? Data(contentsOf: found),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = json["strings"] as? [String: Any]
        else { return nil }

        var out: [String: Entry] = [:]
        for (key, raw) in strings {
            guard let dict = raw as? [String: Any] else { continue }
            let localizations = dict["localizations"] as? [String: Any] ?? [:]

            var locs = Set<String>()
            var vals: [(loc: String, val: String)] = []
            for (loc, payload) in localizations {
                guard
                    let p = payload as? [String: Any],
                    let unit = p["stringUnit"] as? [String: Any],
                    let v = unit["value"] as? String
                else { continue }
                locs.insert(loc)
                vals.append((loc, v))
            }
            out[key] = Entry(locales: locs, values: vals)
        }
        return out
    }

    fileprivate static func truncate(_ s: String, limit: Int = 60) -> String {
        s.count <= limit ? s : String(s.prefix(limit)) + "…"
    }

    fileprivate static func percent(_ n: Int, _ total: Int) -> Int {
        total == 0 ? 0 : Int((Double(n) / Double(total)) * 100)
    }
}
