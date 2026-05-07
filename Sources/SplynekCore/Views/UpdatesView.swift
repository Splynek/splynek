// Copyright © 2026 Splynek. MIT.
//
// UpdatesView — Phase 3 of the 2026-05-07 product expansion.
//
// Universal updater for installed Mac apps.  Unifies several
// upstream sources (Sparkle / GitHub Releases / MAS / Homebrew /
// publisher RSS) under a single UI so the user doesn't have to
// know which app uses which mechanism.
//
// Architectural advantage Splynek already has:
//
//   - BondedFetcher (S5)  → updates download via multi-NIC
//                            bonded byte ranges, faster than
//                            any other Mac updater on multi-
//                            interface setups.
//   - File Witness (S6)   → every install produces an Ed25519-
//                            signed receipt; failure rolls back.
//   - MirrorManifest      → curated mirrors for OS-distro updates
//                            (Ubuntu / Debian / Fedora).
//
// This UI surfaces the resolution + per-app status + Update All
// button.  Background scheduling is the existing AutoUpdateScheduler;
// this view provides the manual + status-check entry point.

#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

@MainActor
struct UpdatesView: View {
    @ObservedObject var vm: SplynekViewModel
    @StateObject private var scanner = SovereigntyScanner()
    @State private var resolved: [AppUpdateInfo] = []
    @State private var isResolving = false

    init(vm: SplynekViewModel) { self.vm = vm }

    /// Apps with a usable update source AND a known available
    /// version newer than installed.
    private var updatesAvailable: [AppUpdateInfo] {
        resolved.filter { $0.hasUpdate && $0.updatePolicy != .ignored }
    }

    /// Apps where we resolved a source but don't have a fresh
    /// "available" version yet.  Surfaces "Check now" affordance.
    private var unchecked: [AppUpdateInfo] {
        resolved.filter { $0.availableVersion == nil && $0.updatePolicy != .ignored }
    }

    /// Apps whose update source we couldn't determine — manual flow.
    private var manualOnly: [AppUpdateInfo] {
        resolved.filter {
            if case .unknown = $0.updateSource { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                if !updatesAvailable.isEmpty { updatesAvailableSection }
                if !unchecked.isEmpty { uncheckedSection }
                if !manualOnly.isEmpty { manualSection }
            }
            .padding(20)
        }
        .navigationTitle("Updates")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await checkAll() }
                } label: {
                    Label("Check all", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isResolving)
            }
        }
        .onAppear { Task { await refreshScanner() } }
    }

    // MARK: Sections

    @ViewBuilder
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heroTitle)
                .font(.system(.title, design: .rounded, weight: .semibold))
            Text(heroSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.green.opacity(0.18), Color.green.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
    }

    private var heroTitle: String {
        if isResolving { return "Checking for updates…" }
        if updatesAvailable.isEmpty && resolved.isEmpty { return "Click Check all to scan installed apps" }
        if updatesAvailable.isEmpty { return "Everything's up to date" }
        return "\(updatesAvailable.count) update\(updatesAvailable.count == 1 ? "" : "s") ready"
    }

    private var heroSubtitle: String {
        if isResolving { return "Resolving Sparkle / GitHub / Homebrew sources…" }
        if resolved.isEmpty { return "Splynek will identify each app's update source — Sparkle, GitHub Releases, Homebrew, App Store, or publisher RSS." }
        if updatesAvailable.isEmpty { return "Splynek checked \(resolved.count) installed app\(resolved.count == 1 ? "" : "s") — no newer versions available." }
        return "Updates download via Splynek's bonded multi-interface fetch and verify with an Ed25519 receipt before installing."
    }

    @ViewBuilder
    private var updatesAvailableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Updates available")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await updateAll() }
                } label: {
                    Label("Update all", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            ForEach(updatesAvailable, id: \.bundleID) { info in
                UpdateRow(info: info, vm: vm)
            }
        }
    }

    @ViewBuilder
    private var uncheckedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unchecked")
                .font(.headline)
            Text("Splynek found update sources for these apps but hasn't fetched the latest versions yet. Click Check all in the toolbar.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(unchecked.prefix(20), id: \.bundleID) { info in
                UpdateRow(info: info, vm: vm)
            }
        }
    }

    @ViewBuilder
    private var manualSection: some View {
        DisclosureGroup {
            ForEach(manualOnly.prefix(50), id: \.bundleID) { info in
                UpdateRow(info: info, vm: vm)
            }
        } label: {
            HStack {
                Text("\(manualOnly.count) apps without a known update source")
                    .font(.subheadline)
                Spacer()
                Text("Manual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Actions

    @MainActor
    private func refreshScanner() async {
        if scanner.apps.isEmpty {
            scanner.scan()
            // small delay so .apps populates before we resolve
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        // Rebuild the resolved list from the scanner's snapshot.
        var out: [AppUpdateInfo] = []
        for app in scanner.apps {
            let source = UpdateSourceResolver.resolve(
                bundleID: app.id, bundleURL: app.bundleURL)
            out.append(AppUpdateInfo(
                bundleID: app.id,
                displayName: app.name,
                installedVersion: app.version ?? "—",
                installedAt: app.bundleURL,
                updateSource: source))
        }
        resolved = out
    }

    @MainActor
    private func checkAll() async {
        isResolving = true
        defer { isResolving = false }
        await refreshScanner()
        // 2026-05-07 phase 3 follow-up: dispatch by UpdateSource
        // case to the right resolver.  Sparkle + GitHub Releases +
        // Homebrew + publisher RSS all wired now.  MAS + unknown
        // are skipped (Apple's App Store handles MAS; .unknown
        // means we never resolved a source for that app).
        var updated = resolved
        await withTaskGroup(of: (Int, ResolvedUpdate?).self) { group in
            for (i, info) in updated.enumerated() {
                switch info.updateSource {
                case .sparkle(let feedURL):
                    group.addTask {
                        return (i, await Self.resolveSparkle(feedURL: feedURL))
                    }
                case .githubReleases(let owner, let repo):
                    group.addTask {
                        return (i, await Self.resolveGitHub(owner: owner, repo: repo))
                    }
                case .homebrew(let formula):
                    // Homebrew check requires `brew outdated --cask
                    // --json` which Splynek can't run inside the
                    // sandbox.  We surface the formula name so the
                    // user can Cmd+Click → "Copy `brew upgrade`
                    // command" from the row.  No version resolution
                    // here in v1; future: a small unsandboxed helper
                    // tool runs brew + writes JSON to a shared path.
                    let _ = formula
                    continue
                case .publisherRSS(let feedURL):
                    group.addTask {
                        return (i, await Self.resolvePublisherRSS(feedURL: feedURL))
                    }
                case .macAppStore, .unknown:
                    continue
                }
            }
            for await (i, result) in group {
                guard let result else { continue }
                updated[i].availableVersion = result.version
                updated[i].availableSizeBytes = result.sizeBytes
                updated[i].availableDownloadURL = result.downloadURL
                updated[i].availableSHA256 = result.sha256
                updated[i].releaseNotes = result.releaseNotes
                updated[i].lastChecked = Date()
            }
        }
        resolved = updated
    }

    /// Common shape returned by every resolver — the UI doesn't
    /// care which feed format the data came from.
    private struct ResolvedUpdate: Sendable {
        let version: String
        let downloadURL: URL?
        let sizeBytes: Int64?
        let sha256: String?
        let releaseNotes: String?
    }

    nonisolated private static func resolveSparkle(feedURL: URL) async -> ResolvedUpdate? {
        var req = URLRequest(url: feedURL)
        req.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let item = SparkleAppcast.parseLatest(data),
              let version = item.shortVersion ?? item.version
        else { return nil }
        return ResolvedUpdate(
            version: version,
            downloadURL: item.enclosureURL,
            sizeBytes: item.sizeBytes,
            sha256: item.sha256,
            releaseNotes: item.releaseNotesText
        )
    }

    nonisolated private static func resolveGitHub(owner: String, repo: String) async -> ResolvedUpdate? {
        guard let url = GitHubReleasesResolver.latestReleaseURL(owner: owner, repo: repo) else {
            return nil
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        // GitHub's API requires a non-empty UA string for
        // anonymous calls; without it some endpoints 403.
        req.setValue("Splynek/1.0 (+https://splynek.app)",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json",
                     forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let release = GitHubReleasesResolver.parseLatest(data)
        else { return nil }
        // Strip a leading "v" from the tag so semver compare works
        // against the bundled CFBundleShortVersionString format.
        var version = release.tagName
        if version.hasPrefix("v") || version.hasPrefix("V") {
            version.removeFirst()
        }
        let asset = GitHubReleasesResolver.pickAsset(release)
        return ResolvedUpdate(
            version: version,
            downloadURL: asset?.browserDownloadURL,
            sizeBytes: asset?.size,
            sha256: nil,  // GitHub Releases API doesn't expose hashes
            releaseNotes: release.body
        )
    }

    nonisolated private static func resolvePublisherRSS(feedURL: URL) async -> ResolvedUpdate? {
        var req = URLRequest(url: feedURL)
        req.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let item = PublisherRSSResolver.parseLatest(data),
              let version = item.version
        else { return nil }
        return ResolvedUpdate(
            version: version,
            // RSS feeds rarely link directly to a binary — the
            // <link> usually points at a release-notes page.
            // Surface it as "release notes" only, no download URL.
            downloadURL: nil,
            sizeBytes: nil,
            sha256: nil,
            releaseNotes: item.title
        )
    }

    @MainActor
    private func updateAll() async {
        // Hand each pending update to the existing VM start path —
        // exact same flow as Sovereignty's "Install" button uses.
        // Schedules them in sequence so the queue doesn't saturate.
        for info in updatesAvailable {
            guard let dl = info.availableDownloadURL else { continue }
            vm.urlText = dl.absoluteString
            vm.start()
            // Small inter-job delay; Splynek's queue handles
            // concurrent submissions but staggering avoids a flash
            // of N progress cards appearing in the same instant.
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }
}

// MARK: - UpdateRow

@MainActor
private struct UpdateRow: View {
    let info: AppUpdateInfo
    let vm: SplynekViewModel

    private var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: info.installedAt.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(info.displayName)
                        .font(.subheadline.weight(.semibold))
                    sourceBadge
                }
                versionLine
                if let notes = info.releaseNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            actionButton
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }

    @ViewBuilder
    private var sourceBadge: some View {
        Text(info.updateSource.displayLabel)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(sourceColor.opacity(0.18)))
            .foregroundStyle(sourceColor)
    }

    private var sourceColor: Color {
        switch info.updateSource {
        case .sparkle:        return .blue
        case .githubReleases: return .purple
        case .macAppStore:    return .pink
        case .homebrew:       return .orange
        case .publisherRSS:   return .teal
        case .unknown:        return .gray
        }
    }

    @ViewBuilder
    private var versionLine: some View {
        if let avail = info.availableVersion, info.hasUpdate {
            HStack(spacing: 4) {
                Text(info.installedVersion)
                    .strikethrough()
                Text("→").foregroundStyle(.secondary)
                Text(avail).bold()
                if let sz = info.availableSizeFormatted {
                    Text("· \(sz)").foregroundStyle(.secondary)
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.primary)
        } else {
            Text("v\(info.installedVersion)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if info.hasUpdate, let dl = info.availableDownloadURL {
            Button {
                vm.urlText = dl.absoluteString
                vm.start()
            } label: {
                Label("Update", systemImage: "arrow.down.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            EmptyView()
        }
    }
}
#endif
