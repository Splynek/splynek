# Splynek for Raycast

Send URLs to Splynek, see active downloads, pause/resume, check your Sovereignty score — all from Raycast.

This is the **first external client** of Splynek's persistent API tokens (Sprint 4 of the PRO-PLUS-IPHONE strategy).

## Setup

1. **Mac side**: Splynek → Settings → API tokens. Mint a token labelled "Raycast" with **Read + write** scope.
2. **Raycast side**: install this extension. Open Raycast preferences → Splynek and enter:
   - **Mac host** — the IP or `.local` hostname of the Mac running Splynek (e.g. `192.168.1.42` or `mac-mini.local`).
   - **Port** — Splynek's HTTP port. Find it in the Mac's Settings → Web dashboard QR (default `55432`).
   - **API token** — paste the token you minted in step 1.

## Commands

| Command | What it does |
| --- | --- |
| **Submit URL to Splynek** | Form to queue or start a download immediately. |
| **Active Splynek Downloads** | Live list of in-flight downloads with phase + progress. Auto-refreshes every 3 s. |
| **Splynek Sovereignty Score** | Your Sovereignty score + top-5 concerns rendered as a Markdown detail. |
| **Pause All Splynek Downloads** | One-tap pause for everything in flight. No view; surfaces a toast. |
| **Resume All Splynek Downloads** | One-tap resume for everything paused. |

## Privacy posture

The extension talks **only** to your Mac on your LAN. No telemetry, no third-party endpoint, no cloud relay. The API token is stored in Raycast's encrypted preferences (per Raycast's standard preference handling).

If you mint a **Read-only** token instead of Read+write:

- ✅ `Active Splynek Downloads` and `Splynek Sovereignty Score` work
- ❌ `Submit URL`, `Pause All`, `Resume All` will return 401 from the Mac

Pick the scope that matches the workflows you want.

## Development

```bash
cd Extensions/Raycast/splynek
npm install
npm run dev   # opens Raycast in develop mode
```

## License

MIT — same as Splynek.
