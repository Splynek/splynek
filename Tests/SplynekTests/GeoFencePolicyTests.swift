import Foundation
@testable import SplynekCompanionCore

/// Pure tests for the iOS geo-fence decision policy.  Sprint 2
/// scaffold (2026-05-09) — exercised on macOS because the policy
/// has no CoreLocation dependency; only the runner does.
enum GeoFencePolicyTests {

    static func run() {
        TestHarness.suite("GeoFence — decision policy") {

            TestHarness.test("Exited with no prior event → pauseAll") {
                let action = GeoFencePolicy.action(
                    for: .exited, lastEvent: nil
                )
                try expect(action == .pauseAll, "expected pauseAll, got \(action)")
            }

            TestHarness.test("Entered with no prior event → resumeAll") {
                let action = GeoFencePolicy.action(
                    for: .entered, lastEvent: nil
                )
                try expect(action == .resumeAll, "expected resumeAll, got \(action)")
            }

            TestHarness.test("Same-direction transition within cooldown → noOp") {
                let prior = GeoFenceEvent(
                    transition: .exited,
                    timestamp: Date(timeIntervalSinceNow: -10)
                )
                let action = GeoFencePolicy.action(
                    for: .exited, lastEvent: prior
                )
                try expect(action == .noOp,
                           "expected noOp for repeat in cooldown, got \(action)")
            }

            TestHarness.test("Same-direction transition AFTER cooldown → fires") {
                let prior = GeoFenceEvent(
                    transition: .exited,
                    timestamp: Date(timeIntervalSinceNow: -120)
                )
                let action = GeoFencePolicy.action(
                    for: .exited, lastEvent: prior,
                    cooldownSeconds: 60
                )
                try expect(action == .pauseAll,
                           "expected pauseAll after cooldown, got \(action)")
            }

            TestHarness.test("Opposite direction within cooldown → fires") {
                let prior = GeoFenceEvent(
                    transition: .exited,
                    timestamp: Date(timeIntervalSinceNow: -10)
                )
                let action = GeoFencePolicy.action(
                    for: .entered, lastEvent: prior,
                    cooldownSeconds: 60
                )
                try expect(action == .resumeAll,
                           "expected resumeAll on opposite-direction within cooldown, got \(action)")
            }
        }
    }
}
