import SwiftUI
import UniformTypeIdentifiers  // v1.7.x: UTType.pdf / UTType.png for the export save panels

/// v1.5: **Trust** tab.  Surfaces public-record concerns (App Store
/// privacy labels, regulatory enforcement actions, CVEs, confirmed
/// breaches, vendor security advisories) for the user's installed
/// Mac apps so they can make informed choices.
///
/// **Privacy contract** (matches Sovereignty exactly):
///   • Reuses `SovereigntyScanner` — enumeration only, on-device,
///     opt-in, no network.
///   • Catalog data is bundled with the app; no calls home.
///   • AI fallback (Pro) suggests *alternatives*, never risk claims.
///
/// **Defamation contract:** every concern shown carries a primary-
/// source citation (Apple, regulator, NVD, HIBP, vendor advisory)
/// with a date.  The UI never editorialises; it surfaces facts.
/// Source URLs are clickable — the user can verify any claim.
///
/// **Score model:** the `TrustScorer` produces a 0–100 score plus
/// a categorical level; the UI ALWAYS shows score + level + the
/// individual concern labels with citations.  Never the score
/// alone — score-without-evidence is the false-precision trap.
///
/// **Alternative lookup chain** (when a target has concerns):
///   1. SovereigntyCatalog.alternatives(for: bundleID) → European
///      / open-source picks.  Always tried first.
///   2. TrustCatalog.profile(for:).fallbackAlternatives → trusted
///      alternatives that may be non-EU / non-OSS but score better
///      on the user's weighted axes.
///   3. (Pro only) AI fallback — local LLM suggests project names,
///      no risk claims, no homepage validation.
struct TrustView: View {
    @ObservedObject var vm: SplynekViewModel
    @StateObject private var scanner = SovereigntyScanner()
    @State private var filter: Filter = .all
    @State private var search: String = ""

    /// v1.7.x: last export error (PDF or PNG).  Surfaced as an alert
    /// to keep the failure inline rather than swallowing it.
    @State private var exportError: String? = nil

    enum Filter: String, CaseIterable, Identifiable {
        case all, severeOnly, privacy, security, trust, businessModel
        var id: String { rawValue }
        var label: LocalizedStringKey {
            switch self {
            case .all:           return "All apps"
            case .severeOnly:    return "High risk only"
            case .privacy:       return "Privacy"
            case .security:      return "Security"
            case .trust:         return "Trust"
            case .businessModel: return "Business model"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 2026-05-08: ContextCard always present.  Splash
                // retired — see SovereigntyView for the same change.
                // Auto-scan on appear means scan results appear
                // directly without a click on the splash button.
                // 2026-05-08: subtitle reverted to the catalog-
                // translated short version.  The scale-direction
                // info that briefly lived here ("0 (clean) → 100
                // (severe + numerous concerns)") is redundant with
                // the per-row gauge labels below, which carry it
                // visually + textually right next to every score.
                ContextCard(
                    systemImage: "checkmark.seal",
                    subtitle: "See what public records say about your installed apps — App Store privacy labels, regulatory rulings, confirmed breaches, vendor security advisories. Every claim cites its primary source. Everything stays local.",
                    tint: .orange
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

                if scanner.apps.isEmpty {
                    inlineScanState
                } else {
                    scanResults
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Trust")
        .onAppear {
            // 2026-05-08: auto-scan replaces the pre-scan splash.
            // Idempotent — re-entries while a scan is in flight
            // become no-ops via SovereigntyScanner.scan()'s guard.
            if scanner.apps.isEmpty && !scanner.isScanning {
                scanner.scan()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportPDF()
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext")
                }
                .help("Export the full Trust scan as a research-grade PDF (all apps, every concern, every primary-source citation)")
                .disabled(scanner.apps.isEmpty || scanner.isScanning)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportPNG()
                } label: {
                    Label("Export PNG", systemImage: "photo")
                }
                .help("Export the top 10 most-concerning apps as a 1200×1200 PNG suitable for social sharing")
                .disabled(scanner.apps.isEmpty || scanner.isScanning)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    scanner.scan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .help("Re-enumerate installed apps")
                .disabled(scanner.isScanning)
            }
        }
        .alert("Export failed",
               isPresented: Binding(
                   get: { exportError != nil },
                   set: { if !$0 { exportError = nil } }
               )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Trust export (PDF + PNG)

    /// v1.7.x: surface a save panel + render the full Trust scan
    /// as a multi-page PDF.  Designed as a research-grade artifact
    /// (cover, methodology, summary stats, per-app cited concerns)
    /// — see `TrustExport.renderPDF` + `TrustReportPDFView`.
    @MainActor
    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "splynek-trust-\(Self.todayStamp).pdf"
        panel.message = Bundle.splynekCore.localizedStringForAppKit(
            "Export the full Trust scan as a research-grade PDF (all apps, every concern, every primary-source citation)"
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scored = TrustExport.rankedScored(
            installedApps: scanner.apps,
            weights: vm.trustWeights
        )
        do {
            try TrustExport.renderPDF(scored, to: url)
        } catch {
            exportError = "Couldn't write PDF: \(error.localizedDescription)"
        }
    }

    /// v1.7.x: surface a save panel + render the top-10 most-concerning
    /// apps as a 1200×1200 PNG suitable for Twitter / Mastodon / Bluesky.
    @MainActor
    private func exportPNG() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "splynek-trust-top10-\(Self.todayStamp).png"
        panel.message = Bundle.splynekCore.localizedStringForAppKit(
            "Export the top 10 most-concerning apps as a 1200×1200 PNG suitable for social sharing"
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scored = TrustExport.rankedScored(
            installedApps: scanner.apps,
            weights: vm.trustWeights
        )
        do {
            try TrustExport.renderPNG(scored, topN: 10, to: url)
        } catch {
            exportError = "Couldn't write PNG: \(error.localizedDescription)"
        }
    }

    /// Today as YYYY-MM-DD for filename stamping.
    private static var todayStamp: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Subviews

    // v1.5.3: contextCard moved to shared `ContextCard` in Components.swift

    // 2026-05-08: pre-scan splash retired.  See SovereigntyView for
    // the matching change.  Replaced with this small inline strip
    // that shows during the auto-scan or surfaces lastError when
    // the scanner couldn't enumerate anything.
    @ViewBuilder
    private var inlineScanState: some View {
        VStack(spacing: 12) {
            if scanner.isScanning {
                ProgressView()
                Text("Scanning installed apps…")
                    .font(.callout).foregroundStyle(.secondary)
            } else if let err = scanner.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
                Text(err)
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again") { scanner.scan() }
                    .controlSize(.small)
            } else {
                Image(systemName: "tray")
                    .foregroundStyle(.secondary)
                    .font(.title2)
                Text("No installed apps detected. Use Rescan in the toolbar.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    @ViewBuilder
    private var scanResults: some View {
        VStack(spacing: 0) {
            filterBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // 2026-05-09 Sprint 1 PRO-PLUS-IPHONE: Trust
                    // Watcher card surfaces policy / ToS changes
                    // detected by the daily diff sweep.  Pro-only;
                    // free users see a Pro-locked teaser instead.
                    trustWatcherCard
                    // 2026-05-09: weights card was previously in
                    // Settings — moved here so the "tune the score
                    // I'm seeing" affordance lives next to the score
                    // it tunes.  Collapsed by default so the per-app
                    // rows remain the primary content.
                    weightsDisclosure
                    if matchedRows.isEmpty && !scanner.isScanning {
                        noMatchesFooter
                    } else {
                        ForEach(matchedRows, id: \.app.id) { row in
                            resultRow(row)
                        }
                        legalFootnote.padding(.top, 16)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Weights (moved from SettingsView 2026-05-09)
    //
    // The Trust score is a weighted sum across four axes (privacy /
    // security / trust / business model).  Defaults match the
    // TrustScorer.Weights.default values.  Putting the sliders here
    // — collapsed by default — means the user finds them at the
    // moment they're looking at a score they want to tune.
    // Previously buried in Settings, two screens away from the data.

    @State private var weightsExpanded = false

    @ViewBuilder
    private var weightsDisclosure: some View {
        DisclosureGroup(isExpanded: $weightsExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Adjust how the Trust tab weighs each axis when scoring your installed apps. A user who cares mostly about privacy can dial security down — the underlying concerns don't change, only the score that summarises them. Defaults: security 1.5, privacy 1.0, trust 1.0, business model 0.6.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                weightSlider(label: "Privacy",
                             accessibilityLabel: "Privacy",
                             systemImage: "eye.slash",
                             tint: .blue,
                             value: $vm.trustWeightPrivacy)
                weightSlider(label: "Security",
                             accessibilityLabel: "Security",
                             systemImage: "shield.fill",
                             tint: .red,
                             value: $vm.trustWeightSecurity)
                weightSlider(label: "Trust / reputation",
                             accessibilityLabel: "Trust",
                             systemImage: "scalemass",
                             tint: .orange,
                             value: $vm.trustWeightTrust)
                weightSlider(label: "Business model",
                             accessibilityLabel: "Business model",
                             systemImage: "creditcard",
                             tint: .purple,
                             value: $vm.trustWeightBusinessModel)
                HStack {
                    Spacer()
                    Button("Reset to defaults") {
                        vm.resetTrustWeightsToDefault()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(.tint)
                Text("Score weights")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "P %.1f · S %.1f · T %.1f · B %.1f",
                            vm.trustWeightPrivacy, vm.trustWeightSecurity,
                            vm.trustWeightTrust, vm.trustWeightBusinessModel))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    @ViewBuilder
    private func weightSlider(
        label: LocalizedStringKey,
        accessibilityLabel: String,
        systemImage: String,
        tint: Color,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.callout)
                    .frame(width: 18)
                Text(label).font(.callout)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
            Slider(value: value, in: 0.1...3.0, step: 0.1)
                .tint(tint)
                .accessibilityLabel(Text(accessibilityLabel + " weight"))
                .accessibilityValue(String(format: "%.1f", value.wrappedValue))
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 220)

            TextField("Search by app name", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)

            Spacer()

            if scanner.isScanning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                // v1.4 plural-free phrasing — auto-localised via xcstrings.
                Text("\(matchedRows.count) / \(scanner.apps.count) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Row model

    /// One row = one installed app + its TrustCatalog profile (if any)
    /// + the computed score.  Pre-compute scores once per scan so the
    /// list scrolls without per-frame recomputation.
    struct Row {
        let app: SovereigntyScanner.InstalledApp
        let entry: TrustCatalog.Entry
        let score: TrustScorer.Score
    }

    private var matchedRows: [Row] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return scanner.apps.compactMap { app -> Row? in
            guard let entry = TrustCatalog.profile(for: app.id) else { return nil }
            // v1.5.4: pass user-customised weights (Settings → Trust
            // weights card).  Defaults match TrustScorer.Weights.default.
            let score = TrustScorer.score(entry, weights: vm.trustWeights)
            // Filter: severeOnly = high or severe.  Axis filters keep
            // entries that have at least one concern on that axis.
            switch filter {
            case .all:           break
            case .severeOnly:    if score.level != .high && score.level != .severe { return nil }
            case .privacy:       if !entry.concerns.contains(where: { $0.axis == .privacy }) { return nil }
            case .security:      if !entry.concerns.contains(where: { $0.axis == .security }) { return nil }
            case .trust:         if !entry.concerns.contains(where: { $0.axis == .trust }) { return nil }
            case .businessModel: if !entry.concerns.contains(where: { $0.axis == .businessModel }) { return nil }
            }
            // Search filter — applies to display name.
            if !q.isEmpty && !entry.targetDisplayName.lowercased().contains(q) && !app.name.lowercased().contains(q) {
                return nil
            }
            return Row(app: app, entry: entry, score: score)
        }
        // Sort by score descending so worst offenders rise to the top
        // (the entries the user is most likely to care about).
        .sorted { $0.score.value > $1.score.value }
    }

    @ViewBuilder
    private func resultRow(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // v1.5.6+: the visual header reads as four separate
            // elements to a sighted user but that's noisy via
            // VoiceOver.  Combine into one utterance: app name,
            // version, score, level.  Each individual element keeps
            // its own a11y label for users who turn on Element-only
            // navigation, but Group-level traversal hits this once.
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(row.app.name)
                    .font(.system(.headline, design: .rounded))
                if let v = row.app.version {
                    Text("v\(v)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                scoreBadge(row.score)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(rowHeaderAccessibilityLabel(row))

            // 2026-05-08: gauge bar with percentile context.  The
            // bar is a green→yellow→orange→red horizontal gradient
            // with a position dot at the app's score, so the
            // direction (left = clean, right = high concern) reads
            // at a glance.  The percentile line says how this app
            // compares with the rest of the user's installed apps
            // — "higher than X% of your apps" is more actionable
            // than a bare number.
            riskGauge(score: row.score, percentile: percentileFor(row))

            // Concern labels — top 3 visible inline; full list inside
            // the disclosure below so the row stays compact.
            FlowLayout(spacing: 6) {
                ForEach(row.entry.concerns.prefix(4), id: \.id) { c in
                    concernLabel(c)
                }
                if row.entry.concerns.count > 4 {
                    Text("+\(row.entry.concerns.count - 4) more")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        .foregroundStyle(.secondary)
                }
            }

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 12) {
                    // v1.5.4: per-axis breakdown — shows the user how
                    // their Settings weights translate into the score.
                    // Only meaningful when there's at least one concern;
                    // a 0/0/0/0 breakdown reads as misleading "no data".
                    if !row.entry.concerns.isEmpty {
                        scoreBreakdown(row.score)
                        Divider()
                    }
                    detailedConcerns(row.entry)
                    Divider()
                    alternatives(for: row)
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.tertiary)
                            .font(.caption)
                        Text("Last reviewed \(row.entry.lastReviewed)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Details + alternatives")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(scoreColor(row.score).opacity(0.2), lineWidth: 0.5)
        )
    }

    /// v1.5.4: per-axis score breakdown.  Shows the user how the
    /// weights they set in Settings translate to the score they see.
    /// Empty axes (no concerns of that axis) collapse out so the
    /// breakdown isn't padded with zeros.
    @ViewBuilder
    private func scoreBreakdown(_ score: TrustScorer.Score) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Score breakdown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Adjust weights in Settings → Trust")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            VStack(spacing: 4) {
                ForEach(TrustCatalog.Axis.allCases) { axis in
                    if let points = score.breakdown[axis], points > 0 {
                        breakdownRow(axis: axis, points: points)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func breakdownRow(axis: TrustCatalog.Axis, points: Int) -> some View {
        let pct = min(100, points)
        HStack(spacing: 8) {
            axisIcon(axis)
                .font(.caption)
                .frame(width: 16)
            Text(axis.label)
                .font(.caption)
                .frame(width: 90, alignment: .leading)
            // Mini bar — mirrors the score colour at this magnitude.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barColor(forPoints: points))
                        .frame(width: geo.size.width * Double(pct) / 100.0)
                }
            }
            .frame(height: 6)
            Text("\(points)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    /// Mini-bar colour mirrors the same band thresholds as
    /// `scoreColor(_:)` so the visual reads consistently per row.
    private func barColor(forPoints points: Int) -> Color {
        switch points {
        case 0..<20:  return .green
        case 20..<50: return .yellow
        case 50..<80: return .orange
        default:      return .red
        }
    }

    @ViewBuilder
    private func detailedConcerns(_ entry: TrustCatalog.Entry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(entry.concerns, id: \.id) { c in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        axisIcon(c.axis)
                        Text(c.summary)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        severityPill(c.severity)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Link("\(c.sourceName) · \(c.evidenceDate)",
                             destination: c.evidenceURL)
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
            }
        }
    }

    @ViewBuilder
    private func alternatives(for row: Row) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // v1.5.1: was "Better alternatives" — dropped "better"
            // because that's an editorial judgement we shouldn't be
            // making for the user.  We surface curated options; the
            // user decides what fits.
            Text("Alternatives")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
            // 1. Sovereignty (EU / OSS) first.  Pass each alternative's
            // `downloadURL` through so users get the same one-click
            // Install path Sovereignty offers (Mozilla redirect for
            // Firefox/Thunderbird, Bitwarden's stable redirect, etc.).
            if let sov = SovereigntyCatalog.alternatives(for: row.app.id) {
                ForEach(sov.alternatives.prefix(3)) { alt in
                    altRow(name: alt.name,
                           homepage: alt.homepage,
                           note: alt.note,
                           downloadURL: alt.downloadURL,
                           sourceLabel: "Sovereignty pick")
                }
            } else if !row.entry.fallbackAlternatives.isEmpty {
                // 2. Trust fallback alternatives — these may also carry
                // a `downloadURL` (e.g. Apple Safari is a system app
                // so no download, but a future Trust fallback like
                // Brave or DuckDuckGo could).
                ForEach(row.entry.fallbackAlternatives) { alt in
                    altRow(name: alt.name,
                           homepage: alt.homepage,
                           note: alt.note,
                           downloadURL: alt.downloadURL,
                           sourceLabel: "Trust pick")
                }
            } else {
                Text("No curated alternative for this app yet. Contribute one at github.com/Splynek/splynek.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Shared row renderer for both Sovereignty- and Trust-sourced
    /// alternatives.  When `downloadURL` is present and https, the
    /// row shows an "Install" button that hands the URL to Splynek's
    /// download engine.  When absent or non-https, it falls back to a
    /// "Visit" link to the homepage — same behaviour as the
    /// Sovereignty tab so users get a consistent ingress.
    @ViewBuilder
    private func altRow(name: String,
                        homepage: URL,
                        note: String,
                        downloadURL: URL?,
                        sourceLabel: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.system(.subheadline, weight: .semibold))
                    Text(sourceLabel)
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .foregroundStyle(.green)
                }
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            altActionButton(name: name, homepage: homepage, downloadURL: downloadURL)
        }
    }

    /// Either "Install" (downloadURL present and https → hand to
    /// `vm.start()`) or "Visit" (open homepage in default browser).
    /// Mirrors `SovereigntyView.actionButton` exactly so the user
    /// gets the same behaviour across tabs.
    @ViewBuilder
    private func altActionButton(name: String, homepage: URL, downloadURL: URL?) -> some View {
        // v1.5.6+: explicit accessibilityLabel naming the alternative
        // — VoiceOver was reading "Install" without context, which
        // is useless when there are 5 alternatives in a row.
        if let dl = downloadURL, isSafeDownloadScheme(dl) {
            Button {
                vm.urlText = dl.absoluteString
                vm.start()
            } label: {
                Label("Install", systemImage: "arrow.down.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Download \(name) via Splynek")
            .accessibilityLabel("Install \(name) via Splynek")
        } else if isSafeHomepageScheme(homepage) {
            Link(destination: homepage) {
                Label("Visit", systemImage: "arrow.up.right.square")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open \(homepage.host ?? name) in your browser")
            .accessibilityLabel("Visit \(name) homepage in browser")
        }
    }

    /// Allow only `https://` for downloads — engine doesn't gain
    /// anything from `http://` (no integrity), and `file://` /
    /// `data:` would let a poisoned catalog leak local files or
    /// trigger arbitrary handlers.  Matches `ViewModel.start()`'s
    /// own scheme gate — both layers enforce, neither relies on
    /// the other.
    private func isSafeDownloadScheme(_ url: URL) -> Bool {
        (url.scheme ?? "").lowercased() == "https"
    }

    /// Allow `https://` (and `http://` for upstreams that haven't
    /// migrated) for homepages opened in the user's browser.
    /// Reject `file://`, `data:`, `javascript:` — `Link` would
    /// happily hand any of those to LaunchServices.
    private func isSafeHomepageScheme(_ url: URL) -> Bool {
        let s = (url.scheme ?? "").lowercased()
        return s == "https" || s == "http"
    }

    // MARK: - Visual atoms

    /// 2026-05-08 v2: badge rebuilt to merge "risk + level" into a
    /// single grammatically-correct phrase.  Was three lines (RISK
    /// / 75/100 / HIGH) which read awkward in pt-PT ("RISCO 75/100
    /// ALTA" — noun-adjective gender mismatch since "risco" is
    /// masculine and "alta" is feminine).  Now two lines: the
    /// 22pt number with `/100` scale, then a single compound
    /// `Risk: <Level>` localised key ("Low risk", "Moderate risk",
    /// "High risk", "Severe risk") which catalogues into a noun
    /// phrase per locale ("Risco alto", "Hohes Risiko", etc.).
    @ViewBuilder
    private func scoreBadge(_ score: TrustScorer.Score) -> some View {
        let color = scoreColor(score)
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(score.value)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text("/100")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(riskLevelLabel(score.level))
                .font(.system(size: 10, weight: .bold))
                .tracking(0.3)
                .textCase(.uppercase)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trust score \(score.value) of 100, level \(levelAccessibilityLabel(score.level))")
    }

    private func scoreColor(_ score: TrustScorer.Score) -> Color {
        switch score.level {
        case .low:       return .green
        case .moderate:  return .yellow
        case .high:      return .orange
        case .severe:    return .red
        }
    }

    /// Horizontal gauge: green → yellow → orange → red gradient with
    /// a position dot at this app's score and an inline percentile
    /// caption underneath.  The gauge spans the full row width so
    /// the eye reads "left = clean, right = lots of concerns"
    /// without any explanatory text.
    @ViewBuilder
    private func riskGauge(score: TrustScorer.Score, percentile: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(LinearGradient(
                            colors: [
                                Color.green.opacity(0.55),
                                Color.yellow.opacity(0.55),
                                Color.orange.opacity(0.55),
                                Color.red.opacity(0.55),
                            ],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 6)
                    let pct = max(0, min(100, score.value))
                    let dotX = geo.size.width * (CGFloat(pct) / 100.0)
                    Circle()
                        .fill(scoreColor(score))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle().strokeBorder(Color.white, lineWidth: 2)
                        )
                        .shadow(color: scoreColor(score).opacity(0.4),
                                radius: 3, y: 1)
                        // 2026-05-08 fix: was `y: 3` which placed the
                        // dot above the bar (bar centre is at
                        // geo.size.height / 2 = 6 — the GeometryReader's
                        // ZStack vertical default is .center, and the
                        // 6pt-tall bar sits at y=3–9, centre y=6).
                        // Use the geometry's centre so the dot stays
                        // perfectly aligned regardless of any future
                        // height tweaks.
                        .position(x: max(6, min(dotX, geo.size.width - 6)),
                                  y: geo.size.height / 2)
                }
            }
            .frame(height: 12)
            HStack(spacing: 4) {
                Text("0 clean")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.green)
                Spacer()
                if let p = percentile {
                    Text("Higher than \(p)% of your installed apps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("high concern 100")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.red)
            }
        }
    }

    /// What % of the user's matched-rows have a STRICTLY LOWER score
    /// than this row.  Returns nil when the row pool is too small
    /// for a meaningful comparison (≤1 entry).
    private func percentileFor(_ row: Row) -> Int? {
        let pool = matchedRows
        guard pool.count > 1 else { return nil }
        let lower = pool.filter { $0.score.value < row.score.value }.count
        let pct = Int((Double(lower) / Double(pool.count - 1)) * 100.0)
        return max(0, min(100, pct))
    }

    private func levelLabel(_ level: TrustScorer.Level) -> LocalizedStringKey {
        switch level {
        case .low:       return "Low"
        case .moderate:  return "Moderate"
        case .high:      return "High"
        case .severe:    return "Severe"
        }
    }

    /// 2026-05-08: compound noun-phrase key for the score-badge label.
    /// Returns "Low risk" / "Moderate risk" / "High risk" / "Severe
    /// risk" — each catalogued as a single phrase per locale so the
    /// noun-adjective agreement falls out naturally (pt-PT "Risco
    /// alto" instead of the broken "RISCO + High → Alta" composition).
    private func riskLevelLabel(_ level: TrustScorer.Level) -> LocalizedStringKey {
        switch level {
        case .low:       return "Low risk"
        case .moderate:  return "Moderate risk"
        case .high:      return "High risk"
        case .severe:    return "Severe risk"
        }
    }

    /// v1.5.6+: combined-utterance row header for VoiceOver.  Reads
    /// as one sentence, e.g. "TikTok version 28.4.0, trust score 85
    /// out of 100, severe risk, 7 concerns".  Matches the visual
    /// hierarchy a sighted user gets without four separate stops.
    private func rowHeaderAccessibilityLabel(_ row: Row) -> String {
        var parts: [String] = []
        parts.append(row.app.name)
        if let v = row.app.version { parts.append("version \(v)") }
        parts.append("trust score \(row.score.value) of 100")
        parts.append(levelAccessibilityLabel(row.score.level))
        let n = row.entry.concerns.count
        parts.append(n == 1 ? "1 concern" : "\(n) concerns")
        return parts.joined(separator: ", ")
    }

    private func levelAccessibilityLabel(_ level: TrustScorer.Level) -> String {
        switch level {
        case .low:       return "low risk"
        case .moderate:  return "moderate risk"
        case .high:      return "high risk"
        case .severe:    return "severe risk"
        }
    }

    @ViewBuilder
    private func concernLabel(_ c: TrustCatalog.Concern) -> some View {
        let color = severityColor(c.severity)
        HStack(spacing: 4) {
            axisIcon(c.axis).font(.caption2)
            Text(LocalizedStringKey(concernShortLabel(c)))
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(c.axis.label), \(c.severity.label) severity: \(c.summary)")
    }

    private func concernShortLabel(_ c: TrustCatalog.Concern) -> String {
        switch c.kind {
        case .appStoreTrackingData:    return "Tracks across apps"
        case .appStoreLinkedData:      return "Linked data"
        case .appStoreUnlinkedData:    return "Unlinked data"
        case .regulatoryFineGDPR:      return "GDPR fine"
        case .regulatoryFineFTC:       return "FTC action"
        case .regulatoryFineOther:     return "Regulator fine"
        case .courtRuling:             return "Court ruling"
        case .governmentSanction:      return "Sanctioned"
        case .knownCVE:                return "Known CVE"
        case .vendorSecurityAdvisory:  return "Security advisory"
        case .dataBreachConfirmed:     return "Confirmed breach"
        case .adSupportedFree:         return "Ad-supported"
        case .telemetryDefaultOn:      return "Default-on telemetry"
        case .vendorPolicyDataSharing: return "ToS data-sharing"
        }
    }

    @ViewBuilder
    private func axisIcon(_ axis: TrustCatalog.Axis) -> some View {
        switch axis {
        case .privacy:        Image(systemName: "eye.slash")
        case .security:       Image(systemName: "shield.fill")
        case .trust:          Image(systemName: "scalemass")
        case .businessModel:  Image(systemName: "creditcard")
        }
    }

    @ViewBuilder
    private func severityPill(_ s: TrustCatalog.Severity) -> some View {
        let color = severityColor(s)
        Text(severityLabel(s))
            .font(.caption2.weight(.bold))
            .tracking(0.4)
            .textCase(.uppercase)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }

    private func severityLabel(_ s: TrustCatalog.Severity) -> LocalizedStringKey {
        switch s {
        case .low:       return "Low"
        case .moderate:  return "Moderate"
        case .high:      return "High"
        case .severe:    return "Severe"
        }
    }

    private func severityColor(_ s: TrustCatalog.Severity) -> Color {
        switch s {
        case .low:       return .green
        case .moderate:  return .yellow
        case .high:      return .orange
        case .severe:    return .red
        }
    }

    @ViewBuilder
    private var noMatchesFooter: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("No public-record concerns for your installed apps")
                .font(.system(.headline, design: .rounded))
            Text("Either none of your installed apps have catalog entries yet, or the current filter is hiding them. The Trust catalog is intentionally focused on the most-installed apps — community PRs at github.com/Splynek/splynek expand it.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    @ViewBuilder
    private var legalFootnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("How this works")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Trust surfaces public-record facts about your installed apps — Apple's own App Store privacy labels (which developers self-disclose), EU and US regulator decisions, the NVD CVE database, the HIBP breach corpus, and vendor security advisories. We do not editorialise. Every concern shown links to its primary source so you can verify the claim. If you spot inaccurate or outdated information, please open a PR or issue at github.com/Splynek/splynek.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

// MARK: - Lightweight FlowLayout

/// Wraps inline pills onto multiple lines.  Built locally because
/// SwiftUI's `Layout` protocol gives us this in ~20 lines and we
/// don't want a dependency for it.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth && x > 0 {
                x = 0; y += lineHeight + spacing; lineHeight = 0
            }
            lineHeight = max(lineHeight, s.height)
            x += s.width + spacing
        }
        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, lineHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.minX + maxWidth && x > bounds.minX {
                x = bounds.minX; y += lineHeight + spacing; lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            lineHeight = max(lineHeight, s.height)
            x += s.width + spacing
        }
    }
}

// MARK: - Trust Watcher card (2026-05-09 Sprint 1 PRO-PLUS-IPHONE)
//
// Sits at the top of the Trust scan results.  Behaviour:
//   • Pro + 0 alerts          → a green "Watching N apps" status
//                                pill + last-sweep timestamp + a
//                                "Run now" button.
//   • Pro + ≥1 pending alerts → list of alerts with severity-tinted
//                                rows, click-through to the policy
//                                URL, dismiss-each + Clear-all
//                                buttons.
//   • Free                    → ProLockedView upsell — "Get notified
//                                when Privacy Policies change."
//
// Placement above the weights disclosure: alerts are time-sensitive
// content; weights are configuration.  News on top, knobs below.

extension TrustView {

    @ViewBuilder
    fileprivate var trustWatcherCard: some View {
        if vm.license.isPro {
            trustWatcherProCard
        } else {
            ProLockedView(
                featureTitle: "Trust Watcher",
                summary: "Get notified when an app you have installed materially changes its Privacy Policy or Terms of Service. Daily check, fully local — we just hash the public policy page and tell you when the hash changes. Splynek Pro.",
                systemImage: "bell.badge",
                onUnlock: { vm.requestProUnlock() }
            )
        }
    }

    @ViewBuilder
    fileprivate var trustWatcherProCard: some View {
        let state = vm.trustWatchState
        let pending = state.alerts.filter { !$0.acknowledged }
        TitledCard(
            title: "Trust Watcher",
            systemImage: "bell.badge",
            accessory: AnyView(
                StatusPill(
                    text: pending.isEmpty
                        ? "WATCHING \(TrustWatchCatalog.watchedBundleIDs.count)"
                        : "\(pending.count) NEW",
                    style: pending.isEmpty ? .success : .warning
                )
            )
        ) {
            // Sprint 3 (2026-05-10): record the view as engagement
            // — tracks "user looked at the watcher card" without
            // any off-device telemetry.
            Color.clear
                .frame(width: 0, height: 0)
                .onAppear {
                    vm.engagementStore.mutate { $0.trustWatcherViews += 1 }
                }
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily diff of Privacy Policies + ToS for popular apps. Splynek hashes the public policy page; when the hash changes you'll see the alert here. Each alert links to the live page so you can read what changed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if pending.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(lastSweepLabel(state.lastSweepAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            Task { _ = await vm.runTrustWatcherNow() }
                        } label: {
                            Label("Run now", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ForEach(pending) { alert in
                        trustWatcherAlertRow(alert)
                    }
                    HStack(spacing: 10) {
                        Spacer()
                        Button {
                            vm.acknowledgeAllTrustAlerts()
                        } label: {
                            Label("Clear all", systemImage: "tray")
                        }
                        .buttonStyle(.bordered)
                        Button {
                            Task { _ = await vm.runTrustWatcherNow() }
                        } label: {
                            Label("Run now", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    @ViewBuilder
    fileprivate func trustWatcherAlertRow(_ alert: TrustWatchAlert) -> some View {
        let tint: Color = {
            switch alert.severity {
            case .info:     return .blue
            case .notice:   return .orange
            case .material: return .red
            }
        }()
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: alert.severity == .material
                  ? "exclamationmark.triangle.fill"
                  : "bell.fill")
                .foregroundStyle(tint)
                .font(.callout)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(alert.target.displayName)
                        .font(.callout.weight(.semibold))
                    Text("·").foregroundStyle(.tertiary)
                    Text(alert.target.kind.label)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    StatusPill(text: alert.severity.label.uppercased(),
                               style: alert.severity == .material
                                    ? .danger
                                    : (alert.severity == .notice ? .warning : .info))
                }
                Text(deltaLabel(alert))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button {
                        // Sprint 3 (2026-05-10): record engagement
                        // before opening; pure local counter.
                        vm.engagementStore.mutate { $0.trustWatcherPagesOpened += 1 }
                        NSWorkspace.shared.open(alert.target.url)
                    } label: {
                        Label("View page", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button {
                        vm.acknowledgeTrustAlert(alert.id)
                    } label: {
                        Label("Dismiss", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 0.6)
        )
    }

    fileprivate func deltaLabel(_ alert: TrustWatchAlert) -> String {
        let pct = alert.lengthDeltaFraction * 100
        let sign = pct >= 0 ? "+" : ""
        let pctStr = String(format: "%@%.0f%%", sign, pct)
        let bytes = abs(alert.newLength - alert.previousLength)
        let bytesStr: String
        switch bytes {
        case ..<1024:        bytesStr = "\(bytes) B"
        case ..<1_048_576:   bytesStr = String(format: "%.1f KB", Double(bytes) / 1024.0)
        default:             bytesStr = String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
        }
        return "Body \(pctStr) (\(bytesStr)) on \(prettyDate(alert.observedAt))"
    }

    fileprivate func lastSweepLabel(_ iso: String?) -> String {
        guard let iso else { return "Watcher activated; first sweep within minutes." }
        return "Last check: \(prettyDate(iso))."
    }

    fileprivate func prettyDate(_ iso: String) -> String {
        let isoF = ISO8601DateFormatter()
        isoF.formatOptions = [.withInternetDateTime]
        guard let date = isoF.date(from: iso) else { return iso }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
