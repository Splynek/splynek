# Splynek

> **Deutsche Kurzfassung.** Die vollständige Dokumentation finden Sie in [README.md](README.md) (auf Englisch).

Splynek ist ein Download-Manager für macOS, der alle Netzwerkverbindungen Ihres Mac bündelt — WLAN, Ethernet, iPhone-Tethering — um Dateien schneller herunterzuladen, als es eine einzelne Verbindung erlauben würde.

## Was Splynek anders macht

- **Schneller** — bündelt die Bandbreite aller gleichzeitig verbundenen Netzwerke. In Tests 1,8× bis 3,5× schneller als Safari auf einer einzelnen Verbindung.
- **Ehrlich** — jeder Download wird gegen die Prüfsumme des Herausgebers verifiziert. Nichts wird auf der Festplatte gespeichert, bevor die Integrität bestätigt ist.
- **Privat** — nichts verlässt Ihren Mac. Kein Konto. Keine Telemetrie. Keine Protokolle.
- **Souverän** — sehen Sie, woher die Apps auf Ihrem Mac stammen und welche europäische oder Open-Source-Alternativen haben.

## Die Hauptregisterkarten

| Tab | Funktion |
|-----|----------|
| **Downloads** | URL, optionale Prüfsumme, wählen Sie die zu verwendenden Netzwerke, laden Sie herunter. |
| **Torrents** | Native BitTorrent v1+v2-Unterstützung (DHT, PEX, Magnet, Multi-Datei). |
| **Live** | Sehen Sie die Bandbreite pro Netzwerk in Echtzeit während eines Downloads. |
| **Souveränität** | Scannen Sie installierte Apps und schlagen Sie europäische / Open-Source-Alternativen vor. Lokal; nichts verlässt das Gerät. |
| **Vertrauen** | Audit Ihrer Apps anhand öffentlicher Aufzeichnungen — App Store Datenschutzlabels, Bußgelder, CVEs, HIBP-Datenlecks. Keine redaktionellen Wertungen. Jede Behauptung zitiert die Quelle. |
| **Agenten** | MCP-Server — lässt Claude, ChatGPT oder andere KI-Agenten Splynek steuern. Standardmäßig deaktiviert. |
| **Warteschlange** | Persistente URL-Warteschlange zum späteren Herunterladen. |
| **Flotte** | Koordination zwischen mehreren Macs im selben lokalen Netzwerk. |
| **Verlauf** | Alles, was Sie heruntergeladen haben. Durchsuchbar, in Spotlight indiziert. |

## Installation

**Mac App Store** (in Prüfung für v1.0): https://apps.apple.com/app/splynek

**DMG direkt** (kostenlos, Developer-ID-signiert, notarisiert):
- [GitHub Releases](https://github.com/Splynek/splynek/releases) — das neueste `.dmg` herunterladen

**Homebrew**:
```bash
brew tap Splynek/splynek
brew install --cask splynek
```

## Datenschutz — der Vertrag

- Splynek sendet **niemals** Daten an unsere Server. Wir haben keine Server.
- Splynek öffnet **niemals** den Inhalt Ihrer Apps. Souveränitäts- und Vertrauensprüfungen lesen nur die Liste installierter Bundles — dasselbe, was Spotlight tut.
- Splynek lädt Ihren Verlauf oder App-Liste **niemals** in die Cloud hoch.
- Der lokale Webserver (den Splynek für Fortschrittsanzeigen oder Browser-Erweiterungs-Integration verwendet) hört standardmäßig nur auf `127.0.0.1`.

## Unterstützte Sprachen

Splynek ist auf **Englisch**, **Portugiesisch (Portugal)**, **Spanisch**, **Französisch**, **Deutsch** und **Italienisch** verfügbar. Siehe [LOCALIZATION.md](LOCALIZATION.md) für den Beitragsworkflow (PRs mit Übersetzungen willkommen).

## Mitwirken

- Der Souveränitäts-Katalog (1.100+ Apps, europäische / OSS-Alternativen) wird in [`Scripts/sovereignty-catalog.json`](Scripts/sovereignty-catalog.json) gepflegt — siehe [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md).
- Der Vertrauens-Katalog (60 Apps, mit Primärquellen) liegt in [`Scripts/trust-catalog.json`](Scripts/trust-catalog.json).
- Bugs, Vorschläge: [github.com/Splynek/splynek/issues](https://github.com/Splynek/splynek/issues).

## Lizenz

[BSD 3-Clause](LICENSE).
