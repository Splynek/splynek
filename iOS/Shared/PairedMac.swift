// Copyright © 2026 Splynek. MIT.
//
// PairedMac — the iOS companion's record of one Splynek-Mac it has been
// paired with.  Persisted in the shared App Group keychain so both the
// main app + the Share Extension can read it.
//
// One iOS device can pair with several Macs (work / home / lab); the
// Share Extension surfaces the list and lets the user pick.  Most
// people have one Mac and the share sheet should auto-pick it.

import Foundation

/// A Mac that the iOS companion has been paired with.  Stable across
/// app launches; identified by the Mac's `uuid` TXT-record value
/// (matches `FleetCoordinator.deviceUUID`).
public struct PairedMac: Codable, Hashable, Identifiable, Sendable {
    /// Stable Mac UUID from its Bonjour TXT record.  Survives the Mac
    /// changing its IP, hostname, or display name.
    public var id: String { uuid }

    public let uuid: String
    /// Display name as the Mac advertises it ("Paulo's MacBook Pro").
    /// Mutable: the user can rename their Mac.
    public var displayName: String
    /// Last-known LAN host for `URLSession` requests.  Re-resolved via
    /// Bonjour every time the app foregrounds; this is just the
    /// last-good fallback for the Share Extension's first request,
    /// which has ~30s of headroom before iOS kills the extension.
    public var lastKnownHost: String
    public var lastKnownPort: Int
    /// FleetCoordinator `webToken`.  Pasted by the user during pairing
    /// (or QR-scanned in a future round).  Stored in the keychain
    /// item, NOT in this struct's plist — kept here only at runtime.
    /// On disk this field is empty; the keychain holds the real value.
    public var token: String
    /// When this pairing was last confirmed working (a successful
    /// `/splynek/v1/status` response).  Used to grey out stale pairings
    /// in the UI.
    public var lastSeen: Date

    public init(uuid: String, displayName: String, lastKnownHost: String,
                lastKnownPort: Int, token: String, lastSeen: Date) {
        self.uuid = uuid
        self.displayName = displayName
        self.lastKnownHost = lastKnownHost
        self.lastKnownPort = lastKnownPort
        self.token = token
        self.lastSeen = lastSeen
    }

    /// The base URL for hitting this Mac's Splynek REST API.  Always
    /// http:// — Splynek's LAN server doesn't terminate TLS (and the
    /// iOS deployment target has `NSAllowsLocalNetworking` set).
    public var baseURL: URL? {
        URL(string: "http://\(lastKnownHost):\(lastKnownPort)")
    }
}
