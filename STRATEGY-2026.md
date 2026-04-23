# Splynek 2026 — strategy memo

**Date:** April 2026 (v1.0 shipped, in Apple review)
**Author:** Paulo with strategic input from Claude Opus 4.7

This is a *decision document*, not a brainstorm. Everything below has a
"why", an "evidence", and a "next action". Where the evidence is from
external research, sources are in-line. Where the call is opinionated
judgement, it's marked *[judgement]* and the reasoning is shown.

---

## 0. One-paragraph position

**Splynek wins by being the first download manager built for 2026 —
on-device AI, multi-interface, LAN-cooperative, Mac-native — shipping
while the incumbents (Folx, Downie, JDownloader) are in active decay.
The wedge is "the only download experience that runs entirely on
your Mac" — a narrative Apple will amplify through 2026–2027 as
Apple Intelligence rolls out, and a narrative none of the incumbents
can truthfully adopt.** The moat is four genuinely-uncopyable things
combined in one product: multi-interface bonding without a VPN,
Apple-Intelligence-native AI, Bonjour LAN cache, and cryptographic
download receipts. Each piece alone is a feature; together they're
a category reset.

---

## 1. Diagnosis — the market is softer than it looks

### The incumbents are wounded

- **Folx** (the category leader on Setapp) has a wall of 2025 reviews
  complaining about lockups, crashes mid-torrent, broken browser
  extensions, and "connecting to unknown machines pre-download"
  (privacy red flag). Source: [Setapp Folx reviews](https://setapp.com/apps/folx/customer-reviews),
  [MacStories Folx review](https://www.macstories.net/reviews/folx/).
- **Downie** took reputational damage in March 2024 from its
  anti-piracy scare popup ("we deleted random files of yours") which
  triggered on legitimate buyers. Users in the HN/mjtsai threads
  are still citing it as a reason to avoid the app. Source:
  [mjtsai](https://mjtsai.com/blog/2024/03/13/downies-anti-piracy-scare-tactic/).
  It's also YouTube-only, fragile on rate-limits, and requires Permute
  ($14.99) for format conversion.
- **JDownloader** is Java, still ships an ancient JDK in the app bundle,
  not Apple-Silicon native by default. Source:
  [Homebrew cask issue #55517](https://github.com/Homebrew/homebrew-cask/issues/55517).
- **Safari / Chrome built-in downloads** are unreliable: "Resume"
  restarts from byte 0, network switches silently kill transfers,
  no retry. Source: [Apple Community](https://discussions.apple.com/thread/251250011),
  [MacRumors](https://forums.macrumors.com/threads/i-cant-resume-downloads-files-with-safari.1110019/).
- **macOS native link aggregation** only does Ethernet+Ethernet LACP.
  You CAN'T bond Wi-Fi + Ethernet + iPhone tether natively. The only
  third-party answer is **Speedify** — which routes through their
  cloud servers (privacy trade-off, subscription). Source:
  [Apple Support](https://support.apple.com/en-hk/guide/mac-help/mchlp2798/mac),
  [Speedify](https://speedify.com/blog/combining-internet-connections/network-bonding-on-mac-guide/).

**Implication:** there is a TAM of Mac users paying for download tools
that are crashing, phoning home, or fabricating progress. Splynek's
opening isn't "build a better Folx." It's "ship the download tool
these users would buy in 2026, without any of the current baggage."

### The pain points are concrete, not abstract

From Reddit/HN/App Store reviews:

1. **Resume is broken** across Safari, Chrome, Folx. Network flaps
   destroy long downloads. *Universal, #1 rated pain.*
2. **Folx is actively unstable** in 2025-2026 reviews — freezes on big
   files, crashes on torrent add, browser extension doesn't function.
3. **Privacy anxiety** — Folx's "connecting to unknown machines"
   review; FDM's 2020–22 backdoored Linux-binary incident still cited
   ([Wikipedia](https://en.wikipedia.org/wiki/Free_Download_Manager));
   every Instagram/TikTok web-downloader logs URLs server-side.
4. **No Mac app does multi-interface without a VPN.** Speedify is the
   only option and it's subscription + cloud relay.
5. **Power users duct-tape yt-dlp + aria2c + Hazel + Alfred.** One app
   that eats this stack would be a no-brainer.
6. **Under-served verticals**: Instagram carousels, Twitch VODs
   (Twitch Leecher is discontinued), bulk academic PDFs (SciHub
   downloaders explicitly say "no Mac version"), whole-site archival
   (SiteSucker is $5 and crashes on SPA sites).

### The tech opportunity is real and time-sensitive

- **Apple Foundation Models framework** shipped in macOS 26 (Sept 2025)
  as a first-class on-device LLM API, free for any 3rd-party app, no
  entitlement required for inference, sandbox-friendly. Source:
  [Apple ML Research](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates),
  [MacRumors WWDC25](https://www.macrumors.com/2025/06/09/foundation-models-framework/).
- **App Intents + Assistant Schemas** landed at WWDC25 — Siri /
  Shortcuts / Spotlight integration is now a few-file implementation.
  Source: [WWDC25 session 244](https://developer.apple.com/videos/play/wwdc2025/244/).
- **Live Activities on macOS 26** mirror from paired iPhones into the
  menu bar — shipping an iOS companion unlocks a Mac feature for free.
  Source: [9to5Mac](https://9to5mac.com/2025/06/16/macos-26-live-activities-work-even-if-your-iphone-is-on-ios-18/).
- **Control Center widgets** work on macOS 26 but 3rd-party adoption is
  near-zero (MacStories: "only Drafts and ScreenFloat are shipped
  examples"). First-mover optics available. Source:
  [MacStories Tahoe review](https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/3/).

**Implication:** the next 6 months are a land-grab window for apps
willing to adopt Apple's 2025 frameworks aggressively. Waiting = losing
the press cycle to someone else.

---

## 2. The wedge — "the only download experience that runs entirely on your Mac"

Stop leading with "multi-interface aggregation." It's a proof point,
not a pitch. The narrative that wins the 2026–2027 Mac user is:

> **On-device AI. LAN co-op. No cloud, no account, no telemetry.**
> **Every byte of every download stays inside your house.**

This positioning is:

- **True** (Splynek has zero backend, uses only on-device LLMs).
- **Uncopyable by the incumbents** — Folx has the "phoning home"
  review problem; Downie can't adopt it without eating Permute; FDM's
  reputation is tainted.
- **Apple-amplified** — Apple markets on-device AI as a core platform
  differentiator through 2026 (see Apple Intelligence launch, 2025 iOS
  and macOS keynotes).
- **Useful as a filter**: every product decision we make either
  reinforces "local" or breaks it. No cloud queue? Fine. No optional
  cross-device sync? Fine — do it via Bonjour instead.

**Proof-points stacked underneath:**
1. Multi-interface bonding (hero feature, keeps the benchmark moment).
2. Apple Foundation Models Concierge (zero-install AI — no terminal, no
   Ollama, nothing to configure).
3. Bonjour LAN cache (the "Napster for legal downloads" household
   moment — see §3 creative move A).
4. Cryptographic download receipts (the privacy-paranoid-journalist
   moment — see §3 creative move B).

---

## 3. The bets (priority-ranked)

I am deliberately proposing FEW bets, each with strong conviction.
Feature creep is the enemy.

### Bet S1 — **Apple Foundation Models Concierge** *(the killer bet)*

**Ship:** Week 1–3 after v1.0 ships.

**What:** Use `FoundationModels.LanguageModelSession` on macOS 26+ as
the primary AI engine for the Concierge + Recipes. Fall back to LM
Studio / Ollama on pre-macOS-26 or non-Apple-Intelligence Macs.

**Why this wins:**
- Eliminates the single biggest Pro-tier friction: "I have to install
  Ollama or LM Studio first". The Foundation Models API is *already
  installed* — the LLM is built into macOS.
- Free to ship, free to run (no API costs, no cloud).
- Runs on Apple Neural Engine — faster than Ollama on M-series.
- Legitimately privacy-first. Apple markets this as "your data stays
  on device." Splynek gets that halo for free.
- Sandboxed, App Store approved API. No entitlement battles.
- Gives us a press-cycle story: **"first download manager with
  Apple Intelligence Concierge"**. First mover in a category that's
  been waiting for it.

**Evidence:**
- Foundation Models is shipping, documented, no entitlement required
  for inference. See [Apple Developer: Foundation Models](https://developer.apple.com/documentation/FoundationModels).
- Current Splynek architecture routes all LLM calls through
  `chatCompletion(system:user:...)` — one integration point to swap.
  The existing Ollama/LM Studio detection code becomes the *fallback*,
  not the primary path.

**Implementation:** ~S (days of work).
- Wrap `LanguageModelSession` behind an `AIAssistant.Provider` case.
- Detection order: `.appleIntelligence` → `.lmStudio` → `.ollama` →
  `.unavailable`.
- Use guided generation for structured JSON (replaces our current
  `response_format: json_object` hack).
- Degrade gracefully on pre-26 hardware.

**Done = shippable = press-ready.**

---

### Bet S2 — **Unbreakable Resume + Smart Mirror Failover**

**Ship:** Week 3–6.

**What:** The download equivalent of the "it just works" promise.
Three components:

1. **HTTP Range resume with Merkle-verified segments** (already partly
   built). Harden the code path: every segment is its own
   content-addressed chunk, resumable across weeks and machine reboots.
2. **NWPathMonitor retry loop.** When Wi-Fi drops or Ethernet switches,
   Splynek pauses, re-probes, and resumes on whatever NIC comes back.
   No user intervention. No lost bytes.
3. **Auto-mirror failover.** If the primary URL starts returning 403s /
   500s / slowdowns, Splynek tries known mirror sets:
   - GitHub release asset → archive.org / jsdelivr / unpkg
   - Ubuntu ISO → mirror list from `launchpad.net/ubuntu/+cdmirrors`
   - Debian ISO → `debian.org/mirror/list`
   - Blender / PyTorch / common dev tools → curated mirror manifest
     shipped with the app, updated via Background Assets.

**Why this wins:**
- Research shows broken resume is the **#1 rated pain point**.
  Fixing it beats every incumbent on a single metric users notice.
- The marketing copy writes itself: **"your download WILL finish."**
- Uses Splynek's existing per-chunk verification (Merkle) as the
  integrity guarantee for cross-mirror switching.

**Implementation:** ~M. NWPathMonitor loop + mirror manifest system
+ UI surface to show "switched to mirror X" transparently.

---

### Bet S3 — **Swallow yt-dlp, cover every capture surface**

**Ship:** Week 4–8.

**What:** Bundle yt-dlp, auto-update it in the background via
`BackgroundAssets`, and expose it through Splynek's one-paste UI.
User pastes ANY URL — YouTube, Twitch, Twitter/X, Instagram post or
carousel, TikTok, Bilibili — Splynek picks the right engine (yt-dlp
for video sites, direct HTTP for files, torrent for magnets).

**Extras (cheap once yt-dlp is bundled):**
- **DOI list mode** — paste a list of DOIs, Splynek fetches PDFs via
  a configurable resolver chain (institutional cookie-login first,
  then open-access fallback). Academics are a real, under-served
  buyer segment.
- **Playlist / channel archive** — "download every video from this
  YouTube channel, max 1080p, save to `~/Videos/YT/%channel%/`".

**Why this wins:**
- Kills Downie on Downie's home turf (YouTube) while also doing
  Instagram carousels, Twitch VODs (Twitch Leecher is discontinued),
  TikTok, etc. One paste, one tool.
- yt-dlp is MIT-licensed; bundling is fine legally.
- The auto-update via Background Assets solves yt-dlp's biggest user
  pain ("youtube-dl broke, I need to update again").

**Implementation:** ~M. Mostly orchestration; yt-dlp already
exists as a CLI we invoke. Auto-update via Background Assets +
signed-release verification.

---

### Bet S4 — **Splynek Companion for iPhone** *(the unfair advantage)*

**Ship:** Week 8–16 (alongside Pro+ tier launch).

**What:** A lightweight iOS app (free on the App Store) that:
1. Adds a **Share Extension** — share any URL from Safari / Twitter /
   Instagram → "Send to Splynek" → queues on your paired Mac. Uses
   Bonjour over the LAN; `NSUserActivity` + optional CloudKit for
   over-cellular relay.
2. Shows a **Live Activity** with download progress on the iPhone
   lock screen + Dynamic Island. Because macOS 26 mirrors paired-iOS
   Live Activities into the Mac menu bar, **this feature lights up
   the Mac menu bar for free** — no separate Mac menu-bar widget to
   build.
3. On-device Web dashboard view (already exists in Splynek server) —
   one-tap "queue from phone, finish on Mac" for any URL you're
   browsing on iPhone.

**Why this wins:**
- **Zero competitor in the download-manager category has an iOS
  companion.** Folx doesn't. Downie doesn't. This is a complete
  category moat.
- The UX story is concrete and viral: "I'm on the couch with my
  iPhone, I see a great article, I share it to Splynek — by the time
  I walk to my Mac, the download's already complete."
- Apple rewards paired iOS+Mac apps in App Store editorial.
- One iOS build unlocks Dynamic Island + Mac menu-bar Live Activities
  simultaneously (macOS 26 feature).

**Implementation:** ~L. It's a new iOS target with Share Extension +
ActivityKit + URLSession Bonjour discovery. But it's 3–4 weeks of
focused work, not 3 months.

---

### Bet A1 — **macOS system integration: App Intents + Shortcuts + Siri + Control Center**

**Ship:** Week 1–4 (parallel with S1).

**What:** The table-stakes 2026 "feels like a Mac app" features:

- **App Intents** for every Splynek operation: add URL, queue URL,
  pause all, resume all, get current throughput, search history.
- **Assistant Schemas** so these integrate into Apple Intelligence
  actions (e.g., Shortcut: "summarise this article → extract download
  links → queue").
- **Siri**: "Hey Siri, download the latest Ubuntu ISO to Splynek."
- **Control Center widgets** — pause-all toggle, throttle toggle,
  current-speed glance. MacStories noted near-zero 3rd-party adoption;
  first-mover optics.
- **Spotlight** — downloads searchable in Spotlight history with
  "Reveal in Splynek" action.

**Why this wins:**
- Makes Splynek feel native and current; the "Java-port-to-Mac"
  critique of JDownloader can never apply.
- Opens secondary press cycles ("Splynek adds Siri support!")
- Reduces the perceived surface area of the app — power users love
  that every feature is scriptable.

**Implementation:** ~S/M. Each intent is a file. The work is modeling
the domain entities (DownloadEntity, QueueEntity) cleanly.

---

### Bet A2 — **Rules Engine + Smart Folder**

**Ship:** Month 3–4.

**What:** Inline with the "kill yt-dlp+Hazel+Alfred stack" thesis.

- **Rule syntax:** `if host = "youtube.com" and type = "video" then format = "mp4 1080p" and save_to = "~/Videos/YT/%channel%/%title%"`
- **Local-LLM-assisted naming:** the Foundation Models Concierge
  suggests smart filenames based on content-type (e.g. extracts
  ISBN from a PDF download to name it properly).
- **Smart folders** — auto-classify downloads into ~/Downloads/,
  ~/Videos/, ~/Papers/, ~/Archives/ based on content type + URL.

**Why this wins:**
- Replaces Hazel ($36) for the download-specific workflows most users
  have set up. Integration is tighter than Hazel's because Splynek
  knows the download's full metadata (source URL, Content-Type, etc.).
- Pro-tier differentiator — keeps the power user happy.

---

### Bet A3 — **"File Witness" cryptographic download receipts** *[creative]*

**Ship:** Month 4–6.

**What:** Every download produces a signed receipt:

```
{
  "url": "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso",
  "sha256": "...",
  "size_bytes": 5_800_134_656,
  "timestamp": "2026-05-14T10:23:41Z",
  "device_pubkey": "age1xyz...",
  "signature": "..."
}
```

Exportable as JSON or human-readable PDF. "Export receipt" button in
History tab.

**Why this wins:**
- **Nobody else does this.** It's a small, easy feature that carves
  out a meaningful niche.
- Real use cases: journalists documenting sources, academics citing
  downloaded datasets, developers proving build reproducibility,
  legal/compliance teams.
- Fits the "privacy + integrity" narrative perfectly.
- The signature infrastructure is trivial — a per-device Ed25519 key
  stored in the Keychain, one line of `CryptoKit`.
- Natural Pro+ tier upsell ("batch-export receipts for all downloads
  in Q1", "Splynek for Journalists" marketing angle).

---

### Bet A4 — **"Household Mode"** *[creative, the viral lever]*

**Ship:** Month 6–9.

**What:** Opt-in feature for Macs on the same home LAN.

- Each Splynek installation advertises (via Bonjour) a short hash of
  its recent completed downloads — never URLs or filenames directly,
  just content-addressed digests.
- When Mac A finishes a big download (Xcode, Ubuntu ISO, a 50 GB
  dataset), Mac B's Splynek notifies: *"Filipe just downloaded
  `Xcode_17.dmg`. Want it? [Take now] [Later] [Never]"*.
- If Mac B takes it, transfer happens over gigabit LAN — seconds
  instead of hours. Zero bytes touch the internet.
- Fully opt-in, per-device, easily revocable. No uploads leave the
  LAN. No cloud. No account.

**Why this wins:**
- Solves a real family / home-lab pain: *we all download the same
  stuff separately*.
- **Viral loop inside households** — one person installs Splynek,
  their family sees the notification, they install it too. Network
  effect inside the home.
- Nobody else in the category has this. Speedify is subscription +
  cloud-relayed; Splynek does it free, local, encrypted.
- Privacy-safe because content-addressed — the hash reveals nothing
  about the file unless the receiving machine already knows it.

**Implementation:** ~M. Splynek already has Bonjour + fleet +
LAN cache. This is a UX-layer evolution plus a clean consent flow.

---

### Bet S5 — **Splynek Accelerator: bond the Mac's internet, not just its downloads** *(the 2x vision)*

**Ship:** Month 3–5 (in parallel with S4 iOS companion).

**What:** Extend Splynek's multi-interface engine from "downloads Splynek
itself initiates" to "any *big-volume* traffic on the Mac" — without a
VPN, without a cloud relay, without a NetworkExtension entitlement.

The path is a **browser extension + local proxy**, not a system-wide
VPN. Here's why and how.

#### The core technical insight

To bond traffic for *all* apps you'd need NEPacketTunnelProvider — a
VPN. That would:
- Require the `com.apple.developer.networking.networkextension` entitlement
  (Apple-approved only, case-by-case).
- Directly contradict the VPN-negation answer we just gave Apple review.
- Turn Splynek into "Speedify clone" in Apple's and users' eyes.
- Require a cloud relay to assemble bonded packets for remote endpoints
  that don't multiplex natively (Speedify's trick). That breaks our
  no-cloud wedge.

So "bond every packet on the Mac" is not the right goal. But:

**Observation:** bonding only matters for *volumetric* traffic. Small
HTTP requests (API calls, webpage HTML, chat messages) are latency-
bound, not bandwidth-bound — a single Wi-Fi is fine. Bandwidth-bound
traffic is (a) large downloads, (b) video streams, (c) file sync (iCloud,
Dropbox) — all of which Splynek can intercept without a VPN.

#### Implementation — three surgical interception points

1. **Browser extensions (Safari, Chrome, Firefox):**
   - When a user clicks a large download link (or the browser surfaces
     one), the extension redirects the transfer to Splynek's bonded
     engine. User sees the file appear in Downloads at 3x speed.
   - Detection heuristics: Content-Length > 50 MB, or known video-site
     DOM pattern (YouTube / Vimeo / Twitch / large-file hosters).
   - No VPN. No system-level interception. Purely per-transfer opt-in.
   - Folx/Downie already do the "intercept browser download" trick; we
     extend it with multi-interface bonding + resume + Merkle
     verification.

2. **Streaming media pre-buffer:**
   - Extension detects HLS/DASH manifests (YouTube, Netflix, Vimeo,
     Twitch live, Plex).
   - Pre-fetches segments 30–60s ahead via bonded multi-path, stores
     locally in a temp ring buffer, serves them to the player via a
     local HTTP proxy.
   - User-visible outcome: video starts instantly, never buffers, even
     on a flaky Wi-Fi + weak 5G tether combo.
   - Works for DRM-free streams (YouTube is DRM-free for non-premium
     content via HLS). Paid streams (Netflix, Disney+) use Widevine /
     FairPlay DRM and are untouchable legally and technically. Skip.

3. **Large-file app transfers via local SOCKS proxy (optional, advanced):**
   - Splynek exposes a SOCKS5 proxy on `127.0.0.1:1080` that bonds
     whatever flows through it.
   - Apps like Slack / Dropbox / Transmit / rsync-over-SSH can be
     pointed at this proxy via each app's own settings (not system-
     wide). Each app opts in per-task.
   - For the 5% of power users who want it. Not a primary pitch.

#### Why this wins

- **No VPN entitlement needed.** Browser extensions use only standard
  `webRequest` / `declarativeNetRequest` APIs; local proxy is plain
  TCP/UDP on loopback.
- **No cloud relay.** Everything happens on the user's Mac. Preserves
  the "no cloud, no account, no telemetry" wedge.
- **Transparent to the user.** The user doesn't see a VPN icon, doesn't
  pick a server, doesn't manage a subscription. Safari feels faster.
  YouTube buffers instantly. That's the whole product story.
- **Category-redefining demo.** Opening Netflix on a hotel Wi-Fi + 5G
  tether and having it start instantly while every other app stutters
  is a viral-video moment. Folx/Downie/Safari have no answer.
- **Legally safe.** We're not bypassing any DRM; we're accelerating
  open HLS. We're not proxying traffic we don't own (user explicitly
  configures the SOCKS path). We're not running a cloud service.

#### What this is NOT

- It is **not** a VPN. Users seeking Speedify-style "bond all my
  packets including WhatsApp video calls" should buy Speedify. We
  don't compete there, and we say so honestly in the marketing.
- It is **not** a system-wide network replacement. Apple's
  NetworkExtension is a deliberate, case-approved API that Splynek
  doesn't qualify for as a download manager.
- It is **not** a streaming DRM breaker. Netflix / Disney+ / Apple TV+
  are off-limits.

#### Implementation difficulty

- Browser extensions: **M** per browser (Safari WebExtension + Chrome +
  Firefox). Shared code is ~80%; each needs its own build + signing.
- Local SOCKS proxy + HLS pre-buffer: **M** (Swift Network.framework
  server, already have all the pieces).
- UX surface: **S** — a new "Accelerator" tab in Splynek showing which
  apps are currently being accelerated + an opt-in-per-site toggle.

#### Where this lands in the narrative

The wedge gets a second proof point:

> **"Splynek isn't just a download manager. It's the aggregation
> fabric for your Mac's internet."**

Downloads at 3x. Video streams that never buffer. Large uploads over
the SOCKS proxy. All local, all private, no subscription.

**This is the "super-power connection" promise, delivered inside the
constraints of the Mac App Store + sandbox + our no-cloud wedge.**

---

### Bet A5 — **Viral benchmark PNG amplifier**

**Ship:** Week 2 (very cheap).

**What:** Splynek already has a Benchmark tab that outputs
`Single: 38 MB/s | Multi: 117 MB/s`. Make it ONE tap to share —
pre-rendered PNG with Splynek branding at bottom, optimized for
Twitter/X / Mastodon / HN embed.

**Why this wins:**
- Every benchmark image posted is a free ad.
- Engineered screenshots are high-leverage — one viral benchmark
  tweet is worth a month of SEO.
- Zero cost to implement (rendering infra exists; add share-to
  buttons + aspect-ratio presets for Twitter 16:9).

---

## 4. Pricing — keep $29, add $49 Pro+ at month 6

Evidence synthesis (full sources in research agent report):

- Downie $19.99, Folx $19.95, Leech $6, Progressive Downloader free —
  **the literal download-manager comp set tops out at $20.**
- CleanShot X ($29 one-time) and Alfred Mega Supporter (£59) are the
  upmarket utility benchmarks — **$29 sits at the sweet-spot anchor.**
- Subscription without real server infra = reviewer backlash (Bartender
  2024). Splynek doesn't run servers → don't go subscription.
- Family-pack upsell — estimated **15–25% take-rate** on well-positioned
  second tiers; blended ARPU rises from $29 to ~$33 at 20% take-rate.

### Recommendations

1. **Keep Splynek Pro at $29 one-time** on Mac App Store. Do NOT
   discount toward Downie's $19.99 — that cannibalizes perceived value
   and gives only marginal volume pickup.

2. **Launch `Splynek Pro+` at $49 at month 6.** Bundle:
   - 3-seat Family Sharing unlock (real 3-seat license, not Apple's
     built-in Family Sharing which is free).
   - iOS Companion premium features (scheduled downloads from phone,
     cross-LAN relay via optional anonymized CloudKit).
   - **File Witness** batch receipt export.
   - Priority 24-h email response.

3. **Edu 30% off ($20) from day one.** Copy CleanShot X's edu flow
   exactly. Zero implementation cost (ASC promo codes); expands TAM
   into students/researchers (a real buyer segment for bulk PDFs +
   File Witness).

4. **"Founders pricing: $29 until Jan 1, 2027"** label in the MAS
   listing. Standard growth-marketing tactic, creates urgency, lets
   you raise to $39 in 2027 with a clear narrative.

5. **Defer Setapp to month 9.** Research shows 30k impressions in week
   one for new Setapp apps; but it cannibalizes full-price direct
   sales and Downie's presence there already compresses category
   perceived value. Let the MAS cohort stabilize first, A/B measure
   cannibalization.

6. **Defer subscription indefinitely** unless we add a real cloud
   component (and we shouldn't, per the "no cloud" wedge).

7. **Never add ads, never add telemetry.** These are the cross-category
   anti-patterns that kill indie brands.

### 12-month revenue target

| Quarter | Revenue move | Estimated ARR contribution |
|---|---|---|
| Q1 (launch) | $29 MAS + direct, Edu 30% off, Founders pricing label | $20k |
| Q2 | Foundation Models press cycle, iOS companion beta | +$30k |
| Q3 | Pro+ tier at $49 (20% take-rate), Household Mode ship | +$50k |
| Q4 | Setapp enrollment, year-1 paid upgrade start | +$40k |
| **Total year-1 gross** | | **~$140k** |
| **Net after platform fees** | | **~$115k** |

---

## 5. Distribution & launch

The single most leveraged move is still Show HN + Product Hunt +
MacStories pitch. But v1.0's narrative needs a refresh first.

### Refined launch narrative (drop the dry "multi-interface" lead)

**Old headline:** "Splynek: use every network at once"
**New headline:** **"Splynek: the macOS download manager that's
actually private"**

Sub-line: *"100% on-device AI. Resumes through anything. Your Mac
and your household, co-operating over the LAN. No cloud, no account,
no telemetry."*

The multi-interface bit becomes the first proof point in the demo
video, not the headline.

### Press cycle schedule

| Week | Action |
|---|---|
| 0 | Ship v1.0 (done) |
| 1 | Ship Bet A1 (App Intents + Control Center) |
| 2 | **Show HN post** (revised narrative) + Product Hunt + r/macapps |
| 2 | Benchmark PNG amplifier live, seed 5 benchmark tweets ourselves |
| 3 | Ship Bet S1 (Foundation Models Concierge) |
| 3 | **MacStories / iDownloadBlog / AppleInsider pitch**: "First download manager with Apple Intelligence" |
| 4 | Ship Bet S3 (yt-dlp swallow) |
| 4 | r/academicresearch + r/gradschool post re: DOI batch mode |
| 8 | Ship Bet S4 (iOS companion beta) |
| 12 | **Second press cycle**: "Splynek 1.1 with iPhone companion" — iCloud-free download handoff angle |
| 16 | Ship Pro+ tier + Household Mode |

Each of Bet S1, S3, S4 is a re-pitchable press cycle. We get 3–4
shots on goal, not one.

### Community-building move

**Publish a `Splynek Extensions API`** by month 6 — JSON-configured
site adapters for hosters / streamers / niche sites. Follows the
Raycast playbook: the extension ecosystem becomes the distribution
flywheel. Estimated payoff is latent (6–12 months) but compounds.

---

## 6. The moat (why this is defensible)

Each piece alone is a feature. Together they are a category reset
that incumbents structurally cannot adopt:

| Splynek has | Folx has? | Downie has? | Speedify has? | Built-in Safari has? | Why incumbents can't copy it quickly |
|---|---|---|---|---|---|
| Multi-interface bonding (no VPN, no cloud) | ❌ | ❌ | ❌ (cloud relay) | ❌ | Requires IP_BOUND_IF + Range-chunked HTTP logic |
| Browser-extension Accelerator (HLS + big downloads) | ❌ | ❌ | ❌ | ❌ | Requires both browser ext + multi-interface engine |
| Apple Foundation Models Concierge | ❌ | ❌ | ❌ | ❌ | They don't have on-device LLM plumbing |
| Bonjour LAN cache + Household Mode | ❌ | ❌ | ❌ | ❌ | Requires fleet protocol design |
| Cryptographic receipts | ❌ | ❌ | ❌ | ❌ | Category blindspot, one-day feature |
| iOS Live Activity companion | ❌ | ❌ | ❌ | ❌ | Requires iOS target + ActivityKit |
| BitTorrent v2 hybrid | Partially | ❌ | ❌ | ❌ | Requires years of libtorrent work |
| Native SwiftUI, sandboxed, notarised | Partially | ✓ | ❌ (VPN) | n/a | — |
| MIT-licensed free tier | ❌ | ❌ | ❌ | n/a | Business-model mismatch |

The combination of **(a) multi-interface + (b) Apple Foundation Models
+ (c) LAN co-op + (d) cryptographic receipts** is uncopyable without
a complete engineering restart. We have a 6–12 month lead on any
incumbent that wanted to match it.

---

## 6.5. What we explicitly do NOT do

Positioning discipline matters. The following are *tempting* but we
reject them deliberately:

1. **Full-system VPN bonding (Speedify clone).** Requires the
   NetworkExtension entitlement, contradicts our VPN-negation to Apple
   review, demands a cloud relay that breaks the no-cloud wedge,
   pushes us toward a subscription model. Hard no. Users who want
   this should buy Speedify; we'll say so openly.
2. **Cloud sync / account system.** Every product decision goes
   through "does this keep the user's data on their Mac?" A cloud
   queue, server-side download orchestration, remote logins — all
   tempting, all corrosive to the wedge. LAN + Bonjour + optional
   E2E-encrypted CloudKit relay is the maximum cloud surface we
   accept, and only when LAN is unavailable.
3. **Cryptocurrency / IPFS / web3 integration.** No.
4. **DRM circumvention.** Netflix / Disney+ / Apple TV+ streams
   remain off-limits. We accelerate open HLS (YouTube, Vimeo,
   Twitch non-subscriber streams) but don't touch Widevine / FairPlay.
5. **"AI agent that auto-downloads things for you".** The Concierge
   is proactive but the user always clicks to queue. We don't build
   autonomous download daemons — that's the road to category
   backlash and Apple review rejections.
6. **Paid plugin marketplace where authors keep revenue.** Plugin
   marketplace = yes, later (Bet §5). Revenue split to plugin
   authors = brings tax + legal + payout complexity we can't
   support as a solo dev.

## 7. Risks + counter-moves

1. **Apple sherlocks multi-interface in macOS 27.** Mitigation: our
   moat isn't multi-interface alone; it's the combination. Even if
   Apple ships `.aggregate` multipath TCP to user-space, Splynek's
   AI Concierge + LAN co-op + cryptographic receipts remain.

2. **Foundation Models API changes / deprecates.** Mitigation: keep
   the Ollama/LM Studio fallback as a permanent path. Users on older
   macOS + users who want a specific model still get the Pro features.

3. **Apple rejects features in review.** We've already absorbed the
   VPN questionnaire cleanly. Mitigation: stay sandboxed, keep
   entitlements minimal, keep the Pro+ tier in a separate release
   cycle from MAS so rejection of one doesn't block the other.

4. **Support burden at 1000+ customers exceeds solo bandwidth.**
   Mitigation: (a) public FAQ on splynek.app/support, (b) in-app
   "search help" Concierge intent, (c) cap support SLA at 48h
   weekdays, (d) auto-responder for common issues via a lightweight
   local model.

5. **Household Mode trust flaw — someone sees what their kid is
   downloading.** Mitigation: content-addressed hashes only, per-
   device opt-in, "ignore downloads under 10 MB" default to avoid
   exposing daily browsing. Clear consent flow in UX.

6. **iOS Companion review rejection.** Unlikely (we've submitted
   Splynek on Mac, same bundle ID logic applies). Mitigation: ship
   with Share Extension + Live Activity only for v1; defer fancier
   features (background fetch, widgets) to v1.1.

---

## 8. 90-day execution plan (opinionated, dated)

### Weeks 1–3 (May 2026)
- [ ] App Intents + Shortcuts + Siri integration (Bet A1)
- [ ] Control Center widgets (Bet A1)
- [ ] Foundation Models Concierge (Bet S1)
- [ ] Ship v1.1 → Show HN post (revised narrative)
- [ ] Seed 5 benchmark tweets from friendly accounts

### Weeks 4–7 (June 2026)
- [ ] NWPathMonitor retry + mirror failover (Bet S2)
- [ ] yt-dlp bundle + auto-update + DOI list mode (Bet S3)
- [ ] Rules engine v1 (Bet A2)
- [ ] Ship v1.2 → MacStories + AppleInsider pitch ("First download manager with Apple Intelligence + yt-dlp swallowed")

### Weeks 8–12 (July 2026)
- [ ] iOS Companion skeleton (Bet S4) — Share Extension + Live Activity
- [ ] **Splynek Accelerator — Safari + Chrome extensions (Bet S5)**:
      auto-route large downloads + HLS pre-buffer via bonded multi-path
- [ ] Benchmark PNG amplifier (Bet A5)
- [ ] File Witness v1 (Bet A3)
- [ ] Ship v1.3 → Second press cycle: "Splynek iPhone companion + Accelerator browser extension — your Mac's internet, bonded"

### Week 13 (August 2026)
- [ ] Launch Pro+ tier at $49 with Family 3-pack + Priority Support + File Witness batch export
- [ ] Edu 30% off already live from day 1 (nothing new this milestone)
- [ ] Assess: conversion rate to Pro (target 3%), take-rate to Pro+
      (target 20%)

### Month 6 (October 2026)
- [ ] Household Mode (Bet A4)
- [ ] Extensions API beta
- [ ] Consider Setapp enrollment

---

## 9. The call

**You asked: is this a no-brain buy for the broadest audience possible?**

At v1.0 *today*, no. It's a credible power-user product at $29. The
pain points are real and mostly solved, but the narrative isn't
sharp enough yet, and the two biggest wedges (on-device AI as first-
class, iOS companion) aren't shipped.

At v1.3 (end of July 2026, ~90 days of focused work), **yes** — with
high conviction:

- Apple Foundation Models Concierge removes the "install Ollama"
  friction (killer for non-technical buyers).
- Unbreakable resume + mirror failover solves the top user complaint.
- yt-dlp swallow kills Downie + every sketchy web-downloader.
- iOS companion + Live Activity gives a uniquely visible demo moment
  nobody else has.
- File Witness carves out a journalist/academic niche for free.
- Household Mode creates viral loops inside families.

The narrative shifts from "multi-interface download manager" to
**"the private, AI-native download experience for macOS 2026."**

For $29 it becomes an obvious yes for anyone who downloads more than
once a week — which is ~every working Mac user.

---

## Appendix — sources

- [Setapp Folx reviews](https://setapp.com/apps/folx/customer-reviews)
- [mjtsai: Downie anti-piracy scare](https://mjtsai.com/blog/2024/03/13/downies-anti-piracy-scare-tactic/)
- [Apple Community: Safari resume broken](https://discussions.apple.com/thread/251250011)
- [MacRumors: Safari resume thread](https://forums.macrumors.com/threads/i-cant-resume-downloads-files-with-safari.1110019/)
- [MacStories Folx review](https://www.macstories.net/reviews/folx/)
- [MacStories Tahoe review](https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/3/)
- [Apple ML Research — Foundation Models 2025](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- [Apple Developer — Foundation Models docs](https://developer.apple.com/documentation/FoundationModels)
- [WWDC25 session 244 — Get to know App Intents](https://developer.apple.com/videos/play/wwdc2025/244/)
- [Apple Developer — Control Widget](https://developer.apple.com/documentation/swiftui/controlwidget)
- [9to5Mac — macOS 26 Live Activities mirror iOS](https://9to5mac.com/2025/06/16/macos-26-live-activities-work-even-if-your-iphone-is-on-ios-18/)
- [WWDC21 10094 — HTTP/3 + QUIC](https://developer.apple.com/videos/play/wwdc2021/10094/)
- [mptcp.dev — macOS guide](https://www.mptcp.dev/macOS.html)
- [Apple — iCloud Private Relay prep](https://developer.apple.com/icloud/prepare-your-network-for-icloud-private-relay/)
- [Apple — Continuity requirements](https://support.apple.com/en-us/108046)
- [Raycast pricing](https://www.raycast.com/pricing)
- [CleanShot X pricing](https://cleanshot.com/pricing)
- [Setapp developers](https://setapp.com/developers)
- [Adapty — Utilities subscription benchmarks 2026](https://adapty.io/blog/utilities-app-subscription-benchmarks/)
- [Adapty — Trial conversion rates 2026](https://adapty.io/blog/trial-conversion-rates-for-in-app-subscriptions/)
- [Apple Support — Native link aggregation (Ethernet-only)](https://support.apple.com/en-hk/guide/mac-help/mchlp2798/mac)
- [Speedify Mac bonding (the only cloud-routed competitor)](https://speedify.com/blog/combining-internet-connections/network-bonding-on-mac-guide/)
- [Free Download Manager backdoor incident (Wikipedia)](https://en.wikipedia.org/wiki/Free_Download_Manager)
- [yt-dlp Twitch issue #8958](https://github.com/yt-dlp/yt-dlp/issues/8958)
- [SciHubDownloader (explicitly no Mac)](https://github.com/HocfaiSun/SciHubDownloader)
- [Homebrew JDownloader JVM issue](https://github.com/Homebrew/homebrew-cask/issues/55517)

---

*This memo is intended to be durable through April 2026. Revisit at
v1.3 launch. Kill any bet that loses conviction in implementation;
the bet count should decrease, not increase, with time.*
