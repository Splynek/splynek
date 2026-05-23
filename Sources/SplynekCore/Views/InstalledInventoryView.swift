// Copyright © 2026 Splynek. MIT.
//
// InstalledInventoryView — IA v2 Phase 3 (2026-05-23).
//
// The marquee surface of the My Apps tab: one row per installed app
// that combines, in a single horizontal scan, the four post-install
// concerns Splynek tracks for that app —
//
//   Sovereignty:    does the catalog have EU/OSS alternatives?
//   Trust:          public-record concerns (App-Store privacy labels,
//                   DPA fines, CVEs, HIBP breaches)?
//   Update:         is a newer version available?
//   Trust Watcher:  has the vendor's Privacy Policy or ToS changed
//                   since we last checked?
//
// All four data sources already exist in SplynekCore.  This view's
// only job is to JOIN them and render row-per-app — that join is
// the unique value of the IA v2 reorg.  Without it the user has to
// hop across four tabs to ask "is this app I have OK?".
//
// Phase 3 keeps the join pure-presentation: no scanner is triggered
// from this view.  If the user hasn't run the Sovereignty scanner
// yet, the rows show an empty state with a CTA to scan.

import SwiftUI

struct InstalledInventoryView: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if vm.sovereigntyScannerApps.isEmpty {
                    emptyState
                } else {
                    summaryCard
                    inventoryList
                }
            }
            .padding(20)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your stack")
                .font(.title2.weight(.semibold))
            Text("Every installed app, with the four signals Splynek tracks: Sovereignty alternatives, Trust score, available update, and Trust Watcher alerts.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No scan yet")
                .font(.headline)
            Text("Splynek hasn't scanned your installed apps. Run a scan from the Sovereignty tab to populate this inventory.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private var summaryCard: some View {
        let rows = inventoryRows
        let totalApps = rows.count
        let updatesReady = rows.filter { $0.hasUpdate }.count
        let alertCount = rows.filter { $0.trustAlerts > 0 }
            .reduce(0) { $0 + $1.trustAlerts }
        let sovereignableCount = rows.filter { $0.hasAlternatives }.count

        HStack(spacing: 16) {
            stackPill(value: "\(totalApps)", label: "apps")
            divider
            stackPill(value: "\(updatesReady)",
                      label: "update\(updatesReady == 1 ? "" : "s") ready",
                      tint: updatesReady > 0 ? .accentColor : .secondary)
            divider
            stackPill(value: "\(alertCount)",
                      label: "Trust Watcher alert\(alertCount == 1 ? "" : "s")",
                      tint: alertCount > 0 ? .red : .secondary)
            divider
            stackPill(value: "\(sovereignableCount)",
                      label: "have EU/OSS alternatives",
                      tint: .orange)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var inventoryList: some View {
        VStack(spacing: 0) {
            ForEach(inventoryRows) { row in
                inventoryRow(row)
                if row.id != inventoryRows.last?.id {
                    Divider().opacity(0.5)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func inventoryRow(_ row: InventoryRow) -> some View {
        HStack(spacing: 14) {
            // App icon (fallback: SF Symbol — fetching real icons
            // from the bundle URL is a Phase-5 polish item)
            Image(systemName: "app.dashed")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)

            // Name + bundle/version
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(.body.weight(.medium))
                Text(row.subline)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 180, alignment: .leading)

            Spacer(minLength: 12)

            // Score / status pills
            HStack(spacing: 6) {
                if row.hasAlternatives {
                    statusPill(text: "Has alternatives",
                               color: .orange)
                }
                if let trustLevel = row.trustLevelLabel {
                    statusPill(text: "Trust \(trustLevel)",
                               color: row.trustIsConcerning ? .yellow : .green)
                }
                if row.hasUpdate {
                    statusPill(text: "Update ready", color: .accentColor)
                }
                if row.trustAlerts > 0 {
                    statusPill(text: "ToS changed (\(row.trustAlerts))",
                               color: .red)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: Subcomponents

    @ViewBuilder
    private func stackPill(value: String, label: String,
                           tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 28)
    }

    @ViewBuilder
    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(0.14))
            )
            .foregroundStyle(color)
    }

    // MARK: Data join

    /// One row of the inventory — pre-joined from the four data
    /// sources so the view body stays purely presentational.
    fileprivate struct InventoryRow: Identifiable, Hashable {
        let id: String          // bundle identifier
        let name: String
        let subline: String
        let hasAlternatives: Bool
        let trustLevelLabel: String?    // "Low" / "Moderate" / "High" / "Severe"
        let trustIsConcerning: Bool
        let hasUpdate: Bool
        let trustAlerts: Int
    }

    /// Compute the row list from the VM each render.  Cheap — all
    /// inputs are in-memory dictionaries / arrays.
    private var inventoryRows: [InventoryRow] {
        let alerts = vm.trustWatchState.alerts.filter { !$0.acknowledged }
        let alertsByBundle: [String: Int] = Dictionary(
            grouping: alerts,
            by: { $0.target.bundleID }
        ).mapValues { $0.count }

        return vm.sovereigntyScannerApps.map { app in
            let sovEntry = SovereigntyCatalog.alternatives(for: app.id)
            let hasAlts = sovEntry?.alternatives.isEmpty == false

            let trustEntry = TrustCatalog.profile(for: app.id)
            let trustScore = trustEntry.map { TrustScorer.score($0) }
            let trustLevelLabel: String? = trustScore.map { score in
                switch score.level {
                case .low: return "Low"
                case .moderate: return "Moderate"
                case .high: return "High"
                case .severe: return "Severe"
                }
            }
            let concerning = trustScore.map {
                $0.level == .high || $0.level == .severe
            } ?? false

            return InventoryRow(
                id: app.id,
                name: app.name,
                subline: "\(app.id)\(app.version.map { " · v\($0)" } ?? "")",
                hasAlternatives: hasAlts,
                trustLevelLabel: trustLevelLabel,
                trustIsConcerning: concerning,
                hasUpdate: false,   // Updates wiring is Phase 4 work
                trustAlerts: alertsByBundle[app.id] ?? 0
            )
        }
        .sorted { lhs, rhs in
            // Sort by "needs attention" first, then alphabetical:
            //   any alerts → top
            //   then any concerning Trust → next
            //   then any updates → next
            //   then by display name
            let lhsAttention = lhs.attentionScore
            let rhsAttention = rhs.attentionScore
            if lhsAttention != rhsAttention { return lhsAttention > rhsAttention }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                == .orderedAscending
        }
    }
}

private extension InstalledInventoryView.InventoryRow {
    /// Higher = more reason to surface the row near the top.
    var attentionScore: Int {
        var s = 0
        if trustAlerts > 0       { s += 10 }
        if trustIsConcerning     { s += 5 }
        if hasUpdate             { s += 2 }
        if hasAlternatives       { s += 1 }
        return s
    }
}
