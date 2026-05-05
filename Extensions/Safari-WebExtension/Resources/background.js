// Splynek Safari WebExtension — background script.
//
// Port of the Chrome MV3 service-worker code (Extensions/Chrome/
// background.js).  Safari WebExtensions are MV3-compatible; the only
// systematic difference is the API namespace — Safari uses `browser`,
// Chrome uses `chrome`.  We pick whichever is defined at load time so
// the same source builds on either browser.
//
// Two jobs (same as Chrome):
//
// 1. Manual hand-off via right-click context menu / keyboard shortcut.
//    Build a `splynek://...` URL and open it in a throwaway tab so
//    macOS routes it to the Splynek app via the registered URL scheme.
//
// 2. Accelerator intercept (Strategy Bet S5 first half).  Watch
//    browser-initiated downloads via `downloads.onCreated`.  When a
//    file ≥ threshold (default 50 MB) starts, prompt the user to
//    redirect through Splynek's bonded engine.
//
// Diffs vs the Chrome port:
//   - Namespace: `X` aliases either `browser` or `chrome`
//   - Safari supports `notifications` since macOS 14 / Safari 17;
//     the API surface matches Chrome's MV3 form
//   - Safari occasionally requires `setTimeout(0)` between API calls
//     in async chains (race conditions in the WKWebView bridge); we
//     don't hit those today but flagged here for future port issues
//   - First splynek:// invocation triggers Safari's "Allow Splynek
//     to open?" dialog; identical to Chrome behaviour, ticking
//     "Always allow" makes it silent thereafter

const X = (typeof browser !== "undefined") ? browser : chrome;

const MENU_IDS = {
  downloadLink: "splynek-download-link",
  queueLink:    "splynek-queue-link",
  downloadPage: "splynek-download-page",
  queuePage:    "splynek-queue-page",
  downloadMedia: "splynek-download-media"
};

X.runtime.onInstalled.addListener(() => {
  X.contextMenus.removeAll(() => {
    X.contextMenus.create({ id: MENU_IDS.downloadLink, title: "Download with Splynek", contexts: ["link"] });
    X.contextMenus.create({ id: MENU_IDS.queueLink,    title: "Add link to Splynek queue", contexts: ["link"] });
    X.contextMenus.create({ id: MENU_IDS.downloadMedia, title: "Download media with Splynek", contexts: ["image", "video", "audio"] });
    X.contextMenus.create({ id: MENU_IDS.downloadPage, title: "Download this page with Splynek", contexts: ["page", "frame"] });
    X.contextMenus.create({ id: MENU_IDS.queuePage,    title: "Add this page to Splynek queue", contexts: ["page", "frame"] });
  });
});

X.contextMenus.onClicked.addListener((info, tab) => {
  const target = info.linkUrl || info.srcUrl || info.pageUrl || (tab && tab.url);
  if (!target) return;
  const action = (info.menuItemId === MENU_IDS.queueLink ||
                  info.menuItemId === MENU_IDS.queuePage) ? "queue" : "download";
  openInSplynek(action, target);
});

X.commands.onCommand.addListener((command) => {
  if (command !== "splynek-download-active-tab") return;
  X.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    const tab = tabs && tabs[0];
    if (tab && tab.url) openInSplynek("download", tab.url);
  });
});

self.openInSplynek = openInSplynek;

function openInSplynek(action, url, extras = {}) {
  const params = new URLSearchParams();
  params.set("url", url);
  params.set("start", "1");
  for (const [k, v] of Object.entries(extras)) {
    if (v != null && v !== "") params.set(k, String(v));
  }
  const splynekURL = `splynek://${action}?${params.toString()}`;
  X.tabs.create({ url: splynekURL, active: false }, (created) => {
    if (X.runtime.lastError) return;
    if (created && created.id !== undefined) {
      setTimeout(() => { X.tabs.remove(created.id).catch(() => {}); }, 400);
    }
  });
}

// ============================================================
// Strategy Bet S5 first half — Accelerator intercept (Safari port)
// ============================================================
//
// Logic identical to the Chrome version.  Safari's downloads API
// uses the same `downloads.onCreated` event shape.  Notification
// quirks: Safari shows extension notifications in macOS Notification
// Center the same way as native macOS notifications; `requireInteraction`
// is supported but the macOS DND switch overrides it (notification
// stays in Notification Center but doesn't pop up on screen).

const THRESHOLD_BYTES_DEFAULT = 50 * 1024 * 1024;

const ACCEL_KEYS = {
  enabled: "accel.enabled",
  threshold: "accel.thresholdBytes",
  optOutHosts: "accel.optOutHosts",
  alwaysHosts: "accel.alwaysHosts",
};

async function readAccelConfig() {
  return new Promise((resolve) => {
    X.storage.sync.get(
      [ACCEL_KEYS.enabled, ACCEL_KEYS.threshold,
       ACCEL_KEYS.optOutHosts, ACCEL_KEYS.alwaysHosts],
      (got) => {
        resolve({
          enabled: !!got[ACCEL_KEYS.enabled],
          threshold: typeof got[ACCEL_KEYS.threshold] === "number"
            ? got[ACCEL_KEYS.threshold] : THRESHOLD_BYTES_DEFAULT,
          optOut: got[ACCEL_KEYS.optOutHosts] || {},
          always: got[ACCEL_KEYS.alwaysHosts] || {},
        });
      }
    );
  });
}

function hostFor(url) {
  try { return new URL(url).hostname.toLowerCase(); }
  catch { return null; }
}

const pendingByNotificationId = new Map();

X.downloads.onCreated.addListener(async (item) => {
  const cfg = await readAccelConfig();
  if (!cfg.enabled) return;
  if (item.totalBytes < cfg.threshold) return;
  if (!item.url) return;
  const host = hostFor(item.url);
  if (host && cfg.optOut[host]) return;
  if (host && cfg.always[host]) {
    X.downloads.cancel(item.id);
    openInSplynek("download", item.url);
    return;
  }
  const sizeMB = (item.totalBytes / (1024 * 1024)).toFixed(1);
  const notifId = `splynek-accel-${item.id}`;
  pendingByNotificationId.set(notifId, { downloadId: item.id, url: item.url, host });
  X.notifications.create(notifId, {
    type: "basic",
    iconUrl: "icons/icon-128.png",
    title: "Splynek can fetch this faster",
    message: `${sizeMB} MB from ${host || "this server"}.  Send to Splynek to bond every network you have.`,
    contextMessage: host
      ? `Click the notification to open the options page (always/never for ${host}).`
      : "Click the notification to open per-host preferences.",
    buttons: [
      { title: "Send to Splynek" },
      { title: "Keep in browser" },
    ],
    requireInteraction: true,
  });
});

X.notifications.onButtonClicked.addListener((notifId, btnIdx) => {
  const pending = pendingByNotificationId.get(notifId);
  if (!pending) return;
  pendingByNotificationId.delete(notifId);
  if (btnIdx === 0) {
    X.downloads.cancel(pending.downloadId);
    openInSplynek("download", pending.url);
  }
  X.notifications.clear(notifId);
});

X.notifications.onClicked.addListener((notifId) => {
  if (notifId.startsWith("splynek-accel-")) {
    X.runtime.openOptionsPage();
  }
});

X.notifications.onClosed.addListener((notifId) => {
  pendingByNotificationId.delete(notifId);
});

async function setHostPreference(host, mode) {
  const cfg = await readAccelConfig();
  const optOut = { ...cfg.optOut };
  const always = { ...cfg.always };
  delete optOut[host];
  delete always[host];
  if (mode === "always") always[host] = true;
  else if (mode === "never") optOut[host] = true;
  return new Promise((resolve) => {
    X.storage.sync.set({
      [ACCEL_KEYS.optOutHosts]: optOut,
      [ACCEL_KEYS.alwaysHosts]: always,
    }, resolve);
  });
}

self.setHostPreference = setHostPreference;
self.readAccelConfig = readAccelConfig;
self.ACCEL_KEYS = ACCEL_KEYS;
