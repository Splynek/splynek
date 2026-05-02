import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// DiskUsageScanner reads file metadata only (size + URL) via
// FileManager.contentsOfDirectory + URLResourceValues.  No content is
// read, no code is executed, no shell-out occurs.  All paths the
// scanner walks are user-supplied (typically via NSOpenPanel) so the
// MAS sandbox naturally bounds reach: Splynek can only enumerate
// what the user explicitly granted via the user-selected.read-write
// entitlement.
// =====================================================================

/// v1.7: top-N space-takers under a user-picked folder, surfaced via
/// the Concierge assistant ("what's eating my disk?").  Designed to
/// run in seconds on a typical Downloads folder; for whole-Mac scans,
/// we point users at the system Storage Management pane instead
/// (Apple's tools are better suited for that).
///
/// The scanner walks the tree breadth-first up to a depth + node
/// budget so we cap worst-case work — runs in O(N) on the file count
/// up to the budget, then stops and returns what it has.  Callers can
/// raise the budget for power-user scans.
///
/// Sandbox note: this type does NOT enumerate
/// `~/Library/Application Support`, `~/Library/Caches`, or any other
/// container that would require special entitlements.  It enumerates
/// whatever URL the caller hands it, which under MAS sandboxing means
/// "whatever the user picked in the open-panel."
enum DiskUsageScanner {

    /// One row in the report.  `path` is absolute; `bytes` is the
    /// recursive size summed at scan time; `kind` distinguishes
    /// directories from files for UI display.
    struct Entry: Hashable, Sendable {
        let path: URL
        let bytes: Int64
        let kind: Kind
        let modified: Date?

        enum Kind: String, Hashable, Sendable {
            case file, directory
        }
    }

    /// Tunables.  Defaults are tuned for "scan my Downloads folder"
    /// in a few hundred milliseconds.
    struct Budget: Sendable {
        let maxDepth: Int
        let maxNodes: Int
        let topN: Int

        init(maxDepth: Int = 3, maxNodes: Int = 20_000, topN: Int = 25) {
            self.maxDepth = maxDepth
            self.maxNodes = maxNodes
            self.topN = topN
        }

        /// Aggressive scan for the "find me hogs across all of /Users/me"
        /// case.  Expect 1-3 seconds; results may be partial if budget hits.
        static let aggressive = Budget(maxDepth: 5, maxNodes: 100_000, topN: 50)
    }

    /// Result envelope — gives the caller a clean signal when the
    /// scan was capped by the budget so the UI can prompt for a
    /// deeper run.
    struct Report: Sendable {
        let root: URL
        let entries: [Entry]
        let totalBytes: Int64
        let nodesVisited: Int
        let truncatedByBudget: Bool
    }

    /// Scan `root` and return the top-N space-takers (files OR
    /// folders) ranked by recursive byte size.
    ///
    /// Symlinks are not followed (avoids unbounded loops and avoids
    /// double-counting).  Hidden files (dotfiles) are included by
    /// default — power users want to see `.Trash` and `.cache`
    /// hogs.
    static func scan(_ root: URL, budget: Budget = Budget()) -> Report {
        var sizeByPath: [URL: Int64] = [:]
        var modifiedByPath: [URL: Date] = [:]
        var kindByPath: [URL: Entry.Kind] = [:]
        var visited = 0
        var truncated = false

        // BFS via a stack of (url, depth) pairs.  Could be DFS via
        // recursion but BFS keeps the budget logic simpler.
        var stack: [(URL, Int)] = [(root, 0)]

        while let (current, depth) = stack.popLast() {
            if visited >= budget.maxNodes {
                truncated = true
                break
            }
            visited += 1

            // Read current node's size + kind in a single shot.
            let resourceKeys: Set<URLResourceKey> = [
                .isDirectoryKey, .fileSizeKey, .totalFileSizeKey,
                .totalFileAllocatedSizeKey, .contentModificationDateKey,
                .isSymbolicLinkKey,
            ]
            guard let values = try? current.resourceValues(forKeys: resourceKeys) else {
                continue
            }
            if values.isSymbolicLink == true { continue }

            modifiedByPath[current] = values.contentModificationDate

            if values.isDirectory == true {
                kindByPath[current] = .directory
                // Enumerate one level — children push to stack with depth+1.
                if depth < budget.maxDepth {
                    if let kids = try? FileManager.default.contentsOfDirectory(
                        at: current,
                        includingPropertiesForKeys: Array(resourceKeys),
                        options: []
                    ) {
                        for k in kids { stack.append((k, depth + 1)) }
                    }
                }
                // Directory size is computed bottom-up by summing child
                // sizes — done in the second pass below.
            } else {
                kindByPath[current] = .file
                let size = Int64(values.totalFileSize ?? values.fileSize ?? 0)
                sizeByPath[current] = size
            }
        }

        // Second pass: roll up directory sizes.  Sort all known paths
        // by depth (deepest first) so we can sum into the parent.
        let sortedByDepth = kindByPath.keys.sorted {
            $0.pathComponents.count > $1.pathComponents.count
        }
        for path in sortedByDepth {
            if kindByPath[path] == .directory {
                // A directory's size = sum of immediate children we visited.
                var sum: Int64 = 0
                for kid in kindByPath.keys {
                    guard kid != path else { continue }
                    if kid.deletingLastPathComponent() == path {
                        sum += sizeByPath[kid] ?? 0
                    }
                }
                sizeByPath[path] = sum
            }
        }

        // Pick the top N entries by size.  Exclude the root itself
        // from the result (the user already knows it's the root).
        let entries: [Entry] = sizeByPath
            .filter { $0.key != root }
            .map {
                Entry(
                    path: $0.key,
                    bytes: $0.value,
                    kind: kindByPath[$0.key] ?? .file,
                    modified: modifiedByPath[$0.key]
                )
            }
            .sorted { $0.bytes > $1.bytes }
            .prefix(budget.topN)
            .map { $0 }

        let total = entries.reduce(0) { $0 + $1.bytes }

        return Report(
            root: root,
            entries: entries,
            totalBytes: total,
            nodesVisited: visited,
            truncatedByBudget: truncated
        )
    }
}
