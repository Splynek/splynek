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
