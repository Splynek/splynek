import Foundation
import CryptoKit

/// **Persistent API tokens** — Sprint 4 PRO-PLUS-IPHONE (2026-05-10).
///
/// "Aposta E" of `STRATEGY-2026-PRO-PLUS-IPHONE.md` (developer
/// power-up).  Lets the user mint named, persistent tokens for
/// external scripting clients — Raycast, Alfred, shell scripts,
/// BetterTouchTool, etc. — that don't share the session-rotating
/// webToken.
///
/// **Why a separate token registry?**  The existing `webToken` on
/// FleetCoordinator is a per-session secret that rotates on a
/// "Regenerate token" click + on every fresh app launch.  External
/// scripts can't follow that rotation — they need a stable secret.
/// API tokens fill that gap **without** weakening webToken's posture
/// for the iPhone Companion / browser dashboard flows that benefit
/// from rotation.
///
/// **Auth model**:
///   - FleetCoordinator validates tokens against the union of
///     `webToken` (session) AND `APITokenStore.tokens` (persistent).
///   - Match on either grants the same scope as the matched token's
///     `scope` field — read-only tokens can hit GET /api/* but not
///     mutating POST /api/*.
///   - Tokens are stored in plain text in
///     `~/Library/Application Support/Splynek/api-tokens.json` —
///     matches the LAN-trust posture (Mac filesystem owner is the
///     trust boundary; we don't add encryption that doesn't change
///     the threat model).
///
/// **MAS posture**: minted tokens never leave the device unless the
/// user copies one to a script.  No telemetry, no cloud sync.
///
/// **Pro gating**: minting + listing tokens requires Pro.  Free-tier
/// users see a ProLockedView upsell in Settings.

public enum APITokenScope: String, Codable, Sendable, CaseIterable {
    /// Token can hit any GET endpoint (jobs, summaries, history).
    /// Cannot queue, download, cancel, pause, resume.
    case readOnly

    /// Token can hit any endpoint, including mutating POSTs.
    /// Equivalent to the session webToken's scope.
    case readWrite

    public var label: String {
        switch self {
        case .readOnly:  return "Read-only"
        case .readWrite: return "Read + write"
        }
    }
}

public struct APIToken: Codable, Hashable, Sendable, Identifiable {
    /// Stable identifier (UUID) used for revocation.  Distinct
    /// from the secret; revealing the id is harmless.
    public let id: String

    /// Human-readable label set when minting ("Raycast",
    /// "Alfred workflow", "deploy.sh").
    public let label: String

    /// 32-byte hex secret the external client sends.  64 chars
    /// long; URL-safe; not a JWT — purely opaque to FleetCoordinator.
    public let secret: String

    /// Permission level.  Defaults to `.readWrite` to match the
    /// existing webToken's behaviour; UI offers .readOnly for
    /// scripts that don't need mutation.
    public let scope: APITokenScope

    /// ISO-8601 mint timestamp.
    public let createdAt: String

    /// ISO-8601 last-used timestamp, refreshed by FleetCoordinator
    /// on every accepted request.  Stored as String so the JSON
    /// stays human-diffable.  nil until first use.
    public var lastUsedAt: String?

    public init(id: String = UUID().uuidString,
                label: String,
                secret: String? = nil,
                scope: APITokenScope = .readWrite,
                createdAt: String = APIToken.iso8601(Date()),
                lastUsedAt: String? = nil) {
        self.id = id
        self.label = label
        self.secret = secret ?? APIToken.generateSecret()
        self.scope = scope
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    /// Generate a fresh 32-byte secret + return its hex form.
    /// Uses CryptoKit's SymmetricKey (CSRNG-backed) so secrets are
    /// indistinguishable from random.
    public static func generateSecret() -> String {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { bytes in
            bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    public static func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}

// MARK: - Persisted store

public struct APITokenStore: Codable, Sendable {
    public var tokens: [APIToken]

    public static let empty = APITokenStore(tokens: [])

    public init(tokens: [APIToken] = []) {
        self.tokens = tokens
    }

    /// Insert a fresh token at the head.
    public mutating func add(_ token: APIToken) {
        tokens.insert(token, at: 0)
    }

    /// Revoke by id.  Idempotent.
    public mutating func revoke(id: String) {
        tokens.removeAll { $0.id == id }
    }

    /// Mark a token's last-used timestamp.  No-op when the secret
    /// doesn't match anything in the store (stale request from
    /// a revoked token).
    public mutating func recordUse(secret: String, at date: Date) {
        guard let i = tokens.firstIndex(where: { $0.secret == secret }) else { return }
        tokens[i].lastUsedAt = APIToken.iso8601(date)
    }

    /// Look up a token by secret.  Returns nil for unknown secret
    /// or empty store.
    public func token(matching secret: String) -> APIToken? {
        tokens.first { $0.secret == secret }
    }
}

// MARK: - Disk I/O

public final class APITokenStoreFile: @unchecked Sendable {

    public static var _testOverrideURL: URL?

    private static var fileURL: URL {
        if let u = _testOverrideURL { return u }
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("api-tokens.json")
    }

    private let lock = NSLock()

    public init() {}

    public func read() -> APITokenStore {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: Self.fileURL),
              let store = try? JSONDecoder().decode(APITokenStore.self, from: data)
        else { return .empty }
        return store
    }

    public func mutate(_ block: (inout APITokenStore) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var store = (try? Data(contentsOf: Self.fileURL))
            .flatMap { try? JSONDecoder().decode(APITokenStore.self, from: $0) }
            ?? .empty
        block(&store)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(store) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    public static func _resetForTesting() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - Pure validation policy

/// Pure functions used by FleetCoordinator's token validator.
/// Single source of truth for "is this token allowed to do this?".
public enum APITokenValidator {

    /// Check whether a presented token (the `?t=<...>` query
    /// value or `X-Splynek-API-Token` header) is allowed to make
    /// a request of the given kind.  Returns the matched token's
    /// id when accepted (so the caller can record `lastUsedAt`),
    /// or nil when rejected.
    ///
    /// `webToken` always grants `.readWrite` — preserves the
    /// existing session-token semantics.  Persistent API tokens
    /// grant their own declared scope.
    public enum RequestKind {
        case read   // GET endpoints
        case write  // POST endpoints (queue, download, pause, etc.)
    }

    public enum Decision: Equatable {
        case acceptedSessionToken
        case acceptedAPIToken(id: String)
        case rejected
    }

    public static func decide(
        presented: String,
        webToken: String,
        store: APITokenStore,
        kind: RequestKind
    ) -> Decision {
        if presented == webToken && !presented.isEmpty {
            return .acceptedSessionToken
        }
        guard let token = store.token(matching: presented) else {
            return .rejected
        }
        switch (token.scope, kind) {
        case (.readWrite, _):
            return .acceptedAPIToken(id: token.id)
        case (.readOnly, .read):
            return .acceptedAPIToken(id: token.id)
        case (.readOnly, .write):
            return .rejected
        }
    }
}
