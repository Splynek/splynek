# IA-WIREFRAMES.md

Figma-ready wireframe specs for the four-tab IA proposal in
`IA-PROPOSAL.md`. Build clickable mocks before any engineering
starts.

**Intended reader:** a designer (or the maintainer using Figma's
auto-layout features) producing 8-10 frames to walk a tester
through. Not pixel-perfect production specs — *good-enough mocks
to validate the IA labels and feature placement*. Production
visuals come later if the IA tests well.

**Style anchor:** the existing `docs/index.html` (live at
splynek.app from v2.0.1) defines the brand's visual language —
dark cosmic background, mint-green accent, panel cards. The
wireframes adopt that system so testers see something that feels
like Splynek, not a generic UX kit.

---

## Section 0 — Design tokens

Copy these into Figma as Variables (preferred) or styles.

### Colors

| Token | Hex | Use |
|---|---|---|
| `bg` | `#0B1128` | App canvas background (gradient base) |
| `bg2` | `#11183A` | Gradient top |
| `panel` | `#151C36` | Card / sidebar / toolbar |
| `panel-lift` | `#1A2145` | Card hover, list-row selected |
| `border` | `rgba(255,255,255,0.08)` | Subtle borders between panels |
| `border-lift` | `rgba(255,255,255,0.14)` | Hover-state borders |
| `text` | `#ECEFF9` | Primary body text |
| `text-dim` | `#C9CEE3` | Secondary text |
| `muted` | `#8891B0` | Captions, hints |
| `accent` | `#5ADCA5` | Primary actions, links, "good" status |
| `accent-dk` | `#2FBC85` | Pressed state of accent buttons |
| `gold` | `#F5C16C` | Warnings, "needs attention", Sovereignty alerts |
| `purple` | `#B48CFF` | Automation / Pro / iPhone tags |
| `pink` | `#FF9BD2` | Tertiary highlights |
| `red` | `#FF7E7E` | Errors, "untrusted", Trust Watcher critical |

The hero/canvas gradient (from `docs/index.html`):

```
radial-gradient(ellipse 1100px 700px at 50% -10%, rgba(90, 220, 165, 0.12) 0%, transparent 60%),
radial-gradient(ellipse  900px 600px at 10% 40%, rgba(180, 140, 255, 0.08) 0%, transparent 55%),
radial-gradient(ellipse  900px 600px at 90% 70%, rgba(255, 155, 210, 0.06) 0%, transparent 55%),
linear-gradient(180deg, #11183A 0%, #0B1128 50%, #0B1128 100%)
```

In Figma: apply as a layered fill on the root frame.

### Typography

System font stack — Figma renders "SF Pro Text" when on macOS;
fall back to Inter for cross-platform mocks.

| Token | Size | Weight | Line-height | Tracking | Use |
|---|---|---|---|---|---|
| `display` | 56 | 700 | 1.05 | -0.03em | Welcome card hero |
| `h1` | 30 | 700 | 1.15 | -0.022em | Tab title |
| `h2` | 22 | 600 | 1.25 | -0.015em | Subview section header |
| `h3` | 17 | 600 | 1.3 | -0.01em | Card title, row primary text |
| `body` | 14.5 | 400 | 1.5 | -0.005em | Body, list-row primary |
| `body-dim` | 14.5 | 400 | 1.5 | -0.005em | Body in `text-dim` colour |
| `caption` | 13 | 400 | 1.4 | 0 | Sub-row metadata |
| `caption-bold` | 13 | 600 | 1.4 | 0 | Sub-row labels |
| `tiny` | 11 | 600 | 1.3 | 0.04em | Uppercase pills / badges |
| `mono` | 12.5 | 400 | 1.5 | 0 | URLs, tokens, paths |

### Spacing scale (4px grid)

`4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 56 · 72`

Use these only. Padding inside cards: 18-24. Gap between cards: 14-18.
Outer margin of main content: 24.

### Radii

| Token | Value | Use |
|---|---|---|
| `radius-sm` | 6 | Pills, small buttons |
| `radius-md` | 10 | Standard button, search field |
| `radius-lg` | 12 | List rows, tiles |
| `radius-xl` | 14 | Cards |
| `radius-2xl` | 16 | Hero card, sheet container |

### Elevation / shadow

The Splynek panel is **flat** — no drop shadows on cards.
Border + background lift is the only depth cue. Keep it.

The only exception: the sheet container (Settings, Concierge)
gets `0 24px 64px rgba(0,0,0,0.4)` for modal lift.

---

## Section 1 — Component inventory

Build these as Figma Components first; every frame composes from
them. Specifying state variants on the component spares having to
re-create them for hover/selected/disabled.

### 1.1 `Window`

The macOS NSWindow container.

- Size: **1280 × 800** (default Splynek window per project.yml
  testing).
- Title bar: 28px tall, gradient `bg2 → bg`, traffic-light dots
  top-left (red/yellow/green standard dots, 12px diameter).
- Frame body: gradient canvas (Section 0 spec).

### 1.2 `Sidebar`

Left nav, **220px wide**, full height.

- Background: `panel` with right border `1px solid border`.
- Top: app logo (28×28, `radius-sm`) + "Splynek" wordmark (15px,
  weight 700), padding 20 × 16.
- Tabs: stack vertically with 4px gap, 12px outer padding.
- Each tab row: 40px tall, 12px horizontal padding, `radius-md`
  rounded corners.
- Tab row states:
  - **Idle**: icon `text-dim`, label `text-dim`
  - **Hover**: background `panel-lift`, label `text`
  - **Selected**: background `panel-lift`, label `text`, left
    accent bar (3px wide, `accent`, vertical, inset 0)
- Icon: 18px, SF Symbols. (See Section 1.3 for the four icons.)
- Footer: pinned to bottom, contains the gear icon (28×28,
  hover lift) opening Settings sheet.

### 1.3 `TabIcon` (variants)

Use SF Symbols Mono Bold weight, 18px.

| Tab | Symbol | Hex notes |
|---|---|---|
| Discover | `sparkles` | matches the "help me decide" verb |
| Download | `arrow.down.circle` | active fetch |
| My Apps | `shippingbox` | the "what's installed" container |
| Coordinate | `laptopcomputer.and.iphone` | multi-device |
| Settings (footer) | `gearshape` | utility |

### 1.4 `TopToolbar`

The strip above the content area inside each tab, **52px tall**.

- Background: transparent over canvas.
- Left: subview chips (segmented control, see 1.5).
- Right: primary action buttons + overflow `⋯` menu.
- Bottom border: `1px solid border`.

### 1.5 `SubviewChips`

Pill-style segmented control for subview switching within a tab.

- Each chip: 32px tall, `radius-md`, 14px horizontal padding,
  body-bold label.
- Chip states:
  - **Idle**: transparent background, `text-dim` label
  - **Hover**: `rgba(255,255,255,0.04)` background, `text` label
  - **Selected**: `panel-lift` background, `text` label, accent
    dot 6px before the label
- Gap between chips: 4px.
- Optional: a count badge (small pill, `accent` background,
  10px font) after the label e.g. **Trust Watcher (3)**.

### 1.6 `Button` (variants)

| Variant | Background | Label | Border | Use |
|---|---|---|---|---|
| `primary` | `accent` | `#0B1128` (dark on light) | none | Main CTA |
| `primary-pressed` | `accent-dk` | `#0B1128` | none | Pressed state of primary |
| `secondary` | transparent | `text` | `1px border-lift` | Secondary action |
| `ghost` | transparent | `text-dim` | none | Tertiary (e.g. "Cancel") |
| `danger` | transparent | `red` | `1px red` | Destructive |

All buttons: 36px tall, 16px horizontal padding, `radius-md`,
body-bold weight (14.5px, 600).

### 1.7 `Card`

- Background: `panel`
- Border: `1px solid border`
- Border-radius: `radius-xl` (14px)
- Padding: 22px
- Hover: border `border-lift`, transform `translateY(-2px)`,
  transition 120ms

### 1.8 `ListRow`

The atomic per-app / per-download / per-device row.

- Height: 56px (collapsed) / 80px (expanded with sub-metrics).
- Padding: 12px vertical, 16px horizontal.
- Background: transparent; selected `panel-lift`.
- Border-bottom: `1px solid border` (last row no border).
- Composition (left → right):
  1. Optional 24px icon (app icon or status glyph)
  2. Primary text column:
     - Line 1: `body` text (app/file name)
     - Line 2 (optional): `caption` text dim (metadata)
  3. Status pills inline (see 1.9)
  4. Right-aligned action chips (mini-buttons, 26px tall,
     `radius-sm`)
- States: idle, hover (`panel-lift`), focused (border `accent`
  thin, 1px), disabled (50% opacity).

### 1.9 `StatusPill`

Small inline indicators.

- Height: 22px, `radius-sm`, 8px horizontal padding,
  `tiny` (11px, 600, uppercase) text.
- Colour variants:
  - `good` — `accent` background at 0.14 alpha, `accent` text
  - `warn` — `gold` at 0.14, `gold` text
  - `crit` — `red` at 0.14, `red` text
  - `info` — `purple` at 0.14, `purple` text
  - `neutral` — `rgba(255,255,255,0.06)`, `muted` text

### 1.10 `SearchField`

- 40px tall, `radius-md`.
- Background: `panel`, border `1px solid border`.
- Left icon: `magnifyingglass`, 14px, `muted`.
- Placeholder: `text-dim`.
- Focus: border `accent`.

### 1.11 `Sheet`

Modal overlay for Settings, Concierge, etc.

- Width: 720px (Settings) / 480px (Concierge).
- Height: 80% of window height.
- Background: `panel` with shadow `0 24px 64px rgba(0,0,0,0.4)`.
- Border-radius: `radius-2xl`.
- Backdrop: `rgba(11, 17, 40, 0.6)` over the window.
- Header: 56px tall, title h2 + close button right.
- Body: scrollable.
- Footer (optional): 56px, divider, action buttons right-aligned.

---

## Section 2 — Frame inventory

Eight frames cover the IA's walkable surface. Build each as a top-level
Figma frame, 1280×800. Mark which subview is active using `SubviewChips`
selected state. Use the components from Section 1.

### Frame 1 — `01 Welcome`

The empty-state on first launch (no paired devices, no downloads, no
alerts).

- **Sidebar**: Discover selected.
- **Main content**: a single centered card (max-width 560), 64px from
  top.
  - Hero: `display` text — "Welcome to Splynek"
  - Subhead: `body` dim — "Splynek fixes the broken download
    lifecycle — from picking the right app, to fetching it fast, to
    keeping your installed stack safe."
  - List: 4 bullets, each row 32px tall, custom bullet glyph in
    `accent`:
    - Discover — find apps worth installing
    - Download — get them here, fast
    - My Apps — keep what you have safe
    - Coordinate — sync across your devices
  - CTA: primary button "Tap Discover to start →"
  - Footer: ghost button "Skip the welcome"

### Frame 2 — `02 Discover / Browse`

Default subview after welcome.

- **Sidebar**: Discover selected.
- **TopToolbar**: chips — [ Browse ▸ ] [ Stacks ] [ Ask Splynek ].
  "Browse" selected.
- **Main content**:
  - Hero row (top): `SearchField` full-width — placeholder "Search
    apps: Notes · Music · Cloud storage · Browser…"
  - Below search: a Sovereignty hint card (max-width 720, panel
    background, gold-accent):
    `💡 Your installed stack costs ~$420/yr. Switch the three
    biggest spenders → save $300/yr. [ Show me how → ]`
  - Categories: 4-column grid of `Card`s, each 220×130:
    - Notes (12 apps, avg 78)
    - Music (8 apps, avg 65)
    - Cloud (6 apps, avg 71)
    - Browsers (5 apps, avg 84)
  - Section header: "Recipes for a setup" (`h2`)
  - 3 `Card`s in a row showing curated stacks (Photographer's,
    Privacy-first writer, EU-only essentials) each with 4-5 app
    icons stacked, a price-saved metric.

### Frame 3 — `03 Discover / Stacks`

Same chip nav as Frame 2 with "Stacks" selected.

- Main content: vertical list of recipe `Card`s (full-width),
  each showing:
  - Recipe name + author (h3 + caption)
  - 5 app icons in a row
  - Summary: "5 apps · avg Sovereignty 82 · avg Trust 89 · $0/mo"
  - Right-aligned: primary button "Install this stack"
- Use this frame to test whether non-techies understand
  "curated stacks" as a concept.

### Frame 4 — `04 Download / Now`

The active-downloads view (the lifecycle's middle).

- **Sidebar**: Download selected.
- **TopToolbar**: chips — [ Now ▸ ] [ Active ] [ Done ];
  right: secondary buttons "Pause all" / "Resume all" /
  primary "+ Add URL".
- **Main content**:
  - 2 active downloads, full-width `Card`s:
    - **Ubuntu-25.04-desktop.iso** — 43% progress bar
      (accent-tinted), 3.5 MB/s with split label
      "2.1 MB/s Ethernet + 1.4 MB/s iPhone hotspot", ETA 8 min,
      bytes-done/bytes-total.
    - **Notion-2.7-mac.dmg** — 8% bar, 600 KB/s "LAN peer cache",
      ETA 4 min.
  - Below: a one-line summary strip — "Today: 3 finished · 240
    MB total · 4 hours saved by multi-interface."
  - Each Card has hover-revealed actions: Pause, Cancel,
    Show in Finder.

### Frame 5 — `05 My Apps / Installed`

The IA's marquee surface. **This is the most important frame to
test** — it's the new view that unifies Trust + Sovereignty + Updates
+ Trust Watcher.

- **Sidebar**: My Apps selected.
- **TopToolbar**: chips — [ Installed ▸ ] [ Updates (3) ] [ Trust
  Watcher (1) ]; right: `SearchField`.
- **Main content**:
  - Stack summary card (full-width, 80px tall):
    ```
    Your stack — 47 apps · Sovereignty 73/100 · 3 updates · 1 alert
    [accent-bar 73% filled gauge]
    Top drag: Notion (-12) · [ See alternatives → ]
    ```
  - List of `ListRow`s (sample 6 apps with diverse states):
    1. **Notion** — Sov 32 (warn pill) · Trust 71 (good pill) ·
       `Update available` (action chip primary) ·
       `See alternatives` (chip secondary)
    2. **Spotify** — Sov 54 (warn) · Trust 62 (warn) ·
       ⚠ **ToS changed last week** (crit pill) ·
       `View diff` (chip)
    3. **1Password** — Sov 89 (good) · Trust 95 (good) ·
       Up to date (caption muted) — no actions
    4. **Adobe Photoshop** — Sov 21 (crit) · Trust 64 (warn) ·
       `Update available` · `Migrate → Affinity Photo`
    5. **Anytype** — Sov 95 (good) · Trust 88 (good) · "EU-based,
       open-source" caption · No actions
    6. **VS Code** — Sov 67 (warn) · Trust 78 (good) · Up to
       date · `See alternatives`
- Each row shows the integration of *all four lifecycle concerns*
  in one place: installed state (it's there), update state, trust
  state, and migration option.

### Frame 6 — `06 My Apps / Trust Watcher`

Same parent tab, "Trust Watcher" chip selected.

- Main content:
  - Header: "Watching 12 apps · 1 alert this week"
  - Alert card (full-width, gold-tinted border):
    - App icon + name (Spotify)
    - Caption: "Terms of Service changed · 2026-05-10"
    - Diff summary in mono: snippet of the change ("Section 4.2
      now includes 'AI training' clause...")
    - Actions: primary "Read full diff", secondary "Forget"
  - Below: 11 other watched apps in a compact list, each row
    "✓ stable since {date}".

### Frame 7 — `07 Coordinate / This LAN`

The multi-device coordination tab.

- **Sidebar**: Coordinate selected.
- **TopToolbar**: chips — [ This LAN ▸ ] [ Cloud relay ] [ External ].
- **Main content**:
  - This Mac card:
    ```
    MacBook Pro de Paulo
    192.168.1.20 · port 58680 · cache 4.2/50 GB · uptime 24h
    [ View shared files ] [ Stop sharing ]
    ```
  - Section: "Macs on your LAN"
    - Studio-iMac · Reachable · "shares 2 hot files" — chip
      "Connect"
    - Mac-mini-AV · Asleep · "last seen 1h ago" — chip "Wake"
  - Section: "iPhone Companions"
    - iPhone 17 Pro · Paired · CloudKit relay on — chip "Unpair"
    - iPad · Not paired — primary chip "Pair via QR"
  - Section: "Apple Watch"
    - Apple Watch S11 · Paired via iPhone

### Frame 8 — `08 Coordinate / External`

Same parent, "External" chip selected. Holds the current
"Agents" tab content.

- Main content:
  - Section "API tokens": list of 2 active tokens (label,
    scope pill, last-used caption), primary "Mint token".
  - Section "Browser extensions": Chrome ✓ installed,
    Safari "Install".
  - Section "Raycast": ✓ Extension detected.
  - Section "MCP server": Off · `Turn on` toggle.
  - Section "Web dashboard": URL + Copy button.

### Frame 9 — `09 Concierge sheet`

The Concierge invoked as a sheet from any tab (Discover toolbar
button or My Apps row right-click).

- Sheet width: 480px, height 80% of window.
- Header: "Ask Splynek" (h2) + close button (×) right.
- Body: chat thread (3 turns shown):
  - User bubble: "What's a privacy-respecting alternative to Notion?"
  - Splynek bubble: a card listing 3 candidates (Anytype,
    Obsidian, Logseq), each with mini Sovereignty + Trust
    scores, click-to-add buttons.
  - User bubble: "Will Anytype sync to my iPad?"
  - Splynek bubble: "Yes — multi-device CRDT sync over local
    network. No cloud required."
- Footer: input field (40px tall) + send button + ghost button
  "Open in Discover".

### Frame 10 — `10 Settings sheet`

Gear icon → sheet.

- Sheet width: 720px.
- Left nav (200px): General / Pro license / Helpers / Privacy /
  Advanced / About / Legal.
- Right pane: form for the selected section. Render the General
  section as the default:
  - Toggle: "Start at login"
  - Toggle: "Simple mode" (defaults on)
  - File picker: "Default download folder"
  - Toggle: "Show in menu bar"
- Footer: "Reset first-run experience" (danger button right).

---

## Section 3 — Interaction states needed for testing

The mocks only need to be clickable; not every state needs to
animate. The minimum clickable surface for a tester walkthrough:

| From | Click target | Goes to |
|---|---|---|
| `01 Welcome` | "Tap Discover to start" button | `02 Discover / Browse` |
| `01 Welcome` | Discover sidebar item | `02 Discover / Browse` |
| `02 Discover / Browse` | "Stacks" chip | `03 Discover / Stacks` |
| `02 Discover / Browse` | "Ask Splynek" chip OR sidebar Discover then Ask | `09 Concierge sheet` |
| any | Download sidebar item | `04 Download / Now` |
| any | My Apps sidebar item | `05 My Apps / Installed` |
| `05 My Apps / Installed` | "Trust Watcher (1)" chip | `06 My Apps / Trust Watcher` |
| any | Coordinate sidebar item | `07 Coordinate / This LAN` |
| `07 Coordinate / This LAN` | "External" chip | `08 Coordinate / External` |
| any | Gear icon | `10 Settings sheet` |

10 click targets across the 10 frames. Any test session goes here →
here → here. The frames themselves only need to be visually
complete; nothing animates.

---

## Section 4 — Copy text consolidated

All user-visible strings used across the frames, in en. Cross-check
against the IA proposal for consistency.

### Tab labels (sidebar)

- Discover
- Download
- My Apps
- Coordinate

### Frame 01 — Welcome card

- Hero: "Welcome to Splynek"
- Sub: "Splynek fixes the broken download lifecycle — from picking
  the right app, to fetching it fast, to keeping your installed
  stack safe."
- Bullets:
  - "Discover — find apps worth installing"
  - "Download — get them here, fast"
  - "My Apps — keep what you have safe"
  - "Coordinate — sync across your devices"
- Primary CTA: "Tap Discover to start →"
- Ghost: "Skip the welcome"

### Frame 02 — Discover / Browse

- Search placeholder: "Search apps: Notes · Music · Cloud storage · Browser…"
- Hint card: "Your installed stack costs ~$420/yr. Switch the three
  biggest spenders → save $300/yr. [ Show me how → ]"
- Section header: "Recipes for a setup"
- Recipe names: "Photographer's stack" / "Privacy-first writer" /
  "EU-only essentials"

### Frame 04 — Download / Now

- Card titles: "Ubuntu-25.04-desktop.iso" / "Notion-2.7-mac.dmg"
- Multi-interface label: "2.1 MB/s Ethernet + 1.4 MB/s iPhone hotspot"
- Toolbar: "Pause all" / "Resume all" / "+ Add URL"
- Summary strip: "Today: 3 finished · 240 MB total · 4 hours saved
  by multi-interface."

### Frame 05 — My Apps / Installed

- Summary card line 1: "Your stack — 47 apps · Sovereignty 73/100 ·
  3 updates · 1 alert"
- Summary card line 2: "Top drag: Notion (-12) · See alternatives →"
- Per-row actions: "Update available" / "See alternatives" /
  "Migrate →" / "View diff"
- Critical pill text: "ToS changed last week"

### Frame 07 — Coordinate / This LAN

- This Mac line: "MacBook Pro de Paulo · 192.168.1.20 · port 58680
  · cache 4.2/50 GB · uptime 24h"
- Section headers: "Macs on your LAN" / "iPhone Companions" / "Apple
  Watch"
- Row CTAs: "Pair via QR" / "Wake" / "Unpair" / "Connect"

### Frame 09 — Concierge sheet

- Header: "Ask Splynek"
- Sample query: "What's a privacy-respecting alternative to Notion?"
- Footer ghost: "Open in Discover"

### Frame 10 — Settings sheet

- Sections: General / Pro license / Helpers / Privacy / Advanced /
  About / Legal
- General toggles: "Start at login" / "Simple mode" / "Show in menu
  bar"
- Danger: "Reset first-run experience"

---

## Section 5 — What NOT to mock (yet)

Defer these from the test-mock to keep complexity down:

- Loading skeletons (testers see populated state only).
- Empty states beyond Frame 01 (skip "no downloads yet" / "no apps
  installed yet" — they distract from IA validation).
- Error states (the tester isn't going to encounter them).
- Right-click menus, drag-and-drop.
- The Pro upsell card variations (one consistent card is fine).
- L10n variants — test in English with non-Anglophone testers
  using the en-with-translation moderator protocol from the user
  test script.
- Accessibility annotations (high-contrast, VoiceOver). Critical
  for production; not needed to validate IA labels.
- The Watch view and iPhone Companion views — those are separate
  IAs.

Total time-budget for a designer to build all 10 frames from these
specs: **about one full day**.

---

## Section 6 — Export protocol for the test

After building frames in Figma:

1. **Prototype mode**: wire the 10 click targets from Section 3.
2. **Share link**: enable "Anyone with the link can view" (not
   edit). Generate a Prototype share URL (not the editor URL).
3. **Mobile preview check**: Figma's iPhone preview will likely
   look broken because the frames are 1280×800; that's fine. Tell
   testers it's a Mac mock and they should use a laptop or
   desktop monitor.
4. **Screen-recording consent**: the user-test script (companion
   doc) covers asking testers' permission to record.
5. **Tester-safe URL**: append `?node-id=…` for Frame 01 so the
   tester always lands on Welcome, not whichever frame you were
   last editing.

---

## Section 7 — Acceptance criteria for the mocks

Before running tests, self-check:

- [ ] All 10 frames exist at 1280×800 with the canvas gradient.
- [ ] Sidebar with 4 tabs renders identically across all 10 frames
      (selected state varies per frame).
- [ ] Click-through path from Frame 01 reaches all four tab
      defaults plus at least one subview switch.
- [ ] No "lorem ipsum" — every label is the copy from Section 4.
- [ ] Component variants exist for at least: Button (3 styles),
      StatusPill (4 colours), ListRow (collapsed + expanded).
- [ ] Settings sheet (Frame 10) reachable from at least one
      sidebar gear click.
- [ ] No production-only details visible: don't show real
      bundle IDs, real download URLs, or real keychain tokens
      — use the placeholder values in Section 4.

When all seven boxes are ticked, ship the link to the moderator
and start scheduling sessions.

---

*Document author: Splynek maintainer + Claude. Created
2026-05-13 evening. Pairs with `IA-PROPOSAL.md` (the structure)
and `IA-USER-TEST-SCRIPT.md` (the validation protocol).*
