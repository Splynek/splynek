# Show HN draft — v1.5.3

**Title candidates — pick one:**

1. `Show HN: Splynek – Mac downloader that audits your other apps for safety/privacy`
2. `Show HN: Splynek – multi-interface Mac downloader + public-record privacy audit`
3. `Show HN: Splynek 1.5 – downloads files over every NIC at once + Trust tab for app risk audit`

**Recommended: #1.** The Trust tab is the unique angle — every other Mac
downloader is just a downloader. Lead with it.

**Post at:** Tuesday or Wednesday, 14:00–16:00 UTC (9–11 AM ET). Avoid
Mondays (queue burst), Fridays (HN coast). Avoid the week of any major
Apple event (drowned out by WWDC / iPhone keynote chatter).

**Pre-flight:**
- v1.0 must be **Ready for Sale** on the Mac App Store before posting
  (so the post can include "MAS link" in the body, not just GitHub).
- splynek.app landing must be live on the v1.5.3 copy.
- Have the comment-seeding answers in a paste buffer.

---

## Body

> Splynek is a native macOS download manager — it pins outbound sockets
> to every network interface you have (Wi-Fi + Ethernet + iPhone tether
> + Thunderbolt NIC) via IP_BOUND_IF and pulls files in parallel via
> HTTP byte-range requests. On flaky hotel Wi-Fi + 5G tether I see 2-3×
> single-path. BitTorrent v1+v2 with hybrid torrents.
>
> But that's the boring part. The reason I'm posting:
>
> v1.5 added two tabs that audit your **other** Mac apps:
>
> **Sovereignty** maps 1,150+ catalogued apps to their country-of-origin
> + curated European or open-source alternatives. Click "Install" to
> download the alternative through Splynek's engine. Localised
> FR / DE / ES / IT.
>
> **Trust** is a public-record audit. For each catalogued app it
> surfaces concerns sourced **only** from primary records you can
> verify in one click: Apple App Store privacy labels (developer self-
> disclosure), EU DPA / FTC / SEC enforcement actions, NVD CVE database,
> HIBP confirmed breaches, vendor security advisories. No tech-press
> citations. No subjective claims. No AI-generated risk assessments.
> Score is paired with the cited evidence; the UI never shows the
> score in isolation. MAS-safe by design — the source allowlist is
> the legal boundary that lets it ship on the App Store.
>
> The catalogs ship in the binary; scans are on-device + opt-in. Zero
> network calls, zero telemetry, zero app-list leaving the device.
> Pipeline is JSON-backed → Swift codegen so community PRs land via
> readable diffs. 145 invariant tests guard quality (banned editorial
> words, HTTPS-only URLs, ID uniqueness, source allowlist).
>
> Plus the things you'd expect from a Mac downloader: SHA-256
> verification, per-chunk Merkle integrity, LAN fleet (other Splyneks
> on Bonjour cooperate), local-LLM Concierge (Apple Intelligence /
> Ollama / LM Studio), CLI + REST API + Raycast + Alfred + Shortcuts.
>
> ~12 k lines of Swift, no third-party deps, MIT (free tier), $29
> one-time IAP for Pro. Notarised + stapled. Mac App Store launching
> imminently — DMG link below works today.
>
> - Site: https://splynek.app
> - Source: https://github.com/Splynek/splynek
> - DMG: https://github.com/Splynek/splynek/releases/tag/v1.5.3
>
> Happy to answer architecture questions, the legal reasoning behind
> the Trust source allowlist (defamation surface), or how the multi-
> interface mechanism is *not* a VPN (Apple's reviewer asked the same
> thing).

---

## Comment-seeding — answers ready to paste

### "How do you avoid defamation with the Trust tab?"

> Source allowlist + factual phrasing. Every concern cites a primary
> source URL with a date. The allowed sources are Apple's own App
> Store privacy labels (developer self-disclosure), EU DPA decisions,
> FTC consent orders, NVD CVE database, HIBP breach corpus, vendor
> security advisories, and government sanctions records. Tech press,
> Wikipedia, ToS;DR, Mozilla *Privacy Not Included* — explicitly
> excluded; too subjective. The regenerator script refuses to ship
> if a summary contains words like "spies" / "untrustworthy" /
> "you are the product" — must read as factual reporting on a
> primary source. We surface public record; we don't editorialise.
> Apple themselves require developers to publish privacy labels —
> Splynek amplifies that programme rather than competing with it.

### "Is the multi-interface thing a VPN?"

> No. It's the BSD socket option `IP_BOUND_IF` (see netinet/in.h)
> applied to Splynek's own outgoing connections. Each lane is a
> regular outgoing socket pinned to a specific NIC. POSIX-level
> outgoing-socket configuration. No `NEVPNManager`, no
> `NEPacketTunnelProvider`, no NetworkExtension entitlement, no
> kernel hook, no traffic interception from other apps. Apple
> reviewer asked the same — answer is in the App Review Notes.

### "Why not just use aria2?"

> aria2 doesn't bind per-interface (uses whatever the OS routes),
> doesn't have a native Mac UI, doesn't do a LAN content cache,
> doesn't audit other apps for privacy concerns, doesn't ship a
> Sovereignty alternatives catalog. Different problem.

### "Is the catalog data going to age out?"

> Yes — that's why there's a JSON-backed pipeline + 3 scheduled
> remote agents that run monthly to (a) discover candidate apps for
> Sovereignty, (b) refresh App Store privacy labels for Trust
> entries older than 90 days + check NVD/HIBP for new entries, and
> (c) audit a rotating area of the codebase quarterly. PRs land for
> human review; nothing auto-merges. There's also a GitHub Actions
> weekly cron that validates URL liveness across the catalog.

### "Trust score — how is it computed?"

> Pure deterministic Swift in `TrustScorer.swift`. Each concern has
> a severity (low/moderate/high/severe → 5/12/25/40 points) and an
> axis (privacy/security/trust/business model). The user's per-axis
> weights (default: security 1.5, privacy 1.0, trust 1.0, business
> model 0.6) multiply the severity points. Sum, clamp to 0-100,
> bucket into Low/Moderate/High/Severe. UI always shows the score
> with the cited concern labels — never the score alone. False
> precision is the path to defamation; the score is a summary, the
> labels are the truth.

### "Why is BitTorrent included?"

> BitTorrent is a common protocol for large legitimate downloads
> (Linux ISOs, game patches, scientific datasets). Splynek implements
> BEP 3/6/9/10/11/52 per spec. We don't host a tracker, don't index
> torrents, don't exchange peers over public internet for legal
> reasons. Users supply their own .torrent files or magnet links.

### "Is this just for macOS?"

> Yes. AppKit + SwiftUI + Network.framework are the load-bearing
> APIs. Linux/Windows port not planned.

### "How do you stay independent?"

> One-time $29 Pro IAP. No subscription, no telemetry, no analytics,
> no advertising, no investor pressure to enshittify. The free tier
> (everything except Concierge / Recipes / Schedule / Web Dashboard)
> is MIT-licensed. The Pro modules are closed source in a sibling
> repo. Sovereignty + Trust are free-tier on principle — they're
> statements of values before they're features.

---

## After the post

- Watch comments for 2 hours minimum. Answer everything, even
  hostile, politely and with specifics.
- Don't upvote your own post.
- Don't ask friends to upvote — HN's flame detector flags it.
- Cross-post to `r/macapps` + `r/selfhosted` 3-4 hours after the
  HN thread hits, linking back to HN for comments.
- Email MacStories / 9to5Mac / The Eclectic Light Company / ATP
  after first HN signal — Mac press reads HN.
- For EU press (Le Monde / Wired / Der Spiegel / FT), use the
  pitches in `PRESS_KIT.md`. Send Wednesday/Thursday morning EU
  time the day after the HN post.

## Fallback if HN is quiet

- Tuesday post quiet? Re-submit with title #2 the following Tuesday.
- Product Hunt launch Thursday/Friday same week. PH has its own
  audience; HN-on-Tuesday + PH-on-Thursday is the canonical solo
  rollout.
- Targeted EU sovereignty angle for `r/europe` + `r/digitalrights` +
  `r/privacy` weekend-after if HN didn't bite.
