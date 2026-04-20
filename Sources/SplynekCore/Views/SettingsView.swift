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
                proCard
                browserHelpersCard
                webDashboardCard
                aiCard
                scheduleCard
                watchedFolderCard
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

    // MARK: Web dashboard (v0.24 splash)

    @ViewBuilder
    private var webDashboardCard: some View {
        if vm.license.isPro {
            webDashboardCardUnlocked
        } else {
            ProLockedView(
                featureTitle: "Mobile web dashboard",
                summary: "Let your phone submit downloads to this Mac over the LAN — QR pairing, live progress, token-gated submit. Free tier runs the dashboard loopback-only; Pro opens it to the LAN.",
                systemImage: "iphone.gen3.radiowaves.left.and.right",
                onUnlock: { vm.requestProUnlock() }
            )
        }
    }

    private var webDashboardCardUnlocked: some View {
        TitledCard(title: "Web dashboard", systemImage: "iphone.gen3.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scan the QR with a phone on the same LAN to submit downloads to this Mac. Read-only state is open to the LAN; submit requires the token embedded in the QR.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = vm.fleet.webDashboardURL() {
                    HStack(alignment: .top, spacing: 14) {
                        // v0.49: QR shrunk 170 → 110 px. At 170 the code
                        // dominated the Web-dashboard card and felt out of
                        // scale with the text beside it; 110 still scans
                        // fine from phone distance (~25 cm) and leaves
                        // room for the URL + token controls to breathe.
                        if let qr = QRCode.image(for: url.absoluteString, size: 110) {
                            Image(nsImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 110, height: 110)
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

    // MARK: Download schedule

    @ViewBuilder
    private var scheduleCard: some View {
        if vm.license.isPro {
            scheduleCardUnlocked
        } else {
            ProLockedView(
                featureTitle: "Download schedule",
                summary: "Only run downloads inside a time window — e.g., overnight on home Wi-Fi — with weekday rules and a cellular-off option. Running downloads are never interrupted; the schedule only gates starts.",
                systemImage: "clock.badge.checkmark",
                onUnlock: { vm.requestProUnlock() }
            )
        }
    }

    private var scheduleCardUnlocked: some View {
        let schedule = Binding(
            get: { vm.downloadSchedule },
            set: { vm.updateSchedule($0) }
        )
        return TitledCard(
            title: "Download schedule",
            systemImage: "clock.badge.checkmark",
            accessory: AnyView(StatusPill(
                text: schedule.wrappedValue.enabled ? "ON" : "OFF",
                style: schedule.wrappedValue.enabled ? .success : .neutral
            ))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Only start queued downloads inside a time window — e.g., overnight on home Wi-Fi. Running downloads are never interrupted; the schedule only gates starts.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: Binding(
                    get: { schedule.wrappedValue.enabled },
                    set: { var s = schedule.wrappedValue; s.enabled = $0; schedule.wrappedValue = s }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Respect schedule")
                        Text(schedule.wrappedValue.summary)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if schedule.wrappedValue.enabled {
                    hourWindowControls(schedule)
                    Divider().opacity(0.3)
                    weekdayPicker(schedule)
                    Divider().opacity(0.3)
                    Toggle(isOn: Binding(
                        get: { schedule.wrappedValue.pauseOnCellular },
                        set: { var s = schedule.wrappedValue; s.pauseOnCellular = $0; schedule.wrappedValue = s }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pause on cellular")
                            Text("Block starts while any selected interface is cellular. Complements the per-day bytes cap.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    currentStateRow
                }
            }
        }
    }

    private func hourWindowControls(_ schedule: Binding<DownloadSchedule>) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { schedule.wrappedValue.startHour },
                    set: { var s = schedule.wrappedValue; s.startHour = $0; schedule.wrappedValue = s }
                )) {
                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                }
                .labelsHidden()
                .frame(width: 90)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("End").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { schedule.wrappedValue.endHour },
                    set: { var s = schedule.wrappedValue; s.endHour = $0; schedule.wrappedValue = s }
                )) {
                    ForEach(1...24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                }
                .labelsHidden()
                .frame(width: 90)
            }
            Spacer()
            if schedule.wrappedValue.startHour > schedule.wrappedValue.endHour {
                StatusPill(text: "WRAPS MIDNIGHT", style: .info)
            }
        }
    }

    private func weekdayPicker(_ schedule: Binding<DownloadSchedule>) -> some View {
        // Ordered Mon→Sun because that reads more naturally in a picker
        // than Cal.weekday's Sun-first convention.
        let order: [(Int, String)] = [
            (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"),
            (6, "Fri"), (7, "Sat"), (1, "Sun")
        ]
        return VStack(alignment: .leading, spacing: 6) {
            Text("Active days").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(order, id: \.0) { item in
                    let active = schedule.wrappedValue.weekdays.contains(item.0)
                    Button {
                        var s = schedule.wrappedValue
                        if active { s.weekdays.remove(item.0) }
                        else      { s.weekdays.insert(item.0) }
                        schedule.wrappedValue = s
                    } label: {
                        Text(item.1)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .frame(width: 36, height: 24)
                            .foregroundStyle(active ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(active ? Color.accentColor : Color.primary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Weekdays") {
                    var s = schedule.wrappedValue
                    s.weekdays = [2, 3, 4, 5, 6]
                    schedule.wrappedValue = s
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Every day") {
                    var s = schedule.wrappedValue
                    s.weekdays = Set(1...7)
                    schedule.wrappedValue = s
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder private var currentStateRow: some View {
        let eval = vm.scheduleEvaluation
        HStack(spacing: 8) {
            Image(systemName: eval == .allowed ? "checkmark.seal.fill" : "hourglass")
                .foregroundStyle(eval == .allowed ? .green : .orange)
            switch eval {
            case .allowed:
                Text("Window is open — queued items will start as slots free up.")
                    .font(.caption).foregroundStyle(.secondary)
            case .blocked(let reason, let nextAllowed):
                if let next = nextAllowed {
                    Text("\(reason.displayText) — next opening \(Self.relative(next)).")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(reason.displayText).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private static func relative(_ date: Date) -> String { formatRelative(date) }

    // MARK: Watched folder

    private var watchedFolderCard: some View {
        TitledCard(
            title: "Watched folder",
            systemImage: "folder.badge.gearshape",
            accessory: AnyView(StatusPill(
                text: vm.watchEnabled ? "ON" : "OFF",
                style: vm.watchEnabled ? .success : .neutral
            ))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Drop `.txt` (one URL per line), `.torrent`, or `.metalink` files here. Splynek queues each new file within 5 seconds, then moves it to a `processed/` subfolder.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: Binding(
                    get: { vm.watchEnabled },
                    set: { vm.setWatchEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watch folder for drops")
                        Text("Polled every 5 s. `# comments` and blank lines in .txt files are ignored.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(vm.watchFolder.path)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Change…") { pickWatchFolder() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button {
                        NSWorkspace.shared.selectFile(nil,
                            inFileViewerRootedAtPath: vm.watchFolder.path)
                    } label: {
                        Label("Reveal", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open the watched folder in Finder.")
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
    }

    private func pickWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Watch"
        panel.directoryURL = vm.watchFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vm.setWatchFolder(url)
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
