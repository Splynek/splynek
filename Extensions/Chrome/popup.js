// Popup: show the current tab's URL and two buttons — download now, or
// queue. Constructs the splynek:// URL inline; the background service
// worker does the same thing for context-menu paths.

document.addEventListener("DOMContentLoaded", () => {
  const urlEl = document.getElementById("url");
  const downloadBtn = document.getElementById("download");
  const queueBtn = document.getElementById("queue");

  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    const tab = tabs && tabs[0];
    if (!tab || !tab.url) {
      urlEl.textContent = "No active tab.";
      downloadBtn.disabled = true;
      queueBtn.disabled = true;
      return;
    }
    urlEl.textContent = tab.url;
    downloadBtn.addEventListener("click", () => dispatch("download", tab.url));
    queueBtn.addEventListener("click",    () => dispatch("queue",    tab.url));
  });
});

function dispatch(action, url) {
  const params = new URLSearchParams({ url, start: "1" });
  const splynekURL = `splynek://${action}?${params.toString()}`;
  chrome.tabs.create({ url: splynekURL, active: false }, (created) => {
    if (created && created.id !== undefined) {
      setTimeout(() => {
        chrome.tabs.remove(created.id).catch(() => {});
      }, 400);
    }
    window.close();
  });
}
