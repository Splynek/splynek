import SwiftUI
import AppKit

/// Everything a user might want to *configure* — separated out of About,
/// which is now just brand + features + links.
///
/// Sections:
///   • Browser helpers (Chrome extension, Safari bookmarklets)
///   • Web dashboard (LAN URL, QR, token controls)
///   • Local AI (Ollama detection + model)
///   • Background mode (dock icon, login item)
///   • Security & privacy (privacy mode, loopback, regenerate token)
///
/// All cards are identical in visual weight; the user scans down a
/// single column to configure the app.
struct SettingsView: View {
    @ObservedObject var vm: SplynekViewModel
    @EnvironmentObject var background: BackgroundModeController

    init(vm: SplynekViewModel) { self.vm = vm }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ContextCard(
                    systemImage: "gearshape",
                    subtitle: "Integrations, background behaviour, web dashboard, and security controls. Nothing here phones home.",
                    tint: .gray
                )
                proCard
                browserHelpersCard
                // 2026-05-09: webDashboardCard + iPhonePairingRow moved
                // to AgentsView — both are external-access surfaces
                // sharing the same listener and token gating; living
                // next to the MCP setup tells the full story in one
                // tab.  See AgentsView.mobileDashboardCard.
                // 2026-05-09: swarmHouseholdCard + securityCard moved
                // to FleetView — household token + privacy/loopback
                // controls now live next to the swarm peers they
                // gate.  See FleetView.householdTokenCard / securityCard.
                aiCard
                // 2026-05-09: scheduleCard + watchedFolderCard moved
                // to QueueView — both configure HOW the queue behaves
                // (gating + ingestion); now live next to the queue
                // they affect.
                backgroundModeCard
                // 2026-05-09: trustWeightsCard moved to TrustView —
                // sliders that tune the Trust score now live next
                // to the score they tune.  See TrustView.weightsDisclosure.
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
