# IA-USER-TEST-SCRIPT.md

Moderator script for the three-non-technical-adult validation
sessions that gate the lifecycle-IA proposal in `IA-PROPOSAL.md`.

**Goal:** answer "is the four-tab IA legible to a non-technical
person?" before any engineering time is spent on the reorg.

**Format:** one moderator, one tester at a time, ~30 minutes each.
Three sessions total. Use the Figma prototype built from
`IA-WIREFRAMES.md`. Sessions can be in-person, over a video call
with screen-share, or via TestingTime / Maze if remote — same
script either way.

**Outcome:** a decision document at the end of session 3 — go,
no-go, or iterate-and-retest.

---

## Recruiting

### Tester profile

Recruit **three adults who fit ALL of**:

1. Use a Mac as their primary computer for more than three months
2. Have **not** worked in software / IT / design / engineering in
   the last 10 years
3. Don't currently use any download manager (no JDownloader, no
   Folx, no Transmission as a primary tool — Safari's built-in
   downloads is fine)
4. Have heard of "Privacy Policy" but couldn't define "Terms of
   Service" precisely if asked

A good shorthand: **your mother, your accountant, a school
teacher**. Bad fit: anyone who has ever opened Terminal voluntarily.

Diversity across testers: age 25-65, mix of professions, at least
one **not** in your immediate social circle (someone who can be
honest with you without social pressure).

### Compensation

If you can: €30 / $30 gift card per session. Their time is real
and being asked to think out loud for 30 minutes is work.

### Logistics

- Sessions of ~30 minutes each
- Record screen + audio with **explicit consent** (see Intro
  script below)
- Recordings used only for internal review; deleted after the
  decision
- Quiet environment, no observers besides moderator

### Scheduling

Run the three sessions over 2-3 days, not the same day.
**Reason:** moderator fatigue alters how the questions get asked,
which contaminates the results. Sleep on session 1 before
session 2.

---

## What the moderator brings

- The Figma prototype URL (set to land on Frame 01 — Welcome)
- A laptop with a 13"+ screen (1280×800 minimum), positioned
  so the tester drives the mouse
- A second device or notepad for the moderator's notes
- A scoring sheet (Section 4 below), one per tester
- Screen-recording tool (QuickTime is fine)
- Optional: a one-page printed glossary the tester can ask for
  if they get stuck — but **don't volunteer it**

---

## Session structure (~30 min)

```
0:00 — 0:03  Intro + consent
0:03 — 0:08  Task 1: Label legibility (Claim 1)
0:08 — 0:18  Task 2: Find-the-feature (Claim 2)
0:18 — 0:24  Task 3: First-tap intuition (Claim 3)
0:24 — 0:30  Debrief + thanks
```

Timing is approximate — don't rush a tester who's mid-thought. If
the session goes 40 minutes, that's fine. If it goes 50, something
in the design is grabbing attention worth investigating.

---

## Section 1 — Intro + consent (3 minutes)

Read this verbatim. Don't paraphrase — consistency across
sessions is what makes results comparable.

> *"Hi [name]. Thank you for doing this. I'm going to show you a
> design mock for a Mac app called Splynek. The app is not built
> yet — these are just pictures of what we're thinking about. I
> want to see if the design makes sense to people who haven't used
> it before.*
>
> *There are no wrong answers. I'm testing the design, not you.
> When you click something that doesn't work or seems confusing,
> that's useful information — it tells me the design needs to
> change.*
>
> *Three things to keep in mind:*
>
> *First, please think out loud. Tell me what you're looking at,
> what you expect to happen, what you're confused by. Even if it
> feels obvious, say it.*
>
> *Second, I'm going to be quiet a lot. That's not because you're
> doing something wrong — it's because if I keep talking, I'll
> lead you. I'll only step in if you're truly stuck.*
>
> *Third, I'm going to record the screen and the audio. The
> recording stays on my laptop and gets deleted after we make a
> decision. Are you OK with that?"*

**Wait for explicit "yes" before starting the recording.**

If they hesitate or say no: thank them, end the session, find
another tester. Don't try to argue. (This rarely happens; mention
the compensation up front when scheduling.)

After recording starts:

> *"Great. I'm going to ask you three short tasks. Drive the
> mouse — I won't touch the laptop. Ready?"*

---

## Section 2 — Task 1: Label legibility (5 minutes)

Validates **Claim 1: three non-technical adults shown the four-tab
labels can each describe (in their own words) what each tab does,
with ≤1 wrong guess per person.**

### Setup

Open the Figma prototype on Frame 01 (Welcome). **Do not let the
tester click yet.** They should see the welcome card and the
sidebar with four tabs.

### Script

> *"You're looking at the Welcome screen of Splynek. On the left
> you see four tabs. Without clicking anything yet, can you read
> the four tab names out loud and tell me, in your own words,
> what you think each one does?*
>
> *Take them in order, top to bottom. Don't guess what the app
> as a whole does — just each tab."*

### What to do during

- **Be silent.** Let them read and ramble.
- For each tab, the tester will say something like *"Discover…
  hmm, I guess that's like, finding new apps?"*
- After they finish, ask one clarifying question per tab if
  needed: *"And what kind of apps?"* or *"What do you mean by
  'find'?"*
- Do **not** correct them. Even if they're wrong. Even if they
  look at you expecting confirmation. Just nod and move on.

### What to record per tab

For each of Discover / Download / My Apps / Coordinate, score:

| Score | Meaning |
|---|---|
| **3 — Right** | Their description matches the IA proposal's intent. e.g. for Discover: "Find new apps", "Browse apps you might want", "Help me pick" |
| **2 — Adjacent** | Their description is close but slightly off. e.g. Discover: "Things Splynek wants me to look at", "Recommendations" |
| **1 — Wrong** | Their description is genuinely off. e.g. Discover: "Settings", "What's new in the app" |
| **0 — Refused** | They couldn't or wouldn't guess |

Verbatim quotes matter more than scores. Write down the actual
words. The pattern across three testers is what informs label
decisions.

### Pass criteria

Claim 1 passes if **across all three testers, ≥9 of 12 scores
are 2 or 3** (≥75%). Wrong/refused tolerated up to 3 across the
whole study.

If any one tab scores Wrong from 2/3 testers: that label is
broken. Rename it before retest.

---

## Section 3 — Task 2: Find-the-feature (10 minutes)

Validates **Claim 2: a power user shown the new IA can find every
feature they used in v2.0.1 in <30 seconds.**

Note: Claim 2 is **for a power user, not a non-techie.** The
non-techie testers run the *non-power* version below; one
additional power-user session (you, after a 24h gap) validates
Claim 2 strictly. The non-techie's variant tests a related but
gentler claim:

> *"Three non-technical adults can find at least 4 of 5 simple
> features in <60 seconds each, without instruction."*

### Setup

> *"I'm going to ask you to find five things in this app. The
> mock is clickable — you can navigate as you would normally.
> When you find each thing, tell me. If you can't find it after
> a couple of minutes, tell me you'd give up — that's a fine
> answer."*

### The five tasks

Read them one at a time, wait until the tester finds it or gives
up before reading the next.

| # | Task | Expected path |
|---|---|---|
| 1 | "Find where you'd go to **see what you've already downloaded** (download history)." | Download → Done chip |
| 2 | "Find where you'd go to **check if Spotify changed its Terms of Service**." | My Apps → Trust Watcher chip |
| 3 | "Find where you'd go to **pair this Mac with your iPhone**." | Coordinate → This LAN OR Coordinate (any subview, the iPhone section is visible) |
| 4 | "Find where you'd **add a new download** by pasting a URL." | Download tab → "+ Add URL" toolbar button |
| 5 | "Find where you'd go to **change which folder your downloads go into**." | Gear icon → Settings sheet → General |

### What to record per task

- **Time to find** (seconds, from "you finish reading the task" to
  "tester says found")
- **Path taken** (which tabs/clicks before they got there)
- **Gave up** (yes/no — if yes, after how long)
- **Quote** (what they said while searching — especially the
  point they tabbed/hovered without clicking)

### Pass criteria

Claim 2 (non-techie variant) passes if **each tester finds ≥4 of
5 tasks in <60s each**, and **no task is consistently failed by
2/3 testers**.

Patterns that mean the IA needs revision:
- 2/3 testers click Discover first looking for downloads → tab
  order is wrong
- 2/3 testers can't find Trust Watcher → it's hidden too deep,
  promote to its own chip-button or even tab
- 2/3 testers look in My Apps for pairing → "Coordinate" label is
  misleading, try "Devices" or "Sharing"

---

## Section 4 — Task 3: First-tap intuition (6 minutes)

Validates **Claim 3: a new user opens the app and intuitively
taps Discover first.**

### Setup

Reset the prototype to Frame 01 (Welcome) **without telling
the tester**. Pretend it's a new session within the test:

> *"OK, I'm going to show you the app one more time as if you
> just installed it. You'll see the same Welcome screen. Don't
> read the welcome — close your eyes for two seconds while I
> set it up."*

Click in the canvas to hide any tooltips, then:

> *"Open. If this were YOUR Mac and you just installed this app,
> which tab would you click first? Don't think about it — just
> click."*

### What to record

- **First click** (which sidebar item OR the welcome's CTA OR
  the gear icon OR something else)
- **Time to click** (seconds — was it instant or did they hover
  first?)
- **Tester's reason** (ask after the click: *"Why that one?"*)

### Pass criteria

Claim 3 passes if **at least 2 of 3 testers click Discover OR
the "Tap Discover to start →" CTA first**, AND no tester clicks
Coordinate or Settings first.

(Settings first means they're looking to configure rather than
explore — fine for a power user but signals the welcome card
isn't pulling them right for an everyday user.)

(Coordinate first means the "across devices" framing is the
hook, which suggests the IA's lifecycle order may need to be
re-thought — Coordinate is genuinely the *last* moment, not the
first.)

---

## Section 5 — Debrief (6 minutes)

Five questions, in order. Same wording for each tester.

### Q1. Overall impression

> *"In your own words, what does this app do?"*

Write down their answer verbatim. The pattern across three is
gold — if they all say "it's about downloading apps safely",
the positioning lands. If they all say "I'm not sure, maybe
something to do with privacy?", the marquee isn't landing.

### Q2. Trust signal

> *"If you saw this app on the Mac App Store today, would you
> trust it enough to install it on your Mac?"*

Possible answers:
- Yes — "trust hierarchy" is good. Probe: *"What about it makes
  you trust it?"*
- No — *"Tell me more — what would make you trust it?"*
- It depends — *"Depends on what?"*

Don't react. Just write the answer down.

### Q3. Friction

> *"What confused you the most? Even small things."*

Write down everything they mention. Even a hesitation over a
label is useful.

### Q4. Memory

> *"Tomorrow, when you wake up, what's the one thing you'll
> remember about this app?"*

If they remember a feature → the feature landed.
If they remember a brand → the marketing landed.
If they remember nothing or only confusion → we have work.

### Q5. Open

> *"Anything else you want to tell me? Anything weird, anything
> good, anything missing?"*

Listen. Take notes. Resist the urge to defend.

### Close

> *"Thank you. This was super useful. I'm going to stop the
> recording now."*

Stop recording. Pay the compensation. Walk them out.

---

## Section 6 — Scoring sheet (per tester)

Print this or copy to a doc; fill in per session.

```
Tester: ______________________   Date: __________   Session #: __

═══ TASK 1 — Label legibility ═══
Discover:
  Tester's words: __________________________________________
  Score: [ 0 — Refused ] [ 1 — Wrong ] [ 2 — Adjacent ] [ 3 — Right ]
Download:
  Tester's words: __________________________________________
  Score: [ 0 ] [ 1 ] [ 2 ] [ 3 ]
My Apps:
  Tester's words: __________________________________________
  Score: [ 0 ] [ 1 ] [ 2 ] [ 3 ]
Coordinate:
  Tester's words: __________________________________________
  Score: [ 0 ] [ 1 ] [ 2 ] [ 3 ]

═══ TASK 2 — Find-the-feature ═══
1. See what you've downloaded:
   Found in __ s · Path: _________ · Gave up? Y/N · Quote: ____
2. Check if Spotify ToS changed:
   Found in __ s · Path: _________ · Gave up? Y/N · Quote: ____
3. Pair with iPhone:
   Found in __ s · Path: _________ · Gave up? Y/N · Quote: ____
4. Add a new download:
   Found in __ s · Path: _________ · Gave up? Y/N · Quote: ____
5. Change download folder:
   Found in __ s · Path: _________ · Gave up? Y/N · Quote: ____

═══ TASK 3 — First-tap intuition ═══
First clicked: ______________________  Time to click: __ s
Why: ______________________________________________________

═══ DEBRIEF ═══
Q1 "What does this app do?":
  __________________________________________________________
Q2 "Would you trust it on your Mac?":
  __________________________________________________________
Q3 "What confused you?":
  __________________________________________________________
Q4 "What will you remember tomorrow?":
  __________________________________________________________
Q5 "Anything else?":
  __________________________________________________________

═══ MODERATOR'S NOTES ═══
  __________________________________________________________
  __________________________________________________________
```

---

## Section 7 — Decision protocol (after all 3 sessions)

Within 24 hours of the third session, compile a single-page
summary.

### Pass / iterate / fail

Compute these aggregates:

1. **Claim 1 — label scores.** Sum across 3 testers × 4 tabs = 12
   scores. **≥9 must be 2 or 3** for pass.
2. **Claim 2 — find-the-feature.** Each tester must score ≥4/5
   tasks with success in <60s.
3. **Claim 3 — first-tap.** **≥2/3** testers click Discover or
   its CTA; **0/3** click Coordinate or Settings first.

Decision:

| Outcome | Means |
|---|---|
| All three claims pass | **GO** — engineering starts; estimated 9 days per IA-PROPOSAL.md |
| One claim fails, but the failure is localized (e.g. one tab label, one feature placement) | **ITERATE** — change the specific element, retest with one new tester, decide |
| Two or more claims fail | **REVISE** — the IA itself, not just labels, needs rework; back to drafting |

### What "GO" doesn't mean

Even on a clean GO:
- The labels might still benefit from tweaks. Note the verbatim
  language testers used; sometimes their words are better than
  ours (e.g. if all 3 testers say "my apps" naturally when
  describing what they have, "My Apps" is validated; if they
  all say "my stuff", consider renaming).
- The mocks aren't production. The eventual implementation will
  surface issues invisible to a static prototype (e.g. live data
  density, scroll behavior, focus states).
- The four tabs solve the IA problem. They don't solve every
  product problem. The press wave still has to land, the Mac App
  Store review still has to clear, the Trust catalog still has
  to grow.

---

## Section 8 — Common failure modes and what they mean

After 30+ tests across various products, recurring patterns:

### "Discover sounds like Apple's app discovery"

If 2/3 testers conflate Splynek's Discover with the App Store's
Today tab, the label is wrong. Try:
- "Find apps"
- "Find better apps"
- "Browse"
- "Choose"

The verb is what matters, not how original the word is.

### "Coordinate is a weird word"

The most likely failure on Claim 1 — "coordinate" is jargon-y.
If 2+ testers say *"what does that even mean?"*, swap to:
- "Devices"
- "Your setup"
- "Across Macs"
- "Sharing"

"Devices" is probably the safest, but it's noun-y, breaking the
verb-tab pattern. Either accept the inconsistency or rename one
of the other tabs to a noun too (e.g. "Discoveries / Downloads /
My Apps / Devices" — all nouns).

### "Why are downloads and apps in different tabs?"

If testers say *"isn't a download an app?"*, the lifecycle isn't
landing. They might be right — for a non-techie, "I download an
app" and "the app I have" might be the same mental act.
Possible response:
- Merge Download + My Apps into a single **Apps** tab with
  Active / Installed subviews.
- That's a 3-tab IA. Worth testing in a v2 of the mock if v1
  fails on this point.

### "The Welcome screen feels condescending"

If testers say the four-bullet welcome card feels like a tour or
onboarding pop-up, simplify. Some users prefer to discover
themselves. Possible response: replace with a single hint chip
at the top of Discover: *"New here? Tap the four tabs in
order →"* and let them go.

---

## Section 9 — Anti-patterns the moderator must avoid

The moderator is the biggest threat to a clean signal. Things
NOT to do:

1. **Don't explain features.** If a tester misunderstands what
   a button does, that's the finding. Don't correct them.

2. **Don't ask "do you like this?"** Likes don't predict use.
   Ask what they'd do, not what they think of it.

3. **Don't fill silence.** Silence is the tester thinking. Wait
   it out. You may feel awkward; they don't.

4. **Don't validate.** "Yes, that's right" or "Good question"
   teaches them what answers you want. Stay neutral. Nod and
   move on.

5. **Don't apologize for confusion.** "Oh, sorry, that's because
   we haven't built X yet" turns the test into reassurance
   theater. Instead: "Tell me more about what you expected."

6. **Don't tweak between sessions.** Run all three on the same
   mock. The point is to find the failure pattern. Iterating
   between testers means you measured three different products.

---

## Section 10 — Time and budget

| Activity | Time | Cost |
|---|---|---|
| Build Figma mocks from IA-WIREFRAMES.md | 1 day (maintainer or designer) | $0 if maintainer, ~$500 if outsourced |
| Recruit 3 testers | 1-2 days elapsed (can be done in parallel) | $90 in gift cards |
| Run 3 sessions | 1.5 hours total session time + 1.5 hours moderator overhead | $0 |
| Compile decision doc | 2 hours | $0 |
| Iterate if needed (one round) | +1 day mocks + 1 retest | +$30 |

**Total to GO/ITERATE/REVISE decision: ~4-5 elapsed days,
~$120 hard cost.**

Compared to the 9-day engineering estimate in IA-PROPOSAL.md,
the test is **10-15% of the cost of the implementation it gates**.
Worth the discipline.

---

## Section 11 — When NOT to run this test

The test is right when the question is *"is this IA legible?"*
The test is wrong when the question is something else.

- **Don't run it to validate a feature.** Feature tests have
  different rubrics ("would you use this?", "would you pay?").
- **Don't run it for visual design** (colors, typography).
  Wireframe tests should be near-monochrome to keep visual
  signal out of the scoring.
- **Don't run it for code architecture.** That's an internal
  design review.
- **Don't run it once the engineering is done.** Sunk cost
  means you can't act on findings; postpone the test until
  before commitment.

---

*Document author: Splynek maintainer + Claude. Created
2026-05-13 evening. Pairs with `IA-PROPOSAL.md` (the structure)
and `IA-WIREFRAMES.md` (the mocks to test against).*
