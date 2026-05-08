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
                ContextCard(
                    systemImage: "checkmark.seal",
                    subtitle: "See what public records say about your installed apps — App Store privacy labels, regulatory rulings, confirmed breaches, vendor security advisories. Each app's risk score runs **0 (clean) → 100 (severe + numerous concerns)**, with a level word and gauge for quick reading. Every claim cites its primary source. Everything stays local.",
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

    /// 2026-05-08: badge rebuilt for legibility.  The prior layout
    /// showed a bare `75` over `ALTA` — ambiguous ("75 of what?",
    /// "is high good or bad?").  Now: explicit `RISK` framing word
    /// on top, the number rendered as `N/100` so the scale is
    /// self-evident, and the level word in plain language.  A
    /// horizontal gauge with green→red gradient + position dot
    /// renders below the badge in the row body so the user can read
    /// the direction at a glance even without the explanatory copy
    /// in the ContextCard.
    @ViewBuilder
    private func scoreBadge(_ score: TrustScorer.Score) -> some View {
        let color = scoreColor(score)
        VStack(alignment: .trailing, spacing: 1) {
            Text("RISK")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(score.value)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text("/100")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(levelLabel(score.level))
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
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
                        .position(x: max(6, min(dotX, geo.size.width - 6)),
                                  y: 3)
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
            Text(concernShortLabel(c))
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
