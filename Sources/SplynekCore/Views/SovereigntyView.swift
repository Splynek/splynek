import SwiftUI

/// v1.2: Sovereignty tab.  Scans the Mac's installed apps (locally,
/// via Spotlight — see SovereigntyScanner for the audit trail) and
/// surfaces EU / open-source alternatives matched from the seed
/// catalog.  Tone is "here's a door out if you want one," not
/// "here's what you should feel bad about having."
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

    enum Filter: String, CaseIterable, Identifiable {
        case all, eu, oss
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .eu:  return "EU only"
            case .oss: return "Open-source only"
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

    private var header: some View {
        PageHeader(
            systemImage: "shield.lefthalf.filled",
            title: "Sovereignty",
            subtitle: "Scan your Mac to see which apps have EU or open-source alternatives. Everything stays local — no account, no telemetry, no app list leaving your device."
        )
    }

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
            Text("Understand your software stack")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Splynek uses Spotlight's existing index to list your third-party apps, then matches them against a handwritten catalog of EU and open-source alternatives. Nothing is uploaded, logged, or remembered across launches.")
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
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            if scanner.isScanning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Scanning…").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("\(matchedRows.count) match\(matchedRows.count == 1 ? "" : "es") out of \(scanner.apps.count) apps")
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
        case .all: return true
        case .eu:  return alt.origin == .eu || alt.origin == .both
        case .oss: return alt.origin == .oss || alt.origin == .both
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
            Link(destination: alt.homepage) {
                Label("Visit", systemImage: "arrow.up.right.square")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    @ViewBuilder
    private func originBadge(for origin: SovereigntyCatalog.Alternative.Origin) -> some View {
        let (bg, fg): (Color, Color) = {
            switch origin {
            case .eu:   return (.blue.opacity(0.18), .blue)
            case .oss:  return (.green.opacity(0.18), .green)
            case .both: return (.purple.opacity(0.18), .purple)
            }
        }()
        Text(origin.label)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.3)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
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
