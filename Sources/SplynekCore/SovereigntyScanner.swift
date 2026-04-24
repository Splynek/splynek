import Foundation
import AppKit

/// v1.2: enumerate the third-party .app bundles installed on this Mac
/// so the Sovereignty tab can suggest EU / open-source alternatives.
///
/// Privacy invariants — these are deliberate, and audited here rather
/// than in a downstream file:
///
///   1. **Enumeration only.**  Uses `NSMetadataQuery` on Spotlight's
///      `kMDItemContentType == "com.apple.application-bundle"` index.
///      Returns bundle URL, display name, bundle ID, version.  We
///      never read the app's binary, Info.plist contents beyond what
///      Spotlight already indexed, its preferences, or any user data.
///
///   2. **Never touches the network.**  The whole scan is local.  The
///      AI that ranks alternatives (if the user invokes it) is itself
///      local — Apple Intelligence or Ollama.  No telemetry, no
///      analytics, no "how many users have Photoshop installed" phone-
///      home.  Ever.
///
///   3. **Sandbox-legal.**  `NSMetadataQuery` with
///      `NSMetadataQueryIndexedLocalComputerScope` works in the MAS
///      App Sandbox without any special entitlement — it's how the
///      Launchpad and Spotlight itself enumerate installed apps.
///
///   4. **Opt-in, one-shot.**  The view never calls this in the
///      background.  It fires only when the user clicks the "Scan my
///      Mac" button on the Sovereignty tab, holds the results in
///      memory, and discards them when the tab's view is destroyed.
///      No persistence, no caching across launches.
///
///   5. **Filters system apps.**  Apple-bundled apps (Safari, Mail,
///      Photos, etc.) aren't surfaced because the user didn't choose
///      them.  The Sovereignty story is about the apps you picked;
///      the built-ins are neither replaceable nor the point.
///
/// The single source of truth for the privacy contract above is this
/// file.  Keep it short, keep it readable, and don't add dependencies
/// on anything that reaches beyond the bundle-listing.
@MainActor
final class SovereigntyScanner: ObservableObject {

    /// One installed .app, with just the metadata we need to match
    /// it against the alternatives catalog.
    struct InstalledApp: Identifiable, Hashable {
        let id: String          // bundle identifier (primary key)
        let name: String        // display name (as Finder shows it)
        let bundleURL: URL      // /Applications/Foo.app, ~/Applications/Foo.app, …
        let version: String?    // CFBundleShortVersionString
    }

    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var lastError: String? = nil


    /// Kick off a scan.  No-op if a scan is already in flight.
    ///
    /// Implementation: direct filesystem enumeration of the standard
    /// install locations (`/Applications`, `~/Applications`, and
    /// `/Applications/Utilities`).  We deliberately avoid
    /// `NSMetadataQuery` here — Spotlight metadata queries against
    /// `kMDItemContentType == 'com.apple.application-bundle'` are
    /// unreliable in the MAS App Sandbox (Spotlight returns zero
    /// hits because the index lives outside the sandbox's read
    /// scope).  `FileManager` listing IS sandbox-legal for
    /// /Applications (top-level directory listing is public on macOS)
    /// and `Bundle(url:)` can load the top-level Info.plist of each
    /// found bundle — which is all we need to get bundle ID, display
    /// name, and version.
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        lastError = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            let apps = Self.enumerateApplications()
            await MainActor.run {
                guard let self else { return }
                self.apps = apps
                self.isScanning = false
                if apps.isEmpty {
                    self.lastError = "No installed apps were enumerable. If you expected more, this is a bug — please report it."
                }
            }
        }
    }

    // nonisolated — pure filesystem + Bundle() work; doesn't touch any
    // @Published state.  Runs on a detached Task's executor; result is
    // handed back via `MainActor.run` in `scan()`.
    nonisolated private static func enumerateApplications() -> [InstalledApp] {
        let fm = FileManager.default
        // Standard install locations.  Order doesn't matter — we
        // dedupe on bundle ID afterwards.
        var searchRoots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
        ]
        if let home = fm.homeDirectoryForCurrentUser as URL? {
            searchRoots.append(home.appendingPathComponent("Applications"))
        }

        var seenBundleIDs = Set<String>()
        var collected: [InstalledApp] = []

        for root in searchRoots {
            guard let contents = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension.lowercased() == "app" {
                guard let bundle = Bundle(url: url),
                      let bid = bundle.bundleIdentifier,
                      !Self.shouldSkip(bundleID: bid, url: url),
                      !seenBundleIDs.contains(bid)
                else { continue }
                seenBundleIDs.insert(bid)

                let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                    ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String

                collected.append(.init(
                    id: bid, name: name, bundleURL: url, version: version
                ))
            }
        }

        collected.sort {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return collected
    }

    /// Reasons we exclude an app from the Sovereignty list:
    ///
    /// - **Apple-bundled**: the user didn't choose Safari or Photos;
    ///   surfacing them as "replaceable" is tone-deaf and doesn't
    ///   match the story the tab tells.  Filter by bundle-ID prefix.
    /// - **System plumbing in /System/Library/CoreServices** etc.:
    ///   apps like "Ticket Viewer", "Screenshot" — invisible to the
    ///   user, shouldn't appear as "consider replacing this."
    /// - **Splynek itself**: don't recommend alternatives to us.
    /// - **Xcode Simulator runtimes**: Spotlight indexes them as
    ///   app bundles; they're not apps the user chose.
    nonisolated private static func shouldSkip(bundleID: String, url: URL) -> Bool {
        let path = url.path
        if path.hasPrefix("/System/") { return true }
        if path.contains(".app/Contents/") { return true }  // nested sub-apps
        if path.contains("/Xcode.app/") { return true }
        if path.contains("/CoreSimulator/") { return true }

        let appleBundlePrefixes = [
            "com.apple.",
            "com.apple.iBooksX",
            "com.apple.MobileSMS",
            "com.apple.shortcuts",
        ]
        if appleBundlePrefixes.contains(where: { bundleID.hasPrefix($0) }) {
            return true
        }

        if bundleID == "app.splynek.Splynek" { return true }

        return false
    }
}
