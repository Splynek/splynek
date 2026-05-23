// Copyright © 2026 Splynek. MIT.
//
// TrustWatcherInboxView — IA v2 Phase 3 (2026-05-23).
//
// The Trust Watcher alert feed, surfaced as its own chip in the
// My Apps tab.  Replaces the v1-era card-inside-the-Trust-tab
// affordance with a first-class destination that the user can
// land on directly (via the chip strip OR the Spotlight
// `splynek://my-apps/trust-watcher` deep link in a future
// commit).
//
// Three states:
//   • Pro-gated (free tier)    → upsell card
//   • No alerts                → "All clear" empty state
//   • Alerts present           → grouped by app, newest first

import SwiftUI

struct TrustWatcherInboxView: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !vm.license.isPro {
                    proGate
                } else if visibleAlerts.isEmpty {
                    emptyState
                } else {
                    alertList
                }
            }
            .padding(20)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trust Watcher")
                .font(.title2.weight(.semibold))
            Text("Daily SHA-256 diff of Privacy Policy + Terms-of-Service URLs for installed apps Splynek's catalog tracks. Material changes show up here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var proGate: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Trust Watcher is a Pro feature.")
                .font(.headline)
            Text("Daily diffs of Privacy Policies and Terms of Service for popular apps you have installed. Push notifications on your iPhone the moment something changes. Unlocked with Splynek Pro.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
                .fixedSize(horizontal: false, vertical: true)
            Button("Unlock Splynek Pro — $29 one-time") {
                vm.showingProUnlock = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("All clear.")
                .font(.headline)
            Text("Splynek is watching \(vm.trustWatchState.targetCount) URLs across \(vm.trustWatchState.bundleCount) installed apps. No material changes since the last sweep.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    @ViewBuilder
    private var alertList: some View {
        VStack(spacing: 12) {
            ForEach(visibleAlerts) { alert in
                alertCard(alert)
            }
            if !visibleAlerts.isEmpty {
                HStack {
                    Spacer()
                    Button("Mark all as read") {
                        vm.acknowledgeAllTrustAlerts()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private func alertCard(_ alert: TrustWatchAlert) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(severityColor(alert.severity))
                Text(alert.target.displayName)
                    .font(.body.weight(.semibold))
                severityPill(alert.severity)
                Spacer()
                Text(alert.observedAt)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(detailLine(alert))
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Link(destination: alert.target.url) {
                    Text("Open \(alert.target.kind.rawValue == "privacyPolicy" ? "Privacy Policy" : "Terms of Service")")
                }
                .font(.callout)
                Spacer()
                Button("Acknowledge") {
                    vm.acknowledgeTrustAlert(alert.id)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(severityColor(alert.severity).opacity(0.3),
                              lineWidth: 1)
        )
    }

    @ViewBuilder
    private func severityPill(_ s: TrustWatchAlertSeverity) -> some View {
        Text(severityLabel(s))
            .font(.system(size: 10.5, weight: .semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(severityColor(s).opacity(0.14))
            )
            .foregroundStyle(severityColor(s))
    }

    // MARK: Helpers

    /// Show all non-acknowledged alerts, newest first.  Acknowledged
    /// alerts persist in the store for iPhone-Mac dedup but don't
    /// surface in the UI.
    private var visibleAlerts: [TrustWatchAlert] {
        vm.trustWatchState.alerts
            .filter { !$0.acknowledged }
            .sorted { $0.observedAt > $1.observedAt }
    }

    private func detailLine(_ alert: TrustWatchAlert) -> String {
        let kind = alert.target.kind.rawValue == "privacyPolicy"
            ? "Privacy Policy" : "Terms of Service"
        let delta = Int((alert.lengthDeltaFraction * 100).rounded())
        let sign = delta >= 0 ? "+" : ""
        return "\(kind) changed by \(sign)\(delta)% in length. Severity: \(severityLabel(alert.severity).lowercased())."
    }

    private func severityLabel(_ s: TrustWatchAlertSeverity) -> String {
        s.label
    }

    private func severityColor(_ s: TrustWatchAlertSeverity) -> Color {
        switch s {
        case .info:     return .yellow
        case .notice:   return .orange
        case .material: return .red
        }
    }
}

// MARK: - VM glue

extension SplynekViewModel {
    /// Counts the UI shows on the empty state.  Cheap reads.
    fileprivate var trustWatchState_targetCount_compat: Int {
        TrustWatchCatalog.targets.count
    }
}

fileprivate extension TrustWatchStore {
    /// Convenience: how many unique bundle IDs the catalog touches.
    var bundleCount: Int {
        Set(TrustWatchCatalog.targets.map { $0.bundleID }).count
    }
    var targetCount: Int { TrustWatchCatalog.targets.count }
}
