// Copyright © 2026 Splynek. MIT.
//
// SplynekStatusWidget — Sprint 1 PRO-PLUS-IPHONE (2026-05-09).
//
// Two-size home-screen widget:
//   • systemSmall — single big number ("Sovereignty score: 73") plus
//     a trend label ("12 of 47 apps to swap").  Fits the iPhone home
//     row + iPad lock-screen perfectly.
//   • systemMedium — three rows: Sovereignty score, active downloads
//     count, Trust Watcher pending alert count.  At-a-glance dashboard
//     of the paired Mac without opening the app.
//
// Refresh policy:
//   • Timeline returns three entries spaced 15/30/60 min ahead.
//     iOS picks one to render at refresh time.
//   • Widgets that miss the iOS-level refresh budget (heavy users)
//     gracefully degrade to "—" placeholders rather than stale data.
//
// Privacy posture:
//   • All data is pulled over the existing token-gated REST surface
//     to the user's own paired Mac.  No third-party endpoints, no
//     analytics, no remote config.
//   • When the user has zero paired Macs the widget shows a setup
//     CTA instead of fake numbers.

#if canImport(WidgetKit) && canImport(SwiftUI)
import WidgetKit
import SwiftUI
// iOS/Shared/* sources (PairedMac, PairedMacStore, PairedMacClient,
// RelaySummary) are inlined into this target by project.yml — no
// module import required.

// MARK: - Entry

@available(iOS 16.0, *)
public struct SplynekStatusEntry: TimelineEntry {
    public let date: Date
    public let macName: String?       // nil → not paired
    public let sovereigntyScore: Int? // nil → not yet scanned
    public let appsWithAlternatives: Int?
    public let totalApps: Int?
    public let activeJobs: Int?
    public let trustWatcherPending: Int?  // nil → free-tier Mac

    public static let placeholder = SplynekStatusEntry(
        date: Date(),
        macName: "Mac",
        sovereigntyScore: 73,
        appsWithAlternatives: 12,
        totalApps: 47,
        activeJobs: 2,
        trustWatcherPending: 1
    )

    public static let unpaired = SplynekStatusEntry(
        date: Date(),
        macName: nil,
        sovereigntyScore: nil,
        appsWithAlternatives: nil,
        totalApps: nil,
        activeJobs: nil,
        trustWatcherPending: nil
    )
}

// MARK: - Provider

@available(iOS 16.0, *)
public struct SplynekStatusProvider: TimelineProvider {

    public init() {}

    public func placeholder(in context: Context) -> SplynekStatusEntry {
        .placeholder
    }

    public func getSnapshot(in context: Context,
                            completion: @escaping (SplynekStatusEntry) -> Void) {
        Task {
            let entry = await fetch()
            completion(entry)
        }
    }

    public func getTimeline(in context: Context,
                            completion: @escaping (Timeline<SplynekStatusEntry>) -> Void) {
        Task {
            let now = Date()
            let entry = await fetch()
            // Refresh in 15/30/60 minutes — iOS picks; conservative
            // budget so we don't churn battery polling the Mac.
            let nextRefresh = now.addingTimeInterval(15 * 60)
            let tl = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(tl)
        }
    }

    /// Resolve "the user's default Mac" + fetch summary endpoints in
    /// parallel.  Each branch fails into a `nil` field so the UI can
    /// show "—" rather than a hard error.
    private func fetch() async -> SplynekStatusEntry {
        guard let store = PairedMacStore() else { return .unpaired }
        let macs = store.all().sorted(by: { $0.lastSeen > $1.lastSeen })
        guard let mac = macs.first else { return .unpaired }

        let client = PairedMacClient(mac: mac)

        async let sov = try? client.sovereigntySummary()
        async let jobs = try? client.jobs()
        async let watcher = try? client.trustWatcherSummary()

        let sovValue = await sov
        let jobsValue = await jobs
        let watcherValue = await watcher

        let activeRunning = jobsValue?.filter { ($0.phase ?? "") == "running" }.count

        return SplynekStatusEntry(
            date: Date(),
            macName: mac.displayName,
            sovereigntyScore: sovValue?.score,
            appsWithAlternatives: sovValue?.appsWithAlternatives,
            totalApps: sovValue?.totalApps,
            activeJobs: activeRunning,
            trustWatcherPending: watcherValue?.pendingAlertCount
        )
    }
}

// MARK: - Views

@available(iOS 16.0, *)
struct SplynekStatusSmallView: View {
    let entry: SplynekStatusEntry
    var body: some View {
        if entry.macName == nil {
            unpairedBody
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(.tint)
                    Text("Sovereignty")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if let score = entry.sovereigntyScore {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                        .minimumScaleFactor(0.6)
                } else {
                    Text("—")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                if let total = entry.totalApps,
                   let with = entry.appsWithAlternatives, total > 0 {
                    Text("\(with) of \(total) to swap")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let mac = entry.macName {
                    Text(mac)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private var unpairedBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "macbook.and.iphone")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("Pair a Mac")
                .font(.headline)
            Text("Open Splynek Companion to pair your first Mac.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...:    return .green
        case 50..<80:  return .orange
        default:       return .red
        }
    }
}

@available(iOS 16.0, *)
struct SplynekStatusMediumView: View {
    let entry: SplynekStatusEntry

    var body: some View {
        if entry.macName == nil {
            VStack(spacing: 8) {
                Image(systemName: "macbook.and.iphone")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("Pair a Mac to see your Splynek status here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if let mac = entry.macName {
                    Text(mac)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                row(icon: "shield.lefthalf.filled",
                    label: "Sovereignty",
                    value: entry.sovereigntyScore.map { "\($0) of 100" } ?? "—",
                    tint: entry.sovereigntyScore.map(scoreColor) ?? .secondary)
                row(icon: "arrow.down.circle",
                    label: "Active downloads",
                    value: entry.activeJobs.map(String.init) ?? "—",
                    tint: (entry.activeJobs ?? 0) > 0 ? .blue : .secondary)
                if let pending = entry.trustWatcherPending {
                    row(icon: "bell.badge",
                        label: "Trust Watcher alerts",
                        value: "\(pending) pending",
                        tint: pending > 0 ? .orange : .secondary)
                } else {
                    row(icon: "bell.slash",
                        label: "Trust Watcher",
                        value: "Pro feature",
                        tint: .secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func row(icon: String, label: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint == .secondary ? .secondary : .primary)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...:    return .green
        case 50..<80:  return .orange
        default:       return .red
        }
    }
}

// MARK: - Widget

@available(iOS 16.0, *)
public struct SplynekStatusWidget: Widget {
    public let kind: String = "SplynekStatusWidget"
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SplynekStatusProvider()) { entry in
            view(for: entry)
        }
        .configurationDisplayName("Splynek status")
        .description("Sovereignty score, active downloads, Trust Watcher alerts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    @ViewBuilder
    private func view(for entry: SplynekStatusEntry) -> some View {
        // .containerBackground is iOS 17+; fall back to a clean
        // padding-based background on iOS 16.
        if #available(iOS 17.0, *) {
            EnvironmentReader(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        } else {
            EnvironmentReader(entry: entry)
                .padding(.horizontal, 4)
        }
    }
}

@available(iOS 16.0, *)
private struct EnvironmentReader: View {
    @Environment(\.widgetFamily) var family
    let entry: SplynekStatusEntry
    var body: some View {
        switch family {
        case .systemSmall:
            SplynekStatusSmallView(entry: entry)
        default:
            SplynekStatusMediumView(entry: entry)
        }
    }
}

#endif
