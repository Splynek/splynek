#!/usr/bin/env python3
"""
Patch iOS Companion's Localizable.xcstrings with v2.0.1 L10n round 5.

The Xcode auto-extractor populated the catalog with English-only
entries during the PRO-PLUS-IPHONE Sprint 8 smoke build.  This
script adds the de/es/fr/it/pt-PT translations idempotently,
preserving every existing entry untouched.

Usage:
    python3 Scripts/translate-ios-catalog.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).parent.parent
CAT_PATH = ROOT / "iOS" / "SplynekCompanion" / "Localizable.xcstrings"

# Translations for the 23 strings the audit found missing.
# Each maps source-string → {locale → translation}.
TRANSLATIONS = {
    " / 100": {
        "pt-PT": " / 100",
        "es": " / 100",
        "fr": " / 100",
        "de": " / 100",
        "it": " / 100",
    },
    " / 100 avg": {
        "pt-PT": " / 100 média",
        "es": " / 100 promedio",
        "fr": " / 100 moyenne",
        "de": " / 100 Durchschnitt",
        "it": " / 100 media",
    },
    " total · %@": {
        "pt-PT": " no total · %@",
        "es": " total · %@",
        "fr": " au total · %@",
        "de": " insgesamt · %@",
        "it": " totale · %@",
    },
    "·": {
        "pt-PT": "·",
        "es": "·",
        "fr": "·",
        "de": "·",
        "it": "·",
    },
    "%@": {
        "pt-PT": "%@",
        "es": "%@",
        "fr": "%@",
        "de": "%@",
        "it": "%@",
    },
    "%@ · %@": {
        "pt-PT": "%1$@ · %2$@",
        "es": "%1$@ · %2$@",
        "fr": "%1$@ · %2$@",
        "de": "%1$@ · %2$@",
        "it": "%1$@ · %2$@",
    },
    "%@ m": {
        "pt-PT": "%@ m",
        "es": "%@ m",
        "fr": "%@ m",
        "de": "%@ m",
        "it": "%@ m",
    },
    "%@ of %@ apps in the high-risk band.": {
        "pt-PT": "%1$@ de %2$@ apps na faixa de alto risco.",
        "es": "%1$@ de %2$@ apps en la franja de alto riesgo.",
        "fr": "%1$@ sur %2$@ applications dans la tranche à haut risque.",
        "de": "%1$@ von %2$@ Apps im Hochrisikobereich.",
        "it": "%1$@ di %2$@ app nella fascia ad alto rischio.",
    },
    "%@ of %@ installed apps have an EU/OSS alternative listed.": {
        "pt-PT": "%1$@ de %2$@ apps instaladas têm uma alternativa EU/OSS listada.",
        "es": "%1$@ de %2$@ apps instaladas tienen una alternativa EU/OSS listada.",
        "fr": "%1$@ sur %2$@ applications installées disposent d'une alternative UE/OSS répertoriée.",
        "de": "%1$@ von %2$@ installierten Apps haben eine EU/OSS-Alternative gelistet.",
        "it": "%1$@ di %2$@ app installate hanno un'alternativa EU/OSS elencata.",
    },
    "→ %@": {
        "pt-PT": "→ %@",
        "es": "→ %@",
        "fr": "→ %@",
        "de": "→ %@",
        "it": "→ %@",
    },
    "Boundary radius": {
        "pt-PT": "Raio do limite",
        "es": "Radio del límite",
        "fr": "Rayon de la limite",
        "de": "Begrenzungsradius",
        "it": "Raggio del confine",
    },
    "Geo-fence": {
        "pt-PT": "Geo-fence",
        "es": "Geo-cerca",
        "fr": "Géofence",
        "de": "Geofence",
        "it": "Geo-recinto",
    },
    "Home location": {
        "pt-PT": "Localização de casa",
        "es": "Ubicación de casa",
        "fr": "Localisation de la maison",
        "de": "Standort zuhause",
        "it": "Posizione di casa",
    },
    "Last seen %@": {
        "pt-PT": "Visto pela última vez %@",
        "es": "Visto por última vez %@",
        "fr": "Vu pour la dernière fois %@",
        "de": "Zuletzt gesehen %@",
        "it": "Visto l'ultima volta %@",
    },
    "On the Mac: Settings → API tokens → Mint token (Read + write). Permanent until you revoke it.": {
        "pt-PT": "No Mac: Definições → Tokens de API → Criar token (Leitura + escrita). Permanente até o revogares.",
        "es": "En el Mac: Ajustes → Tokens de API → Crear token (Lectura + escritura). Permanente hasta que lo revoques.",
        "fr": "Sur le Mac : Réglages → Jetons d'API → Créer un jeton (Lecture + écriture). Permanent jusqu'à révocation.",
        "de": "Am Mac: Einstellungen → API-Tokens → Token erstellen (Lesen + schreiben). Bleibt bestehen, bis Sie ihn widerrufen.",
        "it": "Sul Mac: Impostazioni → Token API → Crea token (Lettura + scrittura). Permanente fino a quando non lo revochi.",
    },
    "On the Mac: Settings → Web dashboard → copy. Rotates on relaunch + on Regenerate-token clicks; you'd need to re-pair after each.": {
        "pt-PT": "No Mac: Definições → Painel web → copiar. Roda a cada relançamento e a cada clique em Regenerar token; terás de re-emparelhar depois de cada um.",
        "es": "En el Mac: Ajustes → Panel web → copiar. Rota en cada relanzamiento y en cada clic de Regenerar token; tendrás que volver a emparejar después de cada uno.",
        "fr": "Sur le Mac : Réglages → Tableau de bord web → copier. Régénéré à chaque relance et à chaque clic sur Régénérer le jeton ; vous devrez ré-appairer après chaque opération.",
        "de": "Am Mac: Einstellungen → Web-Dashboard → kopieren. Wird bei jedem Neustart und bei jedem Klick auf „Token regenerieren“ rotiert; nach jedem Vorgang muss neu gekoppelt werden.",
        "it": "Sul Mac: Impostazioni → Pannello web → copia. Ruota a ogni rilancio e a ogni clic su Rigenera token; dovrai abbinare di nuovo dopo ognuno.",
    },
    "Or: session token": {
        "pt-PT": "Ou: token de sessão",
        "es": "O: token de sesión",
        "fr": "Ou : jeton de session",
        "de": "Oder: Sitzungs-Token",
        "it": "Oppure: token di sessione",
    },
    "Pair a Mac to see your Splynek insights here.": {
        "pt-PT": "Empareia um Mac para veres aqui os teus insights do Splynek.",
        "es": "Empareja un Mac para ver aquí tus insights de Splynek.",
        "fr": "Appairez un Mac pour voir ici vos insights Splynek.",
        "de": "Koppeln Sie einen Mac, um hier Ihre Splynek-Insights zu sehen.",
        "it": "Abbina un Mac per vedere qui i tuoi insight di Splynek.",
    },
    "Recommended: API token (Pro)": {
        "pt-PT": "Recomendado: token de API (Pro)",
        "es": "Recomendado: token de API (Pro)",
        "fr": "Recommandé : jeton d'API (Pro)",
        "de": "Empfohlen: API-Token (Pro)",
        "it": "Consigliato: token API (Pro)",
    },
    "Splynek Pro feature.": {
        "pt-PT": "Funcionalidade do Splynek Pro.",
        "es": "Función de Splynek Pro.",
        "fr": "Fonctionnalité Splynek Pro.",
        "de": "Splynek Pro-Funktion.",
        "it": "Funzionalità Splynek Pro.",
    },
    "Tap to pair · v%@": {
        "pt-PT": "Toca para emparelhar · v%@",
        "es": "Toca para emparejar · v%@",
        "fr": "Touchez pour appairer · v%@",
        "de": "Zum Koppeln tippen · v%@",
        "it": "Tocca per abbinare · v%@",
    },
    "Trust Watcher monitors Privacy Policies + Terms of Service for changes. Ask the Mac owner to upgrade in About → Splynek Pro.": {
        "pt-PT": "O Vigia de Confiança monitoriza alterações em Políticas de Privacidade e Termos de Serviço. Pede ao dono do Mac para fazer upgrade em Sobre → Splynek Pro.",
        "es": "El Vigía de confianza monitoriza cambios en Políticas de Privacidad y Términos de Servicio. Pide al propietario del Mac que haga el upgrade en Acerca de → Splynek Pro.",
        "fr": "La Sentinelle de confiance surveille les modifications des politiques de confidentialité et des CGU. Demandez au propriétaire du Mac de mettre à niveau dans À propos → Splynek Pro.",
        "de": "Der Vertrauenswächter überwacht Änderungen an Datenschutzerklärungen und AGB. Bitten Sie den Mac-Besitzer, in Info → Splynek Pro auf Pro zu aktualisieren.",
        "it": "La Sentinella di fiducia monitora le modifiche a Informative sulla privacy e Termini di servizio. Chiedi al proprietario del Mac di aggiornare in Informazioni → Splynek Pro.",
    },
    "Watching %@ apps · %@": {
        "pt-PT": "A vigiar %1$@ apps · %2$@",
        "es": "Vigilando %1$@ apps · %2$@",
        "fr": "Surveille %1$@ applications · %2$@",
        "de": "Überwacht %1$@ Apps · %2$@",
        "it": "Monitoraggio %1$@ app · %2$@",
    },
}


def main():
    cat = json.loads(CAT_PATH.read_text())
    strings = cat.setdefault("strings", {})

    added = 0
    skipped = 0
    for key, locales in TRANSLATIONS.items():
        if key not in strings:
            print(f"  ⚠  key not in catalog: {key!r}")
            continue
        entry = strings[key]
        loc_block = entry.setdefault("localizations", {})
        for locale, value in locales.items():
            if locale in loc_block:
                skipped += 1
                continue
            loc_block[locale] = {
                "stringUnit": {"state": "translated", "value": value}
            }
            added += 1

    # Sort strings alphabetically for deterministic diffs.
    cat["strings"] = dict(sorted(strings.items()))
    CAT_PATH.write_text(json.dumps(cat, indent=2, ensure_ascii=False))

    n_strings = len(cat["strings"])
    print(f"✓ Catalog has {n_strings} strings")
    print(f"  Added {added} translations across {len(TRANSLATIONS)} keys")
    print(f"  Skipped {skipped} (already translated)")


if __name__ == "__main__":
    main()
