import Foundation
@testable import SplynekCore

/// v1.7: DiskUsageScanner sandbox-safety + ranking invariants.  Tests
/// build a real fixture tree under tmp so we exercise the actual
/// `FileManager.contentsOfDirectory` paths without mocking.
enum DiskUsageScannerTests {

    static func run() {
        TestHarness.suite("DiskUsageScanner") {

            TestHarness.test("Empty folder produces empty report") {
                let root = makeTemp()
                defer { try? FileManager.default.removeItem(at: root) }

                let report = DiskUsageScanner.scan(root)
                try expect(report.entries.isEmpty, "Empty dir → 0 entries")
                try expect(report.totalBytes == 0)
                try expect(report.truncatedByBudget == false)
            }

            TestHarness.test("Files are ranked by size (largest first)") {
                let root = makeTemp()
                defer { try? FileManager.default.removeItem(at: root) }
                writeFile(root.appendingPathComponent("small.bin"),  bytes: 100)
                writeFile(root.appendingPathComponent("big.bin"),    bytes: 10_000)
                writeFile(root.appendingPathComponent("middle.bin"), bytes: 1_000)

                let report = DiskUsageScanner.scan(root)
                try expect(report.entries.count == 3, "Found \(report.entries.count) entries")
                try expect(report.entries[0].path.lastPathComponent == "big.bin")
                try expect(report.entries[1].path.lastPathComponent == "middle.bin")
                try expect(report.entries[2].path.lastPathComponent == "small.bin")
            }

            TestHarness.test("Symlinks are not followed (no infinite loop)") {
                let root = makeTemp()
                defer { try? FileManager.default.removeItem(at: root) }

                let target = root.appendingPathComponent("real")
                try? FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                writeFile(target.appendingPathComponent("file.bin"), bytes: 500)

                // Create a symlink loop: link → root.
                let link = root.appendingPathComponent("loop")
                try? FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)

                let report = DiskUsageScanner.scan(root, budget: DiskUsageScanner.Budget(maxDepth: 5, maxNodes: 100, topN: 25))
                // If the scanner followed the symlink it would explode.  Test passes
                // if we get a finite, reasonable result.
                try expect(report.nodesVisited < 100, "Visited too many nodes — symlink followed? \(report.nodesVisited)")
            }

            TestHarness.test("Budget truncates without crashing") {
                let root = makeTemp()
                defer { try? FileManager.default.removeItem(at: root) }
                for i in 0..<20 {
                    writeFile(root.appendingPathComponent("f\(i).bin"), bytes: 100)
                }
                let tightBudget = DiskUsageScanner.Budget(maxDepth: 3, maxNodes: 5, topN: 25)
                let report = DiskUsageScanner.scan(root, budget: tightBudget)
                try expect(report.truncatedByBudget == true, "Should signal truncation")
                try expect(report.entries.count <= 5, "Should not exceed budget")
            }

            TestHarness.test("Directory size aggregates child file sizes") {
                let root = makeTemp()
                defer { try? FileManager.default.removeItem(at: root) }

                let sub = root.appendingPathComponent("sub")
                try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
                writeFile(sub.appendingPathComponent("a.bin"), bytes: 1_000)
                writeFile(sub.appendingPathComponent("b.bin"), bytes: 2_000)
                writeFile(root.appendingPathComponent("loose.bin"), bytes: 500)

                let report = DiskUsageScanner.scan(root)
                let subEntry = report.entries.first { $0.path.lastPathComponent == "sub" }
                try expect(subEntry != nil, "sub/ should be in the report")
                if let s = subEntry {
                    try expect(s.bytes == 3_000, "Aggregated size should be 1000+2000=3000, got \(s.bytes)")
                    try expect(s.kind == .directory)
                }
            }
        }
    }

    // MARK: - Fixtures

    static func makeTemp() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("splynek-disk-tests")
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func writeFile(_ url: URL, bytes: Int) {
        let data = Data(repeating: 0xAB, count: bytes)
        try? data.write(to: url)
    }
}
