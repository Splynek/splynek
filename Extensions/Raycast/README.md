# Splynek — Raycast extension

Control the [Splynek](https://splynek.app) macOS download manager from
Raycast. Paste a URL, hit ⌘⏎, and watch it land in Splynek.

## Commands

| Command                   | Mode      | What it does |
| ------------------------- | --------- | ------------ |
| `Download URL with Splynek` | no-view | Hand the clipboard URL to Splynek and start downloading. |
| `Queue URL in Splynek`    | no-view   | Append the clipboard URL to Splynek's persistent queue. |
| `Splynek Downloads`       | view      | Live-polling list of active downloads with a cancel action. |

## How it works

The extension reads
`~/Library/Application Support/Splynek/fleet.json` to discover
Splynek.app's local HTTP port + submit token, then POSTs to
`http://127.0.0.1:<port>/splynek/v1/api/*`. No outbound traffic, no
credentials stored. Launch Splynek.app once to generate the
descriptor; the extension picks it up automatically.

## Install (local development mode)

1. Clone or drop this folder somewhere persistent.
2. `npm install` inside it.
3. In Raycast: **Store → Import Extension → this folder**.
4. Run any Splynek command.

To publish to the Raycast Store, submit the `package.json` + `src/`
through `ray publish`. The extension is self-contained — no API keys,
no env config.

## Troubleshooting

- *"Splynek isn't running"*: launch Splynek.app; the descriptor is
  written on first successful HTTP-listener bind.
- *"Fleet token rejected"*: the app regenerates its token on first
  launch after install; re-open Splynek's About view to refresh, then
  retry.
