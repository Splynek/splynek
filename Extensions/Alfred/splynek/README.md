# Splynek for Alfred

Three Alfred keyword workflows that hit Splynek's API-token endpoints — same backend the Raycast extension and the CLI cookbook use.

> **Requires Alfred Powerpack** (Alfred's workflow feature is a paid add-on).  If you don't have Powerpack, use the **CLI cookbook** at `Extensions/CLI/` instead — same recipes, plain bash.

## Setup

1. **Mac side**: Splynek → Settings → API tokens → Mint a token labelled "Alfred" with the scope you want:
   - **Read + write** if you want `splyqueue` (URL submit) + `splypause` / `splyresume` to work.
   - **Read-only** for the read-only commands; mutating commands return 401.
2. **Alfred side**: open Alfred Preferences → Workflows → press the `+` button at the bottom → **Import Workflow…** → select this directory's `info.plist`. Alfred will prompt for the workflow's user-config:
   - **Mac host** — `192.168.1.42` or `mac.local`
   - **Mac port** — `55432` (find in Splynek's Web dashboard QR)
   - **API token** — paste from step 1
3. The workflow's bash scripts shell out to `bash` and call Splynek over `curl`.  No external dependencies beyond what ships with macOS (curl + jq).  Install jq if missing: `brew install jq`.

## Keywords

| Keyword | What it does |
| --- | --- |
| `splyq <url>` | Queue a URL on the paired Mac. Optional Cmd-modifier on Enter starts immediately instead of queueing. |
| `splysov` | Show Sovereignty score + top concerns inline as Alfred items. |
| `splyjobs` | List active downloads with phase + progress. |
| `splypause` | One-tap pause-all (no view; toast). |
| `splyresume` | One-tap resume-all (no view; toast). |

## Layout on disk

```
Extensions/Alfred/splynek/
├── README.md              this file
├── info.plist             Alfred workflow definition (import this)
├── icon.png               64×64 PNG; ships as the workflow icon
└── scripts/
    ├── env.sh             helper: builds curl URL from Alfred env vars
    ├── queue-url.sh       splyq → POST /api/queue
    ├── sovereignty.sh     splysov → GET /api/sovereignty/summary
    ├── jobs.sh            splyjobs → GET /api/jobs
    ├── pause-all.sh       splypause → POST /api/pause-all
    └── resume-all.sh      splyresume → POST /api/resume-all
```

The workflow's `info.plist` contains UUID-based connections that Alfred generates when you import; the scripts in `scripts/` are the source-of-truth and are exec'd by Alfred's Run-Script objects.

## Why three workflow ecosystems?

Splynek's API token surface is intentionally agnostic — same `?t=<token>` convention works from any HTTP client.  We ship workflow scaffolds for three power-user communities:

- **Raycast** (`Extensions/Raycast/splynek/`) — most polished GUI, best for daily-driver workflows.
- **CLI cookbook** (`Extensions/CLI/`) — headless / scriptable, for cron + ssh + Hammerspoon + BetterTouchTool.
- **Alfred** (this directory) — for users on Alfred Powerpack who don't want to switch to Raycast.

Each is independent — pick whichever you already use.

## Privacy posture

Same as the rest: the workflow talks **only** to your Mac on your LAN.  No telemetry, no third-party endpoint.  Alfred's user-config encrypts the API token at rest in the workflow preferences plist.

## License

MIT — same as Splynek.

---

## Maintainer note

This workflow is **scaffold-only as committed**.  The maintainer must:

1. Open Alfred → Preferences → Workflows → import this directory.
2. Alfred generates a fresh workflow `info.plist` with proper UUIDs for inter-object connections.
3. Wire each Run-Script object to the matching script in `scripts/`.
4. Configure user-defaults for host / port / API token.
5. Export back to this directory + commit the populated `info.plist`.

Until step 1-5: the bash scripts in `scripts/` work standalone via `bash scripts/<name>.sh ARGUMENT`, but Alfred can't drive them yet.
