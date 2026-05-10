# Smoke-test runbook — PRO-PLUS-IPHONE Sprints 1-5

> **When to run this:** before tagging the next release after the
> 23-commit PRO-PLUS-IPHONE arc (`5e30f5c` → `552430c`) lands on
> `main`.  Walks every Pro surface + every iPhone Companion path
> end-to-end.  Sprint 5 (Raycast + L10n round 2) and the watchOS
> targets need their respective SDKs / paired hardware to fully
> verify.

> **Time budget:** ~30 min for the Mac + iPhone path; +20 min if
> you also exercise Watch + Raycast.

> **Reset between runs:** the JSON stores at
> `~/Library/Application Support/Splynek/` carry state across
> launches.  If you need a clean slate:
>
> ```sh
> rm -f ~/Library/Application\ Support/Splynek/{trust-watcher,migrate-review-list,engagement,api-tokens}.json
> ```

---

## 1. Mac — Trust Watcher (Sprint 1)

- [ ] Pro license active (Settings → Splynek Pro shows ACTIVE).
- [ ] Open Trust tab → confirm the **Trust Watcher card** sits at the top of scan results.
- [ ] Empty state: card shows `WATCHING N` pill (where N matches `TrustWatchCatalog.watchedBundleIDs.count`, currently 12) + last-sweep label.
- [ ] Click **Run now** → progress; after sweep, alerts (if any) appear; pill flips to `K NEW` for K pending alerts.
- [ ] Click an alert's **View page** → opens the policy URL in Safari.
- [ ] Click **Dismiss** on an alert → row disappears; pending count decrements.
- [ ] Click **Clear all** → every pending alert acknowledged; pill flips back to `WATCHING N`.
- [ ] Switch license OFF (free tier) → card replaced with **ProLockedView** upsell. Switch back to Pro → card returns.

## 2. Mac — Sovereignty Migrate Wizard (Sprint 2)

- [ ] Sovereignty tab → matched-rows section.
- [ ] Each alternative row has a **Migrate Original → Alt** button (Pro) OR **Migrate (Pro)** lock-icon (free).
- [ ] Click Migrate → modal sheet opens with header `Migrate {original} → {alt}` + N steps + "each one runs only when you confirm" subtext.
- [ ] Step-by-step: click **Run with confirmation** on a `markOriginalForReview` step → alert appears with the step's `confirmationPrompt` → click Confirm + run → row gets ✓ Done.
- [ ] **Run all (with confirmations)** runs only the safe (non-destructive) steps; destructive steps still require their per-row confirmation.
- [ ] Close sheet. Reopen Sovereignty tab → at the top of matched-rows: **Sovereignty Migrate review banner** appears with stale-week filter (>7 days). For freshly-marked entries the banner stays hidden until 7 days pass.
- [ ] Banner row: **Open {alt}** opens homepage; **I'm done; forget this** removes from list.

## 3. Mac — Concierge migrate digest (Sprint 3)

- [ ] In Concierge (Pro), prompt: "what's on my migration list?" or "did I switch from Spotify yet?".
- [ ] Concierge picks `migrate_review_digest` tool.
- [ ] Response: `.text` card with "N apps on your migration list. {names}" + stale-week nudge if applicable.
- [ ] Empty list returns the explainer ("when you click Migrate on a Sovereignty alternative, the original lands here").

## 4. Mac — Pricing telemetry + Trust+ upsell (Sprint 3 + 4)

- [ ] Settings → scroll to **Your engagement (read-only)** card (Pro).
- [ ] Three groups visible: Trust Watcher / Sovereignty Migrate / iPhone Companion.
- [ ] Counters non-zero after the smoke-test runs above.
- [ ] **Show JSON file** → Finder reveals `~/Library/Application Support/Splynek/engagement.json`.
- [ ] If `EngagementGate.shouldOfferTrustPlus` fires (≥20 Trust-Watcher engagement events): **Splynek Trust+** upsell card appears below.
  - **I'd be interested** opens mailto: trust-plus@splynek.app with pre-filled subject/body.
  - **Not interested** hides the card for the session.

## 5. Mac — API tokens (Sprint 4)

- [ ] Settings → **API tokens** card (Pro; ProLockedView for free).
- [ ] Empty state: "No tokens minted yet." + mint form.
- [ ] Mint a token: label "Smoke test", scope **Read + write** → click Mint → row appears, secret auto-revealed.
- [ ] **Copy** copies the secret to clipboard.
- [ ] Use the secret from terminal:
  ```sh
  curl "http://localhost:55432/splynek/v1/api/jobs?t=<paste>" | jq
  ```
  Expect 200 with the jobs JSON. Token's `lastUsedAt` updates.
- [ ] Mint a **Read-only** token → confirm it returns 401 on a POST:
  ```sh
  curl -X POST "http://localhost:55432/splynek/v1/api/pause-all?t=<readonly>"
  # → 401 Unauthorized
  ```
- [ ] **Revoke** a token → row disappears; subsequent requests with that secret return 401.

## 6. iPhone Companion (Sprint 1 + 2 + 5)

- [ ] Insights tab (4th tab) shows: paired-Mac header, four cards (Sovereignty / Trust / Trust Watcher / Recent downloads).
- [ ] Pull-to-refresh works.
- [ ] Trust Watcher card on a Pro Mac shows pending count + recent alerts; on a free Mac shows "Splynek Pro feature" upsell.
- [ ] Submit a URL via the Share Extension from Safari → toast on the iPhone; download appears on Mac.
- [ ] **App Intents — Hey Siri:**
  - "Hey Siri, send to Splynek" → URL dialog → URL queued on Mac.
  - "Hey Siri, pause Splynek downloads" → toast confirms.
  - "Hey Siri, what's my Splynek sovereignty score" → answer with score + stat.
- [ ] **Home-screen Widget** — small + medium families render Sovereignty score + active downloads + Trust Watcher pending count.
- [ ] **Geo-fence** (Sprint 2 part-2):
  - Settings → Geo-fence section visible.
  - Toggle on, request whenInUse + always location permission.
  - "Use current location as home" → status flips to "Set".
  - Walk physically out of the radius → after a few seconds, Mac downloads pause (Mac engagement counter `iphoneRemoteCommands` increments).
- [ ] **Pairing flow updated copy** (Sprint 5): Token section shows "Recommended: API token (Pro)" + "Or: session token" hierarchy. Both still pair successfully.

## 7. iPhone push notifications (Sprint 1)

- [ ] On the Mac, force a Trust Watcher alert (e.g. by manually inserting a stale snapshot via the JSON file then Run-now).
- [ ] CloudKit container `iCloud.app.splynek.companion` provisioned + `SplynekTrustWatchAlert` schema promoted to Production (maintainer step).
- [ ] iPhone receives a UNNotification: "Spotify Privacy Policy changed (notable)".
- [ ] Notification has a "View page" action that opens the policy URL.
- [ ] If the schema isn't provisioned: Mac logs a warning under subsystem `app.splynek/TrustWatchCloudKit`; iPhone push silently no-ops; local UI is unaffected (graceful degrade).

## 8. Apple Watch (Sprint 2 part-2 + Sprint 3)

> watchOS SDK install (Xcode → Settings → Components → watchOS) required for compile-verify.

- [ ] Pair iPhone-paired Watch.
- [ ] Splynek Watch app launches → reads paired Mac from App Group plist (no separate pairing step).
- [ ] **Pause all** button → haptic .success + toast "Paused on {Mac}".
- [ ] **Resume all** button → haptic .success.
- [ ] Sovereignty score row visible with traffic-light tint.
- [ ] On a watch face, add a complication → **Splynek** appears with three families (circular / rectangular / inline). Each renders the score live.

## 9. Raycast extension (Sprint 5)

> Requires `node_modules` install + `npm run dev` in `Extensions/Raycast/splynek/`.

- [ ] Raycast preferences → Splynek: enter host, port, API token (use the "Smoke test" token minted in step 5).
- [ ] **Submit URL to Splynek** → form submits → Mac queues download. Toast on success.
- [ ] **Active Splynek Downloads** → list with phase pills + auto-refresh every 3s.
- [ ] **Splynek Sovereignty Score** → Detail with Markdown rendering, traffic-light emoji, top-5 concerns.
- [ ] **Pause All** + **Resume All** no-view commands → toast confirms.
- [ ] Use a **Read-only** API token → Submit / Pause / Resume return 401 (toast surfaces the error). Active Downloads + Sovereignty Score still work.

## 10. Settings Decentralization sanity (2026-05-09 morning)

- [ ] Confiança tab top: **Trust score weights** DisclosureGroup (collapsed by default).
- [ ] Fila tab below queue list: schedule + watched-folder cards.
- [ ] Frota tab: household swarm token + privacy/loopback/regenerate-token security card.
- [ ] Agentes tab: Web dashboard QR + iPhone pairing QR.
- [ ] Sidebar: **brand footer** at the bottom — 28pt logo + version + Settings gear.

## 11. Build sanity (every release)

- [ ] `swift build` clean (0 errors, 0 warnings on fresh DerivedData).
- [ ] `swift run splynek-test` → all 820+ tests pass.
- [ ] `xcodebuild -scheme SplynekCompanion CODE_SIGNING_ALLOWED=NO build` → BUILD SUCCEEDED.
- [ ] `xcodebuild -scheme SplynekWatch CODE_SIGNING_ALLOWED=NO build` → BUILD SUCCEEDED (requires watchOS SDK).
- [ ] `python3 Scripts/find-missing-translations.py` → ≤ 40 missing (down from 79 pre-Sprint-4 + pre-Sprint-5 round 2).
- [ ] `python3 Scripts/regenerate-localizations.py` → all 5 locales report 100% on every catalog string.

## Sign-off

- [ ] All boxes checked.
- [ ] Outstanding maintainer steps documented in `HANDOFF.md` (CloudKit Dashboard schema, watchOS provisioning, Apple Developer Program watch + complications bundle IDs).
- [ ] Tag `v2.0.0` (or whichever version cuts this rollup).
- [ ] DMG + MAS pkg cut + uploaded.

> **If anything's red:** roll back the offending commit on `rollup/2026-05-08`, fix, re-run the affected section.  Don't tag with a known smoke-test failure.
