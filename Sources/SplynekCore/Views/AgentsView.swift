import SwiftUI

/// v1.6.1: dedicated Agents tab — promotion of the v1.6 MCP server
/// from a buried Settings card to a first-class surface.
///
/// **Design rationale.**  MCP isn't a setting — it's a programmable
/// substrate.  Burying it as one of ten cards in Settings made it
/// undiscoverable, and the explanation had to fight for vertical
/// space with watched-folder timing and Trust score weights.  A
/// dedicated tab lets us tell the story (what is MCP? what can it
/// do? how do I connect Claude / ChatGPT / a custom agent?) instead
/// of compressing it into one toggle.
///
/// **What lives here:**
///   - **Status header** — ON/OFF state, copy-paste-able endpoint.
///   - **Tool gallery** — every MCP tool as a visual card so the
///     user can see at a glance what's exposed without reading
///     `MCP_SETUP.md`.
///   - **Quick test** — paste a tool name + arguments, get the
///     response.  Saves the round-trip to a separate Terminal window
///     for verifying the server is alive.
///   - **Per-client setup snippets** — copy the right config for
///     Claude Desktop / claude.ai / curl / custom.
///   - **Privacy + safety footer** — same posture story as the
///     Settings card but with room to breathe.
///
/// The Settings card stays — it's a one-toggle convenience for users
/// who land there.  This view is where the user actually learns about
/// the surface.
struct AgentsView: View {
    @ObservedObject var vm: SplynekViewModel
    @State private var selectedClient: ClientPreset = .claudeCli
    @State private var quickTestToolName: String = "splynek_get_progress"
    @State private var quickTestArgs: String = "{}"
    @State private var quickTestResult: String?
    @State private var quickTestRunning = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ContextCard(
                    systemImage: "antenna.radiowaves.left.and.right",
                    subtitle: "Splynek as a programmable platform — let your phone, Claude, ChatGPT, or any MCP-compatible agent drive downloads, run audits, and search your history through one HTTP endpoint.",
                    tint: .indigo
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                VStack(spacing: 18) {
                    statusCard
                    // 2026-05-09: web dashboard + iPhone pairing QR moved
                    // here from Settings.  Same listener as MCP; same
                    // token gating; same "external interface" story.
                    // Surfacing them together in Agentes lets the user
                    // see every way an outside client can reach this
                    // Mac in one place.
                    mobileDashboardCard
                    toolGalleryCard
                    if vm.mcpEnabled {
                        quickTestCard
                    }
                    clientSetupCard
                    privacyCard
                }
                .padding(20)
                .frame(maxWidth: 880)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Agents")
    }

    // MARK: - Status

    private var statusCard: some View {
        TitledCard(
            title: "Status",
            systemImage: "bolt.horizontal.circle",
            accessory: AnyView(StatusPill(
                text: vm.mcpEnabled ? "ON" : "OFF",
                style: vm.mcpEnabled ? .success : .neutral
            ))
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Allow MCP clients to call Splynek tools",
                       isOn: $vm.mcpEnabled)
                    .toggleStyle(.switch)
                    .font(.callout)

                if vm.mcpEnabled {
                    Divider()
                    if let endpoint = mcpEndpointString() {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Endpoint")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(endpoint)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(endpoint, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.splynekHover)
                                .help("Copy endpoint URL")
                                .accessibilityLabel("Copy endpoint URL to clipboard")
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                            Text("Paste this into your MCP client. Same auth token gates this as the web dashboard.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text("Endpoint binding…")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("Off by default. Flip the switch above to enable agents to call Splynek.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Mobile dashboard + iPhone pairing
    //
    // 2026-05-09: migrated from SettingsView.  Free tier shows a
    // ProLockedView; Pro shows the pair-by-QR experience.  Lives
    // here (not Settings) because it's the same external-access
    // story the rest of this tab tells — the phone is just another
    // client paired with a token-gated endpoint.

    @ViewBuilder
    private var mobileDashboardCard: some View {
        if vm.license.isPro {
            mobileDashboardCardUnlocked
        } else {
            ProLockedView(
                featureTitle: "Mobile web dashboard",
                summary: "Let your phone submit downloads to this Mac over the LAN — QR pairing, live progress, token-gated submit. Free tier runs the dashboard loopback-only; Pro opens it to the LAN.",
                systemImage: "iphone.gen3.radiowaves.left.and.right",
                onUnlock: { vm.requestProUnlock() }
            )
        }
    }

    private var mobileDashboardCardUnlocked: some View {
        TitledCard(title: "Web dashboard", systemImage: "iphone.gen3.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scan the QR with a phone on the same LAN to submit downloads to this Mac. Read-only state is open to the LAN; submit requires the token embedded in the QR.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let url = vm.fleet.webDashboardURL() {
                    HStack(alignment: .top, spacing: 14) {
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

                // S4 iPhone Companion (2026-05-07): second QR for
                // pairing the iOS Splynek Companion app.  Distinct
                // from the dashboard QR — encodes
                // `splynek://pair?host=...&port=...&token=...&name=...`
                // which the iOS app's PairingSheet scans + pre-fills.
                Divider().padding(.vertical, 4)
                iPhonePairingRow
            }
        }
    }

    @ViewBuilder
    private var iPhonePairingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "iphone")
                    .foregroundStyle(.tint)
                Text("Pair Splynek Companion (iPhone)")
                    .font(.headline)
            }
            Text("Open Splynek Companion on your iPhone, tap +, then Scan QR. Pairing is instant — no token paste.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let pairURL = vm.fleet.iPhonePairingURLString() {
                HStack(alignment: .top, spacing: 14) {
                    if let qr = QRCode.image(for: pairURL, size: 110) {
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pairURL)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(2).truncationMode(.middle)
                            .textSelection(.enabled)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(
                                pairURL, forType: .string
                            )
                        } label: {
                            Label("Copy pair URL", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                }
            } else {
                // Loopback-only mode (free tier, default) hides the
                // pairing row — phones aren't on the same network as
                // 127.0.0.1, so a QR pointing to loopback would never
                // pair.  Surface a hint instead.
                Text("LAN sharing is disabled (Privacy mode → Loopback only). Disable Loopback-only above to pair an iPhone.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Tool gallery

    /// Visual catalog of every MCP tool.  Reads from `MCPToolRegistry`
    /// so the gallery stays in sync with what the server actually
    /// exposes — no parallel hand-maintained list to drift.
    private var toolGalleryCard: some View {
        TitledCard(title: "Available tools", systemImage: "rectangle.stack") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Eight tools any MCP client can call. All return human-readable text. Read-only tools listed first; mutating tools at the bottom.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ],
                    spacing: 12
                ) {
                    ForEach(orderedTools, id: \.name) { tool in
                        toolGridItem(tool)
                    }
                }
            }
        }
    }

    /// Order: read-only first (lookup, list, scan, get_progress),
    /// mutating last (download, queue, cancel).  Matches MCP_SETUP.md.
    private var orderedTools: [MCPTool] {
        let readonly = ["splynek_get_progress", "splynek_list_history",
                        "splynek_lookup_sovereignty", "splynek_lookup_trust",
                        "splynek_run_sovereignty_scan"]
        let mutating = ["splynek_download_url", "splynek_queue_url",
                        "splynek_cancel_all"]
        return readonly.compactMap { name in
            MCPToolRegistry.allTools.first(where: { $0.name == name })
        } + mutating.compactMap { name in
            MCPToolRegistry.allTools.first(where: { $0.name == name })
        }
    }

    @ViewBuilder
    private func toolGridItem(_ tool: MCPTool) -> some View {
        let mut = isMutating(tool.name)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: iconForTool(tool.name))
                    .foregroundStyle(mut ? AnyShapeStyle(Color.orange)
                                          : AnyShapeStyle(Color.indigo))
                    .frame(width: 18)
                // v1.6.2: route both display name and tool description
                // through LocalizedStringKey so the catalog can localize.
                Text(LocalizedStringKey(displayName(for: tool.name)))
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                Spacer()
                if mut {
                    StatusPill(text: "WRITES", style: .warning)
                }
            }
            Text(LocalizedStringKey(tool.description))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(5)
            Text(tool.name)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    (mut ? Color.orange : Color.indigo).opacity(0.18),
                    lineWidth: 0.6
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(displayName(for: tool.name))\(mut ? ", mutating tool" : ""), \(tool.description)"
        )
    }

    private func displayName(for name: String) -> String {
        // splynek_lookup_sovereignty → "Lookup sovereignty"
        let stripped = name.hasPrefix("splynek_") ? String(name.dropFirst(8)) : name
        let words = stripped.split(separator: "_")
        guard let first = words.first else { return name }
        return ([first.capitalized] + words.dropFirst().map(String.init)).joined(separator: " ")
    }

    private func iconForTool(_ name: String) -> String {
        switch name {
        case "splynek_get_progress":          return "chart.line.uptrend.xyaxis"
        case "splynek_list_history":          return "clock.arrow.circlepath"
        case "splynek_lookup_sovereignty":    return "shield.lefthalf.filled"
        case "splynek_lookup_trust":          return "checkmark.seal"
        case "splynek_run_sovereignty_scan":  return "magnifyingglass.circle"
        case "splynek_download_url":          return "arrow.down.circle"
        case "splynek_queue_url":             return "line.3.horizontal.decrease.circle"
        case "splynek_cancel_all":            return "stop.circle"
        default:                              return "wrench.and.screwdriver"
        }
    }

    private func isMutating(_ name: String) -> Bool {
        ["splynek_download_url", "splynek_queue_url",
         "splynek_cancel_all"].contains(name)
    }

    // MARK: - Quick test

    /// Simple paste-and-run playground.  Uses the real local MCP
    /// endpoint — same token, same auth.  Helpful for verifying the
    /// server is actually responding before pointing an external
    /// client at it.  Kept simple by design: one tool dropdown, one
    /// JSON args field, one Run button.
    private var quickTestCard: some View {
        TitledCard(title: "Quick test", systemImage: "play.circle") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Verify the server's responding without leaving Splynek. Picks the same endpoint you'd give a remote client.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Picker("Tool", selection: $quickTestToolName) {
                        ForEach(orderedTools, id: \.name) { tool in
                            Text(displayName(for: tool.name)).tag(tool.name)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)

                    TextField("Arguments JSON", text: $quickTestArgs)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))

                    Button {
                        Task { await runQuickTest() }
                    } label: {
                        if quickTestRunning {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Run", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(quickTestRunning)
                }

                if let result = quickTestResult {
                    ScrollView {
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
        }
    }

    private func runQuickTest() async {
        quickTestRunning = true
        defer { quickTestRunning = false }
        guard let endpoint = mcpEndpointString(),
              let url = URL(string: endpoint) else {
            quickTestResult = "Endpoint unavailable."
            return
        }
        let argsJSON: String = quickTestArgs.trimmingCharacters(in: .whitespaces).isEmpty
            ? "{}" : quickTestArgs
        let body = """
        {
          "jsonrpc": "2.0",
          "id": 1,
          "method": "tools/call",
          "params": {
            "name": "\(quickTestToolName)",
            "arguments": \(argsJSON)
          }
        }
        """
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let pretty = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted]) }
                .flatMap { String(data: $0, encoding: .utf8) }
            quickTestResult = pretty ?? String(data: data, encoding: .utf8) ?? "<empty>"
        } catch {
            quickTestResult = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Client setup

    enum ClientPreset: String, CaseIterable, Identifiable {
        case claudeCli, claudeWeb, customCurl, customCode
        var id: String { rawValue }
        var label: String {
            switch self {
            case .claudeCli:  return "Claude Desktop"
            case .claudeWeb:  return "Claude.ai"
            case .customCurl: return "curl"
            case .customCode: return "Custom (any MCP client)"
            }
        }
    }

    private var clientSetupCard: some View {
        TitledCard(title: "Connect a client", systemImage: "link.circle") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Client", selection: $selectedClient) {
                    ForEach(ClientPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                VStack(alignment: .leading, spacing: 8) {
                    // v1.6.2: setupExplanation returns String; wrap to localize.
                    Text(LocalizedStringKey(setupExplanation(for: selectedClient)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(setupSnippet(for: selectedClient))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        VStack {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(
                                    setupSnippet(for: selectedClient),
                                    forType: .string
                                )
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.splynekHover)
                            .help("Copy snippet")
                            .accessibilityLabel("Copy setup snippet to clipboard")
                            .padding(.top, 8)
                            .padding(.trailing, 10)
                            Spacer()
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }

                Text("More details + transport notes in MCP_SETUP.md (in the repo root).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func setupExplanation(for preset: ClientPreset) -> String {
        switch preset {
        case .claudeCli:
            return "Claude Desktop's MCP transport is currently stdio-only. Use a small HTTP-bridge shim like mcp-proxy to bridge to Splynek's HTTP endpoint. When Claude Desktop ships HTTP transport, drop the snippet into ~/Library/Application Support/Claude/claude_desktop_config.json directly."
        case .claudeWeb:
            return "Claude.ai supports remote MCP HTTP transport. Add a remote MCP server in your workspace settings and paste the endpoint URL above."
        case .customCurl:
            return "Quick sanity check — list every available tool. Useful for verifying the server is reachable before configuring a real client."
        case .customCode:
            return "Any client speaking JSON-RPC 2.0 over HTTP POST works. Minimum methods: initialize, tools/list, tools/call. Notifications return 204 (no body)."
        }
    }

    private func setupSnippet(for preset: ClientPreset) -> String {
        let endpoint = mcpEndpointString() ?? "<endpoint unavailable — enable above>"
        switch preset {
        case .claudeCli:
            return """
            {
              "mcpServers": {
                "splynek": {
                  "type": "http",
                  "url": "\(endpoint)"
                }
              }
            }
            """
        case .claudeWeb:
            return endpoint
        case .customCurl:
            return """
            curl -X POST '\(endpoint)' \\
              -H 'Content-Type: application/json' \\
              -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
            """
        case .customCode:
            return """
            POST \(endpoint)
            Content-Type: application/json

            {"jsonrpc":"2.0","id":1,"method":"tools/call",
             "params":{"name":"splynek_lookup_sovereignty",
                       "arguments":{"query":"Spotify"}}}
            """
        }
    }

    // MARK: - Privacy

    private var privacyCard: some View {
        TitledCard(title: "Privacy + safety", systemImage: "hand.raised.fill") {
            VStack(alignment: .leading, spacing: 8) {
                privacyBullet("Off by default. The toggle above is the only way in.")
                privacyBullet("No new sandbox entitlements. The MCP route reuses the existing local-network listener that powers Splynek's web dashboard.")
                privacyBullet("Mutating tools (download / queue / cancel) route through the same ingest path as drag-drop and the browser extension. Every scheme guard, size confirmation, and host cap still fires.")
                privacyBullet("All tool calls are logged via os.Logger under subsystem app.splynek, category system. View with: log stream --predicate 'subsystem == \"app.splynek\"' --info")
                privacyBullet("Catalog data ships in the app — neither Sovereignty nor Trust lookups query a network service. Your installed-app list never leaves your Mac.")
            }
        }
    }

    @ViewBuilder
    private func privacyBullet(_ text: String) -> some View {
        // v1.6.2: route through LocalizedStringKey so catalog can localize.
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .font(.callout)
            Text(LocalizedStringKey(text))
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Helpers

    private func mcpEndpointString() -> String? {
        guard let dashboard = vm.fleet.webDashboardURL() else { return nil }
        guard let comps = URLComponents(url: dashboard, resolvingAgainstBaseURL: false),
              let host = comps.host, let port = comps.port
        else { return nil }
        let token = comps.queryItems?.first(where: { $0.name == "t" })?.value ?? ""
        return "http://\(host):\(port)/splynek/v1/mcp/rpc?t=\(token)"
    }
}
