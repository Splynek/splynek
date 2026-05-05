# Apple v1.0 — Day-10 escalation message (Resolution Center)

> **Trigger:** Apple v1.0 still pending re-review at day 10
> (counting from the 2026-04-26 resubmission).  Paste the message
> below into Resolution Center.  Do NOT use this before day 10 —
> at day 8–9 we're still inside the "typical 1–7 day re-review +
> 2-3 day grace" window and a polite ping risks looking impatient.
>
> **Author:** Paulo Graça Moura, sole developer.
> **Drafted:** 2026-05-05.

## When to send

- ✅ Day 10 reached, no movement (no "In Review" → "Pending Developer
  Release" / "Rejected" / "Ready for Sale" transition)
- ✅ The ASC monitor cron `trig_01FdTsuA5J9d85sknvtFZTHj` continues
  to report "In Review" at day 10's 09:00 UTC firing
- ❌ Don't send if Apple has reached out independently (in-flight
  reviewer questions take priority)
- ❌ Don't send if the binary is already in a transition state

## Where to send

App Store Connect → My Apps → Splynek → "App Review" tab → Resolution
Center → New message.  Subject auto-populates with the build ID.
Address the reviewer in the polite-but-direct tone Apple's review
team prefers — they read thousands of these per week.

## The message

---

Hi App Review Team,

I'm writing to ask for an ETA on Splynek 1.0 (build pending since
2026-04-26).  We're now at the upper edge of the typical re-review
window, and I want to make sure I haven't missed a question or a
required clarification on my end.

Quick context for whoever picks this up:

1. **VPN clarification (the original rejection ground).**  Splynek
   does not use the `com.apple.developer.networking.networkextension`
   entitlement, does not include any `NEPacketTunnelProvider` /
   `NEAppProxyProvider` / `NEFilterDataProvider` subclasses, and
   does not bundle any VPN configuration or tunnel kit.  Splynek's
   "multi-interface bonding" is at the application HTTP layer:
   per-connection `IP_BOUND_IF` socket option (`SO_BINDTODEVICE`
   equivalent) over standard `URLSession`, requesting different
   byte ranges of the same file from each interface in parallel.
   No traffic is routed through any extension; no system-wide
   networking is intercepted.  This was the substantive answer to
   the original rejection's clarification request, included in
   the resubmission's App Review Notes (section "Networking
   Architecture").

2. **Guideline 2.5.2 ("vibe coding" wave).**  Splynek does NOT
   generate, download, install, or execute code.  Its on-device
   AI Concierge (built on `FoundationModels.LanguageModelSession`
   plus optional Ollama / LM Studio fallback) is a URL classifier
   + tool dispatcher only.  The full file-anchored brief is at
   `MAS-2.5.2-COMPLIANCE.md` in the source repository — happy to
   paste the relevant sections inline if useful.

3. **Architecture invariants** (also in App Review Notes): no
   account system, no telemetry, no analytics, no remote config,
   no push notifications, no third-party SDKs.  Network surface
   is exactly: HTTP(S) downloads the user initiates, Bonjour/MDNS
   for the LAN peer cache (opt-in per device), and StoreKit for
   IAP.

The build itself has no functional changes vs the previous
submission's binary (build ##### vs ##### — same source tree, same
commit hash) — the resubmission was purely to attach the VPN
clarification document.

If there's anything I can clarify, add to the App Review Notes,
or rebuild with different metadata, please let me know.  Happy to
turn around in <24 h.

Thanks for your time,
Paulo Graça Moura
Splynek — sole developer
paulo@splynek.app · paulocgm@gmail.com

---

## Tone notes

- Open with "I want to make sure I haven't missed a question on my
  end" — frames the message as cooperative, not nagging.
- Lead with the VPN clarification because that's the single
  rejection ground; reviewers who pull this up cold need to see
  immediately that the clarification has been provided.
- 2.5.2 is included pre-emptively in case the new reviewer is
  pattern-matching against the vibe-coding wave; pointing them at
  `MAS-2.5.2-COMPLIANCE.md` rather than dumping the whole brief
  inline keeps the message scannable.
- "<24 h turnaround" signals you're a sole developer who'll
  respond fast — distinguishes from corporate submissions that
  take weeks to react.
- Sign with full name + role + double email (your alias + your
  primary).  Reviewers occasionally reach out via the dev-account
  email rather than Resolution Center.

## What NOT to write

- Do NOT mention specific competing apps ("Folx", "Downie") even
  to contrast Splynek's no-cloud posture — reviewer policy
  discourages it.
- Do NOT cite App Store metrics, search visibility, or prospective
  press cycle.  Apple reviewers are explicitly trained to ignore
  these.
- Do NOT mention the website, the homebrew tap, or the planned
  Show HN.  Apple may visit splynek.app; if it shows a "Buy
  direct via Stripe" button (when that ships), reviewers may
  flag it under Guideline 3.1.1.  Until v1.0 is Ready for Sale,
  splynek.app should show ONLY the MAS purchase path.
- Do NOT promise feature changes.  v1.0 is what it is; if Apple
  wants something different, that's a v1.1 conversation.

## Build IDs to fill in

Replace `#####` with the actual ASC build numbers when sending.
Look up at App Store Connect → Splynek → TestFlight → Builds.
Typically displayed as "Build 100" or similar; the prior + current
build numbers are useful context for the reviewer.

## After sending

- Apple's typical Resolution Center response cadence is 12–48 h.
- If response is "still in review, no specific ETA": wait another
  72 h before the next message.  Don't escalate twice in the
  same week.
- If response is a question / clarification request: respond
  inside 24 h, mark the message as "Reviewer Reply" in your
  workflow, paste the answer in cleanly.
- If response is a rejection: switch to the rejection-handling
  flow (which depends on the cited guideline).  For 2.5.2,
  paste `MAS-2.5.2-COMPLIANCE.md` + a one-line summary.  For
  any other guideline, surface the cited section first, then
  craft the response.

## Why this doc exists

Day 10 is a real cliff — Apple's reviewer queue management is
not visible to developers, and "no movement" can mean (a) the
binary fell through a queue crack, (b) a reviewer is checking
something privately, (c) Apple's load is unusually heavy.
Polite escalation usually moves it to (d): "the reviewer
remembers to look at it again."

Having the message pre-written + tonally-correct means Paulo
can fire it the moment ASC monitor cron fires the day-10 alert
without spending 30 minutes composing under pressure.
