import Foundation
@testable import SplynekCore

/// Strategy Bet S5 — BondedFetcher byte-range splitter tests.
/// Network round-trips (probeSize, rangeFetch, fullFetch) require
/// a real HTTP server + actual NWInterfaces; tested at runtime
/// with the HLS pre-buffer integration.  These tests cover the
/// pure splitRange helper that's the core of the bonding strategy.
enum BondedFetcherTests {

    static func run() {
        TestHarness.suite("BondedFetcher.splitRange — invariants") {

            TestHarness.test("Single part returns the full range") {
                let r = BondedFetcher.splitRange(total: 1000, parts: 1)
                try expectEqual(r.count, 1)
                try expectEqual(r[0].start, 0)
                try expectEqual(r[0].end, 999)
            }

            TestHarness.test("Two parts split evenly with last covering remainder") {
                let r = BondedFetcher.splitRange(total: 1000, parts: 2)
                try expectEqual(r.count, 2)
                try expectEqual(r[0].start, 0)
                try expectEqual(r[0].end, 499)
                try expectEqual(r[1].start, 500)
                try expectEqual(r[1].end, 999)
            }

            TestHarness.test("Three parts on a non-divisible total") {
                // 1000 / 3 = 333.33 — ceil → 334 per chunk for first 2
                let r = BondedFetcher.splitRange(total: 1000, parts: 3)
                try expectEqual(r.count, 3)
                try expectEqual(r[0].start, 0)
                try expectEqual(r[0].end, 333)
                try expectEqual(r[1].start, 334)
                try expectEqual(r[1].end, 667)
                try expectEqual(r[2].start, 668)
                try expectEqual(r[2].end, 999)
            }

            TestHarness.test("Ranges are contiguous + cover full file") {
                for total in [Int64(10), 1000, 1_000_000, 5_800_134_656] {
                    for parts in [1, 2, 3, 4, 8] {
                        let r = BondedFetcher.splitRange(total: total, parts: parts)
                        try expect(r.count <= parts, "Got \(r.count)")
                        try expectEqual(r.first?.start, 0)
                        try expectEqual(r.last?.end, total - 1)
                        // Contiguous + no gap + no overlap.
                        for i in 1..<r.count {
                            try expectEqual(r[i].start, r[i - 1].end + 1,
                                "Gap between \(r[i - 1]) and \(r[i])")
                        }
                    }
                }
            }

            TestHarness.test("Zero parts returns empty") {
                let r = BondedFetcher.splitRange(total: 1000, parts: 0)
                try expect(r.isEmpty)
            }

            TestHarness.test("Tiny file with many parts — no over-shooting") {
                // 5 bytes split into 10 parts: only 5 ranges (one per byte)
                // emerges; we don't fabricate empty ranges.
                let r = BondedFetcher.splitRange(total: 5, parts: 10)
                try expect(r.count <= 10)
                try expect(r.allSatisfy { $0.start <= $0.end })
                try expectEqual(r.last?.end, 4)
            }

            TestHarness.test("Single byte file") {
                let r = BondedFetcher.splitRange(total: 1, parts: 4)
                try expect(r.count >= 1)
                try expectEqual(r[0].start, 0)
                try expectEqual(r[0].end, 0)
            }
        }
    }
}
