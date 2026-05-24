// Copyright © 2026 Splynek. MIT.
//
// LicenseFileTests — invariants for the .splynekkey Ed25519-signed
// licence format introduced by the 2026-06 direct-sale launch.  See
// LAUNCH-WITHOUT-APPLE.md § 5 and Sources/SplynekCore/LicenseFile.swift.

import Foundation
import CryptoKit
@testable import SplynekCore

enum LicenseFileTests {

    static func run() {
        TestHarness.suite("LicenseFile — Ed25519 envelope") {

            // Generate a fresh test keypair.  We sign + verify with
            // both sides of the pair so the test doesn't depend on
            // any hard-coded secret.
            let privateKey = Curve25519.Signing.PrivateKey()
            let publicKeyB64 = privateKey.publicKey.rawRepresentation.base64EncodedString()
            let purchaseDate = ISO8601DateFormatter().date(from: "2026-06-08T12:00:00Z")!

            TestHarness.test("Round-trip: valid signature verifies") {
                let file = try signedTestLicense(
                    licenseID: "lic_test_1",
                    email: "test@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                let result = file.verify(againstPublicKeyBase64: publicKeyB64)
                try expect(result.isValid,
                           "Freshly signed licence didn't verify against its own public key: \(result)")
            }

            TestHarness.test("Tampered email is rejected") {
                let file = try signedTestLicense(
                    licenseID: "lic_test_2",
                    email: "alice@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                // Swap email AFTER signing — signature is now over the
                // wrong payload.
                let tampered = LicenseFile(
                    licenseID:   file.licenseID,
                    email:       "attacker@example.com",
                    product:     file.product,
                    edition:     file.edition,
                    versionCap:  file.versionCap,
                    purchasedAt: file.purchasedAt,
                    signature:   file.signature
                )
                let result = tampered.verify(againstPublicKeyBase64: publicKeyB64)
                try expect(!result.isValid,
                           "Tampered email should fail verification, but verify returned \(result)")
            }

            TestHarness.test("Tampered edition is rejected") {
                let file = try signedTestLicense(
                    licenseID: "lic_test_3",
                    email: "test@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                let upgraded = LicenseFile(
                    licenseID:   file.licenseID,
                    email:       file.email,
                    product:     file.product,
                    edition:     .proPlusAnnual,        // <-- upgraded without re-signing
                    versionCap:  file.versionCap,
                    purchasedAt: file.purchasedAt,
                    signature:   file.signature
                )
                let result = upgraded.verify(againstPublicKeyBase64: publicKeyB64)
                try expect(!result.isValid,
                           "Self-upgrading lifetime → pro+ should fail verification, got \(result)")
            }

            TestHarness.test("Wrong public key is rejected") {
                let file = try signedTestLicense(
                    licenseID: "lic_test_4",
                    email: "test@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                // Verify against a DIFFERENT key — attacker can't
                // mint a fresh keypair and present its own license.
                let attackerKey = Curve25519.Signing.PrivateKey()
                let attackerPubB64 = attackerKey.publicKey.rawRepresentation
                    .base64EncodedString()
                let result = file.verify(againstPublicKeyBase64: attackerPubB64)
                try expect(!result.isValid,
                           "Verification against attacker key should fail, got \(result)")
            }

            TestHarness.test("Garbage public key is rejected") {
                let file = try signedTestLicense(
                    licenseID: "lic_test_5",
                    email: "test@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                let result = file.verify(againstPublicKeyBase64: "not-base64!!!")
                try expect(!result.isValid,
                           "Non-base64 public key should fail validation, got \(result)")
            }

            TestHarness.test("Garbage signature is rejected") {
                let real = try signedTestLicense(
                    licenseID: "lic_test_6",
                    email: "test@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                let corrupt = LicenseFile(
                    licenseID:   real.licenseID,
                    email:       real.email,
                    product:     real.product,
                    edition:     real.edition,
                    versionCap:  real.versionCap,
                    purchasedAt: real.purchasedAt,
                    signature:   "not-base64-at-all!!!"
                )
                let result = corrupt.verify(againstPublicKeyBase64: publicKeyB64)
                try expect(!result.isValid,
                           "Non-base64 signature should fail validation, got \(result)")
            }

            TestHarness.test("Read from disk + verify (round-trip)") {
                let file = try signedTestLicense(
                    licenseID: "lic_test_disk",
                    email: "diskuser@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                // Encode the licence to JSON, write to tmp, read back.
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(file)
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("test-\(UUID().uuidString).splynekkey")
                try data.write(to: tmp)
                defer { try? FileManager.default.removeItem(at: tmp) }

                let loaded = try LicenseFile.read(from: tmp)
                let result = loaded.verify(againstPublicKeyBase64: publicKeyB64)
                try expect(result.isValid,
                           "Round-trip through disk broke verification: \(result)")
                try expect(loaded.email == "diskuser@example.com",
                           "Round-trip lost the email field, got \(loaded.email)")
            }

            // MARK: – LicenseManager integration

            TestHarness.test("LicenseManager.activate accepts a valid licence file") {
                let mgr = LicenseManager(publicKeyOverride: publicKeyB64)
                mgr.deactivate()                // start clean
                try expect(mgr.isPro == false,
                           "Pristine LicenseManager should start as free tier")

                let file = try signedTestLicense(
                    licenseID: "lic_test_mgr_ok",
                    email: "mgr-ok@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                let url = try writeTempLicense(file)
                defer { try? FileManager.default.removeItem(at: url) }

                let ok = mgr.activate(fileURL: url)
                try expect(ok, "activate() returned false: \(mgr.lastUnlockError ?? "(no error message)")")
                try expect(mgr.isPro,
                           "After activate(), isPro should be true")
                try expect(mgr.licensedEmail == "mgr-ok@example.com",
                           "licensedEmail mismatch, got \(mgr.licensedEmail ?? "nil")")

                mgr.deactivate()                // clean up the persisted file
                try expect(mgr.isPro == false,
                           "After deactivate(), isPro should be false")
            }

            TestHarness.test("LicenseManager.activate rejects a tampered file") {
                let mgr = LicenseManager(publicKeyOverride: publicKeyB64)
                mgr.deactivate()

                let real = try signedTestLicense(
                    licenseID: "lic_test_mgr_bad",
                    email: "real@example.com",
                    purchasedAt: purchaseDate,
                    signedWith: privateKey
                )
                let tampered = LicenseFile(
                    licenseID:   real.licenseID,
                    email:       "attacker@example.com",       // swap
                    product:     real.product,
                    edition:     real.edition,
                    versionCap:  real.versionCap,
                    purchasedAt: real.purchasedAt,
                    signature:   real.signature
                )
                let url = try writeTempLicense(tampered)
                defer { try? FileManager.default.removeItem(at: url) }

                let ok = mgr.activate(fileURL: url)
                try expect(!ok,
                           "activate() should fail on tampered email but returned true")
                try expect(mgr.isPro == false,
                           "After failed activate(), isPro must stay false")
                try expect(mgr.lastUnlockError != nil,
                           "Failed activate() should populate lastUnlockError")
            }
        }
    }

    // MARK: – helpers

    /// Build a signed LicenseFile using a private test key.  Computes
    /// the canonical payload, signs it, splices the base64 signature
    /// back into the envelope.  Same flow the Cloudflare Worker will
    /// run in production.
    private static func signedTestLicense(
        licenseID: String,
        email: String,
        purchasedAt: Date,
        signedWith privateKey: Curve25519.Signing.PrivateKey
    ) throws -> LicenseFile {
        let unsigned = LicenseFile(
            licenseID:   licenseID,
            email:       email,
            product:     "splynek-pro",
            edition:     .lifetime,
            versionCap:  nil,
            purchasedAt: purchasedAt,
            signature:   "PENDING"
        )
        let payload = try unsigned.canonicalPayload()
        let sig = try privateKey.signature(for: payload)
        return LicenseFile(
            licenseID:   unsigned.licenseID,
            email:       unsigned.email,
            product:     unsigned.product,
            edition:     unsigned.edition,
            versionCap:  unsigned.versionCap,
            purchasedAt: unsigned.purchasedAt,
            signature:   sig.base64EncodedString()
        )
    }

    /// Write a LicenseFile to a temp .splynekkey path.  Caller is
    /// responsible for removing it.
    private static func writeTempLicense(_ file: LicenseFile) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).splynekkey")
        try data.write(to: url)
        return url
    }
}
