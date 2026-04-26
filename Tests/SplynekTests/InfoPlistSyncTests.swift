import Foundation

/// v1.5.4: invariant test that catches the bug we shipped twice in
/// v1.4 + v1.5.x — `Resources/Info.plist` (used by the SPM/DMG build)
/// got out-of-sync with `project.yml`'s MARKETING_VERSION (used by
/// the XcodeGen/MAS build) and Alfred workflow's `info.plist`.
///
/// Result: DMGs landed on GitHub Releases marked CFBundleShortVersionString
/// 1.3 even though the user thought they were shipping 1.4 / 1.5.x.
/// Caught only at v1.5.3 release time when checking `plutil` on the
/// freshly-built bundle.
///
/// This test pulls the version string out of all three plist sources
/// and confirms they match.  Adding a new version-bearing file?  Add
/// it to the `versionSources` array below.
enum InfoPlistSyncTests {

    static func run() {
        TestHarness.suite("Version-string sync across all plists") {
            let sources = versionSources()

            TestHarness.test("Every version-bearing file is readable") {
                for s in sources {
                    try expect(
                        s.version != nil,
                        "Could not extract version from \(s.path)"
                    )
                }
            }

            TestHarness.test("All version strings agree") {
                let unique = Set(sources.compactMap { $0.version })
                if unique.count > 1 {
                    let report = sources.map {
                        "  \($0.path): \($0.version ?? "<nil>")"
                    }.joined(separator: "\n")
                    try expect(
                        false,
                        "Version mismatch — DMG/MAS/Alfred bundles will ship as different versions:\n\(report)"
                    )
                }
            }

            TestHarness.test("All version strings are non-empty + look like X.Y(.Z)") {
                let pattern = #"^\d+\.\d+(\.\d+)?$"#
                let regex = try NSRegularExpression(pattern: pattern)
                for s in sources {
                    guard let v = s.version else { continue }
                    let range = NSRange(v.startIndex..., in: v)
                    try expect(
                        regex.firstMatch(in: v, range: range) != nil,
                        "\(s.path) version '\(v)' doesn't look like X.Y or X.Y.Z"
                    )
                }
            }
        }
    }

    // MARK: - Sources

    private struct Source {
        let path: String
        let version: String?
    }

    /// Walks the repo (looking up from the test binary's working
    /// directory) to find every plist / yaml that carries a version
    /// string Splynek ships.  When adding a new version source, append
    /// a `Source(path:version:)` here.
    private static func versionSources() -> [Source] {
        let root = repoRoot()
        return [
            Source(
                path: "Resources/Info.plist",
                version: readInfoPlist(at: root + "/Resources/Info.plist",
                                       key: "CFBundleShortVersionString")
            ),
            Source(
                path: "project.yml",
                version: readYAMLValue(at: root + "/project.yml",
                                       key: "MARKETING_VERSION")
            ),
            Source(
                path: "Extensions/Alfred/Splynek.alfredworkflow/info.plist",
                version: readInfoPlist(at: root + "/Extensions/Alfred/Splynek.alfredworkflow/info.plist",
                                       key: "CFBundleShortVersionString")
            ),
        ]
    }

    /// Best-effort repo-root resolver.  `swift run splynek-test` runs
    /// from the package root in normal operation; if that's wrong we
    /// walk up looking for the canonical marker file.
    private static func repoRoot() -> String {
        let fm = FileManager.default
        var dir = fm.currentDirectoryPath
        for _ in 0..<6 {
            if fm.fileExists(atPath: dir + "/Package.swift")
                && fm.fileExists(atPath: dir + "/project.yml") {
                return dir
            }
            dir = (dir as NSString).deletingLastPathComponent
            if dir == "/" { break }
        }
        return fm.currentDirectoryPath
    }

    /// Read a plist value via PropertyListSerialization.  Avoids the
    /// `plutil` shell-out so the test stays pure-Swift + sandbox-safe.
    private static func readInfoPlist(at path: String, key: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist[key] as? String
    }

    /// Read a value from project.yml without taking on a YAML dep.
    /// project.yml's structure is well-known + line-oriented; the
    /// MARKETING_VERSION line looks like:
    ///     MARKETING_VERSION: "1.5.3"
    /// or  MARKETING_VERSION: 1.5.3
    /// Either with or without quotes; YAML accepts both.
    private static func readYAMLValue(at path: String, key: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        for raw in content.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix(key + ":") else { continue }
            let after = line.dropFirst(key.count + 1)
                .trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes if present.
            if after.hasPrefix("\"") && after.hasSuffix("\"") && after.count >= 2 {
                return String(after.dropFirst().dropLast())
            }
            if after.hasPrefix("'") && after.hasSuffix("'") && after.count >= 2 {
                return String(after.dropFirst().dropLast())
            }
            return after
        }
        return nil
    }
}
