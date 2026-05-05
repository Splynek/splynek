import Foundation
import CryptoKit

/// Strategy Bet S6 — File Witness.
///
/// A `DownloadReceipt` is a self-contained, cryptographically-signed
/// attestation that a specific download finished on this Mac.  Format:
///
/// ```
/// {
///   "splynek_receipt_schema": 1,
///   "url": "https://releases.ubuntu.com/24.04/ubuntu-24.04.iso",
///   "sha256": "a1b2c3...",
///   "size_bytes": 5800134656,
///   "finished_at": "2026-05-14T10:23:41Z",
///   "device_pubkey": "<base64 Ed25519 pubkey>",
///   "signature": "<base64 Ed25519 signature>"
/// }
/// ```
///
/// The signature covers the canonical JSON of every field EXCEPT
/// `signature` itself.  Canonical = sorted keys, no whitespace, no
/// trailing newline — matches what
/// `JSONSerialization.WritingOptions.sortedKeys` produces.
///
/// Use cases:
/// - **Journalists** documenting the source URL of a downloaded
///   document for a story
/// - **Academics** proving the exact dataset they cited
/// - **Build engineers** asserting the exact tarball hash they
///   built against
/// - **Compliance teams** establishing chain-of-custody for
///   downloaded artifacts
///
/// Anyone with the receipt can verify it offline using
/// `Scripts/verify-splynek-receipt.swift` or any Ed25519 verifier
/// that knows how to canonicalize JSON.
public struct DownloadReceipt: Codable, Equatable, Sendable {

    public static let schemaVersion: Int = 1

    public let splynek_receipt_schema: Int
    public let url: String
    public let sha256: String
    public let size_bytes: Int64
    public let finished_at: String  // ISO 8601 with explicit "Z" suffix
    public let device_pubkey: String  // base64 Ed25519 public key
    public let signature: String  // base64 Ed25519 signature

    public init(
        url: String,
        sha256: String,
        sizeBytes: Int64,
        finishedAt: Date,
        devicePubkey: String,
        signature: String
    ) {
        self.splynek_receipt_schema = Self.schemaVersion
        self.url = url
        self.sha256 = sha256
        self.size_bytes = sizeBytes
        self.finished_at = Self.iso8601(from: finishedAt)
        self.device_pubkey = devicePubkey
        self.signature = signature
    }

    /// ISO 8601 in UTC with the explicit "Z" suffix (not `+00:00`).
    /// Stable across locales — important because the receipt is the
    /// canonical artifact and stringly-typed timestamps without a
    /// fixed format are an interop nightmare.
    public static func iso8601(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }

    public static func date(fromIso8601 s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    // MARK: - Mint + verify

    /// Produce a fresh receipt for `(url, sha256, size, finishedAt)`,
    /// signed with the device's Ed25519 key.  Synchronous because
    /// the only async surface is the Keychain, and that's lazy.
    @MainActor
    public static func mint(
        url: URL,
        sha256: String,
        sizeBytes: Int64,
        finishedAt: Date = Date(),
        keys: DeviceKeyManager? = nil
    ) throws -> DownloadReceipt {
        // Resolve the default inside the @MainActor body so the
        // singleton access is in a main-isolated context.  Default
        // parameter values are nonisolated and would warn under
        // Swift 6 strict concurrency.
        let keys = keys ?? DeviceKeyManager.shared
        let pubkey = try keys.publicKeyBase64()
        let unsignedPayload = try canonicalUnsignedJSON(
            url: url.absoluteString,
            sha256: sha256.lowercased(),
            sizeBytes: sizeBytes,
            finishedAt: Self.iso8601(from: finishedAt),
            devicePubkey: pubkey
        )
        let signature = try keys.sign(unsignedPayload)
        return DownloadReceipt(
            url: url.absoluteString,
            sha256: sha256.lowercased(),
            sizeBytes: sizeBytes,
            finishedAt: finishedAt,
            devicePubkey: pubkey,
            signature: signature
        )
    }

    /// Verify the receipt against its OWN embedded public key.  No
    /// trust chain — the verifier is asserting "this receipt is
    /// internally consistent + the bytes match".  External trust
    /// (does the public key belong to who I think it does?) is the
    /// receipt-consumer's responsibility, not the receipt's.
    public func verify() -> Bool {
        // Reconstruct the canonicalization that was signed.
        guard let unsigned = try? Self.canonicalUnsignedJSON(
            url: url,
            sha256: sha256,
            sizeBytes: size_bytes,
            finishedAt: finished_at,
            devicePubkey: device_pubkey
        ) else { return false }
        guard let pubkeyData = Data(base64Encoded: device_pubkey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: pubkeyData),
              let sigData = Data(base64Encoded: signature)
        else { return false }
        return key.isValidSignature(sigData, for: unsigned)
    }

    /// Build the canonical-JSON payload that gets signed.
    /// `JSONSerialization.WritingOptions.sortedKeys` produces stable
    /// output across Swift / Python / Node / Go runtimes — that's
    /// what makes the signature interoperable.
    static func canonicalUnsignedJSON(
        url: String,
        sha256: String,
        sizeBytes: Int64,
        finishedAt: String,
        devicePubkey: String
    ) throws -> Data {
        // Use NSNumber wrapper so the JSON serializer emits an integer,
        // not a double-cast to scientific notation.
        let dict: [String: Any] = [
            "splynek_receipt_schema": Self.schemaVersion,
            "url": url,
            "sha256": sha256,
            "size_bytes": NSNumber(value: sizeBytes),
            "finished_at": finishedAt,
            "device_pubkey": devicePubkey,
        ]
        return try JSONSerialization.data(
            withJSONObject: dict,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    /// Pretty JSON for the export panel + the receipts/ on-disk
    /// store.  Sorted keys + 2-space indent + trailing newline.
    public func prettyJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var out = try encoder.encode(self)
        if let nl = "\n".data(using: .utf8) { out.append(nl) }
        return out
    }
}
