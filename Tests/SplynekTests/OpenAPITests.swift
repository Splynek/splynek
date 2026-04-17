import Foundation
@testable import SplynekCore

/// Load-bearing claim (v0.27): Splynek ships a valid OpenAPI 3.1 spec
/// embedded at `/splynek/v1/openapi.yaml`. Wrong spec shape makes
/// every generated client break silently.
enum OpenAPITests {

    static func run() {
        TestHarness.suite("OpenAPI spec") {

            TestHarness.test("Declares OpenAPI 3.1") {
                try expect(OpenAPI.yaml.contains("openapi: 3.1.0"),
                           "openapi version line missing")
            }

            TestHarness.test("Lists every routed path") {
                let yaml = OpenAPI.yaml
                for path in [
                    "/splynek/v1/status",
                    "/splynek/v1/openapi.yaml",
                    "/splynek/v1/api/jobs",
                    "/splynek/v1/api/history",
                    "/splynek/v1/api/download",
                    "/splynek/v1/api/queue",
                    "/splynek/v1/api/cancel",
                ] {
                    try expect(yaml.contains(path), "missing path: \(path)")
                }
            }

            TestHarness.test("Documents the token parameter") {
                try expect(OpenAPI.yaml.contains("parameters"))
                try expect(OpenAPI.yaml.contains("Token:"))
                try expect(OpenAPI.yaml.contains("Shared secret"))
            }

            TestHarness.test("Declares every schema referenced in paths") {
                let yaml = OpenAPI.yaml
                // Every `$ref:` must point at a `schemas/<name>` that the
                // components block actually declares.
                for name in ["FleetState", "JobList", "HistoryList",
                             "SubmitRequest", "ActiveJob", "CompletedFile"] {
                    try expect(yaml.contains("schemas/\(name)"),
                               "no \\$ref to \(name)")
                    try expect(yaml.contains("\(name):"),
                               "\(name) is referenced but not defined")
                }
            }

            TestHarness.test("Mutating endpoints require the Token parameter") {
                // Each POST path should have `{ $ref: Token }`. The YAML
                // is hand-maintained, so a missing reference on a new
                // mutation endpoint would silently drop auth. Test guards.
                let mustHaveToken: [String] = [
                    "/splynek/v1/api/download",
                    "/splynek/v1/api/queue",
                    "/splynek/v1/api/cancel"
                ]
                let lines = OpenAPI.yaml.split(separator: "\n").map(String.init)
                for path in mustHaveToken {
                    // Find the path line; scan forward to the next path or
                    // components block; within that window require a Token $ref.
                    guard let start = lines.firstIndex(where: { $0.contains("\(path):") }) else {
                        throw Expectation(message: "path \(path) missing", file: #file, line: #line)
                    }
                    // Look at the next ~30 lines (scope of this path item).
                    let windowEnd = min(lines.count, start + 30)
                    let window = lines[start..<windowEnd].joined(separator: "\n")
                    try expect(window.contains("Token"),
                               "path \(path) missing Token parameter")
                }
            }
        }
    }
}
