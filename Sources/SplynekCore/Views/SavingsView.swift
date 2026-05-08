// Copyright © 2026 Splynek. MIT.
//
// SavingsView — v2 (2026-05-08).  Visual revolution + tier picker.
//
// Design moves:
//   1. Big-number hero (recovered + potential) with comparison
//      framing.  The previous flat copy understated the value.
//   2. Vertical SwapCard — paid stack on top, alternative beneath,
//      with a clear ↓ "can be replaced by" arrow between them.
//      Reads as a substitution, not as a side-by-side comparison.
//   3. Per-app tier picker.  Many users on Claude / Adobe / JetBrains
//      / OpenAI sit on a higher tier than the catalog's default
//      landing rate; the picker honours the user's actual cost.
//
// Persistence: confirmed-switch flags + per-app tier selections
// live in UserDefaults.  Confirmed switches credit cumulatively
// against the recovered total; tier picks recompute the per-app
// annualised cost in real time and bubble up to the hero.

#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

@MainActor
struct SavingsView: View {
    @ObservedObject var vm: SplynekViewModel
    @StateObject private var scanner = SovereigntyScanner()

    /// Bundle IDs the user has confirmed they already switched away
    /// from.  Persisted; drives the cumulative recovered-savings
    /// counter at the top of the hero.
    @State private var confirmedSwitches: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "savingsConfirmedSwitches") ?? []
    )

    /// Per-bundle-ID tier-label override picked by the user.  Stored
    /// as a flat dictionary in UserDefaults so we don't bloat the
    /// schema.  Empty string is treated as "use catalog default".
    @State private var tierByBundleID: [String: String] = (
        UserDefaults.standard.dictionary(forKey: "savingsTierByBundleID")
            as? [String: String]) ?? [:]

    init(vm: SplynekViewModel) { self.vm = vm }

    private var rows: [SavingsRow] {
        SavingsRow.compute(installedApps: scanner.apps)
    }

    /// Effective annualised cost for one row, taking the user's
    /// tier selection into account when present.  Falls back to the
    /// catalog's default landing tier otherwise.
    private func annualisedCost(for row: SavingsRow) -> Double {
        let tier = tierByBundleID[row.bundleID]
        return row.pricing.annualizedUSD(forTier: tier) ?? 0
    }

    private var totalAnnualUSD: Double {
        rows.map(annualisedCost(for:)).reduce(0, +)
    }

    private var replaceableAnnualUSD: Double {
        rows
            .filter { !$0.freeAlternatives.isEmpty }
            .map(annualisedCost(for:))
            .reduce(0, +)
    }

    private var recoveredAnnualUSD: Double {
        rows
            .filter { confirmedSwitches.contains($0.bundleID) }
            .map(annualisedCost(for:))
            .reduce(0, +)
    }

    private var pendingAnnualUSD: Double {
        rows
            .filter { !$0.freeAlternatives.isEmpty
                      && !confirmedSwitches.contains($0.bundleID) }
            .map(annualisedCost(for:))
            .reduce(0, +)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ContextCard(
                    systemImage: "dollarsign.circle.fill",
                    subtitle: heroCopy,
                    tint: .green
                )
                if scanner.isScanning && rows.isEmpty {
                    inlineScanState
                } else if rows.isEmpty {
                    emptyState
                } else {
                    bigNumberHero
                    paidAppsSection
                    catalogCallout
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
            if scanner.apps.isEmpty && !scanner.isScanning { scanner.scan() }
        }
    }

    private var heroCopy: LocalizedStringKey {
        if scanner.isScanning && rows.isEmpty {
            return "Scanning installed apps and matching them against \(AppPricing.supportedBundleIDs.count) tracked paid apps…"
        }
        if rows.isEmpty {
            return "Your Mac is running lean. The seed catalog covers \(AppPricing.supportedBundleIDs.count) common paid apps and grows each release."
        }
        return "Splynek tracks the paid apps on this Mac and lights a path to free, tested replacements. One click installs the alternative; we never touch the paid app."
    }

    // MARK: Big-number hero

    /// The new headline block.  Two big stat columns: cumulative
    /// recovered (when there are confirmed switches) + remaining
    /// potential.  Comparison framing under each gives emotional
    /// weight to the number ("≈ 12 months of Spotify").
    @ViewBuilder
    private var bigNumberHero: some View {
        let columns: [GridItem] = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        LazyVGrid(columns: columns, spacing: 12) {
            recoveredStatBlock
            potentialStatBlock
        }
    }

    @ViewBuilder
    private var recoveredStatBlock: some View {
        statBlock(
            label: "Recovered",
            valueUSD: recoveredAnnualUSD,
            secondary: confirmedSwitches.isEmpty
                ? "Tick “I’ve already switched” on a row to start counting."
                : "\(confirmedSwitches.count) confirmed switch\(confirmedSwitches.count == 1 ? "" : "es") · \(comparisonFraming(recoveredAnnualUSD))",
            tint: .green,
            isPrimary: recoveredAnnualUSD > 0
        )
    }

    @ViewBuilder
    private var potentialStatBlock: some View {
        statBlock(
            label: "Could recover",
            valueUSD: pendingAnnualUSD,
            secondary: pendingAnnualUSD > 0
                ? "Across \(pendingRowsCount) app\(pendingRowsCount == 1 ? "" : "s") · \(comparisonFraming(pendingAnnualUSD))"
                : "You’ve switched everything Splynek can replace.",
            tint: .accentColor,
            isPrimary: pendingAnnualUSD > 0
        )
    }

    private var pendingRowsCount: Int {
        rows.filter { !$0.freeAlternatives.isEmpty
                      && !confirmedSwitches.contains($0.bundleID) }.count
    }

    /// One stat-block card.  Big number on top, label above, helper
    /// line below.  The number animates with `.contentTransition`
    /// when tier picks change the underlying total.
    @ViewBuilder
    private func statBlock(label: String, valueUSD: Double,
                           secondary: String, tint: Color,
                           isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatUSD(valueUSD))
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        isPrimary
                            ? AnyShapeStyle(LinearGradient(
                                colors: [tint, tint.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color.primary.opacity(0.55))
                    )
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text("/year")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(secondary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isPrimary
                        ? AnyShapeStyle(LinearGradient(
                            colors: [tint.opacity(0.10), tint.opacity(0.02)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.primary.opacity(0.04))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isPrimary ? tint.opacity(0.30) : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
        )
    }

    /// Convert an annual-USD number into a human comparison frame.
    /// Picks the closest "approachable purchase" — Spotify months,
    /// PS5 games, Apple-Music years — so the savings number reads as
    /// time, not just digits.
    private func comparisonFraming(_ usd: Double) -> String {
        let n = Int(usd.rounded())
        if n <= 0 { return "" }
        if n >= 1500 {
            let macs = Double(n) / 1499.0
            return String(format: "≈ %.1f new MacBook Air every year", macs)
        }
        if n >= 600 {
            let years = Double(n) / 240.0
            return String(format: "≈ %.1f years of Spotify Premium", years)
        }
        if n >= 120 {
            let months = Double(n) / 11.99
            return String(format: "≈ %.0f months of Spotify Premium", months)
        }
        let coffees = Double(n) / 4.5
        return String(format: "≈ %.0f cappuccinos", coffees)
    }

    private func formatUSD(_ v: Double) -> String {
        let rounded = Int(v.rounded())
        if rounded == 0 { return "$0" }
        if rounded < 1000 { return "$\(rounded)" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return "$" + (formatter.string(from: NSNumber(value: rounded)) ?? String(rounded))
    }

    // MARK: Sections

    @ViewBuilder
    private var inlineScanState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Matching installed apps with the pricing catalog…")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    @ViewBuilder
    private var paidAppsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paid apps · free alternatives")
                .font(.headline)
            ForEach(rows, id: \.bundleID) { row in
                SwapCard(
                    row: row,
                    vm: vm,
                    selectedTier: tierByBundleID[row.bundleID],
                    annualised: annualisedCost(for: row),
                    isConfirmed: confirmedSwitches.contains(row.bundleID),
                    onSelectTier: { newLabel in
                        if let newLabel, !newLabel.isEmpty {
                            tierByBundleID[row.bundleID] = newLabel
                        } else {
                            tierByBundleID.removeValue(forKey: row.bundleID)
                        }
                        UserDefaults.standard.set(
                            tierByBundleID, forKey: "savingsTierByBundleID"
                        )
                    },
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("Your Mac is running lean.")
                    .font(.headline)
            }
            Text("No paid apps from Splynek’s seed catalog detected on this Mac. The average Mac has ~$540/year in paid software, mostly subscriptions — you’re already keeping that money.")
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

    @ViewBuilder
    private var catalogCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Looking for more?")
                    .font(.callout.weight(.semibold))
                Text("Splynek’s Sovereignty catalog covers \(AppPricing.supportedBundleIDs.count) paid apps and \(SovereigntyCatalog.entries.count) alternatives.")
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

// MARK: - SavingsRow

@MainActor
struct SavingsRow {
    let bundleID: String
    let displayName: String
    let icon: NSImage?
    let pricing: AppPricing.Pricing
    let freeAlternatives: [SovereigntyCatalog.Alternative]

    static func compute(installedApps: [SovereigntyScanner.InstalledApp]) -> [SavingsRow] {
        var out: [SavingsRow] = []
        for app in installedApps {
            guard let pricing = AppPricing.pricing(for: app.id) else { continue }
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
        return out.sorted { ($0.pricing.annualizedUSD ?? 0) > ($1.pricing.annualizedUSD ?? 0) }
    }

    static func freeAlternativesFor(bundleID: String) -> [SovereigntyCatalog.Alternative] {
        guard let entry = SovereigntyCatalog.entries.first(where: { $0.targetBundleID == bundleID })
        else { return [] }
        let eligibleKinds: Set<SovereigntyCatalog.DeliveryKind> = [
            .directDownload, .versionEmbedded, .homebrew
        ]
        return entry.alternatives.filter { alt in
            (alt.origin == .oss || alt.origin == .europeAndOSS)
            && eligibleKinds.contains(alt.effectiveDeliveryKind)
        }
        .prefix(2)
        .map { $0 }
    }
}

// MARK: - SwapCard (vertical layout)
//
// Was a horizontal three-column layout (paid │ arrow │ free) which
// crammed the visual weight into the centre arrow.  Now a vertical
// stack: paid app on top with red annual cost in big numerals, a
// dedicated tier picker (segmented) when the catalog has tiers, then
// a clear ↓ "can be replaced by" arrow, then the alternative beneath
// with a green "Free" pill and the Install button.  Reads as a
// substitution path, not as a comparison.

@MainActor
private struct SwapCard: View {
    let row: SavingsRow
    let vm: SplynekViewModel
    let selectedTier: String?
    let annualised: Double
    let isConfirmed: Bool
    let onSelectTier: (String?) -> Void
    let onToggleConfirmed: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            paidBlock
            if let tiers = row.pricing.tiers, !tiers.isEmpty {
                tierPicker(tiers: tiers)
            }
            if let alt = row.freeAlternatives.first {
                substitutionArrow
                freeBlock(alt: alt)
                if let extra = row.freeAlternatives.dropFirst().first {
                    extraAlt(alt: extra)
                }
            }
            Divider().opacity(0.3)
            Toggle(isOn: Binding(
                get: { isConfirmed },
                set: { onToggleConfirmed($0) }
            )) {
                if isConfirmed {
                    Text("Switched · +$\(Int(annualised))/yr counted in your savings")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("I’ve already switched away from this app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            .controlSize(.small)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isConfirmed
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color.green.opacity(0.10), Color.green.opacity(0.02)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.primary.opacity(0.03))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isConfirmed ? Color.green.opacity(0.30) : Color.primary.opacity(0.08),
                    lineWidth: 0.5
                )
        )
        .opacity(isConfirmed ? 0.92 : 1.0)
    }

    @ViewBuilder
    private var paidBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = row.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .opacity(isConfirmed ? 0.5 : 1.0)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(row.displayName)
                        .font(.title3.weight(.bold))
                        .strikethrough(isConfirmed, color: .secondary)
                    modelBadge
                }
                if let cycle = currentCycle {
                    Text("costing you ~\(formatUSD(currentApprox))/\(cycle.displayLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("installed paid app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatUSD(annualised))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.red.opacity(0.85))
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text("per year")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentCycle: AppPricing.BillingCycle? {
        if let label = selectedTier,
           let tier = row.pricing.tiers?.first(where: { $0.label == label }) {
            return tier.billingCycle
        }
        return row.pricing.billingCycle
    }

    private var currentApprox: Double {
        if let label = selectedTier,
           let tier = row.pricing.tiers?.first(where: { $0.label == label }) {
            return tier.approxUSD
        }
        return row.pricing.approxUSD ?? 0
    }

    @ViewBuilder
    private func tierPicker(tiers: [AppPricing.Tier]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("YOUR PLAN")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { selectedTier ?? tiers.first?.label ?? "" },
                set: { onSelectTier($0) }
            )) {
                ForEach(tiers) { tier in
                    Text(tier.label).tag(tier.label)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var substitutionArrow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down")
                .font(.headline.weight(.bold))
                .foregroundStyle(.green)
            Text("can be replaced by")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func freeBlock(alt: SovereigntyCatalog.Alternative) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(alt.name)
                        .font(.title3.weight(.bold))
                    StatusPill(text: "FREE", style: .success)
                }
                Text(alt.note.isEmpty ? originLabel(alt.origin) : alt.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            installOrVisitButton(for: alt)
        }
    }

    @ViewBuilder
    private func extraAlt(alt: SovereigntyCatalog.Alternative) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .foregroundStyle(.green.opacity(0.7))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(alt.name)
                    .font(.caption.weight(.semibold))
                Text(alt.note.isEmpty ? originLabel(alt.origin) : alt.note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            installOrVisitButton(for: alt)
        }
        .padding(.leading, 32)
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
        } else {
            Link(destination: alt.homepage) {
                Label("Visit", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func formatUSD(_ v: Double) -> String {
        let rounded = Int(v.rounded())
        if rounded == 0 { return "$0" }
        if rounded < 1000 { return "$\(rounded)" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return "$" + (formatter.string(from: NSNumber(value: rounded)) ?? String(rounded))
    }
}
#endif
