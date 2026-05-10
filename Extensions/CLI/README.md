# Splynek CLI cookbook

Talk to Splynek from any shell using curl + jq.  Same API surface
the Raycast extension uses, just minus the GUI — for shell pipelines,
cron jobs, BetterTouchTool gestures, Hammerspoon configs, ssh hops,
or whatever else writes a `Bash` step.

> All requests go to your **own Mac** on your **own LAN**.  Splynek
> never sees them.  Set up an API token Mac-side first
> (Settings → API tokens → Mint), then paste it into your shell's
> environment.

## Setup

```sh
# 1. Mint a token in Splynek's Settings → API tokens.
#    Read+write if you want to queue/pause; Read-only if you only
#    want to read jobs/sovereignty/trust.

# 2. Export config in your shell rc file:
export SPLYNEK_HOST="192.168.1.42"          # or "mac.local"
export SPLYNEK_PORT="55432"                  # find it in the Mac's
                                             # Web dashboard QR
export SPLYNEK_TOKEN="<paste from step 1>"
```

`bin/splynek` (in this directory) wraps the env-vars + provides
ergonomic subcommands.  Add it to your $PATH:

```sh
export PATH="$PWD/Extensions/CLI/bin:$PATH"
```

Then:

```sh
splynek queue https://example.com/large-file.iso
splynek jobs                            # list active downloads
splynek sovereignty                     # score + top concerns
splynek pause-all
splynek resume-all
splynek trust                           # average score + high-risk count
splynek history                         # recent finished
```

## Direct curl recipes (no wrapper)

Same calls, no script — paste-and-go.

### List active jobs

```sh
curl -s "http://${SPLYNEK_HOST}:${SPLYNEK_PORT}/splynek/v1/api/jobs?t=${SPLYNEK_TOKEN}" \
  | jq '.[] | {filename, lifecycle, percent: (.downloaded * 100 / .total | floor)}'
```

### Submit a URL to the queue

```sh
URL="https://example.com/file.dmg"
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"${URL}\"}" \
  "http://${SPLYNEK_HOST}:${SPLYNEK_PORT}/splynek/v1/api/queue?t=${SPLYNEK_TOKEN}"
```

Returns `202 Accepted` with no body on success; `401 Unauthorized` if
the token's invalid or the read-only token tried to write.

### Pause all running downloads

```sh
curl -s -X POST \
  "http://${SPLYNEK_HOST}:${SPLYNEK_PORT}/splynek/v1/api/pause-all?t=${SPLYNEK_TOKEN}"
```

### Sovereignty score

```sh
curl -s "http://${SPLYNEK_HOST}:${SPLYNEK_PORT}/splynek/v1/api/sovereignty/summary?t=${SPLYNEK_TOKEN}" \
  | jq '{score, totalApps, appsWithAlternatives, topThree: .topConcerns[:3] | map(.displayName)}'
```

### Trust summary

```sh
curl -s "http://${SPLYNEK_HOST}:${SPLYNEK_PORT}/splynek/v1/api/trust/summary?t=${SPLYNEK_TOKEN}" \
  | jq '{averageScore, highRiskCount, total: .totalAppsWithProfile}'
```

### Trust Watcher (Pro-only on Mac side)

```sh
curl -s "http://${SPLYNEK_HOST}:${SPLYNEK_PORT}/splynek/v1/api/trust-watcher/summary?t=${SPLYNEK_TOKEN}" \
  | jq '{watching: .watchingCount, pending: .pendingAlertCount}'
```

Returns `404` on free-tier Macs — Trust Watcher is gated on the Pro
license.

### Recent download history

```sh
curl -s "http://${SPLYNEK_HOST}:${SPLYNEK_PORT}/splynek/v1/api/history/summary?t=${SPLYNEK_TOKEN}" \
  | jq '.recent[:5] | map({filename, bytes, finishedAt})'
```

## Cookbook

### Queue every link from a markdown file

```sh
grep -oE 'https?://[^[:space:])]+' my-links.md | while read url; do
  splynek queue "$url"
done
```

### Watch the queue from another machine over ssh

```sh
ssh mac.local 'while true; do
  curl -s "http://localhost:55432/splynek/v1/api/jobs?t=$SPLYNEK_TOKEN" \
    | jq -r ".[] | \"\(.filename) \(.lifecycle)\""
  sleep 3
done'
```

### Pause Splynek when entering a meeting (BetterTouchTool / Hammerspoon)

Map your "DND on" key to:

```sh
splynek pause-all
```

…and "DND off" to `splynek resume-all`.

### Daily Sovereignty status email (cron)

```sh
0 9 * * * /usr/bin/env zsh -lc '
  status=$(splynek sovereignty)
  echo "$status" | mail -s "Splynek daily" me@example.com
'
```

### Geo-trigger via a Shortcut on iOS

The iPhone Companion's geo-fence already pauses/resumes downloads when
you cross the home boundary (Sprint 2).  But if you'd rather drive it
from a Shortcut:

```
Shortcut: "Leaving home"
  → Get Contents of URL
    URL: http://mac.local:55432/splynek/v1/api/pause-all?t=YOUR_TOKEN
    Method: POST
```

## Privacy posture

- Every request hits **your Mac** on your **LAN** (or VPN, if your
  Mac listener's reachable that way).
- The token is sent as a query param.  In strict environments,
  consider scoping a Read-only token for read-only scripts.
- No telemetry, no third-party server.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Connection refused` | Splynek not running | Open the Mac app |
| `401 Unauthorized` on POST | Token is read-only | Mint a read+write token |
| `401 Unauthorized` on every call | Token revoked or wrong | Re-paste from Mac |
| `404` on `/api/trust-watcher/summary` | Mac is free-tier | Pro feature only |
| `Couldn't find host` | Mac.local mDNS broken | Use IP address instead |

## License

MIT — same as Splynek.
