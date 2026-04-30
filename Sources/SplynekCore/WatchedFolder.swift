import Foundation

/// Poll-based ingestion of dropped files from a watched directory.
///
/// HANDOFF picked polling (5 s Timer) over FSEvents for this first pass
/// because: (a) it's simpler — no CF callback bridging or string-path
/// coalescing logic; (b) it dodges FSEvents' quirks around unplugged
/// volumes and sandbox boundaries; (c) 5 seconds is well below user
/// expectation for "Splynek noticed my drop." FSEvents can replace the
/// Timer later without touching the scan logic.
///
/// The scanner moves each handled file into a `processed/` subdirectory
/// so the next tick doesn't re-ingest the same URL list. `processed/`
/// is created on first enable and remains even after disable so users
/// can trace what the watcher picked up.
///
/// Files modified in the last two seconds are skipped for this tick —
/// partial writes during a drag-drop land here often enough that the
/// naive "grab everything new" loop trips over half-flushed bytes.
@MainActor
final class WatchedFolder {

    /// Supported file types. Anything else is left in place (a future
    /// user might drop a PDF into the folder by mistake; we shouldn't
    /// move it to `processed/` and lose it).
    static let handledExtensions: Set<String> = ["txt", "torrent", "metalink", "meta4"]

    /// Minimum age a file must have before we touch it, to let the OS
    /// finish writing it. 2 s is plenty for a finder drop; large
    /// `.torrent` or `.txt` files arrive atomically anyway.
    static let minimumFileAgeSeconds: TimeInterval = 2

    /// How often the scan runs while the watcher is enabled.
    static let scanIntervalSeconds: TimeInterval = 5

    /// Current folder being watched. `setFolder(_:)` swaps it.
    private(set) var folder: URL

    /// Called on the main actor for every handled file, *before* the
    /// move to `processed/` so the handler sees the original path (it
    /// gets copied to the handler's own state anyway).
    private let onFile: (URL) -> Void

    private var timer: Timer?
    private let fm = FileManager.default

    init(folder: URL, onFile: @escaping (URL) -> Void) {
        self.folder = folder
        self.onFile = onFile
    }

    var isRunning: Bool { timer != nil }

    // MARK: Control

    /// Create the folder (if missing), kick off the first scan, then
    /// install a repeating Timer. Safe to call repeatedly — `stop` is
    /// invoked internally before re-installing.
    /// v1.5.6+: reentrancy guard — if a previous tick's scan is still
    /// in flight (slow disk, network volume, big folder), we drop this
    /// tick rather than stacking another scan on top of it.  Without
    /// this guard, a folder containing 10k files on a network mount
    /// could pile up dozens of overlapping scans on the main actor.
    private var scanInFlight: Bool = false

    func start() {
        stop()
        ensureDirectories()
        // Immediate first scan so users don't wait 5 seconds after
        // enabling for nothing to happen.
        scanGuarded()
        let t = Timer(timeInterval: Self.scanIntervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scanGuarded() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Wrap `scan()` with a reentrancy guard.  Drops the tick (with a
    /// `Log.scan.notice`) if a previous tick is still running.
    private func scanGuarded() {
        guard !scanInFlight else {
            Log.scan.notice("watched-folder scan tick dropped (previous still in flight)")
            return
        }
        scanInFlight = true
        defer { scanInFlight = false }
        scan()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setFolder(_ url: URL) {
        folder = url
        if isRunning { start() }
    }

    // MARK: Scan

    private func ensureDirectories() {
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try? fm.createDirectory(at: processedURL, withIntermediateDirectories: true)
    }

    private var processedURL: URL {
        folder.appendingPathComponent("processed", isDirectory: true)
    }

    private func scan() {
        ensureDirectories()
        guard let entries = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }

        let now = Date()
        for item in entries {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            if isDir.boolValue { continue }   // skip processed/ + anything else

            let ext = item.pathExtension.lowercased()
            guard Self.handledExtensions.contains(ext) else { continue }

            // Skip files that appear to be mid-write.
            if let attrs = try? fm.attributesOfItem(atPath: item.path),
               let modDate = attrs[.modificationDate] as? Date,
               now.timeIntervalSince(modDate) < Self.minimumFileAgeSeconds {
                continue
            }

            onFile(item)
            moveToProcessed(item)
        }
    }

    private func moveToProcessed(_ url: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        let dest = processedURL.appendingPathComponent(
            "\(stamp)_\(url.lastPathComponent)"
        )
        try? fm.moveItem(at: url, to: dest)
    }
}

// MARK: - Pure parser

/// Parses a dropped `.txt` into a list of HTTP(S) or magnet URLs.
/// Blank lines and `#`-prefixed comment lines are skipped. Exposed as
/// a static function so tests don't have to touch the filesystem.
enum WatchedFolderParser {

    static func parseURLs(fromText text: String) -> [String] {
        var out: [String] = []
        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") { continue }      // comment
            if line.hasPrefix("magnet:") {
                out.append(line)
                continue
            }
            if let url = URL(string: line),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                out.append(line)
            }
        }
        return out
    }
}
