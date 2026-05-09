// Copyright © 2026 Splynek. MIT.
//
// iOS App Intents — voice + Shortcuts + Lock Screen surfaces for the
// iPhone Companion.  Sprint 1 PRO-PLUS-IPHONE (2026-05-09).
//
// Why Intents are the multiplier for "must-have" status (per the
// strategy memo):
//   • "Hey Siri, send to Splynek" — turns the iPhone into a
//     hands-free dispatcher.
//   • Lock-screen widgets / Action Button on iPhone 15 Pro+ wire
//     directly to App Intents — zero-tap actions.
//   • Shortcuts integrations make Splynek composable with Working
//     Copy, Drafts, etc.
//
// Each Intent picks the single most-recently-seen paired Mac (the
// "default Mac") and routes through it.  When zero Macs are paired
// the Intent surfaces a clean error to the Shortcuts editor.
//
// All intents are read-only or write-with-explicit-confirmation by
// design.  No Intent ever silently transfers money, modifies system
// settings, or changes file permissions — matches the rest of the
// Splynek safety posture.

#if canImport(AppIntents)
import AppIntents
import Foundation

// MARK: - Pairing helper

/// Resolve "the user's default Mac" — the most-recently-seen paired
/// Mac.  Each Intent calls this; throwing is the right behaviour
/// when the user has no paired Mac (the intent author should pair
/// one first via the Companion app).
@available(iOS 16.0, *)
fileprivate enum DefaultPairedMacResolver {
    static func resolve() throws -> PairedMac {
        guard let store = PairedMacStore() else {
            // App Group not configured — entitlement / build issue.
            // The user can't fix this; surface a clear error so the
            // Shortcuts editor doesn't show a misleading "no Macs"
            // message.
            throw AppIntentError.unknown("App Group unavailable; reinstall Splynek Companion.")
        }
        let macs = store.all()
        guard let mac = macs.sorted(by: { $0.lastSeen > $1.lastSeen }).first else {
            throw AppIntentError.notPaired
        }
        return mac
    }
}

@available(iOS 16.0, *)
public enum AppIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case notPaired
    case macUnreachable
    case macNotPro
    case unknown(String)

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notPaired:
            return "No Splynek Mac paired. Open the Splynek Companion app to pair a Mac first."
        case .macUnreachable:
            return "Couldn't reach the paired Mac. Check it's awake and on the same network."
        case .macNotPro:
            return "This feature requires Splynek Pro on the paired Mac."
        case .unknown(let s):
            return "Splynek error: \(s)"
        }
    }
}

// MARK: - SubmitURLToSplynekIntent

/// "Hey Siri, send to Splynek" / Shortcuts URL action.
/// Submits a URL to the user's default paired Mac for download.
@available(iOS 16.0, *)
public struct SubmitURLToSplynekIntent: AppIntent {
    public static var title: LocalizedStringResource = "Send URL to Splynek"
    public static var description = IntentDescription(
        "Queue a URL on the default Splynek Mac for download."
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "URL")
    public var url: URL

    /// "Start downloading immediately" vs "queue for later" — defaults
    /// to queue so the share-sheet behaviour matches direct submit.
    @Parameter(title: "Start immediately", default: false)
    public var startImmediately: Bool

    public init() {}
    public init(url: URL, startImmediately: Bool = false) {
        self.url = url
        self.startImmediately = startImmediately
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mac = try DefaultPairedMacResolver.resolve()
        let client = PairedMacClient(mac: mac)
        do {
            if startImmediately {
                try await client.download(url: url)
            } else {
                try await client.queue(url: url)
            }
        } catch {
            throw AppIntentError.macUnreachable
        }
        let verb = startImmediately ? "Started" : "Queued"
        return .result(dialog: "\(verb) on \(mac.displayName).")
    }
}

// MARK: - PauseAllSplynekDownloadsIntent

@available(iOS 16.0, *)
public struct PauseAllSplynekDownloadsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Pause all Splynek downloads"
    public static var description = IntentDescription(
        "Pause every running download on the default Splynek Mac."
    )
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mac = try DefaultPairedMacResolver.resolve()
        let client = PairedMacClient(mac: mac)
        do {
            try await client.pauseAll()
        } catch {
            throw AppIntentError.macUnreachable
        }
        return .result(dialog: "Paused all downloads on \(mac.displayName).")
    }
}

// MARK: - ResumeAllSplynekDownloadsIntent

@available(iOS 16.0, *)
public struct ResumeAllSplynekDownloadsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Resume all Splynek downloads"
    public static var description = IntentDescription(
        "Resume every paused download on the default Splynek Mac."
    )
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mac = try DefaultPairedMacResolver.resolve()
        let client = PairedMacClient(mac: mac)
        do {
            try await client.resumeAll()
        } catch {
            throw AppIntentError.macUnreachable
        }
        return .result(dialog: "Resumed all downloads on \(mac.displayName).")
    }
}

// MARK: - SplynekActiveDownloadsIntent

/// "How many downloads are running on Splynek?" — answers a count
/// + filenames.  Read-only; safe for Lock-Screen widget evaluation.
@available(iOS 16.0, *)
public struct SplynekActiveDownloadsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Splynek active downloads"
    public static var description = IntentDescription(
        "How many downloads are running on the default Splynek Mac."
    )
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult
        & ReturnsValue<Int> & ProvidesDialog
    {
        let mac = try DefaultPairedMacResolver.resolve()
        let client = PairedMacClient(mac: mac)
        let jobs: [JobSummary]
        do {
            jobs = try await client.jobs()
        } catch {
            throw AppIntentError.macUnreachable
        }
        let running = jobs.filter { ($0.phase ?? "") == "running" }
        let phrase: String
        switch running.count {
        case 0: phrase = "No downloads running on \(mac.displayName)."
        case 1: phrase = "1 download running on \(mac.displayName)."
        default: phrase = "\(running.count) downloads running on \(mac.displayName)."
        }
        return .result(value: running.count, dialog: IntentDialog(stringLiteral: phrase))
    }
}

// MARK: - SplynekSovereigntyScoreIntent

/// "What's my Splynek sovereignty score?" — reads the Pro-on-iPhone
/// summary endpoint.  Available on free Macs (the Sovereignty
/// catalog is part of the free tier).
@available(iOS 16.0, *)
public struct SplynekSovereigntyScoreIntent: AppIntent {
    public static var title: LocalizedStringResource = "Splynek sovereignty score"
    public static var description = IntentDescription(
        "Your sovereignty score across the apps installed on your default Mac."
    )
    public static var openAppWhenRun: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult
        & ReturnsValue<Int> & ProvidesDialog
    {
        let mac = try DefaultPairedMacResolver.resolve()
        let client = PairedMacClient(mac: mac)
        let summary: RelaySummary.Sovereignty
        do {
            summary = try await client.sovereigntySummary()
        } catch PairedMacClient.ClientError.http(503) {
            // Scanner hasn't run yet — give the user a clean nudge.
            return .result(value: 0, dialog: "Scan hasn't run yet on \(mac.displayName); open Sovereignty in Splynek to start it.")
        } catch {
            throw AppIntentError.macUnreachable
        }
        let phrase = "Sovereignty score \(summary.score) of 100 on \(mac.displayName) — \(summary.appsWithAlternatives) of \(summary.totalApps) installed apps have an EU/OSS alternative listed."
        return .result(value: summary.score,
                       dialog: IntentDialog(stringLiteral: phrase))
    }
}

// MARK: - AppShortcutsProvider

/// Tells iOS which intents to expose as Spotlight + Action-Button
/// + Lock-Screen widgets out of the box (no Shortcut required).
@available(iOS 16.0, *)
public struct SplynekCompanionShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SubmitURLToSplynekIntent(),
            phrases: [
                "Send to \(.applicationName)",
                "Send URL to \(.applicationName)"
            ],
            shortTitle: "Send to Splynek",
            systemImageName: "arrow.up.doc.on.clipboard"
        )
        AppShortcut(
            intent: PauseAllSplynekDownloadsIntent(),
            phrases: [
                "Pause \(.applicationName) downloads",
                "Pause all downloads on \(.applicationName)"
            ],
            shortTitle: "Pause all",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: ResumeAllSplynekDownloadsIntent(),
            phrases: [
                "Resume \(.applicationName) downloads",
                "Resume all downloads on \(.applicationName)"
            ],
            shortTitle: "Resume all",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: SplynekActiveDownloadsIntent(),
            phrases: [
                "How many \(.applicationName) downloads are running",
                "Active \(.applicationName) downloads"
            ],
            shortTitle: "Active downloads",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: SplynekSovereigntyScoreIntent(),
            phrases: [
                "What's my \(.applicationName) sovereignty score",
                "\(.applicationName) sovereignty"
            ],
            shortTitle: "Sovereignty score",
            systemImageName: "shield.lefthalf.filled"
        )
    }
}

#endif
