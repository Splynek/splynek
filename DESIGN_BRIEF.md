# Splynek — logo design brief

A tight spec you can hand to a designer (or use yourself in
Affinity / Figma / Illustrator).

---

## What Splynek is (so the mark has a story)

Splynek is a native macOS download manager that **aggregates every
network interface your Mac has** — Wi-Fi, Ethernet, iPhone tether,
Thunderbolt NIC — and downloads one file over all of them in
parallel. It also acts as a content-addressed cache across a LAN
of Macs (if your colleague already downloaded it, you get it from
them at gigabit).

Brand adjectives: **reliable, technical, quiet, premium**. NOT
playful, NOT novelty, NOT consumer-cute.

## Audience

1. Mac-native developers and power users
2. Small studios / home labs (multi-Mac households)
3. Journalists / researchers / archivists on flaky internet

## Who Splynek sits next to on a dock

Open a typical dev's Dock: Xcode, Terminal, 1Password, Linear,
Figma, Raycast, Arc, Sketch, Kaleidoscope, Things. The logo
needs to feel at home there — understated, confident, high
production value.

## Mandatory constraints

- **Shape**: macOS squircle (superellipse, n≈5 — the
  Apple-standard app-icon outline). Non-negotiable; flat circles
  or hard rectangles look foreign on modern macOS.
- **Format**: vector source (`.svg` or Affinity `.afdesign`).
  Final output: `.iconset` folder → `.icns` via `iconutil`. Sizes
  16, 32, 64, 128, 256, 512, 1024 px, each in @1x and @2x.
- **Must read at 16×16** — the menu-bar / Finder-sidebar size is
  where most macOS icons spend their time. If the concept relies
  on detail that disappears below 32px, it's the wrong concept.
- **Works on any wallpaper** — neutral background treatment (no
  transparent halos that ghost on dark walls). A solid or
  gradient-filled squircle is the Apple way.
- **One focal concept, not a composition**. Apple app icons are
  ONE thing doing ONE thing. Messages = speech bubble. Safari =
  compass. Music = note. Avoid diagrammatic illustrations.

## What to communicate

Pick ONE of these two concepts and commit; don't try to do both:

**Concept A — Download, elevated.**
A single elegant down-arrow. The brand is about *something
arriving*. Sophistication comes from proportions and surface
treatment (gradient + subtle glass highlight), not from
cleverness. Think of the Mail icon's stamp: no one is confused
about what it means, and no one ever noticed the design.

**Concept B — Convergence.**
An abstract mark suggesting many streams becoming one. Pick a
graphical metaphor that's clean enough to read at 16px:
- *Three chevrons nested, pointing down* (radar pulse downward)
- *A drop hitting a surface* (ripple metaphor)
- *A braided cord / single knot* (multi-cable metaphor)
- A letter **S** that arcs into a downward flow — monogram
  style, like Stripe's mark or Figma's F

Avoid: three lines meeting at a point (reads as a chart, not a
brand). Avoid: literal representations of cables or routers.

## Colour

- **Primary palette**: deep dusk blue → near-black gradient.
  Swatches: `#1C366E` top → `#0E1C44` mid → `#06091E` bottom.
  This is the safe default — sits well on both light and dark
  menu bars, doesn't clash with Apple's accent.
- **Optional accent**: a single whisper of indigo or purple —
  use sparingly as a highlight or shadow, not as a fill.
- **The mark itself** (arrow / chevron / letter): white, with a
  very subtle cool gradient (pure white → #E0EAF5 at the tip) so
  it reads as polished rather than flat.
- Avoid: bright blue (reads as Chrome / Facebook / old Windows),
  multi-colour gradients (Instagram-y, wrong register), neon
  (wrong decade).

## Surface treatment

- **Top-left radial highlight** at ~30% opacity, falling off over
  half the canvas. Gives the icon a sense of a light source —
  how Apple's Music, Safari, Reminders all feel alive.
- **Bottom-right vignette** at ~20% opacity. Subtle depth.
- **Inner edge highlight** (1px bright edge at the top of the
  squircle, fading down) — this is the "glass" effect on iOS 16+
  icons. Optional but recommended.
- **Avoid**: hard drop shadows under the mark, emboss / bevel
  effects (both read as circa-2010).

## Typography

If the mark uses a letter (monogram): use **SF Pro Display**,
weight *Bold* (not Heavy, not Regular). Custom-stretched
geometry is fine; literal SF Pro without adjustment is lazy.

## What to deliver

1. `Splynek.icns` (macOS app icon bundle).
2. Standalone PNGs at 16, 32, 64, 128, 256, 512, 1024 px —
   for Chrome extension, Raycast, landing page, README.
3. Source file (`.svg` + `.afdesign` / `.fig`) so we can tweak.
4. A **1-line rationale** — three sentences explaining what the
   mark communicates and why it reads at 16px. If you can't write
   it, the mark isn't doing its job.

## What to explicitly AVOID (from past iterations)

- Three converging diagonal lines with an arrow — reads as a
  data-flow chart, not a brand.
- Horizontal bars beneath the arrow — too literal for
  "destination file".
- Bright primary blue — wrong for premium register.
- Any shape that starts to look like a fishing hook, a funnel,
  or a y-combinator diagram.

## Reference icons to study (not copy)

- Apple Mail (stamp envelope — iconic, quiet)
- Apple Music (note on dusk gradient — the colour is what we
  want)
- Apple Podcasts (concentric curves — "good chevron energy")
- Things (checkmark — unapologetically literal, works)
- Arc (colourful but confident single shape)
- Linear (L monogram, understated)
- Figma (F monogram with geometry)

## Acceptance checklist

- [ ] Recognisable at 16×16 without antialiasing crutches
- [ ] Contrast against a WHITE Finder sidebar — no disappearing
- [ ] Contrast against a BLACK menu bar — no disappearing
- [ ] One focal idea, one compositional axis
- [ ] Feels like it belongs next to Xcode, Terminal, Figma, 1Password
- [ ] Not a data-flow diagram
- [ ] Not another bright-blue download app
