#!/usr/bin/env bash
#
# splyjobs — list active downloads as Alfred items.
#
# Sprint 7 PRO-PLUS-IPHONE (2026-05-10).

set -euo pipefail

source "$(dirname "$0")/env.sh"

if ! command -v jq >/dev/null 2>&1; then
    cat <<EOF
{"items":[{"title":"jq is required","subtitle":"brew install jq","valid":false}]}
EOF
    exit 0
fi

response=$(curl -fsS \
    "${SPLYNEK_BASE}/splynek/v1/api/jobs?t=${SPLYNEK_TOKEN}" 2>&1) || {
    cat <<EOF
{"items":[{"title":"Couldn't reach Splynek","subtitle":"$response","valid":false}]}
EOF
    exit 0
}

# If empty array, emit a friendly placeholder.
count=$(echo "$response" | jq 'length')
if [[ "$count" == "0" ]]; then
    cat <<EOF
{"items":[{"title":"No active downloads","subtitle":"Use splyq <url> to queue one.","valid":false}]}
EOF
    exit 0
fi

echo "$response" | jq '
{
  items: map({
    title: (.filename // .url),
    subtitle: (
      if .total > 0 then
        "\((.downloaded * 100 / .total) | floor)% — \(.lifecycle)"
      else
        "\(.lifecycle)"
      end
    ),
    arg: .url,
    icon: { path: "icon.png" }
  })
}'
