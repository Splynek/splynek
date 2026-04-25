import SwiftUI

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
                // v1.5.3: ContextCard only on the scan-results path so
                // it doesn't double-up with the centred empty-state
                // hero (which has its own dedicated icon + heading).
                if !scanner.apps.isEmpty {
                    ContextCard(
                        systemImage: "shield.lefthalf.filled",
                        subtitle: "See where your Mac's software comes from, and which apps have European or open-source alternatives. Everything stays local — no account, no telemetry, no app list leaving your device.",
                        tint: .blue
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }

                if scanner.apps.isEmpty && !scanner.isScanning {
                    emptyState
                } else {
                    scanResults
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Sovereignty")
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

    // v1.5.3: PageHeader retired — see ContextCard above (rendered
    // inline in body so the empty-state branch doesn't show it).

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple],
                                   startPoint: .top, endPoint: .bottom)
                )
            Text("Your software supply chain")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Most Mac apps are controlled from outside the European Union. Splynek lists your third-party apps with their country-of-origin, and points to European or open-source alternatives where they exist. Nothing is uploaded, logged, or remembered across launches.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            VStack(alignment: .leading, spacing: 10) {
                privacyRow("Enumeration only — never reads app contents")
                privacyRow("Stays on-device — no network calls, ever")
                privacyRow("Opt-in — you click Scan, nothing runs in the background")
                privacyRow("Open-source scanner in the public repo")
            }
            .frame(maxWidth: 500)
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
    private func privacyRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.blue)
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
                    ForEach(matchedRows, id: \.app.id) { row in
                        resultRow(row)
                    }
                    if matchedRows.isEmpty && !scanner.isScanning {
                        noMatchesFooter
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
        HStack(spacing: 12) {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
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
                // v1.2: target-origin badge — where this app is
                // controlled from.  US / CN / RU / OTHER.
                originBadge(for: row.entry.targetOrigin)
            }
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
                Text(alt.name)
                    .font(.system(.subheadline, weight: .semibold))
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
    @ViewBuilder
    private func actionButton(for alt: SovereigntyCatalog.Alternative) -> some View {
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
            .help("Download \(alt.name) via Splynek")
        } else if isSafeHomepageScheme(alt.homepage) {
            Link(destination: alt.homepage) {
                Label("Visit", systemImage: "arrow.up.right.square")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open \(alt.homepage.host ?? alt.name) in your browser")
        }
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
