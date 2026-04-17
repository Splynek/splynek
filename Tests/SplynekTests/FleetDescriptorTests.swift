import Foundation
@testable import SplynekCore

/// Load-bearing claim (v0.27): the CLI / Raycast / Alfred can all
/// locate the running app via a single well-known descriptor file.
/// If this path drifts, every auxiliary surface breaks silently.
enum FleetDescriptorTests {

    static func run() {
        TestHarness.suite("Fleet descriptor") {

            TestHarness.test("Descriptor lives under Application Support / Splynek") {
                let url = FleetCoordinator.fleetDescriptorURL
                let path = url.path
                try expect(path.contains("Application Support"),
                           "path must live under Application Support")
                try expect(path.contains("/Splynek/"),
                           "path must be inside /Splynek/")
                try expect(path.hasSuffix("fleet.json"),
                           "filename must be fleet.json")
            }

            TestHarness.test("Descriptor round-trips via Codable") {
                let original = FleetCoordinator.FleetDescriptor(
                    port: 54321,
                    token: String(repeating: "a", count: 32),
                    deviceName: "Test Mac",
                    deviceUUID: "11111111-2222-3333-4444-555555555555"
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(original)
                let roundTrip = try JSONDecoder().decode(
                    FleetCoordinator.FleetDescriptor.self, from: data
                )
                try expectEqual(roundTrip.port, original.port)
                try expectEqual(roundTrip.token, original.token)
                try expectEqual(roundTrip.deviceName, original.deviceName)
                try expectEqual(roundTrip.deviceUUID, original.deviceUUID)
                try expectEqual(roundTrip.schemeVersion, 1,
                                "default schemeVersion must be 1 for forward compat")
            }
        }
    }
}
