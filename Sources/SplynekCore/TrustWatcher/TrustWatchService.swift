import Foundation
import os

/// Runtime fetcher + diff engine for the Trust Watcher.
///
/// Use one instance per process.  Activate via `start()` (sets up
/// the daily timer); deactivate via `stop()`.  Manual one-shot
/// runs available via `runOnce(...)` for the "Run now" button.
///
/// Pro-gated: the `TrustWatchService` is constructed in
/// `SplynekViewModel` only when `license.isPro` is true, and torn
/// down when the license drops back to free.  Free-tier users
/// never see Trust Watcher activity.
///
/// Architectural invariant (MAS-2.5.2): no LLM is ever invoked
/// from this file.  All comparisons are pure SHA-256 equality.
public actor TrustWatchService {

    // MARK: - Configuration

    /// How often `start()` re-runs the sweep automatically.
    /// Default 24h; can be lowered to 1h in tests.
    private let sweepInterval: TimeInterval

    /// HTTP timeout per fetched URL.  Policies are static text,
    /// so 30 s is generous; we don't want a single slow vendor
    /// stalling the whole sweep.
    private let perRequestTimeout: TimeInterval

    /// Subset of `TrustWatchCatalog.targets` to actually watch.
    /// Defaults to the full catalog filtered to apps the user
    /// actually has installed (set by `setActiveTargets(_:)`).
    private var activeTargets: [TrustWatchTarget]

    /// Bundled catalog the active list is filtered from.  Held
    /// so a re-scan can refresh `activeTargets` without going
    /// back to `SovereigntyScanner`.
    private let allTargets: [TrustWatchTarget]

    // MARK: - Persistence + URL session

    private let store: TrustWatchStoreFile
    private let urlSession: URLSession

    // MARK: - Sweep state

    private var sweepTask: Task<Void, Never>?
    private var isRunning = false

    /// Logger.  Subsystem matches the rest of Splynek.
    private static let log = Logger(
        subsystem: "app.splynek",
        category: "TrustWatcher"
    )

    // MARK: - Init

    public init(store: TrustWatchStoreFile = TrustWatchStoreFile(),
                allTargets: [TrustWatchTarget] = TrustWatchCatalog.targets,
                sweepInterval: TimeInterval = 24 * 60 * 60,
                perRequestTimeout: TimeInterval = 30,
                urlSession: URLSession? = nil) {
        self.store = store
        self.allTargets = allTargets
        self.activeTargets = allTargets
        self.sweepInterval = sweepInterval
        self.perRequestTimeout = perRequestTimeout
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = perRequestTimeout
            config.timeoutIntervalForResource = perRequestTimeout * 2
            // Standard Splynek UA — same as DownloadEngine.
            config.httpAdditionalHeaders = [
                "User-Agent": "Splynek/\(SplynekVersion.current)"
            ]
            self.urlSession = URLSession(configuration: config)
        }
    }

    // MARK: - Public API

    /// Filter the watch list to only apps the user has installed.
    /// Pass the union of bundle IDs from `SovereigntyScanner`.
    /// Empty input = watch nothing (active deactivation).
    public func setActiveTargets(installedBundleIDs: Set<String>) {
        if installedBundleIDs.isEmpty {
            activeTargets = []
        } else {
            activeTargets = allTargets.filter {
                installedBundleIDs.contains($0.bundleID)
            }
        }
        Self.log.info("TrustWatcher active targets: \(self.activeTargets.count, privacy: .public)")
    }

    /// Begin the daily sweep loop.  Idempotent.  The first sweep
    /// runs immediately (after a 5-second grace period to let
    /// the app finish booting); subsequent sweeps fire every
    /// `sweepInterval` seconds.
    public func start() {
        guard sweepTask == nil else { return }
        sweepTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            while !Task.isCancelled {
                _ = await self.runOnce()
                try? await Task.sleep(nanoseconds: UInt64(await self.sweepInterval * 1_000_000_000))
            }
        }
    }

    /// Stop the daily sweep loop.  Any in-flight sweep finishes
    /// before the task fully exits.
    public func stop() {
        sweepTask?.cancel()
        sweepTask = nil
    }

    /// Run a single sweep over `activeTargets`.  Returns the list
    /// of alerts emitted during this run.  Safe to call from the
    /// "Run now" UI button — internal mutex prevents overlapping
    /// sweeps.
    @discardableResult
    public func runOnce() async -> [TrustWatchAlert] {
        guard !isRunning else { return [] }
        isRunning = true
        defer { isRunning = false }

        let started = Date()
        Self.log.info("TrustWatcher sweep start: \(self.activeTargets.count) targets")

        var newAlerts: [TrustWatchAlert] = []

        for target in activeTargets {
            if Task.isCancelled { break }
            let snapshot = await fetchAndHash(target: target)
            let key = TrustWatchStore.key(for: target)
            store.mutate { state in
                let prev = state.snapshots[key]
                state.snapshots[key] = snapshot
                if let prev,
                   let alert = TrustWatcher.diff(previous: prev, current: snapshot) {
                    state.recordAlert(alert)
                    newAlerts.append(alert)
                }
            }
        }

        store.mutate { state in
            state.lastSweepAt = TrustWatcher.iso8601(Date())
        }

        let elapsed = Date().timeIntervalSince(started)
        Self.log.info(
            "TrustWatcher sweep done in \(elapsed, format: .fixed(precision: 1))s, \(newAlerts.count) new alerts"
        )
        return newAlerts
    }

    /// Read-only snapshot of the current alert log + sweep state.
    /// UI calls this instead of touching the store directly.
    public func currentState() -> TrustWatchStore {
        store.read()
    }

    /// Mark a single alert acknowledged.  Persists immediately.
    public func acknowledge(alertID: String) {
        store.mutate { $0.acknowledge(alertID: alertID) }
    }

    /// Mark every alert acknowledged.
    public func acknowledgeAll() {
        store.mutate { $0.acknowledgeAll() }
    }

    // MARK: - Internal: HTTP fetch + hash

    /// Fetch a single target's URL, normalise the body, hash it.
    /// Returns a snapshot regardless of HTTP status — non-200
    /// responses are stored but never trigger alerts (see
    /// `TrustWatcher.diff(...)`).
    private func fetchAndHash(target: TrustWatchTarget) async -> TrustWatchSnapshot {
        let now = TrustWatcher.iso8601(Date())
        var req = URLRequest(url: target.url)
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        // No cookies / no Referer / no Origin — we're just a
        // public-document reader.
        req.httpShouldHandleCookies = false
        do {
            let (data, response) = try await urlSession.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            // Decode best-effort — some vendors serve UTF-8 with
            // a BOM or Latin-1.  Fall back to UTF-8 lossy.
            let body = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            let normalised = TrustWatcher.normalize(body)
            let hash = TrustWatcher.sha256Hex(normalised)
            return TrustWatchSnapshot(
                target: target,
                bodyHash: hash,
                bodyLength: normalised.utf8.count,
                observedAt: now,
                httpStatus: status
            )
        } catch {
            Self.log.notice(
                "TrustWatcher fetch failed for \(target.url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return TrustWatchSnapshot(
                target: target,
                bodyHash: "",
                bodyLength: 0,
                observedAt: now,
                httpStatus: 0
            )
        }
    }
}
