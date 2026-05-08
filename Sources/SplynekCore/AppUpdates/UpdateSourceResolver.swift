// Copyright © 2026 Splynek. MIT.
//
// UpdateSourceResolver — given an installed app, figure out where
// its updates come from.  Phase 3 (2026-05-07).
//
// Resolution priority:
//
//   1. Read the app's Info.plist for `SUFeedURL` (Sparkle).  This
//      is the most-reliable signal — apps that ship Sparkle are
//      explicit about it.
//   2. Match against a known-app table mapping bundleID →
//      `UpdateSource` (covers GitHub-hosted OSS apps that don't
//      ship Sparkle: VSCode, Stats, Element, etc.).
//   3. Fall back to `unknown` — the Updates tab surfaces a
//      "check publisher" link instead of an Update button.
//
// Pure: no I/O.  Tests provide synthetic Info.plist dictionaries +
// installed-app records.

import Foundation

public enum UpdateSourceResolver {

    /// Synchronously resolve a source from on-disk metadata.  The
    /// app's Info.plist is read at the path the
    /// SovereigntyScanner/InstalledAppRegistry recorded; consult
    /// `wellKnownSources` second.
    ///
    /// 2026-05-08: dropped `@MainActor` — this method is pure
    /// synchronous filesystem I/O with no UI access, and the
    /// launch-time warm-up needs to call it from a detached
    /// background Task to keep the boot path fast.
    public static func resolve(
        bundleID: String,
        bundleURL: URL,
        infoPlist: [String: Any]? = nil
    ) -> UpdateSource {
        // 1. Sparkle SUFeedURL declared in the bundle's Info.plist.
        if let plist = infoPlist ?? readInfoPlist(at: bundleURL),
           let feedString = plist["SUFeedURL"] as? String,
           let feedURL = URL(string: feedString),
           feedURL.scheme?.lowercased() == "https"
        {
            return .sparkle(feedURL: feedURL)
        }

        // 2. Known-app table.
        if let known = wellKnownSources[bundleID] {
            return known
        }

        // 3. Couldn't determine.
        return .unknown
    }

    /// Read the app's Info.plist from `<bundleURL>/Contents/Info.plist`.
    /// Returns nil on read failure (sandbox restriction, malformed
    /// plist, etc.) — caller treats nil as "no Sparkle feed found".
    static func readInfoPlist(at bundleURL: URL) -> [String: Any]? {
        let plistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]
        else { return nil }
        return plist
    }

    /// Curated bundle-ID → UpdateSource map for popular apps that
    /// don't ship Sparkle.  Initial entries cover the ones we have
    /// strong confidence about; the table grows by community
    /// contribution (PR adds entries with verifiable upstream
    /// repos).
    public static let wellKnownSources: [String: UpdateSource] = [
        // GitHub-released OSS apps
        "com.exelban.Stats":              .githubReleases(owner: "exelban", repo: "stats"),
        "im.riot.app":                    .githubReleases(owner: "element-hq", repo: "element-desktop"),
        "com.vscodium":                   .githubReleases(owner: "VSCodium", repo: "vscodium"),
        "dev.zed.Zed":                    .githubReleases(owner: "zed-industries", repo: "zed"),
        "com.runningwithcrayons.Alfred":  .unknown,  // no GitHub; Sparkle but not declared as such
        "com.bohemiancoding.sketch3":     .unknown,  // proprietary updater
        "com.openai.chat":                .githubReleases(owner: "openai", repo: "chatgpt-mac"),
        "io.snyk.SnykForMacOS":           .githubReleases(owner: "snyk", repo: "cli"),
        // Mac App Store managed (we won't drive the install)
        "com.apple.iWork.Pages":          .macAppStore(adamID: "409201541"),
        "com.apple.iWork.Numbers":        .macAppStore(adamID: "409203825"),
        "com.apple.iWork.Keynote":        .macAppStore(adamID: "409183694"),
        "com.apple.FinalCut":             .macAppStore(adamID: "424389933"),
        "com.apple.logic10":              .macAppStore(adamID: "634148309"),
    ]
}
