import Foundation
import SplynekCompanionCore

/// S4 phase 3 (2026-05-07): tests for `RelayPolicy.decide(...)`,
/// the pure decision layer that decides "should iOS submit via LAN
/// or fall back to CloudKit?" given the LAN attempt's outcome and
/// the user's relay-enabled toggle.
enum CompanionRelayPolicyTests {

    static func run() {
        TestHarness.suite("RelayPolicy — happy path") {

            TestHarness.test("LAN succeeded → done (no CloudKit)") {
                let d = RelayPolicy.decide(
                    lanOutcome: .success, cloudKitRelayEnabled: true)
                try expect(d == .done)
            }

            TestHarness.test("LAN succeeded with relay disabled → still done") {
                let d = RelayPolicy.decide(
                    lanOutcome: .success, cloudKitRelayEnabled: false)
                try expect(d == .done)
            }
        }

        TestHarness.suite("RelayPolicy — token rejection never falls back") {

            TestHarness.test("Unauthorised + relay enabled → surface error") {
                let d = RelayPolicy.decide(
                    lanOutcome: .unauthorised, cloudKitRelayEnabled: true)
                if case .surfaceError(let msg) = d {
                    try expect(msg.contains("token"))
                    try expect(msg.contains("Re-pair") || msg.contains("re-pair"))
                } else {
                    try expect(false)
                }
            }

            TestHarness.test("Unauthorised + relay disabled → surface error (same)") {
                let d = RelayPolicy.decide(
                    lanOutcome: .unauthorised, cloudKitRelayEnabled: false)
                if case .surfaceError = d {
                    try expect(true)
                } else {
                    try expect(false)
                }
            }
        }

        TestHarness.suite("RelayPolicy — network failure → CloudKit (when enabled)") {

            TestHarness.test("notReachable + relay enabled → fallbackToCloudKit") {
                let d = RelayPolicy.decide(
                    lanOutcome: .notReachable, cloudKitRelayEnabled: true)
                try expect(d == .fallbackToCloudKit)
            }

            TestHarness.test("timeout + relay enabled → fallbackToCloudKit") {
                let d = RelayPolicy.decide(
                    lanOutcome: .timeout, cloudKitRelayEnabled: true)
                try expect(d == .fallbackToCloudKit)
            }

            TestHarness.test("HTTP 500 + relay enabled → fallbackToCloudKit") {
                let d = RelayPolicy.decide(
                    lanOutcome: .other(httpStatus: 500),
                    cloudKitRelayEnabled: true)
                try expect(d == .fallbackToCloudKit)
            }
        }

        TestHarness.suite("RelayPolicy — network failure + relay disabled → surface error") {

            TestHarness.test("notReachable + relay disabled → error mentions Wi-Fi + Settings") {
                let d = RelayPolicy.decide(
                    lanOutcome: .notReachable, cloudKitRelayEnabled: false)
                if case .surfaceError(let msg) = d {
                    try expect(msg.contains("Wi-Fi") || msg.contains("Settings"))
                } else {
                    try expect(false)
                }
            }

            TestHarness.test("timeout + relay disabled → surface error") {
                let d = RelayPolicy.decide(
                    lanOutcome: .timeout, cloudKitRelayEnabled: false)
                if case .surfaceError = d {
                    try expect(true)
                } else {
                    try expect(false)
                }
            }
        }
    }
}
