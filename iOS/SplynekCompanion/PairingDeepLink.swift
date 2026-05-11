// Copyright © 2026 Splynek. MIT.
//
// PairingDeepLink — handles `splynek://pair?host=…&port=…&token=…`
// URLs that arrive via `.onOpenURL`.  The Mac's "Copy pair URL"
// button (AgentsView.iPhonePairingRow) writes this string to the
// pasteboard; if the user opens it from Messages / Mail / Notes /
// Universal Clipboard, iOS routes it here.
//
// Idempotent: re-arriving with the same Mac UUID upserts rather
// than duplicates.  Probes the Mac before persisting so a bad
// link doesn't leave an unreachable entry hanging in the list.
//
// Sprint 9 / v2.0.1 polish (2026-05-11).

#if os(iOS)

import Foundation
import os

enum PairingDeepLink {
    private static let log = Logger(subsystem: "app.splynek.companion", category: "PairingDeepLink")

    @MainActor
    static func handle(url: URL) async {
        guard url.scheme?.lowercased() == "splynek",
              url.host?.lowercased() == "pair" else {
            log.debug("Ignored non-pair URL: \(url.absoluteString, privacy: .public)")
            return
        }
        guard let c = SplynekPairURL.decode(from: url.absoluteString) else {
            log.error("splynek:// URL didn't parse as a pairing link")
            return
        }
        guard let store = PairedMacStore() else {
            log.error("App Group store unavailable; can't persist pairing")
            return
        }

        // Probe before persisting so a bad token / stale Mac doesn't
        // leave a zombie entry.  Caller is on the main actor.
        let candidate = PairedMac(
            uuid: UUID().uuidString,        // overwritten on first poll
            displayName: c.name ?? "My Mac",
            lastKnownHost: c.host,
            lastKnownPort: c.port,
            token: c.token,
            lastSeen: Date()
        )
        let client = PairedMacClient(mac: candidate)
        do {
            _ = try await client.ping()
        } catch {
            log.error("Pair URL pointed at unreachable Mac: \(error.localizedDescription, privacy: .public)")
            return
        }

        _ = store.upsert(candidate)
        // Hand the Watch the new snapshot.
        if #available(iOS 16.0, *) {
            PhoneWatchSync.shared.push()
        }
        log.info("Deep-link pair succeeded for \(candidate.displayName, privacy: .public)")
    }
}

#endif
