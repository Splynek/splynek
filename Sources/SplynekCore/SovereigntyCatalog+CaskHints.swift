// Copyright © 2026 Splynek. MIT.
//
// SovereigntyCatalog+CaskHints — runtime loader for the auto-imported
// Homebrew Cask metadata.
//
// Storage: Resources/cask-hints.json, processed by SwiftPM via
// `.process("Resources/cask-hints.json")` in Package.swift.  The
// embedded JSON file is the single source of truth — regenerate with
// `python3 Scripts/emit-cask-swift.py` after refreshing the cask
// snapshot.
//
// Why JSON, not a Swift literal?  Two prior attempts at a
// `static let caskHints: [CaskHint] = [...]` literal blew up swiftc's
// constraint solver: 4088 entries triggered exponential type-check
// paths and OOM'd at 200 GB during compile.  JSON parses in <50ms on
// first access; the compiler does no work on the data.
//
// Architectural note: this is NOT promoted to SovereigntyCatalog
// because cask metadata is community-maintained + license info isn't
// extracted.  These hints power the Contribute flow + the "We don't
// know yet" disclosure — they help the user, not the catalog itself.

import Foundation

/// One auto-imported metadata record from Homebrew Cask.
struct CaskHint: Hashable, Sendable, Codable {
    let bundleID: String
    let caskToken: String
    let name: String
    let homepageString: String
    let downloadURLString: String
    let categoryHint: String?

    var homepage: URL? { URL(string: homepageString) }
    var downloadURL: URL? { URL(string: downloadURLString) }

    enum CodingKeys: String, CodingKey {
        case bundleID, caskToken, name
        case homepageString = "homepage"
        case downloadURLString = "downloadURL"
        case categoryHint
    }
}

extension SovereigntyCatalog {

    /// Look up Homebrew Cask metadata for a bundle ID, when available.
    /// Returns nil for apps not in the cask snapshot.  O(1) after the
    /// one-time index build on first call.
    static func caskHint(forBundleID bundleID: String) -> CaskHint? {
        caskHintsIndex[bundleID]
    }

    /// Number of cask hints loaded.  Surfaced in the Sovereignty
    /// empty-state copy so users see the magnitude of the gap-filler.
    static var caskHintCount: Int { caskHints.count }

    /// Flat array of every cask-imported hint.  Loaded lazily from
    /// the resource JSON on first access.  Empty if the resource is
    /// missing or the JSON is malformed (defensive — we never crash
    /// at startup over an optional enrichment dataset).
    static let caskHints: [CaskHint] = {
        struct Envelope: Decodable {
            let schemaVersion: Int
            let hints: [CaskHint]
        }
        // Cross-build-system lookup mirroring Splynek's .splynekCore
        // pattern.  In SwiftPM builds the resource lives under the
        // generated Splynek_SplynekCore.bundle; in Xcode-managed MAS
        // builds it's bundled at the .app's main Resources/.
        let candidates: [Bundle] = [
            .splynekCore,
            .main,
        ]
        for bundle in candidates {
            if let url = bundle.url(forResource: "cask-hints",
                                    withExtension: "json")
                ?? bundle.url(forResource: "cask-hints",
                              withExtension: "json",
                              subdirectory: "Resources"),
               let data = try? Data(contentsOf: url),
               let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
               envelope.schemaVersion <= 1
            {
                return envelope.hints
            }
        }
        return []
    }()

    /// Lazy bundleID-keyed index.  Built once on first access via a
    /// for-loop over `caskHints` — Dictionary literal would hit the
    /// same exponential path that broke the all-Swift attempt.
    private static let caskHintsIndex: [String: CaskHint] = {
        var dict = [String: CaskHint](minimumCapacity: caskHints.count)
        for hint in caskHints { dict[hint.bundleID] = hint }
        return dict
    }()
}
