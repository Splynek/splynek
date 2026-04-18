import Foundation
@testable import SplynekCore

/// Pins the mapping from TorrentEngine's freeform `progress.phase` strings
/// (plus piece/finished/seeding state) onto the six-pill shared pipeline
/// vocabulary. The card's phase strip rendering depends on this being
/// deterministic across releases — a regression here means pills jump
/// around during a real swarm run.
enum LiveTorrentPhaseTests {

    static func run() {
        TestHarness.suite("Torrent Live phase mapping") {

            TestHarness.test("blank phase before any announce → announcing") {
                let p = TorrentLivePhase.infer(
                    phase: "", piecesDone: 0, finished: false, seedingListening: false
                )
                try expectEqual(p, .announcing)
            }

            TestHarness.test("Announcing and DHT probing both collapse to announcing") {
                try expectEqual(
                    TorrentLivePhase.infer(
                        phase: "Announcing to trackers…",
                        piecesDone: 0, finished: false, seedingListening: false
                    ),
                    .announcing
                )
                try expectEqual(
                    TorrentLivePhase.infer(
                        phase: "Probing DHT…",
                        piecesDone: 0, finished: false, seedingListening: false
                    ),
                    .announcing
                )
            }

            TestHarness.test("BEP 9 metadata fetch → fetchingMetadata") {
                try expectEqual(
                    TorrentLivePhase.infer(
                        phase: "Fetching metadata (BEP 9)…",
                        piecesDone: 0, finished: false, seedingListening: false
                    ),
                    .fetchingMetadata
                )
            }

            TestHarness.test("Connecting to peers with zero pieces → connecting") {
                try expectEqual(
                    TorrentLivePhase.infer(
                        phase: "Connecting to peers…",
                        piecesDone: 0, finished: false, seedingListening: false
                    ),
                    .connecting
                )
            }

            TestHarness.test("piecesDone > 0 beats the freeform phase string") {
                // Engine leaves phase at "Connecting to peers…" while pieces
                // arrive; the strip should move on regardless.
                try expectEqual(
                    TorrentLivePhase.infer(
                        phase: "Connecting to peers…",
                        piecesDone: 42, finished: false, seedingListening: false
                    ),
                    .downloading
                )
            }

            TestHarness.test("finished + no seeding listener → done") {
                try expectEqual(
                    TorrentLivePhase.infer(
                        phase: "Done.",
                        piecesDone: 100, finished: true, seedingListening: false
                    ),
                    .done
                )
            }

            TestHarness.test("finished + listening seeder → seeding") {
                try expectEqual(
                    TorrentLivePhase.infer(
                        phase: "Seeding.",
                        piecesDone: 100, finished: true, seedingListening: true
                    ),
                    .seeding
                )
            }

            TestHarness.test("Seeding stopped after completion maps to done") {
                try expectEqual(
                    TorrentLivePhase.infer(
                        phase: "Seeding stopped.",
                        piecesDone: 100, finished: true, seedingListening: false
                    ),
                    .done
                )
            }

            TestHarness.test("raw values are stable (they appear in the UI)") {
                // Regression guard: the Live dashboard renders these strings
                // as pill labels; renaming them is a visual change.
                try expectEqual(TorrentLivePhase.announcing.rawValue, "Announcing")
                try expectEqual(TorrentLivePhase.fetchingMetadata.rawValue, "Fetching metadata")
                try expectEqual(TorrentLivePhase.connecting.rawValue, "Connecting to peers")
                try expectEqual(TorrentLivePhase.downloading.rawValue, "Downloading")
                try expectEqual(TorrentLivePhase.seeding.rawValue, "Seeding")
                try expectEqual(TorrentLivePhase.done.rawValue, "Done")
            }

            TestHarness.test("allCases order matches pipeline left-to-right") {
                // Phase strip iterates allCases; reordering would scramble
                // past/current/upcoming state on screen.
                try expectEqual(
                    TorrentLivePhase.allCases,
                    [.announcing, .fetchingMetadata, .connecting, .downloading, .seeding, .done]
                )
            }
        }
    }
}
