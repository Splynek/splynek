import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// `InstallerEngine.run` is the v1.8 pipeline orchestrator.  It walks
// the spec through the seven declared stages — preflight → download
// → verify → install → register — and emits `Stage` events to the
// caller's progress callback.  Every code path the pipeline can take
// is visible in this extension.  No code generation, no dynamic
// dispatch beyond the InstallSpec.Kind switch.  See MAS-2.5.2-
// COMPLIANCE.md (Invariant 4 + Invariant 7) for the reviewer-facing
// breakdown.
// =====================================================================

extension InstallerEngine {

    /// Run the full installer pipeline against a spec.
    ///
    /// - Parameters:
    ///   - spec: what to install.  Built by the caller from a
    ///     Sovereignty/Trust catalog entry, a Homebrew-Cask record,
    ///     or a direct URL.
    ///   - downloadedPayload: the .pkg / .dmg / .app / .zip already
    ///     on disk.  v1.8 takes the *post-download* path because
    ///     the existing multi-interface engine + history layer
    ///     already orchestrate the download itself; this engine
    ///     is purely the verify-and-install half.  A future
    ///     v1.8.x may collapse this into one call.
    ///   - destinationDirectory: usually `/Applications`.  Pass a
    ///     user-picked URL (with active security scope) for
    ///     non-default installs.
    ///   - replaceExisting: if true, an existing install of the
    ///     same .app name is moved to the trash before the new one
    ///     is copied in.  Default: false (suffix-rename instead).
    ///   - onStage: progress callback fired for every stage
    ///     transition.  Caller updates the UI from here.
    ///
    /// - Returns: success → `InstalledAppRecord` upserted to the
    ///   `InstalledAppRegistry`; failure → typed `Failure`.
    static func run(
        spec: InstallSpec,
        downloadedPayload: URL,
        destinationDirectory: URL = URL(fileURLWithPath: "/Applications"),
        replaceExisting: Bool = false,
        onStage: @Sendable @escaping (Stage) -> Void = { _ in }
    ) async -> PipelineResult {

        // Stage 1 — Resolve.  Today this is a no-op (the spec is
        // already resolved by the caller).  v1.8.x will use it for
        // catalog-driven enrichment ("look up Firefox" → spec).
        onStage(.resolving)

        // Stage 2 — Trust preflight.  Advisory; the UI may show this
        // and ask the user to confirm before proceeding.
        if let trust = trustPreflight(spec) {
            onStage(.trustCheck(score: trust.score, summary: trust.summary))
        } else {
            onStage(.trustCheck(score: nil, summary: nil))
        }

        // Stage 3 — Sovereignty preflight.  Advisory.  The UI may
        // surface the alternative + offer a one-click switch.
        if let alt = sovereigntyPreflight(spec) {
            onStage(.sovereigntyCheck(alternative: alt.name))
        } else {
            onStage(.sovereigntyCheck(alternative: nil))
        }

        // Stage 4 — Download is already done by the caller in v1.8.
        // Emit a stage event noting the payload is ready, but skip
        // the actual fetch (existing engine handles that).
        let attrs = (try? FileManager.default.attributesOfItem(atPath: downloadedPayload.path)) ?? [:]
        let totalBytes = (attrs[.size] as? Int64) ?? 0
        onStage(.downloading(receivedBytes: totalBytes, totalBytes: totalBytes))

        // Stage 5 — Verify (HARD: failure aborts).
        onStage(.verifying)
        let verdict = await InstallVerification.verify(
            payload: downloadedPayload,
            expectedDigest: spec.expectedDigest
        )
        switch verdict {
        case .ok:
            break
        case .digestMismatch(let expected, let actual):
            let f = Failure.verificationFailed(
                "SHA-256 mismatch — expected \(expected.prefix(12))…, got \(actual.prefix(12))…"
            )
            onStage(.failed(f))
            return .failure(f)
        case .gatekeeperRejected(let reason):
            let f = Failure.verificationFailed(reason)
            onStage(.failed(f))
            return .failure(f)
        case .ioError(let msg):
            let f = Failure.verificationFailed(msg)
            onStage(.failed(f))
            return .failure(f)
        }

        // Stage 6 — Install.  Switch on the spec's kind.
        onStage(.installing)
        let outcome: AppMover.Outcome
        do {
            switch spec.kind {
            case .appBundle:
                outcome = try AppMover.install(
                    source: downloadedPayload,
                    destinationDirectory: destinationDirectory,
                    replaceExisting: replaceExisting
                )
            case .dmg:
                outcome = try await DmgInstaller.install(
                    dmg: downloadedPayload,
                    destinationDirectory: destinationDirectory,
                    replaceExisting: replaceExisting
                )
            case .pkg:
                // .pkg requires Authorization-framework admin auth and
                // /usr/sbin/installer.  v1.8 ships only .app and .dmg
                // handlers; .pkg lands in v1.8.1.
                let f = Failure.unsupportedKind(".pkg installs land in v1.8.1.")
                onStage(.failed(f))
                return .failure(f)
            case .appArchive:
                // .zip extraction wraps Apple's signed /usr/bin/ditto
                // (preserves resource forks, code-signed quarantine
                // bits, etc.).  v1.8.1.
                let f = Failure.unsupportedKind(".zip / .tar archive installs land in v1.8.1.")
                onStage(.failed(f))
                return .failure(f)
            }
        } catch let appMoverErr as AppMover.Failure {
            let f = Failure.installationFailed(appMoverErr.errorDescription ?? "Unknown.")
            onStage(.failed(f))
            return .failure(f)
        } catch let dmgErr as DmgInstaller.Failure {
            let f = Failure.installationFailed(dmgErr.errorDescription ?? "Unknown.")
            onStage(.failed(f))
            return .failure(f)
        } catch {
            let f = Failure.installationFailed(error.localizedDescription)
            onStage(.failed(f))
            return .failure(f)
        }

        // Stage 7 — Register in the InstalledAppRegistry.
        onStage(.registering)
        let installedDigest: String? = {
            switch InstallVerification.sha256(of: downloadedPayload) {
            case .success(let hex): return hex
            case .failure:          return nil
            }
        }()
        let record = InstalledAppRecord(
            id: UUID(),
            spec: spec,
            installedAt: outcome.installedAt,
            installedVersion: outcome.displayVersion,
            installedDate: Date(),
            installedDigest: installedDigest,
            autoUpdate: false  // off by default; user opts in from the post-install card
        )
        InstalledAppRegistry.upsert(record)

        onStage(.completed(record))
        return .success(record)
    }
}
