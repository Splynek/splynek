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

// MARK: - v1.6: Catalog-aware intents

/// Look up an installed app's Sovereignty profile via Shortcuts / Siri.
///
/// Returns a single text summary the user can route to a notification,
/// HomeKit card, or further-process step.  Hits the same catalog as
/// the in-app Sovereignty tab; no network access.
@available(macOS 13.0, *)
struct LookupSovereigntyIntent: AppIntent {
    static var title: LocalizedStringResource = "Look up Splynek Sovereignty"
    static var description = IntentDescription(
        "Look up an app in the Splynek Sovereignty catalog by bundle ID or display name. Returns target-origin and EU/OSS alternatives."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "App", description: "Bundle ID (e.g. com.spotify.client) or display name (e.g. Spotify).")
    var query: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { throw $query.needsValueError("Enter an app name or bundle ID.") }
        guard let hit = MCPBridgeBuilder.lookupSovereignty(query: q) else {
            return .result(value: "No Sovereignty entry for `\(q)`.")
        }
        var lines = [
            "\(hit.displayName) (\(hit.bundleID))",
            "Controlled from: \(hit.targetOrigin)",
            "",
            "Alternatives:",
        ]
        for alt in hit.alternatives {
            lines.append("• \(alt.name) [\(alt.origin)] — \(alt.note)")
        }
        return .result(value: lines.joined(separator: "\n"))
    }
}

/// Look up an app's Trust score (0–100) via Shortcuts / Siri.
@available(macOS 13.0, *)
struct LookupTrustIntent: AppIntent {
    static var title: LocalizedStringResource = "Look up Splynek Trust score"
    static var description = IntentDescription(
        "Look up an app in the Splynek Trust catalog (public-record audit). Returns 0–100 score, level, and concerns with primary-source citations."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "App", description: "Bundle ID or display name.")
    var query: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { throw $query.needsValueError("Enter an app name or bundle ID.") }
        // Pull current weights from the running VM so the score
        // matches what the user sees in the in-app Trust tab.
        let weights: TrustScorer.Weights = await MainActor.run {
            guard let delegate = NSApp.delegate as? SplynekAppDelegate,
                  let vm = delegate.state?.vm
            else { return TrustScorer.Weights.default }
            return vm.trustWeights
        }
        guard let hit = MCPBridgeBuilder.lookupTrust(query: q, weights: weights) else {
            return .result(value: "No Trust catalog entry for `\(q)`.")
        }
        var lines = [
            "\(hit.displayName) — \(hit.score)/100 \(hit.level)",
            "Last reviewed: \(hit.lastReviewed)",
            "Concerns (\(hit.concernCount)):",
        ]
        for c in hit.concerns {
            lines.append("• [\(c.severity.uppercased()) \(c.axis)] \(c.summary)")
        }
        return .result(value: lines.joined(separator: "\n"))
    }
}

/// Run a one-shot Sovereignty scan from Shortcuts.  Returns the
/// summary counts only — for per-app detail the user chains
/// `LookupSovereigntyIntent`.
@available(macOS 13.0, *)
struct RunSovereigntyScanIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Splynek Sovereignty scan"
    static var description = IntentDescription(
        "Enumerate installed apps and count how many have Sovereignty catalog entries. Local; no network access."
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let s = MCPBridgeBuilder.runSovereigntyScan()
        return .result(value:
            "Scanned \(s.appsScanned) installed apps; \(s.entriesMatched) match Sovereignty catalog entries."
        )
    }
}

// =====================================================================
// v1.7 — Concierge-as-Mac-Assistant intents
// =====================================================================
// These wrap the new public-repo types (HistorySearch, DiskUsageScanner,
// PDFSummarizer) so Shortcuts can drive them too — the same surface
// the Pro Concierge dispatches to internally.  All three are
// **read-only**: they answer questions about the user's own data,
// never write or download anything.

@available(macOS 13.0, *)
struct SearchDownloadHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Search download history"
    static var description = IntentDescription(
        "Search Splynek's download history with a ranked free-text query. Returns top matches."
    )

    @Parameter(title: "Query",
               description: "Free-text query — filename, host, or any keyword.")
    var query: String

    @Parameter(title: "Limit",
               description: "Maximum number of results to return.",
               default: 5)
    var limit: Int

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let matches = HistorySearch.search(query, limit: max(1, min(50, limit)))
        if matches.isEmpty {
            return .result(value: "No matches in download history for \"\(query)\".")
        }
        let lines: [String] = matches.map { m in
            let host = URL(string: m.entry.url)?.host ?? "—"
            let f = ByteCountFormatter.string(
                fromByteCount: m.entry.totalBytes, countStyle: .file
            )
            let when = ISO8601DateFormatter().string(from: m.entry.finishedAt)
            return "\(m.entry.filename) · \(host) · \(f) · \(when)"
        }
        return .result(value: lines.joined(separator: "\n"))
    }
}

@available(macOS 13.0, *)
struct DiskUsageReportIntent: AppIntent {
    static var title: LocalizedStringResource = "Disk usage report"
    static var description = IntentDescription(
        "Scan a folder you pick and report the top 25 space-takers underneath it. Sandbox-safe — Splynek only sees what you grant."
    )

    @Parameter(title: "Folder",
               description: "Folder to scan. Splynek can only enumerate folders the user has selected.")
    var folder: IntentFile

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let url = folder.fileURL else {
            return .result(value: "Couldn't resolve the picked folder.")
        }
        let report = DiskUsageScanner.scan(url)
        if report.entries.isEmpty {
            return .result(value: "Empty folder, or no readable contents.")
        }
        let header = "Top \(report.entries.count) under \(url.lastPathComponent) "
            + "(\(ByteCountFormatter.string(fromByteCount: report.totalBytes, countStyle: .file)) total)"
        let lines = report.entries.prefix(25).map { e -> String in
            let f = ByteCountFormatter.string(fromByteCount: e.bytes, countStyle: .file)
            let kind: String = (e.kind == DiskUsageScanner.Entry.Kind.directory) ? "[dir]" : "[file]"
            return "\(kind) \(e.path.lastPathComponent) — \(f)"
        }
        return .result(value: ([header, ""] + lines).joined(separator: "\n"))
    }
}

@available(macOS 13.0, *)
struct SummarizeFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Summarize file (text only)"
    static var description = IntentDescription(
        "Extract text from a PDF you pick. The Pro Concierge feeds this to the local LLM; without Pro, this returns the raw extracted text capped at 8000 characters."
    )

    @Parameter(title: "PDF",
               description: "A PDF file you've picked.")
    var file: IntentFile

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let url = file.fileURL else {
            return .result(value: "Couldn't resolve the picked file.")
        }
        do {
            let extract = try PDFSummarizer.extract(url)
            let header = "PDF: \(url.lastPathComponent) · \(extract.pageCount) page(s)"
                + (extract.truncated ? " (truncated to 8000 chars)" : "")
            return .result(value: "\(header)\n\n\(extract.text)")
        } catch {
            return .result(value: "Failed to read PDF: \(error.localizedDescription)")
        }
    }
}

@available(macOS 13.0, *)
struct SplynekAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // v1.6.2: AppShortcut phrases only support `\(\.$param)`
        // interpolation when the param type is `AppEntity` or
        // `AppEnum`.  Our query params are `String` (so the user can
        // enter any bundle ID or display name) — wrapping each in an
        // AppEntity would be overkill.  So phrases are static; the
        // user types the query in the Shortcuts editor or after Siri
        // says "what's the query?".
        AppShortcut(
            intent: LookupSovereigntyIntent(),
            phrases: [
                "Look up \(.applicationName) sovereignty",
                "Where is this app controlled from in \(.applicationName)",
            ],
            shortTitle: "Lookup Sovereignty",
            systemImageName: "shield.lefthalf.filled"
        )
        AppShortcut(
            intent: LookupTrustIntent(),
            phrases: [
                "Get \(.applicationName) trust score",
                "Audit an app with \(.applicationName)",
            ],
            shortTitle: "Lookup Trust Score",
            systemImageName: "checkmark.seal"
        )
        AppShortcut(
            intent: RunSovereigntyScanIntent(),
            phrases: [
                "Scan my apps with \(.applicationName)",
                "Audit my Mac with \(.applicationName)",
            ],
            shortTitle: "Run Sovereignty Scan",
            systemImageName: "magnifyingglass.circle"
        )
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
        // v1.7: Concierge-as-Mac-Assistant intents
        AppShortcut(
            intent: SearchDownloadHistoryIntent(),
            phrases: ["Search \(.applicationName) history"],
            shortTitle: "Search History",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: DiskUsageReportIntent(),
            phrases: ["\(.applicationName) disk usage report"],
            shortTitle: "Disk Usage",
            systemImageName: "internaldrive"
        )
        AppShortcut(
            intent: SummarizeFileIntent(),
            phrases: ["Summarize file with \(.applicationName)"],
            shortTitle: "Summarize File",
            systemImageName: "doc.text.magnifyingglass"
        )
    }
}
