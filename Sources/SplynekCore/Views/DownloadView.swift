import SwiftUI

struct DownloadView: View {
    @ObservedObject var vm: SplynekViewModel
    @State private var showAdvanced = false
    @FocusState private var urlFieldFocused: Bool
    @State private var aiQuery: String = ""
    /// Debounce for the auto-enrichment probe. Cancelled on every
    /// keystroke; fires ~600 ms after the user stops typing. Keeps the
    /// probe from slamming the network on every keypress while still
    /// firing before the user clicks Start for typical paste flows.
    @State private var enrichDebounce: Task<Void, Never>?

    init(vm: SplynekViewModel) { self.vm = vm }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isFirstPaint {
                    brandStrip
                } else {
                    PageHeader(
                        systemImage: "arrow.down.circle",
                        title: "Downloads",
                        subtitle: "Paste a URL. Splynek fans it out across every interface you have — Wi-Fi, Ethernet, tether — and reassembles a verified file."
                    )
                }
                sourceCard
                if !vm.aiAvailable && vm.history.count < 3 {
                    aiUpsellRow
                }
                if let projection = projectedSplit() {
                    projectionChip(projection)
                }
                optionsCard
                if showAdvanced { advancedCard }
                interfacesCard
                if !vm.activeJobs.isEmpty {
                    activeJobsHeader
                    ForEach(vm.activeJobs) { job in
                        JobCard(job: job, vm: vm)
                    }
                }
                // (form error banner moved into the Source card so
                // it appears right below the Start button — see the
                // source card's inline error view.)
            }
            .padding(20)
            .animation(.easeInOut(duration: 0.2), value: vm.activeJobs.count)
            .animation(.easeInOut(duration: 0.2), value: vm.formErrorMessage != nil)
            .animation(.easeInOut(duration: 0.2), value: showAdvanced)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(windowTitle)
        .toolbar { downloadToolbar }
    }

    /// True when this is a user's first look at the app: no jobs, no
    /// history, no URL typed. Triggers the compact brand hero +
    /// onboarding hint so the form isn't the user's first impression.
    private var isFirstPaint: Bool {
        vm.activeJobs.isEmpty &&
        vm.history.isEmpty &&
        vm.urlText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Compact brand strip: logo + tagline + one-line hint on what to do
    /// first. Shown only during first-paint (see `isFirstPaint`). Much
    /// smaller than the About-pane hero so it doesn't dominate.
    private var brandStrip: some View {
        HStack(spacing: 14) {
            Group {
                if let url = Bundle.main.url(forResource: "Splynek", withExtension: "icns"),
                   let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                } else if let nsImage = NSApp.applicationIconImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.high)
                }
            }
            .frame(width: 60, height: 60)
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome to Splynek")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Paste a URL below. Splynek downloads it across every interface you have — Wi-Fi, Ethernet, iPhone tether — in parallel.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.18),
                            Color.accentColor.opacity(0.04)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5)
        )
    }

    /// AI upsell. Shown to users who don't have Ollama running (the AI
    /// row would be hidden today) during their first few downloads, so
    /// the AI value prop isn't invisible to the 80% without Ollama.
    /// One-click link to ollama.com/download.
    private var aiUpsellRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 1) {
                Text("Describe downloads in plain English")
                    .font(.callout).fontWeight(.semibold)
                Text("Install Ollama to type “the latest Ubuntu ISO” instead of a URL. Runs locally — free, no account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                if let u = URL(string: "https://ollama.com/download") {
                    NSWorkspace.shared.open(u)
                }
            } label: {
                Label("Install Ollama", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.purple.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.purple.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var windowTitle: String {
        let running = vm.activeJobs.filter { $0.lifecycle == .running }
        if running.count == 1, let job = running.first {
            return "Downloading — \(Int(job.progress.fraction * 100))%"
        }
        if running.count > 1 {
            return "Downloading — \(running.count) active"
        }
        return "Downloads"
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var downloadToolbar: some ToolbarContent {
        // v0.46 UX fix: the toolbar previously carried Start + Queue
        // buttons that were pixel-for-pixel duplicates of the big
        // "Start download" / "Add to queue" buttons inside the
        // Source card below. Users reported it as clutter. Both
        // actions are now card-only; the Return / ⌘⇧Q keyboard
        // shortcuts moved onto the card buttons themselves.
        // Toolbar keeps only the genuinely toolbar-scoped actions:
        // Cancel All (contextual), Copy curl, Advanced toggle.
        ToolbarItemGroup(placement: .primaryAction) {
            if vm.isRunning {
                Button(role: .destructive) { vm.cancelAll() } label: {
                    Label("Cancel All", systemImage: "stop.fill")
                }
                .keyboardShortcut(".", modifiers: .command)
                .help("Cancel every running download (⌘.).")
            }
            Button { vm.copyCurlCommand() } label: {
                Label("Copy curl", systemImage: "terminal")
            }
            .disabled(vm.urlText.isEmpty)
            .help("Copy a curl equivalent to the clipboard.")

            Button { showAdvanced.toggle() } label: {
                Label("Advanced", systemImage: showAdvanced ? "chevron.up" : "chevron.down")
            }
            .help(showAdvanced ? "Hide advanced options" : "Show advanced options (Merkle / Metalink / headers)")
        }
    }

    // MARK: Source card (URL, SHA, output)

    private var sourceCard: some View {
        TitledCard(title: "Source", systemImage: "link") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "globe").foregroundStyle(.secondary)
                    TextField("https://example.com/file.iso", text: $vm.urlText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .focused($urlFieldFocused)
                        .onSubmit {
                            if let u = URL(string: vm.urlText.trimmingCharacters(in: .whitespaces)),
                               u.scheme?.hasPrefix("http") == true {
                                Task { await vm.autoDetectSha256(for: u) }
                            }
                        }
                    if !vm.urlText.isEmpty {
                        Button { vm.urlText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            urlFieldFocused
                                ? Color.accentColor.opacity(0.6)
                                : Color.primary.opacity(0.08),
                            lineWidth: urlFieldFocused ? 1.2 : 0.5
                        )
                )
                .onReceive(NotificationCenter.default.publisher(for: .splynekFocusURL)) { _ in
                    urlFieldFocused = true
                }
                .onChange(of: vm.urlText) { newValue in
                    enrichDebounce?.cancel()
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let u = URL(string: trimmed),
                          u.scheme?.hasPrefix("http") == true else {
                        // Clear stale enrichment state so the UI doesn't
                        // show pills for a URL the user deleted.
                        vm.enrichment = EnrichmentReport()
                        vm.duplicate = nil
                        return
                    }
                    enrichDebounce = Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        if Task.isCancelled { return }
                        await vm.autoDetectSha256(for: u)
                    }
                }
                inputRow(icon: "checkmark.shield",
                         placeholder: "optional SHA-256 for integrity",
                         text: $vm.sha256Expected, mono: true, accessory: {
                    if !vm.sha256Expected.isEmpty {
                        AnyView(StatusPill(text: "SHA-256", style: .success))
                    } else { nil }
                })
                if vm.aiAvailable && vm.license.isPro {
                    aiRow
                }
                if !vm.enrichment.badges.isEmpty {
                    enrichmentRow
                }
                if let dup = vm.duplicate {
                    duplicateBanner(dup)
                }
                // QA P2 #14 (v0.43): inline Start / Queue row so
                // users don't have to hunt for the toolbar. The
                // toolbar buttons remain as the keyboard-shortcut
                // home; these duplicate the primary actions where
                // the eye is already looking.
                HStack(spacing: 10) {
                    Button { vm.start() } label: {
                        Label("Start download", systemImage: "arrow.down.circle.fill")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return)
                    .disabled(vm.urlText.trimmingCharacters(in: .whitespaces).isEmpty
                              || vm.isRunning)
                    .help("Start download now (⏎). Pulls the URL across every selected interface in parallel.")
                    Button { vm.addCurrentToQueue() } label: {
                        Label("Add to queue",
                              systemImage: "line.3.horizontal.decrease.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut("q", modifiers: [.command, .shift])
                    .disabled(vm.urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help("Add to queue (⌘⇧Q). Runs when the current download finishes.")
                    Spacer()
                    if vm.isRunning {
                        StatusPill(text: "RUNNING", style: .info)
                    }
                }
                // v0.46 fix: previously the form error banner (bad
                // URL, probe failure, etc.) was rendered far below
                // the card — often off-screen when the active-jobs
                // list was empty, so a 404 probe looked like "I
                // clicked Start and nothing happened." Move the
                // banner INLINE here so it appears directly under
                // the button the user just clicked.
                if let err = vm.formErrorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(err).font(.callout)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                HStack(spacing: 8) {
                    Image(systemName: "folder").foregroundStyle(.secondary)
                    Text(vm.outputDirectory.path)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Change…") { vm.chooseOutputDirectory() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    /// Natural-language URL resolver row. Only appears when the VM
    /// detected a local Ollama with at least one model installed. The
    /// user types English ("the latest Ubuntu desktop ISO"), Return
    /// (or click the sparkle button) sends it to the local LLM, the
    /// resolved URL populates the field above, and a rationale pill
    /// explains the model's pick. No auto-start — the user confirms
    /// with Start like any other flow.
    private var aiRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .font(.system(size: 13, weight: .bold))
                TextField("Or describe it — “latest Ubuntu 24.04 desktop ISO”",
                          text: $aiQuery)
                    .textFieldStyle(.plain)
                    .font(.system(.callout))
                    .disabled(vm.aiThinking)
                    .onSubmit { resolveAI() }
                if vm.aiThinking {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        resolveAI()
                    } label: {
                        Label("Ask", systemImage: "wand.and.stars")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(aiQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.purple.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.25), lineWidth: 0.5)
            )
            if let rationale = vm.aiRationale {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green.opacity(0.85))
                    Text(rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if let model = vm.aiModel {
                        Text(model)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.purple.opacity(0.10))
                            )
                    }
                }
            }
            if let err = vm.aiErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }
    }

    private func resolveAI() {
        let q = aiQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        vm.resolveViaAI(q)
    }

    /// Projection tuple for the split-preview chip: ordered list of
    /// (interface, bytes-per-second) for currently-selected interfaces
    /// whose host has observed history. Nil when we have nothing to
    /// project (unknown host, no selected interfaces, no prior data).
    private func projectedSplit() -> [(name: String, bps: Double)]? {
        let raw = vm.urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), let host = url.host, !host.isEmpty else {
            return nil
        }
        let profile = DownloadHistory.laneProfile(host: host)
        guard !profile.isEmpty else { return nil }
        let selectedInterfaces = vm.interfaces.filter {
            vm.selected.contains($0.name) && $0.nwInterface != nil
        }
        let items = selectedInterfaces
            .map { ($0.name, profile[$0.name] ?? 0) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        return items.isEmpty ? nil : items
    }

    /// Stacked-bar preview of how Splynek expects this download to
    /// split across the currently-selected interfaces, based on
    /// historical performance against this URL's host. Shows a
    /// projected aggregate throughput + time-to-finish (if we have
    /// the file size from probe). Data comes from
    /// `DownloadHistory.laneProfile(host:)`.
    private func projectionChip(_ items: [(name: String, bps: Double)]) -> some View {
        let total = items.reduce(0.0) { $0 + $1.bps }
        let palette: [Color] = [.accentColor, .green, .orange, .pink, .purple, .cyan]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.tint)
                    .font(.system(size: 12, weight: .semibold))
                Text("Projected split — based on prior runs against this host")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(formatRate(total))
                    .font(.system(.callout, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, pair in
                        let frac = total > 0 ? pair.bps / total : 0
                        Rectangle()
                            .fill(palette[idx % palette.count])
                            .frame(width: max(1, geo.size.width * frac))
                    }
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .frame(height: 10)

            HStack(spacing: 14) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, pair in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(palette[idx % palette.count])
                            .frame(width: 8, height: 8)
                        Text(pair.name)
                            .font(.system(.caption, design: .monospaced))
                        Text(String(format: "%.0f%%",
                                    total > 0 ? (pair.bps / total) * 100 : 0))
                            .font(.caption).foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }

    /// Auto-enrichment pill row. Shown when the VM's background sibling
    /// probes discover helpful metadata next to the pasted URL —
    /// `.torrent`, `.metalink`, `.splynek-manifest`, `.sha256`, `.asc`.
    /// Clicking a pill is mostly informational; Merkle + Metalink
    /// auto-apply in the background.
    private var enrichmentRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(.yellow)
                .font(.system(size: 12, weight: .bold))
            Text("Splynek found:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(vm.enrichment.badges) { badge in
                HStack(spacing: 3) {
                    Image(systemName: badge.systemImage)
                    Text(badge.label)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(tintColor(for: badge.tint))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule(style: .continuous)
                        .fill(tintColor(for: badge.tint).opacity(0.14))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(tintColor(for: badge.tint).opacity(0.25), lineWidth: 0.5)
                )
            }
            Spacer()
        }
    }

    private func tintColor(for tint: EnrichmentTint) -> Color {
        switch tint {
        case .green:     return .green
        case .purple:    return .purple
        case .blue:      return .blue
        case .pink:      return .pink
        case .orange:    return .orange
        case .accent:    return .accentColor
        case .secondary: return .secondary
        }
    }

    /// "You already have this" banner. Appears when the pasted URL
    /// matches a prior completion whose output file is still on disk.
    /// Three actions — Reveal (opens Finder), Re-download (continues
    /// into the normal flow), Dismiss (hides the banner but keeps the
    /// form intact so the user can try something else).
    private func duplicateBanner(_ match: DuplicateMatch) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("You already have this file")
                    .font(.headline)
                Text("\(match.entry.filename) · \(formatBytes(match.entry.totalBytes)) · \(relativeTime(match.ageSeconds)) ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Button {
                vm.revealDuplicateInFinder()
            } label: {
                Label("Reveal", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            Button {
                vm.overrideDuplicateAndStart()
            } label: {
                Label("Re-download", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            Button {
                vm.dismissDuplicate()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.yellow.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.35), lineWidth: 0.5)
        )
    }

    private func relativeTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s < 60        { return "\(s)s" }
        if s < 3600      { return "\(s / 60)m" }
        if s < 86_400    { return "\(s / 3600)h" }
        return "\(s / 86_400)d"
    }

    /// v0.47: label text + an adjacent info ⓘ icon whose hover
    /// tooltip explains what the option does. For non-techie users
    /// who look at "Connections per interface" or "Per-interface DoH"
    /// and don't know what those mean.
    @ViewBuilder
    private func labelWithInfo(_ text: String, tooltip: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption).foregroundStyle(.secondary)
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.6))
                .help(tooltip)
        }
    }

    @ViewBuilder
    private func inputRow(
        icon: String, placeholder: String,
        text: Binding<String>, mono: Bool,
        accessory: () -> AnyView? = { nil },
        onSubmit: @escaping () -> Void = {}
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(mono ? .body : .body, design: mono ? .monospaced : .default))
                .onSubmit(onSubmit)
            accessory()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: Options card

    private var optionsCard: some View {
        TitledCard(title: "Options", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        labelWithInfo(
                            "Connections per interface",
                            tooltip: "How many parallel HTTP connections to open per network interface. More = higher peak throughput, but also more load on origin servers. 1–2 is polite; 4–6 is aggressive."
                        )
                        Stepper(value: $vm.connectionsPerInterface, in: 1...8) {
                            Text("\(vm.connectionsPerInterface)")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 24, alignment: .leading)
                        }
                        .help("Set the per-interface parallel-connection count.")
                    }
                    Divider().frame(height: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        labelWithInfo(
                            "Max concurrent downloads",
                            tooltip: "The most downloads Splynek will run at the same time. Extra URLs queue up and start as slots free. Keep low if your link is thin; higher is fine on a fat pipe."
                        )
                        Stepper(value: $vm.maxConcurrentDownloads, in: 1...10) {
                            Text("\(vm.maxConcurrentDownloads)")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 24, alignment: .leading)
                        }
                        .help("Set the concurrent-download cap.")
                    }
                    Divider().frame(height: 36)
                    Toggle(isOn: $vm.useDoH) {
                        Label("Per-interface DoH", systemImage: "lock.shield")
                    }
                    .toggleStyle(.switch)
                    .help("DNS-over-HTTPS, per interface. Each lane resolves hostnames through Cloudflare (1.1.1.1) using encrypted DNS over the same interface it downloads through — prevents DNS leaks across networks and keeps your ISP from seeing which hosts you query. Slight latency penalty on first request.")
                    Spacer()
                }

                if vm.interfaces.contains(where: { $0.isExpensive && vm.selected.contains($0.name) }) {
                    cellularBudgetRow
                }

                Divider()

                HStack(spacing: 12) {
                    Button { vm.loadMetalink() } label: {
                        Label("Load Metalink…", systemImage: "square.stack.3d.up")
                    }
                    .buttonStyle(.bordered)
                    .help("Load a .metalink / .meta4 file — an XML list of mirror URLs + checksums. Splynek fans the download across every mirror in parallel, one per interface, and verifies against the checksum when done. Common on Linux distros.")
                    if !vm.mirrors.isEmpty {
                        StatusPill(text: "\(vm.mirrors.count) MIRRORS", style: .info)
                        Button("Clear") { vm.clearMirrors() }
                            .buttonStyle(.borderless).controlSize(.small)
                            .help("Drop the mirror list and fall back to the single URL above.")
                    }
                    Divider().frame(height: 20)
                    Button { vm.loadMerkleManifest() } label: {
                        Label("Load Merkle…", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.bordered)
                    .help("Load a .splynek-manifest with a precomputed Merkle tree of the file's contents. Splynek verifies each chunk against its expected leaf hash on arrival — any corrupted byte triggers a re-fetch inline, without waiting for a full-file SHA-256 at the end.")
                    if let m = vm.merkleManifest {
                        StatusPill(text: "\(m.leafHexes.count) LEAVES", style: .success)
                        Button("Clear") { vm.clearMerkleManifest() }
                            .buttonStyle(.borderless).controlSize(.small)
                            .help("Drop the Merkle manifest and fall back to end-of-file SHA-256 verification (or none if unset).")
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: Cellular budget

    @State private var capGB: Double = 0

    private var cellularBudgetRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.pink)
            VStack(alignment: .leading, spacing: 1) {
                Text("Cellular used today")
                    .font(.caption).foregroundStyle(.secondary)
                    .textCase(.uppercase).tracking(0.6)
                Text(formatBytes(vm.cellularBytesToday))
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(vm.cellularBudgetExceeded ? .red : .primary)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("Daily cap").font(.caption).foregroundStyle(.secondary)
                TextField("∞", value: $capGB,
                          format: .number.precision(.fractionLength(1)))
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: capGB) { new in
                        vm.setCellularDailyCap(Int64(new * 1024 * 1024 * 1024))
                    }
                Text("GB").font(.caption2).foregroundStyle(.secondary)
            }
            if vm.cellularBudgetExceeded {
                StatusPill(text: "OVER", style: .danger)
            }
            Button { vm.exportCellularBudgetCSV() } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .help("Export today + historical daily totals as CSV.")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.pink.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.pink.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            capGB = Double(vm.cellularDailyCap) / (1024 * 1024 * 1024)
        }
    }

    // MARK: Advanced

    @State private var newHeaderName: String = ""
    @State private var newHeaderValue: String = ""

    private var advancedCard: some View {
        TitledCard(title: "Advanced", systemImage: "wrench.and.screwdriver") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom HTTP headers")
                    .font(.caption).foregroundStyle(.secondary)
                    .textCase(.uppercase).tracking(0.6)
                if vm.customHeaders.isEmpty {
                    Text("No custom headers — the request will use the defaults.")
                        .foregroundStyle(.secondary).font(.callout)
                } else {
                    VStack(spacing: 4) {
                        ForEach(vm.customHeaders.keys.sorted(), id: \.self) { key in
                            HStack(spacing: 8) {
                                Text(key).font(.system(.callout, design: .monospaced))
                                Text(":").foregroundStyle(.secondary)
                                Text(vm.customHeaders[key] ?? "")
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.tail)
                                Spacer()
                                Button {
                                    vm.customHeaders.removeValue(forKey: key)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.03))
                            )
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField("Name (e.g. X-Api-Key)", text: $newHeaderName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.callout, design: .monospaced))
                        .frame(width: 200)
                    TextField("Value", text: $newHeaderValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.callout, design: .monospaced))
                    Button {
                        let k = newHeaderName.trimmingCharacters(in: .whitespaces)
                        let v = newHeaderValue.trimmingCharacters(in: .whitespaces)
                        guard !k.isEmpty else { return }
                        vm.customHeaders[k] = v
                        newHeaderName = ""
                        newHeaderValue = ""
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(newHeaderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if vm.detachedSignatureURL != nil {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "signature").foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Detached signature available").font(.callout).bold()
                            if let u = vm.detachedSignatureURL {
                                Text(u.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        StatusPill(text: "GPG", style: .info)
                    }
                }
            }
        }
    }

    // MARK: Interfaces

    private var interfacesCard: some View {
        TitledCard(
            title: "Interfaces", systemImage: "network",
            accessory: AnyView(
                Button { Task { await vm.refreshInterfaces() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            )
        ) {
            if vm.interfaces.isEmpty {
                EmptyStateView(systemImage: "network.slash",
                               title: "Discovering interfaces…", message: nil)
            } else {
                VStack(spacing: 6) {
                    let bestName = vm.laneProfile.max(by: { $0.value < $1.value })?.key
                    ForEach(vm.interfaces) { iface in
                        InterfaceRow(
                            interface: iface,
                            selected: Binding(
                                get: { vm.selected.contains(iface.name) },
                                set: { on in
                                    if on { vm.selected.insert(iface.name) }
                                    else  { vm.selected.remove(iface.name) }
                                }),
                            historicalBps: vm.laneProfile[iface.name],
                            isHistoricalBest: (iface.name == bestName &&
                                               (vm.laneProfile[iface.name] ?? 0) > 0),
                            disabled: iface.nwInterface == nil,
                            capBps: Binding(
                                get: { vm.interfaceCapsBps[iface.name] ?? 0 },
                                set: { vm.setInterfaceCap(iface.name, bytesPerSecond: $0) }
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: Active jobs header

    private var activeJobsHeader: some View {
        HStack {
            Label("Active downloads", systemImage: "arrow.down.circle")
                .font(.headline)
            Spacer()
            if vm.activeJobs.contains(where: { $0.lifecycle.isTerminal }) {
                Button { vm.clearFinishedJobs() } label: {
                    Label("Clear finished", systemImage: "trash")
                }
                .buttonStyle(.borderless).controlSize(.small)
            }
        }
    }
}

// MARK: - Job card

private struct JobCard: View {
    @ObservedObject var job: DownloadJob
    let vm: SplynekViewModel
    @ObservedObject var progress: DownloadProgress

    init(job: DownloadJob, vm: SplynekViewModel) {
        self.job = job
        self.vm = vm
        self._progress = ObservedObject(wrappedValue: job.progress)
    }

    var body: some View {
        SectionCard {
            HStack(spacing: 8) {
                Image(systemName: lifecycleIcon)
                    .foregroundStyle(lifecycleColor)
                    .font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(job.outputURL.lastPathComponent)
                        .font(.system(.headline, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                    Text(job.url.host ?? job.url.absoluteString)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if !job.fleetMirrors.isEmpty {
                    StatusPill(text: "FLEET ×\(job.fleetMirrors.count)", style: .success)
                        .help("This download has \(job.fleetMirrors.count) fleet-peer mirror(s) cooperating on the LAN.")
                }
                lifecycleBadge
                actionButtons
            }
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 18) {
                    MetricView(
                        value: String(format: "%.1f%%", progress.fraction * 100),
                        caption: "Complete",
                        tint: progress.finished ? .green : .accentColor
                    )
                    MetricView(
                        value: formatRate(progress.throughputBps),
                        caption: "Throughput",
                        tint: .accentColor
                    )
                    MetricView(value: etaText, caption: "ETA")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatBytes(progress.downloaded))
                            .font(.system(.callout, design: .monospaced, weight: .semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("of \(formatBytes(progress.totalBytes))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                GradientProgressBar(fraction: progress.fraction, height: 8)
                if let msg = progress.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(msg).font(.callout).foregroundStyle(.primary)
                    }
                }
                if progress.finished, let report = progress.report {
                    reportBanner(report)
                }
            }
        }
    }

    /// The "screenshot moment": multi-path vs single-path speedup,
    /// breakdown of bytes per interface.
    @ViewBuilder
    private func reportBanner(_ r: DownloadReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                Text(String(format: "%.1f× faster than single-path", r.speedupFactor))
                    .font(.headline)
                Spacer()
                if r.secondsSaved >= 1 {
                    Text("saved \(formatDuration(r.secondsSaved))")
                        .foregroundStyle(.green).font(.subheadline)
                }
            }
            let sorted = r.bytesPerInterface.sorted { $0.value > $1.value }
            HStack(spacing: 10) {
                ForEach(sorted, id: \.key) { name, bytes in
                    let frac = r.totalBytes > 0
                        ? Double(bytes) / Double(r.totalBytes) : 0
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%  %@",
                                    frac * 100, formatBytes(bytes)))
                            .font(.system(.callout, design: .monospaced, weight: .medium))
                    }
                }
                Spacer()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.yellow.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.yellow.opacity(0.35), lineWidth: 0.5)
        )
    }

    private var etaText: String {
        guard progress.totalBytes > 0, progress.throughputBps > 0, !progress.finished else {
            return "—"
        }
        return formatDuration(Double(progress.totalBytes - progress.downloaded) / progress.throughputBps)
    }

    @ViewBuilder private var lifecycleBadge: some View {
        switch job.lifecycle {
        case .pending:   StatusPill(text: "QUEUED", style: .neutral)
        case .running:   StatusPill(text: "RUNNING", style: .info)
        case .paused:    StatusPill(text: "PAUSED", style: .warning)
        case .completed: StatusPill(text: "DONE", style: .success)
        case .failed:    StatusPill(text: "FAILED", style: .danger)
        case .cancelled: StatusPill(text: "CANCELLED", style: .neutral)
        }
    }

    private var lifecycleIcon: String {
        switch job.lifecycle {
        case .pending:   return "hourglass"
        case .running:   return "arrow.down.circle.fill"
        case .paused:    return "pause.circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .failed:    return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    private var lifecycleColor: Color {
        switch job.lifecycle {
        case .pending:   return .secondary
        case .running:   return .accentColor
        case .paused:    return .orange
        case .completed: return .green
        case .failed:    return .red
        case .cancelled: return .secondary
        }
    }

    @ViewBuilder private var actionButtons: some View {
        HStack(spacing: 6) {
            switch job.lifecycle {
            case .running:
                Button { vm.pauseJob(job) } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.borderless)
                .help("Pause; sidecar is retained so resume picks up here.")
                Button(role: .destructive) { job.cancel() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Cancel.")
            case .paused, .failed:
                Button { vm.resumeJob(job) } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .help(job.lifecycle == .paused ? "Resume." : "Retry.")
                Button(role: .destructive) { vm.removeJob(job) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            case .completed, .cancelled, .pending:
                if job.lifecycle == .completed {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([job.outputURL])
                    } label: {
                        Image(systemName: "magnifyingglass.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Reveal in Finder.")
                }
                Button(role: .destructive) { vm.removeJob(job) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(job.lifecycle == .pending)
            }
        }
    }
}
