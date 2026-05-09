import Foundation

/// The bundled catalog of policy URLs the Trust Watcher monitors.
///
/// **Curation principle**: every URL must be the **vendor's
/// official, canonical, public** Privacy Policy or ToS page —
/// linked directly from their App Store listing, marketing site
/// footer, or in-app Settings → About.  No archived versions, no
/// third-party-mirror copies, no leaked drafts.
///
/// **Catalog growth path**: pull-request driven, reviewer must
/// click the URL + verify it loads a policy page (not a redirect
/// to a landing).  Same workflow as `TrustCatalog`'s
/// `TRUST-CONTRIBUTING.md`.
///
/// Sprint 1 seed (this commit): 12 of the most-installed apps
/// across the Sovereignty/Trust catalogs.  Picked to cover the
/// breadth of likely user concerns: streaming media (Spotify,
/// Netflix), social/chat (Slack, Discord, Zoom), creative
/// (Adobe), workspace (Notion, Dropbox), browsers (Chrome,
/// Firefox), AI tools (OpenAI ChatGPT, Anthropic Claude).
///
/// 2026-05-09: created.  Future enrichment via cron PR — see
/// `Scripts/scrape-app-store-privacy-labels.py` (skeleton from
/// the 2026-05-08 catalog-growth strategy).
public enum TrustWatchCatalog {

    /// Every target the bundled catalog watches.  Lazy because
    /// this list grows over time and we only iterate it from the
    /// `TrustWatchService` actor — no hot-path use.
    public static let targets: [TrustWatchTarget] = buildSeed()

    /// Look up every target for a given bundle ID.  An app may
    /// have 1-3 targets (Privacy Policy + ToS + optionally App
    /// Store privacy label).  Returns empty when the app isn't
    /// in the watch catalog.
    public static func targets(for bundleID: String) -> [TrustWatchTarget] {
        targets.filter { $0.bundleID == bundleID }
    }

    /// Distinct bundle IDs in the catalog.  Used by the UI to
    /// show "watching N apps".
    public static var watchedBundleIDs: Set<String> {
        Set(targets.map(\.bundleID))
    }

    // MARK: - Seed

    /// Hand-curated.  Each `TrustWatchTarget` validates `https`
    /// scheme — invalid entries are dropped + logged at boot.
    private static func buildSeed() -> [TrustWatchTarget] {
        let raw: [(String, String, TrustWatchKind, String)] = [
            // ── Streaming media ──
            ("com.spotify.client", "Spotify", .privacyPolicy,
             "https://www.spotify.com/legal/privacy-policy/"),
            ("com.spotify.client", "Spotify", .termsOfService,
             "https://www.spotify.com/legal/end-user-agreement/"),
            ("com.netflix.Netflix", "Netflix", .privacyPolicy,
             "https://help.netflix.com/legal/privacy"),
            ("com.netflix.Netflix", "Netflix", .termsOfService,
             "https://help.netflix.com/legal/termsofuse"),

            // ── Social / chat / video ──
            ("com.tinyspeck.slackmacgap", "Slack", .privacyPolicy,
             "https://slack.com/trust/privacy/privacy-policy"),
            ("com.tinyspeck.slackmacgap", "Slack", .termsOfService,
             "https://slack.com/terms-of-service/user"),
            ("com.hnc.Discord", "Discord", .privacyPolicy,
             "https://discord.com/privacy"),
            ("com.hnc.Discord", "Discord", .termsOfService,
             "https://discord.com/terms"),
            ("us.zoom.xos", "Zoom", .privacyPolicy,
             "https://www.zoom.com/en/trust/privacy/"),
            ("us.zoom.xos", "Zoom", .termsOfService,
             "https://www.zoom.com/en/trust/terms/"),

            // ── Creative ──
            ("com.adobe.Photoshop", "Adobe Photoshop", .privacyPolicy,
             "https://www.adobe.com/privacy/policy.html"),
            ("com.adobe.Photoshop", "Adobe Photoshop", .termsOfService,
             "https://www.adobe.com/legal/terms.html"),

            // ── Workspace ──
            ("notion.id", "Notion", .privacyPolicy,
             "https://www.notion.com/notion/privacy-policy"),
            ("notion.id", "Notion", .termsOfService,
             "https://www.notion.com/notion/terms"),
            ("com.getdropbox.dropbox", "Dropbox", .privacyPolicy,
             "https://www.dropbox.com/privacy"),
            ("com.getdropbox.dropbox", "Dropbox", .termsOfService,
             "https://www.dropbox.com/terms"),

            // ── Browsers ──
            ("com.google.Chrome", "Google Chrome", .privacyPolicy,
             "https://policies.google.com/privacy"),
            ("com.google.Chrome", "Google Chrome", .termsOfService,
             "https://policies.google.com/terms"),
            ("org.mozilla.firefox", "Mozilla Firefox", .privacyPolicy,
             "https://www.mozilla.org/privacy/firefox/"),
            ("org.mozilla.firefox", "Mozilla Firefox", .termsOfService,
             "https://www.mozilla.org/about/legal/terms/firefox/"),

            // ── AI tools (high-policy-volatility segment) ──
            ("com.openai.chat", "ChatGPT", .privacyPolicy,
             "https://openai.com/policies/row-privacy-policy/"),
            ("com.openai.chat", "ChatGPT", .termsOfService,
             "https://openai.com/policies/row-terms-of-use/"),
            ("com.anthropic.claudefordesktop", "Claude", .privacyPolicy,
             "https://www.anthropic.com/legal/privacy"),
            ("com.anthropic.claudefordesktop", "Claude", .termsOfService,
             "https://www.anthropic.com/legal/consumer-terms"),
        ]

        return raw.compactMap { tuple in
            let (bundleID, name, kind, urlString) = tuple
            guard let url = URL(string: urlString),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https"
            else {
                // Loud at boot — catalog bug, fix-the-data not
                // fix-the-code.
                assertionFailure("TrustWatchCatalog: invalid URL \(urlString)")
                return nil
            }
            return TrustWatchTarget(
                bundleID: bundleID,
                kind: kind,
                url: url,
                displayName: name
            )
        }
    }
}
