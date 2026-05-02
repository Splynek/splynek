import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// AutoUpdateScheduler walks the InstalledAppRegistry, downloads each
// auto-update-enabled app's spec.downloadURL via the same code path
// the user-driven Install tab uses, and re-runs the verified
// installer pipeline.  Every install goes through
// `InstallerEngine.run` — same Trust + Sovereignty preflight, same
// SHA-256 + Gatekeeper verification, same kind-specific handlers.
// Auto-update is just a different *trigger* for the same code path,
// not a different code path.  No code generation, no behaviour
// outside the registered tool surface.
// =====================================================================

/// v1.8.2: periodic re-run of `InstallerEngine.run` against every
/// `InstalledAppRecord` whose `autoUpdate == true`.
///
/// **Trigger model.**  A repeating `Timer` fires every
/// `interval` seconds (default 6 hours).  At each tick the
/// scheduler:
///
///   1. Loads the latest registry (via `InstalledAppRegistry.load()`).
///   2. Filters to records with `autoUpdate == true`.
///   3. For each record, downloads `spec.downloadURL` to a staging
///      directory.  Using a stub `DownloadFunction` here keeps the
///      scheduler decoupled from the heavyweight DownloadEngine —
///      a real wire-up happens in the VM startup, but tests can
///      drop in a fixture.
///   4. Computes SHA-256 of the new payload.  If it matches the
///      previously-recorded `installedDigest`, the app is already
///      current; we skip.
///   5. Otherwise runs `InstallerEngine.run` against the new payload
///      with `replaceExisting: true`, then upserts the registry.
///
/// **Bounded concurrency.**  Updates run sequentially (1 at a time)
/// so we don't hammer the network on a fleet of 30 installed apps.
/// **Cancellation.**  `stop()` invalidates the timer and cancels the
/// in-flight task.
///
/// **Sandbox.**  Same as the user-driven path — relies on the
/// caller's already-granted file access.  No new entitlements.
///
/// **What this is NOT:**
///   - A push-notification system.  We don't tell the user
///     "Firefox 137.0 is available!" — they opted in to silent
///     auto-update for that specific app, so we just install it.
///     A future v1.8.x can add an "ask first" mode.
///   - A version-aware update check.  We compare *digests*, not
///     semver.  If the publisher's URL serves the same bytes,
///     no update; if the bytes differ at all, install.  Simple,
///     content-addressed, no version-string-parsing edge cases.
final class AutoUpdateScheduler: @unchecked Sendable {

    /// Closure that fetches a remote URL to a local file.  Production
    /// passes a closure that drives Splynek's multi-interface
    /// DownloadEngine; tests pass a fixture that returns a fixed
    /// path.  Returns the staged file URL on success, or throws.
    typealias DownloadFunction = @Sendable (
        _ url: URL,
        _ stagingDirectory: URL
    ) async throws -> URL

    private let interval: TimeInterval
    private let download: DownloadFunction
    private let now: @Sendable () -> Date
    private var timer: DispatchSourceTimer?
    private var task: Task<Void, Never>?
    private let queue = DispatchQueue(label: "app.splynek.AutoUpdateScheduler")

    /// `interval`: time between checks.  Default 6 hours.  Must be
    /// ≥ 60 s — anything tighter would hammer the publisher.
    init(
        interval: TimeInterval = 6 * 3600,
        download: @escaping DownloadFunction,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.interval = max(60, interval)
        self.download = download
        self.now = now
    }

    deinit { stop() }

    /// Begin firing.  First tick happens after `interval` seconds —
    /// callers that want an immediate sweep should call `runOnce()`
    /// before `start()`.
    func start() {
        stop()  // idempotent
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(
            deadline: .now() + interval,
            repeating: interval
        )
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
        task?.cancel()
        task = nil
    }

    /// One check pass.  Public so callers can run a manual sweep
    /// from a UI button.  The pass is async; the returned task lets
    /// callers await its completion (e.g. for tests).
    @discardableResult
    func runOnce() -> Task<Sweep, Never> {
        let task = Task<Sweep, Never> { [weak self] in
            guard let self else { return Sweep(updates: [], errors: []) }
            return await self.sweep()
        }
        return task
    }

    /// Result of one tick — used by tests and the UI to surface
    /// "we updated 2 apps and skipped 5."
    struct Sweep: Sendable {
        let updates: [Update]
        let errors: [(record: InstalledAppRecord, message: String)]

        struct Update: Sendable {
            let record: InstalledAppRecord
            let oldDigest: String?
            let newDigest: String
            let result: Result<InstalledAppRecord, InstallerEngine.Failure>
        }
    }

    // MARK: - Internals

    private func tick() {
        // Cancel any in-flight tick so we don't pile up if the user's
        // network is slow + the timer fires faster than work
        // completes.  Tick frequency is 6h default; this is mostly
        // belt-and-braces for low-interval test runs.
        task?.cancel()
        task = Task { [weak self] in
            _ = await self?.sweep()
        }
    }

    /// Walk the auto-update registry and check each candidate.
    /// Bounded concurrency = 1 (sequential).  Per-record errors are
    /// collected, never thrown — one failing app shouldn't prevent
    /// the others from updating.
    func sweep() async -> Sweep {
        var updates: [Sweep.Update] = []
        var errors: [(InstalledAppRecord, String)] = []

        let candidates = InstalledAppRegistry.autoUpdateCandidates()
        for record in candidates {
            if Task.isCancelled { break }
            do {
                let outcome = try await checkAndApply(record: record)
                if let update = outcome { updates.append(update) }
            } catch {
                errors.append((record, error.localizedDescription))
            }
        }

        return Sweep(updates: updates, errors: errors)
    }

    /// Check one record.  Returns `Sweep.Update` if a fresh install
    /// happened, nil if the digest matched (no-op).
    func checkAndApply(record: InstalledAppRecord) async throws -> Sweep.Update? {
        let stagingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("splynek-autoupdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: stagingDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: stagingDir)
        }

        let staged = try await download(record.spec.downloadURL, stagingDir)
        let digest: String
        switch InstallVerification.sha256(of: staged) {
        case .success(let h):
            digest = h
        case .failure(let err):
            throw err
        }

        if let oldDigest = record.installedDigest, oldDigest.lowercased() == digest.lowercased() {
            // Same bytes — no update needed.
            return nil
        }

        // Bytes differ → re-run the installer pipeline.
        let pipelineResult = await InstallerEngine.run(
            spec: record.spec,
            downloadedPayload: staged,
            replaceExisting: true,
            onStage: { _ in }
        )

        return Sweep.Update(
            record: record,
            oldDigest: record.installedDigest,
            newDigest: digest,
            result: pipelineResult
        )
    }
}
