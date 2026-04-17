import AppIntents
import AppKit

/// Shortcuts.app / Siri integration.
///
/// Each intent composes a `splynek://` URL and opens it via
/// `NSWorkspace.shared.open`. That routes through the same scheme
/// handler the app delegate already implements, so there's a single
/// ingress path regardless of whether Splynek is already running.
///
/// Availability: `AppIntents` and `AppShortcutsProvider` are macOS 13+.

@available(macOS 13.0, *)
struct DownloadURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Download URL"
    static var description = IntentDescription(
        "Start a new multi-interface HTTP download in Splynek."
    )

    @Parameter(title: "URL")
    var urlString: String

    @Parameter(title: "SHA-256 (optional)",
               description: "Expected hex digest. The download fails on mismatch.")
    var sha256: String?

    @Parameter(title: "Start immediately",
               description: "If off, the URL is appended to the persistent queue.",
               default: true)
    var startImmediately: Bool

    func perform() async throws -> some IntentResult {
        let action = startImmediately ? "download" : "queue"
        var comps = URLComponents()
        comps.scheme = "splynek"
        comps.host = action
        var items = [URLQueryItem(name: "url", value: urlString)]
        if let s = sha256, !s.isEmpty {
            items.append(URLQueryItem(name: "sha256", value: s))
        }
        if startImmediately {
            items.append(URLQueryItem(name: "start", value: "1"))
        }
        comps.queryItems = items
        guard let url = comps.url else {
            throw $urlString.needsValueError("Provide a valid URL.")
        }
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}

@available(macOS 13.0, *)
struct QueueURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Add URL to Queue"
    static var description = IntentDescription(
        "Append a URL to Splynek's persistent queue without starting immediately."
    )

    @Parameter(title: "URL")
    var urlString: String

    @Parameter(title: "SHA-256 (optional)")
    var sha256: String?

    func perform() async throws -> some IntentResult {
        var comps = URLComponents()
        comps.scheme = "splynek"
        comps.host = "queue"
        var items = [URLQueryItem(name: "url", value: urlString)]
        if let s = sha256, !s.isEmpty {
            items.append(URLQueryItem(name: "sha256", value: s))
        }
        comps.queryItems = items
        guard let url = comps.url else {
            throw $urlString.needsValueError("Provide a valid URL.")
        }
        await MainActor.run { NSWorkspace.shared.open(url) }
        return .result()
    }
}

@available(macOS 13.0, *)
struct ParseMagnetIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Magnet Link in Splynek"
    static var description = IntentDescription(
        "Hand a magnet URI to Splynek for BEP 9 metadata fetch + download."
    )

    @Parameter(title: "Magnet URI")
    var magnet: String

    func perform() async throws -> some IntentResult {
        var comps = URLComponents()
        comps.scheme = "splynek"
        comps.host = "torrent"
        comps.queryItems = [URLQueryItem(name: "magnet", value: magnet)]
        guard let url = comps.url else {
            throw $magnet.needsValueError("Provide a valid magnet URI.")
        }
        await MainActor.run { NSWorkspace.shared.open(url) }
        return .result()
    }
}

@available(macOS 13.0, *)
struct GetDownloadProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Splynek Download Progress"
    static var description = IntentDescription(
        "Return a one-line summary of the app's current aggregate state."
    )
    /// We never want this to open the UI; it's a pure peek.
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary: String = await MainActor.run {
            guard let delegate = NSApp.delegate as? SplynekAppDelegate,
                  let vm = delegate.state?.vm else {
                return "Splynek is not running."
            }
            let running = vm.activeJobs.filter { $0.lifecycle == .running }
            let paused  = vm.activeJobs.filter { $0.lifecycle == .paused }.count
            let queued  = vm.queue.filter { $0.status == .pending }.count
            let seedingPeers = vm.torrentProgress.seeding?.connectedPeers ?? 0
            if running.isEmpty && paused == 0 && queued == 0 && seedingPeers == 0 {
                return "Idle."
            }
            var parts: [String] = []
            if !running.isEmpty {
                let pct = Int(vm.aggregateFraction * 100)
                let bps = Int64(vm.aggregateThroughputBps)
                parts.append("\(running.count) active (\(pct)%, \(formatBytes(bps))/s)")
            }
            if paused > 0  { parts.append("\(paused) paused") }
            if queued > 0  { parts.append("\(queued) queued") }
            if seedingPeers > 0 { parts.append("seeding to \(seedingPeers) peers") }
            return parts.joined(separator: "; ")
        }
        return .result(value: summary)
    }
}

@available(macOS 13.0, *)
struct CancelAllDownloadsIntent: AppIntent {
    static var title: LocalizedStringResource = "Cancel All Splynek Downloads"
    static var description = IntentDescription(
        "Abort every running Splynek download."
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary: String = await MainActor.run {
            guard let delegate = NSApp.delegate as? SplynekAppDelegate,
                  let vm = delegate.state?.vm else {
                return "Splynek is not running."
            }
            let before = vm.activeJobs.filter { $0.lifecycle == .running }.count
            vm.cancelAll()
            return "Cancelled \(before) downloads."
        }
        return .result(value: summary)
    }
}

@available(macOS 13.0, *)
struct PauseAllDownloadsIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause All Splynek Downloads"
    static var description = IntentDescription(
        "Pause every running download. Sidecars are retained so resume picks up where we left off."
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let summary: String = await MainActor.run {
            guard let delegate = NSApp.delegate as? SplynekAppDelegate,
                  let vm = delegate.state?.vm else {
                return "Splynek is not running."
            }
            let running = vm.activeJobs.filter { $0.lifecycle == .running }
            for job in running { vm.pauseJob(job) }
            return "Paused \(running.count) downloads."
        }
        return .result(value: summary)
    }
}

@available(macOS 13.0, *)
struct ListRecentHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "List Recent Splynek Downloads"
    static var description = IntentDescription(
        "Return a newline-separated list of the most recent completed downloads."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "How many",
               description: "Number of recent completions to return (default 10).",
               default: 10)
    var limit: Int

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let cap = max(1, min(500, limit))
        let summary: String = await MainActor.run {
            guard let delegate = NSApp.delegate as? SplynekAppDelegate,
                  let vm = delegate.state?.vm else {
                return "Splynek is not running."
            }
            if vm.history.isEmpty { return "No history yet." }
            return vm.history.suffix(cap).reversed()
                .map { "\($0.filename)  \(ByteCountFormatter.string(fromByteCount: $0.totalBytes, countStyle: .binary))" }
                .joined(separator: "\n")
        }
        return .result(value: summary)
    }
}

@available(macOS 13.0, *)
struct SplynekAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DownloadURLIntent(),
            phrases: [
                "Download with \(.applicationName)",
                "Start a \(.applicationName) download"
            ],
            shortTitle: "Download URL",
            systemImageName: "arrow.down.circle"
        )
        AppShortcut(
            intent: QueueURLIntent(),
            phrases: ["Queue in \(.applicationName)"],
            shortTitle: "Queue URL",
            systemImageName: "line.3.horizontal.decrease.circle"
        )
        AppShortcut(
            intent: ParseMagnetIntent(),
            phrases: ["Open magnet with \(.applicationName)"],
            shortTitle: "Open Magnet",
            systemImageName: "link.circle"
        )
        AppShortcut(
            intent: GetDownloadProgressIntent(),
            phrases: [
                "Get \(.applicationName) progress",
                "What's \(.applicationName) doing"
            ],
            shortTitle: "Get Progress",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: CancelAllDownloadsIntent(),
            phrases: ["Cancel all \(.applicationName) downloads"],
            shortTitle: "Cancel All",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: PauseAllDownloadsIntent(),
            phrases: ["Pause all \(.applicationName) downloads"],
            shortTitle: "Pause All",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: ListRecentHistoryIntent(),
            phrases: ["List \(.applicationName) history",
                      "Recent \(.applicationName) downloads"],
            shortTitle: "List History",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
