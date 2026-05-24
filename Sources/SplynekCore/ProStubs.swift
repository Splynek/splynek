import Foundation
import Combine

/// Free-tier stubs for the Pro API surface.
///
/// The Pro modules (AI Concierge, Recipes, Scheduling, LAN-exposed
/// Fleet, HMAC license) moved to the private `Splynek/splynek-pro`
/// repo at v0.44. They now ship only in the Mac App Store build of
/// Splynek.
///
/// This file provides API-compatible stubs so the public free-tier
/// DMG compiles cleanly against the same `ViewModel` / views as the
/// MAS build. Every stub returns the "free tier" answer:
/// - `LicenseManager.isPro` is always `false`
/// - `AIAssistant.detect()` returns `.unavailable`
/// - All AI query methods throw `UnavailableError`
/// - `DownloadSchedule.evaluate(...)` always returns `.allowed`
/// - `RecipeStore.load()` returns `[]`; `save()` is a no-op
///
/// Views gate their Pro UI on `vm.license.isPro`, which is always
/// false in the free build — Pro tabs never appear in the sidebar,
/// and the Pro-feature settings cards render a "Pro is on the Mac
/// App Store" placeholder instead of the unlock form.
///
/// The MAS build replaces these stubs with the real implementations
/// from the private `SplynekPro` Swift package via target-level
/// source exclusion. See the MAS Xcode project for how the swap
/// is wired.

// MARK: - LicenseManager (file-based for the 2026-06 direct-sale launch)

/// License manager for the direct-sale Mac DMG path.
///
/// 2026-06-08 launch — see `LAUNCH-WITHOUT-APPLE.md` for the full
/// strategy.  Splynek Pro licenses are Ed25519-signed `.splynekkey`
/// JSON files issued by the LemonSqueezy → Cloudflare Worker
/// pipeline.  Verification is offline against the public key baked
/// into this file at build time.
///
/// State machine:
/// - Init: try to load a persisted license from Application Support;
///   verify its signature; set `isPro = true` if valid, else `false`.
/// - `activate(fileURL:)`: read + verify a user-supplied license
///   file (double-clicked from email).  On success, copy to
///   Application Support and flip `isPro = true`.
/// - `deactivate()`: delete the persisted license and flip `isPro =
///   false` (used by the user-side "switch to free" Settings action;
///   not used by any anti-piracy path).
///
/// The MAS build substitutes a separate StoreKit-backed manager
/// (lives in the private splynek-pro target) via target-level source
/// exclusion.  Both builds expose the same public API (`isPro`,
/// `licensedEmail`, `lastUnlockError`, `deactivate()`) so the rest of
/// SplynekCore + Views compile against either.
final class LicenseManager: ObservableObject {

    /// The public Ed25519 key (base64-encoded raw 32 bytes) that the
    /// Cloudflare Worker signs licenses with.  Baked in at build time.
    ///
    /// **PLACEHOLDER** — the maintainer must replace this constant
    /// with the actual public key before the launch build.  See
    /// `LAUNCH-WITHOUT-APPLE.md` § 5.2 + the `D6 — Maintainer
    /// checklist` task.  Generation:
    ///
    /// ```bash
    /// swift -e '
    ///   import CryptoKit
    ///   let k = Curve25519.Signing.PrivateKey()
    ///   let priv = k.rawRepresentation.base64EncodedString()
    ///   let pub = k.publicKey.rawRepresentation.base64EncodedString()
    ///   print("PRIVATE (Worker secret):", priv)
    ///   print("PUBLIC  (this constant):", pub)
    /// '
    /// ```
    ///
    /// Until replaced, every license verification will fail with
    /// `Signature does not match the licence payload`, which is the
    /// correct safe-default (no fake Pro grants).
    static let publicKeyBase64 = "REPLACE_ME_WITH_LAUNCH_PUBLIC_KEY"

    @Published private(set) var isPro: Bool = false
    @Published private(set) var licensedEmail: String? = nil
    @Published var lastUnlockError: String?

    /// Override for tests + the splynek-pro MAS substitution.  Defaults
    /// to the build-time embedded public key.
    private let publicKeyBase64Override: String?

    /// On-disk location of the persisted license file.  Application
    /// Support / Splynek / license.splynekkey.
    private let licenseStoreURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Splynek", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("license.splynekkey")
    }()

    init(publicKeyOverride: String? = nil) {
        self.publicKeyBase64Override = publicKeyOverride
        loadPersistedLicense()
    }

    private var effectivePublicKey: String {
        publicKeyBase64Override ?? Self.publicKeyBase64
    }

    /// Try to load + verify the persisted license on launch.  If
    /// verification fails (signature mismatch, file corrupted, key
    /// rotated), `isPro` stays `false` and the file remains on disk
    /// — we don't delete it automatically because the user can
    /// always re-import a corrected version, and a transient
    /// CryptoKit failure shouldn't punish a legitimate Pro buyer.
    private func loadPersistedLicense() {
        guard FileManager.default.fileExists(atPath: licenseStoreURL.path) else {
            return
        }
        do {
            let file = try LicenseFile.read(from: licenseStoreURL)
            if file.verify(againstPublicKeyBase64: effectivePublicKey).isValid {
                isPro = true
                licensedEmail = file.email
            }
        } catch {
            // Persisted file unreadable — surface in error string but
            // don't crash.  Most likely "user manually edited the
            // file" or "key rotation in a future version."
            lastUnlockError = "Could not read persisted license: \(error.localizedDescription)"
        }
    }

    /// Verify + persist a user-supplied license file.  Called from
    /// `SplynekApp.application(_:open:)` when macOS routes a
    /// `.splynekkey` double-click to us.
    ///
    /// Returns `true` on a clean activation (`isPro` is now `true`).
    /// Returns `false` on any failure; `lastUnlockError` carries the
    /// human-readable reason for views to surface.
    @discardableResult
    func activate(fileURL: URL) -> Bool {
        let file: LicenseFile
        do {
            file = try LicenseFile.read(from: fileURL)
        } catch {
            lastUnlockError = "That doesn't look like a Splynek licence file: "
                            + error.localizedDescription
            return false
        }
        switch file.verify(againstPublicKeyBase64: effectivePublicKey) {
        case .valid:
            // Copy to canonical location.  Overwrite any existing
            // file — re-activation with a fresh license is fine
            // (e.g. tier upgrade).
            do {
                if FileManager.default.fileExists(atPath: licenseStoreURL.path) {
                    try FileManager.default.removeItem(at: licenseStoreURL)
                }
                try FileManager.default.copyItem(at: fileURL, to: licenseStoreURL)
            } catch {
                lastUnlockError = "Could not save licence: \(error.localizedDescription)"
                return false
            }
            isPro = true
            licensedEmail = file.email
            lastUnlockError = nil
            return true

        case .invalid(let reason):
            lastUnlockError = "Licence signature didn't verify: \(reason).  "
                            + "Re-download from your purchase email, or contact support@splynek.app."
            return false
        }
    }

    /// Legacy stub kept for API compatibility with the older "email +
    /// key" path some Settings views still call.  Surfaces a polite
    /// CTA pointing at splynek.app/pro.  Real activation is via
    /// `activate(fileURL:)` (double-click flow).
    @discardableResult
    func unlock(email: String, key: String) -> Bool {
        lastUnlockError = "Splynek Pro is now activated by double-clicking the "
                        + "licence file from your purchase email — there's no "
                        + "manual code to enter.  If you've lost the email, "
                        + "visit splynek.app/support."
        return false
    }

    /// Delete the persisted license + flip back to free tier.  No
    /// network call, no anti-piracy phone-home — the user keeps a
    /// copy of the licence file and can re-activate any time.
    func deactivate() {
        try? FileManager.default.removeItem(at: licenseStoreURL)
        isPro = false
        licensedEmail = nil
        lastUnlockError = nil
    }
}

// MARK: - AIAssistant (stub)

/// Free-tier AI stub. Always reports Ollama as unavailable. All
/// query methods throw so the VM's error-handling paths kick in and
/// the UI tells the user where to go (the MAS build).
final class AIAssistant {

    // v0.50: State shape matches the real AIAssistant in splynek-pro
    // (`.ready(provider:, model:)`) so ViewModel's single pattern-match
    // compiles against either build. Free build never emits `.ready`
    // — always `.unavailable` — so the provider value is cosmetic here.
    enum DetectionState {
        case ready(provider: String, model: String)
        case unavailable(String)
        case unknown
    }

    /// Concierge action classifications returned by the real assistant.
    /// The stub never actually produces one (every concierge call
    /// throws), but the type is part of the API surface so the VM's
    /// `handleConciergeAction` switch compiles.
    enum ConciergeAction {
        case download(url: URL, rationale: String)
        case queue(url: URL, rationale: String)
        case search(query: String)
        case cancelAll
        case pauseAll
        case unclear(followUp: String)
    }

    struct UnavailableError: Error, LocalizedError {
        var errorDescription: String? {
            "AI features are only available in the Mac App Store build of Splynek."
        }
    }

    /// v1.3: one AI suggestion for the Sovereignty tab's
    /// uncataloged-apps fallback flow.  Shared API surface between
    /// the stub (here) and the real impl (splynek-pro/AIAssistant).
    struct SovereigntySuggestion: Hashable, Sendable {
        let name: String
        let note: String
        let homepage: URL?
    }

    init() {}

    /// Always reports AI unavailable in the free build.
    func detect() async -> DetectionState {
        .unavailable("Splynek Pro (Mac App Store) — AI features aren't in the free build.")
    }

    func searchHistory(query: String, entries: [HistoryEntry]) async throws -> [Int] {
        throw UnavailableError()
    }

    func concierge(_ text: String) async throws -> ConciergeAction {
        throw UnavailableError()
    }

    func resolveURL(_ query: String) async throws -> (URL, String) {
        throw UnavailableError()
    }

    func generateRecipe(goal: String) async throws -> DownloadRecipe {
        throw UnavailableError()
    }

    /// v1.3 Sovereignty AI fallback — see the real impl in
    /// splynek-pro/AIAssistant.swift for the working behaviour.
    /// The stub always throws; free-tier builds never surface the
    /// "Ask AI" button because its Sovereignty view gates it behind
    /// `vm.aiAvailable && vm.license.isPro`, which is always false
    /// in the stub.
    func sovereigntyAlternatives(
        appName: String, bundleID: String, timeout: TimeInterval = 30
    ) async throws -> [SovereigntySuggestion] {
        throw UnavailableError()
    }

    /// v1.4 audit gap: Pro's `AIAssistant.prewarm()` is called from
    /// splynek-pro/Views/ConciergeView.swift on input-focus.  That
    /// view is excluded from the free build, so the call site never
    /// reaches the stub — but adding a no-op here makes the API
    /// symmetric and keeps any future free-build call site (e.g. if
    /// we add a free Concierge teaser) from breaking the compile.
    func prewarm() async {
        // No-op in free builds.
    }
}

// MARK: - DownloadRecipe (stub type)

/// Multi-item plan produced by the Pro Agentic Recipes feature. In
/// the free build this type is only used as a "never-populated"
/// value — `currentRecipe` stays nil, `recipeHistory` stays empty.
struct DownloadRecipe: Identifiable, Codable, Equatable {

    var id: UUID
    var goal: String
    var items: [Item]

    struct Item: Identifiable, Codable, Equatable {
        var id: UUID
        var url: String
        var label: String?
        var sha256: String?
        var selected: Bool

        init(id: UUID = UUID(), url: String, label: String? = nil,
             sha256: String? = nil, selected: Bool = true) {
            self.id = id; self.url = url; self.label = label
            self.sha256 = sha256; self.selected = selected
        }
    }

    init(id: UUID = UUID(), goal: String, items: [Item] = []) {
        self.id = id; self.goal = goal; self.items = items
    }
}

/// Free-tier RecipeStore: loads nothing, persists nothing. The real
/// store is a Pro feature — we don't surface saved recipes in the
/// free build because the generation path isn't available anyway.
enum RecipeStore {
    static let maxStored = 20
    static func load() -> [DownloadRecipe] { [] }
    static func save(_ recipes: [DownloadRecipe]) { /* no-op in free build */ }
}

// MARK: - DownloadSchedule (stub)

/// Why the schedule is currently blocking starts. In the free build
/// this never actually gets produced — `evaluate()` always returns
/// `.allowed` — but the type is public so the `SettingsView` schedule
/// editor (which is unreachable in free builds, gated by `isPro`)
/// still compiles.
enum ScheduleBlockReason: Equatable {
    case outsideWindow
    case cellularPaused
    case disabledDay

    var displayText: String {
        switch self {
        case .outsideWindow:   return "Outside the scheduled window"
        case .cellularPaused:  return "Paused while on cellular"
        case .disabledDay:     return "Disabled for today"
        }
    }
}

/// Scheduled-downloads policy. In the free build, every evaluation
/// returns `.allowed` — the queue runs immediately regardless of any
/// previously-persisted schedule JSON. The editable properties below
/// exist for settings-view compile compatibility; they're never read
/// because the Pro-gated editor is unreachable.
struct DownloadSchedule: Codable, Equatable {

    enum Evaluation: Equatable {
        case allowed
        case blocked(reason: ScheduleBlockReason, nextAllowed: Date?)
    }

    var enabled: Bool = false
    var startHour: Int = 0
    var endHour: Int = 24
    var weekdays: Set<Int> = Set(1...7)
    var pauseOnCellular: Bool = false

    var summary: String {
        "Pro feature — available in the Mac App Store build."
    }

    static let `default` = DownloadSchedule()

    init() {}

    static func load() -> DownloadSchedule { .default }
    func save() { /* no-op in free build */ }

    /// Free tier: always `.allowed`. Pro build: real time-window +
    /// weekday-mask + cellular-pause logic.
    func evaluate(at date: Date, onCellular: Bool) -> Evaluation {
        .allowed
    }
}
