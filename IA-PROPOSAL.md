# IA-PROPOSAL.md

**Lifecycle-based information architecture for Splynek.**

Status: **PROPOSAL** (not implemented). Reviewer should sit with this
for 48 hours; show the four tabs to one non-technical person; if they
can name what each tab does without help, the IA is right. If they
can't, the proposal is wrong — iterate before committing engineering.

Drafted 2026-05-13 in response to the reframe that "downloads are
broken" describes a *lifecycle*, not a feature category. Every
existing Splynek surface maps onto one of four moments in that
lifecycle.

---

## The thesis

**Splynek fixes the broken app-download lifecycle, end to end.**

A normal person installing a new app today goes through four moments,
and at each moment they're poorly served:

| Moment | What they're asking | What they get today (without Splynek) |
|---|---|---|
| **Discover** | "What should I install? Is this app safe? Are there better alternatives — safer, cheaper, more aligned with my values?" | Ad-targeted App Store search; opaque reviews; no privacy info; no alternatives surface |
| **Download** | "Get this here. Quickly. Without giving up." | Browser default download. One TCP connection. Bad Wi-Fi means slow / fail / restart from zero |
| **Care** | "Is this app *still* safe? Did its policy change? Is there an update I forgot?" | Manual checking, alert-fatigue tools, nothing watches policies for you |
| **Coordinate** | "I have three Macs and an iPhone. Make this consistent. Move bytes across them." | Each device is an island; you re-download / re-configure on each one |

Splynek already has features for all four moments. The current 17-tab
sidebar hides that the product is *one* thing solving *one* problem
in four sequential phases.

**The reorg is information architecture, not features.** No code that
implements a tab disappears — it just lives under a different
parent.

---

## The four tabs

| Tab | When you're here | Promise to the user |
|---|---|---|
| **Discover** | I'm thinking about installing something | "Before you click Download, here's what we know" |
| **Download** | I want this file/app on this Mac, now | "Use every network you have. Survive bad Wi-Fi" |
| **My Apps** | I care about what's already on this Mac | "Keep your installed stack safe and current" |
| **Coordinate** | I have more than one device | "Splynek across your machines, in sync" |

A gear icon in the toolbar opens Settings/About/Legal as a sheet,
not a tab. (Apple's macOS convention: `Cmd+,` opens preferences;
preferences aren't a tab.) That removes 3 tabs from the visible IA
immediately.

---

## Every current sidebar entry, mapped

Today's sidebar (17 entries, from `Sources/SplynekCore/Views/Sidebar.swift`):

```
downloads, live, torrents, concierge, recipes, sovereignty, trust,
savings, agents, queue, fleet, apps, benchmark, history, settings,
legal, about
```

Mapped to the new IA:

| Today | New home | Why |
|---|---|---|
| `sovereignty` | **Discover** (browse alternatives) | "Find better apps" is pre-install thinking |
| `trust` (catalog browse) | **Discover** (browse trust scores) | "Is this app safe?" is pre-install thinking |
| `concierge` | **Discover** (Ask Splynek button) + invokable from any tab | "Help me decide" is a verb, not a tab |
| `recipes` | **Discover** (curated stacks) | "Set up like a Notion-replacing photographer" is a pre-install browse |
| `savings` | **Discover** (under "Why this matters") | The lever: "you'd save $300/yr by switching X" reinforces Discover |
| `queue` | **Download** (default subview) | The current main download view |
| `live` | **Download** (subview: Now) | Live throughput is a moment |
| `downloads` | **Download** (subview: Active) | Active downloads — redundant with `live` & `queue` today |
| `torrents` | **Download** (subview: Torrents) | A protocol filter, not a separate concept |
| `benchmark` | **Download** (under "Speed test" action in toolbar) | A diagnostic, not a tab |
| `history` | **Download** (subview: Done) | "What did I download" is the third moment in this tab |
| `apps` (Install + Updates) | **My Apps** (default subview: Installed) | "What I have" is post-install thinking |
| Trust Watcher card (inside `trust` today) | **My Apps** (default surface) | "What's changing about my apps" is post-install thinking — the marquee Pro feature |
| Migrate (action inside `sovereignty` today) | **My Apps** (action surface) | "Replace what I have" is post-install thinking |
| `fleet` | **Coordinate** (default subview: This LAN) | "My Macs talking to each other" is coordination |
| `agents` | **Coordinate** (subview: External) | iPhone pairing, MCP, API tokens — all about external machines connecting in |
| `settings` | Gear icon in nav, sheet | Apple convention; not a tab |
| `legal` | Inside Settings sheet | Bookkeeping; not a tab |
| `about` | Inside Settings sheet | Bookkeeping; not a tab |

**17 → 4.** Every feature has a home. Three sub-views per main tab on
average (Download has the most: Now/Active/Torrents/Done plus
Speed-test action). The toolbar gear handles utility navigation.

---

## What each tab actually looks like

### Discover

```
┌─────────────────────────────────────────────────────────────────┐
│  Discover           [ Browse ] [ Stacks ] [ Ask Splynek ]       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Hero row — "What are you looking for?"                         │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  🔍  Notes app · Music · Calendar · Cloud storage…     │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                 │
│  Categories                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ Notes    │ │ Music    │ │ Cloud    │ │ Browser  │            │
│  │ 12 apps  │ │ 8 apps   │ │ 6 apps   │ │ 5 apps   │            │
│  │ avg 78   │ │ avg 65   │ │ avg 71   │ │ avg 84   │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
│                                                                 │
│  Recipes for a setup ─────────────────────────────                │
│   • Photographer's stack (5 apps)                               │
│   • Privacy-first writer (3 apps)                               │
│   • EU-only essentials (8 apps)                                 │
│                                                                 │
│  ──────────────────────────────────────────────────             │
│  💡 Did you know?  Your installed stack costs ~$420/yr.         │
│      Switching the three biggest spenders would save $300/yr.   │
│      [ Show me how → ]                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

- **Browse** subview: searchable list of apps with Trust + Sovereignty
  scores; filterable by category, by EU-only, by open-source, by price
- **Stacks** subview: curated recipes — "If you want X, here's the
  best opinionated set"
- **Ask Splynek**: invokes the Concierge pane (modal or right-side
  pane). NOT a tab; a verb you can also invoke from My Apps' top-right.

### Download

```
┌─────────────────────────────────────────────────────────────────┐
│  Download         [ Now ] [ Active ] [ Done ] [ + Add URL ]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Now — live throughput                                          │
│   ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░  43%  Ubuntu-25.04-desktop.iso              │
│   2.1 MB/s + 1.4 MB/s = 3.5 MB/s · Ethernet + iPhone hotspot     │
│   ETA 8 min                                                     │
│                                                                 │
│   ▓▓░░░░░░░░░░░░░░░  8%   Notion-2.7-mac.dmg                    │
│   600 KB/s · LAN peer cache                                     │
│   ETA 4 min                                                     │
│                                                                 │
│  ──────────────────────────────────────────────────             │
│  Toolbar: [ Pause all ] [ Resume all ] [ Speed test ]           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

- **Now** subview: live downloads, throughput, multi-interface
  visualization (the bonded fetch's value made visible)
- **Active** subview: queued/paused/in-progress including BitTorrents
- **Done** subview: history with search, "Forget this entry" per row
- **+ Add URL** toolbar button: paste / drop a URL or magnet
- **Speed test**: toolbar action that runs the benchmark (was a tab)

### My Apps

```
┌─────────────────────────────────────────────────────────────────┐
│  My Apps    [ Installed ] [ Updates ] [ Trust Watcher (3) ]     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Your stack — 47 apps · Sovereignty 73/100 · 3 alerts           │
│  ┌────────────────────────────────────────────────────────┐     │
│  │  Sovereignty:  ████████████░░░░░  73                   │     │
│  │  Top drag:     Notion (-12)  → see alternatives        │     │
│  │  Updates:      3 ready                                 │     │
│  │  Trust diff:   Spotify ToS changed last week           │     │
│  └────────────────────────────────────────────────────────┘     │
│                                                                 │
│  Installed (47)                                                 │
│   • Notion           Sovereignty 32  Trust 71  Update available │
│   • Spotify          Sovereignty 54  Trust 62  ⚠ ToS changed    │
│   • 1Password        Sovereignty 89  Trust 95  ✓ current        │
│   …                                                             │
│                                                                 │
│  Per row: [ Update ] [ See alternatives ] [ Migrate → ]          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

- **Installed** subview: the canonical "what's on this Mac" inventory
  with combined Trust + Sovereignty + Update + Trust-Watcher status
  per row.  **This is new** — today these are scattered across three
  tabs.
- **Updates** subview: just the apps with updates ready (action-only
  filter on Installed)
- **Trust Watcher** subview: the alert feed (was a card-inside-Trust)
- Migrate is a per-row action, not its own surface

This is the **biggest IA win**. It surfaces three separate concerns
about installed apps in one place where users naturally look.

### Coordinate

```
┌─────────────────────────────────────────────────────────────────┐
│  Coordinate    [ This LAN ] [ Cloud relay ] [ External ]        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  This Mac — MacBook Pro de Paulo                                │
│   192.168.1.20 · port 58680 · 24h uptime · cache 4.2 GB / 50 GB │
│                                                                 │
│  Macs on your LAN                                               │
│   • Studio-iMac    Reachable  ·  shares 2 hot files             │
│   • Mac-mini-AV    Asleep     ·  last seen 1h ago               │
│                                                                 │
│  iPhone Companions                                              │
│   • iPhone 17 Pro  Paired  ·  CloudKit relay enabled             │
│   • iPad           Not paired  ·  [ Pair via QR ]                │
│                                                                 │
│  Apple Watch                                                    │
│   • Apple Watch S11  Paired (via iPhone Companion)               │
│                                                                 │
│  ──────────────────────────────────────────────────             │
│  External tools that can talk to Splynek                        │
│   • API tokens    2 active     [ Mint ] [ Revoke ]              │
│   • Raycast       Extension installed                           │
│   • MCP server    Off          [ Turn on ]                      │
│   • Web dashboard splynek.app/dashboard  [ Copy link ]          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

- **This LAN** subview: the Fleet view, expanded with this Mac's own
  status, peer Macs, paired phones
- **Cloud relay** subview: CloudKit relay status, iPhone Companion
  pairing state, last-relayed counts
- **External** subview: the Agents tab content (API tokens, MCP,
  Raycast, web dashboard) — anything that's a *thing connecting in*

---

## Settings (sheet, not tab)

Gear icon top-right of the main window opens a sheet with the
existing SettingsView content reorganized into:

- General — start at login, simple/power mode, default download dir
- Pro license — purchase, restore, manage
- Helpers — browser extensions, local AI, MCP, background mode
- Privacy — engagement viewer, what's recorded, what's transmitted
- Advanced — flag toggles, debug
- About — version, credits
- Legal — privacy policy, terms, MIT license

`Cmd+,` opens the same sheet. Standard macOS pattern.

---

## What's NOT covered by reorganization alone

Three product-debt observations that surfaced doing the mapping:

1. **The Installed inventory in My Apps is a new view.** Today there
   is no single place that combines Trust + Sovereignty + Update +
   Trust-Watcher per app. The data exists in `SovereigntyStore`,
   `TrustStore`, `UpdatesView` state, and `TrustWatchStore`; joining
   them into one row-per-app needs new VM glue (~1 day of work).

2. **"Sovereignty for your stack" is also new.** Today
   `SovereigntyView` shows a catalog-level score. The user-stack-level
   roll-up ("your installed apps average 73/100, here's the biggest
   drag") needs `SovereigntyStackSummary` aggregation. ~1 day.

3. **Concierge as a verb, not a noun**, is a UX rewrite. Today
   `ConciergeView` is a tab; in the new IA it's a sheet/pane invokable
   from Discover and My Apps. The Concierge code is mostly fine; only
   the entry point and a parent-context binding need to change. ~0.5
   days.

Estimated total work added by the reorg (beyond mechanical
view-shuffling): ~2.5 days of NEW capabilities that make the IA more
than rearrangement.

---

## Rules for "where does a future feature live?"

When adding a new feature, ask: *which of the four moments is the
user in when they need this?*

- **Discover** = anything that helps the user decide *before* they
  download / install
- **Download** = anything that happens *during* the fetch
- **My Apps** = anything about apps already on this Mac, persistent
  over time
- **Coordinate** = anything about more than one device, or external
  things talking to Splynek

If a feature genuinely spans two moments, put it in the *earlier* one
and link to the next. (Example: the Migrate action lives in My Apps
because the user is reacting to an installed app, but tapping it
opens the same Sovereignty browse experience as Discover.)

If a feature doesn't fit any of the four — **don't build it**. That's
the IA's discipline. Feature creep that doesn't earn a place in the
lifecycle is feature creep that confuses the user.

---

## First-run under this IA

The `SIMPLE-MODE-FIRSTRUN.md` spec I drafted earlier is now
**superseded**. Persona-based tab hiding was a workaround for the
noun-based IA. Under the lifecycle IA, no persona selection is
needed — every user gets the same four tabs in the same order, and
the order itself teaches the mental model.

First-run becomes simpler: a single welcome card on the Discover
tab that says **"Welcome to Splynek. Tap through the four tabs once
to see what's here."** Dismissible. Three lines of code. No wizard.

If we later want personalization, it can be done at the *subview*
level (e.g., default to My Apps if `installed apps > 0` and
`trust-watcher-alerts > 0`), not at the tab level.

I'll archive `SIMPLE-MODE-FIRSTRUN.md` with a header pointing here.

---

## Wireframe — the empty state

The first launch of v2.0.1+ on a Mac with no paired devices, no
downloads, no Trust Watcher activity yet:

```
┌──────────────────────────────────────────────────────────────────┐
│ ◉ Splynek                                              ⚙        │
├─────────────┬────────────────────────────────────────────────────┤
│             │                                                    │
│  Discover • │       Welcome to Splynek                           │
│  Download   │                                                    │
│  My Apps    │  Splynek fixes the broken download lifecycle —    │
│  Coordinate │  from picking the right app, to fetching it        │
│             │  fast, to keeping your installed stack safe.       │
│             │                                                    │
│             │  Four tabs, in order:                              │
│             │                                                    │
│             │   • Discover — find apps worth installing          │
│             │   • Download — get them here, fast                 │
│             │   • My Apps — keep what you have safe              │
│             │   • Coordinate — sync across your devices          │
│             │                                                    │
│             │     [ Tap Discover to start →  ]                   │
│             │                                                    │
└─────────────┴────────────────────────────────────────────────────┘
```

No tour, no checklist, no progress bars. Just four sentences and a
hint. The product teaches itself by being walked through once.

---

## Implementation plan (rough)

Once the proposal is approved (or revised + re-approved):

| Phase | Days | What |
|---|---|---|
| **0. Approval + user test** | 2 | Show 3 non-techies the four-tab mock; they each describe what they think each tab does; if 2/3 are roughly right per tab, ship; if not, iterate |
| **1. New tab enum + Sidebar** | 0.5 | Replace 17-case enum with 4-case enum; old enum kept around as `Sidebar.LegacyTab` for migration paths |
| **2. View shuffling** | 2 | Each existing view becomes a subview of one of the four parents; one-to-one move, no logic change |
| **3. New Installed inventory view** | 1 | The combined-data row-per-app view in My Apps |
| **4. New Sovereignty stack summary** | 1 | The "your stack averages X" aggregate |
| **5. Concierge as sheet** | 0.5 | Remove from sidebar, wire as invokable pane |
| **6. Settings sheet** | 0.5 | Move from tab to gear-icon sheet |
| **7. First-run welcome card** | 0.25 | The four-bullet card in Discover |
| **8. L10n** | 0.5 | ~25 new strings × 5 locales |
| **9. Tests + smoke** | 1 | Update navigation tests; release-smoke unchanged |

**Total: ~9 days from approval to merged-to-main.**

The view-shuffling phase is the riskiest. Every existing tab's URL
schemes, deep links, AppleScript dictionary, App Intents references,
and `splynek://` URL handlers may reference the old tab IDs. We need
a deprecation map (`old.tab.sovereignty → new.tab.discover.browse`)
that the App Delegate handles transparently for one release before
removing.

---

## What user testing should validate

Before we cut any code, three falsifiable claims:

1. **Three non-technical adults shown the four-tab labels can each
   describe (in their own words) what each tab does, with ≤1 wrong
   guess per person.** If they consistently confuse Discover with My
   Apps, or Coordinate with Settings, the labels are wrong.

2. **A power user shown the new IA can find every feature they used
   in v2.0.1 in <30 seconds.** Specifically: torrents (Download tab,
   any subview), API tokens (Coordinate → External), Speed test
   (Download toolbar). If they can't, the discoverability of moved
   features is too low.

3. **A new user opens the app and intuitively taps Discover first.**
   The tab order — Discover, Download, My Apps, Coordinate — should
   guide that. If they tap Download first, the labels aren't pulling
   the right way.

Tests 1 and 3 need real humans. Test 2 we can do internally.

---

## Open questions

- **Is "Coordinate" the right label?** Alternatives: "Devices", "Your
  setup", "Across machines". "Coordinate" is verb-y which fits the
  lifecycle theme but might read as jargon. User testing settles it.

- **Should Recipes be its own thing or live in Discover?** Curated
  multi-app setups are arguably their own category. My instinct: live
  in Discover as a sub-section, surface in My Apps when you've
  adopted one ("You have 3 of 5 from the Photographer stack — install
  the missing 2?"). If usage data shows Recipes drives a lot of
  installs we can promote it to its own tab in v3.

- **Where does Savings live?** I parked it in Discover as motivation
  ("here's what you'd save"), but it's also a celebration after
  switching (My Apps). Probably belongs in both — a single number on
  Discover hero, a per-app breakdown in My Apps. Same view component
  rendered in two parents.

- **Trust+ subscription gate UI placement?** Today the engagement
  gate fires in Settings. Under the new IA, the natural surfacing is
  on the Trust Watcher subview after enough alerts ("Want weekly
  catalog refreshes? Try Trust+"). Settings keeps the toggle. The
  CTA moves to where the user is feeling the value.

- **Power users / dense view per tab?** The Download tab's three
  subviews (Now/Active/Done) can get noisy for someone with 40
  active downloads. Do we need a `Tools → ` menu in each tab for
  power affordances? Maybe — but not in v1 of the IA. Ship simple
  first; add Tools menus when real users hit walls.

---

## What this DOESN'T solve

Honest accounting:

- **Doesn't fix the brand pivot question.** Splynek is still called
  Splynek. If we later decide Trust Watcher should be the brand and
  Splynek the feature, the IA tabs still work — "Trust" is the My
  Apps surface in this design — but the brand decision is separate
  from the IA decision. Sequenced, not coupled.

- **Doesn't add new product capabilities** beyond the three small
  joins (Installed inventory, Sovereignty stack summary, Concierge
  sheet). The product remains what v2.0.1 ships; the IA just makes
  it legible.

- **Doesn't replace user testing.** This document is one person's
  opinion turned into a structure. Three non-technical adults
  walking through the mock will tell us more than 100 more pages of
  thinking. Spend the next 2 days on that, not on revising this doc.

---

## Decision request

If you approve this IA, the next concrete action is to **mock the
four tabs in Figma (or paper) and find three non-techie testers**.
That's a 1-2 day effort. Engineering doesn't start until tests pass
claims (1) and (3) above.

If you reject this IA, the next action is to articulate which of the
four moments is wrong, or which feature genuinely doesn't fit. The
mapping table at the top is the testable artifact — disagreement
should point at a specific row, not at the framing.

If you partially approve (e.g., love three of the four tabs, hate
the fourth), say which. The fix is probably a label change, not a
re-architecture.

---

*Document author: Splynek maintainer + Claude. Created 2026-05-13
afternoon. Supersedes `SIMPLE-MODE-FIRSTRUN.md` (which is now
archived as a historical record of an earlier framing).*
