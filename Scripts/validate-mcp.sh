#!/usr/bin/env bash
# v1.6.1: end-to-end smoke test for the local MCP server.
#
# Reads the fleet descriptor (port + token) Splynek persists at
# ~/Library/Application Support/Splynek/fleet.json, then exercises the
# four MCP code paths a real client would hit:
#
#   1. initialize        — server says hello
#   2. tools/list        — all 8 tools enumerate
#   3. tools/call        — a representative read-only call returns
#                          isError:false + a content payload
#   4. invalid call      — tools/call against a bogus name returns
#                          a JSON-RPC methodNotFound (-32601)
#
# Pre-flight checks:
#   - Splynek must be running.
#   - MCP must be ON (Settings → Agents tab → toggle).
#
# Exits 0 on full pass, non-zero otherwise.  Self-contained — no
# dependencies beyond curl + jq, both shipping with macOS.

set -euo pipefail

FLEET_JSON="$HOME/Library/Application Support/Splynek/fleet.json"

if [[ ! -f "$FLEET_JSON" ]]; then
    echo "✗ Fleet descriptor not found at $FLEET_JSON" >&2
    echo "  Splynek hasn't been launched yet, or has never bound a listener." >&2
    exit 1
fi

PORT="$(jq -r .port "$FLEET_JSON")"
TOKEN="$(jq -r .token "$FLEET_JSON")"

if [[ -z "$PORT" || "$PORT" == "null" || "$PORT" == "0" ]]; then
    echo "✗ Port from fleet.json is unusable: '$PORT'" >&2
    exit 1
fi

ENDPOINT="http://127.0.0.1:${PORT}/splynek/v1/mcp/rpc?t=${TOKEN}"

# Reachability: is anything listening on that port at all?
if ! curl -s -o /dev/null --max-time 2 "http://127.0.0.1:${PORT}/" --fail-with-body 2>/dev/null \
   && ! curl -s -o /dev/null --max-time 2 "http://127.0.0.1:${PORT}/" 2>/dev/null; then
    echo "✗ Nothing's responding on http://127.0.0.1:${PORT}/" >&2
    echo "  Is Splynek running?  (open build/Splynek.app)" >&2
    exit 1
fi

echo "→ Endpoint: $ENDPOINT"
echo

call() {
    local desc="$1" body="$2"
    echo "▸ $desc"
    local resp
    resp="$(curl -s --max-time 5 -X POST "$ENDPOINT" \
         -H 'Content-Type: application/json' \
         -d "$body")"
    if [[ -z "$resp" ]]; then
        echo "  ✗ empty response (server disabled? token wrong?)"
        return 1
    fi
    echo "$resp" | jq .
    echo
    printf '%s' "$resp"
}

# ── Test 1 ──────────────────────────────────────────────────────────
init_resp="$(call "initialize" \
    '{"jsonrpc":"2.0","id":1,"method":"initialize"}')"
if echo "$init_resp" | jq -e '.result.protocolVersion' > /dev/null; then
    echo "  ✓ initialize handshake succeeded"
else
    if echo "$init_resp" | jq -e '.error.code == -32001' > /dev/null; then
        echo "  ✗ MCP server is OFF — toggle Settings → Agents → Allow MCP clients." >&2
        exit 2
    fi
    echo "  ✗ initialize did not return protocolVersion" >&2
    exit 3
fi
echo

# ── Test 2 ──────────────────────────────────────────────────────────
list_resp="$(call "tools/list" \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}')"
tool_count="$(echo "$list_resp" | jq -r '.result.tools | length')"
if [[ "$tool_count" == "8" ]]; then
    echo "  ✓ all 8 tools enumerated"
else
    echo "  ✗ expected 8 tools, got $tool_count" >&2
    exit 4
fi
echo

# ── Test 3 ──────────────────────────────────────────────────────────
call_resp="$(call "tools/call splynek_get_progress" '{
    "jsonrpc": "2.0", "id": 3, "method": "tools/call",
    "params": {"name": "splynek_get_progress", "arguments": {}}
}')"
if echo "$call_resp" | jq -e '.result.isError == false' > /dev/null; then
    echo "  ✓ tools/call returned isError:false with text content"
else
    echo "  ✗ tools/call did not return expected envelope" >&2
    exit 5
fi
echo

# ── Test 4 ──────────────────────────────────────────────────────────
bogus_resp="$(call "tools/call <bogus name>" '{
    "jsonrpc": "2.0", "id": 4, "method": "tools/call",
    "params": {"name": "splynek_does_not_exist", "arguments": {}}
}')"
if echo "$bogus_resp" | jq -e '.error.code == -32601' > /dev/null; then
    echo "  ✓ unknown tool name returns JSON-RPC methodNotFound (-32601)"
else
    echo "  ✗ expected -32601 for unknown tool, got something else" >&2
    exit 6
fi
echo

echo "✓ All four MCP smoke tests passed."
