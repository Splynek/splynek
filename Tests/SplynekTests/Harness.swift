import Foundation

/// Minimal assertion harness for Splynek's self-hosted test runner.
///
/// We can't rely on XCTest (needs Xcode) or Swift Testing (needs paths
/// that CLT doesn't hand to SPM cleanly). This harness is 60 lines and
/// gives us everything we actually need for a credibility-pass suite:
/// grouping, assertions, failure messages, exit code.
///
/// Usage:
///     suite("Foo") {
///         test("does a thing") {
///             expect(1 + 1 == 2)
///         }
///     }
///
/// `main.swift` calls a sequence of suite-building functions, then
/// invokes `TestHarness.finish()` which prints the summary and exits.

enum TestHarness {
    static var total = 0
    static var failed = 0
    static var currentSuite: String = ""
    static var failures: [String] = []

    static func suite(_ name: String, _ body: () -> Void) {
        currentSuite = name
        print("  \(name)")
        body()
    }

    static func test(_ name: String, _ body: () throws -> Void) {
        total += 1
        do {
            try body()
            print("    ✓ \(name)")
        } catch {
            failed += 1
            let msg = "    ✗ \(name) — \(error)"
            print(msg)
            failures.append("\(currentSuite): \(name) — \(error)")
        }
    }

    static func finish() -> Never {
        print("")
        if failed == 0 {
            print("✓ \(total) tests passed")
            exit(0)
        } else {
            print("✗ \(failed) of \(total) tests failed")
            for f in failures { print("  \(f)") }
            exit(1)
        }
    }
}

/// Failure surfaced as a thrown error so `test` sees it and reports.
struct Expectation: Error, CustomStringConvertible {
    let message: String
    let file: String
    let line: Int
    var description: String {
        "\(message)  (\((file as NSString).lastPathComponent):\(line))"
    }
}

/// Assert truthiness. On failure, throws so `test` records it.
func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String = "condition was false",
    file: String = #file,
    line: Int = #line
) throws {
    if !condition() {
        throw Expectation(message: message(), file: file, line: line)
    }
}

/// Assert equality; prints both sides on failure.
func expectEqual<T: Equatable>(
    _ lhs: @autoclosure () -> T,
    _ rhs: @autoclosure () -> T,
    _ note: String = "",
    file: String = #file,
    line: Int = #line
) throws {
    let l = lhs()
    let r = rhs()
    if l != r {
        let extra = note.isEmpty ? "" : " — \(note)"
        throw Expectation(
            message: "expected \(l) == \(r)\(extra)",
            file: file, line: line
        )
    }
}
