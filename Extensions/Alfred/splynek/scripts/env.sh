# Source-only helper.  Resolves Splynek host/port/token from
# Alfred's user-config env vars (set on import + editable in
# Workflow Configuration).  Falls back to SPLYNEK_* env vars
# so the same scripts work standalone via bash scripts/foo.sh.
#
# Sprint 7 PRO-PLUS-IPHONE (2026-05-10).

# Alfred workflow user-config exposes these as env vars
# prefixed with `splynek_` (Workflow Configuration → Variables).
SPLYNEK_HOST="${splynek_host:-${SPLYNEK_HOST:-}}"
SPLYNEK_PORT="${splynek_port:-${SPLYNEK_PORT:-55432}}"
SPLYNEK_TOKEN="${splynek_token:-${SPLYNEK_TOKEN:-}}"

if [[ -z "$SPLYNEK_HOST" ]]; then
    echo "Splynek: SPLYNEK_HOST not set." >&2
    exit 65
fi
if [[ -z "$SPLYNEK_TOKEN" ]]; then
    echo "Splynek: SPLYNEK_TOKEN not set." >&2
    exit 65
fi

SPLYNEK_BASE="http://${SPLYNEK_HOST}:${SPLYNEK_PORT}"
