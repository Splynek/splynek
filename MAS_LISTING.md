# Splynek — Mac App Store listing

Copy-paste-ready material for App Store Connect. Each section below maps 1:1 to a field in the ASC app page. Character counts noted where Apple enforces them.

---

## App name (30 char max)

**Splynek**

(6 chars. Room for a suffix if this base name is taken — fallbacks: *Splynek — Download Manager* / *Splynek Downloader*. Check availability first at App Store Connect → My Apps → + → the name field validates live.)

## Subtitle (30 char max)

**Use every network, at once**

(27 chars, includes a breath-pause. Alternatives:
- *Parallel downloads, every NIC* (29)
- *Wi-Fi + Ethernet + tether, synced* (33 — too long)
- *Downloads via every network* (27)
- *Multi-interface downloader* (26)
Pick the punchiest; "Use every network, at once" wins on curiosity.)

## Promotional text (170 char max, editable without new submission)

**Downloads that add your Wi-Fi, Ethernet, and iPhone tether into one stream. Cooperative over your LAN, verified with SHA-256. Zero subscriptions, zero telemetry.**

(161 chars. Update on each release.)

## Description (4000 char max)

```
Splynek is a native macOS download manager that uses every network
interface your Mac has — simultaneously.

Plug in your iPhone's USB tether, connect to Ethernet and Wi-Fi at
the same time, or chain a Thunderbolt NIC, and Splynek will
download a single file in parallel across all of them using HTTP
byte-range requests. 2–3× faster downloads in realistic conditions,
without paying for a VPN or a faster plan.

KEY FEATURES

• Multi-interface aggregation — Splynek binds each download lane to
  a specific network interface via Apple's Network.framework.
  Interfaces work independently: a flaky Wi-Fi doesn't block
  Ethernet; a cellular rate cap doesn't slow down home LAN. Each
  lane has its own health check, failover, and per-interface daily
  byte cap.

• BitTorrent that respects your network — both v1 and v2, magnet
  links, DHT, seeding. Every tracker announce and peer connection
  is pinned to the network interface you chose, so your iPhone
  tether doesn't accidentally sync a 40 GB torrent.

• Live dashboard — a dedicated view for running downloads showing
  72-pt MB/s headlines, per-lane throughput grids, phase-pipeline
  visualisations, and transport controls. The kind of real-time
  view you'd build for yourself if you cared about this stuff.

• History with context — every completed download is logged with
  its interfaces, bytes-per-lane, and SHA-256. Search, filter,
  reveal, re-download. The "how did this file get here" question
  has an answer.

• Browser integrations — Chrome extension, Safari bookmarklets,
  Raycast extension, Alfred workflow. All push URLs into Splynek
  via the splynek:// URL scheme.

• Local AI assistant (Pro) — a chat-first Concierge powered by
  Ollama (local LLM, no cloud; your data never leaves your Mac).
  Ask for a download by description, search your history in
  natural language, or let the Agentic Recipes feature plan a
  multi-step download batch from a goal like "set up my Mac for
  iOS development."

• Scheduled downloads (Pro) — restrict downloads to time windows
  (e.g., overnight on home Wi-Fi), weekdays, and cellular-off
  rules. Running downloads are never interrupted; the schedule
  only gates starts.

• Mobile-phone pairing (Pro) — a LAN-accessible web dashboard that
  your phone connects to via QR code. Submit URLs from your phone;
  Splynek handles the download on your Mac. Your phone stays fast;
  the download doesn't touch its battery.

PRIVACY & TELEMETRY

Splynek collects nothing. No accounts, no tracking, no crash
reports, no phone-home. Your download history lives on your Mac,
period. The full source code for the free tier is MIT-licensed and
available at github.com/Splynek/splynek.

WHAT'S FREE, WHAT'S PRO

Free: multi-interface HTTP aggregation, torrents, queue, history,
Live dashboard, Benchmark, Watched folder, CSV export,
Chrome/Safari/Raycast/Alfred integrations, menu-bar mode,
Gatekeeper signature inspection, per-host caps, cellular budget.

Splynek Pro ($29 one-time, lifetime 0.x updates): AI Concierge,
Agentic Download Recipes, Scheduled Downloads, LAN-exposed
mobile-phone pairing.

SYSTEM REQUIREMENTS

macOS 13.0 or later. Apple silicon or Intel. No third-party
dependencies required.
```

(~2,200 chars. Room to grow in ~800 characters over the next several releases.)

## What's new in this version

First submission (v0.45):

```
Splynek's first Mac App Store release. Compared to the free DMG
build at github.com/Splynek/splynek:

• Signed + notarised — no right-click-to-open dance.
• Auto-updates via the App Store.
• In-App Purchase for Splynek Pro — AI Concierge, Agentic Recipes,
  Scheduled Downloads, and LAN-accessible mobile-phone pairing.

Existing DMG users: your v0.44 install keeps working. Upgrading to
the App Store build is a fresh install; history doesn't migrate
yet (tracked for v0.46).
```

## Keywords (100 char max, comma-separated)

**`download manager, BitTorrent, magnet, iPhone tether, parallel, accelerator, Ethernet, metalink`**

(97 chars. Test ordering with Apple Search Ads keyword tool — leftmost keywords weigh more.)

## Category

- **Primary:** Utilities
- **Secondary:** Productivity

(`LSApplicationCategoryType = public.app-category.utilities` in Info.plist.)

## Pricing

- **Base app:** Free (everyone can install; core features work without IAP)
- **In-App Purchase — "Splynek Pro":**
  - Product ID: `app.splynek.Splynek.pro` (must match `LicenseManager.proProductID`)
  - Type: Non-Consumable
  - Price: Tier 29 ($29.99 USD; localised to all regions at equivalent tiers)
  - Reference name (internal): `Splynek Pro`
  - Display name (shown to users): `Splynek Pro`
  - Description:
    ```
    Unlock AI Concierge, Agentic Download Recipes, Scheduled
    Downloads, and LAN-accessible mobile-phone pairing. One-time
    purchase. Lifetime updates on the 0.x release line.
    ```
- **Small Business Program:** Enrolled (15% Apple cut under $1M/year).

## Privacy labels — Data Not Collected

For every one of the 14 data categories on ASC → App Privacy, select **"Data Not Collected."** Splynek has no telemetry, no accounts, no crash reports, no analytics. Every byte of user data stays on the user's Mac.

Categories (all → Not Collected):
1. Contact Info
2. Health & Fitness
3. Financial Info
4. Location
5. Sensitive Info
6. Contacts
7. User Content
8. Browsing History
9. Search History
10. Identifiers
11. Purchases
12. Usage Data
13. Diagnostics
14. Other Data

**One caveat:** Apple itself logs IAP transactions server-side, but that's on the developer side (linked to your Apple ID, invisible to us) — not data we collect. The ASC form doesn't count this as app-collected data.

## Review notes — paste into ASC → App Review → Notes

```
Hi Reviewer,

Splynek is a multi-interface download manager for macOS. It binds
outbound connections to different network interfaces (Wi-Fi,
Ethernet, iPhone USB/Personal Hotspot, Thunderbolt NICs) and
downloads files in parallel across them using HTTP byte-range
requests. BitTorrent v1/v2 is also supported.

ENTITLEMENTS JUSTIFICATION

• com.apple.security.network.client — every download is outbound
  HTTPS/HTTP. Core functionality.

• com.apple.security.network.server — Splynek runs a local HTTP
  server for two purposes:
    (a) A loopback-only (127.0.0.1) web dashboard used by the
        menu-bar popover and browser extensions (Chrome, Safari).
        Free-tier behaviour.
    (b) A LAN-accessible HTTP server for mobile-phone pairing via
        QR code — users submit download URLs from their phone;
        Splynek handles the download on their Mac. Pro-tier only,
        gated by the In-App Purchase. Token-authenticated; never
        exposed publicly; always opt-in from Settings.

• com.apple.security.files.user-selected.read-write — standard
  output-directory picker, watched-folder picker.

• com.apple.security.files.downloads.read-write — ~/Downloads is
  the default output location.

• com.apple.security.files.bookmarks.app-scope — persists the
  user-selected watched folder across launches via a security-
  scoped bookmark.

TESTING THE $29 IN-APP PURCHASE

The non-consumable IAP "Splynek Pro" (product ID
app.splynek.Splynek.pro) unlocks four features:
  1. Sidebar → Assistant (AI chat powered by local Ollama)
  2. Sidebar → Recipes (multi-step download planner)
  3. Settings → Download schedule card
  4. Settings → Web dashboard card (LAN-exposed QR pairing)

To trigger: Settings tab → Splynek Pro card → "Buy Splynek Pro —
$29" button. A StoreKit sheet appears. "Restore Purchase" (same
card) works if the tester has already purchased.

LOCAL AI / OLLAMA NOTE

The Assistant, Recipes, and history-search features use Ollama
(ollama.com/download), a local LLM runtime that the user installs
and runs on localhost:11434. Splynek talks to it over loopback
only — no data leaves the user's Mac. If Ollama isn't running, Pro
features display a friendly "install Ollama to enable" message.
The AI works entirely offline; we don't send user data to any
cloud service.

For your testing convenience, the Pro features are gated behind
ollama-detection; if Ollama isn't installed on the review machine,
the Assistant tab shows a clear install prompt instead of
erroring. You don't need to install Ollama to complete review.

POTENTIAL CONCERNS

Q: "Why does the app bind to specific network interfaces?"
A: That's the core value proposition — combining bandwidth from
multiple interfaces for a single download. Uses Network.framework's
standard requiredInterface parameter (public API, available since
macOS 10.14). No private API usage.

Q: "Is this a VPN?"
A: No. Splynek doesn't tunnel, proxy, or alter DNS. It downloads
directly from origin servers; each lane simply uses a different
network interface. No VPN entitlement, no Network Extension
entitlement.

Q: "Why is BitTorrent included?"
A: BitTorrent is a common protocol for large legitimate downloads
(Linux ISOs, game updates, scientific datasets). Splynek
implements BEP 1, 9, 10, 23, 52, 29 per spec. We don't host a
tracker, don't help discover content, don't index torrents. Users
supply their own .torrent files or magnet links.

Q: "Why does the app ship bundled browser extensions?"
A: The Chrome extension and Safari bookmarklets are optional
convenience tools that send URLs to Splynek via the splynek://
URL scheme. They're not automatically installed — Settings → Browser
Helpers reveals the bundled files for user-initiated installation.

BUILD NOTES

The source code for the free tier is MIT-licensed and publicly
available at github.com/Splynek/splynek. The Pro modules (Concierge,
Recipes, Scheduling, LAN-exposure) live in a private repository
and are linked only into this App Store build. This lets the app
stay open-source-first while still enforcing the $29 Pro unlock
via StoreKit.

If you have any questions, please reach out at paulo@splynek.app.

Thanks for reviewing,
Paulo Graça Moura
paulo@splynek.app
https://splynek.app
```

## Copyright

`© 2026 Splynek. Source (free tier) available under MIT license.`

## Support URL

`https://splynek.app/support`  *(points at a page with email contact + GitHub issues link — add to the site before submission)*

## Marketing URL

`https://splynek.app`  *(already live via GitHub Pages)*

## Privacy policy URL

`https://splynek.app/privacy`  *(add a page; boilerplate: "Splynek collects no personal data. No accounts, no telemetry, no crash reports. Downloads are direct; Splynek is not a proxy or VPN. IAP transactions are handled entirely by Apple; we never see payment details or your email.")*

## Age rating

**4+** (no objectionable content).

When filling ASC's age-rating form: select "None" for every category (violence, sexual, alcohol, gambling, horror, profanity, medical information, etc.). Splynek is a utility app with zero age-gated content.

## Export compliance

`ITSAppUsesNonExemptEncryption` is set to `false` in the MAS Info.plist because Splynek's crypto usage (HMAC-SHA256 for receipts, TLS for downloads) is exempt under BIS 740.17(b)(3)(i) — symmetric crypto ≤ 256 bits used for authentication / access control / data transport, not for confidentiality of non-TLS protocols. This skips the per-release export-compliance question in ASC.

## Taking the screenshots

Quickest path: do it yourself in ~10 minutes with the app running in real state. Apple won't accept placeholder/mockup screenshots — they want actual UI.

**Setup:**
1. Build the MAS variant once for real screenshots:
   ```sh
   cd "/Users/pcgm/Claude Code"
   xcodebuild -project Splynek.xcodeproj -scheme Splynek-MAS \
       -configuration Release-MAS build CODE_SIGNING_ALLOWED=NO
   open /Users/pcgm/Library/Developer/Xcode/DerivedData/Splynek-*/Build/Products/Release-MAS/Splynek.app
   ```
   (Signing not required for a screenshot session — ad-hoc is fine.)

2. Kick off a real download from the Downloads tab. Use a ~200 MB file that'll stay running long enough to capture the Live dashboard, e.g.:
   ```
   https://releases.ubuntu.com/24.04/ubuntu-24.04.1-desktop-amd64.iso
   ```
   (or any signed DMG from a GitHub Releases page). Select at least two interfaces so the per-lane grid populates.

3. Let 3–5 downloads complete for History screenshots — small files are fine.

**Capture with the built-in screencapture:**

```sh
# Interactive window capture (click the Splynek window)
screencapture -Pw ~/Desktop/splynek-downloads.png    # -P opens preview
screencapture -w ~/Desktop/splynek-live.png
screencapture -w ~/Desktop/splynek-torrents.png
screencapture -w ~/Desktop/splynek-queue.png
screencapture -w ~/Desktop/splynek-history.png
screencapture -w ~/Desktop/splynek-settings.png
```

`-w` captures a specific window you click on. On a Retina display, the PNG comes out at the window's rendered pixel size (typically ~2x logical pts). Apple accepts 2880×1800 or 2560×1600 — resize in Preview → Tools → Adjust Size if needed.

**Retina-quality, scripted:**

```sh
# Find Splynek's window ID, capture without chrome:
WIN_ID=$(osascript -e 'tell app "System Events" to id of window 1 of process "Splynek"')
screencapture -l "$WIN_ID" ~/Desktop/splynek-$(date +%s).png
```

## Screenshots plan

Required: ≥ 1 screenshot per device class. macOS accepts 1280×800, 1440×900, 2560×1600, or 2880×1800 (Retina preferred). We submit 6 Retina screenshots at **2880×1800**.

| # | Screen | What it shows |
|---|---|---|
| 1 | **Downloads tab, active** | URL field with a real URL pasted + interfaces list with Wi-Fi + Ethernet + iPhone tether all checked. The hero shot: "I have three networks, look." |
| 2 | **Live dashboard, running** | Big MB/s headline, per-lane throughput grid, phase strip. The proof shot. |
| 3 | **Torrents tab** | Magnet pasted, piece grid populated, peer count, seeding toggle. |
| 4 | **Queue** | 5–6 entries at various statuses — running, pending, completed, failed — shows the workflow. |
| 5 | **History with the detail sheet open** | Shows the "1.8×" speedup banner, the interface-contribution bar, SHA-256 details. The "look how much faster this is" shot. |
| 6 | **Splynek Pro settings card (MAS build)** | StoreKit "Buy — $29" button + Restore Purchase + the four-feature bullet list. |

Captions for each (Apple shows them beneath the screenshot in the Store):

1. *"Every network interface, in parallel — Wi-Fi, Ethernet, iPhone tether, all at once."*
2. *"Live throughput per interface. See exactly which network is pulling its weight."*
3. *"BitTorrent v1 + v2. Every peer connection pinned to the interface you picked."*
4. *"A queue that remembers what you wanted. Persisted across launches."*
5. *"See the speedup per download. Know exactly how much time multi-interface saved."*
6. *"$29 unlocks AI Concierge, Recipes, Scheduling, and phone pairing. Lifetime updates."*

## Submission checklist

Before hitting "Submit for Review" on ASC:

- [ ] App Record created in ASC with bundle ID `app.splynek.Splynek`
- [ ] IAP record created: product ID `app.splynek.Splynek.pro`, Non-Consumable, Tier 29
- [ ] Apple Distribution + Developer ID Application signing certificates installed (Xcode → Settings → Accounts → Manage Certificates)
- [ ] Small Business Program application submitted
- [ ] Privacy labels filled: 14× "Data Not Collected"
- [ ] Screenshots uploaded (6× 2880×1800)
- [ ] Description, keywords, subtitle, promotional text filled
- [ ] Review notes pasted (see § above)
- [ ] Support URL live at `https://splynek.app/support`
- [ ] Privacy policy URL live at `https://splynek.app/privacy`
- [ ] `xcodegen generate` run to refresh `Splynek.xcodeproj`
- [ ] `xcodebuild -project Splynek.xcodeproj -scheme Splynek-MAS archive` succeeds with real signing
- [ ] Archive validated via Xcode Organizer → Validate App
- [ ] Archive uploaded via Xcode Organizer → Distribute App → App Store Connect
- [ ] TestFlight internal testing round (optional but recommended; catches sandbox issues before public review)
- [ ] "Submit for Review" button clicked with above review notes attached
