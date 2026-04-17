// Splynek Chrome extension — service worker (Manifest V3).
//
// The extension has one job: take a URL the user cares about (a link they
// right-clicked, or the current tab) and hand it to Splynek via the
// `splynek://` scheme that the native app registers.
//
// No native messaging, no cross-origin fetches, no permissions beyond
// contextMenus + activeTab + tabs + storage. Splynek's URL scheme is the
// integration contract, so the extension stays tiny and Chrome Web Store
// review is straightforward.

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
