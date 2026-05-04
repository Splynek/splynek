import Foundation
import Network
@testable import SplynekCore

/// Bet S2 — Unbreakable Resume (component 2): unit tests for the
/// pure translate/equality/restart-decision logic.  The live
/// AsyncStream path requires a real NWPathMonitor against the host's
/// network state, which makes it non-deterministic — covered by
/// integration when the engine subscribes.
enum PathMonitorObserverTests {

    static func run() {
        TestHarness.suite("PathMonitorObserver — translate") {

            TestHarness.test(".satisfied with one interface yields .online") {
                let e = PathMonitorObserver.translate(
                    status: .satisfied,
                    interfaceNames: ["en0"]
                )
                try expectEqual(e, .online(interfaceNames: ["en0"]))
            }

            TestHarness.test(".satisfied with multiple interfaces preserves the set") {
                let e = PathMonitorObserver.translate(
                    status: .satisfied,
                    interfaceNames: ["en0", "en1", "pdp_ip0"]
                )
                try expectEqual(e, .online(interfaceNames: ["en0", "en1", "pdp_ip0"]))
            }

            TestHarness.test(".unsatisfied always yields .offline") {
                let e = PathMonitorObserver.translate(
                    status: .unsatisfied,
                    interfaceNames: []
                )
                try expectEqual(e, .offline)
            }

            TestHarness.test(".requiresConnection yields .offline") {
                let e = PathMonitorObserver.translate(
                    status: .requiresConnection,
                    interfaceNames: ["en0"]
                )
                try expectEqual(e, .offline,
                    ".requiresConnection means no path until the framework dials a VPN — treat as offline so the engine doesn't burn requests against a tunnel that hasn't come up yet")
            }

            TestHarness.test(".satisfied with empty interface set degrades to .offline") {
                let e = PathMonitorObserver.translate(
                    status: .satisfied,
                    interfaceNames: []
                )
                try expectEqual(e, .offline,
                    "Degenerate case the framework doesn't actually emit, but the lane-restart hook would dispatch an empty-interfaces restart that immediately fails — guard against it explicitly")
            }
        }

        TestHarness.suite("PathEvent — equality") {

            TestHarness.test("Two .online events with same interface set are equal") {
                let a: PathEvent = .online(interfaceNames: ["en0"])
                let b: PathEvent = .online(interfaceNames: ["en0"])
                try expectEqual(a, b)
            }

            TestHarness.test("Two .online events with different interface sets are unequal") {
                let a: PathEvent = .online(interfaceNames: ["en0"])
                let b: PathEvent = .online(interfaceNames: ["en1"])
                try expect(a != b, ".online sets are part of the equality contract")
            }

            TestHarness.test(".online and .offline are unequal") {
                let a: PathEvent = .online(interfaceNames: ["en0"])
                let b: PathEvent = .offline
                try expect(a != b)
            }

            TestHarness.test("Set ordering doesn't matter for equality") {
                let a: PathEvent = .online(interfaceNames: ["en0", "en1"])
                let b: PathEvent = .online(interfaceNames: ["en1", "en0"])
                try expectEqual(a, b, "Set semantics — order is immaterial")
            }
        }

        TestHarness.suite("PathEvent — warrantsRestart") {

            TestHarness.test("nil → online: false (first observation, no prior to compare)") {
                let r = PathEvent.warrantsRestart(
                    from: nil,
                    to: .online(interfaceNames: ["en0"])
                )
                try expect(!r, "First event after engine start isn't a path *change*")
            }

            TestHarness.test("nil → offline: false") {
                let r = PathEvent.warrantsRestart(from: nil, to: .offline)
                try expect(!r)
            }

            TestHarness.test("Identical online events: false (suppress flap noise)") {
                let r = PathEvent.warrantsRestart(
                    from: .online(interfaceNames: ["en0"]),
                    to: .online(interfaceNames: ["en0"])
                )
                try expect(!r, "Same interface set means nothing changed — no restart")
            }

            TestHarness.test("Identical offline events: false") {
                let r = PathEvent.warrantsRestart(from: .offline, to: .offline)
                try expect(!r)
            }

            TestHarness.test("online → offline: true (network dropped, pause in-flight)") {
                let r = PathEvent.warrantsRestart(
                    from: .online(interfaceNames: ["en0"]),
                    to: .offline
                )
                try expect(r)
            }

            TestHarness.test("offline → online: true (network came back, restart from sidecar)") {
                let r = PathEvent.warrantsRestart(
                    from: .offline,
                    to: .online(interfaceNames: ["en1"])
                )
                try expect(r)
            }

            TestHarness.test("online interface flip (en0 → en1): true") {
                let r = PathEvent.warrantsRestart(
                    from: .online(interfaceNames: ["en0"]),
                    to: .online(interfaceNames: ["en1"])
                )
                try expect(r, "Wi-Fi → Ethernet flip — sidecar restart picks up over the new lane")
            }

            TestHarness.test("online interface added (en0 → en0+en1): true") {
                let r = PathEvent.warrantsRestart(
                    from: .online(interfaceNames: ["en0"]),
                    to: .online(interfaceNames: ["en0", "en1"])
                )
                try expect(r, "Cable plugged in mid-download — engine should rebalance lanes")
            }

            TestHarness.test("online interface removed (en0+en1 → en0): true") {
                let r = PathEvent.warrantsRestart(
                    from: .online(interfaceNames: ["en0", "en1"]),
                    to: .online(interfaceNames: ["en0"])
                )
                try expect(r, "Cable unplugged — engine drops the en1 lane")
            }
        }

        TestHarness.suite("PathEvent — didGoOffline / didComeOnline") {

            // The narrower predicates the VM uses to gate auto-pause +
            // auto-resume.  warrantsRestart fires on ANY meaningful
            // transition (incl. interface-set flips); these two fire
            // ONLY on connectivity transitions that warrant a full
            // pause+resume cycle.

            TestHarness.test("didGoOffline: online → offline is true") {
                try expect(PathEvent.didGoOffline(
                    from: .online(interfaceNames: ["en0"]),
                    to: .offline
                ))
            }

            TestHarness.test("didGoOffline: nil → offline is false (first-observation)") {
                try expect(!PathEvent.didGoOffline(from: nil, to: .offline))
            }

            TestHarness.test("didGoOffline: offline → offline is false (no transition)") {
                try expect(!PathEvent.didGoOffline(from: .offline, to: .offline))
            }

            TestHarness.test("didGoOffline: online → online (interface flip) is false") {
                try expect(!PathEvent.didGoOffline(
                    from: .online(interfaceNames: ["en0"]),
                    to: .online(interfaceNames: ["en1"])
                ), "Interface-set change isn't a connectivity loss — engine handles via per-lane failover")
            }

            TestHarness.test("didComeOnline: offline → online is true") {
                try expect(PathEvent.didComeOnline(
                    from: .offline,
                    to: .online(interfaceNames: ["en0"])
                ))
            }

            TestHarness.test("didComeOnline: nil → online is false") {
                try expect(!PathEvent.didComeOnline(
                    from: nil,
                    to: .online(interfaceNames: ["en0"])
                ), "First observation isn't a 'came back online' transition")
            }

            TestHarness.test("didComeOnline: online → online is false") {
                try expect(!PathEvent.didComeOnline(
                    from: .online(interfaceNames: ["en0"]),
                    to: .online(interfaceNames: ["en0", "en1"])
                ))
            }

            TestHarness.test("Predicates are mutually exclusive on every transition") {
                let cases: [(PathEvent?, PathEvent)] = [
                    (nil, .offline),
                    (nil, .online(interfaceNames: ["en0"])),
                    (.offline, .offline),
                    (.offline, .online(interfaceNames: ["en0"])),
                    (.online(interfaceNames: ["en0"]), .offline),
                    (.online(interfaceNames: ["en0"]), .online(interfaceNames: ["en0"])),
                    (.online(interfaceNames: ["en0"]), .online(interfaceNames: ["en1"])),
                ]
                for (prev, next) in cases {
                    let off = PathEvent.didGoOffline(from: prev, to: next)
                    let on  = PathEvent.didComeOnline(from: prev, to: next)
                    try expect(!(off && on),
                        "Both predicates fired for \(String(describing: prev)) → \(next) — they should be mutually exclusive")
                }
            }
        }
    }
}
