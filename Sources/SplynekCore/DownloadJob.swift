import Foundation
import SwiftUI

/// One concurrent download. Owns its own `DownloadEngine`, `DownloadProgress`
/// and lifecycle state. The `ViewModel` keeps a list of these; the UI
/// iterates them.
///
/// Pause / Resume semantics:
///   - `pause()` cancels the engine (stops in-flight lanes) but leaves the
///     per-chunk sidecar on disk intact.
///   - `resume(...)` starts a fresh engine with identical parameters; the
///     engine's own sidecar detection picks up completed chunks.
///
/// Cancel vs. Pause:
///   - `cancel()` is a hard stop. The job stays in the list with state
///     `.cancelled`; the user can remove it.
///   - `pause()` is a soft stop. State goes to `.paused`; the progress
///     figures are retained so the UI can show "42% paused".
@MainActor
final class DownloadJob: ObservableObject, Identifiable {

    let id = UUID()

    // Immutable config captured when the job was created.
    let url: URL
    let outputURL: URL
    let interfaces: [DiscoveredInterface]
    let sha256Expected: String?
    let connectionsPerInterface: Int
    let useDoH: Bool
    let merkleManifest: MerkleManifest?
    let extraHeaders: [String: String]
    let sharedBuckets: [String: TokenBucket]
    /// Extra HTTP mirror URLs sourced from fleet peers (other Splynek Macs
    /// on the LAN that already have this file). Appended to the primary
    /// URL and distributed across sub-lanes round-robin.
    let fleetMirrors: [URL]

    let progress: DownloadProgress

    enum Lifecycle: Hashable {
        case pending, running, paused, completed, failed, cancelled
        var isActive: Bool { self == .running || self == .paused }
        var isTerminal: Bool { self == .completed || self == .failed || self == .cancelled }
    }

    @Published var lifecycle: Lifecycle = .pending

    private var engine: DownloadEngine?
    private var task: Task<Void, Never>?

    /// When true, the next natural completion should settle as `.paused`
    /// rather than `.cancelled`. Set by `pause()` before the engine cancel
    /// propagates.
    private var pauseRequested = false

    init(
        url: URL,
        outputURL: URL,
        interfaces: [DiscoveredInterface],
        sha256Expected: String?,
        connectionsPerInterface: Int,
        useDoH: Bool,
        merkleManifest: MerkleManifest?,
        extraHeaders: [String: String],
        sharedBuckets: [String: TokenBucket] = [:],
        fleetMirrors: [URL] = []
    ) {
        self.url = url
        self.outputURL = outputURL
        self.interfaces = interfaces
        self.sha256Expected = sha256Expected
        self.connectionsPerInterface = connectionsPerInterface
        self.useDoH = useDoH
        self.merkleManifest = merkleManifest
        self.extraHeaders = extraHeaders
        self.sharedBuckets = sharedBuckets
        self.fleetMirrors = fleetMirrors
        self.progress = DownloadProgress()
        self.progress.lanes = interfaces.map { LaneStats(interface: $0) }
    }

    // MARK: Lifecycle

    /// Start (or restart) the download. `onFinish` fires when the engine
    /// task exits — naturally complete, paused, cancelled, or failed.
    func start(onFinish: @escaping @MainActor (DownloadJob) -> Void) {
        guard lifecycle != .running else { return }
        lifecycle = .running
        pauseRequested = false
        let engine = DownloadEngine(
            urls: [url] + fleetMirrors,
            outputURL: outputURL,
            interfaces: interfaces,
            sha256Expected: sha256Expected,
            connectionsPerInterface: connectionsPerInterface,
            useDoH: useDoH,
            merkleManifest: merkleManifest,
            extraHeaders: extraHeaders,
            sharedBuckets: sharedBuckets,
            progress: progress
        )
        self.engine = engine
        task = Task { [weak self] in
            await engine.run()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.settleAfterRun()
                onFinish(self)
            }
        }
    }

    private func settleAfterRun() {
        // Derive final lifecycle based on what the engine wrote into
        // progress, and any user intent we captured on the way out.
        if progress.finished {
            lifecycle = .completed
        } else if pauseRequested {
            lifecycle = .paused
            // v0.46 fix: the engine writes "Cancelled." to
            // errorMessage whenever its cancelFlag fires, including
            // the user-initiated pause path. Leaving that stale
            // message behind made paused jobs look red-banner failed.
            // A user pause is not an error; clear the message.
            progress.errorMessage = nil
        } else if progress.errorMessage != nil {
            lifecycle = .failed
        } else {
            lifecycle = .cancelled
        }
        // v0.46 fix: reset the phase so the Live view's pipeline
        // strip doesn't keep highlighting "downloading" after the
        // engine has stopped. For completed jobs the engine already
        // set phase = .done; for paused/cancelled/failed we go back
        // to .pending so the strip reads as "not currently running."
        if lifecycle != .completed {
            progress.phase = .pending
        }
        engine = nil
        task = nil
    }

    /// Hard stop; job remains in the list as `.cancelled`.
    func cancel() {
        pauseRequested = false
        engine?.cancel()
        task?.cancel()
        if lifecycle != .running { lifecycle = .cancelled }
    }

    /// Soft stop; sidecar is retained so `resume()` can pick up from it.
    func pause() {
        guard lifecycle == .running else { return }
        pauseRequested = true
        engine?.cancel()
        // engine.cancel() races the cancel flag into the lane loops; the
        // natural run() exit path will flip lifecycle to .paused via
        // settleAfterRun().
    }

    /// Restart a paused (or failed) job. `onFinish` is re-registered.
    func resume(onFinish: @escaping @MainActor (DownloadJob) -> Void) {
        guard !lifecycle.isActive else { return }
        // The engine's own sidecar detection re-hydrates completed chunks,
        // so we just start a fresh one with identical parameters.
        start(onFinish: onFinish)
    }

    // MARK: Session restore

    /// Serializable snapshot of the job's configuration (not its running
    /// state — that's on disk in the sidecar).
    var snapshot: DownloadJobSnapshot {
        DownloadJobSnapshot(
            url: url.absoluteString,
            outputPath: outputURL.path,
            sha256: sha256Expected,
            connectionsPerInterface: connectionsPerInterface,
            useDoH: useDoH,
            extraHeaders: extraHeaders,
            merkleManifest: merkleManifest,
            interfaceNames: interfaces.map(\.name)
        )
    }

    /// Rebuild a job from a snapshot after a relaunch. The caller supplies
    /// the *current* interface list; we filter `snapshot.interfaceNames`
    /// against it. Restored jobs always land in `.paused` so the user can
    /// review before resuming.
    static func restored(
        from snapshot: DownloadJobSnapshot,
        currentInterfaces: [DiscoveredInterface],
        sharedBuckets: [String: TokenBucket]
    ) -> DownloadJob? {
        guard let url = URL(string: snapshot.url) else { return nil }
        let matched = currentInterfaces.filter {
            snapshot.interfaceNames.contains($0.name) && $0.nwInterface != nil
        }
        guard !matched.isEmpty else { return nil }
        let outURL = URL(fileURLWithPath: snapshot.outputPath)
        let job = DownloadJob(
            url: url,
            outputURL: outURL,
            interfaces: matched,
            sha256Expected: snapshot.sha256,
            connectionsPerInterface: snapshot.connectionsPerInterface,
            useDoH: snapshot.useDoH,
            merkleManifest: snapshot.merkleManifest,
            extraHeaders: snapshot.extraHeaders,
            sharedBuckets: sharedBuckets.filter { matched.map(\.name).contains($0.key) }
        )
        job.lifecycle = .paused
        return job
    }
}
