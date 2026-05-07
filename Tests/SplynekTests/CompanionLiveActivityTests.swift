import Foundation
import SplynekCompanionCore

/// S4 phase 2 (2026-05-07): tests for `LiveActivityCoordinator`'s
/// pure decide/project layer.  No ActivityKit involvement —
/// `LiveActivityDriver` (the iOS-only wrapper that performs the
/// actual `Activity.request` / `update` / `end` calls) lives under
/// iOS/SplynekCompanion/ and is exercised on-device only.
enum CompanionLiveActivityTests {

    static func run() {
        TestHarness.suite("LiveActivityCoordinator — decide()") {

            TestHarness.test("Empty previous + no current jobs → empty plan") {
                let plan = LiveActivityCoordinator.decide(
                    previous: .init(),
                    current: []
                )
                try expect(plan.isEmpty)
            }

            TestHarness.test("New running job → toStart contains it, others empty") {
                let job = makeIdent(id: "j1", phase: "running")
                let plan = LiveActivityCoordinator.decide(
                    previous: .init(),
                    current: [job]
                )
                try expect(plan.toStart.count == 1)
                try expect(plan.toStart.first?.key.jobID == "j1")
                try expect(plan.toUpdate.isEmpty)
                try expect(plan.toEnd.isEmpty)
            }

            TestHarness.test("Continuing running job → toUpdate (not toStart)") {
                let key = LiveActivityCoordinator.ActivityKey(
                    macUUID: "m1", jobID: "j1")
                let prev = LiveActivityCoordinator.Snapshot(activeKeys: [key])
                let job = makeIdent(id: "j1", phase: "running")
                let plan = LiveActivityCoordinator.decide(
                    previous: prev, current: [job])
                try expect(plan.toStart.isEmpty)
                try expect(plan.toUpdate.count == 1)
                try expect(plan.toEnd.isEmpty)
            }

            TestHarness.test("Job no longer in current → toEnd contains its key") {
                let key = LiveActivityCoordinator.ActivityKey(
                    macUUID: "m1", jobID: "j1")
                let prev = LiveActivityCoordinator.Snapshot(activeKeys: [key])
                let plan = LiveActivityCoordinator.decide(
                    previous: prev, current: [])
                try expect(plan.toEnd.count == 1)
                try expect(plan.toEnd.first?.jobID == "j1")
            }

            TestHarness.test("Queued job is ignored — no Activity started") {
                let job = makeIdent(id: "j1", phase: "queued")
                let plan = LiveActivityCoordinator.decide(
                    previous: .init(), current: [job])
                try expect(plan.isEmpty)
            }

            TestHarness.test("Paused job DOES get an Activity (user wants visibility)") {
                let job = makeIdent(id: "j1", phase: "paused")
                let plan = LiveActivityCoordinator.decide(
                    previous: .init(), current: [job])
                try expect(plan.toStart.count == 1)
            }

            TestHarness.test("Job transitions running → finished → ends Activity") {
                let key = LiveActivityCoordinator.ActivityKey(
                    macUUID: "m1", jobID: "j1")
                let prev = LiveActivityCoordinator.Snapshot(activeKeys: [key])
                let job = makeIdent(id: "j1", phase: "finished")
                let plan = LiveActivityCoordinator.decide(
                    previous: prev, current: [job])
                try expect(plan.toEnd.count == 1)
                try expect(plan.toStart.isEmpty)
                try expect(plan.toUpdate.isEmpty)
            }

            TestHarness.test("Mixed snapshot — start one, update one, end one") {
                let oldKey = LiveActivityCoordinator.ActivityKey(macUUID: "m1", jobID: "old")
                let continuingKey = LiveActivityCoordinator.ActivityKey(macUUID: "m1", jobID: "cont")
                let prev = LiveActivityCoordinator.Snapshot(
                    activeKeys: [oldKey, continuingKey])
                let plan = LiveActivityCoordinator.decide(
                    previous: prev,
                    current: [
                        makeIdent(id: "cont", phase: "running"),
                        makeIdent(id: "new",  phase: "running"),
                    ]
                )
                try expect(plan.toStart.count == 1)
                try expect(plan.toStart.first?.key.jobID == "new")
                try expect(plan.toUpdate.count == 1)
                try expect(plan.toUpdate.first?.key.jobID == "cont")
                try expect(plan.toEnd.count == 1)
                try expect(plan.toEnd.first?.jobID == "old")
            }
        }

        TestHarness.suite("LiveActivityCoordinator — project()") {

            TestHarness.test("Project after start adds keys to snapshot") {
                let plan = LiveActivityCoordinator.Plan(
                    toStart: [makeIdent(id: "j1", phase: "running")])
                let after = LiveActivityCoordinator.project(after: plan, from: .init())
                try expect(after.activeKeys.count == 1)
            }

            TestHarness.test("Project after end removes keys from snapshot") {
                let key = LiveActivityCoordinator.ActivityKey(macUUID: "m1", jobID: "j1")
                let prev = LiveActivityCoordinator.Snapshot(activeKeys: [key])
                let plan = LiveActivityCoordinator.Plan(toEnd: [key])
                let after = LiveActivityCoordinator.project(after: plan, from: prev)
                try expect(after.activeKeys.isEmpty)
            }

            TestHarness.test("Project after update is no-op on snapshot") {
                let key = LiveActivityCoordinator.ActivityKey(macUUID: "m1", jobID: "j1")
                let prev = LiveActivityCoordinator.Snapshot(activeKeys: [key])
                let plan = LiveActivityCoordinator.Plan(
                    toUpdate: [makeIdent(id: "j1", phase: "running")])
                let after = LiveActivityCoordinator.project(after: plan, from: prev)
                try expect(after.activeKeys == prev.activeKeys)
            }

            TestHarness.test("Multi-step chain: empty → +j1 → +j2 → -j1 → just j2") {
                var snap = LiveActivityCoordinator.Snapshot()
                let plan1 = LiveActivityCoordinator.decide(
                    previous: snap,
                    current: [makeIdent(id: "j1", phase: "running")]
                )
                snap = LiveActivityCoordinator.project(after: plan1, from: snap)
                let plan2 = LiveActivityCoordinator.decide(
                    previous: snap,
                    current: [
                        makeIdent(id: "j1", phase: "running"),
                        makeIdent(id: "j2", phase: "running"),
                    ]
                )
                snap = LiveActivityCoordinator.project(after: plan2, from: snap)
                let plan3 = LiveActivityCoordinator.decide(
                    previous: snap,
                    current: [makeIdent(id: "j2", phase: "running")]
                )
                snap = LiveActivityCoordinator.project(after: plan3, from: snap)
                try expect(snap.activeKeys.count == 1)
                try expect(snap.activeKeys.contains(.init(macUUID: "m1", jobID: "j2")))
            }
        }

        TestHarness.suite("LiveActivityCoordinator.JobIdent.deservesActivity") {

            TestHarness.test("running deserves") {
                try expect(makeIdent(id: "x", phase: "running").deservesActivity)
            }

            TestHarness.test("paused deserves") {
                try expect(makeIdent(id: "x", phase: "paused").deservesActivity)
            }

            TestHarness.test("queued does NOT deserve") {
                try expect(!makeIdent(id: "x", phase: "queued").deservesActivity)
            }

            TestHarness.test("finished does NOT deserve") {
                try expect(!makeIdent(id: "x", phase: "finished").deservesActivity)
            }

            TestHarness.test("failed does NOT deserve") {
                try expect(!makeIdent(id: "x", phase: "failed").deservesActivity)
            }
        }
    }

    private static func makeIdent(id: String, phase: String) -> LiveActivityCoordinator.JobIdent {
        LiveActivityCoordinator.JobIdent(
            key: .init(macUUID: "m1", jobID: id),
            phase: phase,
            displayName: "test.dmg",
            sourceURL: "https://example.com/test.dmg",
            downloaded: 1024,
            total: 2048,
            throughputBps: 100_000,
            etaSeconds: nil
        )
    }
}
