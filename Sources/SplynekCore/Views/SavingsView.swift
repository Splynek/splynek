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

    /// Bundle IDs the user has confirmed they already switched away
    /// from.  Persisted to UserDefaults; drives the cumulative
    /// savings counter at the top.
    @State private var confirmedSwitches: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "savingsConfirmedSwitches") ?? []
    )

    init(vm: SplynekViewModel) { self.vm = vm }

    private var summary: SavingsSummary {
        SavingsSummary(installedApps: scanner.apps)
    }
    private var rows: [SavingsRow] {
        SavingsRow.compute(installedApps: scanner.apps)
    }
    /// Cumulative recovered annual spend across confirmed switches.
    private var recoveredAnnualUSD: Double {
        rows
            .filter { confirmedSwitches.contains($0.bundleID) }
            .compactMap { $0.pricing.annualizedUSD }
            .reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                summaryStrip
                if !rows.isEmpty {
                    paidAppsSection
                    catalogCallout
                } else {
                    emptyState
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
    private var heroCard: some View {
        ContextCard(
            systemImage: "dollarsign.circle.fill",
            subtitle: heroCopy,
            tint: .green
        )
    }

    private var heroCopy: LocalizedStringKey {
        if scanner.isScanning {
            return "Scanning installed apps to find paid software with free alternatives…"
        }
        if rows.isEmpty {
            return "Your Mac has no paid software Splynek can map to free alternatives. The seed catalog covers ~\(AppPricing.supportedBundleIDs.count) common paid apps and grows each release."
        }
        let replaceable = summary.replaceableAnnualUSD
        if replaceable > 0 {
            return "About **\(summary.formattedReplaceableUSD)/year** of your installed paid apps have a tested free alternative. One click installs the replacement; we don't touch the paid app."
        }
        return "\(summary.totalPaidCount) paid \(summary.totalPaidCount == 1 ? "app" : "apps") installed. No free alternative in the catalog yet — we'll keep watching."
    }

    /// Compact 1-line summary beneath the hero.  Replaces the prior
    /// 3-pill breakdown (Subscription/One-time/Freemium with $0/$0/$X)
    /// — which was meaningless when most users have only one paid app.
    @ViewBuilder
    private var summaryStrip: some View {
        if !rows.isEmpty {
            HStack(spacing: 10) {
                if recoveredAnnualUSD > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("Recovered ~$\(Int(recoveredAnnualUSD))/yr · \(confirmedSwitches.count) confirmed")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                    }
                }
                Spacer()
                let replaceableCount = rows.filter { !$0.freeAlternatives.isEmpty }.count
                Text("\(rows.count) paid · \(replaceableCount) with free alternative · ~\(summary.formattedReplaceableUSD)/yr recoverable")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: Paid-apps list

    @ViewBuilder
    private var paidAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paid apps · free alternatives")
                .font(.headline)
            ForEach(rows, id: \.bundleID) { row in
                SwapCard(
                    row: row,
                    vm: vm,
                    isConfirmed: confirmedSwitches.contains(row.bundleID),
                    onToggleConfirmed: { newVal in
                        if newVal {
                            confirmedSwitches.insert(row.bundleID)
                        } else {
                            confirmedSwitches.remove(row.bundleID)
                        }
                        UserDefaults.standard.set(
                            Array(confirmedSwitches),
                            forKey: "savingsConfirmedSwitches"
                        )
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !scanner.isScanning {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("Your Mac is running lean.")
                        .font(.headline)
                }
                Text("No paid apps from Splynek's seed catalog detected on this Mac. The average Mac has ~$540/year in paid software, mostly subscriptions — you're keeping that money.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.green.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.18), lineWidth: 0.5)
            )
        }
    }

    /// Bottom CTA — links to Sovereignty for the full catalog browse.
    /// Splynek already has the data; this surfaces the bridge so a
    /// user finishing Savings has a next step instead of a dead end.
    @ViewBuilder
    private var catalogCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Looking for more?")
                    .font(.callout.weight(.semibold))
                Text("Splynek's Sovereignty catalog covers \(AppPricing.supportedBundleIDs.count) paid apps and \(SovereigntyCatalog.entries.count) alternatives.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                NotificationCenter.default.post(
                    name: .splynekShowSovereignty, object: nil
                )
            } label: {
                Label("Open Sovereignty", systemImage: "arrow.right")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
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

// MARK: - SwapCard
//
// 2026-05-08 revolution.  Was `PaidAppRow` — a tall stacked layout
// where the paid app and the alternatives were typographic siblings,
// hard to read as "this becomes that".  Now a horizontal swap-card:
//
//   ┌─[icon] Paid · €240/yr   →   [icon] Alternative · Free [Install]┐
//   │                                                                │
//   │ Subscription · IA                  Open-source · IA local       │
//   │                                                                │
//   │ ☐ I've already switched                                         │
//   └────────────────────────────────────────────────────────────────┘
//
// The swap reads left-to-right; the green arrow + "→" label make
// the substitution explicit.  An "I've already switched" toggle
// per row drives the cumulative-savings counter at the top of the
// view, persisted via UserDefaults.

@MainActor
private struct SwapCard: View {
    let row: SavingsRow
    let vm: SplynekViewModel
    let isConfirmed: Bool
    let onToggleConfirmed: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let alt = row.freeAlternatives.first {
                swapHeader(alt: alt)
                if let extra = row.freeAlternatives.dropFirst().first {
                    Divider().opacity(0.3)
                    altSuggestion(alt: extra,
                                  savingsUSD: row.pricing.annualizedUSD ?? 0,
                                  compact: true)
                }
            } else {
                paidOnlyHeader
            }
            if !row.freeAlternatives.isEmpty {
                Divider().opacity(0.3)
                Toggle(isOn: Binding(
                    get: { isConfirmed },
                    set: { onToggleConfirmed($0) }
                )) {
                    Text(isConfirmed
                         ? "Switched · counted in savings"
                         : "I've already switched")
                        .font(.caption)
                        .foregroundStyle(isConfirmed ? .green : .secondary)
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isConfirmed
                      ? Color.green.opacity(0.08)
                      : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isConfirmed
                              ? Color.green.opacity(0.30)
                              : Color.clear, lineWidth: 0.5)
        )
        .opacity(isConfirmed ? 0.85 : 1.0)
    }

    /// The big swap row: paid app on the left, arrow in the middle,
    /// alternative on the right with a one-click Install button.
    @ViewBuilder
    private func swapHeader(alt: SovereigntyCatalog.Alternative) -> some View {
        HStack(alignment: .center, spacing: 10) {
            // Left side: paid app
            HStack(spacing: 8) {
                if let icon = row.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .opacity(isConfirmed ? 0.5 : 1.0)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(row.displayName)
                            .font(.subheadline.weight(.semibold))
                            .strikethrough(isConfirmed, color: .secondary)
                        modelBadge
                    }
                    Text("~$\(Int(row.pricing.annualizedUSD ?? 0))/yr")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.red.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Arrow with label
            VStack(spacing: 1) {
                Image(systemName: "arrow.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
                Text("can become")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Right side: alternative
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(alt.name)
                            .font(.subheadline.weight(.semibold))
                        StatusPill(text: "FREE", style: .success)
                    }
                    Text(originLabel(alt.origin))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.green)
                }
                Spacer(minLength: 0)
                installOrVisitButton(for: alt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// When there are no free alternatives in the catalog, just show
    /// the paid app row.  Future commits may surface "watch for
    /// alternatives" subscriptions here.
    @ViewBuilder
    private var paidOnlyHeader: some View {
        HStack(spacing: 10) {
            if let icon = row.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.displayName).font(.subheadline.weight(.semibold))
                    modelBadge
                }
                Text("~$\(Int(row.pricing.annualizedUSD ?? 0))/yr · no free alternative in catalog yet")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
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
    }

    @ViewBuilder
    private var modelBadge: some View {
        Text(row.pricing.model.displayLabel)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 5)
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

    private func originLabel(_ origin: SovereigntyCatalog.Origin) -> String {
        switch origin {
        case .oss:           return "Open source"
        case .europeAndOSS:  return "EU · open source"
        case .europe:        return "EU"
        case .unitedStates:  return "Free"
        case .china:         return "Free"
        case .russia:        return "Free"
        case .other:         return "Free"
        }
    }

    /// Compact secondary-alternative line.  Same copy shape as before
    /// when there's a second free option.
    @ViewBuilder
    private func altSuggestion(alt: SovereigntyCatalog.Alternative, savingsUSD: Double, compact: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.green.opacity(0.7))
            VStack(alignment: .leading, spacing: 1) {
                Text(alt.name)
                    .font(.caption.weight(.semibold))
                Text(alt.note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            installOrVisitButton(for: alt)
        }
    }

    /// One unified affordance — pipeline-install when we have a real
    /// HTTPS download URL; otherwise a plain Visit link to the
    /// homepage.  No mystery green arrows.
    @ViewBuilder
    private func installOrVisitButton(for alt: SovereigntyCatalog.Alternative) -> some View {
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
            .help("Splynek downloads + verifies + installs the alternative. The paid app stays on this Mac.")
        } else {
            Link(destination: alt.homepage) {
                Label("Visit", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open the publisher's site — no automatic install for this alternative.")
        }
    }
}
#endif
