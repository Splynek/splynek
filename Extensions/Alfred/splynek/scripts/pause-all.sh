#!/usr/bin/env bash
#
# splypause — one-tap pause every running download.
# Output goes to Alfred's notification toast.
#
# Sprint 7 PRO-PLUS-IPHONE (2026-05-10).

set -euo pipefail

source "$(dirname "$0")/env.sh"

response=$(curl -fsS -X POST \
    "${SPLYNEK_BASE}/splynek/v1/api/pause-all?t=${SPLYNEK_TOKEN}" 2>&1) || {
    echo "Splynek pause failed: $response" >&2
    exit 1
}

echo "Splynek: paused all downloads."
