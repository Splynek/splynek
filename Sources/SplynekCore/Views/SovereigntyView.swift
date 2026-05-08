import SwiftUI
import UniformTypeIdentifiers  // v1.7.x: UTType.commaSeparatedText for the CSV save panel

/// v1.2: Sovereignty tab.  Scans the Mac's installed apps (locally
/// — see SovereigntyScanner for the audit trail) and surfaces
/// European or open-source alternatives from the seed catalog.
///
/// The framing is **pro-sovereignty, not anti-any-country**.  An app
/// controlled from the US and an app controlled from China sit in
/// the same bucket from a European user's sovereignty perspective:
/// both place control outside the EU.  The UI shows each target
/// app's country-of-origin so the user can see *where control sits*
/// before deciding what (if anything) to do about it.  European and
/// open-source alternatives are the two buckets we recommend because
/// those are the two that most reduce non-EU dependence.
///
/// All processing is local.  The app list never leaves the Mac.
struct SovereigntyView: View {
    @ObservedObject var vm: SplynekViewModel
    @StateObject private var scanner = SovereigntyScanner()

    /// UI filter — "all" shows every alternative, "EU" filters to
    /// European-origin alts, "OSS" to open-source.  Stored as @State
    /// because the filter has no meaning outside this view's
    /// lifetime.
    @State private var filter: Filter = .all

    /// v1.7.x: last CSV-export error, surfaced inline as an alert.
    /// Local to this view because the Sovereignty scanner doesn't
    /// know or care about export failures (different concern).
    @State private var exportError: String? = nil

    /// v1.3 AI fallback state.  For apps NOT in the curated catalog,
    /// the user can opt-in per-app to ask the local LLM for
    /// alternative suggestions.  State is view-local: nothing is
    /// persisted across launches, nothing is cached between scans.
    @State private var uncatalogedExpanded: Bool = false
    @State private var aiRequests: [String: AIRequestState] = [:]

    /// v1.4 audit: track the in-flight request UUID per app so a
    /// late-arriving response from a superseded request can't
    /// overwrite the state set by a newer request.  Without this,
    /// rapid Ask-AI clicks created a "last finishes wins" race —
    /// the user would see suggestions for click N reverted to those
    /// of click N-1 if N-1's network request happened to land later.
    @State private var aiRequestTokens: [String: UUID] = [:]

    enum AIRequestState: Equatable, Sendable {
        case idle
        case loading
        case ready([AISuggestion])
        case error(String)
    }

    struct AISuggestion: Hashable, Sendable {
        let name: String
        let note: String
        let homepage: URL?
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all, european, oss
        var id: String { rawValue }
        /// Localized label — looks up the string in
        /// SplynekCore's `Localizable.xcstrings` at render time.
        var label: LocalizedStringKey {
            switch self {
            case .all:      return "All alternatives"
            case .european: return "European only"
            case .oss:      return "Open-source only"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 2026-05-08: ContextCard always present, regardless
                // of scan state.  Was previously hidden during the
                // pre-scan splash, which doubled up with the splash's
                // own icon + bullet list.  Now the splash is gone
                // (scan auto-runs on appear) and the ContextCard
                // serves as the canonical "what is this tab" header.
                ContextCard(
                    systemImage: "shield.lefthalf.filled",
                    subtitle: "See where your Mac's software comes from, and which apps have European or open-source alternatives. Everything stays local — no account, no telemetry, no app list leaving your device.",
                    tint: .blue
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
        .navigationTitle("Sovereignty")
        .onAppear {
            // 2026-05-08: auto-scan on first entry instead of asking
            // the user to click "Scan my Mac" on a splash screen.
            // Idempotent — scanner.scan() is a no-op when a scan is
            // already in flight.
            if scanner.apps.isEmpty && !scanner.isScanning {
                scanner.scan()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exportCSV()
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .help("Export your installed-apps × Sovereignty matches as a CSV file")
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
        // v1.6.1: onboarding sheet posts this when the user clicks
        // "Run audit + finish".  We catch it here (regardless of
        // which tab is currently visible — NotificationCenter is
        // global) and trigger the same scan() the toolbar button
        // would.  Idempotent: scanner.scan() is a no-op if a scan
        // is already in flight.
        .onReceive(NotificationCenter.default.publisher(for: .splynekRunSovereigntyScan)) { _ in
            scanner.scan()
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

    // MARK: - Export

    /// v1.7.x: hand the user a save panel for a CSV of their
    /// installed-apps × Sovereignty matches.  Filename suggestion is
    /// stamped with today's date so multiple exports don't overwrite
    /// each other.  The CSV body is generated by `SovereigntyExport.csv`
    /// — see that file for format details (UTF-8, no BOM, RFC 4180).
    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "splynek-sovereignty-\(Self.todayStamp).csv"
        // v1.7.x localization fix #7: the SIX previous Foundation/
        // SwiftUI APIs all returned English in the live .app under
        // pt-PT (see splynek_localization_gotcha.md for the chain).
        // The fix that actually works: read the `.strings` file as a
        // plist directly + look up by exact key match.  Bypasses
        // Foundation's broken default-locale resolution entirely.
        panel.message = Bundle.splynekCore.localizedStringForAppKit(
            "Export your installed-apps × Sovereignty matches as a CSV file"
        )
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let body = SovereigntyExport.csv(installedApps: scanner.apps)
        do {
            try Data(body.utf8).write(to: url, options: .atomic)
        } catch {
            exportError = "Couldn't write CSV: \(error.localizedDescription)"
        }
    }

    /// Today as `YYYY-MM-DD` for filename stamping.  Locale-stable
    /// (uses the C calendar) so the filename sorts predictably across
    /// systems.
    private static var todayStamp: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Subviews

    // v1.5.3: PageHeader retired — see ContextCard above (rendered
    // inline in body so the empty-state branch doesn't show it).

    // 2026-05-08: splash retired in favour of auto-scan + inline
    // status.  The pre-scan icon + bullet hero added zero navigation
    // value once the user has been in the app once — each tab
    // re-entry forced a click before showing real data.  Now we
    // auto-trigger `scanner.scan()` on `.onAppear` and render this
    // small inline strip while the scan is in flight (or surfaces
    // the lastError when it failed).
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
                    ForEach(matchedRows, id: \.app.id) { row in
                        resultRow(row)
                    }
                    if matchedRows.isEmpty && !scanner.isScanning {
                        noMatchesFooter
                    }
                    // 2026-05-08: categorical fallback — apps not in
                    // the hand-curated catalog but whose
                    // LSApplicationCategoryType matches a known
                    // free-software champion category (productivity
                    // → LibreOffice, graphics-design → GIMP, etc.).
                    // Closes the long-tail coverage gap without
                    // hand-curating every bundleID.  Lives in
                    // `SovereigntyCategoryChampions.swift`.
                    if !categoricalRows.isEmpty {
                        categoricalFallbackSection
                            .padding(.top, 8)
                    }
                    // 2026-05-08: "we don't know yet" graceful state.
                    // Apps with no specific entry AND no category
                    // match get listed with a Contribute CTA so the
                    // gap is visible AND actionable.  Hidden behind
                    // a DisclosureGroup so it doesn't overwhelm the
                    // primary list.
                    if !unknownApps.isEmpty {
                        unknownAppsSection
                            .padding(.top, 8)
                    }
                    // v1.4: AI fallback is Pro-only.  The implementation
                    // lives in splynek-pro; the free build's
                    // ProStubs.sovereigntyAlternatives() throws
                    // UnavailableError.  Showing the button without the
                    // Pro gate let free users with Apple Intelligence
                    // click into a guaranteed error.  Both gates required.
                    if vm.aiAvailable && vm.license.isPro {
                        uncatalogedSection
                            .padding(.top, 8)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Categorical fallback (#1 + #8 from the 2026-05-08 strategy)

    /// One row in the categorical-fallback section.  Carries the
    /// installed app + the champions resolved from its
    /// LSApplicationCategoryType.  Distinct from `Row` (which carries
    /// a real `Entry` from the curated catalog) so the UI can clearly
    /// label these as "based on category" rather than "specific match".
    struct CategoricalRow: Identifiable {
        let app: SovereigntyScanner.InstalledApp
        let champions: [SovereigntyCatalog.Alternative]
        var id: String { app.id }
    }

    /// Apps with no specific catalog entry but whose
    /// LSApplicationCategoryType maps to a known champions set.
    /// Filtered through the same origin filter as `matchedRows` so
    /// e.g. "European only" hides champions whose origin doesn't
    /// match.
    private var categoricalRows: [CategoricalRow] {
        scanner.apps.compactMap { app -> CategoricalRow? in
            // Skip apps that already have a specific entry — they're
            // covered by `matchedRows`.
            guard SovereigntyCatalog.alternatives(for: app.id) == nil else {
                return nil
            }
            let raw = SovereigntyCategoryChampions.championsForCategory(app.lsCategory)
            let filtered = raw.filter(matchesFilter)
            guard !filtered.isEmpty else { return nil }
            return CategoricalRow(app: app, champions: filtered)
        }
    }

    /// Apps with no specific entry AND no category fallback.  These
    /// are the genuine gaps the contribute flow is for.
    private var unknownApps: [SovereigntyScanner.InstalledApp] {
        scanner.apps.filter { app in
            guard SovereigntyCatalog.alternatives(for: app.id) == nil else {
                return false
            }
            return SovereigntyCategoryChampions
                .championsForCategory(app.lsCategory).isEmpty
        }
    }

    @ViewBuilder
    private var categoricalFallbackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(.tint)
                Text("Free champions, by category")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(categoricalRows.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text("Suggested matches based on the app's macOS category. We don't have a specific catalog entry for these — these are the free / open-source champions Splynek recommends for the category.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(categoricalRows) { row in
                categoricalRowView(row)
            }
        }
    }

    @ViewBuilder
    private func categoricalRowView(_ row: CategoricalRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "app.dashed")
                    .foregroundStyle(.secondary)
                Text(row.app.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                if let v = row.app.version {
                    Text("v\(v)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let category = row.app.lsCategory?.replacingOccurrences(
                    of: "public.app-category.", with: ""
                ) {
                    Text(category)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        .foregroundStyle(.tint)
                }
            }
            VStack(spacing: 6) {
                ForEach(row.champions.prefix(3)) { alt in
                    alternativeRow(alt)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 0.5)
        )
    }

    @State private var unknownAppsExpanded = false

    @ViewBuilder
    private var unknownAppsSection: some View {
        DisclosureGroup(isExpanded: $unknownAppsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                Text("These apps aren't in our catalog yet AND don't declare a category we cover. The fastest way to get coverage: open a one-click GitHub issue with the app's metadata pre-filled.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(unknownApps.prefix(50)) { app in
                    unknownAppRow(app)
                }
                if unknownApps.count > 50 {
                    Text("…and \(unknownApps.count - 50) more.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.orange)
                Text("Apps we don't know yet")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(unknownApps.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.04))
        )
    }

    @ViewBuilder
    private func unknownAppRow(_ app: SovereigntyScanner.InstalledApp) -> some View {
        HStack(spacing: 8) {
            let nsIcon = NSWorkspace.shared.icon(forFile: app.bundleURL.path)
            Image(nsImage: nsIcon)
                .resizable()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.callout.weight(.medium))
                Text(app.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Link(destination: contributeURL(for: app)) {
                Label("Contribute", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open a GitHub issue with this app's metadata pre-filled. Helps the next Splynek user too.")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    /// Builds a GitHub-issue URL pre-filled with the app's metadata
    /// so a contributor can open + edit + submit in one click.  Falls
    /// back to a generic "/issues/new" when URL encoding fails (very
    /// unusual — only if the bundleID has invalid UTF-8).
    private func contributeURL(for app: SovereigntyScanner.InstalledApp) -> URL {
        let title = "Catalog entry: \(app.id)"
        let body = """
        **App**: \(app.name)
        **Bundle ID**: `\(app.id)`
        **Version**: \(app.version ?? "unknown")
        **Category**: \(app.lsCategory ?? "(not declared)")
        **Homepage**: <add publisher URL>

        Splynek doesn't have a catalog entry for this app yet. Adding to:

        - [ ] Sovereignty (country of origin + free / open-source alternatives)
        - [ ] Trust (privacy + regulatory concerns from public records)
        - [ ] Savings (pricing tier breakdown if paid)

        ### Proposed alternatives

        <list here>

        ---

        Generated by Splynek's "Contribute this app" flow.
        """
        var components = URLComponents(string: "https://github.com/Splynek/splynek/issues/new")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: "catalog,sovereignty"),
        ]
        return components.url ?? URL(string: "https://github.com/Splynek/splynek/issues/new")!
    }

    /// v1.3 uncataloged-apps disclosure.  Apps that aren't in the
    /// handwritten catalog go here.  When collapsed, it's a single
    /// clickable row ("Apps we don't know yet (N) — expand to ask
    /// AI").  When expanded, it lists up to 25 apps; each has an
    /// "Ask AI" button that routes through the local LLM for a
    /// handful of European / open-source suggestions.
    @ViewBuilder
    private var uncatalogedSection: some View {
        let uncataloged = scanner.apps.filter {
            SovereigntyCatalog.alternatives(for: $0.id) == nil
        }
        if !uncataloged.isEmpty {
            DisclosureGroup(isExpanded: $uncatalogedExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(uncataloged.prefix(25))) { app in
                        uncatalogedRow(app)
                    }
                    if uncataloged.count > 25 {
                        Text("…and \(uncataloged.count - 25) more.")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("Apps we don't know yet (\(uncataloged.count))")
                        .font(.system(.subheadline, weight: .semibold))
                    Spacer()
                    Text("Ask AI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.purple.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.18), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func uncatalogedRow(_ app: SovereigntyScanner.InstalledApp) -> some View {
        let state = aiRequests[app.id] ?? .idle
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "app")
                    .foregroundStyle(.secondary)
                Text(app.name)
                    .font(.system(.subheadline, weight: .semibold))
                if let v = app.version {
                    Text("v\(v)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                askAIButton(for: app, currentState: state)
            }
            aiResultView(for: state)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    @ViewBuilder
    private func askAIButton(
        for app: SovereigntyScanner.InstalledApp,
        currentState: AIRequestState
    ) -> some View {
        switch currentState {
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Asking…").font(.caption).foregroundStyle(.secondary)
            }
        case .ready, .error:
            Button {
                requestAIAlternatives(for: app)
            } label: {
                Label("Ask again", systemImage: "arrow.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        case .idle:
            Button {
                requestAIAlternatives(for: app)
            } label: {
                Label("Ask AI", systemImage: "sparkles")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func aiResultView(for state: AIRequestState) -> some View {
        switch state {
        case .idle, .loading:
            EmptyView()
        case .ready(let suggestions):
            if suggestions.isEmpty {
                Text("The local LLM didn't know any good European or open-source alternatives. Contribute one at github.com/Splynek/splynek.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(suggestions, id: \.self) { s in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.purple)
                                .font(.callout)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(s.name)
                                        .font(.system(.subheadline, weight: .semibold))
                                    if let url = s.homepage {
                                        Link(destination: url) {
                                            Image(systemName: "arrow.up.right.square")
                                                .font(.caption)
                                        }
                                    }
                                }
                                if !s.note.isEmpty {
                                    Text(s.note)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 2)
            }
        case .error(let msg):
            Text(msg)
                .font(.caption).foregroundStyle(.red)
        }
    }

    private func requestAIAlternatives(for app: SovereigntyScanner.InstalledApp) {
        // v1.4 audit: token-based dedup.  Each click stamps the request
        // with a fresh UUID; the completion handler only commits its
        // result if the token still matches (i.e. the user hasn't
        // clicked Ask again in the meantime).  Earlier behaviour was
        // last-finishes-wins, which surfaced stale suggestions.
        let token = UUID()
        aiRequestTokens[app.id] = token
        aiRequests[app.id] = .loading
        Task { @MainActor in
            do {
                let raw = try await vm.ai.sovereigntyAlternatives(
                    appName: app.name, bundleID: app.id
                )
                guard aiRequestTokens[app.id] == token else { return }  // superseded
                let mapped = raw.map { s in
                    AISuggestion(name: s.name, note: s.note, homepage: s.homepage)
                }
                aiRequests[app.id] = .ready(mapped)
            } catch {
                guard aiRequestTokens[app.id] == token else { return }  // superseded
                aiRequests[app.id] = .error(
                    "AI request failed: \(error.localizedDescription)"
                )
            }
        }
    }

    private var filterBar: some View {
        // v1.7.x audit fix: pt-PT labels ("Todas as alternativas")
        // are ~25% longer than English ("All alternatives") + the
        // pre-fix HStack(Picker, Spacer, count) was left-anchoring
        // the Picker against the sidebar edge — the leftmost segment
        // clipped (rendering as "…as as alternativas" instead of
        // "Todas as alternativas") because the localised label
        // exceeded the 320pt frame budget.  ZStack-with-overlay
        // makes the Picker dead-center of the pane width regardless
        // of locale-driven label length, with the count overlaid on
        // the trailing edge so it doesn't shift the Picker's center.
        ZStack {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 480)

            HStack {
                Spacer()
                if scanner.isScanning {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    // v1.4: simplified "X / Y apps" phrasing — avoids
                    // per-language plural headaches in the localisations.
                    Text("\(matchedRows.count) / \(scanner.apps.count) apps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Row rendering

    /// Bundle of "an installed app + what the catalog says about it."
    /// Pre-computed in `matchedRows` so the ForEach stays simple.
    struct Row {
        let app: SovereigntyScanner.InstalledApp
        let entry: SovereigntyCatalog.Entry
        let visibleAlternatives: [SovereigntyCatalog.Alternative]
    }

    private var matchedRows: [Row] {
        scanner.apps.compactMap { app -> Row? in
            guard let entry = SovereigntyCatalog.alternatives(for: app.id) else { return nil }
            let filtered = entry.alternatives.filter(matchesFilter)
            guard !filtered.isEmpty else { return nil }
            return Row(app: app, entry: entry, visibleAlternatives: filtered)
        }
    }

    private func matchesFilter(_ alt: SovereigntyCatalog.Alternative) -> Bool {
        switch filter {
        case .all:      return true
        case .european: return alt.origin == .europe || alt.origin == .europeAndOSS
        case .oss:      return alt.origin == .oss || alt.origin == .europeAndOSS
        }
    }

    @ViewBuilder
    private func resultRow(_ row: Row) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // v1.5.6+: combine the row header into one VoiceOver
            // utterance.  Previously read as four fragments.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
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
                // v1.2: target-origin badge — where this app is
                // controlled from.  US / CN / RU / OTHER.
                originBadge(for: row.entry.targetOrigin)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(rowHeaderAccessibilityLabel(row))
            VStack(spacing: 8) {
                ForEach(row.visibleAlternatives) { alt in
                    alternativeRow(alt)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func alternativeRow(_ alt: SovereigntyCatalog.Alternative) -> some View {
        HStack(alignment: .top, spacing: 10) {
            originBadge(for: alt.origin)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(alt.name)
                        .font(.system(.subheadline, weight: .semibold))
                    deliveryKindBadge(for: alt)
                }
                Text(alt.note)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            actionButton(for: alt)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    /// v1.2: either "Install" (direct-download URL known — hand to
    /// Splynek's download engine) or "Visit" (homepage only — open
    /// in the default browser).  Install is the better flow when
    /// available; it keeps users inside Splynek and leverages the
    /// multi-interface aggregation / SHA-256 verification pipeline.
    ///
    /// v1.4 hardening: only HTTP(S) downloadURLs trigger the Install
    /// path.  Catalog data is human-curated, but a malicious upstream
    /// JSON source could submit `file:///` or `data:` schemes via the
    /// discovery pipeline — we defence-in-depth here so the URL never
    /// reaches the download engine even if validation upstream fails.
    /// 2026-05-07 (Phase 1 UX): one-line badge that names what kind
    /// of distribution channel the alt ships through.  Hover-tooltip
    /// gives the longer explainer.  Replaces the silent "downloadURL
    /// or not" fallback that confused users into expecting a DMG and
    /// getting a SaaS sign-up wall.
    @ViewBuilder
    private func deliveryKindBadge(for alt: SovereigntyCatalog.Alternative) -> some View {
        let kind = alt.effectiveDeliveryKind
        Label(kind.displayLabel, systemImage: kind.symbol)
            .font(.system(.caption2, weight: .medium))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.06))
            )
            .foregroundStyle(.secondary)
            .help(kind.tooltip)
            .accessibilityLabel("Distribution: \(kind.displayLabel)")
    }

    /// Per-DeliveryKind call-to-action.  Each kind gets a button
    /// shape + label + behavior tuned to what the user will actually
    /// encounter on the other side — no more "Install" buttons that
    /// silently land on a SaaS sign-up wall.
    @ViewBuilder
    private func actionButton(for alt: SovereigntyCatalog.Alternative) -> some View {
        let kind = alt.effectiveDeliveryKind
        switch kind {
        case .directDownload, .versionEmbedded:
            // Real binary URL OR a publisher URL we believe is
            // currently working (auto-prune watches it).  Same UI.
            if let dl = alt.downloadURL, isSafeDownloadScheme(dl) {
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
                .help("Download \(alt.name) directly via Splynek (multi-interface, verified).")
                .accessibilityLabel("Install \(alt.name) via Splynek")
            } else if isSafeHomepageScheme(alt.homepage) {
                getInstallerButton(for: alt)
            }
        case .macAppStore:
            // Map http(s) homepage to a `macappstore://` deep-link
            // when possible.  If the homepage is a plain web page,
            // fall through to "Open" — the user lands on the
            // publisher's "Get on Mac App Store" landing.
            Link(destination: macAppStoreURL(for: alt) ?? alt.homepage) {
                Label("Open in App Store", systemImage: "apple.logo")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .help("Open \(alt.name) in the Mac App Store.")
            .accessibilityLabel("Open \(alt.name) in App Store")
        case .webService:
            // No native app exists — open in browser, no install pretense.
            if isSafeHomepageScheme(alt.homepage) {
                Link(destination: alt.homepage) {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .labelStyle(.titleAndIcon)
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open \(alt.name) in your browser. No native Mac app — runs in the browser.")
                .accessibilityLabel("Open \(alt.name) in browser")
            }
        case .homebrew:
            // Copy the brew install command to the clipboard.
            Button {
                copyToClipboard("brew install \(homebrewFormulaName(for: alt))")
            } label: {
                Label("Copy brew", systemImage: "terminal")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Copy `brew install \(homebrewFormulaName(for: alt))` to the clipboard, then paste into Terminal.")
            .accessibilityLabel("Copy Homebrew install command for \(alt.name)")
        case .signupRequired, .purchaseRequired:
            // Mac binary exists but the publisher gates the download
            // behind an account or payment.  Honest CTA: "Visit"
            // (no install pretense) + the badge already says why.
            if isSafeHomepageScheme(alt.homepage) {
                Link(destination: alt.homepage) {
                    Label("Visit", systemImage: "arrow.up.right.square")
                        .labelStyle(.titleAndIcon)
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(kind == .signupRequired
                      ? "\(alt.name) requires a free account on the publisher's site to download."
                      : "\(alt.name) is paid — purchase on the publisher's site to download.")
                .accessibilityLabel("Visit \(alt.name) (\(kind.displayLabel.lowercased()))")
            }
        case .comingSoon:
            // Placeholder — desktop announced but not shipped.
            if isSafeHomepageScheme(alt.homepage) {
                Link(destination: alt.homepage) {
                    Label("Visit project", systemImage: "hammer")
                        .labelStyle(.titleAndIcon)
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("\(alt.name)'s desktop app is announced but not yet shipped. Splynek tracks the project page.")
                .accessibilityLabel("Visit \(alt.name) project page")
            }
        }
    }

    @ViewBuilder
    private func getInstallerButton(for alt: SovereigntyCatalog.Alternative) -> some View {
        Link(destination: alt.homepage) {
            Label("Get installer", systemImage: "arrow.up.right.square")
                .labelStyle(.titleAndIcon)
                .font(.callout)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help("Splynek doesn't have a direct download URL for \(alt.name) yet — opens \(alt.homepage.host ?? alt.name) where you can grab the installer.")
        .accessibilityLabel("Open \(alt.name) download page in browser")
    }

    /// Best-effort macappstore:// deep-link.  When the alt's homepage
    /// itself points at apps.apple.com, we can rewrite directly.
    /// Otherwise we hand back nil and the caller falls through to
    /// the homepage.
    private func macAppStoreURL(for alt: SovereigntyCatalog.Alternative) -> URL? {
        guard let host = alt.homepage.host?.lowercased(),
              host == "apps.apple.com"
        else { return nil }
        // apps.apple.com URLs accept macappstore:// when the path
        // matches the App Store schema.  Apple supports this on macOS.
        var s = alt.homepage.absoluteString
        s = s.replacingOccurrences(of: "https://apps.apple.com",
                                   with: "macappstore://apps.apple.com")
        return URL(string: s)
    }

    /// Heuristic: derive the brew formula name from the alt's name.
    /// Lowercased + non-alphanumerics replaced with hyphens.  Good
    /// enough for the well-known formulas in our Homebrew bucket
    /// (hcloud, scaleway, ovhcloud, opentofu, kubectl, etc.).
    private func homebrewFormulaName(for alt: SovereigntyCatalog.Alternative) -> String {
        let lower = alt.name.lowercased()
        var slug = ""
        for c in lower {
            if c.isLetter || c.isNumber { slug.append(c) }
            else if !slug.isEmpty && slug.last != "-" { slug.append("-") }
        }
        return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func copyToClipboard(_ s: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
        #endif
    }

    /// Allow only `https://` for downloads — the engine doesn't gain
    /// anything from `http://` (no integrity), and `file://` / `data:`
    /// would let a poisoned catalog leak local files or trigger
    /// arbitrary handlers.  Match `ViewModel.start()`'s own scheme
    /// gate — both layers enforce, neither relies on the other.
    private func isSafeDownloadScheme(_ url: URL) -> Bool {
        (url.scheme ?? "").lowercased() == "https"
    }

    /// Allow `https://` (and `http://` for the rare upstream that
    /// hasn't migrated) for homepages opened in the user's browser.
    /// Reject `file://`, `data:`, `javascript:`, custom schemes —
    /// `Link` would happily hand any of those to LaunchServices.
    private func isSafeHomepageScheme(_ url: URL) -> Bool {
        let s = (url.scheme ?? "").lowercased()
        return s == "https" || s == "http"
    }

    /// v1.5.6+: combined-utterance row header for VoiceOver.  Reads
    /// as one sentence, e.g. "TikTok version 28.4.0, controlled from
    /// China, 5 alternatives".  Matches the visual hierarchy a sighted
    /// user gets without four separate stops.
    private func rowHeaderAccessibilityLabel(_ row: Row) -> String {
        var parts: [String] = []
        parts.append(row.app.name)
        if let v = row.app.version { parts.append("version \(v)") }
        parts.append("controlled from \(row.entry.targetOrigin.accessibilityLabel)")
        let n = row.visibleAlternatives.count
        parts.append(n == 1 ? "1 alternative" : "\(n) alternatives")
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func originBadge(for origin: SovereigntyCatalog.Origin) -> some View {
        // Colours are intentionally neutral for non-European origins
        // — grey for US / CN / RU / OTHER.  The tab isn't about
        // shaming any country; it's about showing where control
        // sits.  Green / blue / purple are reserved for the positive
        // picks (EU / OSS / both) so they visually lead.
        let (bg, fg): (Color, Color) = {
            switch origin {
            case .europe:        return (.blue.opacity(0.18),   .blue)
            case .oss:           return (.green.opacity(0.18),  .green)
            case .europeAndOSS:  return (.purple.opacity(0.18), .purple)
            case .unitedStates, .china, .russia, .other:
                return (.secondary.opacity(0.18), .secondary)
            }
        }()
        Text(origin.label)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.3)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
            // v1.4 audit: VoiceOver pronounces "EU" / "OSS" as letter
            // soup without a label.  Replace the visual abbreviation
            // with a spoken-language description so the badge conveys
            // the same meaning to screen-reader users that it does to
            // sighted users.
            .accessibilityLabel(origin.accessibilityLabel)
    }

    @ViewBuilder
    private var noMatchesFooter: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("No matches with the current filter")
                .font(.system(.headline, design: .rounded))
            Text("Either your installed apps don't have catalog entries yet, or the filter is hiding them. The catalog is intentionally small at launch — community PRs expand it at [github.com/Splynek/splynek](https://github.com/Splynek/splynek).")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
