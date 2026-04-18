import Foundation
@testable import SplynekCore

/// v0.39 added per-field Gatekeeper detail parsing. The parser
/// consumes the stderr/stdout streams of three real Apple tools —
/// `spctl`, `codesign`, `stapler` — which have no formal schema and
/// drift across OS versions. Pin the field-extraction against
/// realistic canned outputs so the Signature card doesn't silently
/// start showing "—" when the tool wording shifts.
///
/// Each canned string below is taken from a real macOS 14 / 15 run
/// against a notarized + stapled Developer-ID-signed `.app`.
enum GatekeeperDetailTests {

    private static let spctlAccepted = """
    /Applications/Example.app: accepted
    source=Notarized Developer ID
    origin=Developer ID Application: Acme Corp. (ABCD1234)
    """

    private static let spctlRejected = """
    /Applications/Example.app: rejected
    source=no usable signature
    """

    private static let codesignRich = """
    Executable=/Applications/Example.app/Contents/MacOS/Example
    Identifier=com.acme.example
    Format=bundle with Mach-O thin (arm64)
    CodeDirectory v=20500 size=9999 flags=0x10000(runtime) hashes=300+6 location=embedded
    Hash type=sha256 size=32
    CandidateCDHash sha256=abcdef0123456789abcdef0123456789abcdef01
    CDHash=abcdef0123456789abcdef0123456789abcdef01
    Signature size=9027
    Authority=Developer ID Application: Acme Corp. (ABCD1234)
    Authority=Developer ID Certification Authority
    Authority=Apple Root CA
    Timestamp=Apr 10, 2026 at 3:14:15 PM
    Info.plist entries=30
    TeamIdentifier=ABCD1234
    Runtime Version=14.0.0
    Sealed Resources version=2 rules=13 files=42
    """

    private static let codesignUnsigned = """
    Executable=/tmp/whatever
    Format=Mach-O thin (arm64)
    CDHash=
    TeamIdentifier=not set
    """

    private static let staplerValid = """
    Processing: /Applications/Example.app
    The validate action worked!
    """

    private static let staplerMissing = """
    Processing: /Applications/Example.app
    Example.app does not have a ticket stapled to it.
    """

    static func run() {
        TestHarness.suite("Gatekeeper detail parser") {

            TestHarness.test("Accepted + notarized + stapled — all fields extracted") {
                let d = GatekeeperVerify.parseDetail(
                    spctlOutput: spctlAccepted, spctlAccepted: true,
                    codesignOutput: codesignRich,
                    staplerOutput: staplerValid, staplerExit: 0
                )
                try expect(d.accepted)
                try expectEqual(d.source, "Notarized Developer ID")
                try expectEqual(d.origin, "Developer ID Application: Acme Corp. (ABCD1234)")
                try expectEqual(d.teamID, "ABCD1234")
                try expectEqual(d.authorities.count, 3)
                try expectEqual(d.authorities.first, "Developer ID Application: Acme Corp. (ABCD1234)")
                try expectEqual(d.authorities.last, "Apple Root CA")
                try expectEqual(d.cdHashSHA256, "abcdef0123456789abcdef0123456789abcdef01")
                try expectEqual(d.notarizationStapled, true)
            }

            TestHarness.test("Rejected + unsigned — falls through cleanly") {
                let d = GatekeeperVerify.parseDetail(
                    spctlOutput: spctlRejected, spctlAccepted: false,
                    codesignOutput: codesignUnsigned,
                    staplerOutput: staplerMissing, staplerExit: 1
                )
                try expect(!d.accepted)
                try expectEqual(d.source, "no usable signature")
                try expect(d.origin == nil, "no origin line in rejected spctl output")
                try expectEqual(d.authorities.count, 0)
                try expect(d.teamID == nil,
                           "teamID `not set` should normalize to nil, got: \(d.teamID ?? "nil")")
                try expectEqual(d.notarizationStapled, false)
            }

            TestHarness.test("Authorities are captured in cert-chain order (outermost first)") {
                let d = GatekeeperVerify.parseDetail(
                    spctlOutput: spctlAccepted, spctlAccepted: true,
                    codesignOutput: codesignRich,
                    staplerOutput: staplerValid, staplerExit: 0
                )
                try expectEqual(d.authorities, [
                    "Developer ID Application: Acme Corp. (ABCD1234)",
                    "Developer ID Certification Authority",
                    "Apple Root CA"
                ])
            }

            TestHarness.test("Stapler exit non-zero + no ticket message → notarizationStapled = false") {
                let d = GatekeeperVerify.parseDetail(
                    spctlOutput: spctlAccepted, spctlAccepted: true,
                    codesignOutput: codesignRich,
                    staplerOutput: staplerMissing, staplerExit: 2
                )
                try expectEqual(d.notarizationStapled, false)
            }

            TestHarness.test("Stapler inconclusive (offline, ambiguous) → nil") {
                // Neither the "worked" nor any known failure sentinel.
                let d = GatekeeperVerify.parseDetail(
                    spctlOutput: spctlAccepted, spctlAccepted: true,
                    codesignOutput: codesignRich,
                    staplerOutput: "xcrun: error: unable to find utility \"stapler\"",
                    staplerExit: 64
                )
                try expect(d.notarizationStapled == nil,
                           "expected nil, got \(String(describing: d.notarizationStapled))")
            }

            TestHarness.test("raw blob concatenates all three tool outputs with labels") {
                // The Signature card's "Show raw" toggle dumps this
                // verbatim. Keep the separators stable so support
                // screenshots are consistent between releases.
                let d = GatekeeperVerify.parseDetail(
                    spctlOutput: "A", spctlAccepted: true,
                    codesignOutput: "B",
                    staplerOutput: "C", staplerExit: 0
                )
                try expect(d.raw.contains("---- spctl ----"))
                try expect(d.raw.contains("---- codesign ----"))
                try expect(d.raw.contains("---- stapler ----"))
                try expect(d.raw.contains("A"))
                try expect(d.raw.contains("B"))
                try expect(d.raw.contains("C"))
            }

            TestHarness.test("headline renders Accepted vs Rejected + source + stapled state") {
                let accepted = GatekeeperVerify.parseDetail(
                    spctlOutput: spctlAccepted, spctlAccepted: true,
                    codesignOutput: codesignRich,
                    staplerOutput: staplerValid, staplerExit: 0
                )
                try expect(accepted.headline.contains("Accepted"))
                try expect(accepted.headline.contains("Notarized Developer ID"))
                try expect(accepted.headline.contains("stapled"))

                let rejected = GatekeeperVerify.parseDetail(
                    spctlOutput: spctlRejected, spctlAccepted: false,
                    codesignOutput: codesignUnsigned,
                    staplerOutput: staplerMissing, staplerExit: 1
                )
                try expect(rejected.headline.contains("Rejected"))
                try expect(rejected.headline.contains("not stapled"))
            }
        }
    }
}
