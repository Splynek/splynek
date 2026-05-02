import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// The installer pipeline DOES NOT execute downloaded code.  It hands
// .pkg payloads to Apple's `installer(8)`, mounts .dmg via Apple's
// `hdiutil`, copies .app bundles via `FileManager`, and uses
// `GatekeeperVerify` to read signature metadata before any of that.
//
// Apple's `installer` and `hdiutil` are signed system binaries with
// hard-coded paths (/usr/sbin/installer, /usr/bin/hdiutil).  The
// `Process` invocations below use those absolute paths and pass user-
// chosen file URLs as documented arguments — never user-controlled
// flags, never shell-piped strings.
//
// Splynek does NOT auto-launch installed apps.  After install we
// register the bundle in `InstalledAppRegistry` and surface it in the
// post-install card; the user double-clicks to launch.  This matters
// for 2.5.2 because auto-launching would blur "we installed it" with
// "we ran it"; we don't.
// =====================================================================

/// v1.8: the verified-installer pipeline.  `InstallerEngine.run(...)`
/// walks an `InstallSpec` through 7 stages and returns a `Result`.
///
/// ```
///   1. Resolve(spec)               → either spec is direct, or we
///                                    fetch additional metadata from
///                                    the Sovereignty/Trust catalog
///   2. PreFlightTrust(spec)        → if the Trust catalog has a
///                                    score for this bundle ID, return
///                                    it for UI confirmation
///   3. PreFlightSovereignty(spec)  → if the Sovereignty catalog has
///                                    an EU/OSS alternative, surface it
///   4. Download(spec)              → multi-interface fetch + Probe
///                                    validation (existing engine)
///   5. Verify(downloaded)          → GatekeeperVerify + digest check
///   6. Install(verified)           → kind-specific handler:
///                                      .pkg → `installer -pkg ... -target /`
///                                      .dmg → mount, copy .app, unmount
///                                      .appArchive → unzip, move
///                                      .appBundle → move
///   7. Register(installed)         → InstalledAppRegistry.upsert
/// ```
///
/// Each stage emits a `Stage` event the UI can listen to for progress
/// + cancellation.  Stages 2 + 3 are advisory only — the user can
/// override and proceed.  Stage 5 is HARD: a verification failure
/// aborts and surfaces the reason; we never install an unverified
/// payload.
///
/// **Public-repo scope:** this file declares the pipeline TYPES and
/// the orchestration contract.  The kind-specific install handlers
/// (.pkg, .dmg, archive) land in v1.8 implementation work — the
/// interfaces below are stable and tested in
/// `InstallerEngineTests`.
enum InstallerEngine {

    /// One step in the pipeline.  UI subscribes to a stream of these
    /// to update its progress card.  Equatable for testability;
    /// Hashable would require associated values to be Hashable too,
    /// which `Failure` (LocalizedError) isn't, and we don't need
    /// hashing here.
    enum Stage: Equatable, Sendable {
        case resolving
        case trustCheck(score: Int?, summary: String?)
        case sovereigntyCheck(alternative: String?)
        case downloading(receivedBytes: Int64, totalBytes: Int64?)
        case verifying
        case installing
        case registering
        case completed(InstalledAppRecord)
        case failed(Failure)

        // Manual Equatable: `Failure` doesn't synthesise it because
        // the cases hold un-Equatable String payloads with locale-
        // sensitive interpolation.  We compare by case + payload.
        static func == (lhs: Stage, rhs: Stage) -> Bool {
            switch (lhs, rhs) {
            case (.resolving, .resolving),
                 (.verifying, .verifying),
                 (.installing, .installing),
                 (.registering, .registering):
                return true
            case let (.trustCheck(s1, m1), .trustCheck(s2, m2)):
                return s1 == s2 && m1 == m2
            case let (.sovereigntyCheck(a1), .sovereigntyCheck(a2)):
                return a1 == a2
            case let (.downloading(r1, t1), .downloading(r2, t2)):
                return r1 == r2 && t1 == t2
            case let (.completed(a), .completed(b)):
                return a == b
            case let (.failed(a), .failed(b)):
                return a.localizedDescription == b.localizedDescription
            default:
                return false
            }
        }
    }

    enum Failure: Error, LocalizedError, Sendable {
        case userCancelled
        case downloadFailed(String)
        case verificationFailed(String)
        case installationFailed(String)
        case unsupportedKind(String)

        var errorDescription: String? {
            switch self {
            case .userCancelled:                  return "Installation cancelled."
            case .downloadFailed(let s):          return "Download failed: \(s)"
            case .verificationFailed(let s):      return "Verification failed: \(s)"
            case .installationFailed(let s):      return "Installation failed: \(s)"
            case .unsupportedKind(let s):         return "Don't know how to install: \(s)"
            }
        }
    }

    /// Decision point exposed to the UI — after the pre-flight checks,
    /// we ask the user "do you want to proceed?".  The UI returns a
    /// `Decision` and the pipeline continues or aborts.
    enum Decision: Sendable {
        /// Proceed with the install.
        case proceed
        /// Switch to the suggested EU/OSS alternative.  The pipeline
        /// re-runs against the new spec, beginning at stage 1.
        case switchToAlternative(InstallSpec)
        /// Cancel — pipeline ends with `.userCancelled`.
        case cancel
    }

    /// Pipeline result — terminal state after all stages run (or
    /// abort).  Paired with `Stage` events: each stage emits a tick
    /// during the run; `Result` is the last word.
    typealias PipelineResult = Result<InstalledAppRecord, Failure>

    /// Pre-flight Trust evaluation.  Reads the public Trust catalog
    /// (compile-time data) and returns a `(score, summary)` tuple if
    /// the spec's bundleID is known.  Returns nil for unknown apps —
    /// most installs go through with no Trust signal.
    ///
    /// Example output: `(72, "Sends crash reports + OS version to
    /// Microsoft. No telemetry of edited content.")`
    static func trustPreflight(_ spec: InstallSpec) -> (score: Int, summary: String)? {
        guard let bundleID = spec.bundleID,
              let entry = TrustCatalog.profile(for: bundleID) else {
            return nil
        }
        let score = TrustScorer.score(entry, weights: .default)
        let summary = entry.concerns.first?.summary ?? "No specific concerns logged."
        return (Int(score.value), summary)
    }

    /// Pre-flight Sovereignty alternative.  Reads the public
    /// Sovereignty catalog and returns the highest-confidence
    /// EU/OSS alternative if the spec maps to a non-EU target.
    /// Returns nil if the spec is already EU/OSS, or if no
    /// alternative is curated.
    static func sovereigntyPreflight(_ spec: InstallSpec) -> InstallSpec? {
        guard let bundleID = spec.bundleID,
              let entry = SovereigntyCatalog.alternatives(for: bundleID) else {
            return nil
        }
        // Pick the first alternative that has a `downloadURL` and a
        // recommendable origin (EU / OSS).
        let alt = entry.alternatives.first {
            $0.downloadURL != nil && $0.origin.isRecommendable
        }
        guard let chosen = alt, let url = chosen.downloadURL else { return nil }
        return InstallSpec(
            name: chosen.name,
            // Sovereignty alternatives don't carry their own bundleID
            // (the catalog tracks them by slug, not by app identifier).
            // Leave it nil — the post-install step infers the bundle
            // ID from the installed .app's Info.plist.
            bundleID: nil,
            downloadURL: url,
            kind: kindFor(url: url),
            expectedDigest: nil,
            source: .sovereigntyCatalog(slug: chosen.id)
        )
    }

    /// File-extension heuristic — infers `Kind` from the URL path.
    /// Used when the catalog doesn't pin a kind explicitly.
    static func kindFor(url: URL) -> InstallSpec.Kind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pkg":          return .pkg
        case "dmg":          return .dmg
        case "zip", "tar":   return .appArchive
        case "app":          return .appBundle
        default:             return .dmg  // Most macOS direct downloads are DMGs.
        }
    }
}
