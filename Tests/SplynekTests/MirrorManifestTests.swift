import Foundation
@testable import SplynekCore

/// Bet S2 — Unbreakable Resume (component 3): unit tests for the
/// curated mirror manifest's lookup walk + URL-transform shape.  No
/// network round-trips — the mirror URLs aren't dialed; the tests
/// only verify the transform produces well-formed candidates the
/// engine can then race.
enum MirrorManifestTests {

    static func run() {
        TestHarness.suite("MirrorManifest — Ubuntu") {

            TestHarness.test("Claims releases.ubuntu.com") {
                let url = URL(string: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso")!
                try expect(MirrorManifest.ubuntu.matches(url))
            }

            TestHarness.test("Rejects non-Ubuntu hosts") {
                let no = [
                    "https://cdimage.debian.org/debian-cd/12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso",
                    "https://example.com/ubuntu-fake.iso",
                    "https://archlinux.org/iso/2024.04.01/archlinux-2024.04.01-x86_64.iso",
                    // Subdomain that ISN'T releases.ubuntu.com.  We
                    // intentionally don't claim ubuntu.com generally
                    // — only the canonical `releases.ubuntu.com` host
                    // — because the path shape isn't predictable on
                    // other Ubuntu subdomains (cdimage, ports, etc.).
                    "https://cdimage.ubuntu.com/daily/current/foo.iso",
                ].compactMap { URL(string: $0) }
                for u in no {
                    try expect(!MirrorManifest.ubuntu.matches(u),
                               "Should NOT match: \(u.absoluteString)")
                }
            }

            TestHarness.test("Produces 5 ranked alternatives (4 Tier-1 + Wayback)") {
                let primary = URL(string: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso")!
                let alts = MirrorManifest.ubuntu.alternatives(primary)
                try expectEqual(alts.count, 5,
                    "4 curated Tier-1 mirrors + 1 archive.org Wayback long-shot")

                // First four are the curated Tier-1 set, in the
                // order declared in MirrorManifest.swift.  Stable
                // ordering matters because the engine races them
                // sequentially under failure.
                let expectedHosts = [
                    "mirror.kernel.org",
                    "fr.releases.ubuntu.com",
                    "mirror.us.leaseweb.net",
                    "mirrors.cat.net",
                ]
                for (i, host) in expectedHosts.enumerated() {
                    try expectEqual(alts[i].host, host,
                        "Tier-1 #\(i + 1) host should be \(host)")
                }
                // Last is the Wayback long-shot.
                try expect(alts[4].absoluteString.hasPrefix("https://web.archive.org/web/"),
                    "Wayback fallback should be last")
            }

            TestHarness.test("Path is preserved verbatim across hosts") {
                let primary = URL(string: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso")!
                let alts = MirrorManifest.ubuntu.alternatives(primary)
                // The four Tier-1 alts each have their own path
                // prefix (`/ubuntu-releases/` for kernel.org +
                // leaseweb + cat.net; `/` for fr.releases.ubuntu.com)
                // — but every one ends with the same `<ver>/<file>`.
                let suffix = "24.04/ubuntu-24.04-desktop-amd64.iso"
                for alt in alts.prefix(4) {
                    try expect(alt.absoluteString.hasSuffix(suffix),
                        "Tier-1 mirror URL should end with the version+filename: got \(alt.absoluteString)")
                }
            }

            TestHarness.test("Empty-path URL produces no alternatives") {
                let primary = URL(string: "https://releases.ubuntu.com")!
                let alts = MirrorManifest.ubuntu.alternatives(primary)
                try expect(alts.isEmpty,
                    "URL without a path can't be transformed — return [] not malformed mirror URLs")
            }
        }

        TestHarness.suite("MirrorManifest — registry walk") {

            TestHarness.test("alternatives(for:) returns Ubuntu mirrors for an Ubuntu URL") {
                let primary = URL(string: "https://releases.ubuntu.com/22.04.4/ubuntu-22.04.4-live-server-amd64.iso")!
                let alts = MirrorManifest.alternatives(for: primary)
                try expectEqual(alts.count, 5)
            }

            TestHarness.test("alternatives(for:) returns [] for non-claimed URLs") {
                let primary = URL(string: "https://example.com/random/file.tar.gz")!
                let alts = MirrorManifest.alternatives(for: primary)
                try expect(alts.isEmpty,
                    "No mirror set claims example.com — engine should surface failure rather than retry")
            }

            TestHarness.test("publisher(for:) returns 'Ubuntu' for releases.ubuntu.com URLs") {
                let primary = URL(string: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso")!
                try expectEqual(MirrorManifest.publisher(for: primary), "Ubuntu")
            }

            TestHarness.test("publisher(for:) returns nil for non-claimed URLs") {
                let primary = URL(string: "https://example.com/x")!
                try expect(MirrorManifest.publisher(for: primary) == nil)
            }

            TestHarness.test("allSets has the curated initial set (Ubuntu only this commit)") {
                let publishers = Set(MirrorManifest.allSets.map(\.publisher))
                try expect(publishers.contains("Ubuntu"))
                try expectEqual(MirrorManifest.allSets.count, 1,
                    "Got \(MirrorManifest.allSets.count) mirror sets; if a new publisher landed, update this assertion.")
            }
        }
    }
}
