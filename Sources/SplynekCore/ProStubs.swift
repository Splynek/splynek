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

// MARK: - LicenseManager (stub)

/// Free-tier license gate. Always reports `isPro = false`. Unlock
/// attempts always fail with a "Pro is on the Mac App Store" message.
/// The MAS build substitutes a `StoreKit`-backed manager.
final class LicenseManager: ObservableObject {

    @Published private(set) var isPro: Bool = false
    @Published private(set) var licensedEmail: String? = nil
    @Published var lastUnlockError: String?

    init() {}

    /// No-op stub. Surfaces a CTA-friendly error that views can show.
    @discardableResult
    func unlock(email: String, key: String) -> Bool {
        lastUnlockError = "Splynek Pro features are only available in the "
                        + "Mac App Store build of Splynek."
        return false
    }

    func deactivate() {
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
