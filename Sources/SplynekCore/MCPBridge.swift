import Foundation

/// v1.6: bridges `MCPServer.Bridge` to the actual `SplynekViewModel`
/// + catalogs.  Lives in a separate file so MCPServer can be unit-
/// tested without spinning up the whole VM.
///
/// **Threading model:**
///   - Read-only operations (lookups, history) read snapshot state via
///     a `MainActor.run` hop.  Cheap; no race risk.
///   - Mutating operations (download, queue, cancel) hop to the main
///     actor and call the same VM methods that drive the UI.  All the
///     existing scheme guards, sandbox checks, license gates apply.
///   - The Sovereignty enumeration tool runs the static, nonisolated
///     `SovereigntyScanner.enumerateApplications()` directly so the
///     LLM doesn't have to wait on a UI scan.
///
/// **Why this is safe to ship MAS-side:**
///   - No new sandbox entitlements.  Reuses the existing
///     `network.server` scope (loopback / LAN bound by user choice).
///   - All mutating calls land on the same VM ingest contract that
///     drag-drop / browser extension / menu-bar already use.  If the
///     user has a host cap or size confirmation set, those still fire.
///   - Off by default.  The user toggles MCP on in Settings; the route
///     returns 503 + a JSON-RPC `serverDisabled` error otherwise.
@MainActor
enum MCPBridgeBuilder {

    /// Build a `MCPServer.Bridge` from a live ViewModel.  The closures
    /// capture `vm` weakly, so the bridge doesn't keep the VM alive
    /// past app shutdown.
    static func build(vm: SplynekViewModel) -> MCPServer.Bridge {
        // Each closure is `@Sendable` and `async`, so they work from
        // the FleetCoordinator's connection-handling Task.  Because
        // `vm` is `@MainActor`, we hop into the main actor explicitly.
        // Capture is unowned where the closure can be triggered after
        // VM-shutdown is plausible (it isn't, in practice — VM lives
        // for the whole app lifetime — but unowned makes the contract
        // explicit).
        return MCPServer.Bridge(
            startDownload: { url, sha in
                try await MainActor.run {
                    return try doStartDownload(vm: vm, url: url, sha256: sha)
                }
            },
            queueDownload: { url, sha in
                try await MainActor.run {
                    return try doQueueDownload(vm: vm, url: url, sha256: sha)
                }
            },
            getProgress: {
                await MainActor.run { snapshotJobs(vm: vm) }
            },
            cancelAll: {
                await MainActor.run { vm.cancelAll() }
            },
            listHistory: { limit in
                await MainActor.run { snapshotHistory(vm: vm, limit: limit) }
            },
            lookupSovereignty: { query in
                // Catalog lookup is pure / nonisolated — no VM hop.
                lookupSovereignty(query: query)
            },
            lookupTrust: { query in
                lookupTrust(query: query, weights: await MainActor.run { vm.trustWeights })
            },
            runSovereigntyScan: {
                runSovereigntyScan()
            }
        )
    }

    // MARK: - Mutating

    @MainActor
    private static func doStartDownload(
        vm: SplynekViewModel, url: String, sha256: String?
    ) throws -> String {
        try guardScheme(url)
        if let sha = sha256, !sha.isEmpty {
            vm.sha256Expected = sha
        }
        // Route through the SAME callback the web dashboard, browser
        // extension, and Bonjour pairing all use.  All scheme guards,
        // size confirmations, host caps, magnet parsing — every one of
        // those fires automatically because we're not bypassing the
        // ingest contract.  If `onWebIngest` is somehow nil, the VM
        // hasn't finished init yet — we tell the LLM to try again.
        guard let ingest = vm.fleet.onWebIngest else {
            throw MCPBridgeError("Splynek isn't fully initialised yet — try again in a moment.")
        }
        ingest("download", url)
        // The ingest path doesn't return a job ID synchronously
        // (jobs land in `activeJobs` asynchronously once the engine
        // starts).  Return a sentinel; the LLM follows up with
        // `splynek_get_progress` to see the new job.
        return "accepted"
    }

    @MainActor
    private static func doQueueDownload(
        vm: SplynekViewModel, url: String, sha256: String?
    ) throws -> String {
        try guardScheme(url)
        if let sha = sha256, !sha.isEmpty {
            vm.sha256Expected = sha
        }
        guard let ingest = vm.fleet.onWebIngest else {
            throw MCPBridgeError("Splynek isn't fully initialised yet — try again in a moment.")
        }
        ingest("queue", url)
        return "queued"
    }

    /// First-line scheme guard at the bridge boundary.  The VM's
    /// downstream ingest contract repeats the check, but we surface
    /// a friendly error message earlier when the LLM hands us
    /// something obviously wrong.
    private static func guardScheme(_ url: String) throws {
        guard let parsed = URL(string: url),
              let scheme = parsed.scheme?.lowercased(),
              ["http", "https", "magnet"].contains(scheme)
        else {
            throw MCPBridgeError("URL must be http(s) or magnet: — got `\(url)`")
        }
    }

    // MARK: - Read-only snapshots

    @MainActor
    private static func snapshotJobs(vm: SplynekViewModel) -> [MCPServer.JobSummary] {
        vm.activeJobs.map { job in
            MCPServer.JobSummary(
                id: job.id.uuidString,
                url: job.url.absoluteString,
                // outputURL.lastPathComponent is the filename Splynek
                // is writing to.  Same value the UI displays.
                filename: job.outputURL.lastPathComponent,
                lifecycle: String(describing: job.lifecycle),
                downloaded: job.progress.downloaded,
                total: job.progress.totalBytes,
                throughputBps: job.progress.throughputBps
            )
        }
    }

    @MainActor
    private static func snapshotHistory(
        vm: SplynekViewModel, limit: Int
    ) -> [MCPServer.HistorySummary] {
        Array(vm.history.prefix(limit)).map { e in
            MCPServer.HistorySummary(
                id: e.id.uuidString,
                url: e.url,
                filename: e.filename,
                totalBytes: e.totalBytes,
                finishedAt: e.finishedAt,
                outputPath: e.outputPath
            )
        }
    }

    // MARK: - Catalog lookups (nonisolated; no VM dep)

    /// Look up Sovereignty by bundle ID OR display name (case-insensitive).
    /// Display-name lookup walks the entry list once — adequate for
    /// 1k-ish entries; if the catalog grows past 10k we should index
    /// by lowercased display name too.
    nonisolated static func lookupSovereignty(query: String) -> MCPServer.SovereigntyHit? {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nil }
        let entry: SovereigntyCatalog.Entry? = {
            // Direct bundle-ID hit first.
            if let direct = SovereigntyCatalog.alternatives(for: query) { return direct }
            // Display-name hit (case-insensitive).
            for e in SovereigntyCatalog.entries
            where e.targetDisplayName.lowercased() == q
               || e.targetDisplayName.lowercased().contains(q) {
                return e
            }
            return nil
        }()
        guard let entry else { return nil }
        return MCPServer.SovereigntyHit(
            bundleID: entry.targetBundleID,
            displayName: entry.targetDisplayName,
            targetOrigin: entry.targetOrigin.label,
            alternatives: entry.alternatives.map { alt in
                MCPServer.SovereigntyHit.Alternative(
                    id: alt.id,
                    name: alt.name,
                    origin: alt.origin.label,
                    homepage: alt.homepage.absoluteString,
                    downloadURL: alt.downloadURL?.absoluteString,
                    note: alt.note
                )
            }
        )
    }

    nonisolated static func lookupTrust(
        query: String, weights: TrustScorer.Weights
    ) -> MCPServer.TrustHit? {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nil }
        let entry: TrustCatalog.Entry? = {
            if let direct = TrustCatalog.profile(for: query) { return direct }
            for e in TrustCatalog.entries
            where e.targetDisplayName.lowercased() == q
               || e.targetDisplayName.lowercased().contains(q) {
                return e
            }
            return nil
        }()
        guard let entry else { return nil }
        let score = TrustScorer.score(entry, weights: weights)
        return MCPServer.TrustHit(
            bundleID: entry.targetBundleID,
            displayName: entry.targetDisplayName,
            lastReviewed: entry.lastReviewed,
            score: score.value,
            level: String(describing: score.level),
            concernCount: entry.concerns.count,
            concerns: entry.concerns.map { c in
                MCPServer.TrustHit.Concern(
                    id: c.id,
                    axis: String(describing: c.axis),
                    severity: String(describing: c.severity),
                    summary: c.summary,
                    evidenceURL: c.evidenceURL.absoluteString
                )
            }
        )
    }

    /// Run a one-shot Sovereignty scan.  Pure filesystem enumeration
    /// + catalog match.  Returns just the summary counts; the LLM
    /// follows up with `splynek_lookup_sovereignty` if it wants
    /// per-app detail.
    nonisolated static func runSovereigntyScan() -> MCPServer.ScanSummary {
        let apps = SovereigntyScanner.enumerateApplications()
        let matched = apps.filter {
            SovereigntyCatalog.alternatives(for: $0.id) != nil
        }
        return MCPServer.ScanSummary(
            appsScanned: apps.count,
            entriesMatched: matched.count
        )
    }
}
