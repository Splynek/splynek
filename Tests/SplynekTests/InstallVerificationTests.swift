import Foundation
@testable import SplynekCore

/// v1.8: hashing + verdict invariants for InstallVerification.
/// Gatekeeper integration is exercised by spawning real `spctl` /
/// `codesign` against fixture binaries — those tests are guarded
/// by environment so CI without notarisation can skip.
enum InstallVerificationTests {

    static func run() {
        TestHarness.suite("InstallVerification — SHA-256 hashing") {

            TestHarness.test("Empty file hashes to known SHA-256") {
                let url = makeTemp(contents: Data())
                defer { try? FileManager.default.removeItem(at: url) }
                let result = InstallVerification.sha256(of: url)
                if case .success(let hex) = result {
                    // Empty input SHA-256 = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
                    try expect(
                        hex == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                        "Got \(hex)"
                    )
                } else {
                    try expect(false, "Hashing should not fail on empty file")
                }
            }

            TestHarness.test("Single byte hashes to known SHA-256") {
                // SHA-256("a") = ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
                let url = makeTemp(contents: Data("a".utf8))
                defer { try? FileManager.default.removeItem(at: url) }
                let result = InstallVerification.sha256(of: url)
                if case .success(let hex) = result {
                    try expect(
                        hex == "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb",
                        "Got \(hex)"
                    )
                } else {
                    try expect(false, "Hashing failed")
                }
            }

            TestHarness.test("Streaming handles files larger than buffer") {
                // Buffer is 64 KB; write 200 KB so we exercise multiple reads.
                let bytes = Data(repeating: 0xCD, count: 200_000)
                let url = makeTemp(contents: bytes)
                defer { try? FileManager.default.removeItem(at: url) }
                let result = InstallVerification.sha256(of: url)
                if case .success(let hex) = result {
                    try expect(hex.count == 64, "SHA-256 hex must be 64 chars, got \(hex.count)")
                } else {
                    try expect(false, "Streaming hash failed")
                }
            }

            TestHarness.test("Missing file returns failure") {
                let nonexistent = URL(fileURLWithPath: "/tmp/definitely-not-real-\(UUID()).bin")
                let result = InstallVerification.sha256(of: nonexistent)
                if case .failure = result { /* expected */ }
                else { try expect(false, "Should have failed on missing file") }
            }
        }

        TestHarness.suite("InstallVerification — verdict logic") {

            TestHarness.test("Digest mismatch is detected") {
                // We can't easily run a Gatekeeper-failing fixture in
                // CI, but we CAN exercise the digest path with a
                // bogus expected digest.
                let bytes = Data("hello".utf8)
                let url = makeTemp(contents: bytes)
                defer { try? FileManager.default.removeItem(at: url) }
                // Real SHA-256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
                // We supply a wrong digest; the verifier should bounce.
                let verdict = await InstallVerification.verify(
                    payload: url,
                    expectedDigest: "0000000000000000000000000000000000000000000000000000000000000000"
                )
                if case .digestMismatch = verdict { /* expected */ }
                else { try expect(false, "Should have flagged digest mismatch, got \(verdict)") }
            }

            TestHarness.test("Digest case + spacing tolerance") {
                let bytes = Data("hello".utf8)
                let url = makeTemp(contents: bytes)
                defer { try? FileManager.default.removeItem(at: url) }
                // Use a SPACED + UPPER-CASE form of the right digest;
                // verifier should normalise both sides.  Without
                // Gatekeeper running on this fixture file we'll get
                // .gatekeeperRejected (notApplicable type).  But the
                // digest stage should NOT be the failure — that's
                // what we're checking.
                let realDigest = "2CF2 4DBA 5FB0 A30E 26E8 3B2A C5B9 E29E 1B16 1E5C 1FA7 425E 7304 3362 938B 9824"
                let verdict = await InstallVerification.verify(
                    payload: url,
                    expectedDigest: realDigest
                )
                // Whatever the Gatekeeper outcome is, the digest stage
                // must not have failed.
                if case .digestMismatch = verdict {
                    try expect(false, "Digest normalisation broken; spaced+upper should match")
                }
            }
        }
    }

    static func makeTemp(contents: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("splynek-install-verify-\(UUID()).bin")
        try? contents.write(to: url)
        return url
    }
}
