import Foundation

/// v1.6.0+: single source of truth for the version string the UI shows
/// when `Bundle.main.infoDictionary["CFBundleShortVersionString"]` is
/// `nil` — which happens whenever the executable is launched without
/// being wrapped in an `.app` bundle (e.g. `swift run Splynek` from
/// the command line).
///
/// **Why this exists.**  Pre-1.6 we had three different stale fallback
/// strings scattered across the views: `?? "0.6.0"` in `AboutView`,
/// `?? "0.0.0"` in `Sidebar`, `?? "0.0.0"` in `UpdateChecker`.  The
/// fallbacks fired any time the Info.plist couldn't be read, which
/// produced an "About" screen claiming "Version 0.6.0" running on
/// what was actually a v1.6.0 build.  Plist-only sync invariants
/// (`InfoPlistSyncTests`, `ReleaseCoherenceTests`) couldn't catch
/// it because they don't read source-code constants.
///
/// **The contract now**: every version read uses
/// `SplynekVersion.current` — which prefers the Info.plist value when
/// present, and otherwise falls through to `SplynekVersion.fallback`.
/// `fallback` is asserted equal to the Info.plist value by
/// `ReleaseCoherenceTests`, so version bumps catch the constant
/// drifting at CI time.
///
/// **Why not eliminate the fallback entirely.**  A fallback IS
/// necessary because `Bundle.main.infoDictionary` legitimately can be
/// nil when running un-bundled (developers, CI, sanity scripts).
/// Returning "" or "unknown" from those paths shows up in screenshots
/// of demos / test runs and confuses users.  An always-correct
/// constant is the lesser evil.
public enum SplynekVersion {

    /// The compile-time version string.  Bumped together with every
    /// version metadata bump (Info.plist + project.yml + Alfred plist
    /// + Cask).  Asserted equal to Info.plist by
    /// `ReleaseCoherenceTests`.
    public static let fallback = "3.0.0"

    /// The version string SwiftUI views should display.  Reads
    /// Info.plist when available; otherwise returns `fallback`.
    public static var current: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? fallback
    }
}
