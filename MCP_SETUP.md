# Splynek MCP server — setup

**Splynek 1.6+ exposes its core capabilities as an MCP (Model Context Protocol) server.** This means you can drive Splynek from Claude Desktop, Claude.ai, ChatGPT-with-MCP, or any custom agent that speaks MCP — conversations like *"Download these five papers, run a sovereignty check, and summarize what I'm installing"* become one-shot prompts.

## Status

**Experimental.** Transport: JSON-RPC 2.0 over HTTP POST (no SSE). Tool invocation works in every tested MCP client; server-initiated notifications + streaming responses land in v1.7.

## Enabling the server

1. Open Splynek.
2. Go to **Settings → MCP server**.
3. Toggle **Allow MCP clients to call Splynek tools** ON.
4. Copy the endpoint URL shown (it includes the auth token).

The server is **off by default** — the toggle is deliberate.

## Endpoint shape

```
POST http://<host>:<port>/splynek/v1/mcp/rpc?t=<auth-token>
Content-Type: application/json
```

`<host>` is `127.0.0.1` if you have **Settings → Security → Loopback only** turned on (the default in the free tier), or your Mac's LAN IP if you're on Splynek Pro with LAN dashboard enabled.

`<port>` and `<auth-token>` are surfaced in the Settings card. They persist across launches; if you regenerate the token (Settings → Security → Regenerate token), the MCP endpoint URL changes too.

## Available tools

| Name | Description |
|------|-------------|
| `splynek_get_progress` | List currently-active downloads with progress + throughput. |
| `splynek_list_history` | List recent completed downloads (max 50). |
| `splynek_lookup_sovereignty` | Look up an app in the Sovereignty catalog by bundle ID or display name. |
| `splynek_lookup_trust` | Look up an app's Trust score (0–100) with primary-source-cited concerns. |
| `splynek_run_sovereignty_scan` | Enumerate installed apps and count Sovereignty matches. |
| `splynek_download_url` | Start a multi-interface download. Optional SHA-256 verification. |
| `splynek_queue_url` | Append a URL to the download queue without starting it. |
| `splynek_cancel_all` | Cancel every active and queued download. |

All tools return human-readable text. Structured payloads are formatted within the text so an agent can re-parse if needed.

## Client setup

### Claude Desktop (current MCP HTTP transport)

Claude Desktop's MCP support is stdio-only as of writing. To bridge to Splynek's HTTP endpoint, use a small launcher like `mcp-proxy` or write a 30-line stdio→HTTP shim. Once Claude Desktop ships HTTP transport, you'll be able to add Splynek directly:

```json
{
  "mcpServers": {
    "splynek": {
      "type": "http",
      "url": "http://127.0.0.1:<port>/splynek/v1/mcp/rpc?t=<token>"
    }
  }
}
```

### claude.ai (web)

Add a remote MCP server in your workspace settings, paste the endpoint URL. Claude.ai handles HTTP transport natively.

### Custom agents

Any client that speaks JSON-RPC 2.0 can talk to the endpoint. Minimum required methods:

- `initialize` — handshake
- `tools/list` — get available tools
- `tools/call` — invoke a tool

Example call (`curl`):

```
curl -X POST 'http://127.0.0.1:<port>/splynek/v1/mcp/rpc?t=<token>' \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

Example tool invocation:

```
curl -X POST 'http://127.0.0.1:<port>/splynek/v1/mcp/rpc?t=<token>' \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0", "id": 2, "method": "tools/call",
    "params": {
      "name": "splynek_lookup_sovereignty",
      "arguments": { "query": "Spotify" }
    }
  }'
```

## Privacy + security

- The MCP server runs on the **same loopback-or-LAN listener** as Splynek's web dashboard. No new sockets, no new entitlements.
- All tool calls are logged via `os.Logger` under category `system` (subsystem `app.splynek`). View with: `log stream --predicate 'subsystem == "app.splynek"' --info`.
- Mutating tools (`download_url`, `queue_url`, `cancel_all`) route through the same VM ingest contract that drag-drop and the browser extension use. URL scheme guards (HTTP/HTTPS/magnet only), size confirmations, host caps — all of these still fire.
- The `splynek_run_sovereignty_scan` tool returns app metadata that's already visible in `/Applications`. Nothing gets revealed that an `ls` couldn't show.
- Sovereignty + Trust catalogs ship in the app — they don't query a network service. Lookups don't leak the user's installed-app list anywhere.

## Troubleshooting

- **503 Service Unavailable** — MCP server is disabled. Toggle in Settings → MCP server.
- **401 Unauthorized** — token in URL doesn't match. Copy the endpoint URL from Settings again.
- **Empty body / connection refused** — Splynek isn't running, or its fleet listener hasn't bound a port yet (rare; relaunch).
- **Tool returns `isError: true`** — the tool ran but rejected your input. The text content explains why (e.g. `"URL must be http(s) or magnet:"`).
