import Foundation

/// v1.6: MCP tool registry — the actual tools an MCP client can call.
///
/// Each tool has:
///   - `name`: stable wire identifier the client uses in tools/call
///   - `description`: shown in tool pickers; should read like a docstring
///   - `descriptor`: the full JSON Schema MCP expects in tools/list
///   - `handler`: async function returning a human-readable text result
///
/// Tool design principles:
///   - **Idempotent reads**, **explicit writes** — read-only tools
///     (lookup, list, scan) come first; mutating tools (download,
///     queue, cancel) are clearly named with action verbs.
///   - **Text output** — every tool returns a single string the LLM
///     can summarise, quote, or chain.  Structured payloads go in
///     pretty-printed JSON within the text so an agent can reparse
///     if it needs structured access.
///   - **Bounded results** — `list_history` caps at 50, scan results
///     compress to summary counts.  We don't blow up the LLM context
///     with 1k-row dumps.
///   - **Names start with `splynek_`** so when an MCP client merges
///     tools from multiple servers into one prompt, ours don't
///     collide with downloads, search, etc. that sibling servers
///     might offer.
enum MCPToolRegistry {

    static let allTools: [MCPTool] = [
        downloadURL,
        queueURL,
        getProgress,
        cancelAll,
        listHistory,
        lookupSovereignty,
        lookupTrust,
        runSovereigntyScan,
    ]

    // MARK: - Read-only tools

    static let getProgress = MCPTool(
        name: "splynek_get_progress",
        description: """
            List currently-active Splynek download jobs with their progress \
            (downloaded / total bytes), throughput in bytes per second, and \
            lifecycle state (running, paused, queued, completed, failed). \
            Returns an empty list if nothing is in flight.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ]),
        handler: { _, bridge in
            let jobs = await bridge.getProgress()
            if jobs.isEmpty { return "No active downloads." }
            var lines = ["\(jobs.count) active download(s):", ""]
            for j in jobs {
                let pct = j.total > 0
                    ? String(format: "%.1f%%", Double(j.downloaded) / Double(j.total) * 100)
                    : "—"
                let rate = ByteCountFormatter.string(
                    fromByteCount: Int64(j.throughputBps),
                    countStyle: .binary
                ) + "/s"
                let total = ByteCountFormatter.string(
                    fromByteCount: j.total, countStyle: .binary
                )
                lines.append("• \(j.filename) — \(j.lifecycle), \(pct) of \(total), \(rate)")
            }
            return lines.joined(separator: "\n")
        }
    )

    static let listHistory = MCPTool(
        name: "splynek_list_history",
        description: """
            List recently completed Splynek downloads.  Each item includes \
            the original URL, filename, byte count, finish time, and \
            on-disk path.  `limit` defaults to 10 and is capped at 50.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "minimum": .int(1),
                    "maximum": .int(50),
                    "description": .string("How many recent downloads to return (max 50)."),
                ]),
            ]),
            "required": .array([]),
        ]),
        handler: { args, bridge in
            let limit = min(50, max(1, args.int("limit") ?? 10))
            let entries = await bridge.listHistory(limit)
            if entries.isEmpty { return "No download history." }
            var lines = ["\(entries.count) recent download(s):", ""]
            let f = ISO8601DateFormatter()
            for e in entries {
                let size = ByteCountFormatter.string(
                    fromByteCount: e.totalBytes, countStyle: .binary
                )
                lines.append("• \(e.filename) (\(size)) — finished \(f.string(from: e.finishedAt))")
                lines.append("  URL: \(e.url)")
                lines.append("  Path: \(e.outputPath)")
            }
            return lines.joined(separator: "\n")
        }
    )

    static let lookupSovereignty = MCPTool(
        name: "splynek_lookup_sovereignty",
        description: """
            Look up an installed app in the Splynek Sovereignty catalog. \
            Returns the app's target-origin (where it's controlled from: \
            EU, US, OSS, China, Russia, Other) plus a list of \
            EU-or-OSS-controlled alternatives the user could switch to. \
            `query` accepts either a bundle identifier (e.g. \
            `com.spotify.client`) or a display name (e.g. `Spotify`).
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("Bundle ID or display name."),
                ]),
            ]),
            "required": .array([.string("query")]),
        ]),
        handler: { args, bridge in
            guard let query = args.string("query")?.trimmingCharacters(in: .whitespaces),
                  !query.isEmpty
            else { throw MCPToolError("Missing required parameter `query`.") }
            guard let hit = await bridge.lookupSovereignty(query) else {
                return "No Sovereignty catalog entry for `\(query)`."
            }
            var lines = [
                "Sovereignty: \(hit.displayName) (\(hit.bundleID))",
                "Controlled from: \(hit.targetOrigin)",
                "",
                "Alternatives (\(hit.alternatives.count)):",
            ]
            for alt in hit.alternatives {
                lines.append("• \(alt.name) [\(alt.origin)] — \(alt.note)")
                lines.append("  Homepage: \(alt.homepage)")
                if let dl = alt.downloadURL {
                    lines.append("  Download: \(dl)")
                }
            }
            return lines.joined(separator: "\n")
        }
    )

    static let lookupTrust = MCPTool(
        name: "splynek_lookup_trust",
        description: """
            Look up an app in the Splynek Trust catalog — public-record \
            audit of privacy, security, trust, and business-model \
            concerns.  Returns the 0–100 score, severity level, and a \
            list of cited concerns (each with a primary-source URL: \
            App Store privacy labels, EU DPA / FTC enforcement, NVD \
            CVEs, HIBP breaches, vendor advisories — never tech press).
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("Bundle ID or display name."),
                ]),
            ]),
            "required": .array([.string("query")]),
        ]),
        handler: { args, bridge in
            guard let query = args.string("query")?.trimmingCharacters(in: .whitespaces),
                  !query.isEmpty
            else { throw MCPToolError("Missing required parameter `query`.") }
            guard let hit = await bridge.lookupTrust(query) else {
                return "No Trust catalog entry for `\(query)`."
            }
            var lines = [
                "Trust: \(hit.displayName) (\(hit.bundleID))",
                "Score: \(hit.score)/100 — \(hit.level)",
                "Last reviewed: \(hit.lastReviewed)",
                "",
                "Concerns (\(hit.concernCount)):",
            ]
            for c in hit.concerns {
                lines.append("• [\(c.severity.uppercased()), \(c.axis)] \(c.summary)")
                lines.append("  Source: \(c.evidenceURL)")
            }
            return lines.joined(separator: "\n")
        }
    )

    static let runSovereigntyScan = MCPTool(
        name: "splynek_run_sovereignty_scan",
        description: """
            Scan the user's installed apps and return a summary count \
            of how many were matched against the Sovereignty catalog. \
            Use this before `splynek_lookup_sovereignty` to understand \
            the user's overall exposure.  All scanning is on-device; \
            no app list leaves the user's machine.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ]),
        handler: { _, bridge in
            let s = await bridge.runSovereigntyScan()
            return """
                Sovereignty scan complete.
                Apps scanned: \(s.appsScanned)
                Entries matched: \(s.entriesMatched)
                """
        }
    )

    // MARK: - Mutating tools

    static let downloadURL = MCPTool(
        name: "splynek_download_url",
        description: """
            Start an immediate download via Splynek's multi-interface \
            HTTP aggregator.  The URL must be HTTP(S) or a `magnet:` \
            BitTorrent magnet link.  Optional `sha256` enables \
            integrity verification — when present, the download is \
            rejected on hash mismatch.  Output goes to the user's \
            configured Splynek output directory.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "url": .object([
                    "type": .string("string"),
                    "description": .string("HTTP(S) or magnet: URL."),
                ]),
                "sha256": .object([
                    "type": .string("string"),
                    "description": .string("Optional 64-character hex SHA-256."),
                ]),
            ]),
            "required": .array([.string("url")]),
        ]),
        handler: { args, bridge in
            guard let url = args.string("url"), !url.isEmpty
            else { throw MCPToolError("Missing required parameter `url`.") }
            let sha = args.string("sha256")
            do {
                let id = try await bridge.startDownload(url, sha)
                return "Download started — job ID \(id)."
            } catch let e as MCPBridgeError {
                throw MCPToolError("Download rejected: \(e.userMessage)")
            } catch {
                throw MCPToolError("Download rejected: \(String(describing: error))")
            }
        }
    )

    static let queueURL = MCPTool(
        name: "splynek_queue_url",
        description: """
            Append a URL to Splynek's download queue (instead of \
            starting it immediately).  Useful when the user wants to \
            batch up several URLs and let Splynek process them \
            sequentially.  Same URL + sha256 schema as \
            `splynek_download_url`.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "url":    .object(["type": .string("string")]),
                "sha256": .object(["type": .string("string")]),
            ]),
            "required": .array([.string("url")]),
        ]),
        handler: { args, bridge in
            guard let url = args.string("url"), !url.isEmpty
            else { throw MCPToolError("Missing required parameter `url`.") }
            let sha = args.string("sha256")
            do {
                let id = try await bridge.queueDownload(url, sha)
                return "Queued — position \(id)."
            } catch let e as MCPBridgeError {
                throw MCPToolError("Queue rejected: \(e.userMessage)")
            } catch {
                throw MCPToolError("Queue rejected: \(String(describing: error))")
            }
        }
    )

    static let cancelAll = MCPTool(
        name: "splynek_cancel_all",
        description: """
            Cancel every active and queued Splynek download.  This \
            does not delete already-downloaded data; partial files \
            are preserved on disk.  Use cautiously — there's no \
            undo.
            """,
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ]),
        handler: { _, bridge in
            await bridge.cancelAll()
            return "All Splynek downloads cancelled."
        }
    )
}

// MARK: - Tool descriptor

/// MCP tool definition.  `descriptor` is the shape the MCP spec
/// expects in `tools/list` responses.
struct MCPTool {
    let name: String
    let description: String
    let inputSchema: AnyJSON
    let handler: @Sendable (RPCParams, MCPServer.Bridge) async throws -> String

    var descriptor: AnyJSON {
        .object([
            "name":        .string(name),
            "description": .string(description),
            "inputSchema": inputSchema,
        ])
    }
}
