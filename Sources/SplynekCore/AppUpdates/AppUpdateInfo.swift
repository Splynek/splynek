// Copyright © 2026 Splynek. MIT.
//
// AppUpdateInfo — pure data model for the Updates tab (Phase 3,
// 2026-05-07).
//
// Most macOS update tools (Sparkle, MacUpdater, Latest) only
// check what their hard-coded sources tell them.  Splynek's
// update system unifies several paths:
//
//   - Sparkle appcast (the de-facto standard — Bear, Things,
//     OmniFocus, Setapp-managed apps, ~70% of paid Mac apps)
//   - GitHub Releases API (open-source apps — VSCode forks,
//     Mattermost, Stats, Element, etc.)
//   - Mac App Store (LSItemContentType + receipt validation —
//     out of scope for v1, surfaced as "managed by App Store")
//   - Homebrew (`brew outdated --cask --json` — for CLI + cask
//     apps installed via brew)
//   - Publisher RSS / atom feed (when reachable)
//
// The model lives here.  Source-specific resolvers live as
// separate types under AppUpdates/.  AutoUpdateScheduler (existing,
// from v1.8) ingests AppUpdateInfo records and drives the install
// pipeline through the Phase-2-style installer engine — meaning
// updates inherit S5 BondedFetcher (multi-NIC bonded download) +
// S6 File Witness (Ed25519 receipt verification) for free.

import Foundation

/// Where an installed app's "current latest version" comes from.
public enum UpdateSource: Hashable, Sendable, Codable {
    /// Sparkle appcast — the most common format on macOS.  Apps
    /// declare `SUFeedURL` in their Info.plist; we fetch + parse
    /// the RSS-shaped feed.
    case sparkle(feedURL: URL)
    /// GitHub Releases API — `https://api.github.com/repos/{org}/{repo}/releases/latest`.
    /// Asset matching by suffix (`.dmg` / `.pkg`) + macOS architecture.
    case githubReleases(owner: String, repo: String)
    /// Mac App Store managed.  We surface the entry but defer to
    /// `App Store.app` for the actual install — Splynek doesn't
    /// re-implement Apple's MAS update flow.
    case macAppStore(adamID: String?)
    /// Homebrew-installed cask or formula.  We poll `brew outdated`
    /// out-of-process when checking; `formulaName` is the brew
    /// identifier (`hcloud`, `iterm2`, etc.).
    case homebrew(formulaName: String)
    /// Generic publisher RSS / atom feed, used when an app's
    /// publisher exposes release notes via a non-Sparkle feed
    /// (rare but real — kdenlive, blender, some kde apps).
    case publisherRSS(feedURL: URL)
    /// We checked but couldn't resolve a source for this app.
    /// Fallback action: surface the manual "check publisher" link.
    case unknown

    public var displayLabel: String {
        switch self {
        case .sparkle:        return "Sparkle"
        case .githubReleases: return "GitHub"
        case .macAppStore:    return "App Store"
        case .homebrew:       return "Homebrew"
        case .publisherRSS:   return "Publisher feed"
        case .unknown:        return "Manual"
        }
    }
}

/// Everything the Updates tab needs to render a row + drive an
/// install when the user opts in.
public struct AppUpdateInfo: Hashable, Sendable, Identifiable, Codable {
    public var id: String { bundleID }

    public let bundleID: String
    public let displayName: String
    public let installedVersion: String     // CFBundleShortVersionString as found
    public let installedAt: URL             // path to /Applications/Foo.app
    public let updateSource: UpdateSource

    /// Resolved when the user runs "Check for updates" — nil
    /// indicates "we haven't asked the source yet" or "the source
    /// resolver couldn't determine a version."
    public var availableVersion: String?
    public var availableSizeBytes: Int64?
    /// Direct download URL for the new build (when Sparkle / GitHub
    /// resolved one).  Used by the AutoUpdateScheduler to drive
    /// the existing installer engine.  nil when we can only direct
    /// the user at a publisher page.
    public var availableDownloadURL: URL?
    /// SHA-256 of the new build, when Sparkle's appcast or
    /// publisher feed declares it.  Forwarded to S6 File Witness
    /// for Ed25519-receipt verification post-install.
    public var availableSHA256: String?
    /// Plain-text release notes (Sparkle's `<description>` body
    /// or GitHub release `body`).  Surfaced inline in the tab so
    /// the user can decide before tapping Update.
    public var releaseNotes: String?
    /// When we last successfully consulted the source.  Drives the
    /// "stale" badge for sources that haven't responded in 7d+.
    public var lastChecked: Date

    /// 2026-05-08: alternate download URLs ranked by preference.
    /// When the primary `availableDownloadURL` fails the pre-flight
    /// HEAD probe (4xx, HTML, weird MIME) or the magic-byte sniff
    /// catches an unsupported format, `UpdateSweep.run` retries
    /// with each entry in this list before marking the row fatal.
    /// Empty / nil means "no alternates" (Sparkle / RSS / Homebrew —
    /// single-source) so the existing fail-on-primary behaviour
    /// stays the default.
    public var availableAlternateURLs: [URL]?

    /// 2026-05-08: pre-flight warning surfaced in the Updates tab.
    /// Set by `UpdatesView.checkAll` after a HEAD probe of the
    /// resolved download URL.  When `.fatal`, the row downgrades to
    /// a "Manual" affordance with the message as explanation — the
    /// user is told WHY before they click, instead of the install
    /// pipeline failing late.  Single-field design (vs separate
    /// message+flag) so old persisted JSON decodes cleanly.
    public var preflight: Preflight?

    public enum Preflight: Hashable, Sendable, Codable {
        case warning(String)
        case fatal(String)

        public var message: String {
            switch self {
            case .warning(let s), .fatal(let s): return s
            }
        }
        public var isFatal: Bool {
            if case .fatal = self { return true }
            return false
        }
    }

    public enum UpdatePolicy: String, Codable, Hashable, Sendable, CaseIterable {
        /// Quietly install during quiet hours (default 3am).
        case automatic
        /// Notify but require user tap to install.
        case notify
        /// Show in the tab but never auto-act.  Useful for risky
        /// upgrades the user wants to review (major-version bumps).
        case manual
        /// Hide entirely.  Used for apps the user has decided to
        /// not update from Splynek (still get updated by their
        /// publisher's own mechanism).
        case ignored

        public var displayLabel: String {
            switch self {
            case .automatic: return "Auto"
            case .notify:    return "Notify"
            case .manual:    return "Manual"
            case .ignored:   return "Ignored"
            }
        }
    }
    public var updatePolicy: UpdatePolicy

    public init(bundleID: String, displayName: String,
                installedVersion: String, installedAt: URL,
                updateSource: UpdateSource,
                availableVersion: String? = nil,
                availableSizeBytes: Int64? = nil,
                availableDownloadURL: URL? = nil,
                availableSHA256: String? = nil,
                releaseNotes: String? = nil,
                lastChecked: Date = Date(),
                updatePolicy: UpdatePolicy = .notify,
                preflight: Preflight? = nil,
                availableAlternateURLs: [URL]? = nil) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.installedVersion = installedVersion
        self.installedAt = installedAt
        self.updateSource = updateSource
        self.availableVersion = availableVersion
        self.availableSizeBytes = availableSizeBytes
        self.availableDownloadURL = availableDownloadURL
        self.availableSHA256 = availableSHA256
        self.releaseNotes = releaseNotes
        self.lastChecked = lastChecked
        self.updatePolicy = updatePolicy
        self.preflight = preflight
        self.availableAlternateURLs = availableAlternateURLs
    }

    /// Pure semver-ish comparison: returns true when
    /// `availableVersion` is greater than `installedVersion`
    /// using a lexicographic dot-segment compare.  Handles common
    /// forms ("1.2.3", "1.2.3-beta", "v1.2.3") + falls back to
    /// string compare on uncommon forms (date-shaped versions).
    public var hasUpdate: Bool {
        guard let avail = availableVersion else { return false }
        return Self.isNewer(installed: installedVersion, available: avail)
    }

    public static func isNewer(installed: String, available: String) -> Bool {
        let i = normalizeVersion(installed)
        let a = normalizeVersion(available)
        if i == a { return false }
        // Compare segment-by-segment numerically when possible,
        // lexicographically when not.
        let iParts = i.split(separator: ".").map(String.init)
        let aParts = a.split(separator: ".").map(String.init)
        for k in 0..<max(iParts.count, aParts.count) {
            let ip = k < iParts.count ? iParts[k] : "0"
            let ap = k < aParts.count ? aParts[k] : "0"
            if let iN = Int(ip), let aN = Int(ap) {
                if iN < aN { return true }
                if iN > aN { return false }
            } else {
                if ip < ap { return true }
                if ip > ap { return false }
            }
        }
        return false
    }

    static func normalizeVersion(_ v: String) -> String {
        // Strip a leading "v" or "V" + drop "-beta" / "-rc" suffixes.
        var s = v
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        if let dash = s.firstIndex(of: "-") { s = String(s[..<dash]) }
        if let plus = s.firstIndex(of: "+") { s = String(s[..<plus]) }
        return s
    }

    /// Convenience: when the available size is known, format MiB
    /// for the row's secondary text.  Returns nil otherwise.
    public var availableSizeFormatted: String? {
        guard let b = availableSizeBytes, b > 0 else { return nil }
        let mb = Double(b) / 1024 / 1024
        if mb >= 1024 {
            return String(format: "%.1f GiB", mb / 1024)
        }
        return String(format: "%.0f MiB", mb)
    }
}
