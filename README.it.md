# Splynek

> **Versione italiana ridotta.** Per la documentazione completa, consulta [README.md](README.md) (in inglese).

Splynek è un download manager per macOS che combina tutte le connessioni di rete del tuo Mac — Wi-Fi, Ethernet, hotspot dell'iPhone — per scaricare file più velocemente di quanto consenta una singola connessione.

## Cosa rende diverso Splynek

- **Più veloce** — somma la banda di tutte le reti connesse simultaneamente. Nei test, da 1,8× a 3,5× più veloce di Safari su una sola connessione.
- **Onesto** — ogni download viene verificato contro il checksum dell'editore. Nulla viene salvato su disco prima che l'integrità sia confermata.
- **Privato** — nulla esce dal tuo Mac. Nessun account. Nessuna telemetria. Nessun log.
- **Sovrano** — scopri da dove vengono le app sul tuo Mac e quali hanno alternative europee o open source.

## Le schede principali

| Scheda | Cosa fa |
|--------|---------|
| **Download** | URL, checksum opzionale, scegli le reti da usare, scarica. |
| **Torrent** | Supporto nativo BitTorrent v1+v2 (DHT, PEX, magnet, multifile). |
| **Live** | Visualizza in tempo reale la banda per rete durante il download. |
| **Sovranità** | Scansiona le app installate e suggerisce alternative europee / open source. Locale; nulla lascia il dispositivo. |
| **Affidabilità** | Verifica dei registri pubblici delle tue app — etichette privacy dell'App Store, multe regolatorie, CVE, fughe HIBP. Senza editoriali. Ogni affermazione cita la fonte. |
| **Agenti** | Server MCP — consente a Claude, ChatGPT o altri agenti IA di pilotare Splynek. Disattivato per impostazione predefinita. |
| **Coda** | Coda persistente di URL da scaricare in seguito. |
| **Flotta** | Coordinamento tra più Mac sulla stessa rete locale. |
| **Cronologia** | Tutto ciò che hai scaricato. Cercabile, indicizzato in Spotlight. |

## Come installare

**Mac App Store** (in revisione per la v1.0): https://apps.apple.com/app/splynek

**DMG diretto** (gratuito, firmato Developer ID, notarizzato):
- [GitHub Releases](https://github.com/Splynek/splynek/releases) — scarica il `.dmg` più recente

**Homebrew**:
```bash
brew tap Splynek/splynek
brew install --cask splynek
```

## Privacy — il contratto

- Splynek **non invia mai** dati ai nostri server. Non abbiamo server.
- Splynek **non apre mai** il contenuto delle tue app. Le analisi Sovranità e Affidabilità leggono solo l'elenco dei bundle installati — la stessa cosa che fa Spotlight.
- Splynek **non carica mai** la tua cronologia o l'elenco delle app sul cloud.
- Il server web locale (usato da Splynek per mostrare il progresso o integrarsi con le estensioni del browser) ascolta solo su `127.0.0.1` per impostazione predefinita.

## Lingue supportate

Splynek è disponibile in **inglese**, **portoghese (Portogallo)**, **spagnolo**, **francese**, **tedesco** e **italiano**. Vedi [LOCALIZATION.md](LOCALIZATION.md) per il flusso di contribuzione (PR con traduzioni benvenute).

## Contribuire

- Il catalogo Sovranità (1.100+ app, alternative europee / OSS) è mantenuto in [`Scripts/sovereignty-catalog.json`](Scripts/sovereignty-catalog.json) — vedi [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md).
- Il catalogo Affidabilità (60 app, con fonti primarie) è in [`Scripts/trust-catalog.json`](Scripts/trust-catalog.json).
- Bug, suggerimenti: [github.com/Splynek/splynek/issues](https://github.com/Splynek/splynek/issues).

## Licenza

[BSD 3-Clause](LICENSE).
