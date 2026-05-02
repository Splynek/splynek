import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// `ConciergeBridge` is the contract between the Pro-tier LLM dispatcher
// (in splynek-pro/AIConcierge.swift / ConciergeMacAssistant.swift) and
// the public-tier handlers (HistorySearch, DiskUsageScanner,
// PDFSummarizer, the ViewModel, the catalogs).
//
// Why this exists: the Pro dispatcher decodes an LLM-generated
// `ConciergeInvocation` and needs to invoke ONE of the 8 fixed tools
// in `ConciergeToolRegistry`.  The bridge here exposes a SINGLE
// `dispatch(invocation:)` entry point that fans out to the right
// handler.  The Pro side never sees SwiftUI types, never embeds tool
// logic — it just decodes JSON and calls `bridge.dispatch(...)`.
//
// 2.5.2 mapping: every code path the bridge can run is compiled into
// the .app at build time.  The LLM-supplied `tool` name is matched
// against the compile-time-defined `ConciergeToolRegistry.allTools`
// array; an unknown tool ID returns `.error`, never executes
// arbitrary code.
// =====================================================================

/// v1.7: result of a single Concierge tool invocation.  Renders as a
/// chat card in the Concierge view.  All cases carry typed,
/// `Sendable` payloads so the result can hop actors cleanly.
enum ConciergeCard: Sendable {
    /// Plain text answer — used by tools that return a free-form
    /// digest (`recent_activity`) or by the dispatcher when none of
    /// the structured cards fit.
    case text(String)

    /// "Here's the URL I think you want — click Download to start."
    /// The user clicks Download in the chat card; the public-repo
    /// download engine takes over from there.
    case downloadOffer(url: URL, filename: String?, rationale: String)

    /// Top history matches for `search_history`.  The view renders
    /// each as a row with filename + host + size + age.
    case historyMatches([HistorySearch.Match])

    /// Disk-usage report for `disk_usage`.  The view renders the
    /// top 25 entries as a sortable table.
    case diskReport(DiskUsageScanner.Report)

    /// Bare-bones list of installed apps for `installed_apps`.
    /// Pairs `(displayName, bundleID?)` so the view can deep-link
    /// to Sovereignty/Trust details.
    case appList([(displayName: String, bundleID: String?)])

    /// Sovereignty report — for each scanned app that has an
    /// EU/OSS alternative in the catalog, one `Hit`.  Ranked by
    /// catalog confidence; capped at 5.
    case sovereigntyReport([SovereigntyHit])

    /// Trust report — for each scanned app the catalog has a score
    /// for, one `Hit`.  Ranked by severity; capped at 5.
    case trustReport([TrustHit])

    /// PDF summary — `summary` is the one-line description, `bullets`
    /// are the 3 main claims.  Rendered as a blockquote with a
    /// footer showing the source filename + page count.
    case pdfSummary(summary: String, bullets: [String], source: URL)

    /// Recoverable failure — the tool ran but didn't have enough
    /// information to answer.  Shown as a muted card with the
    /// reason; the user can retry with a different prompt.
    case error(String)

    struct SovereigntyHit: Hashable, Sendable {
        let targetName: String
        let targetBundleID: String
        let alternativeName: String
        let alternativeHomepage: URL
        let note: String
        let canInstall: Bool
    }

    struct TrustHit: Hashable, Sendable {
        let appName: String
        let bundleID: String
        let score: Int           // 0…100
        let level: String        // "Low" / "Moderate" / "High" / "Severe"
        let summary: String      // first concern's one-line summary
    }
}

/// One round-trip through the Concierge.  The bridge returns this
/// envelope, which the view renders as a chat card.  `card` is the
/// payload; `toolID` is the tool the LLM picked (for telemetry / "why
/// did you do that?" tooltips); `latencyMs` is for UI throbber tuning.
struct ConciergeResult: Sendable {
    let toolID: String
    let card: ConciergeCard
    let latencyMs: Int
}

/// Bridge between an LLM-generated `ConciergeInvocation` and the
/// concrete handlers in the public repo.  The Pro dispatcher
/// constructs a `ConciergeBridge` (typically `LiveConciergeBridge`
/// below, optionally with custom user-facing folders / files
/// already chosen via NSOpenPanel by the UI) and calls
/// `dispatch(_:)` for each LLM turn.
///
/// `dispatch` is `async` because some tools (PDF summary, disk scan)
/// can take measurable time on large inputs.  Returns a `Result` so
/// errors don't kill the chat session — they render as an error card
/// instead.
protocol ConciergeBridge: Sendable {
    func dispatch(_ invocation: ConciergeInvocation) async -> ConciergeResult
}

// =====================================================================
// LiveConciergeBridge — public-repo-only implementation
// =====================================================================

/// The default bridge: dispatches all 8 ConciergeToolRegistry tools
/// using the public-repo types only.  No SwiftUI dependency, no
/// SplynekViewModel dependency — that means it's safe to instantiate
/// from tests, from the MCP server, or from the Pro Concierge
/// dispatcher uniformly.
///
/// Tools that need user-picked URLs (`disk_usage`, `summarize_pdf`)
/// take those URLs as instance fields populated by the UI BEFORE the
/// invocation is dispatched.  The dispatcher returns an error card
/// if the field is nil — the UI is responsible for prompting first.
struct LiveConciergeBridge: ConciergeBridge {
    /// User-picked folder for `disk_usage`.  The UI prompts via
    /// NSOpenPanel and sets this field before calling `dispatch`
    /// for that tool.  Nil → error card.
    var pickedFolder: URL?

    /// User-picked PDF for `summarize_pdf`.  Same UI prompt pattern.
    var pickedPDF: URL?

    /// Optional history snapshot — tests inject deterministic data;
    /// production omits it and we read DownloadHistory.load() live.
    var historyFixture: [HistoryEntry]?

    /// Optional installed-apps snapshot — same fixture pattern.
    /// `(displayName, bundleID)` pairs.  Production reads
    /// `SovereigntyScanner.scan()` live.
    var installedAppsFixture: [(String, String)]?

    init(
        pickedFolder: URL? = nil,
        pickedPDF: URL? = nil,
        historyFixture: [HistoryEntry]? = nil,
        installedAppsFixture: [(String, String)]? = nil
    ) {
        self.pickedFolder = pickedFolder
        self.pickedPDF = pickedPDF
        self.historyFixture = historyFixture
        self.installedAppsFixture = installedAppsFixture
    }

    func dispatch(_ invocation: ConciergeInvocation) async -> ConciergeResult {
        let start = Date()
        let card = await dispatchCard(invocation)
        let latencyMs = Int(Date().timeIntervalSince(start) * 1000)
        return ConciergeResult(
            toolID: invocation.tool,
            card: card,
            latencyMs: latencyMs
        )
    }

    private func dispatchCard(_ invocation: ConciergeInvocation) async -> ConciergeCard {
        // Validate the tool ID against the compile-time registry.
        guard ConciergeToolRegistry.tool(withID: invocation.tool) != nil else {
            return .error("Unknown tool: \(invocation.tool).  This shouldn't happen — please report.")
        }

        switch invocation.tool {
        case ConciergeToolRegistry.searchHistory.id:
            return handleSearchHistory(args: invocation.args)
        case ConciergeToolRegistry.diskUsage.id:
            return handleDiskUsage()
        case ConciergeToolRegistry.summarizePDF.id:
            return handleSummarizePDF()
        case ConciergeToolRegistry.installedApps.id:
            return handleInstalledApps()
        case ConciergeToolRegistry.sovereigntyReport.id:
            return handleSovereigntyReport()
        case ConciergeToolRegistry.trustReport.id:
            return handleTrustReport()
        case ConciergeToolRegistry.recentActivity.id:
            return handleRecentActivity()
        case ConciergeToolRegistry.downloadByGoal.id:
            // The download-by-goal flow lives in the Pro repo — the
            // bridge can't resolve it on its own.  Return a hint so
            // the Pro dispatcher knows to take over.
            return .text("Download-by-goal must be dispatched by the Pro Concierge.")
        default:
            return .error("Tool \(invocation.tool) has no handler in the bridge yet.")
        }
    }

    // MARK: - Tool handlers

    private func handleSearchHistory(args: ConciergeJSON) -> ConciergeCard {
        guard let query = args.string("query"), !query.isEmpty else {
            return .error("search_history requires a non-empty 'query' argument.")
        }
        let entries = historyFixture ?? DownloadHistory.load()
        let matches = HistorySearch.search(query, in: entries, limit: 5)
        if matches.isEmpty {
            return .text("No matches in download history for \"\(query)\".")
        }
        return .historyMatches(matches)
    }

    private func handleDiskUsage() -> ConciergeCard {
        guard let folder = pickedFolder else {
            return .error("Pick a folder first — the Concierge needs explicit permission to read your filesystem.")
        }
        let report = DiskUsageScanner.scan(folder)
        return .diskReport(report)
    }

    private func handleSummarizePDF() -> ConciergeCard {
        guard let pdf = pickedPDF else {
            return .error("Pick a PDF first.")
        }
        do {
            let extract = try PDFSummarizer.extract(pdf)
            // The actual LLM call (extract → summary, bullets) is the
            // Pro dispatcher's job.  Here we return a placeholder card
            // that the Pro side can replace with the real summary.
            return .pdfSummary(
                summary: "(Pro Concierge will summarize this — \(extract.pageCount) page(s), \(extract.text.count) chars extracted.)",
                bullets: [],
                source: pdf
            )
        } catch {
            return .error("Couldn't read the PDF: \(error.localizedDescription)")
        }
    }

    private func handleInstalledApps() -> ConciergeCard {
        if let fixture = installedAppsFixture {
            let pairs = fixture.map {
                (displayName: $0.0, bundleID: Optional<String>.some($0.1))
            }
            return .appList(pairs)
        }
        // Production path: SovereigntyScanner.enumerateApplications is
        // nonisolated and sync-safe.  No actor hop, no @MainActor
        // dependency.  This is the same call site SovereigntyView uses
        // when populating the scan results.
        let installed = SovereigntyScanner.enumerateApplications()
        let apps = installed.map {
            (displayName: $0.name, bundleID: Optional<String>.some($0.id))
        }
        return .appList(apps)
    }

    private func handleSovereigntyReport() -> ConciergeCard {
        let installed = SovereigntyScanner.enumerateApplications()
        var hits: [ConciergeCard.SovereigntyHit] = []
        for app in installed {
            guard let entry = SovereigntyCatalog.alternatives(for: app.id) else { continue }
            guard let alt = entry.alternatives.first(where: { $0.origin.isRecommendable }) else { continue }
            hits.append(ConciergeCard.SovereigntyHit(
                targetName: entry.targetDisplayName,
                targetBundleID: entry.targetBundleID,
                alternativeName: alt.name,
                alternativeHomepage: alt.homepage,
                note: alt.note,
                canInstall: alt.downloadURL != nil
            ))
            if hits.count >= 5 { break }
        }
        if hits.isEmpty {
            return .text("Scanned \(installed.count) apps — none matched a Sovereignty catalog entry.")
        }
        return .sovereigntyReport(hits)
    }

    private func handleTrustReport() -> ConciergeCard {
        let installed = SovereigntyScanner.enumerateApplications()
        struct Ranked {
            let hit: ConciergeCard.TrustHit
            let severity: Int
        }
        var ranked: [Ranked] = []
        for app in installed {
            guard let entry = TrustCatalog.profile(for: app.id) else { continue }
            let scored = TrustScorer.score(entry, weights: .default)
            ranked.append(Ranked(
                hit: ConciergeCard.TrustHit(
                    appName: app.name,
                    bundleID: app.id,
                    score: Int(scored.value),
                    level: scored.level.rawValue.capitalized,
                    summary: entry.concerns.first?.summary ?? "—"
                ),
                severity: Int(scored.value)
            ))
        }
        let top = ranked
            .sorted { $0.severity > $1.severity }
            .prefix(5)
            .map { $0.hit }
        if top.isEmpty {
            return .text("Scanned \(installed.count) apps — none have Trust catalog entries.")
        }
        return .trustReport(Array(top))
    }

    private func handleRecentActivity() -> ConciergeCard {
        let entries = historyFixture ?? DownloadHistory.load()
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-86_400)
        let recent = entries.filter { $0.finishedAt >= oneDayAgo }
        if recent.isEmpty {
            return .text("No downloads in the last 24 hours.")
        }
        let totalBytes = recent.reduce(Int64(0)) { $0 + $1.totalBytes }
        let formatted = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        let topNames = recent.prefix(5).map { $0.filename }.joined(separator: ", ")
        return .text(
            "\(recent.count) download(s) in the last 24 hours, \(formatted) total."
                + (recent.count > 0 ? "\nMost recent: \(topNames)." : "")
        )
    }
}
