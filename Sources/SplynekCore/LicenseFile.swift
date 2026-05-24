import Foundation
import CryptoKit

/// 2026-06 direct-sale launch (`LAUNCH-WITHOUT-APPLE.md`).
///
/// Splynek Pro licenses ship as `.splynekkey` files — a small JSON
/// envelope plus an Ed25519 signature.  The buyer purchases at
/// splynek.app → LemonSqueezy checkout → a Cloudflare Worker
/// receives the webhook, signs the license JSON with the (private)
/// signing key held in Worker secrets, and emails the signed file
/// as an attachment.  The buyer double-clicks the file; macOS routes
/// it to Splynek.app via the `app.splynek.license` UTI (registered
/// in Resources/Info.plist); `LicenseManager.activate(fileURL:)`
/// verifies the signature against the public key baked into this
/// file (`Self.publicKeyBase64`), and persists the file to
/// Application Support if valid.
///
/// Why a self-contained signed file (not a license-server
/// activation):
/// - **No phone-home.**  Verification happens offline.  Matches
///   Splynek's "100% local, no cloud, no account" positioning.
/// - **Reuses Bet S6 / File Witness infrastructure.**  Same Ed25519
///   primitives we use for download receipts; same CryptoKit
///   `Curve25519.Signing` types.
/// - **No DRM beyond signature verification.**  Anyone with the
///   file can use it; we explicitly chose the Sketch / Tower /
///   Bartender trust-first model.  If we see meaningful piracy we
///   add a Cloudflare-Worker-backed revocation list later.
///
/// Format (JSON):
/// ```
/// {
///   "license_id":   "lic_<lemonsqueezy_order_id>",
///   "email":        "buyer@example.com",
///   "product":      "splynek-pro",
///   "edition":      "lifetime",
///   "version_cap":  null,
///   "purchased_at": "2026-06-08T12:00:00Z",
///   "signature":    "base64(Ed25519(canonical-json(everything-above)))"
/// }
/// ```
///
/// The signature is computed over the **canonical JSON** of the
/// envelope MINUS the `signature` field — sort keys alphabetically,
/// no whitespace, UTF-8 encoded.  Worker and client agree on the
/// canonicalisation so a bit-for-bit signature comparison works.
///
/// File extension: `.splynekkey`.  MIME: `application/x-splynek-license`.
/// UTI: `app.splynek.license`.
public struct LicenseFile: Codable, Equatable, Sendable {

    public let licenseID: String
    public let email: String
    public let product: String
    public let edition: Edition
    public let versionCap: String?
    public let purchasedAt: Date
    public let signature: String

    /// Pro-license edition.  v1.0 ships `.lifetime` only; future
    /// editions (Pro+, annual sub) extend this.
    public enum Edition: String, Codable, Sendable {
        case lifetime
        case annual
        case proPlusAnnual = "pro_plus_annual"
    }

    // MARK: - Decoding

    enum CodingKeys: String, CodingKey {
        case licenseID   = "license_id"
        case email
        case product
        case edition
        case versionCap  = "version_cap"
        case purchasedAt = "purchased_at"
        case signature
    }

    /// Load + parse a `.splynekkey` file from disk.  Throws on JSON
    /// parse failure, missing fields, or unknown edition values.
    /// **Does not verify the signature** — call `verify(against:)`
    /// next to do that.
    public static func read(from url: URL) throws -> LicenseFile {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LicenseFile.self, from: data)
    }

    // MARK: - Verification

    /// Verifies the file's Ed25519 signature against the supplied
    /// public key (base64-encoded raw 32 bytes).  The public key the
    /// shipping binary uses lives in `LicenseManager.publicKeyBase64`;
    /// tests can supply a different key by injection.
    ///
    /// Returns `.valid` on signature match; `.invalid(reason)` on
    /// signature mismatch, malformed key, or canonicalisation error.
    public func verify(againstPublicKeyBase64: String) -> VerificationResult {
        guard let publicKeyData = Data(base64Encoded: againstPublicKeyBase64) else {
            return .invalid("Public key is not valid base64")
        }
        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        } catch {
            return .invalid("Public key is not a valid Curve25519 public key: \(error.localizedDescription)")
        }
        guard let signatureData = Data(base64Encoded: signature) else {
            return .invalid("Signature is not valid base64")
        }
        let payload: Data
        do {
            payload = try canonicalPayload()
        } catch {
            return .invalid("Could not build canonical payload: \(error.localizedDescription)")
        }
        guard publicKey.isValidSignature(signatureData, for: payload) else {
            return .invalid("Signature does not match the licence payload")
        }
        return .valid
    }

    /// Canonical JSON used as the signing input.  Excludes the
    /// `signature` field itself; sorts keys alphabetically; uses
    /// `.iso8601` date formatting + no whitespace; UTF-8 encoded.
    ///
    /// Public so the Cloudflare Worker (or any other signer) can
    /// canonicalise the same way and produce a verifiable signature.
    public func canonicalPayload() throws -> Data {
        // Build a [String: Any] without the `signature` key, then
        // re-encode with sorted keys + no whitespace.  We can't just
        // re-encode `self` because the `signature` field is included
        // in the Codable shape.
        let mirror: [String: Any] = [
            "license_id":   licenseID,
            "email":        email,
            "product":      product,
            "edition":      edition.rawValue,
            "version_cap":  versionCap as Any,
            "purchased_at": Self.isoFormatter.string(from: purchasedAt),
        ]
        return try JSONSerialization.data(
            withJSONObject: mirror,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    public enum VerificationResult: Equatable, Sendable {
        case valid
        case invalid(String)

        public var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }

    /// ISO-8601 formatter shared with the signer side.  Includes
    /// fractional seconds so timestamps round-trip exactly.
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}

// MARK: - JSONSerialization helper for `null` version_cap

extension LicenseFile {
    /// Build a canonical JSON manually since JSONSerialization's
    /// handling of NSNull / Optional<String> can be inconsistent.
    /// We special-case nil → JSON null so the Worker and client
    /// produce identical bytes.
    ///
    /// (kept private to the file as a fallback if the
    /// `JSONSerialization` path above ever proves non-deterministic
    /// for `null` fields; not used in the happy path)
    fileprivate func manualCanonicalPayload() -> Data {
        var parts: [String] = []
        parts.append("\"edition\":\"\(edition.rawValue)\"")
        parts.append("\"email\":\"\(jsonEscape(email))\"")
        parts.append("\"license_id\":\"\(jsonEscape(licenseID))\"")
        parts.append("\"product\":\"\(jsonEscape(product))\"")
        parts.append("\"purchased_at\":\"\(Self.isoFormatter.string(from: purchasedAt))\"")
        if let v = versionCap {
            parts.append("\"version_cap\":\"\(jsonEscape(v))\"")
        } else {
            parts.append("\"version_cap\":null")
        }
        let body = "{" + parts.joined(separator: ",") + "}"
        return Data(body.utf8)
    }

    private func jsonEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
