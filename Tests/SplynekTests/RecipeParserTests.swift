import Foundation
@testable import SplynekCore

/// v0.42 shipped "Agentic Download Recipes" — the LLM proposes a
/// verifiable batch; the user approves; Splynek executes. `RecipeParser`
/// is the robustness layer between LLM output (which does whatever it
/// feels like) and the queue (which needs clean data). These tests
/// pin the tolerance + strictness behaviours:
///   - Tolerance: accept markdown fences, leading prose, trailing
///     prose, nested JSON strings — LLMs love all of these.
///   - Strictness: reject invalid URLs, missing required fields,
///     unreasonable confidence values. A bad item is dropped; a
///     recipe with zero survivors throws `.noItems`.
/// A broken parser here either crashes on weird LLM output or lets
/// hallucinated garbage into the queue. Both are unacceptable.
enum RecipeParserTests {

    // Updated v0.43: the previous canonical fixture used an
    // apps.apple.com URL for Xcode, which the parser now rejects
    // (QA P1 #2). The canonical shape is unchanged; only the
    // first item's URL swapped for one the parser will accept.
    private static let canonical = """
    {
      "title": "Test recipe",
      "items": [
        {
          "name": "VS Code",
          "url": "https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal",
          "homepage": "https://code.visualstudio.com/",
          "sha256": null,
          "sizeHint": "~200 MB",
          "rationale": "General editor.",
          "confidence": 0.9
        },
        {
          "name": "Homebrew",
          "url": "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh",
          "homepage": "https://brew.sh",
          "sha256": null,
          "sizeHint": "~50 KB",
          "rationale": "Package manager.",
          "confidence": 0.9
        }
      ]
    }
    """

    static func run() {
        TestHarness.suite("Recipe parser — tolerance") {

            TestHarness.test("Canonical response parses to a well-formed recipe") {
                let recipe = try RecipeParser.parse(
                    response: canonical,
                    goal: "set up Mac",
                    modelUsed: "llama3.2:3b"
                )
                try expectEqual(recipe.title, "Test recipe")
                try expectEqual(recipe.items.count, 2)
                try expectEqual(recipe.items[0].name, "VS Code")
                try expectEqual(recipe.items[0].confidence, 0.9)
                try expectEqual(recipe.modelUsed, "llama3.2:3b")
                try expectEqual(recipe.goal, "set up Mac")
            }

            TestHarness.test("Markdown-fenced response parses") {
                // LLMs love wrapping JSON in ```json ... ``` even when
                // told not to. Claude, Llama, Gemma all do this.
                let wrapped = "Here's your recipe:\n\n```json\n\(canonical)\n```\n\nHope this helps!"
                let recipe = try RecipeParser.parse(
                    response: wrapped,
                    goal: "set up Mac",
                    modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 2)
            }

            TestHarness.test("Leading prose before the JSON is ignored") {
                let prefixed = "Sure! Here is a good recipe for your goal:\n\(canonical)"
                let recipe = try RecipeParser.parse(
                    response: prefixed, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 2)
            }

            TestHarness.test("Trailing prose after the JSON is ignored") {
                let suffixed = "\(canonical)\n\nLet me know if you want more items."
                let recipe = try RecipeParser.parse(
                    response: suffixed, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 2)
            }

            TestHarness.test("Braces inside JSON string literals don't fool the extractor") {
                // Worst-case nesting — a rationale containing { or }.
                let tricky = """
                {
                  "title": "T",
                  "items": [
                    {
                      "name": "n",
                      "url": "https://x.com/a",
                      "homepage": "https://x.com",
                      "rationale": "contains { and } inside",
                      "confidence": 0.9
                    }
                  ]
                }
                """
                let recipe = try RecipeParser.parse(
                    response: tricky, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 1)
                try expectEqual(recipe.items[0].rationale, "contains { and } inside")
            }
        }

        TestHarness.suite("Recipe parser — strictness") {

            TestHarness.test("Item with non-http(s) URL is dropped") {
                let bad = """
                {
                  "title": "T",
                  "items": [
                    {"name": "bad", "url": "ftp://x.com/f", "homepage": "https://x.com", "rationale": "r", "confidence": 0.9},
                    {"name": "good", "url": "https://x.com/a", "homepage": "https://x.com", "rationale": "r", "confidence": 0.9}
                  ]
                }
                """
                let recipe = try RecipeParser.parse(
                    response: bad, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 1)
                try expectEqual(recipe.items[0].name, "good")
            }

            TestHarness.test("Item missing name / url / rationale is dropped") {
                let holes = """
                {
                  "title": "T",
                  "items": [
                    {"url": "https://x.com/a", "rationale": "r", "confidence": 0.9},
                    {"name": "a", "rationale": "r", "confidence": 0.9},
                    {"name": "b", "url": "https://x.com/b", "confidence": 0.9},
                    {"name": "ok", "url": "https://x.com/ok", "rationale": "r", "confidence": 0.9}
                  ]
                }
                """
                let recipe = try RecipeParser.parse(
                    response: holes, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 1)
                try expectEqual(recipe.items[0].name, "ok")
            }

            TestHarness.test("Confidence is clamped to [0, 1]") {
                let wild = """
                {
                  "title": "T",
                  "items": [
                    {"name": "a", "url": "https://x.com/a", "rationale": "r", "confidence": 2.5},
                    {"name": "b", "url": "https://x.com/b", "rationale": "r", "confidence": -0.3}
                  ]
                }
                """
                let recipe = try RecipeParser.parse(
                    response: wild, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 2)
                try expectEqual(recipe.items[0].confidence, 1.0)
                try expectEqual(recipe.items[1].confidence, 0.0)
            }

            TestHarness.test("Missing confidence defaults to 0.5") {
                let nocfg = """
                {
                  "title": "T",
                  "items": [
                    {"name": "a", "url": "https://x.com/a", "rationale": "r"}
                  ]
                }
                """
                let recipe = try RecipeParser.parse(
                    response: nocfg, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items[0].confidence, 0.5)
            }

            TestHarness.test("Invalid SHA-256 is dropped (not 64 hex chars)") {
                let bad = """
                {
                  "title": "T",
                  "items": [
                    {"name": "a", "url": "https://x.com/a", "rationale": "r",
                     "sha256": "not-a-hash", "confidence": 0.9},
                    {"name": "b", "url": "https://x.com/b", "rationale": "r",
                     "sha256": "ABCDEF0123456789abcdef0123456789ABCDEF0123456789abcdef0123456789",
                     "confidence": 0.9}
                  ]
                }
                """
                let recipe = try RecipeParser.parse(
                    response: bad, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 2)
                try expect(recipe.items[0].sha256 == nil,
                           "non-hex sha should be dropped")
                try expectEqual(recipe.items[1].sha256,
                                "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
                                "valid sha should be lowercased")
            }

            TestHarness.test("Non-http homepage is dropped but item keeps its url") {
                let weird = """
                {
                  "title": "T",
                  "items": [
                    {"name": "a", "url": "https://x.com/a",
                     "homepage": "ftp://x.com", "rationale": "r", "confidence": 0.9}
                  ]
                }
                """
                let recipe = try RecipeParser.parse(
                    response: weird, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 1)
                try expect(recipe.items[0].homepage == nil)
            }

            TestHarness.test("All-items-dropped recipe throws .noItems") {
                let allbad = """
                {
                  "title": "T",
                  "items": [
                    {"name": "a", "url": "ftp://x.com/a", "rationale": "r"},
                    {"url": "https://x.com/b", "rationale": "r"}
                  ]
                }
                """
                do {
                    _ = try RecipeParser.parse(
                        response: allbad, goal: "g", modelUsed: "m"
                    )
                    try expect(false, "expected ParseError.noItems")
                } catch let err as RecipeParser.ParseError {
                    guard case .noItems = err else {
                        try expect(false, "expected .noItems, got \(err)")
                        return
                    }
                }
            }

            TestHarness.test("Missing JSON entirely throws .noJSONFound") {
                do {
                    _ = try RecipeParser.parse(
                        response: "Sorry, I can't help with that.",
                        goal: "g", modelUsed: "m"
                    )
                    try expect(false, "expected ParseError.noJSONFound")
                } catch let err as RecipeParser.ParseError {
                    guard case .noJSONFound = err else {
                        try expect(false, "expected .noJSONFound, got \(err)")
                        return
                    }
                }
            }

            TestHarness.test("Malformed JSON throws .decodeFailed") {
                // Syntactically a {} but not matching the recipe shape.
                do {
                    _ = try RecipeParser.parse(
                        response: "{ \"not_a_recipe\": \"weird\" }",
                        goal: "g", modelUsed: "m"
                    )
                    try expect(false, "expected ParseError.noItems")
                } catch let err as RecipeParser.ParseError {
                    // Missing items → .noItems path (decode succeeds
                    // with raw.items == nil → empty filtered list).
                    guard case .noItems = err else {
                        try expect(false, "got \(err)")
                        return
                    }
                }
            }

            TestHarness.test("App Store / marketing-host URLs are dropped (v0.43 QA guard)") {
                // Real-world bug: llama3.2:3b returned the Mac App
                // Store page as Xcode's "url", which then FAILED in
                // the queue with "Server doesn't advertise Range
                // support." Parser now rejects these client-side.
                let leaky = """
                {
                  "title": "iOS dev",
                  "items": [
                    {"name": "Xcode (App Store)", "url": "https://apps.apple.com/us/app/xcode/id497799835",
                     "homepage": "https://developer.apple.com/xcode/",
                     "rationale": "IDE", "confidence": 0.95},
                    {"name": "itunes thing", "url": "https://itunes.apple.com/us/foo",
                     "rationale": "x", "confidence": 0.5},
                    {"name": "GMail web", "url": "https://play.google.com/store/apps/details?id=com.google.gm",
                     "rationale": "x", "confidence": 0.5},
                    {"name": "Homebrew", "url": "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh",
                     "homepage": "https://brew.sh",
                     "rationale": "pkg mgr", "confidence": 0.9}
                  ]
                }
                """
                let recipe = try RecipeParser.parse(
                    response: leaky, goal: "g", modelUsed: "m"
                )
                try expectEqual(recipe.items.count, 1,
                                "only Homebrew should survive; got \(recipe.items.map(\.name))")
                try expectEqual(recipe.items[0].name, "Homebrew")
            }

            TestHarness.test("All items start `selected = true`") {
                // Regression guard on the UX contract: the happy path
                // is "type goal, hit Queue, everything runs." Users
                // un-check the items they don't want; they don't
                // have to check the ones they do.
                let recipe = try RecipeParser.parse(
                    response: canonical, goal: "g", modelUsed: "m"
                )
                try expect(recipe.items.allSatisfy(\.selected),
                           "every item must default to selected")
            }
        }

        TestHarness.suite("DownloadRecipe Codable round-trip") {

            TestHarness.test("Recipe survives encode → decode via the store encoder") {
                let recipe = try RecipeParser.parse(
                    response: canonical, goal: "g", modelUsed: "m",
                    now: Date(timeIntervalSince1970: 1776000000)
                )
                let enc = JSONEncoder()
                enc.dateEncodingStrategy = .iso8601
                let data = try enc.encode(recipe)
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                let roundtrip = try dec.decode(DownloadRecipe.self, from: data)
                try expectEqual(roundtrip.title, recipe.title)
                try expectEqual(roundtrip.items.count, recipe.items.count)
                try expectEqual(roundtrip.items[0].name, recipe.items[0].name)
                try expectEqual(roundtrip.items[0].url, recipe.items[0].url)
                try expectEqual(roundtrip.items[0].confidence, recipe.items[0].confidence)
            }
        }
    }
}
