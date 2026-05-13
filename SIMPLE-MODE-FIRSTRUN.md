# SIMPLE-MODE-FIRSTRUN.md

Design spec for the first-run experience that turns Splynek from
"power-user download manager" into "a thing for everyone".

Status: **DESIGN** (not implemented). Sprint 10 candidate, post-Apple-v1.0
clearance. Mocks live in the [Wireframes](#wireframes) section below.

---

## The problem

Splynek today opens to the Fila (queue) tab with seven sibling tabs
visible: Sovereignty, Trust, Recipes, Concierge, Agents, History,
Settings (plus Pro-only tabs). For a first-time user, that's seven
nouns competing for attention before they know what the app does for
them.

Two audiences are getting the same surface today:

- **Power users** want every tab. They know what Recipes means.
  Splynek is fine for them. Don't break their flow.
- **Everyday users** (your mother, your non-technical friend, a
  teenager who heard about "the app that watches privacy changes")
  want one screen with the answer. Splynek today drowns them in
  affordances.

The fix is not "redesign the whole app". The fix is **route each user
to the tab subset that matches their actual purpose** on first launch.

---

## The 3 questions

After install, the first launch opens a single full-window pane (not
a sheet — it's the entire app for the first minute) with three
questions, one screen each, with a back arrow and a progress dot
trio. **Each question has exactly two large tappable answers**.

Soft, friendly tone, no jargon. Splynek-green accent. The questions
are deliberately not "tick the features you want" — that's an
engineer's framing. They're "what brought you here", which is a
user's framing.

### Q1. *"What brings you to Splynek today?"*

| Answer | Maps to |
|---|---|
| **I want to know when an app I use changes its privacy or terms.** | `persona.trustwatcher` |
| **I want to find apps that aren't owned by US tech giants.** | `persona.sovereignty` |

If the user picks one, also offer a small ghost-button link below:
"Both, actually" → sets `persona = .both`.

### Q2. *"Do you also download large files?"*

| Answer | Maps to |
|---|---|
| **Sometimes — videos, ISOs, that sort of thing.** | `downloader = .occasional` |
| **All the time. Show me the power tools.** | `downloader = .power` |

If `.power`, we silently set `persona |= .powerUser` regardless of Q1.

### Q3. *"Want your iPhone to talk to your Mac?"*

| Answer | Maps to |
|---|---|
| **Yes, set up the iPhone Companion later.** | shows the iPhone-companion banner in the sidebar |
| **No, just the Mac is fine.** | no banner |

End with **Let's go →**. Total first-run interaction: 4 taps, ~20
seconds.

---

## How the answers shape the UI

The persona maps to a `UIMode` enum persisted in App Group
UserDefaults:

```swift
enum UIMode: String, Codable {
    case trustFirst    // Q1 = trustwatcher, downloader = .occasional
    case sovereigntyFirst  // Q1 = sovereignty, downloader = .occasional
    case powerUser     // any answer + downloader = .power, or Q1 = .both
    case companionFocus    // explicit "just my Mac, focus on iPhone link"
}
```

### `UIMode.trustFirst` (the everyday-user default)

Default tab on next launch: **Trust** (not Fila).

Sidebar shows only:
- **Trust** — landing screen, prominent "Watching N apps · X alerts"
- **Sovereignty** — collapsed to a single "Find better alternatives" card
- **Settings** — same as today

Hidden behind a `Show power features` button at the bottom:
- Fila, Frota, Recipes, Agents, History, Concierge

The hidden tabs are still there in the codebase and one click reveals
them. We're not making the user incapable of accessing power
features — we're making them invisible until invoked.

### `UIMode.sovereigntyFirst`

Default tab: **Sovereignty**.

Sidebar prominent: Sovereignty + Trust. Everything else hidden behind
"Show power features".

### `UIMode.powerUser`

Default tab: **Fila** (today's default). Sidebar shows everything.
Functionally identical to the current app. The 3-question flow is
the only departure from today; once "power user" is picked,
everything looks the same.

### `UIMode.companionFocus`

Default tab: **Trust**, plus a persistent banner at the top of every
view: "**Pair your iPhone →**" that opens the existing pairing UI.
Banner dismisses after a successful pair OR after 7 days, whichever
comes first.

---

## Wireframes

ASCII because anything fancier is premature. Real Figma after
this spec is reviewed.

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│                       Splynek                           │
│                                                         │
│   What brings you to Splynek today?                     │
│                                                         │
│   ┌───────────────────────────────────────────────┐     │
│   │  🔔  I want to know when an app I use         │     │
│   │      changes its privacy or terms.            │     │
│   └───────────────────────────────────────────────┘     │
│                                                         │
│   ┌───────────────────────────────────────────────┐     │
│   │  🛡  I want to find apps that aren't owned    │     │
│   │      by US tech giants.                        │     │
│   └───────────────────────────────────────────────┘     │
│                                                         │
│                            Both, actually               │
│                                                         │
│                      ● ○ ○                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   Do you also download large files?                     │
│                                                         │
│   ┌───────────────────────────────────────────────┐     │
│   │  📥  Sometimes — videos, ISOs, that            │     │
│   │      sort of thing.                            │     │
│   └───────────────────────────────────────────────┘     │
│                                                         │
│   ┌───────────────────────────────────────────────┐     │
│   │  ⚡  All the time. Show me the power tools.    │     │
│   └───────────────────────────────────────────────┘     │
│                                                         │
│                 ← Back        ○ ● ○                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Open questions for review

1. **Should Q1 have a third option** ("I'm just curious")? Defaulting
   to `trustFirst` may be wrong for someone who came from a "Splynek
   downloads things in parallel" Show HN headline. Counter-argument:
   they hit "All the time. Show me the power tools" in Q2 anyway.

2. **"Power features" — is that the right label?** Alternatives:
   "Advanced", "Show all tabs", "Open the toolkit", "More". User
   testing should settle it.

3. **Should `powerUser` see the 3-question flow at all?** Skip-flow
   for users who launch from the Pro license activation page? A
   single "Already a power user? Skip" link at the bottom of Q1.

4. **Reset path**: Settings → Reset first-run? Or only via support
   docs ("hold ⌘ at launch")? Probably visible, so people who picked
   wrong can recover without re-installing.

5. **What about MAS-distributed builds vs DMG?** DMG users self-select
   into "I'm comfortable installing apps myself" → they're more
   likely powerUser. MAS users are mostly trustFirst. We can use
   that as a prior, defaulting the radio buttons accordingly.

6. **Pro tier feature?** Should Simple Mode be a Pro feature
   (incentive to subscribe), or always-free? Argument for free: this
   is the brand on-ramp; charging for it sabotages the funnel.
   Argument for Pro: power users likely buy Pro, so they don't see
   it. Default: **always free**. Pro buys you tools, not the
   on-ramp.

---

## Implementation surface (rough)

When this becomes a sprint, the touch points are:

- **New view**: `Sources/SplynekCore/Views/FirstRunView.swift` —
  3-screen SwiftUI flow, persisted to App Group `UserDefaults` key
  `splynek.firstRun.completed = true`.
- **New model**: `Sources/SplynekCore/UIMode.swift` — the enum
  above + a single `@AppStorage("splynek.uiMode")` source of truth.
- **Sidebar gating**: `Sources/SplynekCore/Sidebar.swift` reads
  `UIMode` and conditionally hides tabs.  Existing tab definitions
  unchanged.
- **Settings**: add **Mode** card with three radio buttons
  (Trust-first / Sovereignty-first / Power user) + **Re-run
  first-run wizard** button.
- **Tests**:
  - `UIModeTests` — every `UIMode` returns a non-empty tab list
  - `FirstRunPersistenceTests` — answers round-trip correctly
  - `SidebarGatingTests` — `.trustFirst` mode hides exactly the
    expected set

No new entitlements. No new permissions. No new dependencies.

---

## Estimated effort

- Design (this doc): **done**.
- Figma + 3 user interviews against the mocks: **4 days**.
- Implementation: **3 days**.
- L10n across 5 locales (~30 new strings): **0.5 days**.
- QA + smoke against every UIMode path: **0.5 days**.

**Total: ~8 days from sign-off to merged-to-main.** Slots in
naturally as Sprint 10 after Apple v1.0 clears and we've reacted
to the press wave's feedback.

---

## Why not just rebrand to Trust Watcher?

Discussed in HANDOFF Option C (the "bold" simplification). Two
problems:

- It throws away the existing Splynek brand recognition. We're
  in `homebrew-splynek`, we have v2.0.1 cask refs, we have
  `splynek.app`. A rename is a one-way door we can't easily
  reverse if it doesn't land.
- It conflates two products. Splynek's download engine is
  legitimately useful for the *power user* segment that wants
  bonded multi-interface fetches and BitTorrent v2. Killing
  that surface drops a real audience.

Simple Mode keeps both audiences served, gates them, and lets
us track which one grows faster via telemetry. It's the
strategic middle that A/B-tests our bet without committing to
the brand pivot too early. If `trustFirst` proves dominant for
six months, *then* we rebrand.

---

*Document author: Splynek maintainer + Claude. Created
2026-05-13 afternoon, post-v2.0.1 ship.*
