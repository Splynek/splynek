import Foundation
import CryptoKit
@testable import SplynekCore

/// Strategy Bet S6 — File Witness — invariant tests.
///
/// These tests don't touch the Keychain (sandbox-isolation pain in
/// CI) — instead they exercise `DownloadReceipt.canonicalUnsignedJSON`
/// + the verify path against ad-hoc keypairs.  The on-disk
/// `ReceiptStore.mintAndStore` integration is verified at runtime.
enum DownloadReceiptTests {

    static func run() {
        TestHarness.suite("DownloadReceipt — canonical JSON") {

            TestHarness.test("Sorted keys, no whitespace, integer not double") {
                let payload = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/file.iso",
                    sha256: "deadbeef" + String(repeating: "0", count: 56),
                    sizeBytes: 1234567890,
                    finishedAt: "2026-05-14T10:23:41Z",
                    devicePubkey: "ABCDABCDABCDABCDABCDABCDABCDABCDABCDABCDABCD="
                )
                let s = String(decoding: payload, as: UTF8.self)
                // Sorted keys → "device_pubkey" before "finished_at" before
                // "sha256" before "size_bytes" before "splynek_receipt_schema"
                // before "url".
                let order = ["device_pubkey", "finished_at", "sha256",
                             "size_bytes", "splynek_receipt_schema", "url"]
                var lastIdx = -1
                for k in order {
                    let idx = s.range(of: "\"\(k)\"")?.lowerBound
                    try expect(idx != nil, "Missing key \(k) in canonical JSON")
                    if let idx {
                        let pos = s.distance(from: s.startIndex, to: idx)
                        try expect(pos > lastIdx, "Keys out of sorted order at \(k)")
                        lastIdx = pos
                    }
                }
                // Integer must not be scientific-notation.
                try expect(s.contains("1234567890"), "Integer mangled: \(s)")
                try expect(!s.contains("1.23"), "Scientific notation leak: \(s)")
            }

            TestHarness.test("Same input produces byte-identical output") {
                let a = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/x", sha256: "a",
                    sizeBytes: 1, finishedAt: "Z",
                    devicePubkey: "P"
                )
                let b = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/x", sha256: "a",
                    sizeBytes: 1, finishedAt: "Z",
                    devicePubkey: "P"
                )
                try expect(a == b, "Canonical JSON not stable")
            }

            TestHarness.test("Different sha256 produces different bytes") {
                let a = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/x", sha256: "a",
                    sizeBytes: 1, finishedAt: "Z",
                    devicePubkey: "P"
                )
                let b = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/x", sha256: "b",
                    sizeBytes: 1, finishedAt: "Z",
                    devicePubkey: "P"
                )
                try expect(a != b)
            }
        }

        TestHarness.suite("DownloadReceipt — sign + verify roundtrip") {

            TestHarness.test("Sign with one key, verify with same key → valid") {
                let key = Curve25519.Signing.PrivateKey()
                let pubkey = key.publicKey.rawRepresentation.base64EncodedString()
                let unsigned = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/x.iso",
                    sha256: String(repeating: "a", count: 64),
                    sizeBytes: 100,
                    finishedAt: "2026-05-14T10:23:41Z",
                    devicePubkey: pubkey
                )
                let sig = try key.signature(for: unsigned).base64EncodedString()
                let r = DownloadReceipt(
                    url: "https://example.com/x.iso",
                    sha256: String(repeating: "a", count: 64),
                    sizeBytes: 100,
                    finishedAt: DownloadReceipt.date(fromIso8601: "2026-05-14T10:23:41Z")!,
                    devicePubkey: pubkey,
                    signature: sig
                )
                try expect(r.verify(), "Self-verify should succeed")
            }

            TestHarness.test("Tampered URL invalidates the signature") {
                let key = Curve25519.Signing.PrivateKey()
                let pubkey = key.publicKey.rawRepresentation.base64EncodedString()
                let unsigned = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/honest.iso",
                    sha256: String(repeating: "a", count: 64),
                    sizeBytes: 100,
                    finishedAt: "2026-05-14T10:23:41Z",
                    devicePubkey: pubkey
                )
                let sig = try key.signature(for: unsigned).base64EncodedString()
                // Build a receipt with a DIFFERENT url than what was signed.
                let r = DownloadReceipt(
                    url: "https://evil.example.com/malware.iso",
                    sha256: String(repeating: "a", count: 64),
                    sizeBytes: 100,
                    finishedAt: DownloadReceipt.date(fromIso8601: "2026-05-14T10:23:41Z")!,
                    devicePubkey: pubkey,
                    signature: sig
                )
                try expect(!r.verify(), "Tampered URL should fail verify")
            }

            TestHarness.test("Tampered sha256 invalidates the signature") {
                let key = Curve25519.Signing.PrivateKey()
                let pubkey = key.publicKey.rawRepresentation.base64EncodedString()
                let unsigned = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/x",
                    sha256: String(repeating: "a", count: 64),
                    sizeBytes: 100,
                    finishedAt: "2026-05-14T10:23:41Z",
                    devicePubkey: pubkey
                )
                let sig = try key.signature(for: unsigned).base64EncodedString()
                let r = DownloadReceipt(
                    url: "https://example.com/x",
                    sha256: String(repeating: "b", count: 64),  // ← tampered
                    sizeBytes: 100,
                    finishedAt: DownloadReceipt.date(fromIso8601: "2026-05-14T10:23:41Z")!,
                    devicePubkey: pubkey,
                    signature: sig
                )
                try expect(!r.verify(), "Tampered sha256 should fail verify")
            }

            TestHarness.test("Wrong key (forged) does not verify") {
                let signer = Curve25519.Signing.PrivateKey()
                let attacker = Curve25519.Signing.PrivateKey()
                let signerPub = signer.publicKey.rawRepresentation.base64EncodedString()
                let unsigned = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/x",
                    sha256: String(repeating: "a", count: 64),
                    sizeBytes: 100,
                    finishedAt: "2026-05-14T10:23:41Z",
                    devicePubkey: signerPub
                )
                // Attacker tries to sign with their own key but claim
                // signer's pubkey.
                let forgedSig = try attacker.signature(for: unsigned).base64EncodedString()
                let r = DownloadReceipt(
                    url: "https://example.com/x",
                    sha256: String(repeating: "a", count: 64),
                    sizeBytes: 100,
                    finishedAt: DownloadReceipt.date(fromIso8601: "2026-05-14T10:23:41Z")!,
                    devicePubkey: signerPub,  // ← claims to be signer
                    signature: forgedSig       // ← actually attacker's signature
                )
                try expect(!r.verify(), "Forged signature should fail verify")
            }

            TestHarness.test("JSON encode/decode roundtrip preserves verifiability") {
                let key = Curve25519.Signing.PrivateKey()
                let pubkey = key.publicKey.rawRepresentation.base64EncodedString()
                let unsigned = try DownloadReceipt.canonicalUnsignedJSON(
                    url: "https://example.com/file.iso",
                    sha256: String(repeating: "c", count: 64),
                    sizeBytes: 5_000_000_000,
                    finishedAt: "2026-05-14T10:23:41Z",
                    devicePubkey: pubkey
                )
                let sig = try key.signature(for: unsigned).base64EncodedString()
                let r = DownloadReceipt(
                    url: "https://example.com/file.iso",
                    sha256: String(repeating: "c", count: 64),
                    sizeBytes: 5_000_000_000,
                    finishedAt: DownloadReceipt.date(fromIso8601: "2026-05-14T10:23:41Z")!,
                    devicePubkey: pubkey,
                    signature: sig
                )
                let json = try r.prettyJSON()
                let decoded = try JSONDecoder().decode(DownloadReceipt.self, from: json)
                try expect(decoded == r, "Encode/decode roundtrip lost data")
                try expect(decoded.verify(), "Decoded receipt should still verify")
            }
        }

        TestHarness.suite("DownloadReceipt — schema") {

            TestHarness.test("Schema version is exposed") {
                try expectEqual(DownloadReceipt.schemaVersion, 1)
            }

            TestHarness.test("ISO 8601 round-trip") {
                let now = Date(timeIntervalSince1970: 1_780_000_000)  // 2026-vintage
                let s = DownloadReceipt.iso8601(from: now)
                try expect(s.hasSuffix("Z"), "Must use Z suffix, got: \(s)")
                let back = DownloadReceipt.date(fromIso8601: s)
                try expect(back != nil, "Failed to parse: \(s)")
                if let back {
                    let delta = abs(back.timeIntervalSince(now))
                    try expect(delta < 1.0, "Roundtrip drift: \(delta)s")
                }
            }
        }
    }
}
