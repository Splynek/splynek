import Foundation
import CryptoKit
import Security

/// Strategy Bet S6 — File Witness.
///
/// Manages a per-device Ed25519 signing key.  Keypair is created
/// lazily on first call to `publicKey` or `sign(...)` and persisted
/// as a Keychain generic-password item that's marked
/// `kSecAttrAccessibleAfterFirstUnlock` (survives reboot once the
/// user has logged in) and **not** synchronizable to iCloud.
///
/// Threat model:
/// - The signing key never leaves the device.  Receipts attest "this
///   download happened on this Mac", not "this download exists on the
///   internet."  A user moving to a new Mac gets a fresh keypair —
///   that's expected.
/// - The public key is embedded in every receipt.  Verifiers extract
///   it from the receipt itself; there's no central CA, no
///   PKI-style chain.  The receipt is self-contained.
/// - If the Mac is wiped, the key is gone.  Existing receipts can
///   still be verified by anyone (the public key is in each receipt),
///   but no NEW receipts can be re-signed for the old downloads.
///   That's correct: receipts are point-in-time attestations.
///
/// Sandbox compatibility: the Keychain item is stored in the app's
/// Keychain access group, which is bound to the bundle ID + Team ID.
/// Both the DMG (Developer-ID-signed) and MAS (Apple-Distribution-
/// signed) builds use the same bundle ID so receipts minted in one
/// build verify identically when the binary's swapped.
@MainActor
public final class DeviceKeyManager {

    /// Service name for the Keychain generic-password item.  Bundle
    /// ID + a stable suffix so future key types (encryption,
    /// authentication, etc.) get distinct slots.
    private static let keychainService = "app.splynek.Splynek.deviceSigningKey.v1"
    private static let keychainAccount = "Splynek Device Identity"

    /// Singleton — there's only one device identity per install.
    public static let shared = DeviceKeyManager()

    /// In-memory cache of the keypair to avoid hitting the Keychain
    /// on every receipt mint.  Cleared if `rotate()` is called.
    private var cachedKey: Curve25519.Signing.PrivateKey?

    private init() {}

    /// The device's public key, base64-encoded raw bytes.  Embeds in
    /// every receipt; verifiers reconstruct the verification key from
    /// it.  Lazy: creates a fresh keypair on first access if none is
    /// stored.
    public func publicKeyBase64() throws -> String {
        let key = try loadOrCreate()
        return key.publicKey.rawRepresentation.base64EncodedString()
    }

    /// Sign `data` with the device's signing key.  Returns the raw
    /// 64-byte Ed25519 signature, base64-encoded.
    public func sign(_ data: Data) throws -> String {
        let key = try loadOrCreate()
        let sig = try key.signature(for: data)
        return sig.base64EncodedString()
    }

    /// Verify a signature against this device's PUBLIC key.  Mostly
    /// for unit-test convenience — real verifiers reconstruct the
    /// pubkey from the receipt's embedded `device_pubkey` field.
    public func verify(_ signatureBase64: String, of data: Data) throws -> Bool {
        let key = try loadOrCreate()
        guard let sig = Data(base64Encoded: signatureBase64) else { return false }
        return key.publicKey.isValidSignature(sig, for: data)
    }

    /// Discard the cached private key + delete the Keychain item.
    /// Next sign/publicKey call will create a fresh keypair.  Used
    /// for "Reset device identity" in Settings — disconnects future
    /// receipts from prior receipts.
    public func rotate() throws {
        cachedKey = nil
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        _ = SecItemDelete(q as CFDictionary)
    }

    // MARK: - Private

    private func loadOrCreate() throws -> Curve25519.Signing.PrivateKey {
        if let cached = cachedKey { return cached }
        if let existing = try Self.loadFromKeychain() {
            cachedKey = existing
            return existing
        }
        let fresh = Curve25519.Signing.PrivateKey()
        try Self.storeInKeychain(fresh)
        cachedKey = fresh
        return fresh
    }

    /// Load the persisted private key from the Keychain.  Returns nil
    /// if no item exists (caller creates fresh).
    static func loadFromKeychain() throws -> Curve25519.Signing.PrivateKey? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeyError.keychainRead(status)
        }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    static func storeInKeychain(_ key: Curve25519.Signing.PrivateKey) throws {
        let raw = key.rawRepresentation
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: raw,
        ]
        let status = SecItemAdd(attrs as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw KeyError.keychainWrite(status)
        }
        // If duplicate (race), update in place.
        if status == errSecDuplicateItem {
            let q: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: keychainAccount,
            ]
            let upd: [String: Any] = [kSecValueData as String: raw]
            let s2 = SecItemUpdate(q as CFDictionary, upd as CFDictionary)
            guard s2 == errSecSuccess else { throw KeyError.keychainWrite(s2) }
        }
    }

    public enum KeyError: Error, CustomStringConvertible {
        case keychainRead(OSStatus)
        case keychainWrite(OSStatus)

        public var description: String {
            switch self {
            case .keychainRead(let s):  return "Keychain read failed (status \(s))"
            case .keychainWrite(let s): return "Keychain write failed (status \(s))"
            }
        }
    }
}
