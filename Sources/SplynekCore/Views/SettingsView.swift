import SwiftUI
import AppKit

/// Everything a user might want to *configure* that doesn't have a
/// natural feature-tab home.  As of 2026-05-09 most cards have been
/// decentralized — Trust weights live in Confiança, Schedule + Watched
/// folder in Fila, Swarm token + Security in Frota, Web dashboard +
/// QR pair in Agentes.  What remains here is genuinely cross-cutting:
///
///   • Pro license (gates several feature tabs at once)
///   • Browser helpers (Chrome extension, Safari bookmarklets)
///   • Local AI (Ollama detection + model — used by Concierge + History)
///   • Background mode (dock icon, login item — app-wide behaviour)
///
/// All cards are identical in visual weight; the user scans down a
/// single column to configure the app.
struct SettingsView: View {
    @ObservedObject var vm: SplynekViewModel
    @EnvironmentObject var background: BackgroundModeController

    /// Sprint 4 PRO-PLUS-IPHONE (2026-05-10): hide-the-Trust+-upsell
    /// session-local toggle.  Persisting this requires another
    /// preference key + read/write site; the v1 scope hides for
    /// the current session only.  If the user wants permanent
    /// dismissal they ignore the card; the next session renders it
    /// again only if engagement still exceeds the gate.
    @State private var upsellHidden: Bool = false

    /// Sprint 4 PRO-PLUS-IPHONE (2026-05-10): API tokens UI state.
    /// Keeps the mint form responsive without round-tripping the
    /// store on every keystroke.
    @State fileprivate var apiTokenDraftLabel: String = ""
    @State fileprivate var apiTokenDraftScope: APITokenScope = .readWrite
    @State fileprivate var apiTokenLastError: String?
    @State fileprivate var revealAPIToken: String?  // token id whose secret is visible
    /// Bumped on every mutate to force the card body to re-read
    /// the store.  SwiftUI's view-identity tracking would otherwise
    /// hold the old `store.tokens` snapshot across mutations
    /// because `vm.fleet.apiTokenStoreFile.read()` isn't published.
    @State fileprivate var apiTokenStoreVersion: Int = 0

    init(vm: SplynekViewModel) { self.vm = vm }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ContextCard(
                    systemImage: "gearshape",
                    subtitle: "Cross-cutting preferences — license, browser integrations, local AI, and background behaviour. Feature-specific knobs live next to the features they affect. Nothing here phones home.",
                    tint: .gray
                )
                proCard
                browserHelpersCard
                aiCard
                backgroundModeCard
                // Sprint 4 PRO-PLUS-IPHONE (2026-05-10): pure-local
                // engagement viewer + Trust+ upsell.  Both Pro-only;
                // both consume the EngagementCounters foundation
                // shipped in `ec1e9d9`.  Privacy through transparency
                // — the user reads the same JSON the future Trust+
                // gate reads.
                engagementViewerCard
                trustPlusUpsellCard
                // Sprint 4 PRO-PLUS-IPHONE (2026-05-10): API
                // tokens.  Pro feature for Raycast / Alfred /
                // shell scripts that need a stable secret across
                // sessions.  Free users see a Pro-locked teaser.
                apiTokensCard
                // 2026-05-09 settings decentralization (commits 57fb6cb,
                // b494a2b, f944b09, 52e9249):
                //   • Trust weights        → TrustView.weightsDisclosure
                //   • Schedule + Watched   → QueueView (scheduleCard,
                //                            watchedFolderCard)
                //   • Swarm token + Sec.   → FleetView (householdTokenCard,
                //                            securityCard)
                //   • Web dashboard + QR   → AgentsView.mobileDashboardCard
                // Discovery wins — the user finds each control next
                // to the surface it governs.
            }
            .padding(20)
            .frame(maxWidth: 780)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Settings")
    }

    // MARK: Pro unlock (v0.41; reworked for StoreKit v0.44)
    // No UI state here anymore — StoreKit drives the purchase sheet
    // in MAS; the DMG build just links out to the App Store page.

    private var proCard: some View {
        TitledCard(
            title: "Splynek Pro",
            systemImage: "sparkles",
            accessory: AnyView(StatusPill(
                text: vm.license.isPro ? "ACTIVE" : "FREE",
                style: vm.license.isPro ? .success : .neutral
            ))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if vm.license.isPro {
                    proActiveContent
                } else {
                    proFreeContent
                }
            }
        }
    }

    @ViewBuilder private var proActiveContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Licensed to \(vm.license.licensedEmail ?? "you")")
                    .font(.callout)
                Text("Thanks for supporting Splynek. AI Concierge, AI history search, scheduled downloads, and LAN-accessible dashboard are unlocked.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(role: .destructive) { vm.license.deactivate() } label: {
                Text("Deactivate on this Mac")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder private var proFreeContent: some View {
        Text("Unlock the AI Concierge, AI-powered history search, scheduled downloads, and phone-accessible LAN dashboard. One-time $29; lifetime 0.x updates.")
            .font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

#if MAS_BUILD
        // MAS build — StoreKit IAP replaces the email+key form. The
        // actual $29 sheet is driven by Apple; we just wire the Buy
        // + Restore buttons to the LicenseManager's StoreKit methods.
        HStack(spacing: 10) {
            Button {
                Task { await vm.license.purchase() }
            } label: {
                Label("Buy Splynek Pro — $29", systemImage: "cart.fill")
            }
            .buttonStyle(.borderedProminent)
            Button {
                Task { await vm.license.restore() }
            } label: {
                Label("Restore Purchase", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        if let err = vm.license.lastUnlockError {
            Text(err).font(.caption).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
#else
        // DMG build — no purchase flow in the free tier. Point users
        // at the Mac App Store for the paid upgrade.
        HStack(spacing: 10) {
            if let url = URL(string: "https://splynek.app/pro") {
                Link(destination: url) {
                    Label("Get Splynek Pro on the Mac App Store", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        Text("Splynek Pro is available only in the Mac App Store build. The free DMG build has the full download engine — torrents, multi-interface HTTP, everything non-AI.")
            .font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
#endif
    }

    // MARK: Browser helpers

    private var browserHelpersCard: some View {
        TitledCard(title: "Browser helpers", systemImage: "safari.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Send links + current pages to Splynek with one click.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button {
                        revealChromeExtension()
                    } label: {
                        Label("Install Chrome extension…", systemImage: "puzzlepiece.extension.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        openSafariBookmarklets()
                    } label: {
                        Label("Safari bookmarklets…", systemImage: "bookmark.fill")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            }
        }
    }

    // 2026-05-09: webDashboardCard + iPhonePairingRow moved to
    // AgentsView.  Both surfaces are external-client interfaces
    // gated by the same listener + token; the Agentes tab now
    // tells the entire "how does an outside thing reach this
    // Mac" story.  See AgentsView.mobileDashboardCard.

    // MARK: Household swarm token (v1.9.7)

    // 2026-05-09: swarmHouseholdCard moved to FleetView.  The
    // household token gates which Macs can talk to each other
    // over the LAN; surfacing it next to the swarm peers it
    // governs is the right home.  See FleetView.householdTokenCard.

    // MARK: Local AI

    private var aiCard: some View {
        TitledCard(
            title: "Local AI assistant",
            systemImage: "sparkles.rectangle.stack.fill",
            accessory: AnyView(
                Button {
                    Task { await vm.refreshAIStatus() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.splynekHover)
                .help("Re-probe localhost:11434 for Ollama")
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // v1.6.2 round 7: switched from \u{201C}/\u{201D} escapes to
                // real curly-quote glyphs so the audit script's regex matches
                // the string literal against the catalog key. Renders identically.
                Text("Paste English like “the latest Ubuntu ISO” and the local LLM returns a direct URL. Natural-language history search too. Runs entirely on this Mac.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if vm.aiAvailable, let model = vm.aiModel {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Detected Ollama —")
                            .font(.callout).foregroundStyle(.secondary)
                        Text(model)
                            .font(.system(.callout, design: .monospaced, weight: .medium))
                        Spacer()
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        // 2026-05-05 audit: aiUnavailableReason is String;
                        // Text(String) doesn't localize.  Wrap so the
                        // pt-PT/de/es/fr/it translations in the catalog
                        // are honoured (e.g. "Splynek Pro (Mac App Store) —
                        // AI features aren't in the free build.").
                        Text(LocalizedStringKey(vm.aiUnavailableReason ?? "Ollama not detected."))
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button {
                            if let u = URL(string: "https://ollama.com/download") {
                                NSWorkspace.shared.open(u)
                            }
                        } label: {
                            Label("Install Ollama", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // 2026-05-09: scheduleCard + scheduleCardUnlocked + hourWindowControls
    // + weekdayPicker + currentStateRow + watchedFolderCard + pickWatchFolder
    // + the private static `relative` wrapper all moved to QueueView.swift
    // (extension at the bottom of that file).  Reason: configuration of
    // queue behaviour belongs on the queue tab, not buried in Settings.


    // MARK: Background mode

    private var backgroundModeCard: some View {
        TitledCard(title: "Background mode", systemImage: "menubar.arrow.up.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Hide the dock icon and/or launch Splynek when you log in.")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle(isOn: $background.menuBarOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Menu-bar only (hide dock icon)")
                        Text("Click the menu bar icon or press ⌘⇧D to surface the main window.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                Divider().opacity(0.3)

                HStack(alignment: .top) {
                    Toggle(isOn: Binding(
                        get: { background.loginItemStatus == .enabled },
                        set: { background.setLoginItemEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at login")
                            loginStatusLine
                        }
                    }
                    .toggleStyle(.switch)
                    Spacer()
                    Button {
                        background.refreshLoginItemStatus()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.splynekHover)
                    .help("Refresh login-item status from macOS")
                }
            }
        }
    }

    @ViewBuilder private var loginStatusLine: some View {
        switch background.loginItemStatus {
        case .enabled:
            Text("Registered. macOS will start Splynek at next login.")
                .font(.caption).foregroundStyle(.green)
        case .disabled:
            Text("Not registered.")
                .font(.caption).foregroundStyle(.secondary)
        case .requiresApproval:
            Text("Approval required — open System Settings → Login Items.")
                .font(.caption).foregroundStyle(.orange)
        case .unavailable(let why):
            Text("Unavailable: \(why)")
                .font(.caption).foregroundStyle(.red)
        case .unknown:
            Text("Status unknown.").font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Trust score weights (v1.5.4)

    /// Per-axis weights for the Trust score in the Trust tab.  The
    /// score is `Σ (severity points × axis weight)` clamped to 0…100.
    /// Default weights err on the side of security > privacy > trust
    /// > business model — see `TrustScorer.Weights`'s doc comment for
    /// the rationale.  Sliders go (0, 3]; the underlying clamp in
    /// `TrustScorer.Weights.sanitised` enforces this regardless of
    /// what the slider sends.
    // v1.6.1: MCP card moved out of Settings into its own `Agents` tab
    // (Sources/SplynekCore/Views/AgentsView.swift).  See `mcpEndpointString`
    // there.  The user said "I have no idea what 'optional SHA-256 for
    // integrity' is" — same critique applies to a programmable platform
    // buried as a 9th card in Settings.  Agents tab gives MCP the room
    // it needs (tool gallery, quick-test playground, per-client setup
    // snippets, privacy story) instead of compressing the whole story
    // into a 200-px Settings card.

    // 2026-05-09: trustWeightsCard + trustWeightSlider helper moved
    // to TrustView (`weightsDisclosure` + `weightSlider`).  Discovery
    // wins — the user finds the sliders at the exact moment they're
    // looking at the score they want to tune.

    // 2026-05-09: securityCard moved to FleetView.  Privacy mode +
    // loopback-only + token regeneration all govern who reaches
    // the swarm; living next to the swarm peers makes the
    // cause-and-effect obvious.  See FleetView.securityCard.

    // MARK: Helpers

    private func revealChromeExtension() {
        guard let base = Bundle.main.resourceURL?
                .appendingPathComponent("Extensions/Chrome", isDirectory: true),
              FileManager.default.fileExists(atPath: base.path) else {
            missingAssetAlert(what: "Chrome extension")
            return
        }
        NSWorkspace.shared.open(base)
    }

    private func openSafariBookmarklets() {
        guard let base = Bundle.main.resourceURL?
                .appendingPathComponent("Extensions/Safari/bookmarklets.html"),
              FileManager.default.fileExists(atPath: base.path) else {
            missingAssetAlert(what: "Safari bookmarklets page")
            return
        }
        NSWorkspace.shared.open(base)
    }

    private func missingAssetAlert(what: String) {
        let alert = NSAlert()
        alert.messageText = "\(what) missing from app bundle"
        alert.informativeText = "This is a packaging bug — please report it. The app works without the helper."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Sprint 4 PRO-PLUS-IPHONE (2026-05-10): engagement viewer + Trust+ upsell
//
// engagementViewerCard — privacy through transparency.  Surfaces
// every counter the EngagementStore records so the user reads the
// same data the future Trust+ gate reads.  No telemetry; the JSON
// file lives at ~/Library/Application Support/Splynek/engagement.json.
//
// trustPlusUpsellCard — appears only when EngagementGate.shouldOfferTrustPlus
// fires (≥20 Trust-Watcher engagement events).  Below the threshold
// the card is invisible — the user hasn't earned the pitch yet.
//
// Both Pro-gated; both fileprivate so the SettingsView struct's
// body stays readable.

extension SettingsView {

    @ViewBuilder
    fileprivate var engagementViewerCard: some View {
        if vm.license.isPro {
            engagementViewerCardBody
        } else {
            EmptyView()  // free tier sees nothing here
        }
    }

    @ViewBuilder
    private var engagementViewerCardBody: some View {
        TitledCard(
            title: "Your engagement (read-only)",
            systemImage: "chart.bar.doc.horizontal",
            accessory: AnyView(
                StatusPill(text: "LOCAL", style: .success)
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Splynek tracks how often you use each Pro feature so a future Trust+ subscription pitch only appears for users who actually engage. The data never leaves your Mac. You're reading the same JSON Splynek reads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                let counters = vm.engagementStore.read()
                Divider().opacity(0.3)
                engagementGroup(title: "Trust Watcher", rows: [
                    ("Card views",        counters.trustWatcherViews),
                    ("Manual sweeps",     counters.trustWatcherManualRuns),
                    ("Alerts handled",    counters.trustWatcherAcksHandled),
                    ("Pages opened",      counters.trustWatcherPagesOpened),
                ])
                engagementGroup(title: "Sovereignty Migrate", rows: [
                    ("Wizard opens",      counters.migrateWizardOpens),
                    ("Steps completed",   counters.migrateStepsCompleted),
                    ("Apps marked",       counters.migrateAppsMarkedTotal),
                ])
                engagementGroup(title: "iPhone Companion", rows: [
                    ("Summary fetches",   counters.iphoneSummaryServes),
                    ("Remote commands",   counters.iphoneRemoteCommands),
                ])

                Divider().opacity(0.3)
                if let first = counters.firstRecordedAt {
                    Text("Recording since \(prettyDate(first)).")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No engagement recorded yet — try Trust Watcher's Run-now or open a Migrate wizard.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                HStack {
                    Spacer()
                    Button {
                        revealEngagementJSON()
                    } label: {
                        Label("Show JSON file", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open the engagement.json file in Finder so you can inspect or delete it directly.")
                }
            }
        }
    }

    @ViewBuilder
    fileprivate var trustPlusUpsellCard: some View {
        if vm.license.isPro {
            let counters = vm.engagementStore.read()
            if EngagementGate.shouldOfferTrustPlus(counters: counters) {
                trustPlusUpsellCardBody(counters: counters)
            } else {
                // Below threshold — no upsell shown.  The user
                // hasn't demonstrated they value the feature.
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func trustPlusUpsellCardBody(
        counters: EngagementCounters
    ) -> some View {
        let active = counters.trustWatcherManualRuns
            + counters.trustWatcherAcksHandled
            + counters.trustWatcherPagesOpened
        TitledCard(
            title: "Splynek Trust+",
            systemImage: "sparkles.tv.fill",
            accessory: AnyView(
                StatusPill(text: "PREVIEW", style: .info)
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("You've engaged with Trust Watcher \(active) times. Splynek's evaluating a Trust+ subscription that adds: weekly Trust-catalog refreshes, acquisition radar (\"this app got bought by X — here's the privacy delta\"), one-click ToS history viewer.")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Trust+ would be opt-in — your existing Pro purchase keeps everything you have today, including Trust Watcher catalog refreshes for the lifetime of this purchase. Trust+ would only add ongoing premium catalog updates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().opacity(0.3)
                Text("This is a preview surface — Trust+ isn't yet available for purchase. We're collecting interest to decide whether to ship it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
                HStack {
                    Spacer()
                    Button {
                        sendTrustPlusInterest(active: active)
                    } label: {
                        Label("I'd be interested", systemImage: "envelope")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Button {
                        // Opt out forever — set the gate to a value
                        // it cannot mathematically reach by user
                        // action (counters are unsigned-ish; setting
                        // each to 0 + adding a "muted" flag would be
                        // cleaner, but for the Sprint-4 scope this
                        // is just a session-local hide).
                        upsellHidden = true
                    } label: {
                        Label("Not interested", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .opacity(upsellHidden ? 0 : 1)
        .frame(height: upsellHidden ? 0 : nil)
    }

    @ViewBuilder
    fileprivate func engagementGroup(
        title: String, rows: [(String, Int)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(rows, id: \.0) { (label, count) in
                HStack {
                    Text(label)
                        .font(.callout)
                    Spacer()
                    Text("\(count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    fileprivate func revealEngagementJSON() {
        let fm = FileManager.default
        guard let base = try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ) else { return }
        let path = base
            .appendingPathComponent("Splynek", isDirectory: true)
            .appendingPathComponent("engagement.json")
        if fm.fileExists(atPath: path.path) {
            NSWorkspace.shared.activateFileViewerSelecting([path])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([
                path.deletingLastPathComponent()
            ])
        }
    }

    fileprivate func sendTrustPlusInterest(active: Int) {
        // Sprint 4: open a pre-filled mailto.  Sprint 5 might add
        // a one-click in-app form via a /trust-plus-interest
        // endpoint on splynek.app; for now mailto keeps it
        // privacy-pristine — user's mail client is the only thing
        // that learns they're interested.
        let subject = "Trust+ interest — \(active) engagement events"
        let body = """
        Hi Splynek,

        I'd be interested in a Splynek Trust+ subscription with
        weekly catalog refreshes, acquisition radar, and ToS
        history viewer.

        I've engaged with Trust Watcher \(active) times so far.

        — sent from Settings → Splynek Trust+
        """
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = "trust-plus@splynek.app"
        comps.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        if let url = comps.url {
            NSWorkspace.shared.open(url)
        }
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

// `upsellHidden` is now a @State on SettingsView itself
// (declared at the top of the struct).  The earlier
// EnvironmentKey draft was dropped — direct @State is simpler.

// MARK: - Sprint 4 PRO-PLUS-IPHONE: API tokens UI

extension SettingsView {

    @ViewBuilder
    fileprivate var apiTokensCard: some View {
        if vm.license.isPro {
            apiTokensCardBody
        } else {
            ProLockedView(
                featureTitle: "API tokens",
                summary: "Mint stable tokens for Raycast, Alfred, BetterTouchTool, or any shell script that wants to talk to Splynek across sessions. Two scopes (read-only / read+write); revoke any time.",
                systemImage: "key.fill",
                onUnlock: { vm.requestProUnlock() }
            )
        }
    }

    @ViewBuilder
    private var apiTokensCardBody: some View {
        TitledCard(
            title: "API tokens",
            systemImage: "key.fill",
            accessory: AnyView(
                StatusPill(text: "PRO", style: .info)
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Persistent tokens for external scripting.  Each token has a label, a scope, and shows up in Splynek's request logs by name. Read-only tokens can hit GET endpoints (jobs, summaries, history); read+write tokens can also queue/cancel/pause downloads.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                let store = vm.fleet.apiTokenStoreFile.read()
                if store.tokens.isEmpty {
                    Text("No tokens minted yet.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.tokens) { token in
                            apiTokenRow(token)
                        }
                    }
                }

                Divider().opacity(0.3)

                HStack(spacing: 8) {
                    TextField("Label (e.g. Raycast)", text: $apiTokenDraftLabel)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220)
                    Picker("", selection: $apiTokenDraftScope) {
                        Text("Read + write").tag(APITokenScope.readWrite)
                        Text("Read-only").tag(APITokenScope.readOnly)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 140)
                    Spacer()
                    Button {
                        mintAPIToken()
                    } label: {
                        Label("Mint token", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(apiTokenDraftLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let err = apiTokenLastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    fileprivate func apiTokenRow(_ token: APIToken) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(token.label)
                    .font(.callout.weight(.semibold))
                Text(token.scope.label)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(token.scope == .readOnly
                            ? Color.blue.opacity(0.18)
                            : Color.orange.opacity(0.18))
                    )
                    .foregroundStyle(token.scope == .readOnly ? .blue : .orange)
                Spacer()
                Button {
                    revealAPIToken = token.id
                } label: {
                    Label("Show", systemImage: revealAPIToken == token.id
                          ? "eye.slash" : "eye")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(token.secret, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button(role: .destructive) {
                    vm.fleet.apiTokenStoreFile.mutate { $0.revoke(id: token.id) }
                    apiTokenStoreVersion += 1
                } label: {
                    Label("Revoke", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if revealAPIToken == token.id {
                Text(token.secret)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )
            }
            HStack(spacing: 6) {
                Text("Created \(prettyDate(token.createdAt))")
                if let used = token.lastUsedAt {
                    Text("·").foregroundStyle(.tertiary)
                    Text("Last used \(prettyDate(used))")
                } else {
                    Text("·").foregroundStyle(.tertiary)
                    Text("Never used").foregroundStyle(.tertiary)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    fileprivate func mintAPIToken() {
        let label = apiTokenDraftLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else {
            apiTokenLastError = "Label can't be empty."
            return
        }
        let token = APIToken(label: label, scope: apiTokenDraftScope)
        vm.fleet.apiTokenStoreFile.mutate { $0.add(token) }
        apiTokenDraftLabel = ""
        apiTokenLastError = nil
        revealAPIToken = token.id  // open it so user can copy
        apiTokenStoreVersion += 1
    }
}
