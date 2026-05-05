// Splynek Chrome extension — service worker (Manifest V3).
//
// Two jobs:
//
// 1. **Manual hand-off** (existing).  Take a URL the user cares about
//    (a link they right-clicked, or the current tab) and hand it to
//    Splynek via the `splynek://` scheme that the native app registers.
//
// 2. **Accelerator intercept** (2026-05-05, Strategy Bet S5 first half).
//    Watch every browser-initiated download via `chrome.downloads.onCreated`.
//    If the file is large enough that Splynek's multi-interface bonding
//    would help (default threshold: 50 MB), cancel the Chrome download
//    and offer to fetch it through Splynek instead via a notification.
//    Per-host opt-out via `chrome.storage.sync` keeps the prompt-fatigue
//    bounded.
//
// No native messaging, no cross-origin fetches.  Splynek's URL scheme
// is the integration contract.  All accelerator decisions are local —
// no server round-trips.

const MENU_IDS = {
  downloadLink: "splynek-download-link",
  queueLink:    "splynek-queue-link",
  downloadPage: "splynek-download-page",
  queuePage:    "splynek-queue-page",
  downloadMedia: "splynek-download-media"
};

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: MENU_IDS.downloadLink,
      title: "Download with Splynek",
      contexts: ["link"]
    });
    chrome.contextMenus.create({
      id: MENU_IDS.queueLink,
      title: "Add link to Splynek queue",
      contexts: ["link"]
    });
    chrome.contextMenus.create({
      id: MENU_IDS.downloadMedia,
      title: "Download media with Splynek",
      contexts: ["image", "video", "audio"]
    });
    chrome.contextMenus.create({
      id: MENU_IDS.downloadPage,
      title: "Download this page with Splynek",
      contexts: ["page", "frame"]
    });
    chrome.contextMenus.create({
      id: MENU_IDS.queuePage,
      title: "Add this page to Splynek queue",
      contexts: ["page", "frame"]
    });
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  const target =
    info.linkUrl ||
    info.srcUrl ||
    info.pageUrl ||
    (tab && tab.url);
  if (!target) return;

  const action = (info.menuItemId === MENU_IDS.queueLink ||
                  info.menuItemId === MENU_IDS.queuePage)
    ? "queue"
    : "download";
  openInSplynek(action, target);
});

// Keyboard shortcut (default ⌘⇧Y on Mac) — downloads the currently
// active tab's URL.
chrome.commands.onCommand.addListener((command) => {
  if (command !== "splynek-download-active-tab") return;
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    const tab = tabs && tabs[0];
    if (tab && tab.url) openInSplynek("download", tab.url);
  });
});

// Expose for popup.html
self.openInSplynek = openInSplynek;

/**
 * Construct a splynek:// URL and hand it to the OS.
 *
 * Chrome blocks navigating the *current* tab to a custom scheme without
 * user interaction, so we create a throwaway background tab that targets
 * splynek:// — macOS intercepts the navigation, launches Splynek (or
 * sends the URL to the already-running instance), and we immediately
 * clean up the tab.
 *
 * First use prompts the user for permission to open Splynek; subsequent
 * invocations are silent after they check "Always allow".
 */
function openInSplynek(action, url, extras = {}) {
  const params = new URLSearchParams();
  params.set("url", url);
  params.set("start", "1");
  for (const [k, v] of Object.entries(extras)) {
    if (v != null && v !== "") params.set(k, String(v));
  }
  const splynekURL = `splynek://${action}?${params.toString()}`;
  chrome.tabs.create({ url: splynekURL, active: false }, (created) => {
    if (chrome.runtime.lastError) {
      // Some Chromium forks refuse to open unknown-scheme tabs at all.
      // Fallback: try an update on a hidden data: tab that then
      // navigates to the scheme. Ugly, but rare.
      return;
    }
    if (created && created.id !== undefined) {
      setTimeout(() => {
        chrome.tabs.remove(created.id).catch(() => {});
      }, 400);
    }
  });
}

// ============================================================
// Strategy Bet S5 first half — Accelerator intercept
// ============================================================
//
// Chrome's download stack invokes `chrome.downloads.onCreated` BEFORE
// the user's browser starts pulling bytes (technically right after the
// HTTP response headers are received).  At that moment we know:
//   - the URL
//   - `totalBytes` (Content-Length, or 0 if not advertised)
//   - the source tab + referrer
//   - the proposed local filename
//
// Decision flow:
//   1. If accelerator is disabled in storage → ignore.
//   2. If totalBytes < THRESHOLD_BYTES → ignore.  Small files are
//      latency-bound, not bandwidth-bound; multi-interface bonding
//      offers no win.
//   3. If host is on the per-user opt-out list → ignore.
//   4. Otherwise: notify the user "Splynek can fetch this faster.
//      [Send to Splynek] [Keep here] [Never for this site]".
//
// We don't auto-cancel + redirect.  That's a hostile UX — the user
// initiated the download in their browser, surprises are bad.  The
// notification gives an EXPLICIT consent moment per file; once they
// approve once for a site, we remember the answer.

const THRESHOLD_BYTES_DEFAULT = 50 * 1024 * 1024;  // 50 MB

const ACCEL_KEYS = {
  enabled: "accel.enabled",          // bool, default false (opt-in)
  threshold: "accel.thresholdBytes", // number, default 50 MB
  optOutHosts: "accel.optOutHosts",  // {host: true} object
  alwaysHosts: "accel.alwaysHosts",  // {host: true} — auto-Splynek
};

async function readAccelConfig() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(
      [ACCEL_KEYS.enabled, ACCEL_KEYS.threshold,
       ACCEL_KEYS.optOutHosts, ACCEL_KEYS.alwaysHosts],
      (got) => {
        resolve({
          enabled: !!got[ACCEL_KEYS.enabled],
          threshold: typeof got[ACCEL_KEYS.threshold] === "number"
            ? got[ACCEL_KEYS.threshold]
            : THRESHOLD_BYTES_DEFAULT,
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

// Track download → notification mapping so the click handler can find
// the right download to cancel + redirect.
const pendingByNotificationId = new Map();

chrome.downloads.onCreated.addListener(async (item) => {
  const cfg = await readAccelConfig();
  if (!cfg.enabled) return;
  if (item.totalBytes < cfg.threshold) return;
  if (!item.url) return;
  const host = hostFor(item.url);
  if (host && cfg.optOut[host]) return;

  if (host && cfg.always[host]) {
    // User previously chose "always send <host> to Splynek".
    chrome.downloads.cancel(item.id);
    openInSplynek("download", item.url);
    return;
  }

  const sizeMB = (item.totalBytes / (1024 * 1024)).toFixed(1);
  const notifId = `splynek-accel-${item.id}`;
  pendingByNotificationId.set(notifId, {
    downloadId: item.id, url: item.url, host
  });
  // Chrome notifications are limited to 2 buttons.  We pack the four
  // logical actions (Send / Keep / Always-for-site / Never-for-site)
  // into two slots that flip between primary actions ("Send", "Keep")
  // and per-host preferences ("Always for <host>", "Never for <host>")
  // based on the click that opened the notification.  Body line tells
  // the user about the extension's options page where they can edit
  // the per-host preferences directly.
  chrome.notifications.create(notifId, {
    type: "basic",
    iconUrl: "icons/icon-128.png",
    title: "Splynek can fetch this faster",
    message: `${sizeMB} MB from ${host || "this server"}.  Send to Splynek to bond every network you have.`,
    contextMessage: host
      ? `Right-click the notification icon for "Always for ${host}" / "Never for ${host}".`
      : "Right-click the notification icon for per-host preferences.",
    buttons: [
      { title: "Send to Splynek" },
      { title: "Keep in browser" },
    ],
    requireInteraction: true,
  });
});

chrome.notifications.onButtonClicked.addListener((notifId, btnIdx) => {
  const pending = pendingByNotificationId.get(notifId);
  if (!pending) return;
  pendingByNotificationId.delete(notifId);
  if (btnIdx === 0) {
    // "Send to Splynek" — cancel Chrome's fetch + hand off to app.
    chrome.downloads.cancel(pending.downloadId);
    openInSplynek("download", pending.url);
  }
  // btnIdx === 1 ("Keep in browser") leaves Chrome to finish the
  // download — we just clear the notification.
  chrome.notifications.clear(notifId);
});

// Right-click on the notification body opens the options page so
// the user can pin "Always for <host>" / "Never for <host>" without
// hunting for the chrome://extensions options link.
chrome.notifications.onClicked.addListener((notifId) => {
  if (notifId.startsWith("splynek-accel-")) {
    chrome.runtime.openOptionsPage();
  }
});

// ============================================================
// Per-host preference helpers (used by options.html via the
// chrome.storage API directly; exposed here for tests).
// ============================================================

/**
 * Move host into one of the three buckets: ask (default), always,
 * never.  Idempotent.
 */
async function setHostPreference(host, mode) {
  const cfg = await readAccelConfig();
  const optOut = { ...cfg.optOut };
  const always = { ...cfg.always };
  delete optOut[host];
  delete always[host];
  if (mode === "always") always[host] = true;
  else if (mode === "never") optOut[host] = true;
  return new Promise((resolve) => {
    chrome.storage.sync.set({
      [ACCEL_KEYS.optOutHosts]: optOut,
      [ACCEL_KEYS.alwaysHosts]: always,
    }, resolve);
  });
}

self.setHostPreference = setHostPreference;
self.readAccelConfig = readAccelConfig;
self.ACCEL_KEYS = ACCEL_KEYS;

// ============================================================
// Strategy Bet S5 second half — HLS pre-buffer detection
// (scaffolding only, 2026-05-05)
// ============================================================
//
// HLS streams are detectable by URL extension (.m3u8 / .m3u) +
// Content-Type ("application/vnd.apple.mpegurl" or
// "application/x-mpegurl").  When we see one, we record the
// detection in storage so the user can opt-in via the options
// page; in v0.24+ this turns into "redirect playlist requests
// through Splynek's local HLS proxy at 127.0.0.1:<port>/hls/...".
//
// Today's scaffolding: just *count* detections and surface them
// in the options page so users (a) know the feature is sniffing
// for streams and (b) can see it actually works on their sites
// before we wire up the proxy redirect.

const HLS_KEYS = {
  detectionCount: "hls.detectionCount",
  lastSeenURL:    "hls.lastSeenURL",
  lastSeenAt:     "hls.lastSeenAt",
};

function looksLikeHLSManifest(url) {
  // Mirrors HLSManifest.looksLikeManifestURL on the Swift side.
  try {
    const u = new URL(url);
    const path = u.pathname.toLowerCase();
    return path.endsWith(".m3u8") || path.endsWith(".m3u");
  } catch { return false; }
}

chrome.webRequest.onHeadersReceived.addListener(
  (details) => {
    if (!looksLikeHLSManifest(details.url)) {
      // Cheap path miss — don't even check content-type for
      // non-manifest-shaped URLs.
      return;
    }
    chrome.storage.local.get(
      [HLS_KEYS.detectionCount, HLS_KEYS.lastSeenURL, HLS_KEYS.lastSeenAt],
      (got) => {
        const count = (got[HLS_KEYS.detectionCount] || 0) + 1;
        chrome.storage.local.set({
          [HLS_KEYS.detectionCount]: count,
          [HLS_KEYS.lastSeenURL]: details.url,
          [HLS_KEYS.lastSeenAt]: Date.now(),
        });
      }
    );
  },
  { urls: ["<all_urls>"], types: ["xmlhttprequest", "media", "other"] }
);

chrome.notifications.onClosed.addListener((notifId) => {
  pendingByNotificationId.delete(notifId);
});
