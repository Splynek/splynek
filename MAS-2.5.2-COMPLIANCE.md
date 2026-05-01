# Splynek — App Store Review Guideline 2.5.2 compliance brief

> **Audience:** App Reviewer.  Author: Paulo Graça Moura, sole developer.
> Last updated: 2026-04-30.  Source-of-truth for all 2.5.2-related
> claims in App Review Notes and Resolution Center replies.

## TL;DR

Splynek **does not generate, download, install, or execute code**.
Every piece of behaviour the user sees is compiled into the .app bundle
at build time and reviewed by Apple as part of the binary submission.
The AI features (Concierge, Recipes) use a local language model as a
**URL classifier** — it returns structured JSON containing URLs the
user must approve before Splynek probes or downloads them.  The MCP
server exposes **8 compile-time-defined tool endpoints**, not arbitrary
code.  Every dynamic-code path that exists in the binary has a
corresponding architectural invariant in the source code, audited
below.

This brief addresses Splynek's posture against **App Store Review
Guideline 2.5.2** (Performance — Software Requirements):

> "Apps should be self-contained in their bundles … nor may they
> download, install, or execute code which introduces or changes
> features or functionality of the app, including other apps."

## Why this brief exists

In 2026, Apple began enforcing 2.5.2 against a class of apps colloquially
called "vibe coding" tools — apps that take natural-language input,
have a remote or local language model generate executable code from
that input, and then execute the generated code on-device.  Replit
and Vibe Code are the named cases.  Splynek's user-facing features —
"Concierge", "natural-language goals", "local LLM", "MCP server" —
sit in the same vocabulary space, even though Splynek's mechanism is
architecturally distinct.  This document makes the distinction
unambiguous so a reviewer can verify it without reading the entire
source tree.

## What Splynek's AI does (and what it does not)

### What it does

| Surface | Input | LLM output | What Splynek does with it |
|---|---|---|---|
| **Concierge** (Pro) | English goal, e.g. "the latest Ubuntu ISO" | JSON: `{candidates: [URL...], alternatives: [...]}` | Probes each URL via HTTP HEAD/range-GET (`Probe.run`).  First responding URL with a sane content-length is offered to the user as a download candidate — the user clicks Download or cancels. |
| **Recipes** (Pro) | English goal, e.g. "set up my Mac for iOS dev" | JSON: array of `{name, url, rationale}` triples | Renders the list in a review-and-approve sheet.  The user unchecks anything they don't want and clicks **Queue all**.  Splynek then runs each download as if the user had pasted the URL into the Downloads tab. |
| **Sovereignty AI fallback** (Pro) | A bundle ID Splynek's catalog doesn't know | JSON: `{alternatives: [{name, homepage}, …]}` | Renders names + homepages as link cards.  The user clicks a link to open the homepage in their default browser.  Nothing is downloaded automatically. |
| **MCP server** (free, opt-in) | JSON-RPC 2.0 calls from a connected MCP client (e.g. claude.ai) | (server side — Splynek **answers** these calls) | Splynek **invokes one of 8 compile-time defined tool functions**.  Output is text the calling client can show in its UI.  No code is generated, sent, or executed. |

### What it does NOT do

Splynek **does not, in any code path:**

1. Use `JavaScriptCore` / `JSContext` / `WKWebView.evaluateJavaScript`
   to interpret strings as code.
2. Use `NSExpression`, `Process`, `posix_spawn`, `dlopen`, or `dlsym`
   on user-supplied or AI-supplied input.
3. Download Swift, Python, JavaScript, shell, AppleScript, or any
   other executable artifact and run it.
4. Hot-load extensions, plug-ins, or rules from the network.
5. Serialise → deserialise → execute any closure, function, or
   bytecode supplied by the LLM, by the user, or by an MCP client.
6. Cache and re-execute earlier LLM responses as code.

The AI is a **strict text-out classifier**: its output is parsed
through a `Codable`-conforming Swift struct.  Anything that doesn't
deserialise into that struct is dropped on the floor.

## Architectural invariants — verifiable in the source

Each invariant has a stable code anchor (file + first line of the
guard comment) so a reviewer can `grep` and verify directly.  All
files referenced are in this submission.

### Invariant 1 — AI returns structured data, not code

**File:** `splynek-pro/Sources/SplynekPro/AIAssistant.swift`
**Anchor:** `struct SovereigntySuggestion`,
            `struct _SovereigntyRaw`,
            `struct Answer`

The LLM responses are decoded with `JSONDecoder` against compile-time
Swift structs.  The structs contain **only `String` and `Bool` fields**
— no `Data`, no closures, no script bodies.  A `do { try decoder.decode(...) }`
that fails returns `nil` and the caller falls back to a "no
suggestion" UI.  Apple-reviewable proof: the type definitions are
visible in source.

### Invariant 2 — AI prompt has a published deny-list

**File:** `splynek-pro/Sources/SplynekPro/AIAssistant.swift`
**Anchor:** "FORBIDDEN PATTERNS" block in the system prompt,
            `sovereigntyDenyList` post-filter

The system prompt to the LLM tells it to NEVER propose Netflix /
Discord / ChatGPT / etc., and a Swift post-filter strips any model
output that matches a known US/CN/RU product.  Belt + braces.  This
exists for the Sovereignty product reason (we steer the model toward
European / OSS alternatives), but it doubles as a guarantee that no
unexpected URL leaks through.

### Invariant 3 — Every URL is probed before it's actioned

**File:** `Sources/SplynekCore/Probe.swift`
**Anchor:** `enum Probe`, `static func run(_ url: URL) async`

Before Splynek queues a download, it issues an HTTP HEAD (and
optionally a 1-byte range-GET) and validates:
- HTTPS or HTTP scheme (no `file://`, `splynek://`, `data:`,
  `javascript:`, etc.)
- Content-Length present
- Content-Type not `text/html` (catches "you've been redirected to a
  signup page" cases)
- Status 200 / 206

A URL that fails the probe is rejected; the user sees an error.  The
LLM cannot bypass this — the probe is the final gate.

### Invariant 4 — MCP exposes a fixed tool set

**File:** `Sources/SplynekCore/MCPTools.swift`
**Anchor:** `enum MCPToolRegistry`, `static let allTools: [MCPTool]`

The MCP server's `tools/list` response is computed from a
**compile-time** array of 8 `MCPTool` values.  Adding or removing a
tool requires a code change, a recompile, and an Apple resubmission.
External callers cannot define new tools.  The 8 tools are:

```
splynek_download_url           — start a download from a URL
splynek_queue_url              — add a URL to the queue
splynek_get_progress           — list active jobs (read-only)
splynek_cancel_all             — cancel every active job
splynek_list_history           — last 50 history entries (read-only)
splynek_lookup_sovereignty     — read public catalog (read-only)
splynek_lookup_trust           — read public catalog (read-only)
splynek_run_sovereignty_scan   — scan /Applications (read-only)
```

Five of the eight are pure reads.  The three writes (`download_url`,
`queue_url`, `cancel_all`) take a URL string or no argument; none
accept code, scripts, or filenames-with-shell-metacharacters.

### Invariant 5 — MCP is off by default and opt-in

**File:** `Sources/SplynekCore/Views/SettingsView.swift`
**Anchor:** Programmability section, `vm.mcpServerEnabled` toggle

The MCP server does not auto-start.  The user must visit Settings →
Programmability and explicitly enable the toggle.  The toggle's
`@AppStorage("mcpServerEnabled")` defaults to `false`.  The Splynek
binary that Apple is reviewing serves no MCP traffic until a human
flips this switch.

### Invariant 6 — No JIT, no JS engine, no expression evaluator

**File:** entire codebase
**Verification:** `grep -r "JSContext\|JavaScriptCore\|NSExpression\|posix_spawn\|dlopen\|dlsym" Sources/`
returns the file `Sources/SplynekCore/GatekeeperVerify.swift`, which
calls `Process` to run `/usr/sbin/spctl`, `/usr/bin/codesign`, and
`/usr/bin/stapler` — Apple-supplied binaries, with hard-coded
arguments — to **read** signature metadata from a downloaded file.
That code path does not execute the downloaded file; it asks the OS
to verify it.

### Invariant 7 — Bundle resources are read, never written

**File:** `Sources/SplynekCore/SplynekApp.swift` and the entitlements
plist
**Anchor:** `Resources/Splynek-MAS.entitlements`

Splynek's MAS sandbox grants `network.client`, `network.server`,
`files.user-selected.read-write`, `files.downloads.read-write`, and
`files.bookmarks.app-scope`.  It does **not** grant
`com.apple.security.cs.disable-library-validation`,
`com.apple.security.cs.allow-jit`,
`com.apple.security.cs.allow-unsigned-executable-memory`,
`com.apple.security.cs.allow-dyld-environment-variables`, or any of
the other entitlements required to load or run downloaded code.
A binary with these entitlements cannot dynamically execute code
even if the source-level guards above were removed.

### Invariant 8 — Compile-time catalog data, never editable at runtime

**File:** `Sources/SplynekCore/SovereigntyCatalog+Entries.swift`,
`Sources/SplynekCore/TrustCatalog+Entries.swift`

These files are generated from JSON sources at build time.  At
runtime they are immutable Swift `let` arrays.  The MCP and App
Intents tools that read these catalogs cannot mutate them.

## Mapping: which 2.5.2 prohibition does each invariant address?

| Prohibition | Invariant(s) |
|---|---|
| "download … code" | I-1, I-3, I-7 |
| "install … code" | I-6, I-7 (no library-validation-disable entitlement) |
| "execute code" | I-1, I-2, I-3, I-4, I-6, I-7 |
| "introduces or changes features or functionality of the app" | I-4, I-5 (tool set is compile-time + opt-in), I-8 |

## How a reviewer can verify in 5 minutes

1. **Source is public.**  The free-tier source is at
   `github.com/Splynek/splynek` (MIT-licensed).  The Pro modules
   referenced above (`AIAssistant.swift`, `AIConcierge.swift`,
   `DownloadRecipe.swift`) are in a private repo, but the **call
   sites in the public repo show every place a Pro AI surface
   touches the rest of the app** — and every one of those call sites
   accepts only `String`, `URL`, or `Codable`-decoded structs.

2. **Run `grep`.**  These five greps complete the audit:

   ```bash
   grep -rn "JSContext\|JavaScriptCore" Sources/        # → 0 hits
   grep -rn "NSExpression" Sources/                     # → 0 hits
   grep -rn "posix_spawn\|dlopen\|dlsym" Sources/       # → 0 hits
   grep -rn "evaluateJavaScript" Sources/               # → 0 hits
   grep -rn "Process(" Sources/                         # → only GatekeeperVerify (spctl/codesign/stapler)
   ```

3. **Inspect the entitlements** — `Resources/Splynek-MAS.entitlements`
   has no JIT / library-validation-disable entries.

4. **Toggle the MCP server** — Settings → Programmability → Enable
   MCP server → verify it serves only the 8 listed tool endpoints
   (visible at `http://127.0.0.1:11435/tools/list` once enabled).

## Differentiating Splynek from Replit / Vibe Code

| Dimension | Replit / Vibe Code | Splynek |
|---|---|---|
| User input | "Build me an app that does X" | "Download me the latest Ubuntu ISO" |
| LLM output | Source code (Python, JS, Swift, …) | URLs + filenames (parsed via `Codable` struct) |
| What runs on device | The LLM-generated code | A pre-compiled, Apple-reviewed download engine |
| Apple-reviewable surface | The runtime that interprets generated code | The fixed Swift binary |
| User correction loop | "The code is wrong — regenerate" | "That URL is wrong — paste a different one or cancel" |
| Failure mode | Wrong code → unintended behaviour | Wrong URL → download fails → user sees error |

Splynek is closer in shape to **Spotlight / Mail / Notes** integrating
Apple Intelligence than to Replit.  In all of those Apple-shipped
examples, the LLM produces structured suggestions (search queries,
suggested replies, summaries) that the user reviews before any
action.  Splynek follows the same review-before-action pattern.

## Appendix A — Full text of guideline 2.5.2

> Apps should be self-contained in their bundles, and may not read or
> write data outside the designated container area, nor may they
> download, install, or execute code which introduces or changes
> features or functionality of the app, including other apps.
> Educational apps designed to teach, develop, or allow students to
> test executable code may, in limited circumstances, download code
> provided that such code is not used for other purposes.  Such apps
> must make the source code provided by the app completely viewable
> and editable by the user.

## Appendix B — Files that contain the user-visible AI surfaces

The reviewer can audit each of these in a few minutes:

```
splynek-pro/Sources/SplynekPro/AIAssistant.swift           ← LLM client + decode
splynek-pro/Sources/SplynekPro/AIConcierge.swift           ← chat → URL pipeline
splynek-pro/Sources/SplynekPro/DownloadRecipe.swift        ← multi-step planner
splynek-pro/Sources/SplynekPro/Views/ConciergeView.swift   ← Concierge UI
splynek-pro/Sources/SplynekPro/Views/RecipeView.swift      ← Recipes UI
Sources/SplynekCore/MCPServer.swift                        ← JSON-RPC over POST
Sources/SplynekCore/MCPTools.swift                         ← 8 tool registry
Sources/SplynekCore/MCPBridge.swift                        ← VM ↔ MCP glue
Sources/SplynekCore/AppIntentsProvider.swift               ← 7 fixed App Intents
Sources/SplynekCore/Probe.swift                            ← URL validation gate
Sources/SplynekCore/Views/SettingsView.swift               ← MCP enable toggle
Resources/Splynek-MAS.entitlements                         ← sandbox proof
```

## Contact

Paulo Graça Moura · `info@splynek.app` · `https://splynek.app`

Happy to demo any of the above, share screen recordings, or walk a
reviewer through the call graph.  Splynek is a one-person project and
I'd rather pre-empt confusion than be re-rejected.
