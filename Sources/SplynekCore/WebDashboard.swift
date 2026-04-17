import Foundation

/// Zero-dependency HTML + JS + CSS dashboard served by the
/// FleetCoordinator's HTTP listener.
///
/// Design constraints:
///   - One file. No external JS/CSS/images. The dashboard must render
///     on a phone over LAN with no internet access (hotel Wi-Fi, etc.).
///   - Mobile-first. Single-column layout, big tap targets, respects
///     dark mode via `prefers-color-scheme`.
///   - Polls `/splynek/v1/ui/state` every 1.5 s. Submits new downloads
///     via POST to `/splynek/v1/ui/submit?t=<token>` where the token
///     is echoed from the page's own query string.
///   - No frameworks. Vanilla DOM + `fetch()`. Works in every browser
///     shipped in the last five years without polyfills.
///
/// State DTO is Codable so the same JSON shape feeds both Swift
/// clients (another Mac's FleetCoordinator) and the browser.
enum WebDashboard {

    struct State: Codable, Sendable {
        let device: String
        let uuid: String
        let port: UInt16
        let peerCount: Int
        let active: [FleetCoordinator.LocalState.ActiveJob]
        let completed: [FleetCoordinator.LocalState.CompletedFile]
    }

    static let html: String = #"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <meta name="apple-mobile-web-app-capable" content="yes">
      <meta name="theme-color" content="#0a84ff">
      <meta name="format-detection" content="telephone=no">
      <title>Splynek</title>
      <style>
        :root {
          color-scheme: light dark;
          --accent: #0a84ff;
          --bg: #f5f5f7;
          --panel: #ffffff;
          --border: rgba(0, 0, 0, 0.08);
          --mute: rgba(0, 0, 0, 0.55);
          --fg: rgba(0, 0, 0, 0.9);
          --good: #34c759;
          --warn: #ff9f0a;
        }
        @media (prefers-color-scheme: dark) {
          :root {
            --bg: #000000;
            --panel: #1c1c1e;
            --border: rgba(255, 255, 255, 0.12);
            --mute: rgba(255, 255, 255, 0.6);
            --fg: rgba(255, 255, 255, 0.95);
          }
        }
        * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
        html, body {
          margin: 0; padding: 0;
          font: 15px/1.45 -apple-system, BlinkMacSystemFont, "SF Pro Text",
                system-ui, Helvetica, Arial, sans-serif;
          color: var(--fg);
          background: var(--bg);
          min-height: 100svh;
          padding-env: env(safe-area-inset-top) env(safe-area-inset-right)
                        env(safe-area-inset-bottom) env(safe-area-inset-left);
        }
        main {
          max-width: 680px;
          margin: 0 auto;
          padding: 20px 16px 60px;
          padding-top: calc(20px + env(safe-area-inset-top));
          padding-bottom: calc(60px + env(safe-area-inset-bottom));
        }
        header {
          display: flex;
          align-items: baseline;
          justify-content: space-between;
          margin: 0 0 18px;
        }
        header h1 {
          font-size: 26px;
          font-weight: 700;
          letter-spacing: -0.02em;
          margin: 0;
        }
        header .device {
          font: 500 13px ui-monospace, SFMono-Regular, Menlo, monospace;
          color: var(--mute);
        }
        .card {
          background: var(--panel);
          border: 1px solid var(--border);
          border-radius: 14px;
          padding: 14px;
          margin: 0 0 12px;
        }
        .card h2 {
          font-size: 13px;
          font-weight: 600;
          margin: 0 0 10px;
          color: var(--mute);
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }
        form.submit {
          display: flex;
          flex-direction: column;
          gap: 10px;
        }
        input[type="url"], input[type="text"] {
          font: 15px ui-monospace, SFMono-Regular, Menlo, monospace;
          width: 100%;
          padding: 11px 12px;
          border-radius: 10px;
          background: rgba(127, 127, 127, 0.10);
          border: 1px solid var(--border);
          color: var(--fg);
          outline: none;
          -webkit-appearance: none;
          appearance: none;
        }
        input:focus { border-color: var(--accent); }
        .row { display: flex; gap: 10px; }
        button {
          flex: 1;
          font: 600 15px -apple-system, system-ui, sans-serif;
          padding: 12px 14px;
          border-radius: 10px;
          border: 1px solid var(--border);
          background: rgba(127, 127, 127, 0.10);
          color: var(--fg);
          cursor: pointer;
          min-height: 44px;    /* iOS accessibility tap target */
        }
        button.primary {
          background: var(--accent);
          color: #fff;
          border-color: transparent;
        }
        button:disabled { opacity: 0.45; }
        .job {
          padding: 12px 0;
          border-top: 1px solid var(--border);
        }
        .job:first-child { border-top: 0; padding-top: 0; }
        .job .name {
          font: 600 15px ui-monospace, SFMono-Regular, Menlo, monospace;
          word-break: break-all;
        }
        .job .url {
          font: 11px ui-monospace, SFMono-Regular, Menlo, monospace;
          color: var(--mute);
          word-break: break-all;
          margin: 2px 0 8px;
        }
        .bar {
          position: relative;
          height: 8px;
          background: rgba(127, 127, 127, 0.15);
          border-radius: 4px;
          overflow: hidden;
        }
        .bar > span {
          position: absolute; left: 0; top: 0; bottom: 0;
          background: linear-gradient(90deg, var(--accent), #5ac8fa);
          border-radius: 4px;
          transition: width 0.4s ease;
        }
        .job .meta {
          display: flex;
          justify-content: space-between;
          margin-top: 6px;
          font-size: 12px;
          color: var(--mute);
        }
        .empty {
          color: var(--mute);
          font-size: 14px;
          padding: 8px 0;
        }
        .pill {
          display: inline-block;
          padding: 2px 8px;
          border-radius: 9999px;
          font: 600 11px ui-monospace, SFMono-Regular, Menlo, monospace;
          background: rgba(52, 199, 89, 0.15);
          color: var(--good);
          margin-left: 6px;
        }
        .toast {
          position: fixed;
          left: 50%;
          bottom: calc(20px + env(safe-area-inset-bottom));
          transform: translate(-50%, 80px);
          background: var(--fg);
          color: var(--bg);
          padding: 10px 16px;
          border-radius: 999px;
          font: 600 13px -apple-system, sans-serif;
          opacity: 0;
          transition: transform 0.25s, opacity 0.25s;
          pointer-events: none;
          z-index: 10;
        }
        .toast.show {
          transform: translate(-50%, 0);
          opacity: 1;
        }
        footer {
          margin-top: 20px;
          text-align: center;
          font-size: 11px;
          color: var(--mute);
        }
      </style>
    </head>
    <body>
      <main>
        <header>
          <h1>Splynek</h1>
          <span class="device" id="device">—</span>
        </header>

        <div class="card">
          <h2>Send a URL to this Mac</h2>
          <form class="submit" id="form">
            <input type="url" id="url" inputmode="url" autocapitalize="off"
                   autocorrect="off" spellcheck="false"
                   placeholder="https://… or magnet:?…" required>
            <div class="row">
              <button type="submit" class="primary" id="download">Download</button>
              <button type="button" id="queue">Queue</button>
            </div>
          </form>
        </div>

        <div class="card">
          <h2>Active<span class="pill" id="peer-count" hidden></span></h2>
          <div id="active"><div class="empty">Nothing running.</div></div>
        </div>

        <div class="card">
          <h2>Recent completions</h2>
          <div id="completed"><div class="empty">No history yet.</div></div>
        </div>

        <footer id="footer">
          Polling /splynek/v1/ui/state every 1.5 s · LAN only.
        </footer>
      </main>
      <div class="toast" id="toast" role="status"></div>

      <script>
      (function () {
        const qs = new URLSearchParams(location.search);
        const token = qs.get('t') || '';
        const byId = id => document.getElementById(id);
        const toast = msg => {
          const t = byId('toast');
          t.textContent = msg;
          t.classList.add('show');
          setTimeout(() => t.classList.remove('show'), 1800);
        };
        const fmtBytes = n => {
          if (!n) return '0 B';
          const u = ['B','KB','MB','GB','TB'];
          const i = Math.min(u.length - 1, Math.floor(Math.log(n) / Math.log(1024)));
          return (n / Math.pow(1024, i)).toFixed(i ? 1 : 0) + ' ' + u[i];
        };
        const fmtPct = (done, total) => total > 0 ? ((done / total) * 100).toFixed(1) + '%' : '';
        const fmtAgo = iso => {
          const then = new Date(iso).getTime();
          if (!then) return '';
          const s = Math.max(0, (Date.now() - then) / 1000);
          if (s < 60)      return Math.round(s) + 's ago';
          if (s < 3600)    return Math.round(s / 60) + 'm ago';
          if (s < 86400)   return Math.round(s / 3600) + 'h ago';
          return Math.round(s / 86400) + 'd ago';
        };

        async function submit(action) {
          const url = byId('url').value.trim();
          if (!url) return;
          try {
            const r = await fetch('/splynek/v1/ui/submit?t=' + encodeURIComponent(token), {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ url, action })
            });
            if (r.status === 202) {
              toast(action === 'queue' ? 'Queued' : 'Downloading');
              byId('url').value = '';
              byId('url').blur();
              refresh();
            } else if (r.status === 401) {
              toast('Token rejected — scan the QR again');
            } else {
              toast('Failed (' + r.status + ')');
            }
          } catch (e) {
            toast('Network error');
          }
        }

        byId('form').addEventListener('submit', e => {
          e.preventDefault();
          submit('download');
        });
        byId('queue').addEventListener('click', () => submit('queue'));

        function renderActive(jobs) {
          const root = byId('active');
          if (!jobs || !jobs.length) {
            root.innerHTML = '<div class="empty">Nothing running.</div>';
            return;
          }
          root.innerHTML = jobs.map(j => {
            const pct = j.totalBytes > 0 ? (j.downloaded / j.totalBytes) * 100 : 0;
            return (
              '<div class="job">' +
                '<div class="name">' + escapeHTML(j.filename) + '</div>' +
                '<div class="url">' + escapeHTML(j.url) + '</div>' +
                '<div class="bar"><span style="width:' + pct.toFixed(1) + '%"></span></div>' +
                '<div class="meta">' +
                  '<span>' + fmtBytes(j.downloaded) + ' / ' + fmtBytes(j.totalBytes) + '</span>' +
                  '<span>' + fmtPct(j.downloaded, j.totalBytes) + '</span>' +
                '</div>' +
              '</div>'
            );
          }).join('');
        }

        function renderCompleted(done) {
          const root = byId('completed');
          if (!done || !done.length) {
            root.innerHTML = '<div class="empty">No history yet.</div>';
            return;
          }
          root.innerHTML = done.map(f => (
            '<div class="job">' +
              '<div class="name">' + escapeHTML(f.filename) + '</div>' +
              '<div class="meta">' +
                '<span>' + fmtBytes(f.totalBytes) + '</span>' +
                '<span>' + fmtAgo(f.finishedAt) + '</span>' +
              '</div>' +
            '</div>'
          )).join('');
        }

        function escapeHTML(s) {
          return String(s == null ? '' : s).replace(/[&<>"']/g, c => (
            { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
          ));
        }

        async function refresh() {
          try {
            const r = await fetch('/splynek/v1/ui/state');
            if (!r.ok) return;
            const s = await r.json();
            byId('device').textContent = s.device + ' · :' + s.port;
            const pc = byId('peer-count');
            if (s.peerCount > 0) {
              pc.hidden = false;
              pc.textContent = '+' + s.peerCount + ' peer' + (s.peerCount === 1 ? '' : 's');
            } else {
              pc.hidden = true;
            }
            renderActive(s.active);
            renderCompleted(s.completed);
          } catch (_) { /* Mac asleep or network dropped */ }
        }

        refresh();
        setInterval(refresh, 1500);
      })();
      </script>
    </body>
    </html>
    """#
}
