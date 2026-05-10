#!/usr/bin/env bash
#
# splyq <url> — queue a URL on the paired Mac.
# Alfred passes the user's typed argument as $1.
#
# Sprint 7 PRO-PLUS-IPHONE (2026-05-10).

set -euo pipefail

source "$(dirname "$0")/env.sh"

url="${1:-}"
if [[ -z "$url" ]]; then
    echo "Usage: splyq <url>" >&2
    exit 64
fi

# Alfred's modifier-key state is in alfred_modifier (cmd, alt, etc.)
# when set; defaults to "queue" — Cmd-Enter starts immediately.
action="queue"
if [[ "${alfred_modifier:-}" == "cmd" ]]; then
    action="download"
fi

response=$(curl -fsS -X POST \
    -H "Content-Type: application/json" \
    -d "{\"url\":\"${url}\"}" \
    "${SPLYNEK_BASE}/splynek/v1/api/${action}?t=${SPLYNEK_TOKEN}" 2>&1) || {
    echo "Splynek: $response" >&2
    exit 1
}

# Alfred reads stdout for the toast text.
case "$action" in
    queue)    echo "Queued on Splynek: ${url}" ;;
    download) echo "Started on Splynek: ${url}" ;;
esac
