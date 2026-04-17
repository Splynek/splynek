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
            .deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in }
    }
}
