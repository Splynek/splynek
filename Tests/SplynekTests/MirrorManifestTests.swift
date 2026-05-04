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

            TestHarness.test("allSets has the curated initial sets") {
                let publishers = Set(MirrorManifest.allSets.map(\.publisher))
                try expect(publishers.contains("Ubuntu"))
                try expect(publishers.contains("Debian"))
                try expect(publishers.contains("Fedora"))
                try expectEqual(MirrorManifest.allSets.count, 3,
                    "Got \(MirrorManifest.allSets.count) mirror sets; if a new publisher landed, update this assertion.")
            }
        }

        TestHarness.suite("MirrorManifest — Debian") {

            TestHarness.test("Claims cdimage.debian.org") {
                let url = URL(string: "https://cdimage.debian.org/debian-cd/12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso")!
                try expect(MirrorManifest.debian.matches(url))
            }

            TestHarness.test("Rejects non-Debian hosts + non-cdimage subdomains") {
                let no = [
                    "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso",
                    // www.debian.org is the project site, not the ISO host —
                    // its path shape is unrelated to debian-cd/.
                    "https://www.debian.org/News/2024",
                    // ftp.debian.org serves repo packages, not ISOs.
                    "https://ftp.debian.org/debian/pool/main/d/debian-archive-keyring/",
                ].compactMap { URL(string: $0) }
                for u in no {
                    try expect(!MirrorManifest.debian.matches(u),
                        "Should NOT match: \(u.absoluteString)")
                }
            }

            TestHarness.test("Produces 5 ranked alternatives (4 Tier-1 + Wayback)") {
                let primary = URL(string: "https://cdimage.debian.org/debian-cd/12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso")!
                let alts = MirrorManifest.debian.alternatives(primary)
                try expectEqual(alts.count, 5)

                let expectedHosts = [
                    "mirror.kernel.org",
                    "gemmei.acc.umu.se",
                    "ftp.heanet.ie",
                    "mirror.us.leaseweb.net",
                ]
                for (i, host) in expectedHosts.enumerated() {
                    try expectEqual(alts[i].host, host,
                        "Tier-1 #\(i + 1) host should be \(host)")
                }
                try expect(alts[4].absoluteString.hasPrefix("https://web.archive.org/web/"),
                    "Wayback fallback should be last")
            }

            TestHarness.test("Path tail (everything after /debian-cd/) is preserved") {
                let primary = URL(string: "https://cdimage.debian.org/debian-cd/12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso")!
                let alts = MirrorManifest.debian.alternatives(primary)
                let suffix = "12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso"
                for alt in alts.prefix(4) {
                    try expect(alt.absoluteString.hasSuffix(suffix),
                        "Tier-1 mirror URL should end with the version+arch+filename: got \(alt.absoluteString)")
                }
            }

            TestHarness.test("URL without /debian-cd/ prefix produces no alternatives") {
                // Defensive: cdimage.debian.org also serves /jigdo/ and
                // /weekly-builds/ paths.  Our matcher claims any
                // cdimage.debian.org URL but extract should bail
                // gracefully if the path shape isn't /debian-cd/<...>.
                let primary = URL(string: "https://cdimage.debian.org/jigdo/12.5.0/amd64/")!
                let alts = MirrorManifest.debian.alternatives(primary)
                try expect(alts.isEmpty,
                    "Non-debian-cd path can't be transformed to mirror URLs — return [] not malformed alts")
            }
        }

        TestHarness.suite("MirrorManifest — parallel vs last-resort split") {

            // Engine integration (DownloadJob.start) injects only
            // parallelAlternatives as round-robin lanes — Wayback
            // archive entries route 20% of bytes through a cold
            // archive otherwise, which would slow legitimate downloads.

            TestHarness.test("parallelAlternatives excludes web.archive.org") {
                let primary = URL(string: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso")!
                let alts = MirrorManifest.parallelAlternatives(for: primary)
                try expect(!alts.isEmpty, "Should have curated Tier-1 mirrors")
                for url in alts {
                    try expect(url.host?.lowercased() != "web.archive.org",
                        "Wayback entry leaked into parallel lanes: \(url.absoluteString)")
                }
            }

            TestHarness.test("parallelAlternatives count is alternatives count minus Wayback") {
                let primary = URL(string: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso")!
                let all = MirrorManifest.alternatives(for: primary)
                let parallel = MirrorManifest.parallelAlternatives(for: primary)
                let lastResort = MirrorManifest.lastResortAlternatives(for: primary)
                try expectEqual(all.count, parallel.count + lastResort.count,
                    "parallel + last-resort = full alternatives set (no overlap, no drops)")
            }

            TestHarness.test("lastResortAlternatives is just web.archive.org URLs") {
                let primary = URL(string: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso")!
                let lastResort = MirrorManifest.lastResortAlternatives(for: primary)
                try expectEqual(lastResort.count, 1)
                try expectEqual(lastResort.first?.host, "web.archive.org")
            }

            TestHarness.test("Both helpers return [] for non-claimed URLs") {
                let primary = URL(string: "https://example.com/x")!
                try expect(MirrorManifest.parallelAlternatives(for: primary).isEmpty)
                try expect(MirrorManifest.lastResortAlternatives(for: primary).isEmpty)
            }
        }

        TestHarness.suite("MirrorManifest — Fedora") {

            // Fedora's annual rotation makes the path-shape verifier
            // load-bearing: we claim release URLs but reject
            // development / updates / archive paths so the curated
            // mirror set isn't applied where it doesn't apply.

            TestHarness.test("Claims download.fedoraproject.org release URLs") {
                let yes = [
                    "https://download.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.5.iso",
                    "https://dl.fedoraproject.org/pub/fedora/linux/releases/40/Server/aarch64/iso/Fedora-Server-dvd-aarch64-40-1.14.iso",
                    "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Spins/x86_64/iso/Fedora-KDE-Live-x86_64-42-1.iso",
                ].compactMap { URL(string: $0) }
                for u in yes {
                    try expect(MirrorManifest.fedora.matches(u),
                        "Should match: \(u.absoluteString)")
                }
            }

            TestHarness.test("Rejects non-release Fedora paths") {
                let no = [
                    // Development branch — different mirror infrastructure
                    "https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Workstation/x86_64/iso/Fedora-Workstation-Rawhide-x86_64-Live.iso",
                    // Updates — completely different topology
                    "https://dl.fedoraproject.org/pub/fedora/linux/updates/41/Everything/x86_64/Packages/k/kernel-6.13.iso",
                    // /releases/development/ — non-numeric "version"
                    "https://dl.fedoraproject.org/pub/fedora/linux/releases/development/41/Workstation/x86_64/iso/foo.iso",
                ].compactMap { URL(string: $0) }
                for u in no {
                    try expect(!MirrorManifest.fedora.matches(u),
                        "Should NOT match: \(u.absoluteString)")
                }
            }

            TestHarness.test("Rejects non-Fedora hosts") {
                let no = [
                    "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso",
                    "https://example.com/fedora-fake.iso",
                ].compactMap { URL(string: $0) }
                for u in no {
                    try expect(!MirrorManifest.fedora.matches(u),
                        "Should NOT match: \(u.absoluteString)")
                }
            }

            TestHarness.test("parseFedoraReleasePath extracts version + tail") {
                let url = URL(string: "https://download.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.5.iso")!
                let parsed = MirrorManifest.parseFedoraReleasePath(url)
                try expectEqual(parsed?.version, "41")
                try expectEqual(parsed?.tail,
                    "Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.5.iso")
            }

            TestHarness.test("parseFedoraReleasePath handles dl. host's /pub/ prefix") {
                let url = URL(string: "https://dl.fedoraproject.org/pub/fedora/linux/releases/40/Server/aarch64/iso/Fedora-Server-dvd-aarch64-40-1.14.iso")!
                let parsed = MirrorManifest.parseFedoraReleasePath(url)
                try expectEqual(parsed?.version, "40")
                try expect(parsed?.tail.contains("Server/aarch64") ?? false)
            }

            TestHarness.test("Alternatives swap host but preserve version + tail") {
                let primary = URL(string: "https://download.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.5.iso")!
                let alts = MirrorManifest.fedora.alternatives(primary)
                // Expected: dl + 2 kernel.org + Wayback = 4
                // (dl. isn't filtered out because primary is download.).
                try expectEqual(alts.count, 4,
                    "Expected dl + 2 kernel.org + Wayback = 4")
                let suffix = "releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.5.iso"
                for alt in alts.prefix(3) {
                    try expect(alt.absoluteString.contains(suffix),
                        "Tier-1 mirror URL should preserve version + tail: got \(alt.absoluteString)")
                }
                try expect(alts[3].absoluteString.hasPrefix("https://web.archive.org/"),
                    "Wayback last")
            }

            TestHarness.test("Primary URL is filtered out of its own alternatives") {
                // When user pastes a dl.fedoraproject.org URL, dl.
                // shouldn't appear in its own alternatives — that'd
                // duplicate the primary lane.
                let primary = URL(string: "https://dl.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.5.iso")!
                let alts = MirrorManifest.fedora.alternatives(primary)
                for alt in alts {
                    try expect(alt.absoluteString != primary.absoluteString,
                        "Primary leaked into alternatives: \(alt.absoluteString)")
                }
                try expect(alts.count >= 3,
                    "Expected kernel.org pair + Wayback even after dl. filter")
            }

            TestHarness.test("Annual rotation: future versions parse cleanly") {
                // Fedora 50 doesn't exist yet, but the parser should
                // handle whatever digits land in the URL — that's
                // what "annual rotation tolerance" means in practice.
                let future = URL(string: "https://download.fedoraproject.org/pub/fedora/linux/releases/50/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-50-1.0.iso")!
                let parsed = MirrorManifest.parseFedoraReleasePath(future)
                try expectEqual(parsed?.version, "50")
                let alts = MirrorManifest.fedora.alternatives(future)
                try expect(!alts.isEmpty)
                try expect(alts[0].absoluteString.contains("releases/50/"))
            }
        }
    }
}
