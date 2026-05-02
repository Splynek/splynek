import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// `InstallSpec` is the input to the v1.8 installer pipeline.  It
// describes what to install, NOT how.  All fields are pure data —
// String, URL, optional digest hex, optional bundle ID.  The
// pipeline that consumes `InstallSpec` (see `InstallerEngine.swift`)
// uses Apple's `installer(8)` for .pkg, mounts .dmg via `hdiutil`,
// and copies `.app` bundles via FileManager.  Splynek does NOT ship
// any post-install scripts, hooks, or executable code.  The .pkg's
// payload is whatever Apple's installer agrees to deploy from a
// signed package.
// =====================================================================

/// v1.8: a description of what the user wants to install — lifted
/// from a Sovereignty/Trust catalog entry, a Homebrew-Cask record, or
/// a direct URL.  `InstallSpec` is purely declarative; it carries no
/// behaviour.  The `InstallerEngine` pipeline turns it into bytes on
/// disk, then a verified install.
///
/// A spec is **complete** when it has at minimum:
///
///   - `name` (display name shown to the user)
///   - `downloadURL` (the .pkg / .dmg / .zip the engine will fetch)
///   - `kind` (so the installer picks the right handler)
///
/// `expectedDigest` and `bundleID` are optional but strongly
/// recommended.  Without `expectedDigest` the installer falls back
/// to Gatekeeper-only verification (see `InstallVerification.swift`),
/// which is sufficient for notarized binaries but weaker against
/// supply-chain compromise.  Without `bundleID` the post-install
/// registry can't match an existing installed copy when the user
/// tries to upgrade.
struct InstallSpec: Codable, Hashable, Sendable {
    /// Display name — what the user sees in the install sheet.
    let name: String

    /// Optional bundle identifier (e.g. "org.mozilla.firefox").  Used
    /// to detect "already installed" + to match auto-update targets.
    let bundleID: String?

    /// The download URL.  Splynek fetches via the existing
    /// multi-interface engine, so all the IP_BOUND_IF tricks apply.
    let downloadURL: URL

    /// What kind of installer payload this is.  Drives the post-
    /// download branching in `InstallerEngine`.
    let kind: Kind

    /// Optional expected hex digest (SHA-256 = 64 hex chars).  When
    /// present, `InstallVerification` rejects the installer if the
    /// downloaded bytes don't match.
    let expectedDigest: String?

    /// Where the spec came from — for the audit trail ("installed
    /// from Sovereignty catalog" vs "user pasted a URL").
    let source: Source

    enum Kind: String, Codable, Hashable, Sendable {
        /// Apple Installer .pkg — handed off to `installer(8)`.
        case pkg
        /// .dmg disk image — mounted via hdiutil, the .app inside is
        /// copied to /Applications, then the disk image is unmounted.
        case dmg
        /// .zip / .tar.gz archive containing a .app — extracted and
        /// the .app moved to /Applications.
        case appArchive
        /// A bare .app bundle (rare, but Sparkle ships some this way).
        case appBundle
    }

    enum Source: Codable, Hashable, Sendable {
        case sovereigntyCatalog(slug: String)
        case trustCatalog(slug: String)
        case homebrewCask(token: String)
        case directURL
    }
}

/// One row in the registry of apps Splynek has installed.  Persisted
/// to `installed-apps.json` in Application Support.  The auto-update
/// scheduler reads this list, looks up each app's current
/// upstream version (via `InstallSpec.downloadURL` redirect-follow),
/// and offers the user a one-click update.
struct InstalledAppRecord: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    /// The spec the user accepted at install time.
    let spec: InstallSpec
    /// Where the .app actually landed (typically /Applications/X.app).
    let installedAt: URL
    /// The version Splynek saw at install time, parsed from the
    /// .app's `Info.plist::CFBundleShortVersionString`.
    let installedVersion: String?
    /// Wall-clock timestamp.
    let installedDate: Date
    /// Hex SHA-256 of the .pkg/.dmg as it was downloaded.  Lets us
    /// verify integrity later if the user re-downloads from another
    /// path.
    let installedDigest: String?
    /// Has the user opted in to auto-update for this app?  Default
    /// false; the install-success card shows a one-line opt-in.
    let autoUpdate: Bool
}
