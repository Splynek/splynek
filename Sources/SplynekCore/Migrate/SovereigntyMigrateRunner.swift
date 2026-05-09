import Foundation
import AppKit

/// **Sovereignty Migrate runner** — Sprint 2 part-2 (2026-05-09).
///
/// Executes one `SovereigntyMigrateStep` at a time, records the
/// outcome.  Mutating steps require the caller to have already
/// gathered explicit user confirmation — the runner trusts the
/// caller for consent (the wizard view is what actually shows
/// the confirmation prompt).
///
/// MAS posture: every action either opens a URL via NSWorkspace
/// (always allowed; equivalent to clicking a link) or writes to
/// our own Application Support file (`migrate-review-list.json`).
/// The brew-cask step opens Terminal with a pre-typed `brew`
/// command — Splynek itself never runs as root, never elevates,
/// never silently mutates the user's brew install state.
enum SovereigntyMigrateRunner {

    enum StepOutcome: Equatable, Sendable {
        case completed
        case skipped(reason: String)
        case failed(reason: String)
    }

    /// Execute a single step.  Returns the outcome the wizard UI
    /// should display in the row's status pill.
    @MainActor
    static func run(
        step: SovereigntyMigrateStep,
        plan: SovereigntyMigratePlan,
        reviewStore: SovereigntyMigrateReviewStore = SovereigntyMigrateReviewStore()
    ) -> StepOutcome {
        switch step.action {
        case .openHomepage, .openAppStore, .openDataExport:
            guard let url = step.url else {
                return .failed(reason: "Step had no URL.")
            }
            NSWorkspace.shared.open(url)
            return .completed

        case .brewInstallCask:
            guard let token = step.brewToken, !token.isEmpty else {
                return .skipped(reason: "No Homebrew cask token for this alternative.")
            }
            // Open Terminal.app with the brew command pre-typed
            // via AppleScript.  We never run brew ourselves; the
            // user kicks it off + sees the output.
            let cmd = "brew install --cask \(token)"
            let script = """
            tell application "Terminal"
                activate
                do script "\(cmd)"
            end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    let msg = error[NSAppleScript.errorMessage] as? String ?? "AppleScript error"
                    return .failed(reason: msg)
                }
                return .completed
            }
            return .failed(reason: "Couldn't dispatch Terminal command.")

        case .markOriginalForReview:
            let entry = SovereigntyMigrateReviewEntry(
                bundleID: plan.originalBundleID,
                originalDisplayName: plan.originalDisplayName,
                alternativeName: plan.alternativeName,
                alternativeHomepage: plan.alternativeHomepage,
                markedAt: ISO8601DateFormatter.shared.string(from: Date())
            )
            reviewStore.mutate { $0.upsert(entry) }
            return .completed
        }
    }
}

// MARK: - Helper

private extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
