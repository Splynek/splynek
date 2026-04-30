import Foundation
import os

/// v1.5.6+: Splynek's structured-logging façade.
///
/// **Why a façade and not raw `Logger(subsystem:category:)` everywhere:**
///
///   - Single subsystem string ("app.splynek") so Console.app filters
///     stay one click rather than seven.
///   - Category names are types, not strings — typo-proof.  A typo in
///     `"flete"` vs `"fleet"` fragments your log namespace silently;
///     a typo in `Log.flete` is a compile error.
///   - The compiler erases unused log calls below the configured
///     OS_ACTIVITY_MODE, so debug-level instrumentation costs zero
///     in release.
///
/// **Privacy contract:**
///
///   `Logger.debug("...")` interpolations default to `.private` for
///   non-static substrings.  We use `.public` deliberately for safe
///   metadata (counts, status codes, role names, peer fingerprints
///   that aren't IPs) and `.private` for anything PII-adjacent
///   (filenames, URLs the user typed, IP addresses, paths).
///
///   When in doubt, mark `.private`.  Privacy errs on the side of
///   silence; users who want to debug can opt-in with the `private_data`
///   sysctl.  Never log secrets (auth tokens, certificates, keys) at
///   any privacy level.
///
/// **Usage:**
///
///     Log.fleet.debug("accept from \(remote, privacy: .private(mask: .hash))")
///     Log.torrent.error("piece \(index, privacy: .public) verify fail")
///     Log.lan.notice("\(peers.count, privacy: .public) peers in 30s")
///
/// **Levels** (least → most severe; pick the lowest that's still useful):
///
///     .debug    — verbose, off by default in release.  Use freely.
///     .info     — interesting but not problems.  Off by default; users
///                 enable with `log stream --level=info --predicate=...`.
///     .notice   — default level, persisted in archive.  Use sparingly
///                 for state transitions worth keeping.
///     .error    — recoverable failures.  Always persisted.
///     .fault    — programmer errors / corruption indicators.  Rare.
///
/// All categories live in this file so `grep "Log\."` enumerates the
/// product's logging surface in one shot.
enum Log {

    private static let subsystem = "app.splynek"

    /// FleetCoordinator: REST server, peer accept/reject, rate-limit
    /// decisions, OAuth-style token validation.
    static let fleet = Logger(subsystem: subsystem, category: "fleet")

    /// BitTorrent core: piece selection, verification, peer protocol,
    /// DHT, tracker exchange, seeding lifecycle.
    static let torrent = Logger(subsystem: subsystem, category: "torrent")

    /// LANPeer: Bonjour discovery, mDNS, phone-pairing handshake.
    static let lan = Logger(subsystem: subsystem, category: "lan")

    /// SovereigntyScanner / WatchedFolder / Quarantine: filesystem
    /// scanning, periodic timers, scan-result diffing.
    static let scan = Logger(subsystem: subsystem, category: "scan")

    /// Multi-interface routing: NWPath observation, NWConnection
    /// per-interface, IP_BOUND_IF socket option dance.
    static let net = Logger(subsystem: subsystem, category: "net")

    /// DownloadJob / DownloadQueue / DownloadHistory: lifecycle
    /// transitions, throughput sampling, queue runner pumps.
    static let download = Logger(subsystem: subsystem, category: "download")

    /// AppIntents, Spotlight, MenuBar, Notifications: system-level
    /// integrations users notice when they fail silently.
    static let system = Logger(subsystem: subsystem, category: "system")

    /// Catalog (Sovereignty + Trust): scan results, per-app score
    /// computation, axis-weight sanitisation.
    static let catalog = Logger(subsystem: subsystem, category: "catalog")
}
