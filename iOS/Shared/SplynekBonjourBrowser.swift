// Copyright © 2026 Splynek. MIT.
//
// SplynekBonjourBrowser — discovers Macs running Splynek on the
// current LAN.  Wraps `NWBrowser` for the `_splynek-fleet._tcp`
// service (the same one FleetCoordinator advertises).
//
// Used in two places on iOS:
//
//  1. The pairing flow's Mac picker — "Add a Mac" lists every Mac
//     currently on the LAN, the user taps one, then pastes / scans
//     the token.
//
//  2. The Share Extension's address-refresh path — when the user
//     paired a Mac last week and its IP has changed since, we
//     re-resolve via Bonjour before posting the URL so the request
//     goes to the right host.
//
// The Mac's TXT record carries: `uuid` (stable), `name` (display),
// `ver` (FleetCoordinator version), `swarm` (1 if peering enabled).
// We decode all four; the Bonjour-only `port` comes from the
// resolved endpoint.

import Foundation
#if canImport(Network)
import Network
#endif

#if canImport(Network)
public final class SplynekBonjourBrowser {
    public struct Discovered: Hashable, Identifiable, Sendable {
        public let uuid: String       // TXT["uuid"]
        public let displayName: String
        public let host: String       // resolved hostname or IP
        public let port: Int
        public let swarmCapable: Bool // TXT["swarm"] == "1"
        public let version: String    // TXT["ver"]
        public var id: String { uuid }
    }

    private var browser: NWBrowser?
    private let serviceType: String
    private let queue: DispatchQueue

    public init(serviceType: String = "_splynek-fleet._tcp") {
        self.serviceType = serviceType
        self.queue = DispatchQueue(label: "splynek.companion.bonjour", qos: .utility)
    }

    /// Start browsing.  `onChange` is invoked on the main queue with
    /// the current set every time results change.  Idempotent — calling
    /// `start` twice replaces the browser without leaking the old one.
    @MainActor
    public func start(onChange: @escaping ([Discovered]) -> Void) {
        stop()
        let params = NWParameters()
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
            type: serviceType, domain: nil
        )
        let browser = NWBrowser(for: descriptor, using: params)
        self.browser = browser
        browser.browseResultsChangedHandler = { results, _ in
            // Static decode: no per-instance state needed; safe to
            // drop the [weak self] capture (the warning the compiler
            // raised about `self` being unused).
            let mapped = Self.decode(results: Array(results))
            DispatchQueue.main.async { onChange(mapped) }
        }
        browser.start(queue: queue)
    }

    @MainActor
    public func stop() {
        browser?.cancel()
        browser = nil
    }

    /// Pure decoding — exposed for unit tests.  Takes whatever
    /// `NWBrowser.browseResultsChangedHandler` saw and returns the
    /// `Discovered` list, sorted by displayName.
    public static func decode(results: [NWBrowser.Result]) -> [Discovered] {
        var out: [Discovered] = []
        for r in results {
            guard case let .service(name, _, _, _) = r.endpoint else { continue }
            guard case let .bonjour(txt) = r.metadata else { continue }
            guard let uuid = txt["uuid"] else { continue }
            let displayName = txt["name"] ?? name
            let swarm = (txt["swarm"] ?? "0") == "1"
            let ver = txt["ver"] ?? "?"
            // The endpoint doesn't carry a resolved host/port on iOS
            // until we open a connection.  We surface the Bonjour
            // service name + a placeholder "<resolve>:0" pair; callers
            // resolve via NWConnection when ready to talk.
            out.append(.init(
                uuid: uuid,
                displayName: displayName,
                host: name,    // Bonjour service name; resolved later
                port: 0,       // ditto
                swarmCapable: swarm,
                version: ver
            ))
        }
        return out.sorted { $0.displayName < $1.displayName }
    }
}
#endif

/// Pure TXT decoder — works on platforms without `Network.framework`
/// (so unit tests on macOS-only Linux runners can hit it).  Takes
/// `[String: String]` (the same shape `NWBrowser` exposes after
/// `case .bonjour(let txt)`) and returns the Discovered fields, or
/// `nil` if the required `uuid` key is missing.
public enum SplynekTXTRecord {
    public struct Decoded: Hashable, Sendable {
        public let uuid: String
        public let displayName: String?
        public let swarmCapable: Bool
        public let version: String
    }

    public static func decode(_ txt: [String: String], serviceName: String) -> Decoded? {
        guard let uuid = txt["uuid"] else { return nil }
        return Decoded(
            uuid: uuid,
            displayName: txt["name"] ?? serviceName,
            swarmCapable: (txt["swarm"] ?? "0") == "1",
            version: txt["ver"] ?? "?"
        )
    }
}
