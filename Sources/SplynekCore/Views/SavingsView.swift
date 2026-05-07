// Copyright © 2026 Splynek. MIT.
//
// SavingsView — 2026-05-07 product expansion.
//
// "Free alternatives to paid apps" tab.  Differentiates between:
//   - Free / OSS                (zero ongoing cost)
//   - One-time payment          (Things 3, Bear lifetime, Affinity v2)
//   - Recurring subscription    (Adobe CC, Setapp, Spotify, 1Password)
//
// Hero: annualized spend across installed paid apps (subscriptions
// + amortized one-time at 5y).  Below: list of installed paid apps
// with cost + a free-alternative chip when Sovereignty has one.
//
// What makes this different from "yet another subscription tracker":
//   - Zero remote dependencies.  Reads only on-device data
//     (SovereigntyScanner installed-apps + Sovereignty catalog +
//     AppPricing seed).
//   - Tied to actually-installed Mac apps, not generic categories.
//   - Free alternatives carry verified downloadURLs (the Phase 1
//     deliveryKind classification + per-kind CTA applies — no
//     surprise sign-up walls when the user clicks "Install").

#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

@MainActor
struct SavingsView: View {
    @ObservedObject var vm: SplynekViewModel
    @StateObject private var scanner = SovereigntyScanner()

    init(vm: SplynekViewModel) { self.vm = vm }

    private var summary: SavingsSummary {
        SavingsSummary(installedApps: scanner.apps)
    }
    private var rows: [SavingsRow] {
        SavingsRow.compute(installedApps: scanner.apps)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                if !rows.isEmpty {
                    breakdownSection
                    paidAppsSection
                }
            }
            .padding(20)
        }
        .navigationTitle("Savings")
        .toolbar {
            ToolbarItem {
                Button {
                    scanner.scan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(scanner.isScanning)
            }
        }
        .onAppear {
            if scanner.apps.isEmpty { scanner.scan() }
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Mac costs ~\(summary.formattedAnnualUSD)/year")
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            if summary.replaceableAnnualUSD > 0 {
                Text("Up to \(summary.formattedReplaceableUSD)/year is replaceable with free alternatives.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if summary.totalPaidCount == 0 {
                if scanner.isScanning {
                    Label("Scanning installed apps…", systemImage: "magnifyingglass")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No installed paid apps detected. Splynek covers ~\(AppPricing.supportedBundleIDs.count) common paid Mac apps in this seed dataset.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("\(summary.totalPaidCount) paid \(summary.totalPaidCount == 1 ? "app" : "apps") installed — no free alternatives in catalog yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }

    // MARK: Breakdown

    @ViewBuilder
    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Breakdown")
                .font(.headline)
            HStack(spacing: 12) {
                breakdownPill(
                    label: "Subscription",
                    count: summary.subscriptionCount,
                    annualUSD: summary.subscriptionAnnualUSD,
                    tint: .red.opacity(0.7))
                breakdownPill(
                    label: "One-time",
                    count: summary.oneTimeCount,
                    annualUSD: summary.oneTimeAnnualUSD,
                    tint: .orange.opacity(0.7))
                breakdownPill(
                    label: "Freemium",
                    count: summary.freemiumCount,
                    annualUSD: summary.freemiumAnnualUSD,
                    tint: .blue.opacity(0.7))
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func breakdownPill(label: String, count: Int, annualUSD: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(count) · ~$\(Int(annualUSD))/yr")
                .font(.system(.subheadline, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.18))
        )
    }

    // MARK: Paid-apps list

    @ViewBuilder
    private var paidAppsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paid apps")
                .font(.headline)
            ForEach(rows, id: \.bundleID) { row in
                PaidAppRow(row: row, vm: vm)
            }
        }
    }
}

// MARK: - SavingsSummary

@MainActor
struct SavingsSummary {
    let totalPaidCount: Int
    let totalAnnualUSD: Double
    let replaceableAnnualUSD: Double
    let subscriptionCount: Int
    let subscriptionAnnualUSD: Double
    let oneTimeCount: Int
    let oneTimeAnnualUSD: Double
    let freemiumCount: Int
    let freemiumAnnualUSD: Double

    var formattedAnnualUSD: String {
        Self.formatUSD(totalAnnualUSD)
    }
    var formattedReplaceableUSD: String {
        Self.formatUSD(replaceableAnnualUSD)
    }

    private static func formatUSD(_ v: Double) -> String {
        let rounded = Int(v.rounded())
        if rounded < 1000 { return "$\(rounded)" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return "$" + (formatter.string(from: NSNumber(value: rounded)) ?? String(rounded))
    }

    init(installedApps: [SovereigntyScanner.InstalledApp]) {
        var rows: [SavingsRow] = SavingsRow.compute(installedApps: installedApps)
        self.totalPaidCount = rows.count
        self.totalAnnualUSD = rows.compactMap { $0.pricing.annualizedUSD }.reduce(0, +)
        self.replaceableAnnualUSD = rows
            .filter { !$0.freeAlternatives.isEmpty }
            .compactMap { $0.pricing.annualizedUSD }
            .reduce(0, +)
        self.subscriptionCount = rows.filter { $0.pricing.model == .subscription }.count
        self.subscriptionAnnualUSD = rows
            .filter { $0.pricing.model == .subscription }
            .compactMap { $0.pricing.annualizedUSD }
            .reduce(0, +)
        self.oneTimeCount = rows.filter { $0.pricing.model == .oneTime }.count
        self.oneTimeAnnualUSD = rows
            .filter { $0.pricing.model == .oneTime }
            .compactMap { $0.pricing.annualizedUSD }
            .reduce(0, +)
        self.freemiumCount = rows.filter { $0.pricing.model == .freemium }.count
        self.freemiumAnnualUSD = rows
            .filter { $0.pricing.model == .freemium }
            .compactMap { $0.pricing.annualizedUSD }
            .reduce(0, +)
    }
}

// MARK: - SavingsRow

@MainActor
struct SavingsRow {
    let bundleID: String
    let displayName: String
    let icon: NSImage?
    let pricing: AppPricing.Pricing
    let freeAlternatives: [SovereigntyCatalog.Alternative]

    /// Compute the rows: filter the installed apps to those with a
    /// pricing record + a paid model, then look up free alternatives
    /// from Sovereignty.
    static func compute(installedApps: [SovereigntyScanner.InstalledApp]) -> [SavingsRow] {
        var out: [SavingsRow] = []
        for app in installedApps {
            guard let pricing = AppPricing.pricing(for: app.id) else { continue }
            // Skip pure-free entries — they don't generate cost rows.
            // Freemium + subscription + one-time + trial all surface.
            if pricing.model == .free && !pricing.freeTier { continue }
            if pricing.model == .free { continue }

            let freeAlts = freeAlternativesFor(bundleID: app.id)
            let icon = NSWorkspace.shared.icon(forFile: app.bundleURL.path)
            out.append(SavingsRow(
                bundleID: app.id,
                displayName: app.name,
                icon: icon,
                pricing: pricing,
                freeAlternatives: freeAlts
            ))
        }
        // Sort: highest annualized cost first.
        return out.sorted { ($0.pricing.annualizedUSD ?? 0) > ($1.pricing.annualizedUSD ?? 0) }
    }

    /// Free alternatives for a given target bundle ID.  Filters to
    /// `.oss` / `.europeAndOSS` origins (genuinely free) AND the
    /// new `.directDownload` / `.versionEmbedded` deliveryKinds
    /// (real binaries, not SaaS sign-up walls).
    static func freeAlternativesFor(bundleID: String) -> [SovereigntyCatalog.Alternative] {
        guard let entry = SovereigntyCatalog.entries.first(where: { $0.targetBundleID == bundleID })
        else { return [] }
        let eligibleKinds: Set<SovereigntyCatalog.DeliveryKind> = [
            .directDownload, .versionEmbedded, .homebrew
        ]
        return entry.alternatives.filter { alt in
            // Free origin
            (alt.origin == .oss || alt.origin == .europeAndOSS)
            // Not a SaaS / paid wall
            && eligibleKinds.contains(alt.effectiveDeliveryKind)
        }
        .prefix(2)  // top 2 per target — choice paralysis kills action
        .map { $0 }
    }
}

// MARK: - PaidAppRow

@MainActor
private struct PaidAppRow: View {
    let row: SavingsRow
    let vm: SplynekViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let icon = row.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.displayName)
                            .font(.subheadline.weight(.semibold))
                        modelBadge
                    }
                    Text("~$\(Int(row.pricing.approxUSD ?? 0))/\(row.pricing.billingCycle?.displayLabel ?? "?") · ~$\(Int(row.pricing.annualizedUSD ?? 0))/yr")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                if let src = row.pricing.sourceURL {
                    Link(destination: src) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .help("View pricing on the publisher's site")
                }
            }
            if !row.freeAlternatives.isEmpty {
                Divider().padding(.vertical, 2)
                ForEach(row.freeAlternatives, id: \.id) { alt in
                    altSuggestion(alt: alt, savingsUSD: row.pricing.annualizedUSD ?? 0)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }

    @ViewBuilder
    private var modelBadge: some View {
        Text(row.pricing.model.displayLabel)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(modelBadgeColor.opacity(0.18)))
            .foregroundStyle(modelBadgeColor)
    }

    private var modelBadgeColor: Color {
        switch row.pricing.model {
        case .free, .freemium: return .blue
        case .oneTime:         return .orange
        case .subscription:    return .red
        case .trial:           return .gray
        }
    }

    @ViewBuilder
    private func altSuggestion(alt: SovereigntyCatalog.Alternative, savingsUSD: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(alt.name)
                        .font(.subheadline.weight(.medium))
                    Text("·").font(.caption).foregroundStyle(.tertiary)
                    Text("Save ~$\(Int(savingsUSD))/yr")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .monospacedDigit()
                }
                Text(alt.note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if let dl = alt.downloadURL,
               (dl.scheme ?? "").lowercased() == "https" {
                Button {
                    vm.urlText = dl.absoluteString
                    vm.start()
                } label: {
                    Label("Install", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Link(destination: alt.homepage) {
                    Label("Visit", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}
#endif
