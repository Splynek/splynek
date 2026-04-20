# Privacy Policy

**Splynek v0.30**
**Last updated: 2026-04-17**

Short version: **Splynek doesn't collect anything about you.**
Nothing is sent off your Mac. Full stop.

## What Splynek does NOT do

- No analytics. No Mixpanel, Segment, Amplitude, Posthog, nothing.
- No crash reporter that phones home. Crashes are handled by
  macOS's system-wide reporter, which you separately opt in or
  out of in System Settings → Privacy & Security → Analytics.
- No account system. There is no server. There is no login. There
  is no password.
- No "device ID that follows you" — Splynek does generate a random
  UUID for LAN fleet identification, but it stays on your Mac and
  is announced only to other Splyneks on your Wi-Fi / Ethernet.
- No silent updates. If an update feed URL is configured, Splynek
  polls it for a JSON file advertising the latest version — which
  server you configured, how often, and whether to configure it
  at all is entirely up to you.
- No cookies. No fingerprinting. No cross-site tracking.

## What Splynek stores locally on your Mac

Under `~/Library/Application Support/Splynek/`:

| File | What it is |
| --- | --- |
| `history.json` | The most recent ≤500 completed downloads — URL, filename, bytes, timestamp, SHA-256 if known. |
| `queue.json`   | Persistent URL queue, including pending / completed entries until you clear them. |
| `session.json` | In-flight job snapshots so Splynek can restore downloads across a reboot. |
| `host-usage.json` | Per-host bytes-per-day tally. Used by the daily-cap feature you configure. |
| `cellular-budget.json` | Cumulative cellular bytes-per-day. Used by the cap feature. |
| `dht-routing.json` | BitTorrent DHT's good-node cache. Discarded on uninstall. |
| `fleet.json`   | Device name, UUID, port, submit token. Read by the CLI / Raycast / Alfred locally. |

Plus per-download `<output>.splynek` sidecars next to each file
in progress, which are removed on successful completion.

Under `UserDefaults`:

- Your preferences (output directory, connections, caps, etc.)
- The fleet's device UUID + shared web token
- Whichever app-intents / shortcuts / AppleScript integrations
  macOS persists on your behalf

## What Splynek reveals to other Splyneks on your LAN

When fleet mode is enabled (default), Splynek announces its
existence on the local network via Bonjour (`_splynek-fleet._tcp`).
Other Splyneks on the same LAN can query this Mac's `/status`
endpoint for:

- Your Mac's name (whatever you set in System Settings → General
  → About)
- The fleet UUID (a random opaque identifier)
- The list of downloads this Mac is currently running or has
  recently completed, including filenames and SHA-256 hashes —
  so peers can cooperate on cache hits.

**To stop Splynek from announcing anything:** enable *Privacy
mode* in Settings → Security & privacy. The LAN status endpoint
will return empty lists. To prevent all outside hosts from
reaching Splynek entirely, enable *Loopback only*. To avoid
announcing your device at all, Bonjour can be disabled via the
same toggle.

## Downloads

Splynek fetches the bytes of whatever URL you give it. Those
bytes are stored at the output path you chose. Splynek does
not inspect, classify, or report the contents of your
downloads. Splynek computes a SHA-256 of each completed file
for integrity / fleet content-addressing purposes and stores
that hex digest in `history.json`.

## AI features (Ollama)

When natural-language features are used (Concierge, URL
resolution, history search), Splynek sends a prompt to Ollama
on `localhost:11434`. **Ollama is a separate program that you
installed yourself.** Splynek does not send the prompt
anywhere else. Ollama's own behaviour — including whether it
logs prompts to its local disk — is governed by its own
documentation and not by Splynek.

## Children

Splynek has no account system and collects no identifying data,
so there is nothing age-specific to handle. Splynek is not
directed at children under 13, and the Acceptable Use Policy
prohibits use for content harmful to minors.

## Changes to this policy

If the privacy posture ever changes, the change will appear in
CHANGELOG.md and this file will be updated with a new date.
"Privacy" is intentionally a compile-time property of the app —
a change requires a new release.

## Contact

Questions: `info@splynek.app` or open an issue on the project
repository.
