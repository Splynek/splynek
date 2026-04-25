import SwiftUI

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
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                if scanner.apps.isEmpty && !scanner.isScanning {
                    emptyState
                } else {
                    scanResults
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Trust")
        .toolbar {
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
    }

    // MARK: - Subviews

    private var header: some View {
        PageHeader(
            systemImage: "checkmark.seal",
            title: "Trust",
            subtitle: "See what public records say about your installed apps — App Store privacy labels, regulatory rulings, confirmed breaches, vendor security advisories. Every claim cites its primary source. Everything stays local."
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.orange, .pink],
                                   startPoint: .top, endPoint: .bottom)
                )
            Text("Public-record audit of your apps")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Splynek cross-references your installed apps against Apple's App Store privacy labels, EU and US regulator decisions, the NVD CVE database, and the HIBP breach corpus. Every concern shown is a fact you can verify yourself — we surface public record, never opinion.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 540)

            VStack(alignment: .leading, spacing: 10) {
                privacyRow("Enumeration only — never reads app contents")
                privacyRow("Stays on-device — no network calls, ever")
                privacyRow("Opt-in — you click Scan, nothing runs in the background")
                privacyRow("Every concern cites a primary source you can open")
            }
            .frame(maxWidth: 540)
            .padding(.top, 8)

            Button {
                scanner.scan()
            } label: {
                Label("Scan my Mac", systemImage: "magnifyingglass")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)
            .disabled(scanner.isScanning)

            if let err = scanner.lastError {
                Text(err)
                    .font(.caption).foregroundStyle(.red)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    @ViewBuilder
    private func privacyRow(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            Text(text).font(.callout).foregroundStyle(.primary)
            Spacer()
        }
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
            let score = TrustScorer.score(entry)
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
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
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
        } else if isSafeHomepageScheme(homepage) {
            Link(destination: homepage) {
                Label("Visit", systemImage: "arrow.up.right.square")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open \(homepage.host ?? name) in your browser")
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

    @ViewBuilder
    private func scoreBadge(_ score: TrustScorer.Score) -> some View {
        let color = scoreColor(score)
        VStack(spacing: 0) {
            Text("\(score.value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(levelLabel(score.level))
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
        }
        .foregroundStyle(color)
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

    private func levelLabel(_ level: TrustScorer.Level) -> LocalizedStringKey {
        switch level {
        case .low:       return "Low"
        case .moderate:  return "Moderate"
        case .high:      return "High"
        case .severe:    return "Severe"
        }
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
