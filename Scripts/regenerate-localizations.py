#!/usr/bin/env python3
"""
v1.6.1: regenerate Sources/SplynekCore/Localizable.xcstrings.

This is the source of truth for Splynek's translations.  The .xcstrings
catalog file gets rebuilt deterministically from the Python data below
so:

  1. The provenance of every translation is auditable in this file
     (vs scattered inline edits to a 459-line JSON catalog).
  2. New strings can be added to one place and propagate to the
     catalog without manual JSON surgery.
  3. Translation status across locales is visible at a glance.
  4. Volunteer translators can submit PRs to this file (which is
     human-readable) instead of the catalog (which is a JSON wire format).

Languages shipped:

  - en     — source (always present)
  - pt-PT  — Portuguese (Portugal), NOT Brazilian Portuguese
  - es     — Spanish
  - fr     — French
  - de     — German
  - it     — Italian

To re-translate:

  1. Edit STRINGS or NEW_V16_STRINGS below.
  2. python3 Scripts/regenerate-localizations.py
  3. swift run splynek-test
  4. Commit Sources/SplynekCore/Localizable.xcstrings + this file.

Translations are AI-generated and reviewed by a single bilingual
maintainer.  Native-speaker review is welcomed via PR — the data
shape makes drive-by improvements low-friction.
"""

import json
from pathlib import Path

ROOT = Path(__file__).parent.parent
CATALOG = ROOT / "Sources" / "SplynekCore" / "Localizable.xcstrings"

# ──────────────────────────────────────────────────────────────────────
# Locales
# ──────────────────────────────────────────────────────────────────────

# Order is for catalog readability only — Apple sorts at runtime by
# user preference.
LOCALES = ["de", "es", "fr", "it", "pt-PT"]


# ──────────────────────────────────────────────────────────────────────
# String → translations.
#
# Format: each English source key maps to a dict with one key per
# target locale.  The English source itself is the dict KEY (matches
# what `Text("...")` renders when the user runs in en).
#
# Style guides, briefly:
#   - pt-PT: European Portuguese.  "ficheiro" not "arquivo",
#     "ecrã" not "tela", "telemóvel" not "celular".  Imperative tense
#     for buttons ("Procurar"), formal you ("Pode adicionar…") for
#     prose.  Apple's macOS Portuguese conventions.
#   - es: Castilian Spanish.  Imperative for buttons.  "Tu" form
#     in prose (modern Apple style).
#   - fr: French.  Apple style.  Use elision before vowels.
#   - de: German.  Sie form.  Capitalise nouns.  Avoid Anglicisms
#     where a native term reads naturally ("Auflistung" not "Listing").
#   - it: Italian.  Apple style.  Tu form in prose.
# ──────────────────────────────────────────────────────────────────────

# The original 56 strings + their 4-language translations get re-asserted
# from the existing catalog (untouched), then we ADD pt-PT to each.
#
# This dict is keyed by the English source string and provides the
# pt-PT translation only.  Existing de/es/fr/it stay as-is.
PT_PT_FOR_EXISTING = {
    "%1$lld / %2$lld apps": "%1$lld / %2$lld apps",
    "+%lld more": "+%lld mais",
    "AI request failed: %@": "Pedido à IA falhou: %@",
    "All alternatives": "Todas as alternativas",
    "All apps": "Todas as apps",
    "Alternatives": "Alternativas",
    "Apps we don't know yet (%lld)": "Apps que ainda não conhecemos (%lld)",
    "Ask AI": "Perguntar à IA",
    "Ask again": "Perguntar de novo",
    "Asking…": "A perguntar…",
    "Business model": "Modelo de negócio",
    "Details + alternatives": "Detalhes + alternativas",
    "Download %@ via Splynek": "Transferir %@ pelo Splynek",
    "Either none of your installed apps have catalog entries yet, or the current filter is hiding them. The Trust catalog is intentionally focused on the most-installed apps — community PRs at github.com/Splynek/splynek expand it.":
        "Ou nenhuma das tuas apps instaladas tem entradas no catálogo, ou o filtro atual está a escondê-las. O catálogo Trust está intencionalmente focado nas apps mais instaladas — PRs da comunidade em github.com/Splynek/splynek alargam-no.",
    "Either your installed apps don't have catalog entries yet, or the filter is hiding them. The catalog is intentionally small at launch — community PRs expand it at [github.com/Splynek/splynek](https://github.com/Splynek/splynek).":
        "Ou as tuas apps instaladas ainda não têm entradas no catálogo, ou o filtro está a escondê-las. O catálogo é intencionalmente pequeno no lançamento — PRs da comunidade alargam-no em [github.com/Splynek/splynek](https://github.com/Splynek/splynek).",
    "Enumeration only — never reads app contents": "Apenas enumeração — nunca lê o conteúdo das apps",
    "European only": "Apenas europeias",
    "Every concern cites a primary source you can open": "Cada preocupação cita uma fonte primária que podes abrir",
    "Filter": "Filtro",
    "High": "Alta",
    "High risk only": "Apenas risco alto",
    "How this works": "Como funciona",
    "Install": "Instalar",
    "Last reviewed %@": "Última revisão %@",
    "Low": "Baixa",
    "Moderate": "Moderada",
    "Most Mac apps are controlled from outside the European Union. Splynek lists your third-party apps with their country-of-origin, and points to European or open-source alternatives where they exist. Nothing is uploaded, logged, or remembered across launches.":
        "A maioria das apps para Mac é controlada fora da União Europeia. O Splynek lista as tuas apps de terceiros com o país de origem e aponta alternativas europeias ou de código aberto, quando existem. Nada é carregado, registado ou guardado entre arranques.",
    "No curated alternative for this app yet. Contribute one at github.com/Splynek/splynek.":
        "Ainda não há uma alternativa curada para esta app. Contribui em github.com/Splynek/splynek.",
    "No matches with the current filter": "Sem correspondências com o filtro atual",
    "No public-record concerns for your installed apps": "Sem preocupações de registo público para as tuas apps instaladas",
    "Open %@ in your browser": "Abrir %@ no navegador",
    "Open-source only": "Apenas código aberto",
    "Open-source scanner in the public repo": "Scanner de código aberto no repositório público",
    "Opt-in — you click Scan, nothing runs in the background": "Opcional — clicas em Analisar, nada corre em segundo plano",
    "Privacy": "Privacidade",
    "Public-record audit of your apps": "Auditoria de registo público das tuas apps",
    "Re-enumerate installed apps": "Re-enumerar apps instaladas",
    "Rescan": "Reanalisar",
    "Scan my Mac": "Analisar o meu Mac",
    "Scanning…": "A analisar…",
    "Search by app name": "Pesquisar por nome da app",
    "Security": "Segurança",
    "See what public records say about your installed apps — App Store privacy labels, regulatory rulings, confirmed breaches, vendor security advisories. Every claim cites its primary source. Everything stays local.":
        "Vê o que os registos públicos dizem sobre as tuas apps instaladas — etiquetas de privacidade da App Store, decisões regulamentares, violações confirmadas, avisos de segurança dos fornecedores. Cada afirmação cita a fonte primária. Tudo permanece local.",
    "See where your Mac's software comes from, and which apps have European or open-source alternatives. Everything stays local — no account, no telemetry, no app list leaving your device.":
        "Vê de onde vem o software do teu Mac e quais apps têm alternativas europeias ou de código aberto. Tudo permanece local — sem conta, sem telemetria, sem a lista de apps a sair do teu dispositivo.",
    "Severe": "Grave",
    "Sovereignty": "Soberania",
    "Sovereignty pick": "Escolha de soberania",
    "Splynek cross-references your installed apps against Apple's App Store privacy labels, EU and US regulator decisions, the NVD CVE database, and the HIBP breach corpus. Every concern shown is a fact you can verify yourself — we surface public record, never opinion.":
        "O Splynek cruza as tuas apps instaladas com as etiquetas de privacidade da App Store da Apple, decisões dos reguladores da UE e dos EUA, a base de dados de CVEs do NVD e o corpus de violações da HIBP. Cada preocupação é um facto que podes verificar — apresentamos registos públicos, nunca opinião.",
    "Stays on-device — no network calls, ever": "Fica no dispositivo — nunca acede à rede",
    "The local LLM didn't know any good European or open-source alternatives. Contribute one at github.com/Splynek/splynek.":
        "O LLM local não conhecia boas alternativas europeias ou de código aberto. Contribui em github.com/Splynek/splynek.",
    "Trust": "Confiança",
    "Trust pick": "Escolha de confiança",
    "Trust surfaces public-record facts about your installed apps — Apple's own App Store privacy labels (which developers self-disclose), EU and US regulator decisions, the NVD CVE database, the HIBP breach corpus, and vendor security advisories. We do not editorialise. Every concern shown links to its primary source so you can verify the claim. If you spot inaccurate or outdated information, please open a PR or issue at github.com/Splynek/splynek.":
        "O Trust apresenta factos de registo público sobre as tuas apps instaladas — as próprias etiquetas de privacidade da App Store da Apple (que os programadores divulgam), decisões dos reguladores da UE e dos EUA, a base de dados de CVEs do NVD, o corpus de violações da HIBP e os avisos de segurança dos fornecedores. Não editorializamos. Cada preocupação tem ligação à fonte primária para que possas verificar a afirmação. Se vires informação imprecisa ou desactualizada, abre um PR ou issue em github.com/Splynek/splynek.",
    "Visit": "Visitar",
    "Your software supply chain": "A tua cadeia de software",
    "…and %lld more.": "…e mais %lld.",
}


# ──────────────────────────────────────────────────────────────────────
# v1.6 new strings — five-language translations.
#
# Each entry is the English source mapped to a dict of locale → value.
# When a translation is intentionally kept identical to English (e.g.
# proper nouns, technical wire identifiers), include it explicitly so
# the catalog state is "translated", not "needs translation".
# ──────────────────────────────────────────────────────────────────────

NEW_V16_STRINGS = {
    # ── Onboarding sheet ─────────────────────────────────────────
    "Welcome to Splynek": {
        "pt-PT": "Bem-vindo ao Splynek",
        "es": "Te damos la bienvenida a Splynek",
        "fr": "Bienvenue dans Splynek",
        "de": "Willkommen bei Splynek",
        "it": "Ti diamo il benvenuto in Splynek",
    },
    "A download manager that pools every network connection your Mac has — Wi-Fi, Ethernet, your iPhone's tether, all at once.": {
        "pt-PT": "Um gestor de transferências que junta todas as ligações de rede do teu Mac — Wi-Fi, Ethernet, partilha do iPhone, tudo ao mesmo tempo.",
        "es": "Un gestor de descargas que combina todas las conexiones de red de tu Mac — Wi-Fi, Ethernet, la conexión compartida del iPhone, todas a la vez.",
        "fr": "Un gestionnaire de téléchargements qui regroupe toutes les connexions réseau de votre Mac — Wi-Fi, Ethernet, partage de connexion iPhone, simultanément.",
        "de": "Ein Download-Manager, der alle Netzwerkverbindungen Ihres Mac bündelt — WLAN, Ethernet, iPhone-Tethering, alles gleichzeitig.",
        "it": "Un download manager che combina tutte le connessioni di rete del tuo Mac — Wi-Fi, Ethernet, hotspot dell'iPhone, tutte insieme.",
    },
    "Faster": {
        "pt-PT": "Mais rápido",
        "es": "Más rápido",
        "fr": "Plus rapide",
        "de": "Schneller",
        "it": "Più veloce",
    },
    "Aggregates throughput across every network you're connected to.": {
        "pt-PT": "Junta o débito de todas as redes a que estás ligado.",
        "es": "Suma el ancho de banda de todas las redes conectadas.",
        "fr": "Cumule le débit de tous les réseaux connectés.",
        "de": "Bündelt die Bandbreite aller verbundenen Netzwerke.",
        "it": "Somma la banda di tutte le reti connesse.",
    },
    "Honest": {
        "pt-PT": "Honesto",
        "es": "Honesto",
        "fr": "Honnête",
        "de": "Ehrlich",
        "it": "Onesto",
    },
    "Every download verified against the publisher's checksum.": {
        "pt-PT": "Cada transferência verificada contra a soma de controlo do editor.",
        "es": "Cada descarga verificada contra la suma de comprobación del autor.",
        "fr": "Chaque téléchargement vérifié contre la somme de contrôle de l'éditeur.",
        "de": "Jeder Download wird gegen die Prüfsumme des Herausgebers verifiziert.",
        "it": "Ogni download viene verificato contro il checksum dell'editore.",
    },
    "Private": {
        "pt-PT": "Privado",
        "es": "Privado",
        "fr": "Privé",
        "de": "Privat",
        "it": "Privato",
    },
    "Nothing leaves your Mac. No account. No telemetry.": {
        "pt-PT": "Nada sai do teu Mac. Sem conta. Sem telemetria.",
        "es": "Nada sale de tu Mac. Sin cuenta. Sin telemetría.",
        "fr": "Rien ne quitte votre Mac. Aucun compte. Aucune télémétrie.",
        "de": "Nichts verlässt Ihren Mac. Kein Konto. Keine Telemetrie.",
        "it": "Nulla esce dal tuo Mac. Nessun account. Nessuna telemetria.",
    },
    "Sovereign": {
        "pt-PT": "Soberano",
        "es": "Soberano",
        "fr": "Souverain",
        "de": "Souverän",
        "it": "Sovrano",
    },
    "See where the apps on your Mac come from, and what regulators say about them.": {
        "pt-PT": "Vê de onde vêm as apps do teu Mac e o que os reguladores dizem sobre elas.",
        "es": "Descubre de dónde vienen las apps de tu Mac y qué dicen los reguladores sobre ellas.",
        "fr": "Découvrez d'où viennent les apps de votre Mac et ce que disent les régulateurs.",
        "de": "Sehen Sie, woher die Apps auf Ihrem Mac stammen und was Regulierungsbehörden dazu sagen.",
        "it": "Scopri da dove vengono le app sul tuo Mac e cosa dicono i regolatori.",
    },
    "Where should downloads go?": {
        "pt-PT": "Onde guardar as transferências?",
        "es": "¿Dónde guardar las descargas?",
        "fr": "Où enregistrer les téléchargements ?",
        "de": "Wo sollen Downloads gespeichert werden?",
        "it": "Dove salvare i download?",
    },
    "Splynek will save files here. You can change this later in Settings — but picking once now means you'll always know where things land.": {
        "pt-PT": "O Splynek guarda aqui os ficheiros transferidos. Podes mudar nas Definições mais tarde — mas escolher agora significa que vais saber sempre onde tudo aparece.",
        "es": "Splynek guardará los archivos aquí. Puedes cambiarlo más tarde en Ajustes — pero elegir ahora significa saber siempre dónde acaban las cosas.",
        "fr": "Splynek y enregistrera les fichiers. Vous pourrez modifier ce choix plus tard dans les Réglages — mais choisir maintenant garantit de toujours savoir où atterrissent les fichiers.",
        "de": "Splynek speichert Dateien hier. Sie können dies später in den Einstellungen ändern — aber jetzt zu wählen bedeutet, dass Sie immer wissen, wo Dateien landen.",
        "it": "Splynek salverà i file qui. Puoi cambiarlo più tardi nelle Impostazioni — ma scegliere ora significa sapere sempre dove finiscono le cose.",
    },
    "Selected folder": {
        "pt-PT": "Pasta selecionada",
        "es": "Carpeta seleccionada",
        "fr": "Dossier sélectionné",
        "de": "Ausgewählter Ordner",
        "it": "Cartella selezionata",
    },
    "Change…": {
        "pt-PT": "Alterar…",
        "es": "Cambiar…",
        "fr": "Modifier…",
        "de": "Ändern…",
        "it": "Cambia…",
    },
    "Choose a download folder": {
        "pt-PT": "Escolher uma pasta para transferências",
        "es": "Elegir una carpeta de descargas",
        "fr": "Choisir un dossier de téléchargement",
        "de": "Download-Ordner auswählen",
        "it": "Scegli una cartella per i download",
    },
    "Tip: many users keep ~/Downloads. Splynek doesn't move files there — it goes straight to whatever you pick.": {
        "pt-PT": "Dica: a maioria dos utilizadores fica por ~/Downloads. O Splynek não copia ficheiros para lá — vai diretamente para a pasta que escolheres.",
        "es": "Consejo: muchos usuarios se quedan con ~/Downloads. Splynek no mueve archivos allí — va directo a lo que elijas.",
        "fr": "Astuce : beaucoup d'utilisateurs gardent ~/Downloads. Splynek ne déplace pas les fichiers — il va directement vers le dossier que vous choisissez.",
        "de": "Tipp: Viele Nutzer behalten ~/Downloads. Splynek verschiebt keine Dateien dorthin — es geht direkt zu dem, was Sie auswählen.",
        "it": "Suggerimento: molti utenti restano su ~/Downloads. Splynek non sposta file lì — va direttamente alla cartella che scegli.",
    },
    "Run a quick audit?": {
        "pt-PT": "Fazer uma auditoria rápida?",
        "es": "¿Hacer una auditoría rápida?",
        "fr": "Lancer un audit rapide ?",
        "de": "Schnelle Prüfung durchführen?",
        "it": "Fare una verifica rapida?",
    },
    "Splynek can scan the apps on your Mac and tell you where each one is controlled from, plus what public records say about its privacy and security. Local-only — nothing leaves your device.": {
        "pt-PT": "O Splynek pode analisar as apps do teu Mac e dizer-te de onde cada uma é controlada, além do que os registos públicos dizem sobre privacidade e segurança. Apenas local — nada sai do teu dispositivo.",
        "es": "Splynek puede analizar las apps de tu Mac y decirte desde dónde se controla cada una, además de lo que los registros públicos dicen sobre su privacidad y seguridad. Solo local — nada sale del dispositivo.",
        "fr": "Splynek peut analyser les apps de votre Mac et vous indiquer d'où chacune est contrôlée, ainsi que ce que les registres publics disent de leur confidentialité et sécurité. Local uniquement — rien ne quitte votre appareil.",
        "de": "Splynek kann die Apps auf Ihrem Mac scannen und Ihnen sagen, von wo jede gesteuert wird, sowie was öffentliche Register zu Datenschutz und Sicherheit sagen. Nur lokal — nichts verlässt Ihr Gerät.",
        "it": "Splynek può scansionare le app sul tuo Mac e dirti da dove ognuna è controllata, oltre a cosa dicono i registri pubblici su privacy e sicurezza. Solo locale — nulla lascia il tuo dispositivo.",
    },
    "Reads only the bundle list — never opens app contents": {
        "pt-PT": "Lê apenas a lista de pacotes — nunca abre o conteúdo das apps",
        "es": "Solo lee la lista de paquetes — nunca abre el contenido de las apps",
        "fr": "Lit seulement la liste des bundles — n'ouvre jamais le contenu des apps",
        "de": "Liest nur die Bundle-Liste — öffnet niemals App-Inhalte",
        "it": "Legge solo l'elenco dei bundle — non apre mai il contenuto delle app",
    },
    "Stays on-device — no network calls, ever": {
        "pt-PT": "Fica no dispositivo — nunca acede à rede",
        "es": "Permanece en el dispositivo — nunca hay llamadas de red",
        "fr": "Reste sur l'appareil — aucun appel réseau, jamais",
        "de": "Bleibt auf dem Gerät — niemals Netzwerkaufrufe",
        "it": "Resta sul dispositivo — nessuna chiamata di rete, mai",
    },
    "Takes about 5 seconds": {
        "pt-PT": "Demora cerca de 5 segundos",
        "es": "Tarda unos 5 segundos",
        "fr": "Prend environ 5 secondes",
        "de": "Dauert etwa 5 Sekunden",
        "it": "Richiede circa 5 secondi",
    },
    "Run audit + finish": {
        "pt-PT": "Executar auditoria + concluir",
        "es": "Ejecutar auditoría + terminar",
        "fr": "Lancer l'audit + terminer",
        "de": "Prüfung ausführen + Abschließen",
        "it": "Esegui verifica + termina",
    },
    "Maybe later": {
        "pt-PT": "Talvez mais tarde",
        "es": "Quizás más tarde",
        "fr": "Plus tard peut-être",
        "de": "Vielleicht später",
        "it": "Forse più tardi",
    },
    "Get started": {
        "pt-PT": "Começar",
        "es": "Empezar",
        "fr": "Commencer",
        "de": "Loslegen",
        "it": "Inizia",
    },
    "Continue": {
        "pt-PT": "Continuar",
        "es": "Continuar",
        "fr": "Continuer",
        "de": "Weiter",
        "it": "Continua",
    },
    "Back": {
        "pt-PT": "Voltar",
        "es": "Atrás",
        "fr": "Précédent",
        "de": "Zurück",
        "it": "Indietro",
    },
    "Skip": {
        "pt-PT": "Ignorar",
        "es": "Omitir",
        "fr": "Ignorer",
        "de": "Überspringen",
        "it": "Salta",
    },
    "Scan started — results appear in Sovereignty + Trust tabs.": {
        "pt-PT": "Análise iniciada — os resultados aparecem nos separadores Sovereignty e Trust.",
        "es": "Análisis iniciado — los resultados aparecen en las pestañas Soberanía y Confianza.",
        "fr": "Analyse démarrée — les résultats apparaissent dans les onglets Souveraineté et Confiance.",
        "de": "Prüfung gestartet — Ergebnisse erscheinen in den Tabs Souveränität und Vertrauen.",
        "it": "Analisi avviata — i risultati appariranno nelle schede Sovranità e Affidabilità.",
    },

    # ── Sidebar group titles ─────────────────────────────────────
    "Ask": {
        "pt-PT": "Perguntar",
        "es": "Preguntar",
        "fr": "Demander",
        "de": "Fragen",
        "it": "Chiedi",
    },
    "Active": {
        "pt-PT": "Ativos",
        "es": "Activo",
        "fr": "Actif",
        "de": "Aktiv",
        "it": "Attivi",
    },
    "Library": {
        "pt-PT": "Biblioteca",
        "es": "Biblioteca",
        "fr": "Bibliothèque",
        "de": "Bibliothek",
        "it": "Libreria",
    },
    "Connect": {
        "pt-PT": "Ligar",
        "es": "Conectar",
        "fr": "Connecter",
        "de": "Verbinden",
        "it": "Connetti",
    },
    "Agents": {
        "pt-PT": "Agentes",
        "es": "Agentes",
        "fr": "Agents",
        "de": "Agenten",
        "it": "Agenti",
    },

    # ── Sidebar tab labels (v1.6.2: previously bypassed
    # localization because Sidebar.swift used Label(_:systemImage:)
    # with a String, which is verbatim.  Fixed by routing the
    # String through LocalizedStringKey; these entries make the
    # catalog hit translate. ──
    "Downloads": {
        "pt-PT": "Transferências",
        "es": "Descargas",
        "fr": "Téléchargements",
        "de": "Downloads",
        "it": "Download",
    },
    "Torrents": {
        "pt-PT": "Torrents",
        "es": "Torrents",
        "fr": "Torrents",
        "de": "Torrents",
        "it": "Torrent",
    },
    "Live": {
        "pt-PT": "Ao Vivo",
        "es": "En Vivo",
        "fr": "En Direct",
        "de": "Live",
        "it": "Live",
    },
    "Concierge": {
        "pt-PT": "Concierge",
        "es": "Concierge",
        "fr": "Concierge",
        "de": "Concierge",
        "it": "Concierge",
    },
    "Recipes": {
        "pt-PT": "Receitas",
        "es": "Recetas",
        "fr": "Recettes",
        "de": "Rezepte",
        "it": "Ricette",
    },
    "Queue": {
        "pt-PT": "Fila",
        "es": "Cola",
        "fr": "File d'attente",
        "de": "Warteschlange",
        "it": "Coda",
    },
    "Fleet": {
        "pt-PT": "Frota",
        "es": "Flota",
        "fr": "Flotte",
        "de": "Flotte",
        "it": "Flotta",
    },
    "Benchmark": {
        "pt-PT": "Avaliação",
        "es": "Prueba de rendimiento",
        "fr": "Évaluation",
        "de": "Benchmark",
        "it": "Benchmark",
    },
    "History": {
        "pt-PT": "Histórico",
        "es": "Historial",
        "fr": "Historique",
        "de": "Verlauf",
        "it": "Cronologia",
    },

    # ── Agents tab ───────────────────────────────────────────────
    "Splynek as a programmable platform — let Claude, ChatGPT, or any MCP-compatible agent drive downloads, run audits, and search your history through one HTTP endpoint.": {
        "pt-PT": "O Splynek como plataforma programável — deixa o Claude, o ChatGPT ou qualquer agente compatível com MCP gerir transferências, executar auditorias e pesquisar o teu histórico através de um único endpoint HTTP.",
        "es": "Splynek como plataforma programable — deja que Claude, ChatGPT o cualquier agente compatible con MCP gestione descargas, ejecute auditorías y busque en tu historial a través de un único endpoint HTTP.",
        "fr": "Splynek en tant que plateforme programmable — laissez Claude, ChatGPT ou tout agent compatible MCP gérer les téléchargements, lancer des audits et rechercher dans votre historique via un seul point d'accès HTTP.",
        "de": "Splynek als programmierbare Plattform — lassen Sie Claude, ChatGPT oder einen MCP-kompatiblen Agenten Downloads steuern, Prüfungen ausführen und Ihren Verlauf über einen HTTP-Endpunkt durchsuchen.",
        "it": "Splynek come piattaforma programmabile — lascia che Claude, ChatGPT o qualsiasi agente compatibile MCP gestisca download, esegua verifiche e cerchi nella cronologia attraverso un unico endpoint HTTP.",
    },
    "Status": {
        "pt-PT": "Estado",
        "es": "Estado",
        "fr": "État",
        "de": "Status",
        "it": "Stato",
    },
    "Allow MCP clients to call Splynek tools": {
        "pt-PT": "Permitir que clientes MCP usem as ferramentas do Splynek",
        "es": "Permitir que los clientes MCP llamen a las herramientas de Splynek",
        "fr": "Autoriser les clients MCP à utiliser les outils Splynek",
        "de": "MCP-Clients erlauben, Splynek-Werkzeuge zu verwenden",
        "it": "Consenti ai client MCP di usare gli strumenti Splynek",
    },
    "Endpoint": {
        "pt-PT": "Endpoint",
        "es": "Endpoint",
        "fr": "Point d'accès",
        "de": "Endpunkt",
        "it": "Endpoint",
    },
    "Off by default. Flip the switch above to enable agents to call Splynek.": {
        "pt-PT": "Desligado por predefinição. Ativa o interruptor acima para permitir que agentes chamem o Splynek.",
        "es": "Desactivado por defecto. Activa el interruptor de arriba para permitir que los agentes llamen a Splynek.",
        "fr": "Désactivé par défaut. Activez le commutateur ci-dessus pour permettre aux agents d'appeler Splynek.",
        "de": "Standardmäßig deaktiviert. Aktivieren Sie den Schalter oben, damit Agenten Splynek aufrufen können.",
        "it": "Disattivato per impostazione predefinita. Attiva l'interruttore sopra per consentire agli agenti di chiamare Splynek.",
    },
    "Available tools": {
        "pt-PT": "Ferramentas disponíveis",
        "es": "Herramientas disponibles",
        "fr": "Outils disponibles",
        "de": "Verfügbare Werkzeuge",
        "it": "Strumenti disponibili",
    },
    "Quick test": {
        "pt-PT": "Teste rápido",
        "es": "Prueba rápida",
        "fr": "Test rapide",
        "de": "Schnelltest",
        "it": "Test rapido",
    },
    "Connect a client": {
        "pt-PT": "Ligar um cliente",
        "es": "Conectar un cliente",
        "fr": "Connecter un client",
        "de": "Client verbinden",
        "it": "Connetti un client",
    },
    "Privacy + safety": {
        "pt-PT": "Privacidade + segurança",
        "es": "Privacidad + seguridad",
        "fr": "Confidentialité + sécurité",
        "de": "Datenschutz + Sicherheit",
        "it": "Privacy + sicurezza",
    },

    # ── Downloads — Source card ──────────────────────────────────
    "Source": {
        "pt-PT": "Fonte",
        "es": "Origen",
        "fr": "Source",
        "de": "Quelle",
        "it": "Origine",
    },
    "Verify this download is authentic (optional)": {
        "pt-PT": "Verificar se esta transferência é autêntica (opcional)",
        "es": "Verificar que esta descarga es auténtica (opcional)",
        "fr": "Vérifier l'authenticité de ce téléchargement (optionnel)",
        "de": "Authentizität dieses Downloads prüfen (optional)",
        "it": "Verifica l'autenticità di questo download (opzionale)",
    },
    "Verified — Splynek will check the file matches the publisher's checksum": {
        "pt-PT": "Verificado — o Splynek vai confirmar que o ficheiro corresponde à soma de controlo do editor",
        "es": "Verificado — Splynek comprobará que el archivo coincide con la suma del autor",
        "fr": "Vérifié — Splynek s'assurera que le fichier correspond à la somme de contrôle de l'éditeur",
        "de": "Verifiziert — Splynek prüft, ob die Datei mit der Prüfsumme des Herausgebers übereinstimmt",
        "it": "Verificato — Splynek controllerà che il file corrisponda al checksum dell'editore",
    },
    "Paste a SHA-256 checksum here (64 hex characters)": {
        "pt-PT": "Cola aqui uma soma SHA-256 (64 caracteres hexadecimais)",
        "es": "Pega aquí una suma SHA-256 (64 caracteres hexadecimales)",
        "fr": "Collez ici une somme SHA-256 (64 caractères hexadécimaux)",
        "de": "Fügen Sie hier eine SHA-256-Prüfsumme ein (64 Hex-Zeichen)",
        "it": "Incolla qui un checksum SHA-256 (64 caratteri esadecimali)",
    },

    # ── Downloads — Options card ─────────────────────────────────
    "Options": {
        "pt-PT": "Opções",
        "es": "Opciones",
        "fr": "Options",
        "de": "Optionen",
        "it": "Opzioni",
    },
    "Speed per network": {
        "pt-PT": "Velocidade por rede",
        "es": "Velocidad por red",
        "fr": "Vitesse par réseau",
        "de": "Geschwindigkeit pro Netzwerk",
        "it": "Velocità per rete",
    },
    "polite": {
        "pt-PT": "discreto",
        "es": "educado",
        "fr": "poli",
        "de": "höflich",
        "it": "cortese",
    },
    "balanced": {
        "pt-PT": "equilibrado",
        "es": "equilibrado",
        "fr": "équilibré",
        "de": "ausgewogen",
        "it": "bilanciato",
    },
    "aggressive": {
        "pt-PT": "agressivo",
        "es": "agresivo",
        "fr": "agressif",
        "de": "aggressiv",
        "it": "aggressivo",
    },
    "Downloads at once": {
        "pt-PT": "Transferências simultâneas",
        "es": "Descargas simultáneas",
        "fr": "Téléchargements simultanés",
        "de": "Gleichzeitige Downloads",
        "it": "Download simultanei",
    },
    "Encrypt DNS lookups": {
        "pt-PT": "Encriptar consultas de DNS",
        "es": "Cifrar consultas DNS",
        "fr": "Chiffrer les requêtes DNS",
        "de": "DNS-Abfragen verschlüsseln",
        "it": "Cripta le query DNS",
    },
    "Advanced source formats": {
        "pt-PT": "Formatos de fonte avançados",
        "es": "Formatos de origen avanzados",
        "fr": "Formats de source avancés",
        "de": "Erweiterte Quellformate",
        "it": "Formati di origine avanzati",
    },

    # ── Settings titles ──────────────────────────────────────────
    "Settings": {
        "pt-PT": "Definições",
        "es": "Ajustes",
        "fr": "Réglages",
        "de": "Einstellungen",
        "it": "Impostazioni",
    },
    "Trust score weights": {
        "pt-PT": "Pesos da pontuação Trust",
        "es": "Pesos de la puntuación Trust",
        "fr": "Pondérations du score Trust",
        "de": "Gewichtungen der Trust-Bewertung",
        "it": "Pesi del punteggio Trust",
    },

    # ── Empty states (post-v1.6.1 polish) ────────────────────────
    "See what regulators, app stores, and breach databases say about the software on your Mac.": {
        "pt-PT": "Vê o que os reguladores, lojas de apps e bases de dados de violações dizem sobre o software no teu Mac.",
        "es": "Descubre lo que dicen los reguladores, las tiendas de apps y las bases de datos de filtraciones sobre el software de tu Mac.",
        "fr": "Découvrez ce que les régulateurs, les boutiques d'apps et les bases de données de fuites disent du logiciel sur votre Mac.",
        "de": "Erfahren Sie, was Regulierungsbehörden, App-Stores und Leak-Datenbanken über die Software auf Ihrem Mac sagen.",
        "it": "Scopri cosa dicono i regolatori, gli app store e i database di violazioni sul software del tuo Mac.",
    },
    "See where your Mac's apps come from, and which have European or open-source alternatives.": {
        "pt-PT": "Vê de onde vêm as apps do teu Mac e quais têm alternativas europeias ou de código aberto.",
        "es": "Descubre de dónde vienen las apps de tu Mac y cuáles tienen alternativas europeas o de código abierto.",
        "fr": "Découvrez d'où viennent les apps de votre Mac et lesquelles ont des alternatives européennes ou open source.",
        "de": "Sehen Sie, woher die Apps Ihres Mac stammen und welche europäische oder Open-Source-Alternativen haben.",
        "it": "Scopri da dove vengono le app del tuo Mac e quali hanno alternative europee o open source.",
    },
    "Sources: Apple App Store, EU and US regulators, NVD CVE database, HIBP, vendor advisories.": {
        "pt-PT": "Fontes: Apple App Store, reguladores da UE e dos EUA, base de dados de CVEs do NVD, HIBP, avisos de fornecedores.",
        "es": "Fuentes: Apple App Store, reguladores de la UE y EE. UU., base de datos CVE de NVD, HIBP, avisos de proveedores.",
        "fr": "Sources : Apple App Store, régulateurs UE et US, base de données CVE NVD, HIBP, avis des éditeurs.",
        "de": "Quellen: Apple App Store, EU- und US-Regulierungsbehörden, NVD-CVE-Datenbank, HIBP, Hersteller-Hinweise.",
        "it": "Fonti: Apple App Store, regolatori UE e USA, database CVE di NVD, HIBP, avvisi dei fornitori.",
    },
    "Catalog covers 1,100+ apps. Community PRs at github.com/Splynek/splynek expand it.": {
        "pt-PT": "O catálogo cobre mais de 1100 apps. PRs da comunidade em github.com/Splynek/splynek alargam-no.",
        "es": "El catálogo cubre más de 1100 apps. Los PR de la comunidad en github.com/Splynek/splynek lo amplían.",
        "fr": "Le catalogue couvre plus de 1 100 apps. Les PR de la communauté sur github.com/Splynek/splynek l'étendent.",
        "de": "Der Katalog umfasst über 1 100 Apps. Community-PRs auf github.com/Splynek/splynek erweitern ihn.",
        "it": "Il catalogo copre oltre 1100 app. Le PR della community su github.com/Splynek/splynek lo ampliano.",
    },

    # ── Common buttons / actions ─────────────────────────────────
    "Cancel": {
        "pt-PT": "Cancelar",
        "es": "Cancelar",
        "fr": "Annuler",
        "de": "Abbrechen",
        "it": "Annulla",
    },
    "Reset to defaults": {
        "pt-PT": "Repor predefinições",
        "es": "Restablecer valores predeterminados",
        "fr": "Rétablir les valeurs par défaut",
        "de": "Auf Standard zurücksetzen",
        "it": "Ripristina valori predefiniti",
    },
    "Start download": {
        "pt-PT": "Iniciar transferência",
        "es": "Iniciar descarga",
        "fr": "Démarrer le téléchargement",
        "de": "Download starten",
        "it": "Avvia download",
    },

    # ── Common card titles + button labels (v1.6.2: TitledCard +
    # labelWithInfo + button labels now route through
    # LocalizedStringKey, so adding the source-language entries
    # here makes them translate.) ──
    "Add to queue": {
        "pt-PT": "Adicionar à fila",
        "es": "Añadir a la cola",
        "fr": "Ajouter à la file",
        "de": "Zur Warteschlange hinzufügen",
        "it": "Aggiungi alla coda",
    },
    "Downloading — \(Int(job.progress.fraction * 100))%": {
        # Pane title for one active download, e.g. "Downloading — 42%".
        # The `\()` interpolation is part of the LocalizedStringKey
        # itself; SwiftUI substitutes the integer at render time.
        "pt-PT": "A transferir — \(Int(job.progress.fraction * 100))%",
        "es": "Descargando — \(Int(job.progress.fraction * 100))%",
        "fr": "Téléchargement — \(Int(job.progress.fraction * 100)) %",
        "de": "Lädt — \(Int(job.progress.fraction * 100))%",
        "it": "Scaricando — \(Int(job.progress.fraction * 100))%",
    },
    "Downloading — \(running.count) active": {
        "pt-PT": "A transferir — \(running.count) ativas",
        "es": "Descargando — \(running.count) activas",
        "fr": "Téléchargement — \(running.count) actifs",
        "de": "Lädt — \(running.count) aktiv",
        "it": "Scaricando — \(running.count) attivi",
    },

    # ── Splash banners + page-level subtitles ──
    "Paste a URL. Splynek fans it out across every interface you have — Wi-Fi, Ethernet, tether — and reassembles a verified file.": {
        "pt-PT": "Cola um URL. O Splynek distribui-o por todas as ligações que tens — Wi-Fi, Ethernet, partilha — e recompõe um ficheiro verificado.",
        "es": "Pega una URL. Splynek la reparte por todas tus conexiones — Wi-Fi, Ethernet, conexión compartida — y reensambla un archivo verificado.",
        "fr": "Collez une URL. Splynek la répartit sur toutes vos interfaces — Wi-Fi, Ethernet, partage — et reconstruit un fichier vérifié.",
        "de": "URL einfügen. Splynek verteilt sie auf alle Verbindungen — WLAN, Ethernet, Tethering — und setzt eine verifizierte Datei zusammen.",
        "it": "Incolla un URL. Splynek lo distribuisce su tutte le tue connessioni — Wi-Fi, Ethernet, hotspot — e ricompone un file verificato.",
    },

    # ── Card titles ──
    "Interfaces": {
        "pt-PT": "Interfaces",
        "es": "Interfaces",
        "fr": "Interfaces",
        "de": "Schnittstellen",
        "it": "Interfacce",
    },

    # ── Pro card ──
    "Splynek Pro": {
        "pt-PT": "Splynek Pro",
        "es": "Splynek Pro",
        "fr": "Splynek Pro",
        "de": "Splynek Pro",
        "it": "Splynek Pro",
    },

    # ── Generic actions / status (v1.6.2: needed by various
    # buttons across tabs.) ──
    "Save": {
        "pt-PT": "Guardar",
        "es": "Guardar",
        "fr": "Enregistrer",
        "de": "Speichern",
        "it": "Salva",
    },
    "Done": {
        "pt-PT": "Concluído",
        "es": "Hecho",
        "fr": "Terminé",
        "de": "Fertig",
        "it": "Fine",
    },
    "Open": {
        "pt-PT": "Abrir",
        "es": "Abrir",
        "fr": "Ouvrir",
        "de": "Öffnen",
        "it": "Apri",
    },
    "Close": {
        "pt-PT": "Fechar",
        "es": "Cerrar",
        "fr": "Fermer",
        "de": "Schließen",
        "it": "Chiudi",
    },
    "About": {
        "pt-PT": "Acerca",
        "es": "Acerca de",
        "fr": "À propos",
        "de": "Über",
        "it": "Info",
    },
    "Legal": {
        "pt-PT": "Avisos legais",
        "es": "Avisos legales",
        "fr": "Mentions légales",
        "de": "Rechtliches",
        "it": "Note legali",
    },

    # ── v1.6.2: catalog-coverage sweep based on
    # `Scripts/find-missing-translations.py` output.  Highest-impact
    # 60 strings — common buttons, Settings card explanations,
    # AboutView bullets, AgentsView extras, Concierge / Recipes
    # upsell.  Long-tail technical tooltips left for follow-ups.

    # ── Common buttons + actions ──
    "Add": {
        "pt-PT": "Adicionar",
        "es": "Añadir",
        "fr": "Ajouter",
        "de": "Hinzufügen",
        "it": "Aggiungi",
    },
    "Cancel All": {
        "pt-PT": "Cancelar tudo",
        "es": "Cancelar todo",
        "fr": "Tout annuler",
        "de": "Alle abbrechen",
        "it": "Annulla tutto",
    },
    "Clear": {
        "pt-PT": "Limpar",
        "es": "Borrar",
        "fr": "Effacer",
        "de": "Löschen",
        "it": "Cancella",
    },
    "Clear finished": {
        "pt-PT": "Limpar concluídos",
        "es": "Borrar terminados",
        "fr": "Effacer les terminés",
        "de": "Beendete löschen",
        "it": "Cancella completati",
    },
    "Clear checksum": {
        "pt-PT": "Apagar checksum",
        "es": "Borrar suma",
        "fr": "Effacer la somme",
        "de": "Prüfsumme löschen",
        "it": "Cancella checksum",
    },
    "Reset": {
        "pt-PT": "Repor",
        "es": "Restablecer",
        "fr": "Réinitialiser",
        "de": "Zurücksetzen",
        "it": "Reimposta",
    },
    "Run": {
        "pt-PT": "Executar",
        "es": "Ejecutar",
        "fr": "Exécuter",
        "de": "Ausführen",
        "it": "Esegui",
    },
    "Reveal": {
        "pt-PT": "Mostrar no Finder",
        "es": "Mostrar en Finder",
        "fr": "Afficher dans le Finder",
        "de": "Im Finder anzeigen",
        "it": "Mostra nel Finder",
    },
    "Re-download": {
        "pt-PT": "Transferir de novo",
        "es": "Volver a descargar",
        "fr": "Re-télécharger",
        "de": "Erneut herunterladen",
        "it": "Riscarica",
    },
    "Copy URL": {
        "pt-PT": "Copiar URL",
        "es": "Copiar URL",
        "fr": "Copier l'URL",
        "de": "URL kopieren",
        "it": "Copia URL",
    },
    "Copy curl": {
        "pt-PT": "Copiar curl",
        "es": "Copiar curl",
        "fr": "Copier curl",
        "de": "curl kopieren",
        "it": "Copia curl",
    },
    "Copy results": {
        "pt-PT": "Copiar resultados",
        "es": "Copiar resultados",
        "fr": "Copier les résultats",
        "de": "Ergebnisse kopieren",
        "it": "Copia risultati",
    },
    "Save image…": {
        "pt-PT": "Guardar imagem…",
        "es": "Guardar imagen…",
        "fr": "Enregistrer l'image…",
        "de": "Bild sichern…",
        "it": "Salva immagine…",
    },
    "Run benchmark": {
        "pt-PT": "Executar avaliação",
        "es": "Ejecutar prueba",
        "fr": "Lancer l'évaluation",
        "de": "Benchmark starten",
        "it": "Esegui benchmark",
    },

    # ── AboutView ──
    "Multi-interface download aggregator": {
        "pt-PT": "Agregador de transferências multi-interface",
        "es": "Agregador de descargas multi-interfaz",
        "fr": "Agrégateur de téléchargements multi-interfaces",
        "de": "Multi-Schnittstellen-Download-Aggregator",
        "it": "Aggregatore di download multi-interfaccia",
    },
    "Download with Splynek": {
        "pt-PT": "Transferir com o Splynek",
        "es": "Descargar con Splynek",
        "fr": "Télécharger avec Splynek",
        "de": "Mit Splynek herunterladen",
        "it": "Scarica con Splynek",
    },
    "End-User Licence, Privacy Policy, and Acceptable Use — bundled into this app, viewable offline. See the *Legal* sidebar tab.": {
        "pt-PT": "Licença de utilizador final, política de privacidade e utilização aceitável — incluídas nesta app, visíveis sem ligação. Vê o separador *Avisos legais* na barra lateral.",
        "es": "Licencia de usuario final, política de privacidad y uso aceptable — incluidas en esta app, visibles sin conexión. Consulta la pestaña *Avisos legales* en la barra lateral.",
        "fr": "Licence utilisateur final, politique de confidentialité et utilisation acceptable — incluses dans cette app, consultables hors ligne. Voir l'onglet *Mentions légales* dans la barre latérale.",
        "de": "Endbenutzer-Lizenz, Datenschutzrichtlinie und akzeptable Nutzung — in dieser App gebündelt, offline einsehbar. Siehe Tab *Rechtliches* in der Seitenleiste.",
        "it": "Licenza per l'utente finale, informativa sulla privacy e uso accettabile — incluse in questa app, visibili offline. Vedi la scheda *Note legali* nella barra laterale.",
    },

    # ── AgentsView extras ──
    "Tool": {
        "pt-PT": "Ferramenta",
        "es": "Herramienta",
        "fr": "Outil",
        "de": "Werkzeug",
        "it": "Strumento",
    },
    "Client": {
        "pt-PT": "Cliente",
        "es": "Cliente",
        "fr": "Client",
        "de": "Client",
        "it": "Client",
    },
    "Eight tools any MCP client can call. All return human-readable text. Read-only tools listed first; mutating tools at the bottom.": {
        "pt-PT": "Oito ferramentas que qualquer cliente MCP pode chamar. Todas devolvem texto legível. As ferramentas só de leitura aparecem primeiro; as que modificam estado em baixo.",
        "es": "Ocho herramientas que cualquier cliente MCP puede llamar. Todas devuelven texto legible. Las de solo lectura aparecen primero; las que modifican estado al final.",
        "fr": "Huit outils que tout client MCP peut appeler. Tous renvoient du texte lisible. Les outils en lecture seule sont en haut ; ceux qui modifient l'état en bas.",
        "de": "Acht Werkzeuge, die jeder MCP-Client aufrufen kann. Alle geben menschenlesbaren Text zurück. Nur-Lese-Werkzeuge zuerst; verändernde Werkzeuge unten.",
        "it": "Otto strumenti che qualsiasi client MCP può chiamare. Tutti restituiscono testo leggibile. Solo lettura prima; quelli che modificano stato in fondo.",
    },
    "Endpoint binding…": {
        "pt-PT": "A vincular endpoint…",
        "es": "Vinculando endpoint…",
        "fr": "Liaison du point d'accès…",
        "de": "Endpunkt wird gebunden…",
        "it": "Associazione endpoint…",
    },
    "Paste this into your MCP client. Same auth token gates this as the web dashboard.": {
        "pt-PT": "Cola isto no teu cliente MCP. O mesmo token de autenticação protege isto e o painel web.",
        "es": "Pega esto en tu cliente MCP. El mismo token de autenticación protege esto y el panel web.",
        "fr": "Collez ceci dans votre client MCP. Le même jeton d'authentification protège ceci et le tableau de bord web.",
        "de": "Fügen Sie dies in Ihren MCP-Client ein. Derselbe Auth-Token schützt dies und das Web-Dashboard.",
        "it": "Incolla questo nel tuo client MCP. Lo stesso token di autenticazione protegge questo e la dashboard web.",
    },
    "Verify the server's responding without leaving Splynek. Picks the same endpoint you'd give a remote client.": {
        "pt-PT": "Verifica se o servidor responde sem sair do Splynek. Usa o mesmo endpoint que darias a um cliente remoto.",
        "es": "Verifica que el servidor responde sin salir de Splynek. Usa el mismo endpoint que darías a un cliente remoto.",
        "fr": "Vérifie que le serveur répond sans quitter Splynek. Utilise le même point d'accès que vous donneriez à un client distant.",
        "de": "Prüft, ob der Server antwortet, ohne Splynek zu verlassen. Verwendet denselben Endpunkt, den Sie einem entfernten Client geben würden.",
        "it": "Verifica che il server risponda senza uscire da Splynek. Usa lo stesso endpoint che daresti a un client remoto.",
    },
    "More details + transport notes in MCP_SETUP.md (in the repo root).": {
        "pt-PT": "Mais detalhes + notas de transporte em MCP_SETUP.md (na raiz do repositório).",
        "es": "Más detalles + notas de transporte en MCP_SETUP.md (en la raíz del repositorio).",
        "fr": "Plus de détails + notes sur le transport dans MCP_SETUP.md (à la racine du dépôt).",
        "de": "Weitere Details + Transport-Hinweise in MCP_SETUP.md (im Stammverzeichnis des Repos).",
        "it": "Altri dettagli + note sul transport in MCP_SETUP.md (nella radice del repository).",
    },
    "Copy endpoint URL": {
        "pt-PT": "Copiar URL do endpoint",
        "es": "Copiar URL del endpoint",
        "fr": "Copier l'URL du point d'accès",
        "de": "Endpunkt-URL kopieren",
        "it": "Copia URL endpoint",
    },
    "Copy snippet": {
        "pt-PT": "Copiar snippet",
        "es": "Copiar snippet",
        "fr": "Copier l'extrait",
        "de": "Snippet kopieren",
        "it": "Copia snippet",
    },

    # ── Concierge / Recipes upsell (free tier) ──
    "The Splynek Concierge": {
        "pt-PT": "O Splynek Concierge",
        "es": "El Splynek Concierge",
        "fr": "Le Splynek Concierge",
        "de": "Der Splynek Concierge",
        "it": "Il Splynek Concierge",
    },
    "Your personal download concierge.": {
        "pt-PT": "O teu concierge pessoal de transferências.",
        "es": "Tu concierge personal de descargas.",
        "fr": "Votre concierge de téléchargement personnel.",
        "de": "Ihr persönlicher Download-Concierge.",
        "it": "Il tuo concierge personale per i download.",
    },
    "Unlock Splynek Pro — $29": {
        "pt-PT": "Desbloquear Splynek Pro — $29",
        "es": "Desbloquear Splynek Pro — $29",
        "fr": "Débloquer Splynek Pro — $29",
        "de": "Splynek Pro freischalten — $29",
        "it": "Sblocca Splynek Pro — $29",
    },
    "One-time purchase. Lifetime 0.x updates.": {
        "pt-PT": "Compra única. Atualizações 0.x para sempre.",
        "es": "Compra única. Actualizaciones 0.x de por vida.",
        "fr": "Achat unique. Mises à jour 0.x à vie.",
        "de": "Einmaliger Kauf. Lebenslange 0.x-Updates.",
        "it": "Acquisto unico. Aggiornamenti 0.x a vita.",
    },
    "Agentic Download Recipes": {
        "pt-PT": "Receitas Agênticas de Transferência",
        "es": "Recetas Agénticas de Descarga",
        "fr": "Recettes Agentiques de Téléchargement",
        "de": "Agentische Download-Rezepte",
        "it": "Ricette Agentiche di Download",
    },
    "Tell it what you want to set up. Get a download plan.": {
        "pt-PT": "Diz-lhe o que queres configurar. Recebe um plano de transferências.",
        "es": "Dile lo que quieres configurar. Obtén un plan de descargas.",
        "fr": "Dites-lui ce que vous voulez configurer. Obtenez un plan de téléchargement.",
        "de": "Sagen Sie ihm, was Sie einrichten möchten. Erhalten Sie einen Download-Plan.",
        "it": "Digli cosa vuoi configurare. Ottieni un piano di download.",
    },

    # ── SettingsView card explanations ──
    "Privacy mode": {
        "pt-PT": "Modo de privacidade",
        "es": "Modo de privacidad",
        "fr": "Mode confidentialité",
        "de": "Datenschutzmodus",
        "it": "Modalità privacy",
    },
    "Hide active + completed downloads from other Splyneks on this LAN. Cooperative cache disabled.": {
        "pt-PT": "Esconde transferências ativas e concluídas de outros Splyneks nesta rede local. Cache cooperativa desativada.",
        "es": "Oculta las descargas activas y completadas de otros Splyneks en esta red local. Caché cooperativa desactivada.",
        "fr": "Masque les téléchargements actifs et terminés des autres Splyneks de ce réseau local. Cache coopératif désactivé.",
        "de": "Versteckt aktive und abgeschlossene Downloads vor anderen Splyneks im lokalen Netzwerk. Kooperativer Cache deaktiviert.",
        "it": "Nasconde i download attivi e completati da altri Splynek su questa rete locale. Cache cooperativa disattivata.",
    },
    "Loopback only (takes effect at next launch)": {
        "pt-PT": "Apenas loopback (entra em vigor no próximo arranque)",
        "es": "Solo loopback (se aplica en el próximo lanzamiento)",
        "fr": "Boucle locale uniquement (effectif au prochain lancement)",
        "de": "Nur Loopback (wird beim nächsten Start wirksam)",
        "it": "Solo loopback (effettivo al prossimo avvio)",
    },
    "Bind the dashboard + API to 127.0.0.1 only. Your phone won't reach it over Wi-Fi.": {
        "pt-PT": "Vincula o painel e a API apenas a 127.0.0.1. O teu telemóvel não vai conseguir aceder via Wi-Fi.",
        "es": "Vincula el panel y la API solo a 127.0.0.1. Tu teléfono no podrá acceder por Wi-Fi.",
        "fr": "Lie le tableau de bord + API uniquement à 127.0.0.1. Votre téléphone ne pourra pas y accéder via le Wi-Fi.",
        "de": "Bindet Dashboard + API nur an 127.0.0.1. Ihr Telefon erreicht es nicht über WLAN.",
        "it": "Vincola dashboard + API solo a 127.0.0.1. Il tuo telefono non potrà raggiungerli via Wi-Fi.",
    },
    "Regenerate token": {
        "pt-PT": "Regenerar token",
        "es": "Regenerar token",
        "fr": "Régénérer le jeton",
        "de": "Token neu erzeugen",
        "it": "Rigenera token",
    },
    "Launch at login": {
        "pt-PT": "Arrancar ao iniciar sessão",
        "es": "Iniciar al iniciar sesión",
        "fr": "Lancer à la connexion",
        "de": "Beim Anmelden starten",
        "it": "Avvia all'accesso",
    },
    "Menu-bar only (hide dock icon)": {
        "pt-PT": "Apenas barra de menus (esconder ícone do Dock)",
        "es": "Solo barra de menú (ocultar icono del Dock)",
        "fr": "Barre de menu uniquement (masquer l'icône du Dock)",
        "de": "Nur Menüleiste (Dock-Symbol ausblenden)",
        "it": "Solo barra dei menu (nascondi icona Dock)",
    },
    "Hide the dock icon and/or launch Splynek when you log in.": {
        "pt-PT": "Esconde o ícone do Dock e/ou inicia o Splynek quando inicias sessão.",
        "es": "Oculta el icono del Dock y/o inicia Splynek al iniciar sesión.",
        "fr": "Masque l'icône du Dock et/ou lance Splynek à la connexion.",
        "de": "Versteckt das Dock-Symbol und/oder startet Splynek beim Anmelden.",
        "it": "Nasconde l'icona del Dock e/o avvia Splynek all'accesso.",
    },
    "Watch folder for drops": {
        "pt-PT": "Vigiar pasta para ficheiros novos",
        "es": "Vigilar carpeta para archivos nuevos",
        "fr": "Surveiller le dossier pour les nouveaux fichiers",
        "de": "Ordner auf neue Dateien überwachen",
        "it": "Monitora cartella per nuovi file",
    },
    "Open the watched folder in Finder.": {
        "pt-PT": "Abrir a pasta vigiada no Finder.",
        "es": "Abrir la carpeta vigilada en Finder.",
        "fr": "Ouvrir le dossier surveillé dans le Finder.",
        "de": "Überwachten Ordner im Finder öffnen.",
        "it": "Apri la cartella monitorata nel Finder.",
    },
    "Pause on cellular": {
        "pt-PT": "Pausar em rede móvel",
        "es": "Pausar en datos móviles",
        "fr": "Mettre en pause en cellulaire",
        "de": "Bei Mobilfunk pausieren",
        "it": "Pausa su rete cellulare",
    },
    "Block starts while any selected interface is cellular. Complements the per-day bytes cap.": {
        "pt-PT": "Impede arranques enquanto alguma interface selecionada for móvel. Complementa o limite diário de dados.",
        "es": "Bloquea inicios mientras alguna interfaz seleccionada sea móvil. Complementa el límite diario de datos.",
        "fr": "Bloque les démarrages tant qu'une interface sélectionnée est cellulaire. Complète la limite quotidienne d'octets.",
        "de": "Blockiert Starts, solange eine ausgewählte Schnittstelle Mobilfunk ist. Ergänzt das tägliche Daten-Limit.",
        "it": "Blocca gli avvii mentre un'interfaccia selezionata è cellulare. Integra il limite giornaliero di dati.",
    },

    # ── TrustView extras ──
    "Adjust weights in Settings → Trust": {
        "pt-PT": "Ajusta os pesos em Definições → Confiança",
        "es": "Ajusta los pesos en Ajustes → Confianza",
        "fr": "Ajustez les pondérations dans Réglages → Confiance",
        "de": "Gewichtungen in Einstellungen → Vertrauen anpassen",
        "it": "Regola i pesi in Impostazioni → Affidabilità",
    },
    "Score breakdown": {
        "pt-PT": "Detalhe da pontuação",
        "es": "Desglose de puntuación",
        "fr": "Répartition du score",
        "de": "Punkte-Aufschlüsselung",
        "it": "Dettaglio punteggio",
    },
    "Trust audit": {
        "pt-PT": "Auditoria de confiança",
        "es": "Auditoría de confianza",
        "fr": "Audit de confiance",
        "de": "Vertrauensprüfung",
        "it": "Verifica di affidabilità",
    },

    # ── TorrentView ──
    "Load .torrent file…": {
        "pt-PT": "Carregar ficheiro .torrent…",
        "es": "Cargar archivo .torrent…",
        "fr": "Charger un fichier .torrent…",
        "de": ".torrent-Datei laden…",
        "it": "Carica file .torrent…",
    },
    "Parse": {
        "pt-PT": "Analisar",
        "es": "Analizar",
        "fr": "Analyser",
        "de": "Analysieren",
        "it": "Analizza",
    },
    "Start": {
        "pt-PT": "Iniciar",
        "es": "Iniciar",
        "fr": "Démarrer",
        "de": "Start",
        "it": "Avvia",
    },
    "Trackers": {
        "pt-PT": "Trackers",
        "es": "Trackers",
        "fr": "Trackers",
        "de": "Trackers",
        "it": "Tracker",
    },
    "Seed when complete": {
        "pt-PT": "Semear quando concluir",
        "es": "Sembrar al completar",
        "fr": "Partager une fois terminé",
        "de": "Beim Abschluss seeden",
        "it": "Distribuisci al completamento",
    },
    "Seed while leeching": {
        "pt-PT": "Semear durante a transferência",
        "es": "Sembrar mientras descarga",
        "fr": "Partager pendant le téléchargement",
        "de": "Während des Ladens seeden",
        "it": "Distribuisci durante il download",
    },

    # ── Misc ──
    "About Splynek": {
        "pt-PT": "Acerca do Splynek",
        "es": "Acerca de Splynek",
        "fr": "À propos de Splynek",
        "de": "Über Splynek",
        "it": "Info su Splynek",
    },
    "$29 one-time on the Mac App Store.": {
        "pt-PT": "$29 compra única na Mac App Store.",
        "es": "$29 pago único en la Mac App Store.",
        "fr": "$29 achat unique sur le Mac App Store.",
        "de": "$29 einmalig im Mac App Store.",
        "it": "$29 acquisto unico nel Mac App Store.",
    },

    # ── v1.6.2 round 2: next 40 strings (DownloadView labels +
    # tooltips, common Pro upsell, BenchmarkView buttons,
    # AgentsView accessibility labels). ──

    # Downloads — labels + state
    "Active downloads": {
        "pt-PT": "Transferências ativas",
        "es": "Descargas activas",
        "fr": "Téléchargements actifs",
        "de": "Aktive Downloads",
        "it": "Download attivi",
    },
    "Advanced": {
        "pt-PT": "Avançado",
        "es": "Avanzado",
        "fr": "Avancé",
        "de": "Erweitert",
        "it": "Avanzato",
    },
    "Custom HTTP headers": {
        "pt-PT": "Cabeçalhos HTTP personalizados",
        "es": "Cabeceras HTTP personalizadas",
        "fr": "En-têtes HTTP personnalisés",
        "de": "Benutzerdefinierte HTTP-Header",
        "it": "Intestazioni HTTP personalizzate",
    },
    "No custom headers — the request will use the defaults.": {
        "pt-PT": "Sem cabeçalhos personalizados — o pedido vai usar as predefinições.",
        "es": "Sin cabeceras personalizadas — la petición usará los valores por defecto.",
        "fr": "Aucun en-tête personnalisé — la requête utilisera les valeurs par défaut.",
        "de": "Keine benutzerdefinierten Header — die Anfrage verwendet die Standardwerte.",
        "it": "Nessuna intestazione personalizzata — la richiesta userà i valori predefiniti.",
    },
    "Daily cap": {
        "pt-PT": "Limite diário",
        "es": "Límite diario",
        "fr": "Limite quotidienne",
        "de": "Tageslimit",
        "it": "Limite giornaliero",
    },
    "Cellular used today": {
        "pt-PT": "Rede móvel usada hoje",
        "es": "Datos móviles usados hoy",
        "fr": "Données cellulaires utilisées aujourd'hui",
        "de": "Heute verwendete Mobildaten",
        "it": "Rete mobile usata oggi",
    },
    "Detached signature available": {
        "pt-PT": "Assinatura separada disponível",
        "es": "Firma separada disponible",
        "fr": "Signature détachée disponible",
        "de": "Separate Signatur verfügbar",
        "it": "Firma separata disponibile",
    },
    "Splynek found:": {
        "pt-PT": "O Splynek encontrou:",
        "es": "Splynek encontró:",
        "fr": "Splynek a trouvé :",
        "de": "Splynek hat gefunden:",
        "it": "Splynek ha trovato:",
    },
    "You already have this file": {
        "pt-PT": "Já tens este ficheiro",
        "es": "Ya tienes este archivo",
        "fr": "Vous avez déjà ce fichier",
        "de": "Sie haben diese Datei bereits",
        "it": "Hai già questo file",
    },
    "Unlock Pro — $29": {
        "pt-PT": "Desbloquear Pro — $29",
        "es": "Desbloquear Pro — $29",
        "fr": "Débloquer Pro — $29",
        "de": "Pro freischalten — $29",
        "it": "Sblocca Pro — $29",
    },
    "Load Metalink…": {
        "pt-PT": "Carregar Metalink…",
        "es": "Cargar Metalink…",
        "fr": "Charger Metalink…",
        "de": "Metalink laden…",
        "it": "Carica Metalink…",
    },
    "Load Merkle…": {
        "pt-PT": "Carregar Merkle…",
        "es": "Cargar Merkle…",
        "fr": "Charger Merkle…",
        "de": "Merkle laden…",
        "it": "Carica Merkle…",
    },
    "Reveal in Finder.": {
        "pt-PT": "Mostrar no Finder.",
        "es": "Mostrar en Finder.",
        "fr": "Afficher dans le Finder.",
        "de": "Im Finder anzeigen.",
        "it": "Mostra nel Finder.",
    },
    "How many parallel connections to open on each network interface.": {
        "pt-PT": "Quantas ligações paralelas abrir em cada interface de rede.",
        "es": "Cuántas conexiones paralelas abrir en cada interfaz de red.",
        "fr": "Combien de connexions parallèles ouvrir sur chaque interface réseau.",
        "de": "Wie viele parallele Verbindungen pro Netzwerkschnittstelle geöffnet werden.",
        "it": "Quante connessioni parallele aprire su ogni interfaccia di rete.",
    },
    "How many downloads Splynek will run in parallel.": {
        "pt-PT": "Quantas transferências o Splynek vai correr em paralelo.",
        "es": "Cuántas descargas ejecutará Splynek en paralelo.",
        "fr": "Combien de téléchargements Splynek exécutera en parallèle.",
        "de": "Wie viele Downloads Splynek parallel ausführt.",
        "it": "Quanti download Splynek eseguirà in parallelo.",
    },
    "Cancel every running download (⌘.).": {
        "pt-PT": "Cancelar todas as transferências em curso (⌘.).",
        "es": "Cancelar todas las descargas en curso (⌘.).",
        "fr": "Annuler tous les téléchargements en cours (⌘.).",
        "de": "Alle laufenden Downloads abbrechen (⌘.).",
        "it": "Annulla tutti i download in corso (⌘.).",
    },
    "Add to queue (⌘⇧Q). Runs when the current download finishes.": {
        "pt-PT": "Adicionar à fila (⌘⇧Q). Começa quando a transferência atual terminar.",
        "es": "Añadir a la cola (⌘⇧Q). Empieza cuando termine la descarga actual.",
        "fr": "Ajouter à la file (⌘⇧Q). Démarre quand le téléchargement actuel se termine.",
        "de": "Zur Warteschlange hinzufügen (⌘⇧Q). Startet, wenn der aktuelle Download fertig ist.",
        "it": "Aggiungi alla coda (⌘⇧Q). Parte quando il download attuale finisce.",
    },
    "Start download now (⏎). Pulls the URL across every selected interface in parallel.": {
        "pt-PT": "Iniciar transferência agora (⏎). Puxa o URL por todas as interfaces selecionadas em paralelo.",
        "es": "Iniciar descarga ahora (⏎). Tira de la URL por todas las interfaces seleccionadas en paralelo.",
        "fr": "Démarrer le téléchargement maintenant (⏎). Tire l'URL sur toutes les interfaces sélectionnées en parallèle.",
        "de": "Download jetzt starten (⏎). Lädt die URL parallel über alle ausgewählten Schnittstellen.",
        "it": "Avvia download ora (⏎). Preleva l'URL su tutte le interfacce selezionate in parallelo.",
    },
    "Copy a curl equivalent to the clipboard.": {
        "pt-PT": "Copiar um equivalente curl para a área de transferência.",
        "es": "Copiar un equivalente curl al portapapeles.",
        "fr": "Copier un équivalent curl dans le presse-papiers.",
        "de": "curl-Äquivalent in die Zwischenablage kopieren.",
        "it": "Copia un equivalente curl negli appunti.",
    },
    "Don't have one? Skip this — Splynek will still download the file, just without the extra integrity check.": {
        "pt-PT": "Não tens nenhuma? Salta isto — o Splynek transfere o ficheiro à mesma, só sem a verificação extra.",
        "es": "¿No tienes? Omite esto — Splynek descargará el archivo igualmente, solo sin la comprobación extra.",
        "fr": "Vous n'en avez pas ? Passez — Splynek téléchargera quand même le fichier, juste sans la vérification supplémentaire.",
        "de": "Keine zur Hand? Überspringen Sie — Splynek lädt die Datei trotzdem herunter, nur ohne die zusätzliche Integritätsprüfung.",
        "it": "Non ne hai? Salta — Splynek scaricherà comunque il file, solo senza il controllo extra.",
    },
    "Drop the mirror list and fall back to the single URL above.": {
        "pt-PT": "Largar a lista de espelhos e voltar ao URL único acima.",
        "es": "Soltar la lista de mirrors y volver a la URL única de arriba.",
        "fr": "Abandonner la liste des miroirs et revenir à l'URL unique ci-dessus.",
        "de": "Spiegel-Liste verwerfen und zur einzelnen URL oben zurückkehren.",
        "it": "Lascia l'elenco dei mirror e torna all'URL singolo sopra.",
    },
    "Drop the chunk-fingerprint file and fall back to end-of-file integrity check.": {
        "pt-PT": "Largar o ficheiro de impressão digital de fragmentos e voltar à verificação no fim do ficheiro.",
        "es": "Soltar el archivo de huellas digitales por fragmentos y volver a la comprobación al final del archivo.",
        "fr": "Abandonner le fichier d'empreintes par fragments et revenir à la vérification en fin de fichier.",
        "de": "Chunk-Fingerprint-Datei verwerfen und zur Integritätsprüfung am Dateiende zurückkehren.",
        "it": "Lascia il file di impronte per frammenti e torna al controllo a fine file.",
    },

    # AgentsView accessibility
    "Copy endpoint URL to clipboard": {
        "pt-PT": "Copiar URL do endpoint para a área de transferência",
        "es": "Copiar URL del endpoint al portapapeles",
        "fr": "Copier l'URL du point d'accès dans le presse-papiers",
        "de": "Endpunkt-URL in die Zwischenablage kopieren",
        "it": "Copia URL endpoint negli appunti",
    },
    "Copy setup snippet to clipboard": {
        "pt-PT": "Copiar snippet de configuração para a área de transferência",
        "es": "Copiar snippet de configuración al portapapeles",
        "fr": "Copier l'extrait de configuration dans le presse-papiers",
        "de": "Konfigurations-Snippet in die Zwischenablage kopieren",
        "it": "Copia snippet di configurazione negli appunti",
    },

    # BenchmarkView extras
    "Render a 1200×630 PNG for sharing on social media.": {
        "pt-PT": "Renderizar um PNG 1200×630 para partilhar em redes sociais.",
        "es": "Renderizar un PNG 1200×630 para compartir en redes sociales.",
        "fr": "Générer un PNG 1200×630 pour partager sur les réseaux sociaux.",
        "de": "Ein 1200×630 PNG zum Teilen in sozialen Netzwerken erstellen.",
        "it": "Renderizza un PNG 1200×630 per condividere sui social.",
    },
    "Copy a plain-text summary of the results to the clipboard.": {
        "pt-PT": "Copiar um resumo em texto simples dos resultados para a área de transferência.",
        "es": "Copiar un resumen en texto plano de los resultados al portapapeles.",
        "fr": "Copier un résumé en texte brut des résultats dans le presse-papiers.",
        "de": "Eine Klartext-Zusammenfassung der Ergebnisse in die Zwischenablage kopieren.",
        "it": "Copia un riepilogo in testo semplice dei risultati negli appunti.",
    },
    "Results below ↓": {
        "pt-PT": "Resultados em baixo ↓",
        "es": "Resultados abajo ↓",
        "fr": "Résultats ci-dessous ↓",
        "de": "Ergebnisse unten ↓",
        "it": "Risultati sotto ↓",
    },

    # Sidebar/About
    "About Splynek": {
        "pt-PT": "Acerca do Splynek",
        "es": "Acerca de Splynek",
        "fr": "À propos de Splynek",
        "de": "Über Splynek",
        "it": "Info su Splynek",
    },
}


def main():
    # Load existing catalog (preserves the de/es/fr/it work already done
    # on the original 56 strings).
    if CATALOG.exists():
        catalog = json.loads(CATALOG.read_text())
    else:
        catalog = {"sourceLanguage": "en", "version": "1.0", "strings": {}}

    # 1. Add pt-PT to existing strings.
    for key, pt_value in PT_PT_FOR_EXISTING.items():
        if key not in catalog["strings"]:
            # New key — initialize.
            catalog["strings"][key] = {"localizations": {}}
        loc = catalog["strings"][key].setdefault("localizations", {})
        loc["pt-PT"] = {
            "stringUnit": {"state": "translated", "value": pt_value}
        }

    # 2. Add new v1.6 strings with all 5 locales.
    for key, locales in NEW_V16_STRINGS.items():
        if key not in catalog["strings"]:
            catalog["strings"][key] = {"localizations": {}}
        loc = catalog["strings"][key].setdefault("localizations", {})
        for locale, value in locales.items():
            loc[locale] = {
                "stringUnit": {"state": "translated", "value": value}
            }

    # 3. Sort strings alphabetically by key for stable diffs.
    catalog["strings"] = dict(sorted(catalog["strings"].items()))

    # 4. Write back with Apple's pretty-print conventions
    #    (2-space indent, sorted keys at every level).
    CATALOG.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    )

    # 5. Report
    n_strings = len(catalog["strings"])
    locales = sorted(set(
        loc
        for entry in catalog["strings"].values()
        for loc in entry.get("localizations", {})
    ))
    print(f"✓ wrote {n_strings} strings across locales: {locales}")
    coverage = {loc: 0 for loc in locales}
    for entry in catalog["strings"].values():
        for loc in entry.get("localizations", {}):
            coverage[loc] += 1
    for loc in locales:
        pct = (coverage[loc] / n_strings * 100) if n_strings else 0
        print(f"  {loc}: {coverage[loc]}/{n_strings}  ({pct:.0f}%)")


if __name__ == "__main__":
    main()
