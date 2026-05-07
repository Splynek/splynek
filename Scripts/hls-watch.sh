#!/bin/bash
# hls-watch.sh — live monitor for the Splynek HLS proxy.
#
# Polls /splynek/v1/hls/stats once per second and prints a one-line
# rolling readout: cache hit-rate, segments served, throughput
# attribution (cache vs origin), active sessions.  Use this while
# opening a real Vimeo / Twitch / YouTube URL with the Splynek
# Accelerator browser extension active to verify the pre-buffer
# is working as intended.
#
# Usage:
#   ./Scripts/hls-watch.sh                     # auto-detects port + token
#   ./Scripts/hls-watch.sh --reset             # zero counters first
#   ./Scripts/hls-watch.sh --host 127.0.0.1    # override target
#   ./Scripts/hls-watch.sh --interval 0.5      # poll twice per sec
#   ./Scripts/hls-watch.sh --help              # this message
#
# What "good" looks like:
#   - cacheHitRate ≥ 0.85 once playback is steady
#   - prefetchInsertions climbing in lockstep with segmentRequests
#   - bytesFromCache > bytesFromOrigin on a steady-state video
#
# Strategy memo demo:
#   Open Vimeo on weak Wi-Fi + 5G tether, run hls-watch.sh, observe
#   cache hit-rate flip from ~0% (no extension) to >90% (extension
#   on, BondedFetcher pulling segments via parallel byte ranges
#   across both NICs).

set -u
INTERVAL=1
RESET=0
HOST="127.0.0.1"
TOKEN=""
PORT=""

# Auto-detect from fleet.json (written by FleetCoordinator on start).
FLEET_JSON="${HOME}/Library/Application Support/Splynek/fleet.json"
if [[ -f "$FLEET_JSON" ]]; then
    PORT=$(/usr/bin/python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('port',''))" "$FLEET_JSON" 2>/dev/null || echo "")
    TOKEN=$(/usr/bin/python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('token',''))" "$FLEET_JSON" 2>/dev/null || echo "")
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --reset)    RESET=1; shift ;;
        --host)     HOST="$2"; shift 2 ;;
        --port)     PORT="$2"; shift 2 ;;
        --token)    TOKEN="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,30p' "$0" | sed 's/^# *//; s/^#$//'
            exit 0 ;;
        *)
            echo "warn: unknown flag '$1'" >&2; shift ;;
    esac
done

if [[ -z "$PORT" ]]; then
    echo "error: couldn't auto-detect port from $FLEET_JSON" >&2
    echo "       launch Splynek first, then re-run, or pass --port + --token" >&2
    exit 1
fi
if [[ -z "$TOKEN" ]]; then
    echo "error: couldn't auto-detect token from $FLEET_JSON" >&2
    echo "       launch Splynek first, then re-run, or pass --token" >&2
    exit 1
fi

URL="http://${HOST}:${PORT}/splynek/v1/hls/stats?t=${TOKEN}"
if (( RESET )); then
    echo "Resetting HLS proxy counters…"
    curl -s "${URL}&reset=1" >/dev/null || {
        echo "error: couldn't reach Splynek at ${HOST}:${PORT}" >&2
        exit 1
    }
fi

echo "Watching HLS proxy at ${HOST}:${PORT} (Ctrl-C to stop)."
echo
printf "%-19s | %-8s | %-9s | %-9s | %-12s | %-12s | %s\n" \
    "Time" "Sessions" "Segments" "Cache hit" "From cache" "From origin" "Hit rate"
echo "--------------------------------------------------------------------------------------------------"

human() {
    # bytes → human-readable (MiB / GiB)
    local v=$1
    local i=0
    local units=("B" "KiB" "MiB" "GiB" "TiB")
    while (( $(echo "$v >= 1024" | bc -l) )) && (( i < 4 )); do
        v=$(echo "scale=1; $v / 1024" | bc -l)
        i=$((i+1))
    done
    printf "%.1f %s" "$v" "${units[$i]}"
}

while true; do
    json=$(curl -s -m 3 "$URL" 2>/dev/null)
    if [[ -z "$json" ]]; then
        printf "%-19s | (no response)\n" "$(date '+%H:%M:%S')"
        sleep "$INTERVAL"
        continue
    fi
    sa=$(echo "$json"   | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin).get('sessionsActive',0))")
    sr=$(echo "$json"   | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin).get('segmentRequests',0))")
    sh=$(echo "$json"   | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin).get('segmentCacheHits',0))")
    bc=$(echo "$json"   | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin).get('bytesFromCache',0))")
    bo=$(echo "$json"   | /usr/bin/python3 -c "import json,sys; print(json.load(sys.stdin).get('bytesFromOrigin',0))")
    hr=$(echo "$json"   | /usr/bin/python3 -c "import json,sys; r=json.load(sys.stdin); h=r.get('segmentCacheHits',0); m=r.get('segmentCacheMisses',0); print(f\"{(h/(h+m)) if (h+m)>0 else 0:.2%}\")")
    printf "%-19s | %-8d | %-9d | %-9d | %-12s | %-12s | %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$sa" "$sr" "$sh" \
        "$(human $bc)" "$(human $bo)" "$hr"
    sleep "$INTERVAL"
done
