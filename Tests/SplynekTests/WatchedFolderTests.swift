import Foundation
@testable import SplynekCore

/// `WatchedFolderParser.parseURLs` is the only side-effect-free piece
/// of the watched-folder pipeline. The scan loop is a filesystem
/// concern exercised by the app in practice; parsing is the layer
/// where invariants ("# comments skipped, magnets preserved, random
/// lines dropped") belong and where a regression is easiest to catch.
enum WatchedFolderTests {

    static func run() {
        TestHarness.suite("Watched folder — .txt parser") {

            TestHarness.test("single http URL is returned verbatim") {
                let urls = WatchedFolderParser.parseURLs(
                    fromText: "https://example.com/file.bin"
                )
                try expectEqual(urls, ["https://example.com/file.bin"])
            }

            TestHarness.test("multiple lines become multiple URLs in order") {
                let text = """
                https://a.example/x
                https://b.example/y
                https://c.example/z
                """
                let urls = WatchedFolderParser.parseURLs(fromText: text)
                try expectEqual(urls.count, 3)
                try expectEqual(urls[0], "https://a.example/x")
                try expectEqual(urls[1], "https://b.example/y")
                try expectEqual(urls[2], "https://c.example/z")
            }

            TestHarness.test("blank lines and leading/trailing whitespace are ignored") {
                let text = """

                    https://a.example/x

                https://b.example/y
                """
                let urls = WatchedFolderParser.parseURLs(fromText: text)
                try expectEqual(urls, [
                    "https://a.example/x",
                    "https://b.example/y"
                ])
            }

            TestHarness.test("# comment lines are skipped") {
                let text = """
                # daily mirror list
                https://a.example/x
                # a note
                https://b.example/y
                """
                let urls = WatchedFolderParser.parseURLs(fromText: text)
                try expectEqual(urls, [
                    "https://a.example/x",
                    "https://b.example/y"
                ])
            }

            TestHarness.test("magnet lines pass through without http rewriting") {
                let text = """
                magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567
                https://a.example/x
                """
                let urls = WatchedFolderParser.parseURLs(fromText: text)
                try expectEqual(urls.count, 2)
                try expect(urls[0].hasPrefix("magnet:"))
                try expectEqual(urls[1], "https://a.example/x")
            }

            TestHarness.test("unsupported schemes are dropped") {
                let text = """
                ftp://a.example/x
                file:///tmp/y
                ssh://user@host
                https://ok.example/ok
                """
                let urls = WatchedFolderParser.parseURLs(fromText: text)
                try expectEqual(urls, ["https://ok.example/ok"])
            }

            TestHarness.test("plain text garbage lines are dropped") {
                let text = """
                hello world
                /just/a/path
                https://ok.example/ok
                """
                let urls = WatchedFolderParser.parseURLs(fromText: text)
                try expectEqual(urls, ["https://ok.example/ok"])
            }

            TestHarness.test("handledExtensions covers the four accepted types and nothing else") {
                // Regression guard: if someone extends the watcher, the
                // handler dispatch in ViewModel.handleWatchedFile needs
                // to learn about the new extension at the same time.
                try expectEqual(
                    WatchedFolder.handledExtensions,
                    Set(["txt", "torrent", "metalink", "meta4"])
                )
            }
        }
    }
}
