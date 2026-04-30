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
    static var skipped = 0
    static var currentSuite: String = ""
    static var failures: [String] = []

    /// v1.6.2: substring filter for narrowing a run.  Set via `--filter
    /// <substring>` (or `-f <substring>`) on the splynek-test command
    /// line.  Match is case-insensitive against `"<suite>: <name>"`.
    /// nil → run everything (the default).
    static var filter: String?

    static func suite(_ name: String, _ body: () -> Void) {
        currentSuite = name
        suiteHeaderPrinted = false
        // v1.6.2: only print the suite header when at least one of its
        // tests will actually run under the current filter — keeps the
        // filtered-run output tight.
        if filter == nil {
            print("  \(name)")
            suiteHeaderPrinted = true
        }
        body()
    }

    /// v1.6.2: returns true if the test should run under the current
    /// `filter`.  Substring match against `"<suite>: <name>"`,
    /// case-insensitive.
    fileprivate static func matchesFilter(_ name: String) -> Bool {
        guard let f = filter else { return true }
        return "\(currentSuite): \(name)".lowercased().contains(f.lowercased())
    }

    /// Lazy suite-header for filtered runs: print the header at most
    /// once per suite, just before its first matching test.
    fileprivate static var suiteHeaderPrinted = false
    fileprivate static func ensureSuiteHeader() {
        if filter != nil && !suiteHeaderPrinted {
            print("  \(currentSuite)")
            suiteHeaderPrinted = true
        }
    }

    static func test(_ name: String, _ body: () throws -> Void) {
        if !matchesFilter(name) {
            skipped += 1
            return
        }
        ensureSuiteHeader()
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

    /// v1.6: async-test overload — runs the body on a fresh Task and
    /// blocks the synchronous suite walker via DispatchSemaphore.  Used
    /// by MCP / network protocol tests where the system under test is
    /// async/await all the way down.  Same printing + counting logic
    /// as the sync overload.
    static func test(_ name: String, _ body: @escaping @Sendable () async throws -> Void) {
        if !matchesFilter(name) {
            skipped += 1
            return
        }
        ensureSuiteHeader()
        total += 1
        let sema = DispatchSemaphore(value: 0)
        var caught: Error?
        Task {
            do { try await body() } catch { caught = error }
            sema.signal()
        }
        sema.wait()
        if let error = caught {
            failed += 1
            let msg = "    ✗ \(name) — \(error)"
            print(msg)
            failures.append("\(currentSuite): \(name) — \(error)")
        } else {
            print("    ✓ \(name)")
        }
    }

    static func finish() -> Never {
        print("")
        let suffix = skipped > 0 ? " (\(skipped) skipped by filter)" : ""
        if failed == 0 {
            if total == 0 && filter != nil {
                print("✗ no tests matched filter \"\(filter!)\"")
                exit(1)
            }
            print("✓ \(total) tests passed\(suffix)")
            exit(0)
        } else {
            print("✗ \(failed) of \(total) tests failed\(suffix)")
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
