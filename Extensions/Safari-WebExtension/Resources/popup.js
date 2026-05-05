// Safari port of Extensions/Chrome/popup.js — same logic, browser
// namespace.

const X = (typeof browser !== "undefined") ? browser : chrome;

document.addEventListener("DOMContentLoaded", () => {
  const urlEl = document.getElementById("url");
  const downloadBtn = document.getElementById("download");
  const queueBtn = document.getElementById("queue");
  const accelToggle = document.getElementById("accel-toggle");

  X.tabs.query({ active: true, currentWindow: true }, (tabs) => {
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

  if (accelToggle) {
    X.storage.sync.get("accel.enabled", (got) => {
      accelToggle.checked = !!got["accel.enabled"];
    });
    accelToggle.addEventListener("change", () => {
      X.storage.sync.set({ "accel.enabled": accelToggle.checked });
    });
  }
});

function dispatch(action, url) {
  const params = new URLSearchParams({ url, start: "1" });
  const splynekURL = `splynek://${action}?${params.toString()}`;
  X.tabs.create({ url: splynekURL, active: false }, (created) => {
    if (created && created.id !== undefined) {
      setTimeout(() => { X.tabs.remove(created.id).catch(() => {}); }, 400);
    }
    window.close();
  });
}
