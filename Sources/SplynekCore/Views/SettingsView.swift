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
                PageHeader(
                    systemImage: "gearshape",
                    title: "Settings",
                    subtitle: "Integrations, background behaviour, web dashboard, and security controls. Nothing here phones home."
                )
                browserHelpersCard
                webDashboardCard
                aiCard
                backgroundModeCard
                securityCard
            }
            .padding(20)
            .frame(maxWidth: 780)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Settings")
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

    // MARK: Web dashboard (v0.24 splash)

    private var webDashboardCard: some View {
        TitledCard(title: "Web dashboard", systemImage: "iphone.gen3.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scan the QR with a phone on the same LAN to submit downloads to this Mac. Read-only state is open to the LAN; submit requires the token embedded in the QR.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = vm.fleet.webDashboardURL() {
                    HStack(alignment: .top, spacing: 14) {
                        if let qr = QRCode.image(for: url.absoluteString, size: 170) {
                            Image(nsImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 170, height: 170)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Color.primary.opacity(0.12),
                                                      lineWidth: 0.5)
                                )
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(url.absoluteString)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2).truncationMode(.middle)
                                .textSelection(.enabled)
                            HStack(spacing: 8) {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(
                                        url.absoluteString, forType: .string
                                    )
                                } label: {
                                    Label("Copy URL", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                Button {
                                    NSWorkspace.shared.open(url)
                                } label: {
                                    Label("Open", systemImage: "safari")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        Spacer()
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Waiting for the fleet listener to bind…")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

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
                .buttonStyle(.borderless)
                .help("Re-probe localhost:11434 for Ollama")
            )
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Paste English like \u{201C}the latest Ubuntu ISO\u{201D} and the local LLM returns a direct URL. Natural-language history search too. Runs entirely on this Mac.")
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
                        Text(vm.aiUnavailableReason ?? "Ollama not detected.")
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
                    .buttonStyle(.borderless)
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

    // MARK: Security & privacy

    private var securityCard: some View {
        TitledCard(title: "Security & privacy", systemImage: "lock.shield.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Controls over what the LAN can see and who can submit downloads to this Mac.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: Binding(
                    get: { vm.fleet.privacyMode },
                    set: { vm.fleet.privacyMode = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy mode")
                        Text("Hide active + completed downloads from other Splyneks on this LAN. Cooperative cache disabled.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: Binding(
                    get: { vm.fleet.loopbackOnly },
                    set: { vm.fleet.loopbackOnly = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loopback only (takes effect at next launch)")
                        Text("Bind the dashboard + API to 127.0.0.1 only. Your phone won't reach it over Wi-Fi.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                Divider().opacity(0.3)

                HStack(spacing: 10) {
                    Button {
                        vm.fleet.regenerateWebToken()
                    } label: {
                        Label("Regenerate token", systemImage: "arrow.triangle.2.circlepath.circle")
                    }
                    .buttonStyle(.bordered)
                    .help("Invalidate any QR code you've already shared. CLI / Raycast / Alfred re-pair automatically.")
                    Text("Rate limit: 60 req / 10 s per remote IP.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

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
