// Copyright © 2026 Splynek. MIT.
//
// MacInsightsView — Sprint 1 PRO-PLUS-IPHONE (2026-05-09).
//
// Pro-on-iPhone surface.  Pulls Sovereignty / Trust / Trust Watcher
// / History summaries from the user's default paired Mac and renders
// them with the same look + feel as the Mac TrustView / SovereigntyView.
//
// Why "Pro on iPhone" makes sense as a Companion feature:
//   • The user already paid for Pro on the Mac.  Surfacing the same
//     features on the phone — without an extra fee — turns the
//     iPhone into a *second* surface for the same purchase.
//   • Trust Watcher alerts in particular should reach the phone:
//     Pro is sold partly on "you'll know when an app's ToS changes",
//     and "you'll know" cashes out as a phone notification.
//
// This view:
//   • Tab section in ContentView (new "Insights" tab).
//   • Shows Sovereignty + Trust + History summary cards.
//   • Trust Watcher card is Pro-only on the Mac side; we present
//     a 404 result as "Trust Watcher needs Splynek Pro on the
//     paired Mac" upsell.
//
// All HTTP calls go via PairedMacClient → /api/*/summary endpoints
// shipped earlier in this sprint (`a113dc9`).

#if canImport(SwiftUI)
import SwiftUI

struct MacInsightsView: View {
    @State private var mac: PairedMac?
    @State private var sovereignty: RelaySummary.Sovereignty?
    @State private var trust: RelaySummary.Trust?
    @State private var watcher: RelaySummary.TrustWatcher?
    @State private var watcherProRequired: Bool = false
    @State private var history: RelaySummary.History?
    @State private var loadError: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let mac {
                    macHeader(mac)
                    sovereigntyCard
                    trustCard
                    trustWatcherCard
                    historyCard
                } else {
                    unpairedHero
                }
                if let err = loadError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(16)
        }
        .navigationTitle("Insights")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    if isLoading {
                        ProgressView().controlSize(.regular)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)
            }
        }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    // MARK: Sections

    @ViewBuilder
    private func macHeader(_ mac: PairedMac) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "macbook.and.iphone")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(mac.displayName)
                    .font(.headline)
                Text("Last seen \(mac.lastSeen.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var unpairedHero: some View {
        VStack(spacing: 12) {
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Pair a Mac to see your Splynek insights here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    @ViewBuilder
    private var sovereigntyCard: some View {
        InsightsCard(
            title: "Sovereignty",
            systemImage: "shield.lefthalf.filled",
            tint: .indigo
        ) {
            if let s = sovereignty {
                HStack(alignment: .lastTextBaseline) {
                    Text("\(s.score)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor(s.score))
                    Text(" / 100")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text("\(s.appsWithAlternatives) of \(s.totalApps) installed apps have an EU/OSS alternative listed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !s.topConcerns.isEmpty {
                    Divider().padding(.vertical, 4)
                    ForEach(s.topConcerns, id: \.bundleID) { app in
                        HStack {
                            Text(app.displayName)
                                .font(.callout)
                            Spacer()
                            if let alt = app.firstAlternative {
                                Text("→ \(alt)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                placeholderRow("Open Sovereignty on the Mac to scan.")
            }
        }
    }

    @ViewBuilder
    private var trustCard: some View {
        InsightsCard(
            title: "Trust",
            systemImage: "checkmark.seal",
            tint: .orange
        ) {
            if let t = trust {
                HStack(alignment: .lastTextBaseline) {
                    Text("\(t.averageScore)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor(t.averageScore))
                    Text(" / 100 avg")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text("\(t.highRiskCount) of \(t.totalAppsWithProfile) apps in the high-risk band.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !t.topConcerns.isEmpty {
                    Divider().padding(.vertical, 4)
                    ForEach(t.topConcerns, id: \.bundleID) { app in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(app.displayName)
                                    .font(.callout)
                                Spacer()
                                Text("\(app.score)")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(scoreColor(app.score))
                            }
                            Text(app.topConcernSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            } else {
                placeholderRow("Open Trust on the Mac to scan.")
            }
        }
    }

    @ViewBuilder
    private var trustWatcherCard: some View {
        InsightsCard(
            title: "Trust Watcher",
            systemImage: "bell.badge",
            tint: .purple
        ) {
            if watcherProRequired {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Splynek Pro feature.")
                        .font(.callout.weight(.semibold))
                    Text("Trust Watcher monitors Privacy Policies + Terms of Service for changes. Ask the Mac owner to upgrade in About → Splynek Pro.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let w = watcher {
                HStack(alignment: .lastTextBaseline) {
                    Text("\(w.pendingAlertCount)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(w.pendingAlertCount == 0 ? .green : .orange)
                    Text(w.pendingAlertCount == 1 ? " alert" : " alerts")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                Text("Watching \(w.watchingCount) apps · \(w.lastSweepAt.map { "last check \(prettyDate($0))" } ?? "first check pending")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !w.recentAlerts.isEmpty {
                    Divider().padding(.vertical, 4)
                    ForEach(w.recentAlerts.filter { !$0.acknowledged }, id: \.id) { alert in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(alert.displayName)
                                    .font(.callout.weight(.semibold))
                                Text("·").foregroundStyle(.tertiary)
                                Text(alert.kindLabel)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(alert.severityLabel)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                            Text(prettyDate(alert.observedAt))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            } else {
                placeholderRow("Watcher hasn't run yet.")
            }
        }
    }

    @ViewBuilder
    private var historyCard: some View {
        InsightsCard(
            title: "Recent downloads",
            systemImage: "clock.arrow.circlepath",
            tint: .blue
        ) {
            if let h = history {
                HStack(alignment: .lastTextBaseline) {
                    Text("\(h.totalEntries)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                    Text(" total · \(formatBytes(h.totalBytes))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                if !h.recent.isEmpty {
                    Divider().padding(.vertical, 4)
                    ForEach(h.recent.prefix(5), id: \.url) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.filename)
                                .font(.callout)
                                .lineLimit(1)
                            Text("\(formatBytes(item.bytes)) · \(prettyDate(item.finishedAt))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                placeholderRow("No recent downloads.")
            }
        }
    }

    @ViewBuilder
    private func placeholderRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Refresh

    @MainActor
    private func refresh() async {
        guard let store = PairedMacStore() else {
            loadError = "App Group unavailable."
            return
        }
        let macs = store.all().sorted(by: { $0.lastSeen > $1.lastSeen })
        guard let mac = macs.first else {
            self.mac = nil
            return
        }
        self.mac = mac
        isLoading = true
        defer { isLoading = false }
        loadError = nil

        let client = PairedMacClient(mac: mac)
        async let s = try? client.sovereigntySummary()
        async let t = try? client.trustSummary()
        async let h = try? client.historySummary()

        // Trust Watcher is the only endpoint that 404's by design
        // (free tier).  Catch that specifically; everything else is
        // a generic error.
        let watcherResult: (RelaySummary.TrustWatcher?, Bool)
        do {
            let w = try await client.trustWatcherSummary()
            watcherResult = (w, false)
        } catch PairedMacClient.ClientError.http(404) {
            watcherResult = (nil, true)
        } catch {
            watcherResult = (nil, false)
        }

        sovereignty = await s
        trust = await t
        history = await h
        watcher = watcherResult.0
        watcherProRequired = watcherResult.1
    }

    // MARK: Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...:    return .green
        case 50..<80:  return .orange
        default:       return .red
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    private func prettyDate(_ iso: String) -> String {
        let isoF = ISO8601DateFormatter()
        isoF.formatOptions = [.withInternetDateTime]
        guard let d = isoF.date(from: iso) else { return iso }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }
}

// MARK: - Card chrome

private struct InsightsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

#Preview { NavigationStack { MacInsightsView() } }
#endif
