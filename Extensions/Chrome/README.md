# Splynek — Chrome extension

Send links and current pages to Splynek directly from Chrome / Brave /
Edge / Arc / any Chromium-based browser. Right-click a link → *Download
with Splynek*. Or click the toolbar icon to hand off the current tab.

**Requires the Splynek macOS app** to be installed. The extension does
nothing by itself — it just hands URLs to Splynek via the `splynek://`
URL scheme that the app registers on install.

## Install (unpacked — one-time, no store required)

1. Open `chrome://extensions` (or the equivalent URL in your browser:
   `brave://extensions`, `edge://extensions`, `arc://extensions`).
2. Toggle **Developer mode** on (top-right).
3. Click **Load unpacked**.
4. Pick this folder (`Extensions/Chrome`).

Splynek is a Mac app, so this extension is only useful on macOS. On
Linux/Windows Chromium the extension will still load — the
`splynek://` URL will just fail to resolve.

## Usage

| Where            | Action                                    |
|------------------|-------------------------------------------|
| Right-click link | Download with Splynek / Add to queue      |
| Right-click img  | Download media with Splynek               |
| Right-click page | Download this page / Add to queue         |
| Toolbar icon     | Popup with *Download* + *Queue* buttons   |
| Shortcut         | `⌘⇧Y` — download the current tab          |

You can reassign the keyboard shortcut at
`chrome://extensions/shortcuts`.

## First use

The first time the extension invokes `splynek://…`, Chrome shows an
**Open Splynek?** prompt. Tick **Always allow splynek links to open
the associated app** and it becomes silent from then on.

## What does it actually send?

The extension builds URLs of this shape and hands them to the OS:

```
splynek://download?url=<percent-encoded>&start=1
splynek://queue?url=<percent-encoded>
```

The Splynek app treats these identically to a drag-and-drop or a
Shortcuts invocation — same code path, same interface selection, same
integrity checks. The extension has no access to Splynek's internals.

## Permissions

| Permission     | Why                                                 |
|----------------|-----------------------------------------------------|
| `contextMenus` | Right-click items on links / images / pages       |
| `activeTab`    | Read the URL of the current tab for the popup     |
| `tabs`         | Create a short-lived background tab to trigger    |
|                | the `splynek://` scheme, then close it            |
| `storage`      | Persist Accelerator opt-in + per-host preferences |
| `webRequest`   | (v0.22) Observe downloads for the Accelerator     |
| `downloads`    | Cancel a Chrome download when the user picks      |
|                | "Send to Splynek" from the Accelerator notif      |
| `notifications`| Show the Accelerator prompt when a >50 MB         |
|                | download is about to start                        |
| `host_permissions: <all_urls>` | Required for `webRequest` to       |
|                see download URLs cross-host                         |

No content scripts. No background network requests of our own —
`webRequest` is observe-only.

## Accelerator (v0.22+, off by default)

When you enable the **Accelerator** toggle in the popup, the
extension watches every browser-initiated download.  If the file is
≥ 50 MB, it shows a notification:

> Splynek can fetch this faster
> 247.3 MB from releases.example.org.  Send to Splynek to bond
> every network you have.
> [ Send to Splynek ]   [ Keep in browser ]

If you click "Send to Splynek", the Chrome download is cancelled and
the URL hands off to Splynek.  Splynek's multi-interface engine then
fetches the file across every Wi-Fi / Ethernet / iPhone-tether
connection you have at the same time — typically 2–4× faster on a
home network with cable + 5G tether.

**Per-host preferences** are stored in `chrome.storage.sync`:
- `accel.optOutHosts` — never prompt for these hosts (e.g. internal
  corporate Sharepoint where Splynek can't reach the auth)
- `accel.alwaysHosts` — always send these hosts to Splynek without
  the notification (e.g. ubuntu.com, mozilla.org, large CDNs)

These lists are populated by the future "Never for this site" /
"Always for this site" notification buttons (v0.23 — currently the
notification only has Send / Keep buttons; opt-out is via the popup
UI for now).

**Threshold** defaults to 50 MB.  Override with:
```js
chrome.storage.sync.set({ "accel.thresholdBytes": 100 * 1024 * 1024 });
```

The Accelerator does NOT touch the page DOM, does NOT proxy any
traffic, does NOT make its own network requests.  It only
**observes** Chrome's download stack and **redirects** large
downloads with explicit per-file consent.

## Uninstall

`chrome://extensions` → **Remove**. Splynek itself is unaffected.
