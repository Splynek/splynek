# Splynek strategy memo — 2026-05-09

## Pro tier reinvention + iPhone Companion → must

> **Status:** thinking, then EXECUTING.  Sprint 1 commits begin
> 2026-05-09 evening (this commit set).  This document is the
> source-of-truth for the strategic framing; concrete progress
> tracked in `SESSION-LOG.md` per-commit narrative.

---

## 1. Diagnóstico honesto do Pro actual

Pro hoje vende:

| Surface | Pro gate |
|---|---|
| Concierge tab | `isPro` |
| Recipes tab | `isPro` |
| Mobile web dashboard + iPhone QR | `isPro` |
| Scheduled downloads | `isPro` |
| AI search (Download / History / Sovereignty views) | `aiAvailable && isPro` |
| Fleet > 2 dispositivos | `proGateForcesLoopback` |

**Conclusão dura:** Pro hoje é "remove fricções de coisas que já podias fazer".  Não muda *o que* o utilizador pode fazer com Splynek; só *como bem* o faz.  **Nenhum Pro feature actual é razão para alguém comprar Splynek**; são razões para upgradar **depois** de já o estar a usar muito.

**Risco competitivo não-óbvio:** o eixo "Concierge / IA local" colapsa quando macOS 26 ship Apple Intelligence integrado com Spotlight downloads.  Estamos a vender o que o sistema operativo está a pôr a caminho de oferecer de borla.

---

## 2. Diagnóstico do iPhone Companion

O Companion hoje faz três coisas: **submeter URLs, ver progress, pairing**.  Útil.  Não é must.

**O que torna uma app de iPhone um "must":**

1. **Notificações que o utilizador realmente quer** — "acabou o download de 8GB"; "Adobe alterou os ToS"; "Spotify foi vendida"
2. **Acesso passivo na lock-screen / Always-On / Dynamic Island** sem abrir a app
3. **Voz / Shortcuts / atalhos** — "Hey Siri, envia para o Splynek"
4. **Acções que só fazem sentido no telemóvel** — geo-fence, camera, OCR
5. **Library na palma da mão** — pesquisa do que descarreguei

O Companion actual cumpre **zero** destes cinco.

---

## 3. Cinco apostas estratégicas para o Pro

### Aposta A — **"Splynek Pro = centro de operações de soberania digital da casa"**

A única aposta em que Splynek é genuinamente único e defensável.

- **Trust Watcher** — daily diff de hashes ToS + Privacy Policy do catálogo público; alerta local quando muda algo.  100% local com catálogo versionado em git, mesmo padrão que Sovereignty.
- **Acquisition radar** — catálogo curado de aquisições com delta de risco
- **Sovereignty Migrate Wizard** — one-click "queres mesmo trocar Spotify→Tidal?"
- **Annual Sovereignty Report** — PDF/PNG partilhável

**Defensibilidade:** alta.  Apple não vai entrar nesta arena.  Concorrentes precisam montar o catálogo de raiz.

### Aposta B — **"Splynek Pro = agente que age, não só responde"**

- Recipes 2.0 com sync via CloudKit
- Triggered automations (eventos → audit → alerta)
- Concierge sequences com confirmação humana
- MCP avançado (writes destravados + quotas para clients agentic externos)

**Defensibilidade:** média-alta.

### Aposta C — **"Splynek Pro = rede cooperativa da casa/edifício"**

- Bandwidth + quota dashboards
- Timeline da casa: "quem baixou o quê quando"
- Mirror cooperativo opt-in

**Defensibilidade:** média.  Atrai um nicho.

### Aposta D — **"Splynek Pro = phone-first"**

A maior parte das funcionalidades Pro hoje **não estão acessíveis no iPhone**.  Buraco gigante.

- **Pro on iPhone** — Sovereignty/Trust scores do Mac, viewable via relay.  History search no telemóvel.  Multi-Mac fleet console.
- **iPhone como controlo remoto da frota** — `pause all`, `resume all`, mudar pasta de output

**Defensibilidade:** alta combinada com aposta A ou B.

### Aposta E — **"Splynek Pro = developer power-up"**

- API tokens persistentes (Raycast, Alfred, BetterTouchTool)
- Xcode prefetch
- GitHub releases watcher

**Defensibilidade:** baixa-média.  Mercado nicho mas alta-LTV.

---

## 4. iPhone Companion → must, lista accionável

### Tier 1 — quick wins, alto impacto (próximos 3 meses)

| Feature | Por que é must | Custo eng |
|---|---|---|
| **Push notifications via CloudKit subscriptions** | "Acabou o download" / "Trust changed" — razão para abrir a app | 2-3 dias |
| **Widget compacto + médio** | Presença na home screen sem abrir a app | 3-4 dias |
| **App Intents iOS** (Hey Siri) | Voz é multiplicador massivo de utilidade | 1 semana |
| **Library no telemóvel** (espelha history do Mac via relay) | Pesquisa em qualquer lado | 1 semana |
| **Quick action: Pause/Resume all** com Face ID | Pausar tudo num toque é caso de uso real | 1-2 dias |

### Tier 2 — diferenciadores genuínos (próximos 6 meses)

| Feature | Por que é must | Custo eng |
|---|---|---|
| **Geo-fence** ("leaving home"→pause, "arriving home"→resume) | Apenas o phone tem location | 1 semana |
| **Apple Watch app** (tap-to-pause + complication + notification) | Watch é o segundo nível de must | 2 semanas |
| **Camera: OCR de license keys + scan QR de qualquer ecrã** | Phone-only sinergia | 1 semana |
| **Sovereignty/Trust dos apps do iPhone** | "O meu Mac está limpo. E o meu telemóvel?" | 2-3 semanas |

### Tier 3 — moonshots (próximos 12 meses)

- iCloud Drive watcher
- Lock Screen Shortcut widget
- Companion broadcasting (Bonjour, peer-to-peer entre Splyneks de diferentes casas)

---

## 5. Plano executável — 3 sprints

### Sprint 1 (pós-v2.0, **EM EXECUÇÃO 2026-05-09**)

**Foco: tornar Pro defensável e iPhone notificável.**

- [ ] **Strategy doc** (este ficheiro) — preserva o pensamento
- [ ] **Trust Watcher** (Aposta A) — catálogo de ToS hashes versionado em git, daily diff, alert local + UI Mac
- [ ] **CloudKit push notifications** (iPhone) — Mac escreve alert records, iOS subscreve; reusa infra do relay
- [ ] **iOS App Intents** — SubmitURLIntent, PauseAllIntent, ResumeAllIntent, GetSovereigntyScoreIntent
- [ ] **iOS Widget** — small + medium widget para fleet stats / Sovereignty score
- [ ] **Pro on iPhone** — endpoints relay + iOS views para Sovereignty / Trust / History do Mac
- [ ] **MONETIZATION.md** — repositioning per esta estratégia

### Sprint 2 (3-6 meses)

**Foco: fechar o ciclo Concierge-actua + Watch.**

- [ ] Concierge sequences com confirmação humana
- [ ] Sovereignty Migrate Wizard (one-click swap com cask)
- [ ] Apple Watch app
- [ ] Geo-fence pause/resume

### Sprint 3 (6-12 meses)

**Foco: pricing model evolution.**

- [ ] Avaliar telemetria Trust Watcher → decidir spinning Trust+ subscrição $9/yr
- [ ] Splynek Teams revisitado **só se** Pro tier > 300 unidades vendidas

---

## 6. Princípios de pricing & posicionamento

1. **$29 one-time fica.**  É a âncora.  Não cobramos mensalidade por algo que não exige infra recorrente.
2. **Family Sharing on MAS é gratuito-de-fábrica** — anunciar isto explicitamente na landing como "buy once, your whole household has Pro".
3. **iPhone Companion fica gratuito** *por design* — é o demo viral.  Mas funcionalidades Pro só funcionam se houver **um** Pro Mac na casa.  Cria mecânica de conversão familiar.
4. **MCP fica "read-only" no free, "writes + quotas" no Pro.**  Targeting o utilizador que paga $20/mês a Claude.
5. **Sovereignty Catalog refreshes** ficam grátis para sempre — é o nosso valor identitário, não o nosso revenue stream.
6. **Trust Watcher catalog refreshes** ficam grátis no Pro original; subscrição opt-in **só se** futura telemetria justificar.

---

## 7. Critérios de sucesso (medir em 90 dias após v2.0)

| Métrica | Meta |
|---|---|
| Conversão free → Pro | **≥ 3%** (vs 2% projectado em MONETIZATION.md original) |
| iPhone Companion installs / Pro purchase | **≥ 1.5×** (Companion grátis empurra Pro) |
| Trust Watcher daily-engagement rate | **≥ 40%** (justifica a aposta A como marquee) |
| App Store reviews mencionando "Sovereignty" ou "Trust" | **≥ 20%** das 5★ |
| Apple Intelligence threat (Concierge sherlock-able) | **mitigado** se Pro perception shifted to Trust+Sovereignty |

---

## 8. O que muda face ao MONETIZATION.md original

- Sub Concierge como marquee feature → promove Trust Watcher como marquee
- Adiciona Aposta D (Pro on iPhone) como vector explícito de valor para Pro existente
- Repositiona iPhone Companion de "submetedor URL" para "presença passiva permanente"
- Adia Teams indefinidamente; Pro Family Sharing no MAS preenche 80% do caso

---

## Histórico

- **2026-05-09 (este commit)** — doc criada após sessão de design
  decentralization (`57fb6cb` → `00f6c80`).  User pediu para
  "alavancar Pro" e "tornar iPhone Companion um must"; este memo
  é a resposta.  Sprint 1 execução começa imediatamente.

- **2026-05-09 evening** — Sprint 1 SHIPPED (4 commits `5e30f5c` →
  `fabf46e` + docs `7a93885`).  Trust Watcher (Mac complete with
  UI, 22 tests, ProLockedView teaser, Pro-gated activation), Mac
  REST relay endpoints (6 new endpoints + Codable summary types),
  iOS App Intents (5 intents wired for Hey Siri), iOS Widget
  (small + medium home-screen with Sovereignty score hero), Pro
  on iPhone (Insights tab), CloudKit push notifications (Trust
  Watcher alert → user's private DB → iPhone subscriber → local
  UNNotification).  767 tests green; iOS xcodebuild SUCCEEDED.

- **2026-05-09 evening** — Sprint 2 scaffolds opened.  Pure data
  models + invariant-enforcing policy modules + tests for three of
  four Sprint 2 items: Sovereignty Migrate Wizard, Concierge
  Sequences with confirmation, Geo-fence pause/resume.  786 tests
  green.  **Watch app deferred** to Sprint 2 part 2 — adding a
  watchOS target to project.yml requires a separate build pipeline
  + Apple Developer Program watchOS provisioning + ActivityKit
  glanceable variant; cleaner to ship in a focused commit when the
  prerequisites are confirmed.

  ### Sprint 2 part-1 scaffolds (this commit)

  | File                                                     | Purpose                              |
  |----------------------------------------------------------|--------------------------------------|
  | `Sources/SplynekCore/Migrate/SovereigntyMigratePlan.swift` | Migrate plan data model + planner    |
  | `Sources/SplynekCore/ConciergeSequence.swift`              | Sequence type + policy invariants    |
  | `iOS/Shared/GeoFencePolicy.swift`                          | iOS geo-fence decision logic         |
  | `Tests/SplynekTests/SovereigntyMigratePlanTests.swift`     | 6 tests                              |
  | `Tests/SplynekTests/ConciergeSequenceTests.swift`          | 7 tests                              |
  | `Tests/SplynekTests/GeoFencePolicyTests.swift`             | 5 tests                              |

  ### Sprint 2 part-2 — SHIPPED 2026-05-10 (4 commits)

  All four items closed:
  - **Sovereignty Migrate Wizard** end-to-end (`641dc70`) —
    runner (NSWorkspace + AppleScript Terminal + review-list)
    + SwiftUI sheet with per-step confirmation alerts +
    persisted review list (`migrate-review-list.json`).
    Pro-gated entry from every alternative row in Sovereignty.
  - **Geo-fence iOS** end-to-end (`f658e2f`) — CLLocationManager
    wrapper + Settings UI (enable toggle + "Use current
    location as home" + radius slider).  Coordinates never
    leave device; only "you crossed the boundary" boolean
    triggers PairedMacClient.pauseAll/resumeAll.
  - **Watch app target skeleton** (`aec950d`) — project.yml
    target + scheme + minimal SwiftUI body with action buttons
    + Sovereignty score row + haptics.  watchOS SDK install
    required for compile-verify (maintainer step).
  - **Concierge sequence runner + preview UI** (`9e1db78`) —
    actor wrapping MCPServer.Bridge + SwiftUI sheet with
    CheckedContinuation alert/confirm pattern.

  Sprint 2 numbers: 5 total commits (1 part-1 scaffolds +
  4 part-2 implementations); +30 tests across part-1 + part-2
  (786 → 797 → 797 — runner counts in the latter).

  ### Sprint 3 — SHIPPED 2026-05-10 evening (4 commits)

  Items 3-6 of the original Sprint 3 backlog all closed:
  - **Watch complication** (`85d6e4f`) — three accessory
    families backed by the same paired-Mac summary endpoints
    the iOS Widget uses.  New SplynekWatchComplications target.
  - **Sovereignty review banner** (`85d6e4f`) — DisclosureGroup
    surfacing Migrate-marked apps >7 days old.
  - **Migrate review digest in Concierge** (`529ea18`) — 9th
    tool in ConciergeToolRegistry; handler returns `.text` card
    with count + names + stale-week nudge.
  - **Pricing telemetry foundation** (`ec1e9d9`) — pure-local
    engagement counters, 9 per-surface ints, `EngagementGate
    .shouldOfferTrustPlus` pure decision function.  Privacy
    posture explicitly stated: nothing leaves the device.

  Sprint 3 numbers: 4 commits + docs; 797 → 808 tests (+11);
  ~1,000 lines new code.

  Items 1-2 of the original Sprint 3 backlog are deferred to
  Sprint 4: end-to-end smoke test (manual) and splynek-pro
  ConciergeView wiring (private repo, requires LLM dispatch).

  ### Sprint 4 — SHIPPED 2026-05-10 night (4 commits)

  Items 2-3 of the original Sprint 4 backlog closed; new items
  added:
  - **Engagement viewer** (`7f02266`) — privacy through
    transparency.  User reads the same JSON the future Trust+
    gate reads.
  - **Trust+ upsell card** (`7f02266`) — appears only when
    `EngagementGate.shouldOfferTrustPlus` fires.  Honest
    pitch with mailto: registration of interest, no server.
  - **L10n catalog +28 strings × 5 locales** (`96b03f1`) —
    closes 24/79 of the audit gap.
  - **API tokens for external scripting** (`088d8d1`) —
    Aposta E developer power-up.  Persistent named tokens
    with two scopes; Settings UI to mint/list/revoke.

  Sprint 4 numbers: 4 commits + docs; 808 → 820 tests (+12);
  ~1,400 lines new code + 140 new translations.

  Items 1, 4, 5 of the original backlog deferred:
  - Item 1 (smoke test) — manual; deferred to Sprint 5.
  - Item 4 (splynek-pro Concierge) — private repo; deferred
    until pro-side capacity.
  - Item 5 (Apple Developer provisioning) — maintainer step;
    out of band.

  ### Sprint 5 — SHIPPED 2026-05-10 late night (5 commits)

  Items 2-4 of original backlog closed; item 1 (smoke test)
  delivered as a runbook (manual walk-through stays maintainer-
  side, but the checklist is now committed):
  - **Raycast extension scaffold** (`79fe846`) — first concrete
    external API-token client.  5 commands.
  - **iPhone Companion pairing-flow copy** (`eead2aa`) — Token
    section ranks API token (Pro) above session token; Mac
    validation always accepted both since Sprint 4.
  - **L10n round 2** (`552430c`) — +26 strings × 5 locales
    (770 → 796).  Interpolated `%@` forms now first-class.
  - **SMOKE-TEST-RUNBOOK** (`6580ec0`) — 11-section pre-tag
    checklist.

  Sprint 5 numbers: 5 commits + docs; 820 → 820 tests
  (UI + scaffolding only); +130 new translations.

  ### Sprint 6 — SHIPPED 2026-05-10 deep night (4 commits)

  Items 2 + 4 + 5 of original backlog closed; items 1 + 3
  deferred to Sprint 7 (1 = manual smoke; 3 = Alfred needs
  installed Powerpack to test against):
  - **CLI cookbook** (`5760117`) — `Extensions/CLI/` with
    bash wrapper + cookbook README.  Second external
    API-token client.
  - **L10n round 3** (`a5e1139`) — +16 strings × 5 locales
    (796 → 812).  Audit gap 40 → 25.
  - **LANDING-V2-DRAFT** (`27ce72e`) — announcement copy
    pivoting marquee from Concierge → Trust Watcher.
    Show HN draft + press kit + gating checklist.

  Sprint 6 numbers: 4 commits + docs; 820 → 820 tests
  (UI/docs/L10n only); +80 new translations; ~330 lines bash.

  ### Sprint 7 — SHIPPED 2026-05-10 deep-deep night (4 commits)

  Items 1-3 of original backlog closed; items 4-5 deferred to
  Sprint 8 (manual smoke + tag + announce):
  - **SMOKE-TEST partial sign-off** (`836354c`) — programmatic
    green; manual items explicitly UNCHECKED for the maintainer.
  - **L10n round 4 — audit gap reaches ZERO** (`b16a6fd`) —
    +29 strings × 5 locales (812 → 841).  Audit reports **0
    missing** for the first time in the arc.
  - **Alfred workflow scaffold** (`90074a5`) — third external
    API-token client.  5 keyword commands.

  Sprint 7 numbers: 4 commits + docs; 820 → 820 tests
  (L10n + docs + bash only); +145 new translations.

  ### Sprint 8 — LIVE-VALIDATED 2026-05-10 evening (4 commits)

  Item 4 of Sprint 8's original backlog (manual smoke on real
  hardware) executed.  Items 1-3 (tag, announce, landing
  adaptation) deferred to Sprint 9 — value of having walked the
  surface live first is that we caught 3 in-flight bugs that
  would have entered the v2.0.0 release otherwise:
  - **CloudKit gates** (`276d6ec`) — `CKContainer.__allocating_init`
    trap on Pro-DMG (no iCloud entitlement) fixed via compile-time
    `#if !MAS_BUILD` gate.
  - **Runbook port + endpoint corrections** (`9e25cd6`) —
    `<PORT>` placeholder + `/api/sovereignty/summary` instead of
    the unauth `/api/jobs`.
  - **iOS Companion catalog auto-extract** (`bc5af7c`) — +37
    English-only entries flagged for L10n round 5.

  Live verification highlights (per `SMOKE-TEST-SIGNOFF-2026-05-10.md`):
  - Trust Watcher detected 9 real policy hash diffs — all
    correctly classified as "Minor change" (severity heuristic
    distinguishes noise from signal as designed).
  - iPhone Insights tab (Sprint 1) rendered live data from
    Mac via API token; Sovereignty 84/100, Trust 75/100 avg.
  - Mac-side `iphoneSummaryServes` engagement counter
    0 → 6 confirmed end-to-end.
  - watchOS SDK install unblocked; both Watch + Watch
    Complications targets compile cleanly.

  Sprint 8 numbers: 4 commits + docs; 820 → 820 tests
  (live walk + bug fixes; no test deltas).

  ### Sprint 9 (next session, if executed)

  Decision point: tag v2.0.0 NOW given the live-validated
  surface, or do one more polish round first?

  **Path A — tag v2.0.0 now**:
  1. Tag from `rollup/2026-05-08` + cut DMG + Homebrew Cask
     refresh + MAS resubmit
  2. Show HN + Product Hunt + Mac-app blogger emails
  3. Adapt LANDING-V2-DRAFT.md into splynek-landing
  4. Treat the Sprint 9 polish items as v2.0.1 follow-up

  **Path B — one more polish round, tag v2.0.0 after**:
  1. L10n round 5 — iPhone Companion catalog
     (de/es/fr/it/pt-PT for the +37 auto-extracted strings)
  2. Update Bonjour TXT-record version string (currently
     hardcoded "v0.19" — caught in iPhone discovery)
  3. Test Concierge / Recipes Pro UI via MAS build
     (requires Apple Developer Program + signing)
  4. Physical-iPhone test (push notifications, geo-fence
     walking) once schema is in CloudKit Dashboard
  5. THEN tag v2.0.0

  Path A is faster + lets users see the marquee features
  sooner; v2.0.1 polish lands within 2 weeks.  Path B
  delays launch by 1-2 weeks but ships a more complete
  initial cut.  Recommendation lean on **Path A** —
  Sprint 8's live validation already caught the
  catastrophic bugs (CloudKit init crash); the Path-B
  items are polish, not blockers.

  Or alternative directions if Apple v2.0 review takes weeks:
  - Trust+ subscription UI (consume the engagement gate —
    already shipped in Sprint 4) — pricing decision after
    the first 90 days of telemetry.
  - More sophisticated Trust Watcher catalog growth (current
    seed is 12 apps × 2 URLs = 24 watched; grow to ~100
    via cron-based PR-driven contributions).
  - splynek-pro: ConciergeView wiring that emits a
    `ConciergeSequence` from a user prompt.

  ### PRO-PLUS-IPHONE arc — public-repo state at end of
  Sprint 7 (publish-ready AND translation-complete)

  35 commits total across Sprints 1-7; ~12,000 lines new code;
  **~500 new translations** (catalog 740 → 841 strings × 5
  locales = 4,205 translations; **audit gap = 0**).  820 tests
  green.  Branch `rollup/2026-05-08` ~182 commits ahead of
  `origin/main`.

  Three external API-token clients exist:
  - Raycast extension (Sprint 5, GUI workflow tool)
  - CLI bash wrapper (Sprint 6, headless / scriptable)
  - Alfred workflow scaffold (Sprint 7, Powerpack community)
  Plus the iPhone Companion (Sprint 5 messaging update —
  uses same API tokens for stable pairing).

  Remaining work is split into three pots:
  - **Maintainer-only out-of-band**: CloudKit Dashboard
    schema (`SplynekTrustWatchAlert`), watchOS SDK install,
    Apple Developer Program watch + complications + iOS
    bundle-ID provisioning, Stripe/Paddle direct-DMG
    account, Mac App Store v2.0 review + clearance.
  - **`splynek-pro` repo**: ConciergeView wiring that emits
    a `ConciergeSequence` from a user prompt (LLM call
    lives in Pro repo).
  - **Manual smoke + tag + announce**: walk
    `SMOKE-TEST-RUNBOOK.md` on real hardware, sign off,
    tag v2.0.0, cut DMG + MAS pkg, adapt
    `LANDING-V2-DRAFT.md` into splynek-landing, post Show HN.

  ### PRO-PLUS-IPHONE arc — public-repo state at end of
  Sprint 6 (publish-ready)

  31 commits total across Sprints 1-6; ~11,000 lines new code;
  ~350 new translations; 820 tests green.  Branch
  `rollup/2026-05-08` ~178 commits ahead of `origin/main`.

  Three external API-token clients exist:
  - Raycast extension (Sprint 5, GUI workflow tool)
  - CLI bash wrapper (Sprint 6, headless / scriptable)
  - iPhone Companion (Sprint 5 messaging update — uses
    same API tokens for stable pairing)

  Remaining work is split into three pots:
  - **Maintainer-only out-of-band**: CloudKit Dashboard
    schema (`SplynekTrustWatchAlert`), watchOS SDK install,
    Apple Developer Program watch + complications + iOS
    bundle-ID provisioning, Stripe/Paddle direct-DMG
    account, Mac App Store v2.0 review + clearance.
  - **`splynek-pro` repo**: ConciergeView wiring that emits
    a `ConciergeSequence` from a user prompt (LLM call
    lives in Pro repo).
  - **Manual smoke + tag + announce**: walk
    `SMOKE-TEST-RUNBOOK.md`, sign off, tag v2.0.0, cut
    DMG + MAS pkg, adapt `LANDING-V2-DRAFT.md` into
    splynek-landing, post Show HN.

  ### PRO-PLUS-IPHONE arc — public-repo state at end of
  Sprint 5

  Feature-complete on the public-repo side.  27 commits
  total across Sprints 1-5; ~10,500 lines new code; ~270
  new translations; 820 tests green.  Branch `rollup/
  2026-05-08` ~174 commits ahead of `origin/main`.

  Remaining work is split into three pots:
  - **Maintainer-only out-of-band**: CloudKit Dashboard
    schema (`SplynekTrustWatchAlert`), watchOS SDK install,
    Apple Developer Program watch + complications + iOS
    bundle-ID provisioning, Stripe/Paddle direct-DMG
    account, Mac App Store v2.0 review + clearance.
  - **`splynek-pro` repo**: ConciergeView wiring that emits
    a `ConciergeSequence` from a user prompt (LLM call
    lives in Pro repo).
  - **Manual smoke + tag**: walk `SMOKE-TEST-RUNBOOK.md`,
    sign off, tag v2.0.0, cut DMG + MAS pkg.
