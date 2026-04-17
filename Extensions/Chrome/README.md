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

| Permission   | Why                                                   |
|--------------|-------------------------------------------------------|
| `contextMenus` | Right-click items on links / images / pages         |
| `activeTab`    | Read the URL of the current tab for the popup       |
| `tabs`         | Create a short-lived background tab to trigger      |
|                | the `splynek://` scheme, then close it              |
| `storage`      | Reserved for future prefs (not used today)          |

No content scripts. No host permissions. No background network.

## Uninstall

`chrome://extensions` → **Remove**. Splynek itself is unaffected.
