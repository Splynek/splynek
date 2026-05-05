// Splynek Accelerator — options page logic.
//
// Edits the same `chrome.storage.sync` keys the background.js
// service worker reads.  Storage updates take effect immediately —
// the next download Chrome starts uses the new state.

const KEYS = {
  enabled: "accel.enabled",
  threshold: "accel.thresholdBytes",
  optOut: "accel.optOutHosts",
  always: "accel.alwaysHosts",
};

const els = {
  enabled: document.getElementById("enabled"),
  threshold: document.getElementById("threshold"),
  alwaysList: document.getElementById("alwaysList"),
  neverList: document.getElementById("neverList"),
  alwaysInput: document.getElementById("alwaysInput"),
  neverInput: document.getElementById("neverInput"),
  alwaysAdd: document.getElementById("alwaysAdd"),
  neverAdd: document.getElementById("neverAdd"),
};

document.addEventListener("DOMContentLoaded", () => {
  refresh();

  els.enabled.addEventListener("change", () => {
    chrome.storage.sync.set({ [KEYS.enabled]: els.enabled.checked });
  });

  els.threshold.addEventListener("change", () => {
    const mb = parseInt(els.threshold.value, 10);
    if (!Number.isFinite(mb) || mb < 1) return;
    chrome.storage.sync.set({ [KEYS.threshold]: mb * 1024 * 1024 });
  });

  els.alwaysAdd.addEventListener("click", () => {
    addHost("always", els.alwaysInput);
  });
  els.neverAdd.addEventListener("click", () => {
    addHost("never", els.neverInput);
  });
  // Enter key submits the add-host inputs.
  els.alwaysInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") addHost("always", els.alwaysInput);
  });
  els.neverInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") addHost("never", els.neverInput);
  });
});

function refresh() {
  chrome.storage.sync.get(
    [KEYS.enabled, KEYS.threshold, KEYS.optOut, KEYS.always],
    (got) => {
      els.enabled.checked = !!got[KEYS.enabled];
      const thresholdBytes = typeof got[KEYS.threshold] === "number"
        ? got[KEYS.threshold]
        : 50 * 1024 * 1024;
      els.threshold.value = Math.round(thresholdBytes / (1024 * 1024));
      renderList(els.alwaysList, got[KEYS.always] || {}, "always");
      renderList(els.neverList, got[KEYS.optOut] || {}, "never");
    }
  );
}

function renderList(ulEl, dict, mode) {
  ulEl.innerHTML = "";
  const hosts = Object.keys(dict).sort();
  if (hosts.length === 0) {
    const li = document.createElement("li");
    li.className = "empty";
    li.textContent = "No hosts yet.";
    ulEl.appendChild(li);
    return;
  }
  for (const host of hosts) {
    const li = document.createElement("li");
    const label = document.createElement("span");
    label.textContent = host;
    li.appendChild(label);
    const btn = document.createElement("button");
    btn.textContent = "Remove";
    btn.addEventListener("click", () => removeHost(host, mode));
    li.appendChild(btn);
    ulEl.appendChild(li);
  }
}

function addHost(mode, inputEl) {
  const raw = inputEl.value.trim().toLowerCase();
  if (!raw) return;
  // Light validation: allow only [a-z0-9.-], reject leading/trailing
  // dots, require at least one dot somewhere.  Defends against
  // accidental URLs being pasted in (e.g. a full https://... URL).
  const host = sanitizeHost(raw);
  if (!host) {
    inputEl.style.borderColor = "var(--warn)";
    setTimeout(() => { inputEl.style.borderColor = ""; }, 1200);
    return;
  }
  inputEl.value = "";
  const key = mode === "always" ? KEYS.always : KEYS.optOut;
  // Reading + writing both buckets atomically because moving a host
  // from "always" → "never" should remove from "always" first.
  chrome.storage.sync.get([KEYS.always, KEYS.optOut], (got) => {
    const always = { ...(got[KEYS.always] || {}) };
    const optOut = { ...(got[KEYS.optOut] || {}) };
    delete always[host];
    delete optOut[host];
    if (mode === "always") always[host] = true;
    else                   optOut[host] = true;
    chrome.storage.sync.set({
      [KEYS.always]: always,
      [KEYS.optOut]: optOut,
    }, refresh);
  });
}

function removeHost(host, mode) {
  const key = mode === "always" ? KEYS.always : KEYS.optOut;
  chrome.storage.sync.get(key, (got) => {
    const dict = { ...(got[key] || {}) };
    delete dict[host];
    chrome.storage.sync.set({ [key]: dict }, refresh);
  });
}

/**
 * Trim a paste like `https://releases.ubuntu.com/24.04/file.iso` down
 * to `releases.ubuntu.com`.  Returns null on garbage.  Exported for
 * testing.
 */
function sanitizeHost(raw) {
  if (!raw) return null;
  const s = String(raw).trim().toLowerCase();
  if (!s) return null;
  // If the user pasted a URL, parse it and pull the host.
  if (/^https?:\/\//.test(s)) {
    try { return new URL(s).hostname.toLowerCase(); }
    catch { return null; }
  }
  // Otherwise it's already a host string; validate it's in
  // [a-z0-9.-]+ + has a dot somewhere + doesn't start/end with a dot.
  if (!/^[a-z0-9.-]+$/.test(s)) return null;
  if (s.startsWith(".") || s.endsWith(".")) return null;
  if (!s.includes(".")) return null;
  return s;
}

// Expose for tests.
self.sanitizeHost = sanitizeHost;
