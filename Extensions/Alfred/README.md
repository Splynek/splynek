# Splynek — Alfred workflow

Alfred keywords that talk to the Splynek macOS download manager.

## Install

1. Zip the `Splynek.alfredworkflow` folder (keep the folder structure —
   the file extension matters):
   ```sh
   cd Extensions/Alfred
   zip -r Splynek.alfredworkflow.zip Splynek.alfredworkflow
   mv Splynek.alfredworkflow.zip Splynek.alfredworkflow
   ```
2. Double-click `Splynek.alfredworkflow` in Finder. Alfred imports it.

Alternative: point Alfred's *Preferences → Workflows → +* at the
unzipped folder directly — Alfred accepts both.

## Keywords

| Keyword            | What |
| ------------------ | ---- |
| `dl <url>`         | Download the URL with Splynek |
| `dlq <url>`        | Append the URL to Splynek's queue |
| `dlstatus`         | Show a one-line summary of active downloads |

## How it works

`splynek.sh` reads
`~/Library/Application Support/Splynek/fleet.json` for the running
app's port + token, then curls the local HTTP API. Uses `osascript`
(JXA) to parse JSON — no jq / python runtime dep. Launch Splynek.app
once to create the descriptor.
