// Copyright © 2026 Splynek. MIT.
//
// HomebrewResolver — pure parser for `brew outdated --cask --json`
// output.  Phase 3 follow-up (2026-05-07).
//
// Why JSON-only (no `brew info`): `outdated` already returns
// `current_version` and `installed_versions` in the response, which
// is exactly what we need to render "v2.7.4 → v2.8.0" in the
// Updates tab.  No second hop required.
//
// We don't shell out from this module — Splynek runs in the App
// Sandbox, which forbids `Process()`.  This file decodes JSON the
// caller fetched (in DMG builds) or surfaces "Homebrew not
// available" (in MAS builds).  The DMG path is the supported one;
// MAS users get the per-publisher Sparkle / GitHub paths.
//
// Schema (sample):
//
//   {
//     "casks": [
//       { "name": "iterm2", "installed_versions": ["3.5.10"],
//         "current_version": "3.5.11", "pinned": false,
//         "pinned_version": null }
//     ]
//   }

import Foundation

public enum HomebrewResolver {

    public struct OutdatedCask: Decodable, Equatable, Sendable {
        public let name: String
        public let installedVersions: [String]
        public let currentVersion: String

        enum CodingKeys: String, CodingKey {
            case name
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
        }
    }

    public struct OutdatedReport: Decodable, Equatable, Sendable {
        public let casks: [OutdatedCask]
    }

    /// Parse `brew outdated --cask --json` bytes.  Returns nil when
    /// the JSON is malformed (brew not installed, MAS sandbox
    /// blocking the call, schema drift).
    public static func parseOutdated(_ data: Data) -> OutdatedReport? {
        try? JSONDecoder().decode(OutdatedReport.self, from: data)
    }

    /// Look up the outdated entry for a specific cask in a parsed
    /// report.  Returns nil when the cask is up-to-date (not in the
    /// report) or missing (typo in the bundle-ID → cask map).
    public static func entry(for caskName: String,
                             in report: OutdatedReport) -> OutdatedCask? {
        report.casks.first { $0.name == caskName }
    }

    /// Whether brew reports a usable update for `caskName`: present
    /// in the report AND `current_version` differs from the most
    /// recent `installed_versions` entry.  Mirrors the
    /// `AppUpdateInfo.hasUpdate` logic but uses semver compare from
    /// AppUpdateInfo.isNewer to stay consistent across resolvers.
    public static func hasUpdate(_ caskName: String,
                                 in report: OutdatedReport) -> Bool {
        guard let entry = entry(for: caskName, in: report),
              let installed = entry.installedVersions.last
        else { return false }
        return AppUpdateInfo.isNewer(
            installed: installed, available: entry.currentVersion)
    }

    /// Build the `brew install` command the Updates tab can hand to
    /// the user (via Copy-to-clipboard) when they want to apply the
    /// update manually.  Splynek itself can't run brew due to the
    /// sandbox.
    public static func installCommand(for caskName: String) -> String {
        "brew upgrade --cask \(caskName)"
    }
}
