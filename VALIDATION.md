# Splynek v1.6 — validation playbook

Five things shipped in v1.6 that need wet-lab verification (the test
suite covers protocol-level invariants but can't drive the system
UI). Do them in order — each takes ~30 seconds.

> Throughout: paths assume the repo at `/Users/pcgm/Claude Code/`.

## 0. Launch a fresh build

```bash
cd "/Users/pcgm/Claude Code"
./Scripts/build.sh debug                 # ~90s first time, ~10s after
open build/Splynek.app
```

Sidebar footer should read **v1.6.1**. If it says anything else, abort
and tell me — version-coherence regression.

---

## 1. First-launch onboarding

The `vm.hasCompletedOnboarding` flag persists, so onboarding only
appears on first run. To force it:

```bash
defaults delete app.splynek.Splynek hasCompletedOnboarding
open build/Splynek.app
```

**You should see:** A 620×540 sheet slides up. Three dotted page
indicators at top. Skip on the right.

| Step | Pass criteria |
|------|---------------|
| Welcome | Big purple-gradient down-arrow icon. "Welcome to Splynek" title. Four bullets (Faster / Honest / Private / Sovereign). |
| Output folder | Folder card shows current path (~/Downloads by default). "Change…" opens NSOpenPanel. |
| Audit | "Run audit + finish" + "Maybe later". Clicking Run audit shows green check + "Scan started — results appear in Sovereignty + Trust tabs." |

**Then dismiss.** Re-launch the app. The sheet must NOT reappear.
If it does, the flag isn't persisting.

---

## 2. Spotlight catalog indexing

Spotlight indexes asynchronously after first launch. Wait ~30 seconds
after launch, then:

```
⌘-Space → "Notion"
```

**You should see:** A row with the **Splynek folder icon** (or default
app icon). Title "Notion". Subtitle reads something like
"OTHER origin · 2 alternatives — Notesnook, Logseq" for the Sovereignty
hit, OR "Trust audit · 3 concerns from public records" for the Trust
hit.

Try a couple more: **Spotify**, **Slack**, **Google Chrome**.

**Activating a hit** should open Splynek (launching it if closed) and
route to the matching tab.

> If Spotlight returns no Splynek hits even after waiting, Splynek
> isn't reindexing. Check Console.app for `app.splynek` log lines:
> ```bash
> log stream --predicate 'subsystem == "app.splynek"' --info
> ```

---

## 3. App Intents in Shortcuts

Open **Shortcuts.app** (Spotlight: "Shortcuts" or `/Applications/Shortcuts.app`).
Click the search field at the top of the gallery and type "Splynek".

**You should see at least these 10 Intents:**

| Action | What it does |
|--------|-------------|
| Download URL | Send a URL to Splynek's engine |
| Add URL to Queue | Queue without starting |
| Open Magnet Link in Splynek | Parse a magnet: link |
| Get Splynek Download Progress | Active jobs summary |
| Cancel All Splynek Downloads | Cancel everything |
| Pause All Splynek Downloads | Pause everything |
| List Recent Splynek Downloads | Last N completed |
| **Look up Splynek Sovereignty** | New v1.6 — bundle-ID lookup |
| **Look up Splynek Trust score** | New v1.6 — 0–100 score |
| **Run Splynek Sovereignty scan** | New v1.6 — one-shot audit |

**Drag one** ("Look up Splynek Sovereignty") into the editor → fill
"Spotify" as the query → run. Shortcut should return text like:

```
Spotify (com.spotify.client)
Controlled from: SE
Alternatives: …
```

> If Splynek isn't visible in the Intent gallery, Shortcuts.app
> doesn't have the Intents registered. Sometimes a system reboot or
> a force-quit + relaunch of Shortcuts is needed for Intents from
> a freshly-installed app to register.

---

## 4. MCP server end-to-end

```bash
# Splynek must be running, MCP must be ON in Settings → Agents tab.
"/Users/pcgm/Claude Code/Scripts/validate-mcp.sh"
```

**You should see:**

```
→ Endpoint: http://127.0.0.1:64218/splynek/v1/mcp/rpc?t=…

▸ initialize
{ … "protocolVersion": "2024-11-05" … }
  ✓ initialize handshake succeeded

▸ tools/list
{ … "tools": [ … 8 entries … ] }
  ✓ all 8 tools enumerated

▸ tools/call splynek_get_progress
{ … "isError": false … "No active downloads." … }
  ✓ tools/call returned isError:false with text content

▸ tools/call <bogus name>
{ … "code": -32601 … }
  ✓ unknown tool name returns JSON-RPC methodNotFound (-32601)

✓ All four MCP smoke tests passed.
```

If you see `503 Service Unavailable` — MCP toggle is OFF. Flip it on
in **Agents tab → Allow MCP clients to call Splynek tools**.

If you see `401 Unauthorized` — fleet token mismatch. Re-launch the
app to regenerate the descriptor.

If `Nothing's responding on http://127.0.0.1:port/` — Splynek isn't
running, or its fleet listener never bound. Check Console.app.

---

## 5. Localization

Switch the system to Portuguese (Portugal) and verify the UI translates:

```bash
defaults write app.splynek.Splynek AppleLanguages -array "pt-PT"
killall Splynek 2>/dev/null
open build/Splynek.app
```

**Spot-check translations:**

| English | Portuguese |
|---------|-----------|
| Sidebar group **Ask** | **Perguntar** |
| Sidebar group **Connect** | **Ligar** |
| Tab **Sovereignty** | **Soberania** |
| Tab **Trust** | **Confiança** |
| Tab **Agents** | **Agentes** |
| Downloads → "Speed per network" | "Velocidade por rede" |
| Downloads → "Downloads at once" | "Transferências simultâneas" |
| Downloads → "Encrypt DNS lookups" | "Encriptar consultas de DNS" |
| Downloads → "polite/balanced/aggressive" subtitle | "educado/equilibrado/agressivo" |
| Source → "Verify this download is authentic (optional)" | "Verificar se esta transferência é autêntica (opcional)" |
| Trust empty state title | "Auditoria de registo público das tuas apps" |

Onboarding (after `defaults delete … hasCompletedOnboarding`):

| English | Portuguese |
|---------|-----------|
| "Welcome to Splynek" | "Bem-vindo ao Splynek" |
| "Where should downloads go?" | "Para onde devem ir as transferências?" |
| "Run a quick audit?" | "Fazer uma auditoria rápida?" |

Try the same for **fr / de / it / es** (replace `"pt-PT"` with the
target locale code in the `defaults write` above).

**Reset to English when done:**

```bash
defaults delete app.splynek.Splynek AppleLanguages
killall Splynek 2>/dev/null
open build/Splynek.app
```

> If anything fails to translate, the catalog is missing that key.
> Edit `Scripts/regenerate-localizations.py`, run
> `python3 Scripts/regenerate-localizations.py`, rebuild.

---

## What "all green" looks like

If every section passes:

- ☑ Onboarding fires on flag-clear, dismisses cleanly, doesn't re-fire
- ☑ Spotlight returns Splynek-icon hits for catalog apps
- ☑ Shortcuts gallery shows all 10 Intents including v1.6 catalog ones
- ☑ `Scripts/validate-mcp.sh` exits 0
- ☑ pt-PT (and other locales) actually translate the UI

Splynek v1.6.1 is then **operationally validated end-to-end** and
ready for tag + DMG cut as soon as Apple clears v1.0.

If any section fails, send me the output and we debug.
