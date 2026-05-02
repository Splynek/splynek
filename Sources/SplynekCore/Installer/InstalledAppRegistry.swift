import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// `InstalledAppRegistry` is a pure read/write JSON store of metadata
// about apps the user installed via Splynek.  No code execution, no
// network calls, no `Process(...)`.  The registry is the source of
// truth for the auto-update scheduler in v1.8 — given a record, the
// scheduler re-runs `InstallerEngine` against the spec's
// `downloadURL`, fetches the latest payload, and offers an upgrade
// if the digest differs.
// =====================================================================

/// v1.8: persisted "what Splynek installed for you" registry.  Written
/// to `~/Library/Application Support/Splynek/installed-apps.json`.
/// Schema-versioned so v1.8.x future changes don't break the v1.8.0
/// store.
///
/// **Why not just walk /Applications?**  Because we want to know the
/// *origin* of an install (which catalog, which URL, which digest),
/// and `/Applications` doesn't carry that breadcrumb.  Also: many
/// users will have apps installed manually that aren't candidates for
/// Splynek's auto-update flow.
enum InstalledAppRegistry {

    /// Path on disk.  Mirrors the convention used by `DownloadHistory`.
    static var storeURL: URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("installed-apps.json")
    }

    /// Versioned envelope so future schema migrations are
    /// non-destructive.  Increment when adding required fields to
    /// `InstalledAppRecord`; load() handles older schemas by
    /// returning empty.
    struct Envelope: Codable {
        var schemaVersion: Int
        var records: [InstalledAppRecord]
    }

    static let currentSchemaVersion = 1

    /// Load the registry.  Returns an empty array if the file is
    /// missing, unparseable, or from a future schema version we don't
    /// understand.
    static func load() -> [InstalledAppRecord] {
        guard let data = try? Data(contentsOf: storeURL),
              let envelope = try? JSONDecoder.iso8601.decode(Envelope.self, from: data),
              envelope.schemaVersion <= currentSchemaVersion
        else { return [] }
        return envelope.records
    }

    /// Insert or replace the record matching by bundle ID.  Without a
    /// bundle ID we can't dedupe; in that case we append.  Atomic
    /// write so a crash mid-save doesn't corrupt the file.
    static func upsert(_ record: InstalledAppRecord) {
        var records = load()
        if let bundleID = record.spec.bundleID,
           let idx = records.firstIndex(where: { $0.spec.bundleID == bundleID }) {
            records[idx] = record
        } else {
            records.append(record)
        }
        save(records)
    }

    /// Remove by record ID.  Useful when the user uninstalls an app
    /// outside Splynek and wants the registry tidy.
    static func remove(id: UUID) {
        let filtered = load().filter { $0.id != id }
        save(filtered)
    }

    /// All records the user opted in to auto-update.  v1.8's auto-
    /// update scheduler iterates this and calls `InstallerEngine.run`
    /// in update-only mode for each.
    static func autoUpdateCandidates() -> [InstalledAppRecord] {
        load().filter { $0.autoUpdate }
    }

    /// Mark a record as auto-update-enabled or disabled.  Returns
    /// true if the record was found + updated.
    @discardableResult
    static func setAutoUpdate(_ id: UUID, enabled: Bool) -> Bool {
        var records = load()
        guard let idx = records.firstIndex(where: { $0.id == id }) else {
            return false
        }
        let r = records[idx]
        records[idx] = InstalledAppRecord(
            id: r.id,
            spec: r.spec,
            installedAt: r.installedAt,
            installedVersion: r.installedVersion,
            installedDate: r.installedDate,
            installedDigest: r.installedDigest,
            autoUpdate: enabled
        )
        save(records)
        return true
    }

    // MARK: - Persistence

    static func save(_ records: [InstalledAppRecord]) {
        let envelope = Envelope(schemaVersion: currentSchemaVersion, records: records)
        guard let data = try? JSONEncoder.iso8601.encode(envelope) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    /// Test-only helper: clear the on-disk store.  Used by
    /// `InstalledAppRegistryTests` to reset between cases.
    static func _resetForTesting() {
        try? FileManager.default.removeItem(at: storeURL)
    }
}

// MARK: - File-local JSON helpers
//
// `DownloadHistory.swift` defines its own fileprivate JSONEncoder.iso8601
// helper.  We can't reuse that one, so this file declares a parallel
// helper.  Both encode dates as ISO-8601 strings — interoperable with
// the rest of the Splynek persistence layer.

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
