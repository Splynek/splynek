#!/bin/bash
# Splynek Alfred glue. Called by the workflow's script actions with
# ($action, $url). Discovers the running app's port + token through
# the shared fleet descriptor and hits the local HTTP API.

set -eu

DESCRIPTOR="$HOME/Library/Application Support/Splynek/fleet.json"

if [[ ! -f "$DESCRIPTOR" ]]; then
    echo "Splynek isn't running — launch Splynek.app first."
    exit 1
fi

# Parse fleet.json with osascript/JXA so we don't depend on jq / python
# / anything that might not be on a user's $PATH.
eval "$(/usr/bin/osascript -l JavaScript -e "
const raw = ObjC.stringWithContentsOfFile_encoding_error_(
    '$DESCRIPTOR', \$.NSUTF8StringEncoding, null
).js;
const d = JSON.parse(raw);
'PORT=' + d.port + '\nTOKEN=' + d.token
")"

ACTION="${1:-}"
URL="${2:-}"

case "$ACTION" in
    download|queue)
        if [[ -z "$URL" ]]; then
            echo "Usage: splynek.sh $ACTION <url>"
            exit 1
        fi
        BODY=$(/usr/bin/osascript -l JavaScript -e "JSON.stringify({ url: '$URL' })")
        if /usr/bin/curl -fsS --max-time 5 \
             -H "Content-Type: application/json" \
             -d "$BODY" \
             -o /dev/null \
             "http://127.0.0.1:${PORT}/splynek/v1/api/${ACTION}?t=${TOKEN}"; then
            echo "✓ Splynek: ${ACTION} ${URL}"
        else
            echo "✗ Splynek HTTP call failed"
            exit 2
        fi
        ;;
    status)
        # Single fetch + JXA summary. JXA can parse JSON with JSON.parse.
        RESP=$(/usr/bin/curl -fsS --max-time 5 \
            "http://127.0.0.1:${PORT}/splynek/v1/api/jobs")
        SUMMARY=$(/usr/bin/osascript -l JavaScript -e "
            const jobs = JSON.parse($(printf '%s' "$RESP" | /usr/bin/python3 -c 'import sys,json;print(json.dumps(sys.stdin.read()))'));
            if (!jobs.length) {
                'No active downloads.'
            } else {
                const names = jobs.slice(0, 5).map(j => j.filename).join(', ');
                jobs.length + ' active: ' + names
            }
        ")
        echo "$SUMMARY"
        ;;
    *)
        echo "Unknown action: $ACTION"
        exit 1
        ;;
esac
