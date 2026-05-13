# Splynek IA mocks — moderator quick-reference

Clickable HTML/CSS prototype of the lifecycle-based IA proposal
in `../IA-PROPOSAL.md`. Use these for the validation tests
described in `../IA-USER-TEST-SCRIPT.md`.

**Live URL:** `https://splynek.app/mocks/` (auto-deploys from
`docs/mocks/` on `main` via GitHub Pages).

**Local URL (after `cd docs && python3 -m http.server 8765`):**
`http://localhost:8765/mocks/`

---

## Frame map

| File | Frame(s) | Tab + subview |
|---|---|---|
| `index.html` | 01 | Welcome (empty state, Discover CTA) |
| `discover.html` | 02 + 03 + 09 | Discover / Browse + Stacks + (Concierge sheet) |
| `download.html` | 04 | Download / Now + Active + Done |
| `my-apps.html` | 05 + 06 + 09 | My Apps / Installed + Updates + Trust Watcher + (Concierge) |
| `coordinate.html` | 07 + 08 | Coordinate / This LAN + Cloud relay + External |
| `_shared.css` | – | Design tokens + components |
| `_shared.js` | – | Subview chip switching + sheet open/close |
| Settings sheet | 10 | Available on every page via the gear icon |

---

## Click-through map for testers

Order of clicks the moderator might walk a tester through during
Task 2 of the user test script:

```
                    (Sidebar shown on every page)
                  ┌──────────────────────────────────┐
                  │  ✨ Discover                      │
                  │  ⬇ Download                      │
                  │  📦 My Apps                       │
                  │  🖥 Coordinate                    │
                  │  …                                │
                  │  ⚙ (footer)                      │
                  └──────────────────────────────────┘

  Welcome (index.html)
       │
       ▼
  Discover / Browse  (sidebar Discover OR welcome CTA)
       │
       ├──→  Discover / Stacks   (top chip)
       │
       └──→  Concierge sheet     ("Ask Splynek" chip)

  Download / Now     (sidebar Download)
       │
       ├──→  Download / Active   (top chip)
       │
       └──→  Download / Done     (top chip)

  My Apps / Installed (sidebar My Apps)
       │
       ├──→  My Apps / Updates   (top chip)
       │
       └──→  My Apps / Trust Watcher (top chip)

  Coordinate / This LAN (sidebar Coordinate)
       │
       ├──→  Cloud relay
       │
       └──→  External

  Settings sheet        (gear icon, available from every page)
```

10 click targets, each landing on a distinct frame or subview.

---

## URL conventions for the moderator

- Append `?moderator=1` to any URL to show the bottom-right banner
  with the frame number.
  E.g. `http://localhost:8765/mocks/my-apps.html?moderator=1`.
- Append `#installed` / `#trust-watcher` / etc. as hash to jump to
  a specific subview within a tab (e.g. for Task 2 prompts).
- The browser back/forward buttons work as expected.

---

## What's intentionally NOT in the mock

Per IA-WIREFRAMES.md § "What NOT to mock":

- Loading skeletons / spinners
- Error states
- Right-click context menus
- Drag-and-drop
- Real download behaviour (Active subview is static)
- Real catalog data (uses 12 apps × 24 URLs from the seed only)
- Accessibility annotations
- L10n variants

Testers see one consistent populated state per frame. That's
enough to test labels, placement, and intuition without
distracting them with edge-case UI.

---

## How to run a session against these mocks

Following `IA-USER-TEST-SCRIPT.md`:

1. Share `https://splynek.app/mocks/?moderator=1` or
   `http://localhost:8765/mocks/?moderator=1` if running locally.
2. The tester lands on **Welcome (Frame 01)**. Do NOT let them
   click yet.
3. Walk Task 1 (label legibility) — only read the 4 sidebar
   labels.
4. Walk Task 2 (find-the-feature) — let them click freely. Use
   the click-through map above to score each task.
5. Walk Task 3 (first-tap intuition) — reload the prototype URL
   to reset to Welcome, then ask "where would you click first?"
6. Debrief (5 questions).

Detailed scoring sheet is in IA-USER-TEST-SCRIPT.md § Section 6.

---

## Iterating on the mocks

To change a label:

```bash
# Example: rename "Coordinate" to "Devices"
cd docs/mocks
sed -i '' 's/Coordinate/Devices/g' *.html
```

The mocks deploy via GitHub Pages on push to `main`, so a label
change → commit → push lands publicly within ~1 minute.

To add a new subview to a tab, copy an existing subview block
(any `<div class="subview" data-subview="...">…</div>`) inside
the matching page, then add a corresponding chip with
`data-subview="…"` in the toolbar.

---

## Mocks vs production

These are **wireframes**, not the production UI. Key differences
from what an eventual implementation would have:

- The mock is one page per tab; production has a single window
  with tab switching (the AppKit / SwiftUI `WindowGroup`).
- Real data is dynamic; the mock data is hard-coded HTML.
- The mock has no keyboard nav past Tab; production should be
  fully keyboard-driven.
- Concierge in the mock is a static chat thread; in production
  it talks to splynek-pro's local AI.

The mocks exist to **validate the IA**, not the visual polish or
the engineering. After tests pass per IA-USER-TEST-SCRIPT.md,
the implementation begins per IA-PROPOSAL.md § Implementation
Plan.

---

*Maintained by: Splynek maintainer + Claude. Companion to
IA-PROPOSAL.md, IA-WIREFRAMES.md, IA-USER-TEST-SCRIPT.md.*
