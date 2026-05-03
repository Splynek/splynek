import Foundation

/// v1.7.x: Concierge transcript persistence.  Survives session restart
/// so the chat history isn't blanked when the user quits + relaunches.
///
/// Persists `id / role / text / action / toolID` only — not the typed
/// `ConciergeCard` payload.  Cards encode live state (URLs to scan
/// reports, file paths in disk usage, "Download" / "Open" buttons that
/// dispatch off in-process closures).  Restoring them after a relaunch
/// would render interactive surfaces over stale data.  The text caption
/// (always populated by `captionFor(card:)` in the Pro dispatcher)
/// preserves the conversation's readability — it's what the user
/// already sees above each card.
///
/// File: `~/Library/Application Support/Splynek/concierge-transcript.json`
/// (sandboxed → resolves under the app's container).  Schema-versioned
/// so future changes can be detected + skipped.
struct ConciergeTranscriptStore {

    /// One persisted message.  Mirrors `ConciergeMessage`'s text-only
    /// surface.  `role` is the raw enum string ("user" / "assistant" /
    /// "system") so unknown future roles round-trip cleanly.
    struct PersistedMessage: Codable, Equatable {
        let id: UUID
        let role: String
        let text: String
        let action: String?
        let toolID: String?
    }

    /// Cap on persisted messages.  Keeps the file small (a 200-message
    /// transcript is ~30 KB) + ensures load/save stay sub-millisecond
    /// on the main actor.  Saves the LAST `maxMessages` so recent
    /// context wins when the user has had a long-running session.
    static let maxMessages = 200

    /// Schema version.  Bumped when the on-disk format changes in a
    /// non-back-compat way.  A mismatched version on load returns `[]`
    /// rather than crashing or guessing.
    static let schemaVersion = 1

    /// File URL.  Nil disables persistence (used by tests that don't
    /// want to touch disk + by free-tier paths that haven't unlocked
    /// the Concierge tab).
    let url: URL?

    init(url: URL? = ConciergeTranscriptStore.defaultURL) {
        self.url = url
    }

    /// Default location: `~/Library/Application Support/Splynek/
    /// concierge-transcript.json`.  Sandbox-safe — `applicationSupport
    /// Directory` resolves under the app's container.  Falls back to
    /// `nil` (no persistence) if the directory can't be created, so a
    /// permissions failure doesn't crash the chat surface.
    static var defaultURL: URL? {
        let fm = FileManager.default
        guard let appSupport = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let dir = appSupport.appendingPathComponent("Splynek", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return dir.appendingPathComponent("concierge-transcript.json")
    }

    /// Load the persisted transcript.  Returns `[]` for any failure
    /// mode (missing file, corrupted JSON, schema mismatch, IO error)
    /// so a bad on-disk state never breaks the live chat.
    func load() -> [PersistedMessage] {
        guard let url else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.version == Self.schemaVersion
        else { return [] }
        return envelope.messages
    }

    /// Save the transcript atomically.  Caps to the last
    /// `maxMessages` entries so the file can't grow unbounded.  Silent
    /// no-op on encode/write failure — persistence is best-effort.
    func save(_ messages: [PersistedMessage]) {
        guard let url else { return }
        let trimmed = Array(messages.suffix(Self.maxMessages))
        let envelope = Envelope(version: Self.schemaVersion, messages: trimmed)
        guard let data = try? JSONEncoder.transcript.encode(envelope) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Remove the persisted file.  Used by `conciergeReset()`-style
    /// callers that want a clean slate, not just an empty array.
    /// Equivalent to `save([])` semantically; physical-delete is
    /// preferred so a corrupted file doesn't survive a reset.
    func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private struct Envelope: Codable {
        let version: Int
        let messages: [PersistedMessage]
    }
}

private extension JSONEncoder {
    static var transcript: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
