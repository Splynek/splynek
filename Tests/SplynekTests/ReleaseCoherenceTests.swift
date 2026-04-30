import Foundation
@testable import SplynekCore

/// v1.5.6+: invariant test that catches the *broader* drift class
/// `InfoPlistSyncTests` cannot — when commit subjects, CHANGELOG
/// entries, and HANDOFF prose claim a "shipped vN.N.N" that has no
/// corresponding git tag or DMG.
///
/// We've now hit this twice:
///
///   1. v1.4 → v1.5.x (April 2026): three commits with subject
///      `vN.N.N` shipped only as commits, never tagged.  Fixed in
///      v1.5.6 audit pass.
///   2. v1.5.4–v1.5.6 (April 2026): commits subject-tagged but the
///      latest git tag was still v1.5.3.  HANDOFF claimed "shipped
///      v1.5.4" but no v1.5.4 tag, no DMG, no notarisation.
///
/// `InfoPlistSyncTests` checks plist-vs-yaml-vs-Alfred agreement.
/// This test asserts a stronger invariant: **the version declared in
/// `Resources/Info.plist` must equal either the latest git tag, or a
/// pre-release version that's strictly greater than the latest tag.**
/// If `CFBundleShortVersionString = X.Y.Z` and there's no tag `vX.Y.Z`
/// yet, that's fine — we're staging an unreleased build.  But if the
/// plist version is *equal to or less than* an older tag, something
/// has rewound.
///
/// Also asserts: **the latest CHANGELOG `## vN.N.N` heading must be
/// >= `Resources/Info.plist`'s version.** A higher CHANGELOG without
/// the matching plist bump is the classic "wrote the changelog,
/// forgot to bump the version" trap.
///
/// This test relies on `git` being available on PATH.  In sandboxed
/// CI runs that strip git, the test is *skipped* with a printed
/// notice rather than failing — the alternative would be unreliable
/// failures in the very environments that need this least.
enum ReleaseCoherenceTests {

    static func run() {
        TestHarness.suite("Release coherence (tag ↔ plist ↔ CHANGELOG)") {

            let root = repoRoot()
            let plistVersion = readInfoPlistVersion(root: root)
            let changelogVersion = readLatestChangelogVersion(root: root)
            let latestTag = latestSemverTag(root: root)

            TestHarness.test("Info.plist version is parseable as semver") {
                try expect(
                    plistVersion != nil,
                    "Could not read CFBundleShortVersionString from Resources/Info.plist"
                )
                guard let v = plistVersion else { return }
                try expect(
                    parseSemver(v) != nil,
                    "Info.plist version '\(v)' is not parseable as X.Y.Z semver"
                )
            }

            TestHarness.test("CHANGELOG latest entry is parseable as semver") {
                try expect(
                    changelogVersion != nil,
                    "Could not find a `## vN.N.N` heading in CHANGELOG.md"
                )
                guard let v = changelogVersion else { return }
                try expect(
                    parseSemver(v) != nil,
                    "CHANGELOG latest entry '\(v)' is not parseable as X.Y.Z semver"
                )
            }

            TestHarness.test("CHANGELOG latest entry matches Info.plist version") {
                guard let p = plistVersion, let c = changelogVersion else { return }
                try expect(
                    p == c,
                    """
                    Info.plist version '\(p)' but CHANGELOG latest is '\(c)'.
                    These must match — otherwise we either bumped the plist without
                    documenting the release, or wrote a changelog entry without bumping
                    the binary.
                    """
                )
            }

            TestHarness.test("Info.plist version is >= latest git tag") {
                guard
                    let p = plistVersion,
                    let pSem = parseSemver(p)
                else { return }
                guard let tag = latestTag, let tSem = parseSemver(tag) else {
                    print("    ℹ  Skipping git-tag comparison (no git or no semver tags found)")
                    return
                }
                let cmp = compareSemver(pSem, tSem)
                try expect(
                    cmp >= 0,
                    """
                    Info.plist version '\(p)' is OLDER than the latest git tag 'v\(tag)'.
                    Did a release get reverted?  Bump the plist forward, or revert the tag.
                    """
                )
            }

            TestHarness.test("SplynekVersion.fallback matches Info.plist") {
                guard let p = plistVersion else { return }
                try expect(
                    SplynekVersion.fallback == p,
                    """
                    SplynekVersion.fallback ('\(SplynekVersion.fallback)') drifted \
                    from Info.plist ('\(p)').  Bump SplynekVersion.fallback to match \
                    or screenshots taken without an .app bundle (e.g. `swift run`) \
                    will show the wrong version.
                    """
                )
            }

            TestHarness.test("HEAD commit subject doesn't claim a version > Info.plist") {
                guard
                    let p = plistVersion,
                    let pSem = parseSemver(p)
                else { return }
                guard let subject = headCommitSubject(root: root) else {
                    print("    ℹ  Skipping HEAD-commit check (no git available)")
                    return
                }
                // Look for the canonical "vN.N.N" prefix in the subject.
                guard let claimedRaw = extractVersionFromSubject(subject) else { return }
                guard let claimedSem = parseSemver(claimedRaw) else { return }
                let cmp = compareSemver(claimedSem, pSem)
                try expect(
                    cmp <= 0,
                    """
                    HEAD commit subject claims 'v\(claimedRaw)' but Info.plist is '\(p)'.
                    Either bump Info.plist to match, or rewrite the commit subject.
                    Mismatched commit subjects are how 'shipped vN.N.N' lies into HANDOFF.md.
                    """
                )
            }
        }
    }

    // MARK: - Filesystem readers

    private static func repoRoot() -> String {
        let fm = FileManager.default
        var dir = fm.currentDirectoryPath
        for _ in 0..<6 {
            if fm.fileExists(atPath: dir + "/Package.swift")
                && fm.fileExists(atPath: dir + "/CHANGELOG.md") {
                return dir
            }
            dir = (dir as NSString).deletingLastPathComponent
            if dir == "/" { break }
        }
        return fm.currentDirectoryPath
    }

    private static func readInfoPlistVersion(root: String) -> String? {
        let path = root + "/Resources/Info.plist"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist["CFBundleShortVersionString"] as? String
    }

    /// Pull the version from the topmost `## vN.N.N` heading in
    /// CHANGELOG.md.  We tolerate optional trailing context after the
    /// version like `## v1.5.6 — weekly workflow hardening (...)`.
    private static func readLatestChangelogVersion(root: String) -> String? {
        let path = root + "/CHANGELOG.md"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8)
        else { return nil }
        for raw in content.split(separator: "\n") {
            let line = String(raw)
            // Top-level releases use "## vN.N.N" — second-level headings.
            // First-level "# Splynek changelog" gets skipped by hasPrefix.
            guard line.hasPrefix("## v") else { continue }
            let after = line.dropFirst(4)  // drop "## v"
            let versionRun = after.prefix { $0.isNumber || $0 == "." }
            let v = String(versionRun)
            if !v.isEmpty { return v }
        }
        return nil
    }

    // MARK: - git readers

    /// Latest tag matching `vX.Y` or `vX.Y.Z`.  Strips the leading
    /// `v`.  Returns nil if `git` isn't available or no tags exist.
    private static func latestSemverTag(root: String) -> String? {
        guard let out = runGit(args: ["tag", "--list", "v*", "--sort=-v:refname"],
                               cwd: root) else { return nil }
        for line in out.split(separator: "\n") {
            let raw = String(line).trimmingCharacters(in: .whitespaces)
            guard raw.hasPrefix("v") else { continue }
            let stripped = String(raw.dropFirst())
            if parseSemver(stripped) != nil { return stripped }
        }
        return nil
    }

    private static func headCommitSubject(root: String) -> String? {
        runGit(args: ["log", "-1", "--pretty=%s"], cwd: root)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "v1.5.6 — fix weekly workflow ..." → "1.5.6".  We only look at
    /// the first whitespace-separated token; if it starts with `v` and
    /// the rest is semver, that's our claim.
    private static func extractVersionFromSubject(_ subject: String) -> String? {
        let trimmed = subject.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.split(separator: " ").first else { return nil }
        var token = String(first)
        // Tolerate trailing punctuation: `v1.5.6:`, `v1.5.6 —`, etc.
        token = token.trimmingCharacters(in: CharacterSet(charactersIn: ":,;—–"))
        guard token.hasPrefix("v") else { return nil }
        let stripped = String(token.dropFirst())
        return parseSemver(stripped) != nil ? stripped : nil
    }

    private static func runGit(args: [String], cwd: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["git", "-C", cwd] + args
        let out = Pipe()
        let err = Pipe()
        task.standardOutput = out
        task.standardError = err
        do {
            try task.run()
        } catch {
            return nil
        }
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Semver parser (deliberately tiny)

    /// (major, minor, patch).  `1.5` → (1, 5, 0).
    private static func parseSemver(_ s: String) -> (Int, Int, Int)? {
        let parts = s.split(separator: ".")
        guard parts.count == 2 || parts.count == 3 else { return nil }
        guard let mj = Int(parts[0]), let mn = Int(parts[1]) else { return nil }
        let p = parts.count == 3 ? (Int(parts[2]) ?? -1) : 0
        if p < 0 { return nil }
        return (mj, mn, p)
    }

    private static func compareSemver(
        _ a: (Int, Int, Int), _ b: (Int, Int, Int)
    ) -> Int {
        if a.0 != b.0 { return a.0 < b.0 ? -1 : 1 }
        if a.1 != b.1 { return a.1 < b.1 ? -1 : 1 }
        if a.2 != b.2 { return a.2 < b.2 ? -1 : 1 }
        return 0
    }
}
