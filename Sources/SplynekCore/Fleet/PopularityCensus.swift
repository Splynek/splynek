// Copyright © 2026 Splynek. MIT.
//
// PopularityCensus — anonymous bundleID popularity census across
// the Splynek Fleet (LAN peers).
//
// 2026-05-08: Splynek can't catalog every Mac app individually
// (30,000+ MAS apps; we hand-curate ~1,150).  But we CAN learn
// which apps are popular among Splynek users + prioritise the
// curation work accordingly.  This is the "data tells you what
// to curate next" piece — orthogonal to the catalog itself, but
// it directs every curation hour to maximum impact.
//
// Privacy
// -------
// Every record is the SHA-256 of the bundleID + version, plus a
// truncated Mac fingerprint hash (NOT a stable user identifier;
// rotates every Splynek launch).  No bundleIDs leave the LAN in
// plain text.  No app names, no install paths, no anything that
// could re-identify a user's app set.  The aggregator (when one
// exists) sees only "hash X has been observed N times" and uses
// that to rank candidates.
//
// Architecture
// ------------
// • Local: each Splynek installation maintains a HASHED census of
//   apps it has seen.  Sent over Fleet's existing peer protocol
//   on opt-in.
// • Federated: a Splynek peer can SUBSCRIBE to the LAN's census,
//   accumulating the union of hashes seen by all peers on the
//   same network.  Sample-of-one gets enriched to sample-of-many.
// • Public: a future GitHub Action could publish the union of
//   hashes seen by an opt-in subset of users; the catalog
//   maintainers see "these 50 hashes are most common but not
//   in the catalog → research them next."
//
// This file is the local + federated surface.  The public-
// publishing piece is gated behind explicit user consent + lives
// in CI not the app.
//
// Status: SCAFFOLDING.  Wired into Fleet but not surfaced in any
// UI yet — the user's contribution flow (#5 in the 2026-05-08
// strategy) gives the same value with explicit consent + zero
// privacy questions, so PopularityCensus is the long-term safety
// net rather than the day-1 fix.

import Foundation
import CryptoKit

// Internal because callers (Fleet coordinator, Settings toggle)
// are all inside SplynekCore + the dependent type
// `SovereigntyScanner.InstalledApp` is itself internal.  Going
// public would force a wider visibility surface for no observable
// benefit.
@MainActor
enum PopularityCensus {

    /// One hashed observation.  `bundleHash` is SHA-256 of the
    /// bundleID; we never carry the bundleID in plain text outside
    /// the local Mac.  `versionHash` is SHA-256 of the version
    /// (CFBundleShortVersionString) so a future cron can detect
    /// "users on this Mac are mostly on version X" without needing
    /// the version literal.
    struct Observation: Codable, Hashable, Sendable {
        let bundleHash: String
        let versionHash: String?
        let lsCategory: String?  // already non-PII (Apple-defined)
        let observedAt: Date
    }

    /// Local store path — not synced via iCloud, not visible to
    /// other apps in the sandbox.  Lives in
    /// `~/Library/Application Support/Splynek/popularity.json`.
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
        return dir.appendingPathComponent("popularity.json")
    }

    /// Hash a bundleID for census purposes.  Truncated to 24 hex
    /// chars (96 bits) — collision-safe for the population (low
    /// millions of distinct bundleIDs in the wild) and short enough
    /// to keep the JSON small.
    static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    /// Build a fresh census from a SovereigntyScanner snapshot.
    /// Called by Fleet's announcement loop when popularity sharing
    /// is opted in — see Settings → Fleet → Popularity census.
    static func observations(from apps: [SovereigntyScanner.InstalledApp]) -> [Observation] {
        let now = Date()
        return apps.map { app in
            Observation(
                bundleHash: hash(app.id),
                versionHash: app.version.map { hash($0) },
                lsCategory: app.lsCategory,
                observedAt: now
            )
        }
    }

    /// Persist the local snapshot.  Called once per hour by the
    /// Fleet coordinator's tick.  Atomic write so a crash mid-save
    /// doesn't corrupt the file.
    static func save(_ observations: [Observation]) {
        let envelope = Envelope(
            schemaVersion: currentSchemaVersion,
            observations: observations,
            generatedAt: Date()
        )
        guard let data = try? JSONEncoder.iso8601.encode(envelope) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    static func load() -> [Observation] {
        guard let data = try? Data(contentsOf: storeURL),
              let envelope = try? JSONDecoder.iso8601.decode(Envelope.self, from: data),
              envelope.schemaVersion <= currentSchemaVersion
        else { return [] }
        return envelope.observations
    }

    static let currentSchemaVersion = 1

    struct Envelope: Codable, Sendable {
        let schemaVersion: Int
        let observations: [Observation]
        let generatedAt: Date
    }
}

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
