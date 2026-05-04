import Foundation
@testable import SplynekCore

/// v1.9.x: PublisherPattern invariants.  We don't hit publisher CDNs
/// from tests (network flakiness, slow, version drift) — the cases
/// here cover:
///   - URL-matching: each pattern claims the right hosts + rejects
///     the wrong ones
///   - SHA256SUMS parser: handles the real-publisher line shapes
///     (Mozilla / Debian / Ubuntu) verbatim from copy-paste fixtures
///   - Registry walk: extractDigest returns the first publisher
///     whose pattern matches
///
/// The actual network round-trips (`extract` closures) are the
/// thinnest layer; if they break in the wild it's a network /
/// publisher-URL-shape change, surfaced via runtime logs.
enum PublisherPatternTests {

    static func run() {
        TestHarness.suite("PublisherPattern — host matching") {

            TestHarness.test("Mozilla pattern claims mozilla.org / mozilla.com / mozilla.net") {
                let yes = [
                    "https://download-installer.cdn.mozilla.net/pub/firefox/releases/127.0/mac/en-US/Firefox%20127.0.dmg",
                    "https://archive.mozilla.org/pub/thunderbird/releases/115.0/mac/en-US/Thunderbird.dmg",
                    "https://www.mozilla.org/firefox/download/",
                ].compactMap { URL(string: $0) }
                let no = [
                    "https://example.com/x",
                    "https://github.com/mozilla/firefox/releases/download/x.dmg",
                ].compactMap { URL(string: $0) }
                for u in yes { try expect(PublisherPattern.mozillaReleases.matches(u),
                                          "Should match: \(u.absoluteString)") }
                for u in no  { try expect(!PublisherPattern.mozillaReleases.matches(u),
                                          "Should NOT match: \(u.absoluteString)") }
            }

            TestHarness.test("Apache pattern claims apache.org") {
                let url = URL(string: "https://downloads.apache.org/httpd/httpd-2.4.59.tar.gz")!
                try expect(PublisherPattern.apacheReleases.matches(url))
                let no = URL(string: "https://example.com/apache.tar.gz")!
                try expect(!PublisherPattern.apacheReleases.matches(no))
            }

            TestHarness.test("Debian pattern claims debian.org") {
                let url = URL(string: "https://cdimage.debian.org/debian-cd/12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso")!
                try expect(PublisherPattern.debianReleases.matches(url))
                let no = URL(string: "https://www.linuxmint.com/edition.php?id=300")!
                try expect(!PublisherPattern.debianReleases.matches(no))
            }

            TestHarness.test("Ubuntu pattern claims ubuntu.com") {
                let url = URL(string: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso")!
                try expect(PublisherPattern.ubuntuReleases.matches(url))
            }

            TestHarness.test("Arch pattern claims archlinux.org") {
                let url = URL(string: "https://archlinux.org/iso/2024.04.01/archlinux-2024.04.01-x86_64.iso")!
                try expect(PublisherPattern.archReleases.matches(url))
            }

            TestHarness.test("GitHub Releases pattern claims github.com/.../releases/download/...") {
                let yes = [
                    "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-apple-darwin.tar.gz",
                    "https://github.com/sharkdp/fd/releases/download/v10.0.0/fd-v10.0.0-x86_64-apple-darwin.tar.gz",
                    "https://github.com/helix-editor/helix/releases/download/24.03/helix-24.03-aarch64-macos.tar.xz",
                ].compactMap { URL(string: $0) }
                let no = [
                    // Same host, wrong path shape (PR / issue / blob URLs).
                    "https://github.com/BurntSushi/ripgrep/pulls",
                    "https://github.com/BurntSushi/ripgrep/blob/master/README.md",
                    "https://github.com/BurntSushi/ripgrep/archive/refs/tags/14.1.0.tar.gz",
                    // Post-redirect host should NOT match — its parent
                    // directory doesn't expose the manifest.
                    "https://objects.githubusercontent.com/github-production-release-asset/123/abc",
                    // Other hosts.
                    "https://gitlab.com/owner/repo/releases/download/v1/file.tar.gz",
                ].compactMap { URL(string: $0) }
                for u in yes { try expect(PublisherPattern.githubReleases.matches(u),
                                          "Should match: \(u.absoluteString)") }
                for u in no  { try expect(!PublisherPattern.githubReleases.matches(u),
                                          "Should NOT match: \(u.absoluteString)") }
            }
        }

        TestHarness.suite("PublisherPattern — SHA256SUMS parser") {

            TestHarness.test("Mozilla SHA256SUMS shape parses cleanly") {
                let body = """
                    9d8be4d4cb86d4d2d4f1ec2cb44a8aaef79e2828bf90c45e9b81f33dabc8d70d  Firefox 127.0.dmg
                    a1b2c3d4e5f6071829304050607080900a0b0c0d0e0f10111213141516171819  Firefox 127.0.tar.bz2
                    """
                let digest = PublisherPattern.parseSHA256SUMS(body, filename: "Firefox 127.0.dmg")
                try expect(digest == "9d8be4d4cb86d4d2d4f1ec2cb44a8aaef79e2828bf90c45e9b81f33dabc8d70d",
                           "Got: \(digest ?? "nil")")
            }

            TestHarness.test("Asterisk binary-mode prefix is stripped") {
                // Some tools emit `<digest>  *<filename>` for binary mode.
                let body = "fa01debc1245fa01debc1245fa01debc1245fa01debc1245fa01debc1245fa01  *binary.iso"
                let digest = PublisherPattern.parseSHA256SUMS(body, filename: "binary.iso")
                try expect(digest != nil, "Should match despite * prefix")
            }

            TestHarness.test("./ path prefix is stripped") {
                let body = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  ./relative.iso"
                let digest = PublisherPattern.parseSHA256SUMS(body, filename: "relative.iso")
                try expect(digest != nil, "Should match despite ./ prefix")
            }

            TestHarness.test("Filename mismatch returns nil") {
                let body = """
                    fa01debc1245fa01debc1245fa01debc1245fa01debc1245fa01debc1245fa01  one.iso
                    fa02debc1245fa02debc1245fa02debc1245fa02debc1245fa02debc1245fa02  two.iso
                    """
                let digest = PublisherPattern.parseSHA256SUMS(body, filename: "three.iso")
                try expect(digest == nil)
            }

            TestHarness.test("Garbage input returns nil") {
                let body = "this is not a SHA256SUMS file at all"
                let digest = PublisherPattern.parseSHA256SUMS(body, filename: "anything")
                try expect(digest == nil)
            }

            TestHarness.test("Non-hex digest is rejected") {
                let body = "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG  fake.iso"
                let digest = PublisherPattern.parseSHA256SUMS(body, filename: "fake.iso")
                try expect(digest == nil, "Non-hex must be rejected")
            }

            TestHarness.test("Wrong-length digest is rejected") {
                let body = "abc123  short.iso"
                let digest = PublisherPattern.parseSHA256SUMS(body, filename: "short.iso")
                try expect(digest == nil, "<64 hex chars must be rejected")
            }

            TestHarness.test("isHex64 contract") {
                try expect(PublisherPattern.isHex64(String(repeating: "a", count: 64)))
                try expect(PublisherPattern.isHex64("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"))
                try expect(!PublisherPattern.isHex64(String(repeating: "z", count: 64)))
                try expect(!PublisherPattern.isHex64(String(repeating: "a", count: 63)))
                try expect(!PublisherPattern.isHex64(""))
            }
        }

        TestHarness.suite("PublisherPattern — registry walk") {

            TestHarness.test("allPatterns has all six publishers") {
                let names = Set(PublisherPattern.allPatterns.map(\.name))
                try expect(names.contains("Mozilla"))
                try expect(names.contains("Apache"))
                try expect(names.contains("Debian"))
                try expect(names.contains("Ubuntu"))
                try expect(names.contains("Arch"))
                try expect(names.contains("GitHub Releases"))
                try expect(PublisherPattern.allPatterns.count == 6,
                           "Got \(PublisherPattern.allPatterns.count) patterns; if a new publisher landed, update this assertion.")
            }

            TestHarness.test("GitHub Releases parses lowercase sha256sums.txt") {
                // ripgrep-style manifest line shape.
                let body = """
                    fa01debc1245fa01debc1245fa01debc1245fa01debc1245fa01debc1245fa01  ripgrep-14.1.0-x86_64-apple-darwin.tar.gz
                    fa02debc1245fa02debc1245fa02debc1245fa02debc1245fa02debc1245fa02  ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz
                    """
                let digest = PublisherPattern.parseSHA256SUMS(
                    body, filename: "ripgrep-14.1.0-x86_64-apple-darwin.tar.gz"
                )
                try expectEqual(digest, "fa01debc1245fa01debc1245fa01debc1245fa01debc1245fa01debc1245fa01")
            }

            TestHarness.test("Non-matching URL returns nil from extractDigest") {
                let url = URL(string: "https://example.com/random/file.dmg")!
                let result = await PublisherPattern.extractDigest(for: url)
                try expect(result == nil)
            }
        }
    }
}
