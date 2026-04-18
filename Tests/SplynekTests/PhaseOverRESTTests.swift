import Foundation
@testable import SplynekCore

/// v0.36 added a `phase` field to `LocalState.ActiveJob` so REST
/// consumers (integration tests, CLI status, Raycast) can observe
/// the pipeline stage transitions, not just byte counts. These
/// tests pin:
///   (a) the JSON payload actually includes `phase`;
///   (b) the values agree exactly with `DownloadProgress.Phase.rawValue`
///       — a regression here silently breaks every client that
///       dispatches on the string;
///   (c) the OpenAPI spec lists `phase` as a required field on
///       `ActiveJob` so generated-client codegen picks it up.
enum PhaseOverRESTTests {

    static func run() {
        TestHarness.suite("Phase over REST") {

            TestHarness.test("ActiveJob JSON round-trips with phase populated") {
                let original = FleetCoordinator.LocalState.ActiveJob(
                    url: "https://example.com/x.bin",
                    filename: "x.bin",
                    outputPath: "/tmp/x.bin",
                    totalBytes: 2_097_152,
                    downloaded: 1_048_576,
                    chunkSize: 4_194_304,
                    completedChunks: [0],
                    phase: "Downloading"
                )
                let data = try JSONEncoder().encode(original)
                guard let json = String(data: data, encoding: .utf8) else {
                    try expect(false, "encode produced non-UTF8"); return
                }
                try expect(json.contains("\"phase\""),
                           "phase key missing from JSON")
                try expect(json.contains("\"Downloading\""),
                           "phase value missing from JSON")
                let decoded = try JSONDecoder().decode(
                    FleetCoordinator.LocalState.ActiveJob.self, from: data
                )
                try expectEqual(decoded.phase, "Downloading")
                try expectEqual(decoded.downloaded, 1_048_576)
            }

            TestHarness.test("Phase strings match DownloadProgress.Phase exactly") {
                // If someone renames a phase in the engine, the REST
                // value moves with it — but the OpenAPI `enum` on the
                // `phase` property and downstream clients (CLI, test
                // script) would silently break. This test locks the
                // string set so that kind of rename requires explicit
                // consent from the test suite.
                let expected = [
                    "Queued", "Probing", "Planning", "Connecting",
                    "Downloading", "Verifying", "Gatekeeper", "Done"
                ]
                try expectEqual(
                    DownloadProgress.Phase.allCases.map(\.rawValue),
                    expected
                )
            }

            TestHarness.test("OpenAPI spec lists phase as a required ActiveJob property") {
                let yaml = OpenAPI.yaml
                try expect(yaml.contains("phase:"),
                           "OpenAPI ActiveJob schema missing phase property")
                // All eight engine phases must appear in the enum.
                for raw in DownloadProgress.Phase.allCases.map(\.rawValue) {
                    try expect(yaml.contains(raw),
                               "OpenAPI phase enum missing value: \(raw)")
                }
                // Required list includes phase so generated clients
                // don't mark it optional.
                try expect(
                    yaml.contains("required: [url, filename, outputPath, totalBytes, downloaded, chunkSize, completedChunks, phase]"),
                    "phase not listed as required on ActiveJob"
                )
            }

            TestHarness.test("Default phase is empty string (pre-populated job)") {
                // A brand-new ActiveJob (before the first phase transition
                // fires the Combine republish) should carry an empty
                // phase string. The CLI defaults the field when decoding,
                // and integration-test.py treats "" as "not yet started."
                let fresh = FleetCoordinator.LocalState.ActiveJob(
                    url: "x", filename: "x", outputPath: "x",
                    totalBytes: 0, downloaded: 0,
                    chunkSize: 0, completedChunks: []
                )
                try expectEqual(fresh.phase, "")
            }
        }
    }
}
