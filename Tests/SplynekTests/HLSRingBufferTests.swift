import Foundation
@testable import SplynekCore

/// Strategy Bet S5 — HLSRingBuffer invariants.  Pure data-structure
/// tests; no network, no actor-isolation gymnastics.
enum HLSRingBufferTests {

    static func run() {
        TestHarness.suite("HLSRingBuffer — basic insertion + lookup") {

            TestHarness.test("Empty buffer reports zero") {
                let buf = HLSRingBuffer()
                try expectEqual(buf.count, 0)
                try expectEqual(buf.bytesHeld, 0)
                try expect(!buf.contains(URL(string: "https://x.com/seg.ts")!))
            }

            TestHarness.test("Insert then get returns the bytes") {
                var buf = HLSRingBuffer()
                let url = URL(string: "https://x.com/seg.ts")!
                let data = Data(repeating: 0xAB, count: 1024)
                buf.insert(url: url, data: data)
                try expectEqual(buf.count, 1)
                try expectEqual(buf.bytesHeld, 1024)
                try expect(buf.contains(url))
                let got = buf.get(url)
                try expectEqual(got, data)
            }

            TestHarness.test("Re-insert with same URL replaces") {
                var buf = HLSRingBuffer()
                let url = URL(string: "https://x.com/seg.ts")!
                buf.insert(url: url, data: Data(repeating: 0xAA, count: 100))
                buf.insert(url: url, data: Data(repeating: 0xBB, count: 200))
                try expectEqual(buf.count, 1)
                try expectEqual(buf.bytesHeld, 200)
                let got = buf.get(url)
                try expectEqual(got?.count, 200)
                try expectEqual(got?.first, 0xBB)
            }
        }

        TestHarness.suite("HLSRingBuffer — LRU eviction at capacity") {

            TestHarness.test("Eviction kicks in once capacity exceeded") {
                // Capacity = 3 KiB; insert four 1 KiB segments → first
                // one (oldest) gets evicted.
                var buf = HLSRingBuffer(capacity: 3 * 1024)
                let urls = (0..<4).map { URL(string: "https://x.com/seg\($0).ts")! }
                for u in urls {
                    buf.insert(url: u, data: Data(repeating: 0x00, count: 1024))
                }
                try expectEqual(buf.count, 3, "Should evict oldest")
                try expect(!buf.contains(urls[0]), "First inserted should be evicted")
                try expect(buf.contains(urls[3]), "Latest insert should be present")
                try expectEqual(buf.bytesHeld, 3 * 1024)
            }

            TestHarness.test("get() bumps LRU — recent gets survive eviction") {
                var buf = HLSRingBuffer(capacity: 3 * 1024)
                let urls = (0..<3).map { URL(string: "https://x.com/seg\($0).ts")! }
                for u in urls {
                    buf.insert(url: u, data: Data(repeating: 0x00, count: 1024))
                }
                // Touch URL 0 — should bump it to the tail.
                _ = buf.get(urls[0])
                // Insert a new entry — eviction should drop URL 1
                // (oldest after the touch), NOT URL 0.
                buf.insert(url: URL(string: "https://x.com/seg-new.ts")!,
                           data: Data(repeating: 0x00, count: 1024))
                try expect(buf.contains(urls[0]), "Touched URL should survive")
                try expect(!buf.contains(urls[1]), "Untouched oldest should evict")
            }

            TestHarness.test("Single oversized segment fits + later evicts itself") {
                var buf = HLSRingBuffer(capacity: 1024)
                let url = URL(string: "https://x.com/big.ts")!
                let data = Data(repeating: 0xFF, count: 4096)  // 4× capacity
                buf.insert(url: url, data: data)
                // Even though it exceeds capacity, the buffer holds it
                // (otherwise we'd never serve oversized segments at all).
                try expectEqual(buf.count, 1)
                try expect(buf.contains(url))
                // But adding a second item should evict the oversized one.
                buf.insert(url: URL(string: "https://x.com/small.ts")!,
                           data: Data(repeating: 0x01, count: 100))
                try expect(!buf.contains(url), "Oversized should evict")
            }
        }

        TestHarness.suite("HLSRingBuffer — clear") {

            TestHarness.test("Clear empties everything") {
                var buf = HLSRingBuffer()
                buf.insert(url: URL(string: "https://x.com/seg0.ts")!,
                           data: Data(count: 100))
                buf.insert(url: URL(string: "https://x.com/seg1.ts")!,
                           data: Data(count: 200))
                buf.clear()
                try expectEqual(buf.count, 0)
                try expectEqual(buf.bytesHeld, 0)
                try expect(buf.snapshotURLs.isEmpty)
            }
        }

        TestHarness.suite("HLSRingBuffer — diagnostics") {

            TestHarness.test("snapshotURLs returns LRU order") {
                var buf = HLSRingBuffer()
                let urls = (0..<3).map { URL(string: "https://x.com/seg\($0).ts")! }
                for u in urls {
                    buf.insert(url: u, data: Data(count: 100))
                }
                // Touch index 0 — moves it to tail.
                _ = buf.get(urls[0])
                let snapshot = buf.snapshotURLs
                try expectEqual(snapshot.count, 3)
                // After touching URL 0, order should be: 1, 2, 0 (tail = most recently used).
                try expectEqual(snapshot[0], urls[1])
                try expectEqual(snapshot[1], urls[2])
                try expectEqual(snapshot[2], urls[0])
            }
        }
    }
}
