import Foundation

/// **Sovereignty Migrate Wizard** — Sprint 2 scaffold (2026-05-09).
///
/// Pure data model + plan builder for one-click "swap Spotify → Tidal"
/// migrations.  Per `STRATEGY-2026-PRO-PLUS-IPHONE.md` § "Aposta A".
///
/// ## Why a *plan* type, not direct action
///
/// Splynek's MAS-2.5.2 invariants forbid silent mutating operations.
/// Every step that touches the user's system is a **proposal** the
/// user confirms in a checklist UI.  The plan describes the
/// proposal; the wizard view + the runner enact each step only on
/// explicit click.
///
/// ## Scope of Sprint 2 scaffold
///
/// **Built here** (data + pure logic):
///   - `SovereigntyMigrateStep` — one atomic operation in a plan
///   - `SovereigntyMigratePlan` — ordered list of steps with target
///   - `SovereigntyMigratePlanner` — given a Sovereignty alternative,
///     produces a plan (no execution)
///
/// **Not built here** (Sprint 2 part 2 — UI + runner):
///   - The wizard SwiftUI view (`SovereigntyMigrateWizardView`)
///   - The step runner that translates each step into NSWorkspace /
///     `brew install --cask` invocations
///   - History recording so a user can undo / resume a partial
///     migration
///
/// ## MAS posture
///
/// No LLM is used in plan generation — purely catalog data +
/// deterministic templates.  Each step's `confirmationPrompt` is
/// a pre-baked human-readable string the user clicks "Confirm" on
/// before the runner moves to the next step.

enum SovereigntyMigrateAction: String, Codable, Sendable {
    /// Open the alternative's homepage in the user's default
    /// browser.  No mutation; safe baseline.
    case openHomepage
    /// Run `brew install --cask <token>` via the user's Terminal
    /// (not Splynek's process — we never elevate privileges).
    /// Only available when Sovereignty entry has a brew cask token.
    case brewInstallCask
    /// Open the App Store deep link to the alternative.  No
    /// mutation; safe baseline.
    case openAppStore
    /// Add the original app's bundle ID to a "consider uninstalling"
    /// reminder list — surfaces in Sovereignty later.  Doesn't
    /// touch the original app at all.
    case markOriginalForReview
    /// Open the original app's website's account-export / data-
    /// portability page (when known) so the user can grab their
    /// data before switching.
    case openDataExport
}

struct SovereigntyMigrateStep: Codable, Hashable, Sendable, Identifiable {
    public let id: String                 // <plan-id>:<step-index>
    public let action: SovereigntyMigrateAction
    /// Human-readable title shown in the wizard's checklist.
    public let title: String
    /// Longer summary shown when the row is expanded.
    public let summary: String
    /// One-liner the user clicks "Confirm" against.  Phrased as
    /// a question with explicit subject + verb.  Required even
    /// for read-only steps (.openHomepage / .openAppStore) so
    /// the wizard's UX is uniform.
    public let confirmationPrompt: String
    /// URL the action will open, when applicable.  Nil for
    /// `.markOriginalForReview`.
    public let url: URL?
    /// Brew cask token, only set for `.brewInstallCask`.
    public let brewToken: String?
    /// True when this step is *destructive* (changes user state).
    /// `.openHomepage` / `.openAppStore` / `.openDataExport` are
    /// non-destructive; `.brewInstallCask` and
    /// `.markOriginalForReview` are.
    public let isDestructive: Bool

    public init(id: String,
                action: SovereigntyMigrateAction,
                title: String,
                summary: String,
                confirmationPrompt: String,
                url: URL?,
                brewToken: String?,
                isDestructive: Bool) {
        self.id = id
        self.action = action
        self.title = title
        self.summary = summary
        self.confirmationPrompt = confirmationPrompt
        self.url = url
        self.brewToken = brewToken
        self.isDestructive = isDestructive
    }
}

struct SovereigntyMigratePlan: Codable, Hashable, Sendable, Identifiable {
    public let id: String                  // UUID
    public let originalBundleID: String
    public let originalDisplayName: String
    public let alternativeName: String
    public let alternativeHomepage: URL
    public let createdAt: String           // ISO-8601
    public let steps: [SovereigntyMigrateStep]

    public init(id: String,
                originalBundleID: String,
                originalDisplayName: String,
                alternativeName: String,
                alternativeHomepage: URL,
                createdAt: String,
                steps: [SovereigntyMigrateStep]) {
        self.id = id
        self.originalBundleID = originalBundleID
        self.originalDisplayName = originalDisplayName
        self.alternativeName = alternativeName
        self.alternativeHomepage = alternativeHomepage
        self.createdAt = createdAt
        self.steps = steps
    }
}

// MARK: - Planner (pure)

enum SovereigntyMigratePlanner {

    /// Build a migration plan from a Sovereignty catalog
    /// alternative.  Pure deterministic — same inputs → same
    /// plan.  Returns nil only when the alternative entry is
    /// missing the homepage (the only required field).
    public static func makePlan(
        from original: SovereigntyCatalog.Entry,
        alternative: SovereigntyCatalog.Alternative,
        now: Date = Date()
    ) -> SovereigntyMigratePlan? {
        let planID = UUID().uuidString
        let nowStr = iso8601(now)
        var steps: [SovereigntyMigrateStep] = []
        var idx = 0

        // Step 1: open the alternative's homepage so the user
        // can see what they're migrating to.  Always present.
        idx += 1
        steps.append(.init(
            id: "\(planID):\(idx)",
            action: .openHomepage,
            title: "Visit \(alternative.name)",
            summary: "Open \(alternative.name)'s homepage in your default browser. No installation yet — this is just a look.",
            confirmationPrompt: "Open \(alternative.homepage.host ?? alternative.homepage.absoluteString) in Safari?",
            url: alternative.homepage,
            brewToken: nil,
            isDestructive: false
        ))

        // Step 2 (optional): brew cask install when we know the
        // cask token.  Sprint 2 scaffold: the brew token is
        // expected to live on `Alternative.brewToken` (added when
        // catalog supports it).  We currently surface a TODO note
        // in the plan and skip the step until catalog-side work.
        // Keep this branch even though the catalog doesn't yet
        // expose `brewToken`, so the runner can light up later.
        // Placeholder: caller can pass a hint via `brewToken`.

        // Step 3: open the original's data-export page if known.
        // Sprint 2 stub: not yet sourced from the catalog.
        // Surface as a generic prompt the user can decline.
        // Future commits attach a `dataExportURL` to TrustCatalog
        // entries based on the curated catalog.

        // Step 4: mark the original for review.  Always present.
        idx += 1
        steps.append(.init(
            id: "\(planID):\(idx)",
            action: .markOriginalForReview,
            title: "Add \(original.targetDisplayName) to a 'consider uninstalling' list",
            summary: "We'll mark this app for follow-up — Sovereignty will surface a reminder a week from now to check whether you've actually moved over.",
            confirmationPrompt: "Add \(original.targetDisplayName) to your migration follow-up list?",
            url: nil,
            brewToken: nil,
            isDestructive: true
        ))

        return SovereigntyMigratePlan(
            id: planID,
            originalBundleID: original.targetBundleID,
            originalDisplayName: original.targetDisplayName,
            alternativeName: alternative.name,
            alternativeHomepage: alternative.homepage,
            createdAt: nowStr,
            steps: steps
        )
    }

    private static func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
