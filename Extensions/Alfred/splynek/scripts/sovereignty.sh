#!/usr/bin/env bash
#
# splysov — Sovereignty score + top concerns as Alfred items.
# Emits the JSON-list format Alfred Script Filters expect.
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
    "${SPLYNEK_BASE}/splynek/v1/api/sovereignty/summary?t=${SPLYNEK_TOKEN}" 2>&1) || {
    cat <<EOF
{"items":[{"title":"Couldn't reach Splynek","subtitle":"$response","valid":false}]}
EOF
    exit 0
}

# Build Alfred script-filter JSON.  Header item shows the score;
# top-concerns items show one app per row.
echo "$response" | jq '
{
  items: ([
    {
      title: ("Sovereignty score: \(.score) / 100"),
      subtitle: ("\(.appsWithAlternatives) of \(.totalApps) installed apps have an EU/OSS alternative."),
      arg: "https://splynek.app/sovereignty",
      icon: { path: "icon.png" }
    }
  ] + (.topConcerns | map({
      title: .displayName,
      subtitle: (if .firstAlternative then "→ \(.firstAlternative)" else "no alternative listed yet" end),
      arg: ("https://duckduckgo.com/?q=\(.displayName | @uri)+alternatives"),
      icon: { path: "icon.png" }
  })))
}'
