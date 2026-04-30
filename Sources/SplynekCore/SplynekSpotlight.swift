import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Index completed downloads into Spotlight so users can find what Splynek
/// has fetched from the system-wide search bar.
///
/// Each `HistoryEntry` becomes a `CSSearchableItem` under the domain
/// `app.splynek.history`. Attributes carry the filename, originating host,
/// byte count, and finished-at timestamp. Activating a Spotlight hit opens
/// the file in its parent folder (handled by the system once the
/// `contentURL` is set).
enum SplynekSpotlight {

    static let domain = "app.splynek.history"

    /// Replace the current Splynek-domain index with the supplied entries.
    /// Called after every download completion so the index stays in sync
    /// with the on-disk history file. Silent on failure — Spotlight is a
    /// best-effort convenience, not a correctness requirement.
    static func reindex(_ entries: [HistoryEntry]) {
        let index = CSSearchableIndex.default()
        let items = entries.map { entry -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .item)
            attrs.title = entry.filename
            let host = URL(string: entry.url)?.host ?? entry.url
            attrs.contentDescription =
                "Downloaded from \(host) — \(ByteCountFormatter.string(fromByteCount: entry.totalBytes, countStyle: .binary))"
            attrs.downloadedDate = entry.finishedAt
            attrs.addedDate = entry.startedAt
            attrs.contentModificationDate = entry.finishedAt
            attrs.fileSize = NSNumber(value: entry.totalBytes)
            attrs.contentURL = URL(fileURLWithPath: entry.outputPath)
            attrs.keywords = [host, "splynek", "download"]
            return CSSearchableItem(
                uniqueIdentifier: entry.id.uuidString,
                domainIdentifier: domain,
                attributeSet: attrs
            )
        }
        // Clear first so deleted / expired history entries stop surfacing.
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            index.indexSearchableItems(items) { _ in /* silent */ }
        }
    }

    /// Remove every Splynek Spotlight item. Useful if the user clears
    /// history or resets preferences.
    static func wipe() {
        CSSearchableIndex.default()
            .deleteSearchableItems(withDomainIdentifiers: [
                domain,
                sovereigntyDomain,
                trustDomain,
            ]) { _ in }
    }

    // MARK: - v1.6: Sovereignty + Trust catalog indexing

    /// Domain for Sovereignty catalog hits in Spotlight.  Activating a
    /// hit opens Splynek to the Sovereignty tab focused on the entry
    /// via the `splynek://sovereignty/<bundle-id>` URL scheme.
    static let sovereigntyDomain = "app.splynek.sovereignty"
    static let trustDomain = "app.splynek.trust"

    /// Index every Sovereignty catalog entry into Spotlight so a
    /// system-wide search for "Notion" surfaces "Notion — Sovereignty:
    /// Privacy concerns + EU/OSS alternatives".  This is a one-shot
    /// per-launch reindex; the catalog is generated at compile time so
    /// it doesn't change during a session.
    ///
    /// **Privacy invariants preserved:**
    ///   - Only catalog data (which ships with the app) lands in
    ///     Spotlight.  No data about the user's installed apps is
    ///     written.  The catalog is identical for every Splynek user.
    ///   - `contentURL` is set to a `splynek://` deep link, NOT a file
    ///     URL — Spotlight surfaces the entry but tapping it routes
    ///     back into Splynek without exposing any local path.
    static func reindexCatalog() {
        let index = CSSearchableIndex.default()
        var items: [CSSearchableItem] = []

        // Sovereignty
        for entry in SovereigntyCatalog.entries {
            let attrs = CSSearchableItemAttributeSet(contentType: .item)
            attrs.title = entry.targetDisplayName
            let altCount = entry.alternatives.count
            let altList = entry.alternatives
                .prefix(3)
                .map(\.name)
                .joined(separator: ", ")
            attrs.contentDescription = "\(entry.targetOrigin.label) origin · "
                + "\(altCount) alternative\(altCount == 1 ? "" : "s")"
                + (altList.isEmpty ? "" : " — \(altList)")
            attrs.contentURL = URL(string: "splynek://sovereignty/\(entry.targetBundleID)")
            attrs.keywords = [
                "splynek", "sovereignty",
                entry.targetBundleID,
                entry.targetOrigin.label,
            ] + entry.alternatives.prefix(5).map(\.name)
            items.append(CSSearchableItem(
                uniqueIdentifier: "sov:\(entry.targetBundleID)",
                domainIdentifier: sovereigntyDomain,
                attributeSet: attrs
            ))
        }

        // Trust
        for entry in TrustCatalog.entries {
            let attrs = CSSearchableItemAttributeSet(contentType: .item)
            attrs.title = entry.targetDisplayName
            let n = entry.concerns.count
            attrs.contentDescription = "Trust audit · \(n) concern\(n == 1 ? "" : "s") "
                + "from public records (App Store privacy labels, EU DPAs, FTC, NVD, HIBP)"
            attrs.contentURL = URL(string: "splynek://trust/\(entry.targetBundleID)")
            attrs.keywords = [
                "splynek", "trust", "privacy", "audit",
                entry.targetBundleID,
            ]
            items.append(CSSearchableItem(
                uniqueIdentifier: "trust:\(entry.targetBundleID)",
                domainIdentifier: trustDomain,
                attributeSet: attrs
            ))
        }

        // Replace any prior catalog index in one transaction so a
        // catalog rev doesn't leave stale entries in Spotlight.
        //
        // v1.6.2: previously swallowed all errors silently — `{ _ in }`.
        // Field investigation showed `mdfind` returned empty for the
        // Splynek domains even after a clean app launch, meaning the
        // index calls were either never firing or erroring.  Now we
        // log the outcome so the user can diagnose via:
        //
        //   log show --predicate 'subsystem == "app.splynek"
        //                         AND category == "scan"' --info --last 5m
        let totalItems = items.count
        Log.scan.info("Spotlight reindex starting: \(totalItems, privacy: .public) items across sovereignty + trust domains")
        index.deleteSearchableItems(withDomainIdentifiers: [
            sovereigntyDomain, trustDomain,
        ]) { deleteError in
            if let err = deleteError {
                Log.scan.error("Spotlight delete-pre-reindex failed: \(String(describing: err), privacy: .public)")
                // Continue anyway — the indexer will overwrite by
                // uniqueIdentifier.
            }
            index.indexSearchableItems(items) { indexError in
                if let err = indexError {
                    Log.scan.error("Spotlight indexSearchableItems failed: \(String(describing: err), privacy: .public)")
                } else {
                    Log.scan.info("Spotlight reindex done: \(totalItems, privacy: .public) items indexed")
                }
            }
        }
    }
}
