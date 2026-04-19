import Foundation
import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class SplynekViewModel: ObservableObject {

    // Input (session-only)
    @Published var urlText: String = ""
    @Published var sha256Expected: String = ""
    @Published var mirrors: [URL] = []   // populated by loading a .metalink file
    @Published var merkleManifest: MerkleManifest?

    // Persisted preferences (survive relaunch via UserDefaults)
    @Published var outputDirectory: URL {
        didSet { UserDefaults.standard.set(outputDirectory.path, forKey: "outputDirectoryPath") }
    }
    @Published var connectionsPerInterface: Int {
        didSet { UserDefaults.standard.set(connectionsPerInterface, forKey: "connectionsPerInterface") }
    }
    @Published var useDoH: Bool {
        didSet { UserDefaults.standard.set(useDoH, forKey: "useDoH") }
    }
    /// Max simultaneous HTTP downloads. 1 == old strictly-sequential behaviour.
    @Published var maxConcurrentDownloads: Int {
        didSet {
            UserDefaults.standard.set(maxConcurrentDownloads, forKey: "maxConcurrentDownloads")
            pumpQueueRunner()
        }
    }

    /// Live jobs (running, paused, or recently completed/cancelled/failed
    /// — the UI lists them until the user clears).
    @Published var activeJobs: [DownloadJob] = []

    /// True iff at least one job is in .running state.
    var isRunning: Bool { activeJobs.contains { $0.lifecycle == .running } }

    /// Sum of current throughput across every running job.
    var aggregateThroughputBps: Double {
        activeJobs.reduce(0) { acc, job in
            job.lifecycle == .running ? acc + job.progress.throughputBps : acc
        }
    }

    /// Aggregate download fraction for dock-badge purposes. Weighted by
    /// totalBytes so bigger jobs dominate.
    var aggregateFraction: Double {
        let running = activeJobs.filter { $0.lifecycle == .running }
        let total = running.reduce(Int64(0)) { $0 + $1.progress.totalBytes }
        guard total > 0 else { return 0 }
        let done = running.reduce(Int64(0)) { $0 + $1.progress.downloaded }
        return Double(done) / Double(total)
    }

    // Discovery
    @Published var interfaces: [DiscoveredInterface] = []
    @Published var selected: Set<String> = []

    // Form-level ephemeral state (last-known probe result for the form)
    @Published var suggestedFilename: String = ""
    @Published var outputPath: URL?
    /// Surface-level error from a probe failure before a job is created.
    /// Job-specific errors live on each job's own `progress.errorMessage`.
    @Published var formErrorMessage: String?

    // Alerts
    @Published var sizeConfirmationPending: Bool = false
    @Published var pendingSizeBytes: Int64 = 0
    @Published var hostCapAlertPending: Bool = false
    @Published var hostCapAlertHost: String = ""
    @Published var hostCapAlertUsed: Int64 = 0
    @Published var hostCapAlertLimit: Int64 = 0

    // History / replay
    @Published var history: [HistoryEntry] = []
    @Published var laneProfile: [String: Double] = [:]

    // Queue
    @Published var queue: [QueueEntry] = []

    /// Populated in the background by `UpdateChecker.check()` shortly after
    /// launch. Nil means "up-to-date" or "no feed configured" — the UI
    /// treats both as silent.
    @Published var availableUpdate: UpdateInfo?

    // MARK: Cellular budget

    /// Current day's bytes used on cellular interfaces (aggregate).
    @Published var cellularBytesToday: Int64 = 0
    /// User-configured daily cap in bytes. 0 = unlimited.
    @Published var cellularDailyCap: Int64 = 0

    /// 10 Hz-ish poll that keeps the UI numbers in sync with what lanes
    /// are writing to disk. Cheap — it's a single JSON decode of ~60 bytes.
    private var cellularTimer: Timer?

    func refreshCellularBudget() {
        let state = CellularBudget.load()
        cellularBytesToday = state.bytesToday
        cellularDailyCap = state.dailyCap
    }

    func setCellularDailyCap(_ bytes: Int64) {
        CellularBudget.setDailyCap(bytes)
        cellularDailyCap = bytes
    }

    /// Kick off a normal multi-interface download for the advertised
    /// update artefact. Populates the URL + SHA-256 fields, then invokes
    /// `start()` so the job appears in the activeJobs list like any other.
    /// The user clicks the banner's *Download*, watches the job land in
    /// History, and installs manually from Finder.
    func downloadUpdate() {
        guard let info = availableUpdate else { return }
        urlText = info.url
        if let sha = info.sha256, !sha.isEmpty {
            sha256Expected = sha
        }
        start()
    }

    /// Returns true if any selected interface is cellular *and* the user
    /// has a daily cap that today's usage is already past. The VM uses
    /// this to decide whether to prompt before spawning a new job.
    var cellularBudgetExceeded: Bool {
        cellularDailyCap > 0 && cellularBytesToday >= cellularDailyCap
    }

    // MARK: Recipes (v0.42 — agentic download planner)

    /// Current draft recipe — populated when `generateRecipe(goal:)`
    /// returns. Users review + unselect items, then `queueRecipe()`
    /// batches the selected items into the queue.
    @Published var currentRecipe: DownloadRecipe?

    /// True while the LLM is generating. Disables the input + shows
    /// a spinner in the Recipes view.
    @Published var recipeGenerating: Bool = false

    /// Last error from generation — surfaced inline so users see
    /// "model returned invalid JSON, try again" rather than silence.
    @Published var recipeError: String?

    /// Most-recent previous recipes (rolled off at 20). Rendered as
    /// a collapsible history at the bottom of the Recipes view; users
    /// can revisit a past plan without re-running the LLM.
    @Published var recipeHistory: [DownloadRecipe] = []

    /// Kick off LLM recipe generation for the user-typed goal.
    /// Populates `currentRecipe` on success.
    func generateRecipe(for goal: String) {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recipeError = nil
        recipeGenerating = true
        let assistant = ai
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.recipeGenerating = false }
            do {
                let recipe = try await assistant.generateRecipe(goal: trimmed)
                self.currentRecipe = recipe
                self.recipeHistory.insert(recipe, at: 0)
                self.recipeHistory = Array(self.recipeHistory.prefix(RecipeStore.maxStored))
                RecipeStore.save(self.recipeHistory)
            } catch {
                self.recipeError = error.localizedDescription
            }
        }
    }

    /// Toggle selection of a single item in the current recipe.
    func toggleRecipeItem(id: UUID) {
        guard var recipe = currentRecipe,
              let idx = recipe.items.firstIndex(where: { $0.id == id }) else { return }
        recipe.items[idx].selected.toggle()
        currentRecipe = recipe
    }

    /// Queue every selected item from the current recipe in one
    /// go. Empties `currentRecipe` on success.
    func queueCurrentRecipe() {
        guard let recipe = currentRecipe else { return }
        let picked = recipe.items.filter(\.selected)
        guard !picked.isEmpty else { return }
        for item in picked {
            queue.append(QueueEntry(
                id: UUID(),
                url: item.url,
                sha256: item.sha256,
                addedAt: Date(),
                status: .pending,
                errorMessage: nil
            ))
        }
        DownloadQueue.save(queue)
        // Kick the scheduler so the first item starts immediately.
        if !isRunning, !isTorrenting { runNextInQueue() }
        currentRecipe = nil
    }

    /// Discard the current draft without queuing anything.
    func discardCurrentRecipe() {
        currentRecipe = nil
    }

    /// Re-open an archived recipe as the current draft so the user
    /// can queue it again (possibly with different selections).
    func reopenRecipe(_ recipe: DownloadRecipe) {
        var copy = recipe
        // Reset selection so the user reviews each item afresh.
        copy.items = copy.items.map {
            var it = $0; it.selected = true; return it
        }
        currentRecipe = copy
    }

    // MARK: Pro license (v0.41)

    /// Offline-validated Pro unlock. Gates AI Concierge, AI history
    /// search, scheduled downloads, and the LAN-accessible web
    /// dashboard. Check `license.isPro` at call sites. See
    /// `LicenseManager` for the threat model and rotation policy.
    @Published var license = LicenseManager()

    /// Shown in the Pro-unlock settings card after the user sees a
    /// paywall CTA. True flips the card into the email+key form.
    @Published var showingProUnlock: Bool = false

    /// Called from any ProLockedView "Unlock" button. Jumps to
    /// Settings and scrolls to the unlock form.
    func requestProUnlock() {
        showingProUnlock = true
    }

    // MARK: Watched folder (v0.34)

    /// User-toggleable background ingestion of files dropped into a
    /// watched folder. Off by default; defaults to `~/Splynek/Watch/`
    /// when enabled for the first time.
    @Published private(set) var watchEnabled: Bool = UserDefaults.standard.bool(forKey: "watchEnabled")
    @Published private(set) var watchFolder: URL = {
        if let saved = UserDefaults.standard.string(forKey: "watchFolderPath"),
           !saved.isEmpty {
            return URL(fileURLWithPath: saved, isDirectory: true)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Splynek/Watch", isDirectory: true)
    }()

    private var watcher: WatchedFolder?

    func setWatchEnabled(_ on: Bool) {
        watchEnabled = on
        UserDefaults.standard.set(on, forKey: "watchEnabled")
        refreshWatcher()
    }

    func setWatchFolder(_ url: URL) {
        watchFolder = url
        UserDefaults.standard.set(url.path, forKey: "watchFolderPath")
        refreshWatcher()
    }

    private func refreshWatcher() {
        if watchEnabled {
            if watcher == nil {
                watcher = WatchedFolder(folder: watchFolder) { [weak self] url in
                    Task { @MainActor [weak self] in self?.handleWatchedFile(url) }
                }
            } else {
                watcher?.setFolder(watchFolder)
            }
            watcher?.start()
        } else {
            watcher?.stop()
            watcher = nil
        }
    }

    /// Called from WatchedFolder for each eligible dropped file.
    /// Silent on parse failures — we don't want an error banner from
    /// a file the user didn't explicitly open. Bad drops simply land
    /// in `processed/` without effect.
    private func handleWatchedFile(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "txt":
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
            var changed = false
            for link in WatchedFolderParser.parseURLs(fromText: text) {
                if link.hasPrefix("magnet:") {
                    // Magnets set up torrent state but don't auto-start
                    // the swarm — user still picks an interface.
                    self.magnetText = link
                    parseMagnet()
                    continue
                }
                queue.append(QueueEntry(
                    id: UUID(), url: link, sha256: nil,
                    addedAt: Date(), status: .pending
                ))
                changed = true
            }
            if changed {
                DownloadQueue.save(queue)
                if !isRunning && !isTorrenting { runNextInQueue() }
            }
        case "torrent":
            if let info = try? TorrentFile.parse(contentsOf: url) {
                torrentInfo = info
                suggestedFilename = info.name
                magnetInfoHash = nil
                magnetTrackers = []
            }
        case "metalink", "meta4":
            if let file = try? Metalink.parse(contentsOf: url),
               let first = file.urls.first {
                queue.append(QueueEntry(
                    id: UUID(), url: first.absoluteString, sha256: file.sha256,
                    addedAt: Date(), status: .pending
                ))
                DownloadQueue.save(queue)
                if !isRunning && !isTorrenting { runNextInQueue() }
            }
        default: break
        }
    }

    // MARK: Download schedule (v0.34)

    /// Global policy that gates when the engine is allowed to start queue
    /// items. The UI writes through `updateSchedule(_:)` so persistence
    /// and next-tick retry happen in one place.
    @Published private(set) var downloadSchedule: DownloadSchedule = .default

    /// Fires every 60s so a queued item whose window just opened wakes
    /// up on its own. Cheap — it short-circuits immediately when the
    /// queue is idle.
    private var scheduleRetryTimer: Timer?

    func updateSchedule(_ schedule: DownloadSchedule) {
        downloadSchedule = schedule
        schedule.save()
        // If the change unblocks the queue, kick it right away.
        if !isRunning, !isTorrenting { runNextInQueue() }
    }

    /// True when any currently selected interface is cellular. Used by
    /// the schedule's `pauseOnCellular` rule.
    var hasCellularSelected: Bool {
        interfaces.contains { selected.contains($0.name) && $0.isExpensive }
    }

    /// Current gate state for the head-of-queue, snapshot-style. Used by
    /// QueueView to render the "Waiting until 02:00" pill on pending
    /// entries when the window is closed.
    ///
    /// Free tier (v0.41+): the scheduler is a Pro feature, so for
    /// non-Pro sessions we always return `.allowed` — downloads fire
    /// immediately regardless of the on-disk schedule config. The
    /// Settings card also hides its contents, but a persisted
    /// `schedule.json` from a previous Pro session would otherwise
    /// silently keep gating starts; this guard ensures it doesn't.
    var scheduleEvaluation: DownloadSchedule.Evaluation {
        guard license.isPro else { return .allowed }
        return downloadSchedule.evaluate(at: Date(), onCellular: hasCellularSelected)
    }

    // MARK: Per-host caps (HostUsage)

    /// Live snapshot of top hosts, refreshed alongside the cellular
    /// timer. The UI binds to this so edits + traffic both reflect.
    @Published var topHosts: [HostUsageEntry] = []

    func refreshHostUsage() {
        topHosts = HostUsage.top(8)
    }

    func setHostDailyCap(_ host: String, bytes: Int64) {
        HostUsage.setCap(host: host, bytes: bytes)
        refreshHostUsage()
    }

    // Auth + headers (cleared after each download starts)
    @Published var customHeaders: [String: String] = [:]
    @Published var detachedSignatureURL: URL?   // `.asc` / `.sig` sibling, if detected

    /// Auto-enrichment results for the current URL in the form — sibling
    /// `.torrent`, `.metalink`, `.splynek-manifest`, etc. Populated in
    /// the background by `Enrichment.probe` a few hundred ms after the
    /// URL field changes, cleared when the URL changes or a job starts.
    @Published var enrichment: EnrichmentReport = .init()

    /// If the pasted URL matches a prior completion whose file still
    /// exists on disk, this holds the match — the UI renders a yellow
    /// "already have this" banner with Reveal / Re-download / Dismiss
    /// actions, and `start()` routes around the normal spawn path.
    @Published var duplicate: DuplicateMatch?

    /// Downloads above this size trigger a confirmation alert.
    static let sizeConfirmationThreshold: Int64 = 10 * 1024 * 1024 * 1024  // 10 GiB

    private var pendingStart: (URL, URL, [DiscoveredInterface], Int64, String?, [String: String])?
    private var dockTimer: Timer?

    /// Per-interface TokenBuckets, created lazily on first use. Shared
    /// across every concurrent DownloadEngine so bandwidth caps apply to
    /// the interface in aggregate, not per-engine.
    private var sharedBuckets: [String: TokenBucket] = [:]

    /// Per-interface bandwidth caps in bytes/sec (0 = no cap). Exposed to
    /// the UI so user edits in the Interfaces list flow straight through
    /// to the shared bucket.
    @Published var interfaceCapsBps: [String: Int64] = [:]

    /// Retrieve (or lazily create) a bucket for `interfaceName`.
    private func bucket(for interfaceName: String) -> TokenBucket {
        if let existing = sharedBuckets[interfaceName] { return existing }
        let bps = interfaceCapsBps[interfaceName] ?? 0
        let b = TokenBucket(ratePerSec: bps)
        sharedBuckets[interfaceName] = b
        return b
    }

    /// Apply a new cap to the shared bucket for this interface.
    func setInterfaceCap(_ interfaceName: String, bytesPerSecond: Int64) {
        interfaceCapsBps[interfaceName] = bytesPerSecond
        let b = bucket(for: interfaceName)
        Task { await b.setRate(bytesPerSecond) }
    }

    /// Build the dict DownloadEngine expects: one (shared) bucket per
    /// interface we're going to route through.
    private func bucketsFor(_ interfaces: [DiscoveredInterface]) -> [String: TokenBucket] {
        Dictionary(uniqueKeysWithValues: interfaces.map { ($0.name, bucket(for: $0.name)) })
    }

    // Fleet orchestration — singleton, owned by the VM, exposed to views.
    let fleet = FleetCoordinator()

    /// URLs the user has explicitly excluded from fleet sharing.
    /// Persisted to UserDefaults. Entries here are filtered out of
    /// `publishFleetState`'s completed list, so other Splyneks on
    /// the LAN can't fetch these files from this Mac. Added in v0.46
    /// in response to "I want to stop sharing this specific file
    /// but keep it in my history."
    @Published var fleetExcludedURLs: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "fleetExcludedURLs") ?? []
    )

    /// Toggle a completed file's fleet-sharing status. Does NOT
    /// delete the file or remove the history entry — just changes
    /// whether peers can fetch it from us.
    func toggleFleetSharing(url: String) {
        if fleetExcludedURLs.contains(url) {
            fleetExcludedURLs.remove(url)
        } else {
            fleetExcludedURLs.insert(url)
        }
        UserDefaults.standard.set(Array(fleetExcludedURLs),
                                  forKey: "fleetExcludedURLs")
        publishFleetState()
    }

    // MARK: AI

    /// Local-AI assistant backed by Ollama on localhost. See
    /// [AIAssistant.swift](AIAssistant.swift). The VM owns the actor;
    /// views bind to the published flags below.
    let ai = AIAssistant()

    /// True iff Ollama is running and at least one model is installed.
    @Published var aiAvailable: Bool = false
    /// The model tag the assistant will use (picked heuristically).
    @Published var aiModel: String?
    /// One-line reason Ollama isn't usable; surfaced in the AboutView.
    @Published var aiUnavailableReason: String?
    /// True while a URL-resolution request is in flight.
    @Published var aiThinking: Bool = false
    /// Short phrase the model produced alongside its URL — shown as a
    /// pill under the URL field after a successful AI resolution.
    @Published var aiRationale: String?
    /// Last error surfaced to the AI row — cleared on next request.
    @Published var aiErrorMessage: String?

    /// Indices (into `history`) returned by the last AI history search.
    /// Drives the History view's "AI results" section. Empty = no
    /// search active / no results.
    @Published var aiHistoryHits: [Int] = []
    /// The query that produced `aiHistoryHits` — shown to the user as
    /// a chip, with an x-button to clear and return to the full list.
    @Published var aiHistoryQuery: String = ""
    /// True while a history search is in flight.
    @Published var aiHistoryThinking: Bool = false

    /// Running chat transcript for the AI Concierge view. Each entry
    /// is one bubble — user on the right, assistant on the left.
    @Published var aiChat: [ConciergeMessage] = []
    /// True while the concierge is waiting on a model response.
    @Published var aiConciergeThinking: Bool = false

    struct ConciergeMessage: Identifiable, Equatable {
        let id = UUID()
        let role: Role
        let text: String
        let action: String?   // short human-readable chip under assistant msgs
        enum Role: String { case user, assistant, system }
    }

    // Torrent
    @Published var torrentProgress = TorrentProgress()
    @Published var isTorrenting = false
    @Published var torrentInfo: TorrentInfo?
    /// Absolute path of the most recently loaded .torrent file, if any.
    /// Persisted across launches so relaunch can re-ingest.
    @Published var lastTorrentFilePath: String?
    @Published var seedAfterCompletion: Bool {
        didSet { UserDefaults.standard.set(seedAfterCompletion, forKey: "seedAfterCompletion") }
    }
    @Published var seedWhileLeeching: Bool {
        didSet { UserDefaults.standard.set(seedWhileLeeching, forKey: "seedWhileLeeching") }
    }
    private var torrentEngine: TorrentEngine?
    private var torrentTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        // Output directory: load persisted, else Downloads, else tempDir.
        if let path = defaults.string(forKey: "outputDirectoryPath"),
           FileManager.default.fileExists(atPath: path) {
            self.outputDirectory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            self.outputDirectory = FileManager.default.urls(
                for: .downloadsDirectory, in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
        }
        let savedConns = defaults.integer(forKey: "connectionsPerInterface")
        self.connectionsPerInterface = (1...8).contains(savedConns) ? savedConns : 1
        self.useDoH = defaults.bool(forKey: "useDoH")
        self.seedAfterCompletion = defaults.bool(forKey: "seedAfterCompletion")
        self.seedWhileLeeching = defaults.bool(forKey: "seedWhileLeeching")
        let savedMax = defaults.integer(forKey: "maxConcurrentDownloads")
        self.maxConcurrentDownloads = (1...10).contains(savedMax) ? savedMax : 3

        history = DownloadHistory.load()
        queue = DownloadQueue.load()
        downloadSchedule = DownloadSchedule.load()
        recipeHistory = RecipeStore.load()
        startDockBadgeTimer()
        scheduleRetryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isRunning, !self.isTorrenting else { return }
                self.runNextInQueue()
            }
        }
        // Resume watched-folder ingestion if the user had it on last launch.
        Task { @MainActor [weak self] in self?.refreshWatcher() }
        // Seed cellular budget from disk + keep it refreshed as lanes write.
        refreshCellularBudget()
        refreshHostUsage()
        cellularTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshCellularBudget()
                self?.refreshHostUsage()
                self?.publishFleetState()
            }
        }
        // Stand up the Bonjour fleet listener + browser. Silent on
        // networks where mDNS is blocked (no peers discovered). Pro
        // gate (v0.41+): free tier forces loopback-only so the web
        // dashboard stays local-only; Pro lifts the restriction.
        fleet.proGateForcesLoopback = !license.isPro
        fleet.start()
        publishFleetState()
        // Force-write the fleet descriptor shortly after launch so the
        // CLI / Raycast / Alfred always find a current file. Release
        // optimizer has a way of folding the NWListener .ready
        // callback's Task body into the caller; this timer makes the
        // write unambiguously reachable.
        Task { @MainActor [weak self] in
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.publishFleetState()
            }
        }
        // Wire the web dashboard's submit endpoint to the same ingest
        // contract the scheme handler, drop handler, and menu-bar
        // popover use. One path for every surface.
        fleet.onCancelAll = { [weak self] in self?.cancelAll() }
        fleet.onWebIngest = { [weak self] action, raw in
            guard let self else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("magnet:") {
                self.magnetText = trimmed
                self.parseMagnet()
                return
            }
            guard let url = URL(string: trimmed),
                  url.scheme?.lowercased().hasPrefix("http") == true else { return }
            self.urlText = trimmed
            if action == "queue" {
                self.addCurrentToQueue()
            } else {
                self.start()
            }
        }
        // Push the loaded history into Spotlight so prior runs are
        // searchable system-wide. Reindexed again after every completion.
        SplynekSpotlight.reindex(history)
        // Session restore is deferred until `restoreSession()` is called
        // from the app delegate, after interface discovery has populated.
        // Non-blocking update poll; silent if no feed is configured.
        Task { [weak self] in
            let info = await UpdateChecker.check()
            await MainActor.run { self?.availableUpdate = info }
        }
        // Non-blocking AI detection. Sets `aiAvailable` if Ollama is
        // running locally with at least one model installed.
        Task { [weak self] in await self?.refreshAIStatus() }
    }

    /// Re-probe Ollama. Called at launch and from the AboutView
    /// "Refresh" button so users can kick a re-check after installing
    /// a new model or starting `ollama serve`.
    func refreshAIStatus() async {
        let state = await ai.detect()
        await MainActor.run {
            switch state {
            case .ready(let model):
                self.aiAvailable = true
                self.aiModel = model
                self.aiUnavailableReason = nil
            case .unavailable(let why):
                self.aiAvailable = false
                self.aiModel = nil
                self.aiUnavailableReason = why
            case .unknown:
                break
            }
        }
    }

    /// Ask the local LLM to rank history entries against a plain-English
    /// query. Populates `aiHistoryHits` + `aiHistoryQuery`; the History
    /// view binds to both. Silent on failure — the UI falls back to
    /// the full list.
    func searchHistoryViaAI(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, aiAvailable else {
            aiHistoryHits = []
            aiHistoryQuery = ""
            return
        }
        aiHistoryThinking = true
        let entries = history
        Task { [weak self] in
            guard let self else { return }
            do {
                let hits = try await self.ai.searchHistory(
                    query: trimmed, entries: entries
                )
                await MainActor.run {
                    self.aiHistoryHits = hits
                    self.aiHistoryQuery = trimmed
                    self.aiHistoryThinking = false
                }
            } catch {
                await MainActor.run {
                    self.aiHistoryHits = []
                    self.aiHistoryQuery = ""
                    self.aiHistoryThinking = false
                }
            }
        }
    }

    /// Clear the AI search results; HistoryView goes back to the full list.
    func clearAIHistorySearch() {
        aiHistoryHits = []
        aiHistoryQuery = ""
    }

    // MARK: Concierge (v0.28)

    /// Dispatch a free-form utterance through the concierge. Appends
    /// to `aiChat`; the ConciergeView binds to it. Honors the
    /// ai-available gate — if Ollama isn't detected, we append a
    /// system message telling the user how to enable it.
    func conciergeSend(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        aiChat.append(.init(role: .user, text: trimmed, action: nil))
        guard aiAvailable else {
            aiChat.append(.init(
                role: .system,
                text: "Install Ollama (ollama.com/download) + any model — llama3.2:3b is perfect — to enable the Concierge. Until then the ingress surfaces (Download tab, menu bar, CLI, web dashboard) all still work.",
                action: nil
            ))
            return
        }
        aiConciergeThinking = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let action = try await self.ai.concierge(trimmed)
                await MainActor.run {
                    self.handleConciergeAction(action, userText: trimmed)
                    self.aiConciergeThinking = false
                }
            } catch {
                await MainActor.run {
                    self.aiChat.append(.init(
                        role: .assistant,
                        text: "Something went wrong: \(error.localizedDescription)",
                        action: nil
                    ))
                    self.aiConciergeThinking = false
                }
            }
        }
    }

    /// Clear the concierge transcript — restart the conversation.
    func conciergeReset() {
        aiChat = []
    }

    /// Route the classified action through the existing VM operations.
    /// Every action produces one assistant bubble so the user sees
    /// what we did; that bubble's `action` chip labels the dispatch.
    @MainActor
    private func handleConciergeAction(
        _ action: AIAssistant.ConciergeAction, userText: String
    ) {
        switch action {
        case .download(let url, let rationale):
            urlText = url.absoluteString
            aiChat.append(.init(
                role: .assistant,
                text: rationale + " Starting download.",
                action: "DOWNLOAD"
            ))
            Task { await self.autoDetectSha256(for: url) }
            start()

        case .queue(let url, let rationale):
            urlText = url.absoluteString
            aiChat.append(.init(
                role: .assistant,
                text: rationale + " Added to queue.",
                action: "QUEUE"
            ))
            addCurrentToQueue()

        case .search(let query):
            searchHistoryViaAI(query)
            aiChat.append(.init(
                role: .assistant,
                text: "Searching your history for: \(query). Results appear in the History tab.",
                action: "SEARCH"
            ))

        case .cancelAll:
            let n = activeJobs.filter { $0.lifecycle == .running }.count
            cancelAll()
            aiChat.append(.init(
                role: .assistant,
                text: "Cancelled \(n) running download\(n == 1 ? "" : "s").",
                action: "CANCEL"
            ))

        case .pauseAll:
            let running = activeJobs.filter { $0.lifecycle == .running }
            for job in running { pauseJob(job) }
            aiChat.append(.init(
                role: .assistant,
                text: "Paused \(running.count) download\(running.count == 1 ? "" : "s"). Resume them from the Downloads tab.",
                action: "PAUSE"
            ))

        case .unclear(let followUp):
            aiChat.append(.init(
                role: .assistant,
                text: followUp,
                action: nil
            ))
        }
    }

    /// Ask the local LLM to turn `query` into a download URL. On
    /// success, populates the URL field + the rationale pill; never
    /// auto-starts. The user hits Return / Start to proceed exactly
    /// like any other paste flow.
    func resolveViaAI(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, aiAvailable else { return }
        aiThinking = true
        aiErrorMessage = nil
        aiRationale = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let (url, rationale) = try await self.ai.resolveURL(trimmed)
                await MainActor.run {
                    self.urlText = url.absoluteString
                    self.aiRationale = rationale
                    self.aiThinking = false
                    // Kick enrichment + duplicate checks like a paste.
                    Task { await self.autoDetectSha256(for: url) }
                }
            } catch {
                await MainActor.run {
                    self.aiThinking = false
                    self.aiErrorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Persist every non-terminal job, plus a light torrent snapshot, so we
    /// can bring them back on the next launch. Called from AppDelegate on
    /// willTerminate.
    func saveSession() {
        let snapshots = activeJobs
            .filter { !$0.lifecycle.isTerminal }
            .map(\.snapshot)
        let torrentSnap: TorrentSnapshot?
        let hasMagnet = !magnetText.trimmingCharacters(in: .whitespaces).isEmpty
        if hasMagnet || lastTorrentFilePath != nil {
            torrentSnap = TorrentSnapshot(
                magnetText: hasMagnet ? magnetText : nil,
                torrentFilePath: lastTorrentFilePath
            )
        } else {
            torrentSnap = nil
        }
        SessionStore.save(jobs: snapshots, torrent: torrentSnap)
    }

    /// Rebuild jobs + (optionally) re-parse a magnet / reload a .torrent
    /// from the previous session. Missing output files or sidecars cause
    /// the HTTP entry to drop; missing .torrent files are silently
    /// skipped.
    func restoreSession() {
        let payload = SessionStore.load()
        let fm = FileManager.default

        // HTTP jobs
        for snap in payload.jobs {
            let outURL = URL(fileURLWithPath: snap.outputPath)
            let sidecar = outURL.appendingPathExtension("splynek")
            guard fm.fileExists(atPath: outURL.path),
                  fm.fileExists(atPath: sidecar.path) else {
                continue
            }
            let buckets = bucketsFor(interfaces.filter { snap.interfaceNames.contains($0.name) })
            if let job = DownloadJob.restored(
                from: snap,
                currentInterfaces: interfaces,
                sharedBuckets: buckets
            ) {
                activeJobs.append(job)
            }
        }

        // Torrent side: restore last magnet or last .torrent.
        if let t = payload.torrent {
            if let magnet = t.magnetText, !magnet.isEmpty {
                self.magnetText = magnet
                parseMagnet()
            } else if let path = t.torrentFilePath,
                      fm.fileExists(atPath: path) {
                let url = URL(fileURLWithPath: path)
                if let info = try? TorrentFile.parse(contentsOf: url) {
                    self.torrentInfo = info
                    self.suggestedFilename = info.name
                    self.lastTorrentFilePath = path
                }
            }
        }

        SessionStore.clear()
    }

    /// 1 Hz dock-badge refresh based on aggregate download state.
    private func startDockBadgeTimer() {
        dockTimer?.invalidate()
        dockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshDockBadge() }
        }
    }

    private func refreshDockBadge() {
        let running = activeJobs.filter { $0.lifecycle == .running }
        if running.isEmpty {
            DockBadge.set(nil)
        } else if running.count == 1 {
            DockBadge.showProgress(aggregateFraction)
        } else {
            DockBadge.set("\(running.count)")
        }
    }

    // MARK: Discovery

    func refreshInterfaces() async {
        let list = await InterfaceDiscovery.current()
        self.interfaces = list
        if selected.isEmpty {
            // Default: everything that isn't expensive (cellular).
            self.selected = Set(list.filter { !$0.isExpensive }.map(\.name))
        }
    }

    // MARK: Start / cancel

    /// Begin a download described by the current form state. Creates a new
    /// DownloadJob and runs it concurrently up to maxConcurrentDownloads.
    ///
    /// Before spawning, *cancelled* and *failed* job cards are swept out
    /// of the list so a fresh download doesn't sit next to a stale red
    /// "Cancelled" tombstone. Completed jobs are kept — they're success
    /// and the user may still want to Reveal the file.
    func start() {
        formErrorMessage = nil
        activeJobs.removeAll {
            $0.lifecycle == .cancelled || $0.lifecycle == .failed
        }
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            formErrorMessage = "URL must be http:// or https:// with a valid host."
            return
        }
        // Duplicate guard: if this URL has been downloaded before and the
        // output file is still on disk, surface the match instead of
        // silently re-downloading. The user can dismiss the banner and
        // call `overrideDuplicateAndStart` to force a fresh pull.
        if duplicate == nil,
           let match = Duplicate.findMatch(for: url, in: history) {
            duplicate = match
            return
        }
        let chosen = interfaces.filter { selected.contains($0.name) && $0.nwInterface != nil }
        guard !chosen.isEmpty else {
            formErrorMessage = "Select at least one interface."
            return
        }
        // Per-host cap pre-flight: if today's usage already crossed the
        // user-configured cap for this host, stash the request and let
        // the user confirm or cancel via alert.
        if let entry = HostUsage.entry(for: host), entry.isOverCap {
            hostCapAlertHost = host
            hostCapAlertUsed = entry.bytesToday
            hostCapAlertLimit = entry.dailyCap
            hostCapAlertPending = true
            return
        }
        laneProfile = DownloadHistory.laneProfile(host: host)

        let trimmedHash = sha256Expected.trimmingCharacters(in: .whitespacesAndNewlines)
        let expected = trimmedHash.isEmpty ? nil : trimmedHash
        let capturedHeaders = customHeaders

        Task { [weak self] in
            guard let self else { return }
            var filename = "download.bin"
            var probedURL = url
            var totalBytes: Int64 = 0
            do {
                let probed = try await Probe.run(url, extraHeaders: capturedHeaders)
                filename = probed.suggestedFilename
                probedURL = probed.finalURL
                totalBytes = probed.totalBytes
            } catch {
                await MainActor.run {
                    self.formErrorMessage = "Probe failed: \(error.localizedDescription)"
                }
                return
            }
            let outPath = Self.uniqueOutputPath(self.outputDirectory, filename)
            await MainActor.run {
                self.suggestedFilename = outPath.lastPathComponent
                self.outputPath = outPath
            }
            if totalBytes >= Self.sizeConfirmationThreshold {
                await MainActor.run {
                    self.pendingStart = (probedURL, outPath, chosen, totalBytes, expected, capturedHeaders)
                    self.pendingSizeBytes = totalBytes
                    self.sizeConfirmationPending = true
                }
                return
            }
            await MainActor.run {
                self.spawnJob(url: probedURL, outPath: outPath, interfaces: chosen,
                              sha256: expected, totalBytes: totalBytes,
                              extraHeaders: capturedHeaders)
            }
        }
    }

    func confirmLargeDownload() {
        guard let (url, outPath, ifs, total, sha, headers) = pendingStart else { return }
        sizeConfirmationPending = false
        pendingStart = nil
        spawnJob(url: url, outPath: outPath, interfaces: ifs,
                 sha256: sha, totalBytes: total, extraHeaders: headers)
    }

    func declineLargeDownload() {
        sizeConfirmationPending = false
        pendingStart = nil
    }

    /// "Download anyway" from the host-cap alert — temporarily clears the
    /// cap so `start()` won't re-trigger the alert, and reruns start.
    /// The cap is restored on the next midnight roll, or the user can
    /// re-enter it from the History card.
    func confirmOverCapDownload() {
        let host = hostCapAlertHost
        hostCapAlertPending = false
        // Null the cap for today; preserves "cap exists" intent for tomorrow
        // would require separate persistence. Pragmatic choice: clearing
        // is the user saying "stop warning me today."
        if !host.isEmpty {
            HostUsage.setCap(host: host, bytes: 0)
            refreshHostUsage()
        }
        start()
    }

    func declineOverCapDownload() {
        hostCapAlertPending = false
    }

    /// Create a DownloadJob and either start it immediately (if under
    /// `maxConcurrentDownloads`) or leave it `.pending` for the pump.
    private func spawnJob(
        url: URL, outPath: URL,
        interfaces: [DiscoveredInterface],
        sha256: String?, totalBytes: Int64,
        extraHeaders: [String: String]
    ) {
        // Fold in any fleet-peer mirrors. Two sources:
        //   1. URL-match  — peer has (or is actively downloading) exactly
        //      this URL. Same-origin cooperation.
        //   2. Hash-match — if the user supplied a SHA-256, any fleet
        //      peer that ever completed a file with that exact digest can
        //      serve it by content address, even if it downloaded the
        //      file from a different URL. The LAN becomes a content
        //      cache, not a URL cache.
        var fleetMirrors = fleet.mirrors(for: url)
        if let sha = sha256, !sha.isEmpty {
            fleetMirrors.append(contentsOf: fleet.contentMirrors(for: sha))
        }
        // Dedupe by absolute string so a peer matching on both URL and
        // content hash only contributes one lane.
        var seenURLs: Set<String> = []
        fleetMirrors = fleetMirrors.filter { seenURLs.insert($0.absoluteString).inserted }
        let job = DownloadJob(
            url: url, outputURL: outPath, interfaces: interfaces,
            sha256Expected: sha256,
            connectionsPerInterface: connectionsPerInterface,
            useDoH: useDoH, merkleManifest: merkleManifest,
            extraHeaders: extraHeaders,
            sharedBuckets: bucketsFor(interfaces),
            fleetMirrors: fleetMirrors
        )
        job.progress.totalBytes = totalBytes
        activeJobs.append(job)
        publishFleetState()
        pumpQueueRunner()
    }

    /// Push the VM's download state into the fleet coordinator so peers
    /// see an up-to-date `/status` endpoint. Called from the 2 Hz timer
    /// (and at spawnJob / completion boundaries) — cheap.
    func publishFleetState() {
        var active: [FleetCoordinator.LocalState.ActiveJob] = []
        for job in activeJobs where job.lifecycle == .running || job.lifecycle == .paused {
            // Load the current sidecar to know which chunks are complete.
            let sidecarPath = job.outputURL.appendingPathExtension("splynek")
            var completed: [Int] = []
            var chunkSize: Int64 = DownloadEngine.chunkBytes
            if let data = try? Data(contentsOf: sidecarPath),
               let state = try? JSONDecoder().decode(SidecarState.self, from: data) {
                completed = state.completed
                chunkSize = state.chunkSize
            }
            active.append(.init(
                url: job.url.absoluteString,
                filename: job.outputURL.lastPathComponent,
                outputPath: job.outputURL.path,
                totalBytes: job.progress.totalBytes,
                downloaded: job.progress.downloaded,
                chunkSize: chunkSize,
                completedChunks: completed,
                phase: job.progress.phase.rawValue
            ))
        }
        // Publish only completed files that still exist on disk — a peer
        // fetching from us would otherwise get a 500 from the server's
        // FileHandle open. Also carry the SHA-256 so content-addressed
        // lookups work across URL changes.
        //
        // v0.46: respect the per-file "stop sharing" exclusion set.
        // Entries in `fleetExcludedURLs` are hidden from the fleet
        // sharing card and skipped when serving peer fetches.
        let fm = FileManager.default
        let excluded = fleetExcludedURLs
        let completed: [FleetCoordinator.LocalState.CompletedFile] = history
            .prefix(100)
            .compactMap { h in
                guard fm.fileExists(atPath: h.outputPath) else { return nil }
                guard !excluded.contains(h.url) else { return nil }
                return FleetCoordinator.LocalState.CompletedFile(
                    url: h.url, filename: h.filename,
                    outputPath: h.outputPath,
                    totalBytes: h.totalBytes,
                    finishedAt: h.finishedAt,
                    sha256: h.sha256
                )
            }
        fleet.updateLocalState(.init(active: active, completed: completed))
    }

    /// Start as many pending jobs as the cap allows, then pop from the
    /// persistent queue if the HTTP + torrent side are idle.
    func pumpQueueRunner() {
        while activeJobs.filter({ $0.lifecycle == .running }).count < maxConcurrentDownloads,
              let next = activeJobs.first(where: { $0.lifecycle == .pending }) {
            startJob(next)
        }
        if !isRunning, !isTorrenting,
           queue.contains(where: { $0.status == .pending }) {
            runNextInQueue()
        }
    }

    private func startJob(_ job: DownloadJob) {
        // Republish fleet state on every phase transition so API
        // consumers (integration tests, CLI, Raycast) observe the
        // Probing → Planning → Connecting → Downloading → Verifying
        // → Gatekeeper → Done order even when the 2 Hz publisher
        // would compress fast transitions. Removed in the completion
        // callback below.
        let jobID = job.id
        let cancellable = job.progress.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.publishFleetState() }
        jobPhaseCancellables[jobID] = cancellable

        job.start { [weak self] finished in
            guard let self else { return }
            self.jobPhaseCancellables.removeValue(forKey: finished.id)
            self.history = DownloadHistory.load()
            SplynekSpotlight.reindex(self.history)
            let ok = finished.progress.finished
            let msg = finished.progress.errorMessage
            self.markCurrentQueueEntry(success: ok, errorMessage: msg)
            self.pumpQueueRunner()
        }
    }

    /// Combine subscriptions tracking each active job's phase changes
    /// so fleet state gets republished immediately when the pipeline
    /// stage flips. Keyed by `DownloadJob.id`; torn down on completion.
    private var jobPhaseCancellables: [UUID: AnyCancellable] = [:]

    func removeJob(_ job: DownloadJob) {
        // v0.46 fix: the previous `isActive` guard made the trash
        // icon silently do nothing on paused jobs (because paused
        // counts as active in the lifecycle enum). That left users
        // unable to clear a paused job from the list without first
        // cancelling it in a separate click. Now we cancel the
        // engine inline if the job is still running or paused, then
        // remove it regardless.
        if job.lifecycle == .running || job.lifecycle == .paused {
            job.cancel()
        }
        activeJobs.removeAll { $0.id == job.id }
    }

    func clearFinishedJobs() {
        activeJobs.removeAll { $0.lifecycle.isTerminal }
    }

    func pauseJob(_ job: DownloadJob) { job.pause() }

    func resumeJob(_ job: DownloadJob) {
        job.resume { [weak self] _ in
            guard let self else { return }
            self.history = DownloadHistory.load()
            SplynekSpotlight.reindex(self.history)
            self.pumpQueueRunner()
        }
    }

    /// Cancel every in-flight job.
    func cancelAll() {
        for job in activeJobs where job.lifecycle.isActive {
            job.cancel()
        }
        if let i = queue.firstIndex(where: { $0.status == .running }) {
            queue[i].status = .cancelled
            queue[i].finishedAt = Date()
            DownloadQueue.save(queue)
        }
    }

    /// Preserved for existing call-sites (menu-bar `.keyboardShortcut(".")`,
    /// toolbar Cancel button).
    func cancel() { cancelAll() }

    // MARK: Queue

    func addCurrentToQueue() {
        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty, URL(string: url) != nil else {
            formErrorMessage = "Nothing to queue — paste a URL first."
            return
        }
        let sha = sha256Expected.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = QueueEntry(
            id: UUID(),
            url: url,
            sha256: sha.isEmpty ? nil : sha,
            addedAt: Date(),
            status: .pending
        )
        queue.append(entry)
        DownloadQueue.save(queue)
        // If nothing is running, kick the queue.
        if !isRunning && !isTorrenting { runNextInQueue() }
    }

    func removeFromQueue(id: UUID) {
        queue.removeAll { $0.id == id && $0.status != .running }
        DownloadQueue.save(queue)
    }

    func clearFinishedQueue() {
        queue.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
        DownloadQueue.save(queue)
    }

    // MARK: Queue export / import

    /// Write the current queue (pending + finished) to a JSON file the user
    /// can share, move, or version-control.
    // MARK: Usage CSV export (v0.37)

    func exportHostUsageCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "splynek-host-usage-\(HostUsage.today()).csv"
        if let csv = UTType(filenameExtension: "csv") {
            panel.allowedContentTypes = [csv]
        }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        let csv = UsageCSV.hostUsageCSV(
            today: HostUsage.load(),
            history: HostUsage.loadHistory()
        )
        do {
            try csv.data(using: .utf8)?.write(to: dest, options: .atomic)
        } catch {
            formErrorMessage = "Host-usage export failed: \(error.localizedDescription)"
        }
    }

    func exportCellularBudgetCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "splynek-cellular-budget-\(CellularBudget.today()).csv"
        if let csv = UTType(filenameExtension: "csv") {
            panel.allowedContentTypes = [csv]
        }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        let csv = UsageCSV.cellularBudgetCSV(
            today: CellularBudget.load(),
            history: CellularBudget.loadHistory()
        )
        do {
            try csv.data(using: .utf8)?.write(to: dest, options: .atomic)
        } catch {
            formErrorMessage = "Cellular-budget export failed: \(error.localizedDescription)"
        }
    }

    func exportQueue() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "splynek-queue.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(queue)
            try data.write(to: dest, options: .atomic)
        } catch {
            formErrorMessage = "Queue export failed: \(error.localizedDescription)"
        }
    }

    /// Read a JSON file produced by `exportQueue` and merge its entries into
    /// the live queue. Imported entries are always marked `.pending`
    /// regardless of their original state, and get fresh UUIDs so round-
    /// tripping is idempotent.
    func importQueue() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let src = panel.url else { return }
        do {
            let data = try Data(contentsOf: src)
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            let entries = try dec.decode([QueueEntry].self, from: data)
            for entry in entries {
                var fresh = entry
                fresh.id = UUID()
                fresh.status = .pending
                fresh.addedAt = Date()
                fresh.finishedAt = nil
                fresh.errorMessage = nil
                queue.append(fresh)
            }
            DownloadQueue.save(queue)
            if !isRunning && !isTorrenting { runNextInQueue() }
        } catch {
            formErrorMessage = "Queue import failed: \(error.localizedDescription)"
        }
    }

    func retryQueue(id: UUID) {
        guard let i = queue.firstIndex(where: { $0.id == id }) else { return }
        queue[i].status = .pending
        queue[i].errorMessage = nil
        queue[i].finishedAt = nil
        DownloadQueue.save(queue)
        if !isRunning && !isTorrenting { runNextInQueue() }
    }

    /// Pop the next pending entry and start it. Called after every completion
    /// and after adding to an idle queue.
    private func runNextInQueue() {
        guard !isRunning, !isTorrenting,
              let nextIdx = queue.firstIndex(where: { $0.status == .pending })
        else { return }
        // Schedule gate. When blocked, leave the entry pending; the
        // 60-second retry timer will re-enter this function when the
        // window opens.
        if case .blocked = scheduleEvaluation { return }
        var entry = queue[nextIdx]
        entry.status = .running
        entry.startedAt = Date()
        queue[nextIdx] = entry
        DownloadQueue.save(queue)

        // Populate inputs from the queue entry and fire the normal start path.
        urlText = entry.url
        sha256Expected = entry.sha256 ?? ""
        mirrors = []
        merkleManifest = nil
        start()
    }

    /// Mark the first running queue entry. With concurrent downloads, in-
    /// flight queue entries retire FIFO — approximate but good enough for
    /// the status badges in the Queue view.
    fileprivate func markCurrentQueueEntry(success: Bool, errorMessage: String? = nil) {
        guard let i = queue.firstIndex(where: { $0.status == .running }) else {
            return
        }
        queue[i].status = success ? .completed : .failed
        queue[i].finishedAt = Date()
        queue[i].errorMessage = errorMessage
        DownloadQueue.save(queue)
    }

    // MARK: Output helpers

    // MARK: Metalink

    func loadMetalink() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.prompt = "Load"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let file = try Metalink.parse(contentsOf: url)
            self.mirrors = file.urls
            if let first = file.urls.first { self.urlText = first.absoluteString }
            if let hash = file.sha256 { self.sha256Expected = hash }
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            self.formErrorMessage = error.localizedDescription
        }
    }

    func clearMirrors() { mirrors = [] }

    func loadMerkleManifest() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Load"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(MerkleManifest.self, from: data)
            self.merkleManifest = manifest
        } catch {
            self.formErrorMessage = "Manifest load failed: \(error.localizedDescription)"
        }
    }

    func clearMerkleManifest() { merkleManifest = nil }

    // MARK: Manifest publisher (Tools menu)

    /// Pick a local file, chunk/hash it, write `<file>.splynek-manifest`
    /// alongside. Side-channel signed-integrity for content distributed
    /// over HTTP; downstream Splynek installs can load the manifest and
    /// verify each chunk inline as it lands.
    func publishManifest() {
        let open = NSOpenPanel()
        open.canChooseFiles = true
        open.canChooseDirectories = false
        open.allowsMultipleSelection = false
        open.prompt = "Publish"
        guard open.runModal() == .OK, let source = open.url else { return }
        do {
            let manifest = try MerklePublisher.manifest(for: source)
            let save = NSSavePanel()
            save.nameFieldStringValue = source.lastPathComponent + ".splynek-manifest"
            save.canCreateDirectories = true
            save.directoryURL = source.deletingLastPathComponent()
            guard save.runModal() == .OK, let dest = save.url else { return }
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(manifest).write(to: dest, options: .atomic)
            formErrorMessage = "Wrote \(manifest.leafHexes.count) leaves to \(dest.lastPathComponent)."
        } catch {
            formErrorMessage = "Manifest publish failed: \(error.localizedDescription)"
        }
    }

    // MARK: Drag-and-drop

    /// Accept URLs (from Safari etc.), file URLs (`.torrent`, `.metalink`),
    /// or plain-text magnets. Returns true if at least one provider is
    /// loadable — SwiftUI uses this as a hover affordance hint.
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        // Try file URL first (.torrent / .metalink drops)
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let self, let url else { return }
                Task { @MainActor in self.ingest(url: url) }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier,
                              options: nil) { [weak self] coerced, _ in
                guard let self else { return }
                let text: String?
                if let s = coerced as? String { text = s }
                else if let d = coerced as? Data { text = String(data: d, encoding: .utf8) }
                else { text = nil }
                guard let text else { return }
                Task { @MainActor in self.ingest(text: text) }
            }
            return true
        }
        return false
    }

    private func ingest(url: URL) {
        if url.isFileURL {
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "torrent":
                do {
                    let info = try TorrentFile.parse(contentsOf: url)
                    self.torrentInfo = info
                    self.suggestedFilename = info.name
                    self.magnetInfoHash = nil
                    self.magnetTrackers = []
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                } catch {
                    self.formErrorMessage = error.localizedDescription
                }
            case "metalink", "meta4":
                do {
                    let file = try Metalink.parse(contentsOf: url)
                    self.mirrors = file.urls
                    if let first = file.urls.first { self.urlText = first.absoluteString }
                    if let hash = file.sha256 { self.sha256Expected = hash }
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                } catch {
                    self.formErrorMessage = error.localizedDescription
                }
            default:
                // Unknown file type — ignore rather than treat it as a download URL.
                break
            }
            return
        }
        // Remote URL — populate the field.
        self.urlText = url.absoluteString
        Task { await self.autoDetectSha256(for: url) }
    }

    private func ingest(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("magnet:") {
            self.magnetText = trimmed
            self.parseMagnet()
        } else if let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true {
            self.urlText = trimmed
            Task { await self.autoDetectSha256(for: url) }
        }
    }

    // MARK: Auto-sha256 sibling detection

    /// Try fetching `<url>.sha256`; if the body contains a 64-hex digest,
    /// prefill the integrity field. Also HEAD `.asc` and `.sig` siblings; if
    /// one exists, note it for the UI as a "detached signature available"
    /// hint (we don't verify GPG — that'd need gpg tooling).
    ///
    /// Beyond the legacy two probes, kicks off the full `Enrichment.probe`
    /// in parallel — that one covers `.torrent`, `.metalink`, and
    /// `.splynek-manifest` siblings and publishes to `enrichment` for
    /// the UI to badge. Also checks for a duplicate against history so
    /// the user can see "you already have this" before clicking Start.
    func autoDetectSha256(for url: URL) async {
        // Reset state for the new URL so stale badges don't linger.
        await MainActor.run {
            self.enrichment = EnrichmentReport()
            self.duplicate = Duplicate.findMatch(for: url, in: self.history)
        }
        async let shaTask: Void = detectSha256Sibling(for: url)
        async let sigTask: Void = detectSignatureSibling(for: url)
        async let enrichTask = Enrichment.probe(url)
        let (_, _, report) = await (shaTask, sigTask, enrichTask)
        await MainActor.run {
            self.enrichment = report
            // Auto-apply the Merkle manifest if we found one and no
            // manifest is already loaded — chunk integrity is a pure
            // win with no user interaction needed.
            if self.merkleManifest == nil, let manURL = report.splynekManifest {
                Task { await self.autoLoadMerkleManifest(from: manURL) }
            }
            // Auto-apply the metalink mirrors the same way.
            if self.mirrors.isEmpty, let metaURL = report.metalink {
                Task { await self.autoLoadMetalink(from: metaURL) }
            }
        }
    }

    /// Fetch and parse a `.splynek-manifest` sibling we discovered via
    /// HEAD; if the JSON decodes cleanly, assign it to `merkleManifest`.
    /// Silent on failure — the user can still download without it.
    private func autoLoadMerkleManifest(from url: URL) async {
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let manifest = try? JSONDecoder().decode(MerkleManifest.self, from: data)
        else { return }
        await MainActor.run {
            if self.merkleManifest == nil { self.merkleManifest = manifest }
        }
    }

    /// Fetch and parse a `.metalink` / `.meta4` sibling we discovered via
    /// HEAD; if it parses, populate the mirror list. Silent on failure.
    private func autoLoadMetalink(from url: URL) async {
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let file = try? Metalink.parse(data)
        else { return }
        await MainActor.run {
            if self.mirrors.isEmpty { self.mirrors = file.urls }
            if self.sha256Expected.isEmpty, let sha = file.sha256 {
                self.sha256Expected = sha
            }
        }
    }

    /// Clear the duplicate banner so the user can see the form again.
    func dismissDuplicate() { duplicate = nil }

    /// "Re-download anyway" from the duplicate banner — dismiss the
    /// banner and run the normal start path.
    func overrideDuplicateAndStart() {
        duplicate = nil
        start()
    }

    /// "Reveal" action — open Finder on the prior output file.
    func revealDuplicateInFinder() {
        guard let path = duplicate?.entry.outputPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func detectSha256Sibling(for url: URL) async {
        if !sha256Expected.isEmpty { return }
        let siblingURL = url.deletingLastPathComponent()
            .appendingPathComponent(url.lastPathComponent + ".sha256")
        var req = URLRequest(url: siblingURL)
        req.timeoutInterval = 5
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n") {
            let first = String(line.split(separator: " ").first ?? "")
            if first.count == 64, first.allSatisfy({ $0.isHexDigit }) {
                await MainActor.run { self.sha256Expected = first.lowercased() }
                return
            }
        }
    }

    private func detectSignatureSibling(for url: URL) async {
        for ext in ["asc", "sig"] {
            let sibling = url.deletingLastPathComponent()
                .appendingPathComponent(url.lastPathComponent + "." + ext)
            var req = URLRequest(url: sibling)
            req.httpMethod = "HEAD"
            req.timeoutInterval = 5
            if let (_, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode < 400 {
                await MainActor.run { self.detachedSignatureURL = sibling }
                return
            }
        }
    }

    // MARK: Torrent

    func loadTorrentFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Load"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let info = try TorrentFile.parse(contentsOf: url)
            self.torrentInfo = info
            self.suggestedFilename = info.name
            self.magnetInfoHash = nil
            self.magnetTrackers = []
            self.lastTorrentFilePath = url.path
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch {
            self.formErrorMessage = error.localizedDescription
        }
    }

    @Published var magnetText: String = ""
    @Published var magnetInfoHash: Data?
    @Published var magnetTrackers: [URL] = []
    @Published var magnetDisplayName: String?

    /// Parse the `magnet:?…` URI in `magnetText`, stash the info hash and
    /// trackers, and set a placeholder TorrentInfo so the UI can render the
    /// "start torrent" flow. The engine will upgrade this stub via BEP 9
    /// metadata exchange once peers arrive.
    func parseMagnet() {
        let trimmed = magnetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let m = try Magnet.parse(trimmed)
            magnetInfoHash = m.infoHash
            magnetTrackers = m.trackers
            magnetDisplayName = m.displayName
            // Stub info so the UI has something to show; will be replaced
            // once BEP 9 metadata exchange completes.
            let stubMeta: TorrentMetaVersion = m.isV2 ? .v2 : .v1
            torrentInfo = TorrentInfo(
                name: m.displayName ?? "magnet-\(m.infoHash.prefix(4).hexEncodedString)",
                totalLength: 0, pieceLength: 0, pieceHashes: [],
                infoHash: m.isV2 ? Data(count: 20) : m.infoHash,
                infoHashV2: m.infoHashV2,
                infoHashV2Short: m.infoHashV2?.prefix(20),
                announceURLs: m.trackers,
                files: [], isMultiFile: false,
                comment: nil, createdBy: nil,
                metaVersion: stubMeta,
                pieceLayers: [:]
            )
        } catch {
            self.formErrorMessage = error.localizedDescription
        }
    }

    func startTorrent() {
        guard !isTorrenting, let info = torrentInfo else { return }
        let chosen = interfaces.filter { selected.contains($0.name) && $0.nwInterface != nil }
        guard let iface = chosen.first else {
            formErrorMessage = "Select at least one interface for torrent mode."
            return
        }
        let fresh = TorrentProgress()
        torrentProgress = fresh
        // For multi-file torrents the engine writes under the user's output
        // directory with `info.name` as the root folder. For single-file
        // torrents it creates one file inside the output directory.
        outputPath = outputDirectory.appendingPathComponent(info.name)
        let engine = TorrentEngine(
            info: info, rootDirectory: outputDirectory,
            interface: iface, progress: fresh,
            extraTrackers: magnetTrackers,
            magnetInfoHash: magnetInfoHash
        )
        engine.seedAfterCompletion = seedAfterCompletion
        engine.seedWhileLeeching = seedWhileLeeching
        torrentEngine = engine
        isTorrenting = true
        torrentTask = Task { [weak self] in
            await engine.run()
            await MainActor.run { self?.isTorrenting = false }
        }
    }

    func cancelTorrent() {
        torrentEngine?.cancel()
        torrentTask?.cancel()
        isTorrenting = false
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = outputDirectory
        if panel.runModal() == .OK, let url = panel.url {
            outputDirectory = url
        }
    }

    func revealOutput() {
        guard let path = outputPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([path])
    }

    // MARK: Export as curl

    func copyCurlCommand() {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw) else { return }
        let chosen = interfaces.filter { selected.contains($0.name) }.map(\.name)
        let script = CurlExport.generate(
            .init(
                urls: [url],
                outputFilename: outputPath?.lastPathComponent ?? "download.bin",
                interfaces: chosen.isEmpty ? ["en0"] : chosen,
                sha256: sha256Expected.isEmpty ? nil : sha256Expected
            )
        )
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(script, forType: .string)
    }

    // MARK: Filename collision

    /// If `name` exists in `dir`, append " (1)", " (2)", etc. until a free slot.
    static func uniqueOutputPath(_ dir: URL, _ name: String) -> URL {
        let fm = FileManager.default
        let first = dir.appendingPathComponent(name)
        if !fm.fileExists(atPath: first.path) { return first }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 1
        while n < 10_000 {
            let candidate: String = ext.isEmpty
                ? "\(base) (\(n))"
                : "\(base) (\(n)).\(ext)"
            let url = dir.appendingPathComponent(candidate)
            if !fm.fileExists(atPath: url.path) { return url }
            n += 1
        }
        return first  // give up and overwrite; unreachable in practice
    }
}
