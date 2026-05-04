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
        "pt-PT": "moderado",
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
    # Raw strings (r"...") because the Swift \(...) interpolation reads
    # like a Python escape sequence and trips a SyntaxWarning otherwise.
    # The catalog still receives literal `\(...)` text at runtime.
    r"Downloading — \(Int(job.progress.fraction * 100))%": {
        # Pane title for one active download, e.g. "Downloading — 42%".
        # The `\()` interpolation is part of the LocalizedStringKey
        # itself; SwiftUI substitutes the integer at render time.
        "pt-PT": r"A transferir — \(Int(job.progress.fraction * 100))%",
        "es": r"Descargando — \(Int(job.progress.fraction * 100))%",
        "fr": r"Téléchargement — \(Int(job.progress.fraction * 100)) %",
        "de": r"Lädt — \(Int(job.progress.fraction * 100))%",
        "it": r"Scaricando — \(Int(job.progress.fraction * 100))%",
    },
    r"Downloading — \(running.count) active": {
        "pt-PT": r"A transferir — \(running.count) ativas",
        "es": r"Descargando — \(running.count) activas",
        "fr": r"Téléchargement — \(running.count) actifs",
        "de": r"Lädt — \(running.count) aktiv",
        "it": r"Scaricando — \(running.count) attivi",
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

    # ── v1.6.2 round 3: cross-tab labels (Live, Queue, Fleet,
    # History, Torrents) ── 30 high-frequency strings ──

    "No active downloads": {
        "pt-PT": "Sem transferências ativas",
        "es": "Sin descargas activas",
        "fr": "Aucun téléchargement actif",
        "de": "Keine aktiven Downloads",
        "it": "Nessun download attivo",
    },
    "Pause": {
        "pt-PT": "Pausar",
        "es": "Pausar",
        "fr": "Pause",
        "de": "Pause",
        "it": "Pausa",
    },
    "Resume": {
        "pt-PT": "Retomar",
        "es": "Reanudar",
        "fr": "Reprendre",
        "de": "Fortsetzen",
        "it": "Riprendi",
    },
    "Pause all": {
        "pt-PT": "Pausar tudo",
        "es": "Pausar todo",
        "fr": "Tout mettre en pause",
        "de": "Alle pausieren",
        "it": "Pausa tutto",
    },
    "Resume all": {
        "pt-PT": "Retomar tudo",
        "es": "Reanudar todo",
        "fr": "Tout reprendre",
        "de": "Alle fortsetzen",
        "it": "Riprendi tutto",
    },
    "Export…": {
        "pt-PT": "Exportar…",
        "es": "Exportar…",
        "fr": "Exporter…",
        "de": "Exportieren…",
        "it": "Esporta…",
    },
    "Export CSV": {
        "pt-PT": "Exportar CSV",
        "es": "Exportar CSV",
        "fr": "Exporter CSV",
        "de": "CSV exportieren",
        "it": "Esporta CSV",
    },
    "Export today + historical daily totals as CSV.": {
        "pt-PT": "Exportar totais diários de hoje + históricos como CSV.",
        "es": "Exportar totales diarios de hoy + históricos como CSV.",
        "fr": "Exporter les totaux quotidiens d'aujourd'hui + l'historique en CSV.",
        "de": "Heute + historische Tageszusammenfassungen als CSV exportieren.",
        "it": "Esporta i totali giornalieri di oggi + storici come CSV.",
    },
    "Export today + historical daily snapshots as CSV.": {
        "pt-PT": "Exportar instantâneos diários de hoje + históricos como CSV.",
        "es": "Exportar instantáneas diarias de hoy + históricas como CSV.",
        "fr": "Exporter les instantanés quotidiens d'aujourd'hui + historiques en CSV.",
        "de": "Heute + historische Tages-Snapshots als CSV exportieren.",
        "it": "Esporta gli snapshot giornalieri di oggi + storici come CSV.",
    },
    "Downloading now:": {
        "pt-PT": "A transferir agora:",
        "es": "Descargando ahora:",
        "fr": "Téléchargement en cours :",
        "de": "Aktuell ladend:",
        "it": "In download ora:",
    },
    "Nothing yet. Start a download — other Splyneks on this LAN will see it and can pull completed chunks from this Mac once they finish.": {
        "pt-PT": "Ainda nada. Inicia uma transferência — os outros Splyneks na rede local vão vê-la e podem puxar fragmentos completos deste Mac quando terminarem.",
        "es": "Aún no hay nada. Inicia una descarga — los demás Splyneks de esta red local la verán y podrán tirar de los fragmentos completados desde este Mac cuando terminen.",
        "fr": "Rien pour l'instant. Démarrez un téléchargement — les autres Splyneks de ce réseau local le verront et pourront récupérer les morceaux terminés depuis ce Mac une fois finis.",
        "de": "Noch nichts. Starten Sie einen Download — andere Splyneks im lokalen Netzwerk sehen ihn und können fertige Chunks von diesem Mac abrufen, wenn sie fertig sind.",
        "it": "Ancora niente. Avvia un download — gli altri Splynek su questa rete locale lo vedranno e potranno scaricare i frammenti completati da questo Mac al termine.",
    },
    "Evaluating signature…": {
        "pt-PT": "A avaliar assinatura…",
        "es": "Evaluando firma…",
        "fr": "Évaluation de la signature…",
        "de": "Signatur wird geprüft…",
        "it": "Valutando firma…",
    },
    "No per-interface data recorded for this download.": {
        "pt-PT": "Sem dados por interface registados para esta transferência.",
        "es": "Sin datos por interfaz registrados para esta descarga.",
        "fr": "Aucune donnée par interface enregistrée pour ce téléchargement.",
        "de": "Keine Daten pro Schnittstelle für diesen Download aufgezeichnet.",
        "it": "Nessun dato per interfaccia registrato per questo download.",
    },
    "Format": {
        "pt-PT": "Formato",
        "es": "Formato",
        "fr": "Format",
        "de": "Format",
        "it": "Formato",
    },
    "Once the download finishes, keep serving pieces to other peers.": {
        "pt-PT": "Quando a transferência terminar, continua a servir fragmentos a outros pares.",
        "es": "Cuando termine la descarga, sigue sirviendo fragmentos a otros pares.",
        "fr": "Une fois le téléchargement terminé, continue à servir des morceaux aux autres pairs.",
        "de": "Wenn der Download fertig ist, weiterhin Stücke an andere Peers ausliefern.",
        "it": "Quando il download finisce, continua a servire frammenti agli altri peer.",
    },
    "Serve completed pieces to other peers before the download finishes.": {
        "pt-PT": "Servir fragmentos concluídos a outros pares antes de a transferência terminar.",
        "es": "Servir fragmentos completados a otros pares antes de que termine la descarga.",
        "fr": "Servir les morceaux terminés aux autres pairs avant la fin du téléchargement.",
        "de": "Fertige Stücke an andere Peers ausliefern, bevor der Download abgeschlossen ist.",
        "it": "Servi frammenti completati ad altri peer prima del termine del download.",
    },
    "Open in Finder": {
        "pt-PT": "Mostrar no Finder",
        "es": "Mostrar en Finder",
        "fr": "Afficher dans le Finder",
        "de": "Im Finder anzeigen",
        "it": "Mostra nel Finder",
    },
    "Show in Finder": {
        "pt-PT": "Mostrar no Finder",
        "es": "Mostrar en Finder",
        "fr": "Afficher dans le Finder",
        "de": "Im Finder anzeigen",
        "it": "Mostra nel Finder",
    },
    "Recent downloads": {
        "pt-PT": "Transferências recentes",
        "es": "Descargas recientes",
        "fr": "Téléchargements récents",
        "de": "Letzte Downloads",
        "it": "Download recenti",
    },
    "All downloads": {
        "pt-PT": "Todas as transferências",
        "es": "Todas las descargas",
        "fr": "Tous les téléchargements",
        "de": "Alle Downloads",
        "it": "Tutti i download",
    },
    "Today": {
        "pt-PT": "Hoje",
        "es": "Hoy",
        "fr": "Aujourd'hui",
        "de": "Heute",
        "it": "Oggi",
    },
    "Yesterday": {
        "pt-PT": "Ontem",
        "es": "Ayer",
        "fr": "Hier",
        "de": "Gestern",
        "it": "Ieri",
    },
    "Earlier": {
        "pt-PT": "Anteriores",
        "es": "Anteriores",
        "fr": "Plus tôt",
        "de": "Früher",
        "it": "Precedenti",
    },
    "Pick a CDN-backed URL with `Accept-Ranges: bytes`. The default is Hetzner's 100 MB speed-test file.": {
        "pt-PT": "Escolhe um URL servido por CDN com `Accept-Ranges: bytes`. A predefinição é o ficheiro de teste de 100 MB da Hetzner.",
        "es": "Elige una URL servida por CDN con `Accept-Ranges: bytes`. Por defecto se usa el archivo de prueba de 100 MB de Hetzner.",
        "fr": "Choisissez une URL servie par CDN avec `Accept-Ranges: bytes`. Par défaut, le fichier de test de 100 Mo de Hetzner.",
        "de": "Wählen Sie eine CDN-bereitgestellte URL mit `Accept-Ranges: bytes`. Voreinstellung: Hetzners 100-MB-Speedtest-Datei.",
        "it": "Scegli un URL servito da CDN con `Accept-Ranges: bytes`. Predefinito: file di test da 100 MB di Hetzner.",
    },
    "Run the benchmark: single-path vs multi-path throughput across every selected interface (⏎).": {
        "pt-PT": "Executa a avaliação: débito de caminho único vs múltiplo em todas as interfaces selecionadas (⏎).",
        "es": "Ejecuta la prueba: ancho de banda de ruta única vs múltiple en todas las interfaces seleccionadas (⏎).",
        "fr": "Lance l'évaluation : débit chemin unique vs multi-chemin sur toutes les interfaces sélectionnées (⏎).",
        "de": "Benchmark ausführen: Einzelpfad- vs. Mehrpfad-Durchsatz über alle ausgewählten Schnittstellen (⏎).",
        "it": "Esegui il benchmark: throughput a percorso singolo vs multi-percorso su tutte le interfacce selezionate (⏎).",
    },
    "Connected to": {
        "pt-PT": "Ligado a",
        "es": "Conectado a",
        "fr": "Connecté à",
        "de": "Verbunden mit",
        "it": "Connesso a",
    },
    "Disconnected": {
        "pt-PT": "Desligado",
        "es": "Desconectado",
        "fr": "Déconnecté",
        "de": "Getrennt",
        "it": "Disconnesso",
    },
    "Failed": {
        "pt-PT": "Falhou",
        "es": "Falló",
        "fr": "Échec",
        "de": "Fehlgeschlagen",
        "it": "Fallito",
    },
    "Completed": {
        "pt-PT": "Concluído",
        "es": "Completado",
        "fr": "Terminé",
        "de": "Abgeschlossen",
        "it": "Completato",
    },
    "Cancelled": {
        "pt-PT": "Cancelado",
        "es": "Cancelado",
        "fr": "Annulé",
        "de": "Abgebrochen",
        "it": "Annullato",
    },
    "Paused": {
        "pt-PT": "Em pausa",
        "es": "En pausa",
        "fr": "En pause",
        "de": "Angehalten",
        "it": "In pausa",
    },
    "Running": {
        "pt-PT": "Em execução",
        "es": "En ejecución",
        "fr": "En cours",
        "de": "Läuft",
        "it": "In esecuzione",
    },
    "Queued": {
        "pt-PT": "Em fila",
        "es": "En cola",
        "fr": "En file d'attente",
        "de": "In Warteschlange",
        "it": "In coda",
    },
    "Verifying integrity…": {
        "pt-PT": "A verificar integridade…",
        "es": "Verificando integridad…",
        "fr": "Vérification de l'intégrité…",
        "de": "Integrität wird geprüft…",
        "it": "Verifica integrità…",
    },

    # ── v1.6.2 round 4: massive sweep covering screenshots from
    # 15-image review.  Settings cards, ContextCard subtitles,
    # state labels, bullets across Concierge / Recipes /
    # Sovereignty / Trust / Agents / History / Benchmark / Fleet /
    # Queue / Live / Torrents.  ──

    # ── Slider label (the yellow circle) ──
    "Trust / reputation": {
        "pt-PT": "Confiança / reputação",
        "es": "Confianza / reputación",
        "fr": "Confiance / réputation",
        "de": "Vertrauen / Reputation",
        "it": "Affidabilità / reputazione",
    },

    # ── ContextCard subtitles per tab ──
    "Integrations, background behaviour, web dashboard, and security controls. Nothing here phones home.": {
        "pt-PT": "Integrações, comportamento em segundo plano, painel web e controlos de segurança. Nada aqui contacta servidores externos.",
        "es": "Integraciones, comportamiento en segundo plano, panel web y controles de seguridad. Nada aquí contacta con servidores externos.",
        "fr": "Intégrations, comportement en arrière-plan, tableau de bord web et contrôles de sécurité. Rien ici ne contacte de serveurs externes.",
        "de": "Integrationen, Hintergrund-Verhalten, Web-Dashboard und Sicherheits-Kontrollen. Nichts hier kontaktiert externe Server.",
        "it": "Integrazioni, comportamento in background, dashboard web e controlli di sicurezza. Niente qui contatta server esterni.",
    },
    "Every completed download, searchable by filename, URL or host — and by natural language when a local LLM is available.": {
        "pt-PT": "Todas as transferências concluídas, pesquisáveis por nome do ficheiro, URL ou servidor — e por linguagem natural quando um LLM local está disponível.",
        "es": "Todas las descargas completadas, buscables por nombre de archivo, URL o host — y por lenguaje natural cuando hay un LLM local disponible.",
        "fr": "Tous les téléchargements terminés, recherchables par nom de fichier, URL ou hôte — et en langage naturel quand un LLM local est disponible.",
        "de": "Jeder abgeschlossene Download, durchsuchbar nach Dateiname, URL oder Host — und per natürlicher Sprache, wenn ein lokales LLM verfügbar ist.",
        "it": "Ogni download completato, cercabile per nome file, URL o host — e in linguaggio naturale quando è disponibile un LLM locale.",
    },
    "Measure single-path versus multi-path throughput against a CDN-backed URL. Real engine, real bytes — export the result as a shareable PNG.": {
        "pt-PT": "Mede o débito de caminho único versus múltiplo contra um URL servido por CDN. Motor real, bytes reais — exporta o resultado como PNG partilhável.",
        "es": "Mide el ancho de banda de ruta única frente a múltiple contra una URL servida por CDN. Motor real, bytes reales — exporta el resultado como PNG compartible.",
        "fr": "Mesure le débit chemin unique vs multi-chemin contre une URL servie par CDN. Moteur réel, octets réels — exporte le résultat en PNG partageable.",
        "de": "Misst den Einzelpfad- vs. Mehrpfad-Durchsatz gegen eine CDN-bereitgestellte URL. Echte Engine, echte Bytes — Ergebnis als teilbares PNG exportieren.",
        "it": "Misura il throughput a percorso singolo vs multi-percorso contro un URL servito da CDN. Motore reale, byte reali — esporta il risultato come PNG condivisibile.",
    },
    "Other Splynek Macs on your LAN, advertised over Bonjour. Shared files skip the internet — downloads go Mac-to-Mac at gigabit.": {
        "pt-PT": "Outros Macs com Splynek na tua rede local, anunciados via Bonjour. Os ficheiros partilhados saltam a Internet — as transferências vão Mac-a-Mac a velocidades gigabit.",
        "es": "Otros Macs con Splynek en tu red local, anunciados vía Bonjour. Los archivos compartidos se saltan internet — las descargas van Mac-a-Mac a gigabit.",
        "fr": "Autres Macs avec Splynek sur votre réseau local, annoncés via Bonjour. Les fichiers partagés sautent Internet — les téléchargements vont Mac-à-Mac à gigabit.",
        "de": "Andere Splynek-Macs in Ihrem lokalen Netzwerk, angekündigt über Bonjour. Geteilte Dateien überspringen das Internet — Downloads laufen Mac-zu-Mac mit Gigabit.",
        "it": "Altri Mac con Splynek sulla tua rete locale, annunciati via Bonjour. I file condivisi saltano Internet — i download vanno Mac-a-Mac a gigabit.",
    },
    "URLs waiting their turn. Splynek starts each one automatically when an active slot frees up.": {
        "pt-PT": "URLs à espera da vez. O Splynek inicia cada um automaticamente quando uma vaga ativa fica livre.",
        "es": "URLs esperando su turno. Splynek inicia cada una automáticamente cuando se libera un slot activo.",
        "fr": "URLs en attente de leur tour. Splynek démarre chacune automatiquement quand un emplacement actif se libère.",
        "de": "URLs warten auf ihren Platz. Splynek startet jede automatisch, sobald ein aktiver Slot frei wird.",
        "it": "URL in attesa del loro turno. Splynek avvia ognuna automaticamente quando si libera uno slot attivo.",
    },
    "What the engine is doing right now. One section per running download — throughput, interface breakdown, pipeline stage.": {
        "pt-PT": "O que o motor está a fazer agora. Uma secção por transferência em curso — débito, divisão por interface, fase do pipeline.",
        "es": "Lo que el motor está haciendo ahora. Una sección por descarga en curso — ancho de banda, desglose por interfaz, fase del pipeline.",
        "fr": "Ce que le moteur fait en ce moment. Une section par téléchargement en cours — débit, répartition par interface, étape du pipeline.",
        "de": "Was die Engine gerade tut. Ein Abschnitt pro laufendem Download — Durchsatz, Schnittstellen-Aufschlüsselung, Pipeline-Phase.",
        "it": "Cosa sta facendo il motore in questo momento. Una sezione per ogni download in corso — throughput, suddivisione per interfaccia, fase pipeline.",
    },
    "Native BitTorrent v1 + v2 + hybrid. Paste a magnet, load a .torrent, or pick a web-seed mirror. Integrity is verified per piece.": {
        "pt-PT": "BitTorrent v1 + v2 + híbrido nativo. Cola um magnet, carrega um .torrent ou escolhe um espelho web-seed. A integridade é verificada por fragmento.",
        "es": "BitTorrent v1 + v2 + híbrido nativo. Pega un magnet, carga un .torrent o elige un mirror web-seed. La integridad se verifica por fragmento.",
        "fr": "BitTorrent v1 + v2 + hybride natif. Collez un magnet, chargez un .torrent ou choisissez un miroir web-seed. L'intégrité est vérifiée par morceau.",
        "de": "Natives BitTorrent v1 + v2 + Hybrid. Magnet einfügen, .torrent laden oder Web-Seed-Spiegel wählen. Integrität wird pro Stück verifiziert.",
        "it": "BitTorrent v1 + v2 + ibrido nativo. Incolla un magnet, carica un .torrent o scegli un mirror web-seed. L'integrità è verificata per pezzo.",
    },

    # ── State labels + table headers ──
    "Lifetime": {"pt-PT": "Total", "es": "Total", "fr": "Total", "de": "Gesamt", "it": "Totale"},
    "DOWNLOADS": {"pt-PT": "TRANSFERÊNCIAS", "es": "DESCARGAS", "fr": "TÉLÉCHARGEMENTS", "de": "DOWNLOADS", "it": "DOWNLOAD"},
    "BYTES": {"pt-PT": "BYTES", "es": "BYTES", "fr": "OCTETS", "de": "BYTES", "it": "BYTE"},
    "AVG THROUGHPUT": {"pt-PT": "DÉBITO MÉDIO", "es": "ANCHO MEDIO", "fr": "DÉBIT MOYEN", "de": "Ø DURCHSATZ", "it": "VELOCITÀ MEDIA"},
    "TIME SAVED": {"pt-PT": "TEMPO POUPADO", "es": "TIEMPO AHORRADO", "fr": "TEMPS GAGNÉ", "de": "ZEIT GESPART", "it": "TEMPO RISPARMIATO"},
    "Usage timeline": {"pt-PT": "Linha temporal de uso", "es": "Línea de uso", "fr": "Chronologie d'usage", "de": "Nutzungs-Zeitleiste", "it": "Cronologia uso"},
    "Host": {"pt-PT": "Anfitrião", "es": "Anfitrión", "fr": "Hôte", "de": "Host", "it": "Host"},
    "Cellular": {"pt-PT": "Móvel", "es": "Móvil", "fr": "Cellulaire", "de": "Mobilfunk", "it": "Cellulare"},
    "Recent": {"pt-PT": "Recentes", "es": "Recientes", "fr": "Récents", "de": "Neueste", "it": "Recenti"},
    "Search by filename, URL, or host": {
        "pt-PT": "Pesquisar por nome do ficheiro, URL ou anfitrião",
        "es": "Buscar por nombre de archivo, URL o host",
        "fr": "Rechercher par nom de fichier, URL ou hôte",
        "de": "Nach Dateiname, URL oder Host suchen",
        "it": "Cerca per nome file, URL o host",
    },
    "14 days": {"pt-PT": "14 dias", "es": "14 días", "fr": "14 jours", "de": "14 Tage", "it": "14 giorni"},

    # ── Benchmark tab ──
    "Benchmark target": {"pt-PT": "Alvo da avaliação", "es": "Objetivo de la prueba", "fr": "Cible de l'évaluation", "de": "Benchmark-Ziel", "it": "Target del benchmark"},
    "Interfaces in play": {"pt-PT": "Interfaces em uso", "es": "Interfaces en juego", "fr": "Interfaces en jeu", "de": "Beteiligte Schnittstellen", "it": "Interfacce in uso"},
    "What this measures": {"pt-PT": "O que isto mede", "es": "Qué mide esto", "fr": "Ce que cela mesure", "de": "Was dies misst", "it": "Cosa misura"},
    "Splynek downloads the target URL through each interface individually, then through all of them aggregated. Temp files are placed in /tmp/ and deleted after each probe, so the benchmark touches only network + CPU. The multi-path number is the real-world aggregate using keep-alive HTTP/1.1 lanes bound via IP_BOUND_IF.": {
        "pt-PT": "O Splynek transfere o URL alvo por cada interface individualmente e depois por todas agregadas. Os ficheiros temporários ficam em /tmp/ e são apagados após cada teste, por isso a avaliação toca apenas rede + CPU. O número multi-caminho é o agregado real usando vias HTTP/1.1 keep-alive vinculadas via IP_BOUND_IF.",
        "es": "Splynek descarga la URL objetivo por cada interfaz individualmente, luego por todas agregadas. Los archivos temp van a /tmp/ y se borran después de cada prueba, así que la prueba solo toca red + CPU. El número multi-ruta es el agregado real usando carriles HTTP/1.1 keep-alive vinculados vía IP_BOUND_IF.",
        "fr": "Splynek télécharge l'URL cible via chaque interface individuellement, puis via toutes agrégées. Les fichiers temp vont dans /tmp/ et sont supprimés après chaque sonde, donc l'évaluation touche seulement réseau + CPU. Le nombre multi-chemin est l'agrégat réel utilisant des canaux HTTP/1.1 keep-alive liés via IP_BOUND_IF.",
        "de": "Splynek lädt die Ziel-URL über jede Schnittstelle einzeln herunter, dann über alle aggregiert. Temp-Dateien landen in /tmp/ und werden nach jeder Sonde gelöscht; der Benchmark berührt also nur Netzwerk + CPU. Die Mehrpfad-Zahl ist der reale Aggregatwert mit HTTP/1.1-keep-alive-Spuren via IP_BOUND_IF.",
        "it": "Splynek scarica l'URL target attraverso ogni interfaccia individualmente, poi attraverso tutte aggregate. I file temp vanno in /tmp/ e sono cancellati dopo ogni sonda, quindi il benchmark tocca solo rete + CPU. Il numero multi-percorso è l'aggregato reale usando corsie HTTP/1.1 keep-alive associate via IP_BOUND_IF.",
    },

    # ── Fleet tab ──
    "This Mac": {"pt-PT": "Este Mac", "es": "Este Mac", "fr": "Ce Mac", "de": "Dieser Mac", "it": "Questo Mac"},
    "ADVERTISED": {"pt-PT": "ANUNCIADO", "es": "ANUNCIADO", "fr": "ANNONCÉ", "de": "ANGEKÜNDIGT", "it": "ANNUNCIATO"},
    "DEVICE ID": {"pt-PT": "ID DO DISPOSITIVO", "es": "ID DEL DISPOSITIVO", "fr": "ID DE L'APPAREIL", "de": "GERÄTE-ID", "it": "ID DISPOSITIVO"},
    "PORT": {"pt-PT": "PORTA", "es": "PUERTO", "fr": "PORT", "de": "PORT", "it": "PORTA"},
    "ACTIVE": {"pt-PT": "ATIVOS", "es": "ACTIVOS", "fr": "ACTIFS", "de": "AKTIV", "it": "ATTIVI"},
    "SHAREABLE": {"pt-PT": "PARTILHÁVEIS", "es": "COMPARTIBLES", "fr": "PARTAGEABLES", "de": "TEILBAR", "it": "CONDIVISIBILI"},
    "HASHED": {"pt-PT": "HASHED", "es": "HASHED", "fr": "HASHED", "de": "HASHED", "it": "HASHED"},
    "NAME": {"pt-PT": "NOME", "es": "NOMBRE", "fr": "NOM", "de": "NAME", "it": "NOME"},
    "Peers on this LAN": {"pt-PT": "Pares nesta rede local", "es": "Pares en esta red local", "fr": "Pairs sur ce réseau local", "de": "Peers in diesem lokalen Netzwerk", "it": "Peer su questa rete locale"},
    "No other Splynek Macs found": {"pt-PT": "Não foram encontrados outros Macs com Splynek", "es": "No se encontraron otros Macs con Splynek", "fr": "Aucun autre Mac Splynek trouvé", "de": "Keine anderen Splynek-Macs gefunden", "it": "Nessun altro Mac Splynek trovato"},
    "Fleet advertises every Splynek install on this network over Bonjour. Anything else with Splynek open will show up here and can lend completed downloads to this Mac.": {
        "pt-PT": "A Frota anuncia cada instalação do Splynek nesta rede via Bonjour. Qualquer outra coisa com o Splynek aberto vai aparecer aqui e pode emprestar transferências concluídas a este Mac.",
        "es": "Flota anuncia cada instalación de Splynek en esta red vía Bonjour. Cualquier otra cosa con Splynek abierto aparecerá aquí y puede prestar descargas completadas a este Mac.",
        "fr": "Flotte annonce chaque installation Splynek sur ce réseau via Bonjour. Tout autre Splynek ouvert apparaîtra ici et peut prêter des téléchargements terminés à ce Mac.",
        "de": "Flotte meldet jede Splynek-Installation in diesem Netzwerk über Bonjour. Jedes andere geöffnete Splynek erscheint hier und kann fertige Downloads an diesen Mac verleihen.",
        "it": "Flotta annuncia ogni installazione Splynek su questa rete via Bonjour. Qualsiasi altro Splynek aperto apparirà qui e può prestare download completati a questo Mac.",
    },
    "What this Mac is sharing": {"pt-PT": "O que este Mac está a partilhar", "es": "Qué está compartiendo este Mac", "fr": "Ce que ce Mac partage", "de": "Was dieser Mac teilt", "it": "Cosa sta condividendo questo Mac"},
    "Nothing yet. Start a download — other Splyneks on this LAN will see it and can pull completed chunks from this Mac once they land on disk.": {
        "pt-PT": "Ainda nada. Inicia uma transferência — outros Splyneks nesta rede local vão vê-la e podem puxar fragmentos concluídos deste Mac assim que chegarem ao disco.",
        "es": "Aún nada. Inicia una descarga — otros Splyneks en esta red local la verán y podrán tirar fragmentos completados desde este Mac cuando lleguen al disco.",
        "fr": "Rien pour l'instant. Démarrez un téléchargement — les autres Splyneks de ce réseau local le verront et pourront récupérer les morceaux terminés depuis ce Mac dès qu'ils atteindront le disque.",
        "de": "Noch nichts. Starten Sie einen Download — andere Splyneks im lokalen Netzwerk sehen ihn und können fertige Chunks von diesem Mac abrufen, sobald sie auf der Festplatte landen.",
        "it": "Ancora niente. Avvia un download — gli altri Splynek su questa rete locale lo vedranno e potranno scaricare frammenti completati da questo Mac appena arrivano sul disco.",
    },

    # ── Queue tab ──
    "Queue is empty": {"pt-PT": "Fila vazia", "es": "Cola vacía", "fr": "File vide", "de": "Warteschlange ist leer", "it": "Coda vuota"},
    "Add a URL to the queue from the Downloads tab — Splynek will run it when the current download finishes.": {
        "pt-PT": "Adiciona um URL à fila a partir do separador Transferências — o Splynek executa-o quando a transferência atual terminar.",
        "es": "Añade una URL a la cola desde la pestaña Descargas — Splynek la ejecutará cuando termine la descarga actual.",
        "fr": "Ajoutez une URL à la file depuis l'onglet Téléchargements — Splynek l'exécutera quand le téléchargement actuel se terminera.",
        "de": "Fügen Sie eine URL aus dem Downloads-Tab zur Warteschlange hinzu — Splynek führt sie aus, wenn der aktuelle Download fertig ist.",
        "it": "Aggiungi un URL alla coda dalla scheda Download — Splynek lo eseguirà quando il download attuale finisce.",
    },
    "Start one from the Downloads tab or the Assistant, and it'll show up here in real time.": {
        "pt-PT": "Inicia uma a partir do separador Transferências ou do Assistente e aparece aqui em tempo real.",
        "es": "Inicia una desde la pestaña Descargas o el Asistente, y aparecerá aquí en tiempo real.",
        "fr": "Démarrez-en un depuis l'onglet Téléchargements ou l'Assistant, et il apparaîtra ici en temps réel.",
        "de": "Starten Sie einen aus dem Downloads-Tab oder dem Assistenten, und er erscheint hier in Echtzeit.",
        "it": "Avviane uno dalla scheda Download o dall'Assistente e apparirà qui in tempo reale.",
    },

    # ── Concierge free-tier bullets ──
    "Talk to Splynek in plain English": {
        "pt-PT": "Fala com o Splynek em linguagem natural",
        "es": "Habla con Splynek en lenguaje natural",
        "fr": "Parlez à Splynek en langage naturel",
        "de": "Mit Splynek in natürlicher Sprache reden",
        "it": "Parla con Splynek in linguaggio naturale",
    },
    "Chat-routed downloads, queue, cancellations, pauses": {
        "pt-PT": "Transferências, fila, cancelamentos e pausas via chat",
        "es": "Descargas, cola, cancelaciones y pausas vía chat",
        "fr": "Téléchargements, file, annulations et pauses via chat",
        "de": "Downloads, Warteschlange, Abbrüche und Pausen per Chat",
        "it": "Download, coda, annullamenti e pause via chat",
    },
    "Natural-language search of your download history": {
        "pt-PT": "Pesquisa em linguagem natural no histórico de transferências",
        "es": "Búsqueda en lenguaje natural del historial de descargas",
        "fr": "Recherche en langage naturel dans l'historique de téléchargement",
        "de": "Sprachsuche in Ihrem Download-Verlauf",
        "it": "Ricerca in linguaggio naturale nella cronologia dei download",
    },
    "100% local LLM (LM Studio or Ollama) — no cloud, no account": {
        "pt-PT": "LLM 100% local (LM Studio ou Ollama) — sem cloud, sem conta",
        "es": "LLM 100% local (LM Studio u Ollama) — sin nube, sin cuenta",
        "fr": "LLM 100% local (LM Studio ou Ollama) — pas de cloud, pas de compte",
        "de": "100% lokales LLM (LM Studio oder Ollama) — keine Cloud, kein Konto",
        "it": "LLM 100% locale (LM Studio o Ollama) — niente cloud, niente account",
    },

    # ── Recipes free-tier bullets ──
    "Type a goal like \"set up my Mac for iOS dev\"": {
        "pt-PT": "Escreve um objetivo como \"configurar o meu Mac para desenvolvimento iOS\"",
        "es": "Escribe un objetivo como \"configurar mi Mac para desarrollo iOS\"",
        "fr": "Tapez un objectif comme \"configurer mon Mac pour le développement iOS\"",
        "de": "Tippen Sie ein Ziel ein wie \"Mac für iOS-Entwicklung einrichten\"",
        "it": "Scrivi un obiettivo come \"configura il mio Mac per sviluppo iOS\"",
    },
    "The local LLM proposes each download with URL + rationale": {
        "pt-PT": "O LLM local propõe cada transferência com URL + justificação",
        "es": "El LLM local propone cada descarga con URL + justificación",
        "fr": "Le LLM local propose chaque téléchargement avec URL + justification",
        "de": "Das lokale LLM schlägt jeden Download mit URL + Begründung vor",
        "it": "L'LLM locale propone ogni download con URL + motivazione",
    },
    "Review, uncheck, and queue the whole batch in one click": {
        "pt-PT": "Revê, desmarca e enfileira o lote inteiro com um clique",
        "es": "Revisa, desmarca y pon en cola el lote entero con un clic",
        "fr": "Examinez, décochez et mettez en file tout le lot en un clic",
        "de": "Prüfen, abwählen und das ganze Paket mit einem Klick in die Warteschlange",
        "it": "Rivedi, deseleziona e accoda l'intero lotto con un clic",
    },
    "24 themed starter goals across 6 categories": {
        "pt-PT": "24 objetivos temáticos iniciais em 6 categorias",
        "es": "24 objetivos temáticos iniciales en 6 categorías",
        "fr": "24 objectifs thématiques de démarrage dans 6 catégories",
        "de": "24 thematische Start-Ziele in 6 Kategorien",
        "it": "24 obiettivi tematici iniziali in 6 categorie",
    },

    # ── Settings: large card descriptions + titles ──
    "Splynek Pro (Mac App Store) — AI features aren't in the free build.": {
        "pt-PT": "Splynek Pro (Mac App Store) — as funcionalidades de IA não estão na versão gratuita.",
        "es": "Splynek Pro (Mac App Store) — las funciones de IA no están en la versión gratuita.",
        "fr": "Splynek Pro (Mac App Store) — les fonctions IA ne sont pas dans la version gratuite.",
        "de": "Splynek Pro (Mac App Store) — KI-Funktionen sind nicht in der kostenlosen Version.",
        "it": "Splynek Pro (Mac App Store) — le funzioni IA non sono nella versione gratuita.",
    },
    "Unlock the AI Concierge, AI-powered history search, scheduled downloads, and phone-accessible LAN dashboard. One-time $29; lifetime 0.x updates.": {
        "pt-PT": "Desbloqueia o Concierge IA, pesquisa de histórico com IA, transferências agendadas e painel acessível pelo telemóvel via rede local. Compra única $29; atualizações 0.x para sempre.",
        "es": "Desbloquea el Concierge IA, búsqueda de historial con IA, descargas programadas y panel accesible desde el teléfono vía red local. Compra única $29; actualizaciones 0.x de por vida.",
        "fr": "Débloquez le Concierge IA, recherche d'historique IA, téléchargements planifiés et tableau de bord accessible par téléphone via réseau local. Achat unique $29 ; mises à jour 0.x à vie.",
        "de": "Schalten Sie KI-Concierge, KI-Verlaufssuche, geplante Downloads und vom Telefon zugängliches Dashboard über lokales Netzwerk frei. Einmaliger Kauf $29; lebenslange 0.x-Updates.",
        "it": "Sblocca il Concierge IA, ricerca cronologia con IA, download programmati e dashboard accessibile dal telefono via rete locale. Acquisto unico $29; aggiornamenti 0.x a vita.",
    },
    "Get Splynek Pro on the Mac App Store": {
        "pt-PT": "Obter o Splynek Pro na Mac App Store",
        "es": "Obtener Splynek Pro en la Mac App Store",
        "fr": "Obtenir Splynek Pro sur le Mac App Store",
        "de": "Splynek Pro im Mac App Store holen",
        "it": "Scarica Splynek Pro dal Mac App Store",
    },
    "Splynek Pro is available only in the Mac App Store build. The free DMG build has the full download engine — torrents, multi-interface HTTP, everything non-AI.": {
        "pt-PT": "O Splynek Pro só está disponível na versão da Mac App Store. A versão DMG gratuita tem o motor de transferências completo — torrents, HTTP multi-interface, tudo o que não envolve IA.",
        "es": "Splynek Pro solo está disponible en la versión de Mac App Store. La versión DMG gratuita tiene el motor de descargas completo — torrents, HTTP multi-interfaz, todo lo no-IA.",
        "fr": "Splynek Pro est disponible uniquement dans la version Mac App Store. La version DMG gratuite a le moteur de téléchargement complet — torrents, HTTP multi-interfaces, tout sauf l'IA.",
        "de": "Splynek Pro ist nur in der Mac-App-Store-Version verfügbar. Die kostenlose DMG-Version hat die vollständige Download-Engine — Torrents, Multi-Schnittstellen-HTTP, alles außer KI.",
        "it": "Splynek Pro è disponibile solo nella versione Mac App Store. La versione DMG gratuita ha il motore di download completo — torrent, HTTP multi-interfaccia, tutto tranne l'IA.",
    },
    "Browser helpers": {"pt-PT": "Auxiliares de navegador", "es": "Auxiliares de navegador", "fr": "Assistants navigateur", "de": "Browser-Helfer", "it": "Aiuti per browser"},
    "Mobile web dashboard": {"pt-PT": "Painel web móvel", "es": "Panel web móvil", "fr": "Tableau de bord mobile", "de": "Mobiles Web-Dashboard", "it": "Dashboard web mobile"},
    "Splynek Pro feature": {"pt-PT": "Funcionalidade Splynek Pro", "es": "Función Splynek Pro", "fr": "Fonctionnalité Splynek Pro", "de": "Splynek Pro-Funktion", "it": "Funzione Splynek Pro"},
    "Let your phone submit downloads to this Mac over the LAN — QR pairing, live progress, token-gated submit. Free tier runs the dashboard loopback-only; Pro opens it to the LAN.": {
        "pt-PT": "Deixa o teu telemóvel enviar transferências para este Mac via rede local — emparelhamento QR, progresso ao vivo, envio com token. A versão gratuita corre o painel apenas em loopback; o Pro abre-o à rede local.",
        "es": "Deja que tu teléfono envíe descargas a este Mac vía red local — emparejamiento QR, progreso en vivo, envío con token. La versión gratuita ejecuta el panel solo en loopback; Pro lo abre a la red local.",
        "fr": "Laissez votre téléphone soumettre des téléchargements à ce Mac via le réseau local — appairage QR, progression en direct, soumission avec jeton. La version gratuite exécute le tableau de bord en boucle locale uniquement ; Pro l'ouvre au réseau local.",
        "de": "Lassen Sie Ihr Telefon Downloads über das lokale Netzwerk an diesen Mac senden — QR-Pairing, Live-Fortschritt, Token-Übergabe. Die kostenlose Version läuft nur im Loopback; Pro öffnet sie für das lokale Netzwerk.",
        "it": "Lascia che il tuo telefono invii download a questo Mac via rete locale — abbinamento QR, progresso in diretta, invio con token. La versione gratuita esegue la dashboard solo in loopback; Pro la apre alla rete locale.",
    },
    "Local AI assistant": {"pt-PT": "Assistente de IA local", "es": "Asistente IA local", "fr": "Assistant IA local", "de": "Lokaler KI-Assistent", "it": "Assistente IA locale"},
    "Download schedule": {"pt-PT": "Agendamento de transferências", "es": "Programación de descargas", "fr": "Planification des téléchargements", "de": "Download-Zeitplan", "it": "Pianificazione download"},
    "Watched folder": {"pt-PT": "Pasta vigiada", "es": "Carpeta vigilada", "fr": "Dossier surveillé", "de": "Überwachter Ordner", "it": "Cartella monitorata"},
    "Drop `.txt` (one URL per line), `.torrent`, or `.metalink` files here. Splynek queues each new file within 5 seconds, then moves it to a `processed/` subfolder.": {
        "pt-PT": "Larga aqui ficheiros `.txt` (um URL por linha), `.torrent` ou `.metalink`. O Splynek enfileira cada ficheiro novo em 5 segundos e depois move-o para a subpasta `processed/`.",
        "es": "Suelta aquí archivos `.txt` (una URL por línea), `.torrent` o `.metalink`. Splynek pone en cola cada nuevo archivo en 5 segundos y luego lo mueve a la subcarpeta `processed/`.",
        "fr": "Déposez ici des fichiers `.txt` (une URL par ligne), `.torrent` ou `.metalink`. Splynek met en file chaque nouveau fichier en 5 secondes, puis le déplace dans le sous-dossier `processed/`.",
        "de": "Legen Sie hier `.txt`- (eine URL pro Zeile), `.torrent`- oder `.metalink`-Dateien ab. Splynek stellt jede neue Datei innerhalb von 5 Sekunden in die Warteschlange und verschiebt sie dann in den Unterordner `processed/`.",
        "it": "Trascina qui file `.txt` (un URL per riga), `.torrent` o `.metalink`. Splynek mette in coda ogni nuovo file entro 5 secondi, poi lo sposta nella sottocartella `processed/`.",
    },
    "Polled every 5 s. `# comments` and blank lines in .txt files are ignored.": {
        "pt-PT": "Verificada de 5 em 5 s. Comentários `# ...` e linhas em branco em ficheiros .txt são ignorados.",
        "es": "Sondeada cada 5 s. Los comentarios `# ...` y las líneas en blanco en archivos .txt se ignoran.",
        "fr": "Sondé toutes les 5 s. Les commentaires `# ...` et les lignes vides dans les fichiers .txt sont ignorés.",
        "de": "Alle 5 s abgefragt. `# Kommentare` und leere Zeilen in .txt-Dateien werden ignoriert.",
        "it": "Sondata ogni 5 s. I commenti `# ...` e le righe vuote nei file .txt vengono ignorati.",
    },
    "Background mode": {"pt-PT": "Modo em segundo plano", "es": "Modo en segundo plano", "fr": "Mode arrière-plan", "de": "Hintergrund-Modus", "it": "Modalità background"},
    "Hide the dock icon and/or launch Splynek when you log in.": {
        "pt-PT": "Esconde o ícone do Dock e/ou inicia o Splynek quando inicias sessão.",
        "es": "Oculta el icono del Dock y/o inicia Splynek al iniciar sesión.",
        "fr": "Masquez l'icône du Dock et/ou lancez Splynek à la connexion.",
        "de": "Dock-Symbol ausblenden und/oder Splynek beim Anmelden starten.",
        "it": "Nascondi l'icona del Dock e/o avvia Splynek all'accesso.",
    },
    "Click the menu bar icon or press ⌘⇧D to surface the main window.": {
        "pt-PT": "Clica no ícone da barra de menus ou prime ⌘⇧D para mostrar a janela principal.",
        "es": "Haz clic en el icono de la barra de menú o pulsa ⌘⇧D para mostrar la ventana principal.",
        "fr": "Cliquez sur l'icône de la barre de menus ou appuyez sur ⌘⇧D pour afficher la fenêtre principale.",
        "de": "Klicken Sie auf das Menüleisten-Symbol oder drücken Sie ⌘⇧D, um das Hauptfenster anzuzeigen.",
        "it": "Fai clic sull'icona della barra dei menu o premi ⌘⇧D per mostrare la finestra principale.",
    },
    "Unavailable: Move Splynek to /Applications first, then toggle this on.": {
        "pt-PT": "Indisponível: move primeiro o Splynek para /Applications e depois ativa esta opção.",
        "es": "No disponible: mueve primero Splynek a /Applications y luego activa esta opción.",
        "fr": "Indisponible : déplacez d'abord Splynek vers /Applications, puis activez cette option.",
        "de": "Nicht verfügbar: Verschieben Sie Splynek zuerst nach /Applications und aktivieren Sie dann diese Option.",
        "it": "Non disponibile: sposta prima Splynek in /Applications, poi attiva questa opzione.",
    },
    "Adjust how the Trust tab weighs each axis when scoring your installed apps.  A user who cares mostly about privacy can dial security down — the underlying concerns don't change, only the score that summarises them.  Defaults: security 1.5, privacy 1.0, trust 1.0, business model 0.6.": {
        "pt-PT": "Ajusta como o separador Confiança pesa cada eixo ao pontuar as tuas apps instaladas. Quem se preocupa mais com privacidade pode reduzir a segurança — as preocupações subjacentes não mudam, só a pontuação que as resume. Predefinições: segurança 1.5, privacidade 1.0, confiança 1.0, modelo de negócio 0.6.",
        "es": "Ajusta cómo la pestaña Confianza pondera cada eje al puntuar tus apps instaladas. Quien se preocupa sobre todo por la privacidad puede bajar la seguridad — las preocupaciones subyacentes no cambian, solo la puntuación que las resume. Por defecto: seguridad 1.5, privacidad 1.0, confianza 1.0, modelo de negocio 0.6.",
        "fr": "Ajustez comment l'onglet Confiance pondère chaque axe lors de l'évaluation de vos apps installées. Un utilisateur qui se soucie surtout de la confidentialité peut diminuer la sécurité — les préoccupations sous-jacentes ne changent pas, seule la note qui les résume. Par défaut : sécurité 1.5, confidentialité 1.0, confiance 1.0, modèle économique 0.6.",
        "de": "Passen Sie an, wie der Vertrauen-Tab jede Achse bei der Bewertung Ihrer installierten Apps gewichtet. Wer sich vor allem um Datenschutz sorgt, kann Sicherheit zurückdrehen — die zugrundeliegenden Bedenken ändern sich nicht, nur die Bewertung, die sie zusammenfasst. Standard: Sicherheit 1.5, Datenschutz 1.0, Vertrauen 1.0, Geschäftsmodell 0.6.",
        "it": "Regola come la scheda Affidabilità pesa ogni asse nel valutare le tue app installate. Chi si preoccupa soprattutto della privacy può abbassare la sicurezza — le preoccupazioni sottostanti non cambiano, solo il punteggio che le riassume. Predefiniti: sicurezza 1.5, privacy 1.0, affidabilità 1.0, modello di business 0.6.",
    },
    "Security & privacy": {"pt-PT": "Segurança e privacidade", "es": "Seguridad y privacidad", "fr": "Sécurité et confidentialité", "de": "Sicherheit & Datenschutz", "it": "Sicurezza e privacy"},
    "Controls over what the LAN can see and who can submit downloads to this Mac.": {
        "pt-PT": "Controlos sobre o que a rede local consegue ver e quem pode enviar transferências para este Mac.",
        "es": "Controles sobre lo que la red local puede ver y quién puede enviar descargas a este Mac.",
        "fr": "Contrôles sur ce que le réseau local peut voir et qui peut soumettre des téléchargements à ce Mac.",
        "de": "Steuerungen darüber, was das lokale Netzwerk sehen kann und wer Downloads an diesen Mac senden darf.",
        "it": "Controlli su cosa la rete locale può vedere e chi può inviare download a questo Mac.",
    },
    "Rate limit: 60 req / 10 s per remote IP.": {
        "pt-PT": "Limite de taxa: 60 pedidos / 10 s por IP remoto.",
        "es": "Límite de tasa: 60 peticiones / 10 s por IP remota.",
        "fr": "Limite de débit : 60 requêtes / 10 s par IP distante.",
        "de": "Rate-Limit: 60 Anfragen / 10 s pro Remote-IP.",
        "it": "Limite di tasso: 60 richieste / 10 s per IP remoto.",
    },

    # ── Sovereignty bullets (also used by privacyRow code path) ──
    # (Already in catalog.)

    # ── Agents tab privacy bullets ──
    "Off by default. The toggle above is the only way in.": {
        "pt-PT": "Desligado por predefinição. O interruptor acima é a única forma de entrar.",
        "es": "Desactivado por defecto. El interruptor de arriba es la única forma de entrar.",
        "fr": "Désactivé par défaut. Le commutateur ci-dessus est la seule façon d'entrer.",
        "de": "Standardmäßig aus. Der Schalter oben ist der einzige Weg hinein.",
        "it": "Disattivato per impostazione predefinita. L'interruttore sopra è l'unico modo per entrare.",
    },
    "No new sandbox entitlements. The MCP route reuses the existing local-network listener that powers Splynek's web dashboard.": {
        "pt-PT": "Sem novos privilégios de sandbox. A rota MCP reutiliza o ouvinte de rede local que já alimenta o painel web do Splynek.",
        "es": "Sin nuevos permisos de sandbox. La ruta MCP reutiliza el listener de red local existente que impulsa el panel web de Splynek.",
        "fr": "Aucune nouvelle autorisation sandbox. La route MCP réutilise l'écouteur de réseau local existant qui alimente le tableau de bord web de Splynek.",
        "de": "Keine neuen Sandbox-Berechtigungen. Die MCP-Route nutzt den bestehenden Local-Network-Listener, der Splyneks Web-Dashboard antreibt.",
        "it": "Nessun nuovo permesso sandbox. Il percorso MCP riutilizza il listener di rete locale esistente che alimenta la dashboard web di Splynek.",
    },
    "Mutating tools (download / queue / cancel) route through the same ingest path as drag-drop and the browser extension. Every scheme guard, size confirmation, and host cap still fires.": {
        "pt-PT": "Ferramentas que modificam estado (transferir / enfileirar / cancelar) seguem o mesmo caminho de ingestão que o arrastar-e-largar e a extensão do navegador. Todas as proteções de esquema, confirmações de tamanho e limites por servidor continuam a disparar.",
        "es": "Las herramientas que modifican estado (descargar / encolar / cancelar) siguen la misma ruta de ingesta que arrastrar-y-soltar y la extensión del navegador. Todas las protecciones de esquema, confirmaciones de tamaño y límites por host siguen activándose.",
        "fr": "Les outils modificateurs (télécharger / mettre en file / annuler) passent par le même chemin d'ingestion que le glisser-déposer et l'extension navigateur. Toutes les protections de schéma, confirmations de taille et limites par hôte se déclenchent toujours.",
        "de": "Verändernde Werkzeuge (download / queue / cancel) durchlaufen denselben Aufnahmepfad wie Drag-Drop und die Browser-Erweiterung. Alle Schema-Schutzmechanismen, Größen-Bestätigungen und Host-Limits feuern weiterhin.",
        "it": "Gli strumenti che modificano lo stato (scarica / accoda / annulla) seguono lo stesso percorso di ingestione di trascina-e-rilascia e dell'estensione browser. Tutte le protezioni di schema, conferme di dimensione e limiti per host continuano a scattare.",
    },
    "All tool calls are logged via os.Logger under subsystem app.splynek, category system. View with: log stream --predicate 'subsystem == \"app.splynek\"' --info": {
        "pt-PT": "Todas as chamadas de ferramentas são registadas via os.Logger no subsistema app.splynek, categoria system. Vê com: log stream --predicate 'subsystem == \"app.splynek\"' --info",
        "es": "Todas las llamadas a herramientas se registran vía os.Logger bajo subsistema app.splynek, categoría system. Ver con: log stream --predicate 'subsystem == \"app.splynek\"' --info",
        "fr": "Tous les appels d'outils sont consignés via os.Logger sous le sous-système app.splynek, catégorie system. À voir avec : log stream --predicate 'subsystem == \"app.splynek\"' --info",
        "de": "Alle Tool-Aufrufe werden über os.Logger unter Subsystem app.splynek, Kategorie system protokolliert. Anzeige mit: log stream --predicate 'subsystem == \"app.splynek\"' --info",
        "it": "Tutte le chiamate agli strumenti sono registrate via os.Logger sotto sottosistema app.splynek, categoria system. Vedi con: log stream --predicate 'subsystem == \"app.splynek\"' --info",
    },
    "Catalog data ships in the app — neither Sovereignty nor Trust lookups query a network service. Your installed-app list never leaves your Mac.": {
        "pt-PT": "Os dados do catálogo são enviados na app — nem as consultas Soberania nem Confiança consultam um serviço de rede. A tua lista de apps instaladas nunca sai do Mac.",
        "es": "Los datos del catálogo se envían en la app — ni Soberanía ni Confianza consultan un servicio de red. Tu lista de apps instaladas nunca sale del Mac.",
        "fr": "Les données du catalogue sont incluses dans l'app — ni Souveraineté ni Confiance n'interrogent un service réseau. Votre liste d'apps installées ne quitte jamais votre Mac.",
        "de": "Katalog-Daten werden mit der App ausgeliefert — weder Souveränität- noch Vertrauen-Abfragen kontaktieren einen Netzwerkdienst. Ihre Liste installierter Apps verlässt Ihren Mac nie.",
        "it": "I dati del catalogo vengono distribuiti nell'app — né Sovranità né Affidabilità interrogano un servizio di rete. Il tuo elenco di app installate non lascia mai il Mac.",
    },

    # ── Agents tab setup explanations + custom client tab ──
    "Custom (any MCP client)": {"pt-PT": "Personalizado (qualquer cliente MCP)", "es": "Personalizado (cualquier cliente MCP)", "fr": "Personnalisé (tout client MCP)", "de": "Eigene (jeder MCP-Client)", "it": "Personalizzato (qualsiasi client MCP)"},
    "Claude Desktop's MCP transport is currently stdio-only. Use a small HTTP-bridge shim like mcp-proxy to bridge to Splynek's HTTP endpoint. When Claude Desktop ships HTTP transport, drop the snippet into ~/Library/Application Support/Claude/claude_desktop_config.json directly.": {
        "pt-PT": "O transporte MCP do Claude Desktop é atualmente só por stdio. Usa um pequeno adaptador HTTP como o mcp-proxy para fazer a ponte ao endpoint HTTP do Splynek. Quando o Claude Desktop tiver transporte HTTP, coloca o snippet diretamente em ~/Library/Application Support/Claude/claude_desktop_config.json.",
        "es": "El transporte MCP de Claude Desktop actualmente es solo stdio. Usa un pequeño puente HTTP como mcp-proxy para conectar con el endpoint HTTP de Splynek. Cuando Claude Desktop tenga transporte HTTP, coloca el snippet directamente en ~/Library/Application Support/Claude/claude_desktop_config.json.",
        "fr": "Le transport MCP de Claude Desktop est actuellement stdio uniquement. Utilisez un petit shim HTTP comme mcp-proxy pour ponter vers le point d'accès HTTP de Splynek. Quand Claude Desktop livrera le transport HTTP, placez l'extrait directement dans ~/Library/Application Support/Claude/claude_desktop_config.json.",
        "de": "Claude Desktops MCP-Transport ist aktuell nur stdio. Verwenden Sie einen kleinen HTTP-Bridge-Shim wie mcp-proxy, um zum HTTP-Endpunkt von Splynek zu verbinden. Wenn Claude Desktop HTTP-Transport ausliefert, fügen Sie das Snippet direkt in ~/Library/Application Support/Claude/claude_desktop_config.json ein.",
        "it": "Il trasporto MCP di Claude Desktop è attualmente solo stdio. Usa un piccolo shim HTTP come mcp-proxy per fare da ponte verso l'endpoint HTTP di Splynek. Quando Claude Desktop avrà il trasporto HTTP, metti lo snippet direttamente in ~/Library/Application Support/Claude/claude_desktop_config.json.",
    },
    "Claude.ai supports remote MCP HTTP transport. Add a remote MCP server in your workspace settings and paste the endpoint URL above.": {
        "pt-PT": "O Claude.ai suporta transporte MCP HTTP remoto. Adiciona um servidor MCP remoto nas definições da tua área de trabalho e cola o URL do endpoint acima.",
        "es": "Claude.ai soporta transporte MCP HTTP remoto. Añade un servidor MCP remoto en los ajustes de tu espacio de trabajo y pega la URL del endpoint de arriba.",
        "fr": "Claude.ai supporte le transport MCP HTTP distant. Ajoutez un serveur MCP distant dans les réglages de votre espace de travail et collez l'URL du point d'accès ci-dessus.",
        "de": "Claude.ai unterstützt Remote-MCP-HTTP-Transport. Fügen Sie einen Remote-MCP-Server in Ihren Workspace-Einstellungen hinzu und fügen Sie die Endpunkt-URL oben ein.",
        "it": "Claude.ai supporta il trasporto MCP HTTP remoto. Aggiungi un server MCP remoto nelle impostazioni del tuo workspace e incolla l'URL dell'endpoint sopra.",
    },
    "Quick sanity check — list every available tool. Useful for verifying the server is reachable before configuring a real client.": {
        "pt-PT": "Verificação rápida — lista todas as ferramentas disponíveis. Útil para confirmar que o servidor está acessível antes de configurar um cliente real.",
        "es": "Verificación rápida — lista todas las herramientas disponibles. Útil para verificar que el servidor es accesible antes de configurar un cliente real.",
        "fr": "Vérification rapide — liste tous les outils disponibles. Utile pour vérifier que le serveur est joignable avant de configurer un vrai client.",
        "de": "Schnelle Prüfung — listet alle verfügbaren Werkzeuge auf. Nützlich, um zu verifizieren, dass der Server erreichbar ist, bevor ein echter Client konfiguriert wird.",
        "it": "Controllo rapido — elenca tutti gli strumenti disponibili. Utile per verificare che il server sia raggiungibile prima di configurare un client reale.",
    },
    "Any client speaking JSON-RPC 2.0 over HTTP POST works. Minimum methods: initialize, tools/list, tools/call. Notifications return 204 (no body).": {
        "pt-PT": "Qualquer cliente que fale JSON-RPC 2.0 sobre HTTP POST funciona. Métodos mínimos: initialize, tools/list, tools/call. Notificações devolvem 204 (sem corpo).",
        "es": "Cualquier cliente que hable JSON-RPC 2.0 sobre HTTP POST funciona. Métodos mínimos: initialize, tools/list, tools/call. Las notificaciones devuelven 204 (sin cuerpo).",
        "fr": "Tout client parlant JSON-RPC 2.0 sur HTTP POST fonctionne. Méthodes minimales : initialize, tools/list, tools/call. Les notifications renvoient 204 (sans corps).",
        "de": "Jeder Client, der JSON-RPC 2.0 über HTTP POST spricht, funktioniert. Mindestmethoden: initialize, tools/list, tools/call. Benachrichtigungen geben 204 zurück (kein Body).",
        "it": "Qualsiasi client che parli JSON-RPC 2.0 su HTTP POST funziona. Metodi minimi: initialize, tools/list, tools/call. Le notifiche restituiscono 204 (nessun corpo).",
    },

    # ── Agents tool gallery display names ──
    "Get progress": {"pt-PT": "Obter progresso", "es": "Obtener progreso", "fr": "Obtenir progression", "de": "Fortschritt abrufen", "it": "Ottieni progresso"},
    "List history": {"pt-PT": "Listar histórico", "es": "Listar historial", "fr": "Lister l'historique", "de": "Verlauf auflisten", "it": "Elenca cronologia"},
    "Lookup sovereignty": {"pt-PT": "Consultar soberania", "es": "Consultar soberanía", "fr": "Consulter la souveraineté", "de": "Souveränität abfragen", "it": "Consulta sovranità"},
    "Lookup trust": {"pt-PT": "Consultar confiança", "es": "Consultar confianza", "fr": "Consulter la confiance", "de": "Vertrauen abfragen", "it": "Consulta affidabilità"},
    "Run sovereignty scan": {"pt-PT": "Executar análise de soberania", "es": "Ejecutar análisis de soberanía", "fr": "Exécuter l'analyse de souveraineté", "de": "Souveränitäts-Scan ausführen", "it": "Esegui scansione sovranità"},
    "Download url": {"pt-PT": "Transferir URL", "es": "Descargar URL", "fr": "Télécharger l'URL", "de": "URL herunterladen", "it": "Scarica URL"},
    "Queue url": {"pt-PT": "Enfileirar URL", "es": "Encolar URL", "fr": "Mettre URL en file", "de": "URL in Warteschlange", "it": "Accoda URL"},
    "Cancel all": {"pt-PT": "Cancelar tudo", "es": "Cancelar todo", "fr": "Tout annuler", "de": "Alle abbrechen", "it": "Annulla tutto"},

    # ── v1.6.2 round 5: gap-fill from final visual audit. ──

    # Browser helpers card body
    "Send links + current pages to Splynek with one click.": {
        "pt-PT": "Envia links + páginas atuais para o Splynek com um clique.",
        "es": "Envía enlaces + páginas actuales a Splynek con un clic.",
        "fr": "Envoyez des liens + pages actuelles à Splynek en un clic.",
        "de": "Links + aktuelle Seiten mit einem Klick an Splynek senden.",
        "it": "Invia link + pagine correnti a Splynek con un clic.",
    },

    # MetricView captions in HistoryView (mixed-case keys, uppercased at render)
    "Downloads": {
        "pt-PT": "Transferências", "es": "Descargas",
        "fr": "Téléchargements", "de": "Downloads", "it": "Download",
    },
    "Bytes": {
        "pt-PT": "Bytes", "es": "Bytes",
        "fr": "Octets", "de": "Bytes", "it": "Byte",
    },
    "Avg throughput": {
        "pt-PT": "Débito médio", "es": "Ancho medio",
        "fr": "Débit moyen", "de": "Ø Durchsatz", "it": "Velocità media",
    },
    "Time saved": {
        "pt-PT": "Tempo poupado", "es": "Tiempo ahorrado",
        "fr": "Temps gagné", "de": "Zeit gespart", "it": "Tempo risparmiato",
    },

    # Empty-state for Queue (now translatable after EmptyStateView fix)
    "Queue is empty": {
        "pt-PT": "Fila vazia", "es": "Cola vacía",
        "fr": "File vide", "de": "Warteschlange ist leer", "it": "Coda vuota",
    },
    # Already in catalog: "Add a URL to the queue from the Downloads tab — Splynek will run it when the current download finishes."

    # Avaliação body — exact key with markdown backticks as in code
    "Splynek downloads the target URL through each interface individually, then through all of them aggregated. Temp files are placed in `/tmp/` and deleted after each probe, so the benchmark touches only network + CPU. The multi-path number is the real-world aggregate using keep-alive HTTP/1.1 lanes bound via `IP_BOUND_IF`.": {
        "pt-PT": "O Splynek transfere o URL alvo por cada interface individualmente e depois por todas agregadas. Os ficheiros temporários ficam em `/tmp/` e são apagados após cada teste, por isso a avaliação toca apenas rede + CPU. O número multi-caminho é o agregado real usando vias HTTP/1.1 keep-alive vinculadas via `IP_BOUND_IF`.",
        "es": "Splynek descarga la URL objetivo por cada interfaz individualmente, luego por todas agregadas. Los archivos temp van a `/tmp/` y se borran después de cada prueba, así que la prueba solo toca red + CPU. El número multi-ruta es el agregado real usando carriles HTTP/1.1 keep-alive vinculados vía `IP_BOUND_IF`.",
        "fr": "Splynek télécharge l'URL cible via chaque interface individuellement, puis via toutes agrégées. Les fichiers temp vont dans `/tmp/` et sont supprimés après chaque sonde, donc l'évaluation touche seulement réseau + CPU. Le nombre multi-chemin est l'agrégat réel utilisant des canaux HTTP/1.1 keep-alive liés via `IP_BOUND_IF`.",
        "de": "Splynek lädt die Ziel-URL über jede Schnittstelle einzeln herunter, dann über alle aggregiert. Temp-Dateien landen in `/tmp/` und werden nach jeder Sonde gelöscht; der Benchmark berührt also nur Netzwerk + CPU. Die Mehrpfad-Zahl ist der reale Aggregatwert mit HTTP/1.1-keep-alive-Spuren via `IP_BOUND_IF`.",
        "it": "Splynek scarica l'URL target attraverso ogni interfaccia individualmente, poi attraverso tutte aggregate. I file temp vanno in `/tmp/` e sono cancellati dopo ogni sonda, quindi il benchmark tocca solo rete + CPU. Il numero multi-percorso è l'aggregato reale usando corsie HTTP/1.1 keep-alive associate via `IP_BOUND_IF`.",
    },

    # Paste English body — uses curly quotes \u{201C}…\u{201D} — exact key
    "Paste English like “the latest Ubuntu ISO” and the local LLM returns a direct URL. Natural-language history search too. Runs entirely on this Mac.": {
        "pt-PT": "Cola inglês como “a última ISO do Ubuntu” e o LLM local devolve um URL direto. Pesquisa de histórico em linguagem natural também. Corre inteiramente neste Mac.",
        "es": "Pega inglés como “la última ISO de Ubuntu” y el LLM local devuelve una URL directa. Búsqueda de historial en lenguaje natural también. Corre por completo en este Mac.",
        "fr": "Collez de l'anglais comme “la dernière ISO Ubuntu” et le LLM local renvoie une URL directe. Recherche d'historique en langage naturel aussi. Tourne entièrement sur ce Mac.",
        "de": "Englisch wie “die neueste Ubuntu-ISO” einfügen und das lokale LLM gibt eine direkte URL zurück. Auch Verlaufssuche in natürlicher Sprache. Läuft komplett auf diesem Mac.",
        "it": "Incolla inglese come “l'ultima ISO di Ubuntu” e l'LLM locale restituisce un URL diretto. Ricerca cronologia in linguaggio naturale anche. Gira interamente su questo Mac.",
    },

    # ── v1.6.2 round 6: Frota MetricView captions + StatusPill
    # labels + 8 MCP tool descriptions + top long-tail strings. ──

    # ── Frota column labels (mixed-case keys, MetricView .uppercase()) ──
    "Name": {"pt-PT": "Nome", "es": "Nombre", "fr": "Nom", "de": "Name", "it": "Nome"},
    "Device ID": {"pt-PT": "ID do dispositivo", "es": "ID del dispositivo", "fr": "ID de l'appareil", "de": "Geräte-ID", "it": "ID dispositivo"},
    "Port": {"pt-PT": "Porta", "es": "Puerto", "fr": "Port", "de": "Port", "it": "Porta"},
    "Active": {"pt-PT": "Ativos", "es": "Activos", "fr": "Actifs", "de": "Aktiv", "it": "Attivi"},
    "Shareable": {"pt-PT": "Partilháveis", "es": "Compartibles", "fr": "Partageables", "de": "Teilbar", "it": "Condivisibili"},
    "Hashed": {"pt-PT": "Em hash", "es": "Con hash", "fr": "Hashés", "de": "Mit Hash", "it": "Con hash"},

    # ── Frota StatusPill labels ──
    "ADVERTISED": {"pt-PT": "ANUNCIADO", "es": "ANUNCIADO", "fr": "ANNONCÉ", "de": "ANGEKÜNDIGT", "it": "ANNUNCIATO"},
    "STARTING": {"pt-PT": "A INICIAR", "es": "INICIANDO", "fr": "DÉMARRAGE", "de": "STARTET", "it": "AVVIO"},

    # ── 8 MCP tool descriptions (paragraphs from MCPTools.swift) ──
    "List currently-active Splynek download jobs with their progress (downloaded / total bytes), throughput in bytes per second, and lifecycle state (running, paused, queued, completed, failed). Returns an empty list if nothing is in flight.": {
        "pt-PT": "Lista os trabalhos de transferência ativos do Splynek com o progresso (bytes transferidos / total), débito em bytes por segundo e estado do ciclo de vida (em execução, em pausa, em fila, concluído, falhado). Devolve uma lista vazia se não houver nada em curso.",
        "es": "Lista los trabajos de descarga activos de Splynek con su progreso (bytes descargados / total), ancho de banda en bytes por segundo y estado de ciclo de vida (en ejecución, pausado, en cola, completado, fallado). Devuelve una lista vacía si no hay nada en curso.",
        "fr": "Liste les tâches de téléchargement actives de Splynek avec leur progression (octets téléchargés / total), débit en octets par seconde et état du cycle de vie (en cours, en pause, en file, terminé, échoué). Renvoie une liste vide si rien n'est en cours.",
        "de": "Listet aktuell laufende Splynek-Download-Jobs auf, mit Fortschritt (heruntergeladene / Gesamt-Bytes), Durchsatz in Bytes pro Sekunde und Lebenszyklus-Status (läuft, pausiert, in Warteschlange, abgeschlossen, fehlgeschlagen). Gibt eine leere Liste zurück, wenn nichts läuft.",
        "it": "Elenca i lavori di download attivi di Splynek con il loro progresso (byte scaricati / totali), throughput in byte al secondo e stato del ciclo di vita (in esecuzione, in pausa, in coda, completato, fallito). Restituisce un elenco vuoto se non c'è nulla in corso.",
    },
    "List recently completed Splynek downloads.  Each item includes the original URL, filename, byte count, finish time, and on-disk path.  `limit` defaults to 10 and is capped at 50.": {
        "pt-PT": "Lista as transferências do Splynek concluídas recentemente. Cada item inclui o URL original, nome do ficheiro, contagem de bytes, hora de conclusão e caminho no disco. `limit` é 10 por predefinição e tem limite máximo de 50.",
        "es": "Lista las descargas de Splynek completadas recientemente. Cada elemento incluye la URL original, nombre de archivo, conteo de bytes, hora de finalización y ruta en disco. `limit` por defecto es 10, máximo 50.",
        "fr": "Liste les téléchargements Splynek récemment terminés. Chaque élément inclut l'URL originale, le nom du fichier, le nombre d'octets, l'heure de fin et le chemin sur disque. `limit` vaut 10 par défaut, plafonné à 50.",
        "de": "Listet kürzlich abgeschlossene Splynek-Downloads auf. Jeder Eintrag enthält die Original-URL, den Dateinamen, die Byte-Anzahl, die Endzeit und den Pfad auf der Festplatte. `limit` ist standardmäßig 10, maximal 50.",
        "it": "Elenca i download Splynek completati di recente. Ogni elemento include l'URL originale, nome del file, conteggio byte, ora di fine e percorso su disco. `limit` predefinito 10, massimo 50.",
    },
    "Look up an installed app in the Splynek Sovereignty catalog. Returns the app's target-origin (where it's controlled from: EU, US, OSS, China, Russia, Other) plus a list of EU-or-OSS-controlled alternatives the user could switch to. `query` accepts either a bundle identifier (e.g. `com.spotify.client`) or a display name (e.g. `Spotify`).": {
        "pt-PT": "Consulta uma app instalada no catálogo Soberania do Splynek. Devolve a origem-alvo da app (de onde é controlada: UE, EUA, OSS, China, Rússia, Outra) e uma lista de alternativas controladas na UE ou de código aberto para as quais o utilizador pode mudar. `query` aceita um identificador de pacote (ex.: `com.spotify.client`) ou um nome a apresentar (ex.: `Spotify`).",
        "es": "Consulta una app instalada en el catálogo Soberanía de Splynek. Devuelve el origen-objetivo de la app (desde dónde se controla: UE, EE. UU., OSS, China, Rusia, Otro) y una lista de alternativas controladas en UE u open source a las que el usuario puede cambiar. `query` acepta un identificador de paquete (p. ej. `com.spotify.client`) o un nombre visible (p. ej. `Spotify`).",
        "fr": "Recherche une app installée dans le catalogue Souveraineté de Splynek. Renvoie l'origine cible de l'app (d'où elle est contrôlée : UE, États-Unis, OSS, Chine, Russie, Autre) ainsi qu'une liste d'alternatives contrôlées en UE ou open source. `query` accepte un identifiant de bundle (ex. `com.spotify.client`) ou un nom affiché (ex. `Spotify`).",
        "de": "Schlägt eine installierte App im Splynek-Souveränitäts-Katalog nach. Gibt das Ziel-Herkunftsland der App zurück (woher sie gesteuert wird: EU, USA, OSS, China, Russland, Andere) sowie eine Liste von EU- oder Open-Source-kontrollierten Alternativen, auf die der Benutzer wechseln könnte. `query` akzeptiert eine Bundle-ID (z. B. `com.spotify.client`) oder einen Anzeigenamen (z. B. `Spotify`).",
        "it": "Cerca un'app installata nel catalogo Sovranità di Splynek. Restituisce l'origine-target dell'app (da dove è controllata: UE, USA, OSS, Cina, Russia, Altro) e un elenco di alternative controllate UE o open source a cui l'utente potrebbe passare. `query` accetta un identificatore di bundle (es. `com.spotify.client`) o un nome visualizzato (es. `Spotify`).",
    },
    "Look up an app in the Splynek Trust catalog — public-record audit of privacy, security, trust, and business-model concerns.  Returns the 0–100 score, severity level, and a list of cited concerns (each with a primary-source URL: App Store privacy labels, EU DPA / FTC enforcement, NVD CVEs, HIBP breaches, vendor advisories — never tech press).": {
        "pt-PT": "Consulta uma app no catálogo Confiança do Splynek — auditoria de registo público sobre privacidade, segurança, confiança e modelo de negócio. Devolve a pontuação 0–100, nível de gravidade e uma lista de preocupações citadas (cada uma com URL de fonte primária: etiquetas de privacidade da App Store, ações de DPA da UE / FTC, CVEs do NVD, violações HIBP, avisos de fornecedores — nunca imprensa tecnológica).",
        "es": "Consulta una app en el catálogo Confianza de Splynek — auditoría de registro público sobre privacidad, seguridad, confianza y modelo de negocio. Devuelve la puntuación 0–100, nivel de gravedad y lista de preocupaciones citadas (cada una con URL de fuente primaria: etiquetas de privacidad de App Store, acciones de DPA UE / FTC, CVE de NVD, filtraciones HIBP, avisos de proveedores — nunca prensa tecnológica).",
        "fr": "Recherche une app dans le catalogue Confiance de Splynek — audit des registres publics sur la confidentialité, la sécurité, la confiance et le modèle économique. Renvoie le score 0–100, le niveau de gravité et une liste de préoccupations citées (chacune avec une URL de source primaire : étiquettes de confidentialité App Store, actions DPA UE / FTC, CVE NVD, fuites HIBP, avis éditeurs — jamais la presse tech).",
        "de": "Schlägt eine App im Splynek-Vertrauen-Katalog nach — Audit öffentlicher Aufzeichnungen zu Datenschutz, Sicherheit, Vertrauen und Geschäftsmodell. Gibt die 0–100-Bewertung, das Schweregradlevel und eine Liste zitierter Bedenken zurück (jedes mit Primärquellen-URL: App-Store-Datenschutzlabels, EU-DPA-/FTC-Verfahren, NVD-CVEs, HIBP-Datenlecks, Hersteller-Hinweise — niemals Tech-Presse).",
        "it": "Cerca un'app nel catalogo Affidabilità di Splynek — verifica dei registri pubblici su privacy, sicurezza, affidabilità e modello di business. Restituisce il punteggio 0–100, livello di gravità ed elenco delle preoccupazioni citate (ciascuna con URL di fonte primaria: etichette privacy App Store, azioni DPA UE / FTC, CVE NVD, fughe HIBP, avvisi vendor — mai stampa tech).",
    },
    "Scan the user's installed apps and return a summary count of how many were matched against the Sovereignty catalog. Use this before `splynek_lookup_sovereignty` to understand the user's overall exposure.  All scanning is on-device; no app list leaves the user's machine.": {
        "pt-PT": "Analisa as apps instaladas do utilizador e devolve uma contagem resumida de quantas correspondem ao catálogo Soberania. Usa isto antes de `splynek_lookup_sovereignty` para perceber a exposição geral do utilizador. Toda a análise é no dispositivo; nenhuma lista de apps sai da máquina do utilizador.",
        "es": "Analiza las apps instaladas del usuario y devuelve un conteo resumido de cuántas coinciden con el catálogo Soberanía. Úsalo antes de `splynek_lookup_sovereignty` para entender la exposición general del usuario. Todo el análisis es en el dispositivo; ninguna lista de apps sale de la máquina del usuario.",
        "fr": "Analyse les apps installées de l'utilisateur et renvoie un nombre récapitulatif de celles qui correspondent au catalogue Souveraineté. Utilisez-le avant `splynek_lookup_sovereignty` pour comprendre l'exposition globale de l'utilisateur. Toute l'analyse est sur l'appareil ; aucune liste d'apps ne quitte la machine de l'utilisateur.",
        "de": "Scannt die installierten Apps des Benutzers und gibt eine zusammenfassende Anzahl zurück, wie viele mit dem Souveränitäts-Katalog übereinstimmen. Verwenden Sie dies vor `splynek_lookup_sovereignty`, um die Gesamtexposition des Benutzers zu verstehen. Der gesamte Scan erfolgt auf dem Gerät; keine App-Liste verlässt den Computer des Benutzers.",
        "it": "Scansiona le app installate dell'utente e restituisce un conteggio riassuntivo di quante corrispondono al catalogo Sovranità. Usalo prima di `splynek_lookup_sovereignty` per capire l'esposizione complessiva dell'utente. Tutta la scansione è sul dispositivo; nessun elenco di app lascia la macchina dell'utente.",
    },
    "Start an immediate download via Splynek's multi-interface HTTP aggregator.  The URL must be HTTP(S) or a `magnet:` BitTorrent magnet link.  Optional `sha256` enables integrity verification — when present, the download is rejected on hash mismatch.  Output goes to the user's configured Splynek output directory.": {
        "pt-PT": "Inicia uma transferência imediata via o agregador HTTP multi-interface do Splynek. O URL tem de ser HTTP(S) ou um link `magnet:` BitTorrent. O `sha256` opcional ativa a verificação de integridade — quando presente, a transferência é rejeitada em caso de divergência. A saída vai para o diretório de saída configurado do Splynek.",
        "es": "Inicia una descarga inmediata vía el agregador HTTP multi-interfaz de Splynek. La URL debe ser HTTP(S) o un enlace `magnet:` BitTorrent. El `sha256` opcional activa la verificación de integridad — cuando está presente, la descarga se rechaza en caso de discrepancia de hash. La salida va al directorio de salida configurado de Splynek.",
        "fr": "Démarre un téléchargement immédiat via l'agrégateur HTTP multi-interface de Splynek. L'URL doit être HTTP(S) ou un lien `magnet:` BitTorrent. Le `sha256` optionnel active la vérification d'intégrité — s'il est présent, le téléchargement est rejeté en cas de divergence de hash. La sortie va vers le répertoire de sortie configuré de Splynek.",
        "de": "Startet einen sofortigen Download über Splyneks Multi-Schnittstellen-HTTP-Aggregator. Die URL muss HTTP(S) oder ein BitTorrent-Magnet-Link `magnet:` sein. Der optionale `sha256` aktiviert die Integritätsprüfung — wenn vorhanden, wird der Download bei Hash-Abweichung abgelehnt. Die Ausgabe geht ins konfigurierte Splynek-Ausgabeverzeichnis.",
        "it": "Avvia un download immediato tramite l'aggregatore HTTP multi-interfaccia di Splynek. L'URL deve essere HTTP(S) o un link `magnet:` BitTorrent. Il `sha256` opzionale abilita la verifica di integrità — se presente, il download è rifiutato in caso di mismatch hash. L'output va nella directory di output configurata di Splynek.",
    },
    "Append a URL to Splynek's download queue (instead of starting it immediately).  Useful when the user wants to batch up several URLs and let Splynek process them sequentially.  Same URL + sha256 schema as `splynek_download_url`.": {
        "pt-PT": "Adiciona um URL à fila de transferências do Splynek (em vez de iniciar imediatamente). Útil quando o utilizador quer agrupar vários URLs e deixar o Splynek processá-los em sequência. Mesmo esquema URL + sha256 que `splynek_download_url`.",
        "es": "Añade una URL a la cola de descargas de Splynek (en lugar de iniciarla inmediatamente). Útil cuando el usuario quiere agrupar varias URLs y dejar que Splynek las procese en secuencia. Mismo esquema URL + sha256 que `splynek_download_url`.",
        "fr": "Ajoute une URL à la file d'attente de téléchargement de Splynek (au lieu de la démarrer immédiatement). Utile quand l'utilisateur veut grouper plusieurs URLs et laisser Splynek les traiter en séquence. Même schéma URL + sha256 que `splynek_download_url`.",
        "de": "Hängt eine URL an die Splynek-Download-Warteschlange an (anstatt sie sofort zu starten). Nützlich, wenn der Benutzer mehrere URLs bündeln und Splynek sequentiell verarbeiten lassen möchte. Gleiches URL + sha256-Schema wie `splynek_download_url`.",
        "it": "Aggiunge un URL alla coda di download di Splynek (invece di avviarlo immediatamente). Utile quando l'utente vuole raggruppare più URL e lasciare che Splynek li elabori in sequenza. Stesso schema URL + sha256 di `splynek_download_url`.",
    },
    "Cancel every active and queued Splynek download.  This does not delete already-downloaded data; partial files are preserved on disk.  Use cautiously — there's no undo.": {
        "pt-PT": "Cancela todas as transferências ativas e em fila do Splynek. Isto não apaga dados já transferidos; ficheiros parciais são preservados no disco. Usa com cautela — não há anular.",
        "es": "Cancela todas las descargas activas y en cola de Splynek. Esto no borra datos ya descargados; los archivos parciales se conservan en disco. Úsalo con cuidado — no hay deshacer.",
        "fr": "Annule tous les téléchargements actifs et en file de Splynek. Ceci ne supprime pas les données déjà téléchargées ; les fichiers partiels sont conservés sur disque. À utiliser avec précaution — il n'y a pas d'annulation.",
        "de": "Bricht alle aktiven und in der Warteschlange befindlichen Splynek-Downloads ab. Dies löscht keine bereits heruntergeladenen Daten; Teil-Dateien bleiben auf der Festplatte erhalten. Mit Vorsicht verwenden — kein Rückgängig.",
        "it": "Annulla tutti i download attivi e in coda di Splynek. Questo non elimina i dati già scaricati; i file parziali vengono conservati su disco. Usa con cautela — non c'è annulla.",
    },

    # ── Top long-tail strings (DownloadView tooltips, AboutView,
    # SettingsView details, BenchmarkView interactives) ──

    "Splynek": {"pt-PT": "Splynek", "es": "Splynek", "fr": "Splynek", "de": "Splynek", "it": "Splynek"},
    "Splynek Pro feature": {"pt-PT": "Funcionalidade Splynek Pro", "es": "Función Splynek Pro", "fr": "Fonctionnalité Splynek Pro", "de": "Splynek Pro-Funktion", "it": "Funzione Splynek Pro"},
    "How this works": {"pt-PT": "Como funciona", "es": "Cómo funciona", "fr": "Comment ça marche", "de": "So funktioniert es", "it": "Come funziona"},
    "Cancel.": {"pt-PT": "Cancelar.", "es": "Cancelar.", "fr": "Annuler.", "de": "Abbrechen.", "it": "Annulla."},
    "Pause; sidecar is retained so resume picks up here.": {
        "pt-PT": "Pausa; o sidecar é preservado para que o retomar continue daqui.",
        "es": "Pausa; el sidecar se conserva para que reanudar continúe desde aquí.",
        "fr": "Pause ; le sidecar est conservé pour que la reprise continue ici.",
        "de": "Pause; Sidecar wird beibehalten, damit das Fortsetzen hier weitermacht.",
        "it": "Pausa; il sidecar viene mantenuto in modo che la ripresa continui da qui.",
    },
    "Projected split — based on prior runs against this host": {
        "pt-PT": "Divisão prevista — com base em execuções anteriores contra este servidor",
        "es": "División proyectada — basada en ejecuciones previas contra este host",
        "fr": "Répartition projetée — basée sur les exécutions précédentes contre cet hôte",
        "de": "Projizierte Aufteilung — basierend auf vorherigen Läufen gegen diesen Host",
        "it": "Suddivisione prevista — basata sulle esecuzioni precedenti verso questo host",
    },
    "GB": {"pt-PT": "GB", "es": "GB", "fr": "Go", "de": "GB", "it": "GB"},
    "Type a goal like \"set up my Mac for iOS dev\"": {
        # Already in catalog — no-op duplicate but harmless if regenerator is idempotent.
        "pt-PT": "Escreve um objetivo como \"configurar o meu Mac para desenvolvimento iOS\"",
        "es": "Escribe un objetivo como \"configurar mi Mac para desarrollo iOS\"",
        "fr": "Tapez un objectif comme \"configurer mon Mac pour le développement iOS\"",
        "de": "Tippen Sie ein Ziel ein wie \"Mac für iOS-Entwicklung einrichten\"",
        "it": "Scrivi un obiettivo come \"configura il mio Mac per sviluppo iOS\"",
    },

    # ── DownloadView tooltips (.help() — hover-only, but still
    # user-visible) ──
    "Drop the .splynek-manifest with a precomputed Merkle tree of the file's contents. Splynek verifies each chunk against its expected leaf hash on arrival — any corrupted byte triggers a re-fetch inline, without waiting for a full-file SHA-256 at the end.": {
        "pt-PT": "Largar o .splynek-manifest com uma árvore Merkle pré-calculada do conteúdo do ficheiro. O Splynek verifica cada fragmento contra o hash de folha esperado à chegada — qualquer byte corrompido desencadeia uma re-transferência em linha, sem esperar por um SHA-256 do ficheiro inteiro no fim.",
        "es": "Suelta el .splynek-manifest con un árbol Merkle precalculado del contenido del archivo. Splynek verifica cada fragmento contra su hash de hoja esperado a la llegada — cualquier byte corrupto activa una re-descarga en línea, sin esperar a un SHA-256 del archivo completo al final.",
        "fr": "Déposez le .splynek-manifest avec un arbre Merkle précalculé du contenu du fichier. Splynek vérifie chaque morceau par rapport à son hash de feuille attendu à l'arrivée — tout octet corrompu déclenche un re-téléchargement en ligne, sans attendre un SHA-256 du fichier entier à la fin.",
        "de": "Legen Sie das .splynek-manifest mit einem vorab berechneten Merkle-Baum des Dateiinhalts ab. Splynek verifiziert jeden Chunk gegen seinen erwarteten Blatt-Hash bei Ankunft — jedes beschädigte Byte löst einen Inline-Neu-Abruf aus, ohne am Ende auf einen vollständigen Datei-SHA-256 warten zu müssen.",
        "it": "Trascina il .splynek-manifest con un albero Merkle precalcolato del contenuto del file. Splynek verifica ogni frammento rispetto al suo hash foglia atteso all'arrivo — qualsiasi byte corrotto attiva un re-download in linea, senza attendere un SHA-256 dell'intero file alla fine.",
    },
    "Active downloads": {
        "pt-PT": "Transferências ativas", "es": "Descargas activas",
        "fr": "Téléchargements actifs", "de": "Aktive Downloads",
        "it": "Download attivi",
    },
    "Reveal in Finder": {
        "pt-PT": "Mostrar no Finder", "es": "Mostrar en Finder",
        "fr": "Afficher dans le Finder", "de": "Im Finder anzeigen",
        "it": "Mostra nel Finder",
    },
    "Re-download from origin (does not pull from fleet peers).": {
        "pt-PT": "Voltar a transferir da origem (não puxa de pares na frota).",
        "es": "Volver a descargar desde el origen (no tira de pares de la flota).",
        "fr": "Re-télécharger depuis l'origine (ne tire pas des pairs de la flotte).",
        "de": "Erneut von der Quelle herunterladen (zieht nicht von Flotten-Peers).",
        "it": "Riscarica dall'origine (non preleva dai peer della flotta).",
    },
    "Detached signature available": {
        "pt-PT": "Assinatura separada disponível",
        "es": "Firma separada disponible",
        "fr": "Signature détachée disponible",
        "de": "Separate Signatur verfügbar",
        "it": "Firma separata disponibile",
    },

    # ── BenchmarkView interactives ──
    "Re-run with the same target. Useful after switching networks.": {
        "pt-PT": "Voltar a executar com o mesmo alvo. Útil após mudar de rede.",
        "es": "Volver a ejecutar con el mismo objetivo. Útil tras cambiar de red.",
        "fr": "Relancer avec la même cible. Utile après avoir changé de réseau.",
        "de": "Mit demselben Ziel erneut ausführen. Nützlich nach einem Netzwerkwechsel.",
        "it": "Riesegui con lo stesso target. Utile dopo aver cambiato rete.",
    },
    "Reset to default URL.": {
        "pt-PT": "Repor o URL predefinido.",
        "es": "Restablecer la URL predeterminada.",
        "fr": "Réinitialiser à l'URL par défaut.",
        "de": "Auf Standard-URL zurücksetzen.",
        "it": "Reimposta all'URL predefinito.",
    },

    # ── Settings: schedule details ──
    "Active days": {"pt-PT": "Dias ativos", "es": "Días activos", "fr": "Jours actifs", "de": "Aktive Tage", "it": "Giorni attivi"},
    "Start": {"pt-PT": "Início", "es": "Inicio", "fr": "Début", "de": "Start", "it": "Inizio"},
    "End": {"pt-PT": "Fim", "es": "Fin", "fr": "Fin", "de": "Ende", "it": "Fine"},
    "Every day": {"pt-PT": "Todos os dias", "es": "Todos los días", "fr": "Tous les jours", "de": "Jeden Tag", "it": "Ogni giorno"},
    "Weekdays": {"pt-PT": "Dias úteis", "es": "Días laborables", "fr": "Jours ouvrés", "de": "Wochentage", "it": "Giorni feriali"},
    "Respect schedule": {"pt-PT": "Respeitar agendamento", "es": "Respetar programación", "fr": "Respecter la planification", "de": "Zeitplan einhalten", "it": "Rispetta pianificazione"},
    "Window is open — queued items will start as slots free up.": {
        "pt-PT": "A janela está aberta — os itens em fila vão começar à medida que as vagas ficam livres.",
        "es": "La ventana está abierta — los elementos en cola comenzarán a medida que se liberen los slots.",
        "fr": "La fenêtre est ouverte — les éléments en file commenceront à mesure que les emplacements se libèrent.",
        "de": "Das Fenster ist offen — Elemente in der Warteschlange starten, sobald Slots frei werden.",
        "it": "La finestra è aperta — gli elementi in coda partiranno man mano che si liberano gli slot.",
    },
    "Detected Ollama —": {"pt-PT": "Detetado Ollama —", "es": "Ollama detectado —", "fr": "Ollama détecté —", "de": "Ollama erkannt —", "it": "Ollama rilevato —"},
    "Re-probe localhost:11434 for Ollama": {
        "pt-PT": "Voltar a sondar localhost:11434 para o Ollama",
        "es": "Volver a sondear localhost:11434 para Ollama",
        "fr": "Re-sonder localhost:11434 pour Ollama",
        "de": "localhost:11434 erneut auf Ollama prüfen",
        "it": "Riprova localhost:11434 per Ollama",
    },
    "Refresh login-item status from macOS": {
        "pt-PT": "Atualizar estado de item de início de sessão do macOS",
        "es": "Actualizar estado de elemento de inicio del macOS",
        "fr": "Actualiser l'état de l'élément d'ouverture de session depuis macOS",
        "de": "Login-Item-Status von macOS aktualisieren",
        "it": "Aggiorna stato elemento di avvio da macOS",
    },
    "Restore Purchase": {
        "pt-PT": "Restaurar compra",
        "es": "Restaurar compra",
        "fr": "Restaurer l'achat",
        "de": "Kauf wiederherstellen",
        "it": "Ripristina acquisto",
    },
    "Status unknown.": {
        "pt-PT": "Estado desconhecido.",
        "es": "Estado desconocido.",
        "fr": "État inconnu.",
        "de": "Status unbekannt.",
        "it": "Stato sconosciuto.",
    },
    "Not registered.": {
        "pt-PT": "Não registado.",
        "es": "No registrado.",
        "fr": "Non enregistré.",
        "de": "Nicht registriert.",
        "it": "Non registrato.",
    },
    "Approval required — open System Settings → Login Items.": {
        "pt-PT": "Aprovação necessária — abre Definições do Sistema → Itens de início de sessão.",
        "es": "Aprobación requerida — abre Ajustes del Sistema → Elementos de inicio.",
        "fr": "Approbation requise — ouvrez Réglages Système → Éléments d'ouverture de session.",
        "de": "Genehmigung erforderlich — Systemeinstellungen → Anmeldeobjekte öffnen.",
        "it": "Approvazione richiesta — apri Impostazioni Sistema → Elementi all'avvio.",
    },
    "Registered. macOS will start Splynek at next login.": {
        "pt-PT": "Registado. O macOS vai iniciar o Splynek no próximo início de sessão.",
        "es": "Registrado. macOS iniciará Splynek en el próximo inicio de sesión.",
        "fr": "Enregistré. macOS lancera Splynek à la prochaine connexion.",
        "de": "Registriert. macOS wird Splynek bei der nächsten Anmeldung starten.",
        "it": "Registrato. macOS avvierà Splynek al prossimo accesso.",
    },
    "Deactivate on this Mac": {
        "pt-PT": "Desativar neste Mac",
        "es": "Desactivar en este Mac",
        "fr": "Désactiver sur ce Mac",
        "de": "Auf diesem Mac deaktivieren",
        "it": "Disattiva su questo Mac",
    },
    "Buy Splynek Pro — $29": {
        "pt-PT": "Comprar Splynek Pro — $29",
        "es": "Comprar Splynek Pro — $29",
        "fr": "Acheter Splynek Pro — $29",
        "de": "Splynek Pro kaufen — $29",
        "it": "Acquista Splynek Pro — $29",
    },
    "Thanks for supporting Splynek. AI Concierge, AI history search, scheduled downloads, and LAN-accessible dashboard are unlocked.": {
        "pt-PT": "Obrigado por apoiares o Splynek. O Concierge IA, pesquisa de histórico com IA, transferências agendadas e painel acessível pela rede local estão desbloqueados.",
        "es": "Gracias por apoyar Splynek. El Concierge IA, búsqueda de historial con IA, descargas programadas y panel accesible por red local están desbloqueados.",
        "fr": "Merci de soutenir Splynek. Le Concierge IA, la recherche d'historique IA, les téléchargements planifiés et le tableau de bord accessible par réseau local sont débloqués.",
        "de": "Danke, dass Sie Splynek unterstützen. KI-Concierge, KI-Verlaufssuche, geplante Downloads und lokal-Netzwerk-zugängliches Dashboard sind freigeschaltet.",
        "it": "Grazie per supportare Splynek. Il Concierge IA, ricerca cronologia con IA, download programmati e dashboard accessibile via rete locale sono sbloccati.",
    },

    # ── Round 7 — long-tail tooltip / button / help text ────────────
    # 42 plain-string entries surfaced by Scripts/find-missing-translations.py
    # after round 6. All non-interpolated; another 55 interpolated strings
    # stay queued for round 8 (need %@/%lld parameterization).
    "Refresh": {
        "pt-PT": "Atualizar",
        "es": "Actualizar",
        "fr": "Actualiser",
        "de": "Aktualisieren",
        "it": "Aggiorna",
    },
    "Retry": {
        "pt-PT": "Repetir",
        "es": "Reintentar",
        "fr": "Réessayer",
        "de": "Erneut versuchen",
        "it": "Riprova",
    },
    "Import…": {
        "pt-PT": "Importar…",
        "es": "Importar…",
        "fr": "Importer…",
        "de": "Importieren…",
        "it": "Importa…",
    },
    "Restore all": {
        "pt-PT": "Restaurar tudo",
        "es": "Restaurar todo",
        "fr": "Tout restaurer",
        "de": "Alle wiederherstellen",
        "it": "Ripristina tutto",
    },
    "Quick Look": {
        # Apple's canonical localised names for the macOS feature.
        "pt-PT": "Vista Rápida",
        "es": "Vista Rápida",
        "fr": "Coup d'œil",
        "de": "Übersicht",
        "it": "Visualizzazione rapida",
    },
    "Download anyway": {
        "pt-PT": "Transferir mesmo assim",
        "es": "Descargar igualmente",
        "fr": "Télécharger quand même",
        "de": "Trotzdem herunterladen",
        "it": "Scarica comunque",
    },
    "Unavailable.": {
        "pt-PT": "Indisponível.",
        "es": "No disponible.",
        "fr": "Indisponible.",
        "de": "Nicht verfügbar.",
        "it": "Non disponibile.",
    },
    "MB/s": {
        # Universal unit — kept verbatim across locales.
        "pt-PT": "MB/s",
        "es": "MB/s",
        "fr": "Mo/s",
        "de": "MB/s",
        "it": "MB/s",
    },
    "Open URL in browser": {
        "pt-PT": "Abrir URL no navegador",
        "es": "Abrir URL en el navegador",
        "fr": "Ouvrir l'URL dans le navigateur",
        "de": "URL im Browser öffnen",
        "it": "Apri URL nel browser",
    },
    "Remove from queue": {
        "pt-PT": "Remover da fila",
        "es": "Quitar de la cola",
        "fr": "Retirer de la file",
        "de": "Aus Warteschlange entfernen",
        "it": "Rimuovi dalla coda",
    },
    "Reveal the downloaded file in Finder.": {
        "pt-PT": "Mostrar o ficheiro transferido no Finder.",
        "es": "Mostrar el archivo descargado en el Finder.",
        "fr": "Afficher le fichier téléchargé dans le Finder.",
        "de": "Heruntergeladene Datei im Finder anzeigen.",
        "it": "Mostra il file scaricato nel Finder.",
    },
    "Reveal the source Markdown in Finder": {
        "pt-PT": "Mostrar o Markdown de origem no Finder",
        "es": "Mostrar el Markdown original en el Finder",
        "fr": "Afficher le Markdown source dans le Finder",
        "de": "Quell-Markdown im Finder anzeigen",
        "it": "Mostra il Markdown originale nel Finder",
    },
    "Email info@splynek.app": {
        # Email address kept verbatim; verb localised.
        "pt-PT": "Enviar e-mail para info@splynek.app",
        "es": "Enviar correo a info@splynek.app",
        "fr": "Envoyer un e-mail à info@splynek.app",
        "de": "E-Mail an info@splynek.app senden",
        "it": "Scrivi a info@splynek.app",
    },
    "Install Chrome extension…": {
        "pt-PT": "Instalar extensão do Chrome…",
        "es": "Instalar extensión de Chrome…",
        "fr": "Installer l'extension Chrome…",
        "de": "Chrome-Erweiterung installieren…",
        "it": "Installa estensione di Chrome…",
    },
    "Install Ollama": {
        "pt-PT": "Instalar o Ollama",
        "es": "Instalar Ollama",
        "fr": "Installer Ollama",
        "de": "Ollama installieren",
        "it": "Installa Ollama",
    },
    "Safari bookmarklets…": {
        "pt-PT": "Bookmarklets do Safari…",
        "es": "Bookmarklets de Safari…",
        "fr": "Bookmarklets Safari…",
        "de": "Safari-Bookmarklets…",
        "it": "Bookmarklet di Safari…",
    },
    "Describe downloads in plain English": {
        "pt-PT": "Descrever transferências em inglês corrente",
        "es": "Describe descargas en inglés sencillo",
        "fr": "Décrivez vos téléchargements en anglais courant",
        "de": "Downloads in einfachem Englisch beschreiben",
        "it": "Descrivi i download in inglese semplice",
    },
    "Best historical throughput for this host.": {
        "pt-PT": "Melhor débito histórico para este servidor.",
        "es": "Mejor velocidad histórica para este servidor.",
        "fr": "Meilleur débit historique pour cet hôte.",
        "de": "Bester historischer Durchsatz für diesen Host.",
        "it": "Miglior velocità storica per questo host.",
    },
    "Per-interface bandwidth cap (applies across all concurrent downloads).": {
        "pt-PT": "Limite de largura de banda por interface (aplica-se a todas as transferências em curso).",
        "es": "Límite de ancho de banda por interfaz (se aplica a todas las descargas simultáneas).",
        "fr": "Limite de bande passante par interface (s'applique à tous les téléchargements simultanés).",
        "de": "Bandbreitenlimit pro Schnittstelle (gilt für alle gleichzeitigen Downloads).",
        "it": "Limite di banda per interfaccia (si applica a tutti i download in corso).",
    },
    "Show details — speedup, per-interface contribution, SHA-256.": {
        "pt-PT": "Mostrar detalhes — aceleração, contribuição por interface, SHA-256.",
        "es": "Mostrar detalles — aceleración, contribución por interfaz, SHA-256.",
        "fr": "Afficher les détails — accélération, contribution par interface, SHA-256.",
        "de": "Details anzeigen — Beschleunigung, Beitrag pro Schnittstelle, SHA-256.",
        "it": "Mostra dettagli — accelerazione, contributo per interfaccia, SHA-256.",
    },
    "vs. best single-path estimate": {
        "pt-PT": "vs. melhor estimativa de caminho único",
        "es": "vs. mejor estimación de ruta única",
        "fr": "vs. meilleure estimation à voie unique",
        "de": "ggü. bester Einzelpfad-Schätzung",
        "it": "vs. miglior stima a percorso singolo",
    },
    "Export the full timeline as CSV.": {
        "pt-PT": "Exportar a cronologia completa como CSV.",
        "es": "Exportar la línea de tiempo completa como CSV.",
        "fr": "Exporter la chronologie complète au format CSV.",
        "de": "Vollständige Zeitleiste als CSV exportieren.",
        "it": "Esporta la cronologia completa come CSV.",
    },
    "Re-query every fleet peer for current downloads": {
        "pt-PT": "Reconsultar cada par da Frota para ver as transferências atuais",
        "es": "Volver a consultar a cada par de la flota por sus descargas actuales",
        "fr": "Réinterroger chaque pair de la flotte sur ses téléchargements actuels",
        "de": "Jeden Flotten-Peer erneut nach aktuellen Downloads abfragen",
        "it": "Interroga di nuovo ogni peer della flotta per i download attuali",
    },
    "Stop sharing this file with other Splyneks on the LAN. The file and history entry are kept; only fleet sharing stops.": {
        "pt-PT": "Parar de partilhar este ficheiro com outros Splyneks na rede local. O ficheiro e a entrada no histórico são mantidos; só a partilha pela Frota termina.",
        "es": "Dejar de compartir este archivo con otros Splyneks en la red local. El archivo y la entrada en el historial se conservan; solo se detiene el uso compartido por la flota.",
        "fr": "Cesser de partager ce fichier avec les autres Splyneks du réseau local. Le fichier et l'entrée d'historique sont conservés ; seul le partage par la flotte s'arrête.",
        "de": "Diese Datei nicht mehr mit anderen Splyneks im LAN teilen. Datei und Verlaufseintrag bleiben erhalten; nur die Flotten-Freigabe wird beendet.",
        "it": "Smetti di condividere questo file con gli altri Splynek nella rete locale. Il file e la voce di cronologia vengono mantenuti; si interrompe solo la condivisione tramite flotta.",
    },
    "Waiting for the fleet listener to bind…": {
        "pt-PT": "À espera que o ouvinte da Frota se ligue…",
        "es": "Esperando a que el escuchador de la flota se vincule…",
        "fr": "En attente de la liaison de l'écouteur de flotte…",
        "de": "Warte, bis der Flotten-Listener gebunden wird…",
        "it": "In attesa che il listener della flotta si colleghi…",
    },
    "Re-queue every failed or cancelled entry. Runs immediately if nothing else is running.": {
        "pt-PT": "Voltar a colocar na fila todas as entradas falhadas ou canceladas. Inicia de imediato se nada estiver em curso.",
        "es": "Volver a poner en cola cada entrada fallida o cancelada. Comienza de inmediato si no hay nada más en marcha.",
        "fr": "Remettre en file toutes les entrées ayant échoué ou annulées. Démarre immédiatement si rien d'autre n'est en cours.",
        "de": "Alle fehlgeschlagenen oder abgebrochenen Einträge erneut einreihen. Startet sofort, wenn nichts anderes läuft.",
        "it": "Rimetti in coda ogni voce fallita o annullata. Parte subito se non c'è nient'altro in esecuzione.",
    },
    "Remove every completed, failed, and cancelled entry. Running and pending entries are kept.": {
        "pt-PT": "Remover todas as entradas concluídas, falhadas e canceladas. As entradas em curso e pendentes são mantidas.",
        "es": "Eliminar todas las entradas completadas, fallidas y canceladas. Las entradas en curso y pendientes se conservan.",
        "fr": "Supprimer toutes les entrées terminées, échouées et annulées. Les entrées en cours et en attente sont conservées.",
        "de": "Alle abgeschlossenen, fehlgeschlagenen und abgebrochenen Einträge entfernen. Laufende und ausstehende Einträge bleiben erhalten.",
        "it": "Rimuovi tutte le voci completate, fallite e annullate. Le voci in esecuzione e in attesa vengono mantenute.",
    },
    "Load queue entries from a JSON file produced by Export.": {
        "pt-PT": "Carregar entradas da fila a partir de um ficheiro JSON produzido pela exportação.",
        "es": "Cargar entradas de la cola desde un archivo JSON producido por Exportar.",
        "fr": "Charger les entrées de la file depuis un fichier JSON produit par l'export.",
        "de": "Warteschlangeneinträge aus einer von Export erzeugten JSON-Datei laden.",
        "it": "Carica le voci della coda da un file JSON prodotto dall'esportazione.",
    },
    "Write the current queue to a JSON file.": {
        "pt-PT": "Escrever a fila atual num ficheiro JSON.",
        "es": "Escribir la cola actual en un archivo JSON.",
        "fr": "Écrire la file actuelle dans un fichier JSON.",
        "de": "Aktuelle Warteschlange in eine JSON-Datei schreiben.",
        "it": "Scrivi la coda attuale in un file JSON.",
    },
    "Only start queued downloads inside a time window — e.g., overnight on home Wi-Fi. Running downloads are never interrupted; the schedule only gates starts.": {
        "pt-PT": "Iniciar transferências em fila apenas dentro de uma janela horária — por exemplo, de noite no Wi-Fi de casa. As transferências em curso nunca são interrompidas; o agendamento controla apenas o arranque.",
        "es": "Iniciar las descargas en cola solo dentro de una ventana horaria — por ejemplo, de noche en el Wi-Fi de casa. Las descargas en curso nunca se interrumpen; la planificación solo regula los inicios.",
        "fr": "Lancer les téléchargements en file uniquement dans une fenêtre horaire — par exemple la nuit sur le Wi-Fi domestique. Les téléchargements en cours ne sont jamais interrompus ; la planification ne contrôle que les démarrages.",
        "de": "Geplante Downloads nur innerhalb eines Zeitfensters starten — z. B. nachts im Heim-WLAN. Laufende Downloads werden nie unterbrochen; der Zeitplan reguliert nur Starts.",
        "it": "Avvia i download in coda solo all'interno di una finestra temporale — ad esempio di notte sul Wi-Fi di casa. I download in corso non vengono mai interrotti; la pianificazione regola solo gli avvii.",
    },
    "Invalidate any QR code you've already shared. CLI / Raycast / Alfred re-pair automatically.": {
        "pt-PT": "Invalidar qualquer código QR que já tenhas partilhado. CLI / Raycast / Alfred voltam a emparelhar automaticamente.",
        "es": "Invalidar cualquier código QR que ya hayas compartido. CLI / Raycast / Alfred se vuelven a emparejar automáticamente.",
        "fr": "Invalider tout code QR déjà partagé. CLI / Raycast / Alfred se réappairent automatiquement.",
        "de": "Bereits geteilten QR-Code ungültig machen. CLI / Raycast / Alfred koppeln sich automatisch neu.",
        "it": "Invalida qualsiasi codice QR già condiviso. CLI / Raycast / Alfred si riassociano automaticamente.",
    },
    "Scan the QR with a phone on the same LAN to submit downloads to this Mac. Read-only state is open to the LAN; submit requires the token embedded in the QR.": {
        "pt-PT": "Lê o código QR com um telemóvel na mesma rede local para submeter transferências a este Mac. O estado de leitura está aberto à rede local; submeter requer o token embutido no QR.",
        "es": "Escanea el QR con un teléfono en la misma red local para enviar descargas a este Mac. El estado de solo lectura está abierto a la red local; enviar requiere el token incrustado en el QR.",
        "fr": "Scannez le QR avec un téléphone sur le même réseau local pour soumettre des téléchargements à ce Mac. L'état en lecture seule est ouvert au réseau local ; la soumission requiert le jeton intégré dans le QR.",
        "de": "Scannen Sie den QR-Code mit einem Telefon im selben LAN, um Downloads an diesen Mac zu übermitteln. Der schreibgeschützte Status ist im LAN offen; das Übermitteln erfordert das im QR eingebettete Token.",
        "it": "Scansiona il QR con un telefono sulla stessa rete locale per inviare download a questo Mac. Lo stato in sola lettura è aperto alla rete locale; l'invio richiede il token incorporato nel QR.",
    },
    "End-User Licence, Privacy Policy, and Acceptable Use — bundled into this app, viewable offline. See the *Legal* sidebar entry.": {
        "pt-PT": "Licença de Utilizador Final, Política de Privacidade e Uso Aceitável — incluídos nesta aplicação, visíveis offline. Vê a entrada *Legal* na barra lateral.",
        "es": "Licencia de Usuario Final, Política de Privacidad y Uso Aceptable — incluidos en esta app, visibles sin conexión. Consulta la entrada *Legal* en la barra lateral.",
        "fr": "Licence Utilisateur Final, Politique de Confidentialité et Usage Acceptable — inclus dans cette app, consultables hors ligne. Voir l'entrée *Legal* dans la barre latérale.",
        "de": "Endnutzerlizenz, Datenschutzrichtlinie und Akzeptable Nutzung — in diese App eingebettet, offline einsehbar. Siehe Eintrag *Legal* in der Seitenleiste.",
        "it": "Licenza per l'Utente Finale, Informativa sulla Privacy e Uso Accettabile — inclusi in questa app, consultabili offline. Vedi la voce *Legal* nella barra laterale.",
    },
    "The three documents above form the complete agreement between you and Splynek's maintainers. If anything is unclear, or if you think a clause needs to change for your specific use, reach out:": {
        "pt-PT": "Os três documentos acima constituem o acordo completo entre ti e os mantenedores do Splynek. Se algo não for claro, ou se achares que uma cláusula precisa de mudar para o teu caso específico, contacta-nos:",
        "es": "Los tres documentos anteriores constituyen el acuerdo completo entre tú y los mantenedores de Splynek. Si algo no está claro, o si crees que alguna cláusula debe cambiar para tu uso específico, ponte en contacto:",
        "fr": "Les trois documents ci-dessus forment l'accord complet entre vous et les mainteneurs de Splynek. Si quoi que ce soit n'est pas clair, ou si vous pensez qu'une clause doit être modifiée pour votre usage spécifique, contactez-nous :",
        "de": "Die drei Dokumente oben bilden die vollständige Vereinbarung zwischen Ihnen und den Maintainern von Splynek. Wenn etwas unklar ist oder Sie eine Klausel für Ihren konkreten Einsatz anpassen möchten, melden Sie sich:",
        "it": "I tre documenti qui sopra costituiscono l'accordo completo tra te e i manutentori di Splynek. Se qualcosa non è chiaro, o se ritieni che una clausola debba cambiare per il tuo uso specifico, contattaci:",
    },
    "These documents are templates provided in good faith. Before deploying Splynek in a context where legal precision matters (business use, enterprise distribution, unusual jurisdictions), have your own counsel review them.": {
        "pt-PT": "Estes documentos são modelos fornecidos de boa-fé. Antes de implementares o Splynek num contexto em que a precisão jurídica seja relevante (uso comercial, distribuição empresarial, jurisdições atípicas), pede a um advogado teu para os rever.",
        "es": "Estos documentos son plantillas proporcionadas de buena fe. Antes de desplegar Splynek en un contexto donde la precisión jurídica sea importante (uso empresarial, distribución corporativa, jurisdicciones atípicas), haz que tu propio abogado los revise.",
        "fr": "Ces documents sont des modèles fournis de bonne foi. Avant de déployer Splynek dans un contexte où la précision juridique compte (usage professionnel, distribution en entreprise, juridictions atypiques), faites-les relire par votre propre conseil.",
        "de": "Diese Dokumente sind Vorlagen, die nach bestem Wissen bereitgestellt werden. Bevor Sie Splynek in einem Kontext einsetzen, in dem juristische Präzision wichtig ist (geschäftliche Nutzung, Unternehmensverteilung, ungewöhnliche Jurisdiktionen), lassen Sie sie von Ihrem eigenen Rechtsbeistand prüfen.",
        "it": "Questi documenti sono modelli forniti in buona fede. Prima di adottare Splynek in un contesto in cui la precisione legale è rilevante (uso commerciale, distribuzione aziendale, giurisdizioni atipiche), fai esaminare i documenti da un legale di tua fiducia.",
    },
    "Some publishers list a **checksum** (also called a *hash* or *SHA-256*) next to their download link. It's a fingerprint of the original file. If you have one, paste it below and Splynek will refuse to save the download if even a single byte doesn't match — protects you against corrupted downloads or files swapped at a malicious mirror.": {
        "pt-PT": "Alguns editores indicam uma **soma de controlo** (também chamada *hash* ou *SHA-256*) ao lado do link de transferência. É uma impressão digital do ficheiro original. Se tiveres uma, cola-a abaixo e o Splynek recusa-se a guardar a transferência se um único byte não corresponder — protege-te contra transferências corrompidas ou ficheiros trocados num espelho malicioso.",
        "es": "Algunos autores publican una **suma de comprobación** (también llamada *hash* o *SHA-256*) junto al enlace de descarga. Es la huella digital del archivo original. Si tienes una, pégala abajo y Splynek se negará a guardar la descarga si aunque sea un solo byte no coincide — te protege contra descargas corruptas o archivos sustituidos en un mirror malicioso.",
        "fr": "Certains éditeurs publient une **somme de contrôle** (aussi appelée *hash* ou *SHA-256*) à côté de leur lien de téléchargement. C'est une empreinte du fichier original. Si vous en avez une, collez-la ci-dessous et Splynek refusera d'enregistrer le téléchargement si un seul octet diffère — vous protège contre les téléchargements corrompus ou les fichiers substitués sur un miroir malveillant.",
        "de": "Manche Herausgeber geben eine **Prüfsumme** (auch *Hash* oder *SHA-256* genannt) neben dem Download-Link an. Sie ist ein Fingerabdruck der Originaldatei. Wenn Sie eine haben, fügen Sie sie unten ein und Splynek weigert sich, den Download zu speichern, sobald auch nur ein einziges Byte abweicht — schützt Sie vor beschädigten Downloads oder bei einem böswilligen Spiegel ausgetauschten Dateien.",
        "it": "Alcuni editori pubblicano un **checksum** (chiamato anche *hash* o *SHA-256*) accanto al link di download. È un'impronta del file originale. Se ne hai uno, incollalo qui sotto e Splynek si rifiuterà di salvare il download anche se differisce di un solo byte — ti protegge da download corrotti o file sostituiti su un mirror malevolo.",
    },
    "Splynek looks up hostnames over Cloudflare's encrypted DNS (DNS-over-HTTPS, port 443). Stops your internet provider from seeing which sites you download from. Tiny latency cost on the first request to each hostname.": {
        "pt-PT": "O Splynek resolve nomes de servidor através do DNS encriptado da Cloudflare (DNS-over-HTTPS, porta 443). Impede que o teu fornecedor de internet veja de que sites transferes. Pequeno custo de latência no primeiro pedido a cada nome.",
        "es": "Splynek resuelve los nombres de servidor a través del DNS cifrado de Cloudflare (DNS-over-HTTPS, puerto 443). Evita que tu proveedor de internet vea de qué sitios descargas. Pequeño coste de latencia en la primera solicitud a cada nombre.",
        "fr": "Splynek résout les noms d'hôte via le DNS chiffré de Cloudflare (DNS-over-HTTPS, port 443). Empêche votre fournisseur d'accès de voir depuis quels sites vous téléchargez. Léger surcoût de latence à la première requête vers chaque nom.",
        "de": "Splynek löst Hostnamen über Cloudflares verschlüsseltes DNS auf (DNS-over-HTTPS, Port 443). Verhindert, dass Ihr Internetanbieter sieht, von welchen Seiten Sie herunterladen. Kleine Latenzkosten bei der ersten Anfrage zu jedem Hostnamen.",
        "it": "Splynek risolve i nomi host tramite il DNS cifrato di Cloudflare (DNS-over-HTTPS, porta 443). Impedisce al tuo provider di vedere da quali siti scarichi. Piccolo costo di latenza alla prima richiesta verso ogni nome.",
    },
    "Splynek understands two extra file formats some publishers ship next to their main download. Pick one if you've got it; otherwise skip — they're optional speed-ups, not required.": {
        "pt-PT": "O Splynek reconhece dois formatos extra que alguns editores publicam junto à transferência principal. Escolhe um se tiveres; caso contrário, ignora — são acelerações opcionais, não obrigatórias.",
        "es": "Splynek reconoce dos formatos extra que algunos autores publican junto a su descarga principal. Elige uno si lo tienes; si no, omítelo — son aceleradores opcionales, no obligatorios.",
        "fr": "Splynek comprend deux formats supplémentaires que certains éditeurs publient à côté de leur téléchargement principal. Choisissez-en un si vous en disposez ; sinon, passez — ce sont des accélérations facultatives, pas obligatoires.",
        "de": "Splynek versteht zwei zusätzliche Dateiformate, die manche Herausgeber neben dem Hauptdownload veröffentlichen. Wählen Sie eines, wenn Sie es haben; ansonsten überspringen — sie sind optionale Beschleuniger, nicht erforderlich.",
        "it": "Splynek comprende due formati aggiuntivi che alcuni editori pubblicano accanto al download principale. Scegline uno se ce l'hai; altrimenti ignora — sono acceleratori facoltativi, non obbligatori.",
    },
    "A .metalink / .meta4 file is an XML list of mirror URLs + checksums some publishers (Linux distros, Apache, KDE) ship next to their main download. Splynek fans the download across every mirror you've got in parallel — one mirror per network interface — then verifies the assembled file against the publisher's checksum.": {
        "pt-PT": "Um ficheiro .metalink / .meta4 é uma lista XML de URLs de espelhos + somas de controlo que alguns editores (distribuições Linux, Apache, KDE) publicam junto à transferência principal. O Splynek distribui a transferência por todos os espelhos disponíveis em paralelo — um espelho por interface de rede — e depois verifica o ficheiro montado contra a soma de controlo do editor.",
        "es": "Un archivo .metalink / .meta4 es una lista XML de URLs de mirrors + sumas de comprobación que algunos autores (distros de Linux, Apache, KDE) publican junto a su descarga principal. Splynek distribuye la descarga entre todos los mirrors disponibles en paralelo — un mirror por interfaz de red — y luego verifica el archivo ensamblado contra la suma de comprobación del autor.",
        "fr": "Un fichier .metalink / .meta4 est une liste XML d'URLs de miroirs + sommes de contrôle que certains éditeurs (distros Linux, Apache, KDE) publient à côté de leur téléchargement principal. Splynek répartit le téléchargement sur tous les miroirs disponibles en parallèle — un miroir par interface réseau — puis vérifie le fichier assemblé avec la somme de contrôle de l'éditeur.",
        "de": "Eine .metalink / .meta4-Datei ist eine XML-Liste von Spiegel-URLs + Prüfsummen, die manche Herausgeber (Linux-Distros, Apache, KDE) neben dem Hauptdownload veröffentlichen. Splynek verteilt den Download parallel auf alle verfügbaren Spiegel — ein Spiegel pro Netzwerkschnittstelle — und prüft anschließend die zusammengesetzte Datei gegen die Prüfsumme des Herausgebers.",
        "it": "Un file .metalink / .meta4 è un elenco XML di URL di mirror + checksum che alcuni editori (distro Linux, Apache, KDE) pubblicano accanto al download principale. Splynek distribuisce il download su tutti i mirror disponibili in parallelo — un mirror per interfaccia di rete — quindi verifica il file assemblato confrontandolo con il checksum dell'editore.",
    },
    "A .splynek-manifest is a chunk-by-chunk fingerprint of the original file. With one loaded, Splynek verifies each piece as it arrives — bad bytes get re-fetched on the spot instead of waiting until the whole download finishes to discover something corrupted. Useful for very large files (10+ GB).": {
        "pt-PT": "Um .splynek-manifest é uma impressão digital pedaço-a-pedaço do ficheiro original. Com um carregado, o Splynek verifica cada peça assim que chega — bytes inválidos são re-obtidos na hora, em vez de esperar até ao fim da transferência para descobrir que algo está corrompido. Útil para ficheiros muito grandes (10+ GB).",
        "es": "Un .splynek-manifest es una huella digital trozo a trozo del archivo original. Con uno cargado, Splynek verifica cada pieza a medida que llega — los bytes erróneos se vuelven a descargar al instante, en lugar de esperar a que termine la descarga para descubrir que algo está corrupto. Útil para archivos muy grandes (10+ GB).",
        "fr": "Un .splynek-manifest est une empreinte morceau par morceau du fichier original. Avec un manifeste chargé, Splynek vérifie chaque pièce à mesure qu'elle arrive — les octets erronés sont retéléchargés sur place au lieu d'attendre la fin du téléchargement pour découvrir une corruption. Utile pour les fichiers très volumineux (10+ Go).",
        "de": "Ein .splynek-manifest ist ein stückweiser Fingerabdruck der Originaldatei. Mit einem geladenen Manifest verifiziert Splynek jedes Stück, sobald es eintrifft — fehlerhafte Bytes werden sofort neu geladen, statt bis zum Ende des Downloads zu warten, um eine Beschädigung zu entdecken. Nützlich für sehr große Dateien (10+ GB).",
        "it": "Un .splynek-manifest è un'impronta digitale pezzo per pezzo del file originale. Con uno caricato, Splynek verifica ogni parte mentre arriva — i byte errati vengono riscaricati sul momento, invece di attendere la fine del download per scoprire una corruzione. Utile per file molto grandi (10+ GB).",
    },
    # Both source literals (line 95 in RecipeView.swift uses real curly
    # quotes, line 259 in ConciergeView.swift uses \u{201C}/\u{201D}
    # escapes) collapse to the same Swift string, so the catalog key uses
    # the actual U+201C / U+201D characters.
    "Type “the latest Ubuntu ISO” instead of a URL. Splynek Pro feature — powered by a local LLM (LM Studio or Ollama) on your Mac.": {
        "pt-PT": "Escreve “o ISO mais recente do Ubuntu” em vez de um URL. Funcionalidade do Splynek Pro — alimentada por um LLM local (LM Studio ou Ollama) no teu Mac.",
        "es": "Escribe “la última ISO de Ubuntu” en lugar de una URL. Función de Splynek Pro — impulsada por un LLM local (LM Studio u Ollama) en tu Mac.",
        "fr": "Tapez “la dernière ISO Ubuntu” au lieu d'une URL. Fonctionnalité Splynek Pro — propulsée par un LLM local (LM Studio ou Ollama) sur votre Mac.",
        "de": "Tippen Sie “das neueste Ubuntu-ISO” statt einer URL. Splynek-Pro-Funktion — angetrieben von einem lokalen LLM (LM Studio oder Ollama) auf Ihrem Mac.",
        "it": "Scrivi “l'ultima ISO di Ubuntu” invece di un URL. Funzione di Splynek Pro — basata su un LLM locale (LM Studio o Ollama) sul tuo Mac.",
    },
    "Paste English like “the latest Ubuntu ISO” and the local LLM returns a direct URL. Natural-language history search too. Runs entirely on this Mac.": {
        "pt-PT": "Cola inglês como “o ISO mais recente do Ubuntu” e o LLM local devolve um URL direto. Pesquisa do histórico em linguagem natural também. Tudo a correr neste Mac.",
        "es": "Pega inglés como “la última ISO de Ubuntu” y el LLM local devuelve una URL directa. Búsqueda del historial en lenguaje natural también. Todo se ejecuta en este Mac.",
        "fr": "Collez de l'anglais comme “la dernière ISO Ubuntu” et le LLM local renvoie une URL directe. Recherche d'historique en langage naturel aussi. Tout s'exécute sur ce Mac.",
        "de": "Fügen Sie englischen Text wie “das neueste Ubuntu-ISO” ein und das lokale LLM liefert eine direkte URL. Auch Verlaufssuche in natürlicher Sprache. Läuft komplett auf diesem Mac.",
        "it": "Incolla inglese come “l'ultima ISO di Ubuntu” e l'LLM locale restituisce un URL diretto. Anche ricerca cronologia in linguaggio naturale. Tutto in esecuzione su questo Mac.",
    },

    # ── Round 8 — interpolated strings keyed by format spec ─────────
    # These match SwiftUI's runtime-converted catalog lookup form
    # (each `\(expr)` becomes %@ for strings or %lld for integers;
    # multi-arg strings use positional %1$@ / %2$lld so translators
    # can rearrange).  See `_swift_interp_to_format_specs` in
    # find-missing-translations.py for the matching heuristic.

    # Single-arg, single-locale-typical patterns first.
    "Fetch %@ using Splynek's own multi-interface download engine.": {
        "pt-PT": "Obter %@ com o próprio motor de transferência multi-interface do Splynek.",
        "es": "Obtener %@ con el propio motor de descarga multi-interfaz de Splynek.",
        "fr": "Récupérer %@ avec le moteur de téléchargement multi-interfaces propre à Splynek.",
        "de": "%@ mit Splyneks eigener Multi-Schnittstellen-Download-Engine abrufen.",
        "it": "Scarica %@ con il motore di download multi-interfaccia di Splynek.",
    },
    "Version %@ is available": {
        "pt-PT": "Está disponível a versão %@",
        "es": "La versión %@ está disponible",
        "fr": "La version %@ est disponible",
        "de": "Version %@ ist verfügbar",
        "it": "È disponibile la versione %@",
    },
    "Version %@": {
        "pt-PT": "Versão %@",
        "es": "Versión %@",
        "fr": "Version %@",
        "de": "Version %@",
        "it": "Versione %@",
    },
    "v%@": {
        # Universal "v1.6.2" prefix — kept as-is across locales.
        "pt-PT": "v%@",
        "es": "v%@",
        "fr": "v%@",
        "de": "v%@",
        "it": "v%@",
    },
    "Clear %lld finished": {
        "pt-PT": "Limpar %lld concluídas",
        "es": "Limpiar %lld terminadas",
        "fr": "Effacer %lld terminés",
        "de": "%lld abgeschlossene löschen",
        "it": "Cancella %lld completate",
    },
    "Retry %lld failed": {
        "pt-PT": "Tentar de novo %lld falhadas",
        "es": "Reintentar %lld fallidas",
        "fr": "Réessayer %lld échoués",
        "de": "%lld fehlgeschlagene erneut versuchen",
        "it": "Riprova %lld fallite",
    },
    "Could not load %@ from the app bundle. Please report this as a packaging issue.": {
        "pt-PT": "Não foi possível carregar %@ a partir do pacote da aplicação. Reporta isto como um problema de empacotamento.",
        "es": "No se pudo cargar %@ desde el paquete de la app. Por favor, repórtalo como un problema de empaquetado.",
        "fr": "Impossible de charger %@ depuis le bundle de l'app. Veuillez signaler ce problème d'empaquetage.",
        "de": "%@ konnte nicht aus dem App-Bundle geladen werden. Bitte melden Sie dies als Paketierungsproblem.",
        "it": "Impossibile caricare %@ dal bundle dell'app. Segnalalo come problema di packaging.",
    },
    "Install %@ via Splynek": {
        "pt-PT": "Instalar %@ via Splynek",
        "es": "Instalar %@ con Splynek",
        "fr": "Installer %@ via Splynek",
        "de": "%@ über Splynek installieren",
        "it": "Installa %@ tramite Splynek",
    },
    "Visit %@ homepage in browser": {
        "pt-PT": "Visitar a página inicial de %@ no navegador",
        "es": "Visitar la página de inicio de %@ en el navegador",
        "fr": "Visiter la page d'accueil de %@ dans le navigateur",
        "de": "Startseite von %@ im Browser öffnen",
        "it": "Visita la home page di %@ nel browser",
    },
    "Next opening %@.": {
        "pt-PT": "Próxima abertura %@.",
        "es": "Próxima apertura %@.",
        "fr": "Prochaine ouverture %@.",
        "de": "Nächste Öffnung %@.",
        "it": "Prossima apertura %@.",
    },
    "Port %lld": {
        "pt-PT": "Porta %lld",
        "es": "Puerto %lld",
        "fr": "Port %lld",
        "de": "Port %lld",
        "it": "Porta %lld",
    },
    "Step %lld of 3": {
        "pt-PT": "Passo %lld de 3",
        "es": "Paso %lld de 3",
        "fr": "Étape %lld sur 3",
        "de": "Schritt %lld von 3",
        "it": "Passaggio %lld di 3",
    },
    "Shareable (%lld):": {
        "pt-PT": "Partilháveis (%lld):",
        "es": "Compartibles (%lld):",
        "fr": "Partageables (%lld) :",
        "de": "Teilbar (%lld):",
        "it": "Condivisibili (%lld):",
    },
    "This download has %lld fleet-peer mirror(s) cooperating on the LAN.": {
        "pt-PT": "Esta transferência tem %lld espelho(s) na Frota a cooperar na rede local.",
        "es": "Esta descarga tiene %lld mirror(s) de la flota cooperando en la red local.",
        "fr": "Ce téléchargement a %lld miroir(s) de flotte coopérant sur le réseau local.",
        "de": "Dieser Download hat %lld Flotten-Peer-Spiegel, die im LAN kooperieren.",
        "it": "Questo download ha %lld mirror della flotta che cooperano sulla rete locale.",
    },
    "This download is %@. Continue?": {
        "pt-PT": "Esta transferência tem %@. Continuar?",
        "es": "Esta descarga es de %@. ¿Continuar?",
        "fr": "Ce téléchargement fait %@. Continuer ?",
        "de": "Dieser Download ist %@. Fortfahren?",
        "it": "Questo download è di %@. Continuare?",
    },
    "Today you've already used %1$@ from %2$@, past your %3$@ daily cap. Downloading anyway will clear today's cap for this host.": {
        "pt-PT": "Hoje já usaste %1$@ de %2$@, ultrapassando o limite diário de %3$@. Transferir mesmo assim limpa o limite de hoje para este servidor.",
        "es": "Hoy ya has usado %1$@ de %2$@, superando tu límite diario de %3$@. Descargar igualmente borrará el límite de hoy para este servidor.",
        "fr": "Vous avez déjà utilisé %1$@ depuis %2$@ aujourd'hui, dépassant votre plafond quotidien de %3$@. Télécharger quand même réinitialisera le plafond du jour pour cet hôte.",
        "de": "Sie haben heute bereits %1$@ von %2$@ verbraucht und damit Ihr Tageslimit von %3$@ überschritten. Trotzdem herunterzuladen setzt das heutige Limit für diesen Host zurück.",
        "it": "Oggi hai già usato %1$@ da %2$@, superando il limite giornaliero di %3$@. Scaricare comunque azzererà il limite di oggi per questo host.",
    },
    "Trust score %1$lld of 100, level %2$@": {
        # Accessibility label.
        "pt-PT": "Pontuação de confiança %1$lld em 100, nível %2$@",
        "es": "Puntuación de confianza %1$lld de 100, nivel %2$@",
        "fr": "Score de confiance %1$lld sur 100, niveau %2$@",
        "de": "Vertrauenswert %1$lld von 100, Stufe %2$@",
        "it": "Punteggio di affidabilità %1$lld su 100, livello %2$@",
    },
    "Unavailable: %@": {
        "pt-PT": "Indisponível: %@",
        "es": "No disponible: %@",
        "fr": "Indisponible : %@",
        "de": "Nicht verfügbar: %@",
        "it": "Non disponibile: %@",
    },
    "%1$@, %2$@ severity: %3$@": {
        # Accessibility label for trust concern (axis, severity, summary).
        "pt-PT": "%1$@, gravidade %2$@: %3$@",
        "es": "%1$@, gravedad %2$@: %3$@",
        "fr": "%1$@, gravité %2$@ : %3$@",
        "de": "%1$@, Schweregrad %2$@: %3$@",
        "it": "%1$@, gravità %2$@: %3$@",
    },
    "%1$lld chunks · %2$@": {
        "pt-PT": "%1$lld pedaços · %2$@",
        "es": "%1$lld fragmentos · %2$@",
        "fr": "%1$lld morceaux · %2$@",
        "de": "%1$lld Stücke · %2$@",
        "it": "%1$lld pezzi · %2$@",
    },
    "%lld chunks": {
        "pt-PT": "%lld pedaços",
        "es": "%lld fragmentos",
        "fr": "%lld morceaux",
        "de": "%lld Stücke",
        "it": "%lld pezzi",
    },
    "%1$@ · %2$@ · %3$@ ago": {
        # History match line: filename · size · time-ago.
        "pt-PT": "%1$@ · %2$@ · há %3$@",
        "es": "%1$@ · %2$@ · hace %3$@",
        "fr": "%1$@ · %2$@ · il y a %3$@",
        "de": "%1$@ · %2$@ · vor %3$@",
        "it": "%1$@ · %2$@ · %3$@ fa",
    },
    "%lld days": {
        "pt-PT": "%lld dias",
        "es": "%lld días",
        "fr": "%lld jours",
        "de": "%lld Tage",
        "it": "%lld giorni",
    },
    "%1$@ — next opening %2$@.": {
        "pt-PT": "%1$@ — próxima abertura %2$@.",
        "es": "%1$@ — próxima apertura %2$@.",
        "fr": "%1$@ — prochaine ouverture %2$@.",
        "de": "%1$@ — nächste Öffnung %2$@.",
        "it": "%1$@ — prossima apertura %2$@.",
    },
    "%1$lld of %2$lld": {
        # History "X of Y" filter results.
        "pt-PT": "%1$lld de %2$lld",
        "es": "%1$lld de %2$lld",
        "fr": "%1$lld sur %2$lld",
        "de": "%1$lld von %2$lld",
        "it": "%1$lld di %2$lld",
    },
    "of %@": {
        # Bytes-of-total: "5 MB of 100 MB".
        "pt-PT": "de %@",
        "es": "de %@",
        "fr": "sur %@",
        "de": "von %@",
        "it": "di %@",
    },
    "saved %@": {
        # "saved 8.2 s" — time saved by multi-interface aggregation.
        "pt-PT": "poupados %@",
        "es": "ahorrado %@",
        "fr": "économisés %@",
        "de": "%@ gespart",
        "it": "risparmiati %@",
    },
    "took %@": {
        # "took 14.3 s" — total elapsed time.
        "pt-PT": "demorou %@",
        "es": "tardó %@",
        "fr": "a pris %@",
        "de": "dauerte %@",
        "it": "impiegato %@",
    },

    # ── v1.8 InstallView ────────────────────────────────────────────
    "Drop a .dmg, .zip, or .app here": {
        "pt-PT": "Larga aqui um .dmg, .zip ou .app",
        "es": "Suelta aquí un .dmg, .zip o .app",
        "fr": "Déposez ici un .dmg, .zip ou .app",
        "de": "Legen Sie hier ein .dmg, .zip oder .app ab",
        "it": "Trascina qui un .dmg, .zip o .app",
    },
    "Or click to pick a file.": {
        "pt-PT": "Ou clica para escolher um ficheiro.",
        "es": "O haz clic para elegir un archivo.",
        "fr": "Ou cliquez pour choisir un fichier.",
        "de": "Oder klicken, um eine Datei auszuwählen.",
        "it": "Oppure clicca per scegliere un file.",
    },
    "Choose file…": {
        "pt-PT": "Escolher ficheiro…",
        "es": "Elegir archivo…",
        "fr": "Choisir un fichier…",
        "de": "Datei auswählen…",
        "it": "Scegli file…",
    },
    "Double-click to launch — Splynek never auto-runs an installed binary.": {
        "pt-PT": "Duplo clique para abrir — o Splynek nunca executa automaticamente um binário instalado.",
        "es": "Haz doble clic para abrir — Splynek nunca ejecuta automáticamente un binario instalado.",
        "fr": "Double-cliquez pour lancer — Splynek n'exécute jamais automatiquement un binaire installé.",
        "de": "Doppelklicken zum Starten — Splynek führt eine installierte Binärdatei niemals automatisch aus.",
        "it": "Doppio clic per avviare — Splynek non esegue mai automaticamente un binario installato.",
    },

    # ── v1.8 Install pipeline stage labels + card titles ────────────
    "Pipeline": {
        "pt-PT": "Pipeline",
        "es": "Pipeline",
        "fr": "Pipeline",
        "de": "Pipeline",
        "it": "Pipeline",
    },
    "Resolving": {
        "pt-PT": "A resolver",
        "es": "Resolviendo",
        "fr": "Résolution",
        "de": "Auflösen",
        "it": "Risoluzione",
    },
    "Trust check": {
        "pt-PT": "Verificação de Confiança",
        "es": "Verificación de Confianza",
        "fr": "Contrôle Confiance",
        "de": "Vertrauensprüfung",
        "it": "Controllo Affidabilità",
    },
    "Sovereignty check": {
        "pt-PT": "Verificação de Soberania",
        "es": "Verificación de Soberanía",
        "fr": "Contrôle Souveraineté",
        "de": "Souveränitätsprüfung",
        "it": "Controllo Sovranità",
    },
    "Verifying": {
        "pt-PT": "A verificar",
        "es": "Verificando",
        "fr": "Vérification",
        "de": "Überprüfung",
        "it": "Verifica",
    },
    "Installing": {
        "pt-PT": "A instalar",
        "es": "Instalando",
        "fr": "Installation",
        "de": "Installation",
        "it": "Installazione",
    },
    "Registering": {
        "pt-PT": "A registar",
        "es": "Registrando",
        "fr": "Enregistrement",
        "de": "Registrierung",
        "it": "Registrazione",
    },
    "Ready to install": {
        "pt-PT": "Pronto para instalar",
        "es": "Listo para instalar",
        "fr": "Prêt à installer",
        "de": "Bereit zur Installation",
        "it": "Pronto per l'installazione",
    },
    "Installed": {
        "pt-PT": "Instalado",
        "es": "Instalado",
        "fr": "Installé",
        "de": "Installiert",
        "it": "Installato",
    },
    "Install failed": {
        "pt-PT": "Instalação falhou",
        "es": "Falló la instalación",
        "fr": "Échec de l'installation",
        "de": "Installation fehlgeschlagen",
        "it": "Installazione non riuscita",
    },
    "Installed via Splynek (%lld)": {
        "pt-PT": "Instalado via Splynek (%lld)",
        "es": "Instalado con Splynek (%lld)",
        "fr": "Installé via Splynek (%lld)",
        "de": "Über Splynek installiert (%lld)",
        "it": "Installato tramite Splynek (%lld)",
    },

    # ── v1.8.3 InstallView auto-update controls ─────────────────────
    "Auto-update": {
        "pt-PT": "Atualização automática",
        "es": "Auto-actualizar",
        "fr": "Mise à jour automatique",
        "de": "Auto-Update",
        "it": "Aggiornamento automatico",
    },
    "Check now": {
        "pt-PT": "Verificar agora",
        "es": "Comprobar ahora",
        "fr": "Vérifier maintenant",
        "de": "Jetzt prüfen",
        "it": "Controlla ora",
    },
    "When on, Splynek re-runs the installer pipeline every 6 hours and replaces this app if the publisher's URL serves new bytes.": {
        "pt-PT": "Quando ativo, o Splynek volta a executar a pipeline do instalador a cada 6 horas e substitui esta aplicação se o URL do editor publicar novos bytes.",
        "es": "Cuando está activo, Splynek vuelve a ejecutar el pipeline del instalador cada 6 horas y reemplaza esta app si la URL del autor sirve nuevos bytes.",
        "fr": "Quand actif, Splynek relance le pipeline d'installation toutes les 6 heures et remplace cette app si l'URL de l'éditeur sert de nouveaux octets.",
        "de": "Wenn aktiv, führt Splynek alle 6 Stunden die Installer-Pipeline erneut aus und ersetzt diese App, sobald die URL des Herausgebers neue Bytes liefert.",
        "it": "Se attivo, Splynek riesegue la pipeline di installazione ogni 6 ore e sostituisce questa app se l'URL dell'editore serve nuovi byte.",
    },

    # ── v1.9.7 Household swarm token (Settings card) ────────────────
    "Set the same string on every Mac in your household to let them share download bytes over the LAN. Empty disables peer-to-peer transfers; phone QR + same-Mac flows still work.": {
        "pt-PT": "Define a mesma palavra em todos os Macs da tua casa para partilharem bytes de transferência pela rede local. Vazio desactiva as transferências entre pares; QR no telemóvel e fluxos no mesmo Mac continuam a funcionar.",
        "es": "Define la misma cadena en todos los Mac de tu hogar para que compartan bytes de descarga por la red local. Vacío desactiva las transferencias entre pares; los flujos con QR en el móvil y dentro del mismo Mac siguen funcionando.",
        "fr": "Définissez la même chaîne sur chaque Mac de votre foyer pour qu'ils partagent les octets de téléchargement sur le réseau local. Vide désactive les transferts entre pairs ; les flux QR depuis un téléphone et au sein d'un même Mac continuent de fonctionner.",
        "de": "Setzen Sie auf jedem Mac Ihres Haushalts dieselbe Zeichenfolge, damit sie Download-Bytes im LAN teilen. Leer deaktiviert Peer-to-Peer-Übertragungen; Telefon-QR + Selbst-Mac-Abläufe funktionieren weiterhin.",
        "it": "Imposta la stessa stringa su ogni Mac della tua famiglia per condividere byte di download sulla rete locale. Vuoto disattiva i trasferimenti tra peer; i flussi con QR da telefono e sullo stesso Mac continuano a funzionare.",
    },
    "Best practice: pick a short memorable phrase, type it on each Mac. Every chunk is still SHA-256 verified before it lands on disk — a malicious peer cannot inject corrupt bytes.": {
        "pt-PT": "Boa prática: escolhe uma frase curta e fácil de memorizar, e digita-a em cada Mac. Cada pedaço é verificado por SHA-256 antes de chegar ao disco — um par malicioso não pode injectar bytes corrompidos.",
        "es": "Buena práctica: elige una frase corta y memorable, y escríbela en cada Mac. Cada fragmento se verifica con SHA-256 antes de aterrizar en el disco — un par malicioso no puede inyectar bytes corruptos.",
        "fr": "Bonne pratique : choisissez une phrase courte et mémorable, tapez-la sur chaque Mac. Chaque morceau est vérifié par SHA-256 avant d'atterrir sur le disque — un pair malveillant ne peut pas injecter d'octets corrompus.",
        "de": "Best Practice: Wählen Sie eine kurze, einprägsame Phrase und tippen Sie sie auf jedem Mac ein. Jeder Block wird per SHA-256 verifiziert, bevor er auf der Festplatte landet — ein bösartiger Peer kann keine beschädigten Bytes einschleusen.",
        "it": "Buona pratica: scegli una frase corta e memorabile, e digitala su ogni Mac. Ogni blocco è verificato con SHA-256 prima di atterrare sul disco — un peer malevolo non può iniettare byte corrotti.",
    },
    "Household swarm token": {
        "pt-PT": "Token partilhado da Frota",
        "es": "Token compartido del hogar",
        "fr": "Jeton partagé du foyer",
        "de": "Haushalts-Swarm-Token",
        "it": "Token condiviso della casa",
    },
    "Shared token (any string)": {
        "pt-PT": "Token partilhado (qualquer texto)",
        "es": "Token compartido (cualquier texto)",
        "fr": "Jeton partagé (n'importe quel texte)",
        "de": "Geteilter Token (beliebige Zeichenfolge)",
        "it": "Token condiviso (qualsiasi stringa)",
    },
    "Clear": {
        "pt-PT": "Limpar",
        "es": "Borrar",
        "fr": "Effacer",
        "de": "Löschen",
        "it": "Cancella",
    },
    "OFF": {
        "pt-PT": "DESL.",
        "es": "DESACT.",
        "fr": "DÉSACT.",
        "de": "AUS",
        "it": "DISATT.",
    },
    "ACTIVE": {
        "pt-PT": "ATIVO",
        "es": "ACTIVO",
        "fr": "ACTIF",
        "de": "AKTIV",
        "it": "ATTIVO",
    },

    # ── v1.9.x InstallView gaps caught by the de+fr visual sweep ─────
    "Drop a .dmg, .zip, or .app onto Splynek and we'll verify, Trust-check, and install it. The user double-clicks to launch — Splynek never auto-runs an installed binary.": {
        "pt-PT": "Larga um .dmg, .zip ou .app sobre o Splynek e ele verifica-o, faz a verificação de Confiança e instala-o. O utilizador faz duplo clique para abrir — o Splynek nunca executa automaticamente um binário instalado.",
        "es": "Suelta un .dmg, .zip o .app sobre Splynek y nosotros lo verificamos, comprobamos su Confianza e instalamos. Tú haces doble clic para abrirlo — Splynek nunca ejecuta automáticamente un binario instalado.",
        "fr": "Déposez un .dmg, .zip ou .app sur Splynek et nous le vérifierons, contrôlerons sa Confiance et l'installerons. L'utilisateur double-clique pour le lancer — Splynek n'exécute jamais automatiquement un binaire installé.",
        "de": "Legen Sie eine .dmg, .zip oder .app auf Splynek ab — wir überprüfen, Vertrauens-prüfen und installieren sie. Der Benutzer doppelklickt zum Starten — Splynek führt eine installierte Binärdatei niemals automatisch aus.",
        "it": "Trascina un .dmg, .zip o .app su Splynek e noi la verificheremo, controlleremo l'Affidabilità e la installeremo. L'utente fa doppio clic per avviarla — Splynek non esegue mai automaticamente un binario installato.",
    },
    "Auto-update activity": {
        "pt-PT": "Atividade de atualização automática",
        "es": "Actividad de auto-actualización",
        "fr": "Activité de mise à jour automatique",
        "de": "Auto-Update-Aktivität",
        "it": "Attività di aggiornamento automatico",
    },
    "No apps opted in to auto-update. Toggle one above to enable.": {
        "pt-PT": "Nenhuma aplicação optou por atualização automática. Ativa uma acima para ligar.",
        "es": "Ninguna app optó por la auto-actualización. Activa una arriba para habilitarla.",
        "fr": "Aucune app n'a opté pour la mise à jour automatique. Activez-en une ci-dessus pour l'activer.",
        "de": "Keine Apps haben sich für Auto-Updates angemeldet. Schalten Sie oben eine ein, um sie zu aktivieren.",
        "it": "Nessuna app ha optato per l'aggiornamento automatico. Attivane una sopra per abilitarla.",
    },
    "All %lld auto-updating apps are current.": {
        "pt-PT": "Todas as %lld aplicações com atualização automática estão atualizadas.",
        "es": "Las %lld apps con auto-actualización están al día.",
        "fr": "Toutes les %lld apps en mise à jour automatique sont à jour.",
        "de": "Alle %lld Auto-Update-Apps sind aktuell.",
        "it": "Tutte le %lld app in aggiornamento automatico sono aggiornate.",
    },
    "Last sweep: %1$lld update(s), %2$lld error(s) across %3$lld candidate(s).": {
        "pt-PT": "Última verificação: %1$lld atualização(ões), %2$lld erro(s) em %3$lld candidato(s).",
        "es": "Última pasada: %1$lld actualización(es), %2$lld error(es) en %3$lld candidato(s).",
        "fr": "Dernier passage : %1$lld mise(s) à jour, %2$lld erreur(s) sur %3$lld candidat(s).",
        "de": "Letzter Durchlauf: %1$lld Update(s), %2$lld Fehler bei %3$lld Kandidat(en).",
        "it": "Ultima scansione: %1$lld aggiornamento/i, %2$lld errore/i su %3$lld candidato/i.",
    },
    "%lld app(s) opted in. No sweep yet — periodic runs every 6 hours.": {
        "pt-PT": "%lld aplicação(ões) optou(aram) pela atualização. Sem verificação ainda — execuções periódicas a cada 6 horas.",
        "es": "%lld app(s) optaron. Aún sin pasada — ejecuciones periódicas cada 6 horas.",
        "fr": "%lld app(s) en mise à jour automatique. Aucun passage encore — exécutions périodiques toutes les 6 heures.",
        "de": "%lld App(s) angemeldet. Noch kein Durchlauf — periodische Läufe alle 6 Stunden.",
        "it": "%lld app abilitate. Ancora nessuna scansione — esecuzioni periodiche ogni 6 ore.",
    },

    # ── v1.9.x — audit catch-up after extending the regex set to ────
    # recognise ContextCard / TitledCard / StatusPill / EmptyStateView
    # / MetricView named-parameter literals.  49 strings across all
    # tabs were rendering English on non-English locales because the
    # audit didn't see them.

    # Status pills — short uppercase labels rendered in StatusPill text:
    "DONE":       {"pt-PT": "PRONTO",   "es": "HECHO",     "fr": "TERMINÉ",    "de": "FERTIG",   "it": "FATTO"},
    "RUNNING":    {"pt-PT": "EM CURSO", "es": "EN CURSO",  "fr": "EN COURS",   "de": "AKTIV",    "it": "IN CORSO"},
    "FAILED":     {"pt-PT": "FALHOU",   "es": "FALLÓ",     "fr": "ÉCHEC",      "de": "FEHLER",   "it": "FALLITO"},
    "PAUSED":     {"pt-PT": "EM PAUSA", "es": "PAUSADO",   "fr": "EN PAUSE",   "de": "PAUSIERT", "it": "IN PAUSA"},
    "QUEUED":     {"pt-PT": "EM FILA",  "es": "EN COLA",   "fr": "EN FILE",    "de": "WARTEND",  "it": "IN CODA"},
    "CANCELLED":  {"pt-PT": "CANCELADO","es": "CANCELADO", "fr": "ANNULÉ",     "de": "ABGEBROCHEN","it": "ANNULLATO"},
    "DOWNLOADING":{"pt-PT": "A TRANSFERIR","es": "DESCARGANDO","fr": "TÉLÉCH.","de": "LÄDT",   "it": "SCARICANDO"},
    "WAITING":    {"pt-PT": "EM ESPERA","es": "ESPERANDO", "fr": "ATTENTE",    "de": "WARTET",   "it": "IN ATTESA"},
    "RESOLVING":  {"pt-PT": "A RESOLVER","es": "RESOLVIENDO","fr": "RÉSOLUTION","de": "AUFLÖSEN","it": "RISOLUZIONE"},
    "ERROR":      {"pt-PT": "ERRO",     "es": "ERROR",     "fr": "ERREUR",     "de": "FEHLER",   "it": "ERRORE"},
    "COMPLETE":   {"pt-PT": "COMPLETO", "es": "COMPLETO",  "fr": "TERMINÉ",    "de": "FERTIG",   "it": "COMPLETO"},
    "SEEDING":    {"pt-PT": "A SEMEAR", "es": "SEMBRANDO", "fr": "PARTAGE",    "de": "SAATGUT",  "it": "SEEDING"},
    "DRAFT":      {"pt-PT": "RASCUNHO", "es": "BORRADOR",  "fr": "BROUILLON",  "de": "ENTWURF",  "it": "BOZZA"},
    "ENDGAME":    {"pt-PT": "FINAL",    "es": "FINAL",     "fr": "FINAL",      "de": "ENDSPIEL", "it": "FINALE"},
    "FAILED OVER":{"pt-PT": "TROCADO",  "es": "TRASPASADO","fr": "BASCULÉ",    "de": "UMGESCHALTET","it": "COMMUTATO"},
    "FAILOVER":   {"pt-PT": "FAILOVER", "es": "FAILOVER",  "fr": "FAILOVER",   "de": "FAILOVER", "it": "FAILOVER"},
    "OVER":       {"pt-PT": "ACABOU",   "es": "FIN",       "fr": "FIN",        "de": "ENDE",     "it": "FINE"},
    "AUTO-DETECTED":{"pt-PT": "AUTO-DETECTADO","es": "AUTO-DETECTADO","fr": "AUTO-DÉTECTÉ","de": "AUTO-ERKANNT","it": "AUTO-RILEVATO"},
    "WRAPS MIDNIGHT":{"pt-PT": "PASSA À MEIA-NOITE","es": "PASA MEDIANOCHE","fr": "PASSE MINUIT","de": "ÜBER MITTERNACHT","it": "OLTRE MEZZANOTTE"},
    "WRITES":     {"pt-PT": "ESCREVE",  "es": "ESCRIBE",   "fr": "ÉCRIT",      "de": "SCHREIBT", "it": "SCRIVE"},
    "NO NW":      {"pt-PT": "SEM REDE", "es": "SIN RED",   "fr": "PAS DE RÉSEAU","de": "KEIN NETZ","it": "SENZA RETE"},
    "NOW":        {"pt-PT": "AGORA",    "es": "AHORA",     "fr": "MAINTENANT", "de": "JETZT",    "it": "ORA"},
    "LIVE":       {"pt-PT": "AO VIVO",  "es": "EN VIVO",   "fr": "EN DIRECT",  "de": "LIVE",     "it": "LIVE"},

    # Brand acronyms — kept verbatim across all locales (these are
    # technical abbreviations users recognise universally).
    "AI":         {"pt-PT": "IA",       "es": "IA",        "fr": "IA",         "de": "KI",       "it": "IA"},
    "MAS":        {"pt-PT": "MAS",      "es": "MAS",       "fr": "MAS",        "de": "MAS",      "it": "MAS"},
    "GPG":        {"pt-PT": "GPG",      "es": "GPG",       "fr": "GPG",        "de": "GPG",      "it": "GPG"},
    "ETA":        {"pt-PT": "ETA",      "es": "ETA",       "fr": "ETA",        "de": "ETA",      "it": "ETA"},
    "PRO":        {"pt-PT": "PRO",      "es": "PRO",       "fr": "PRO",        "de": "PRO",      "it": "PRO"},
    "NEW":        {"pt-PT": "NOVO",     "es": "NUEVO",     "fr": "NOUVEAU",    "de": "NEU",      "it": "NUOVO"},
    "ON":         {"pt-PT": "LIGADO",   "es": "ON",        "fr": "ACTIF",      "de": "AN",       "it": "ON"},

    # Section titles + card headers
    "Details":                       {"pt-PT": "Detalhes",          "es": "Detalles",         "fr": "Détails",         "de": "Details",          "it": "Dettagli"},
    "Performance":                   {"pt-PT": "Desempenho",        "es": "Rendimiento",      "fr": "Performance",     "de": "Leistung",         "it": "Prestazioni"},
    "Progress":                      {"pt-PT": "Progresso",         "es": "Progreso",         "fr": "Progression",     "de": "Fortschritt",      "it": "Avanzamento"},
    "Summary":                       {"pt-PT": "Resumo",            "es": "Resumen",          "fr": "Résumé",          "de": "Zusammenfassung",  "it": "Riepilogo"},
    "Entries":                       {"pt-PT": "Entradas",          "es": "Entradas",         "fr": "Entrées",         "de": "Einträge",         "it": "Voci"},
    "Torrent":                       {"pt-PT": "Torrent",           "es": "Torrent",          "fr": "Torrent",         "de": "Torrent",          "it": "Torrent"},
    "Interface contribution":        {"pt-PT": "Contribuição da interface","es": "Contribución por interfaz","fr": "Contribution par interface","de": "Schnittstellen-Beitrag","it": "Contributo per interfaccia"},
    "Web dashboard":                 {"pt-PT": "Painel web",        "es": "Panel web",        "fr": "Tableau de bord web","de": "Web-Dashboard",  "it": "Dashboard web"},
    "Your rights + responsibilities":{"pt-PT": "Os teus direitos e responsabilidades","es": "Tus derechos y responsabilidades","fr": "Vos droits et responsabilités","de": "Ihre Rechte + Pflichten","it": "I tuoi diritti e responsabilità"},
    "Questions?":                    {"pt-PT": "Dúvidas?",          "es": "¿Preguntas?",      "fr": "Des questions ?", "de": "Fragen?",          "it": "Domande?"},
    "Size (metadata pending)":       {"pt-PT": "Tamanho (metadados pendentes)","es": "Tamaño (metadatos pendientes)","fr": "Taille (métadonnées en attente)","de": "Größe (Metadaten ausstehend)","it": "Dimensione (metadati in attesa)"},

    # Format-spec status pills (interpolated)
    "%lld HTTP": {
        "pt-PT": "%lld HTTP", "es": "%lld HTTP", "fr": "%lld HTTP", "de": "%lld HTTP", "it": "%lld HTTP",
    },
    "%lld UDP": {
        "pt-PT": "%lld UDP", "es": "%lld UDP", "fr": "%lld UDP", "de": "%lld UDP", "it": "%lld UDP",
    },
    "%lld live": {
        "pt-PT": "%lld em curso", "es": "%lld activos", "fr": "%lld actifs", "de": "%lld aktiv", "it": "%lld attivi",
    },
    "%lld err": {
        "pt-PT": "%lld erros", "es": "%lld err", "fr": "%lld err", "de": "%lld Fehler", "it": "%lld err",
    },
    "%lld CHUNKS": {
        "pt-PT": "%lld PEDAÇOS", "es": "%lld FRAGMENTOS", "fr": "%lld MORCEAUX", "de": "%lld BLÖCKE", "it": "%lld PEZZI",
    },
    "%lld SWARM": {
        "pt-PT": "%lld FROTA", "es": "%lld ENJAMBRE", "fr": "%lld ESSAIM", "de": "%lld SWARM", "it": "%lld SCIAME",
    },
    "%lld MIRRORS": {
        "pt-PT": "%lld ESPELHOS", "es": "%lld MIRRORS", "fr": "%lld MIROIRS", "de": "%lld SPIEGEL", "it": "%lld MIRROR",
    },
    "FLEET ×%lld": {
        "pt-PT": "FROTA ×%lld", "es": "FLOTA ×%lld", "fr": "FLOTTE ×%lld", "de": "FLOTTE ×%lld", "it": "FLOTTA ×%lld",
    },

    # v1.7.x — Sovereignty CSV export toolbar tooltip + alert button
    "Export your installed-apps × Sovereignty matches as a CSV file": {
        "pt-PT": "Exportar a tabela de aplicações instaladas × Soberania como ficheiro CSV",
        "es": "Exportar tus aplicaciones instaladas × Soberanía como archivo CSV",
        "fr": "Exporter vos applications installées × Souveraineté en fichier CSV",
        "de": "Ihre installierten Apps × Souveränität als CSV-Datei exportieren",
        "it": "Esporta le app installate × Sovranità come file CSV",
    },
    "OK": {
        "pt-PT": "OK", "es": "OK", "fr": "OK", "de": "OK", "it": "OK",
    },

    # v1.7.x — Wayback last-resort affordance on failed-job error card
    "Last resort: archived copy": {
        "pt-PT": "Último recurso: cópia arquivada",
        "es": "Último recurso: copia archivada",
        "fr": "Dernier recours : copie archivée",
        "de": "Letzte Option: archivierte Kopie",
        "it": "Ultima risorsa: copia archiviata",
    },
    "If primary and mirrors are all unavailable, the file may exist as a Wayback Machine snapshot. Coverage is unreliable for binaries — verify the file is what you expect before downloading.": {
        "pt-PT": "Se o servidor principal e os espelhos estiverem todos indisponíveis, o ficheiro pode existir como instantâneo na Wayback Machine. A cobertura é pouco fiável para ficheiros binários — verifica que o ficheiro é o que esperas antes de transferir.",
        "es": "Si el servidor principal y los mirrors están todos no disponibles, el archivo puede existir como instantánea en la Wayback Machine. La cobertura no es fiable para binarios — verifica que el archivo es el que esperas antes de descargar.",
        "fr": "Si le serveur principal et les miroirs sont tous indisponibles, le fichier peut exister sous forme d'instantané dans la Wayback Machine. La couverture est peu fiable pour les binaires — vérifiez que le fichier est bien celui que vous attendez avant de télécharger.",
        "de": "Wenn der Primärserver und alle Spiegel nicht verfügbar sind, existiert die Datei möglicherweise als Snapshot in der Wayback Machine. Die Abdeckung für Binärdateien ist unzuverlässig — überprüfen Sie vor dem Herunterladen, ob die Datei das ist, was Sie erwarten.",
        "it": "Se il server principale e i mirror non sono tutti disponibili, il file potrebbe esistere come snapshot sulla Wayback Machine. La copertura non è affidabile per i binari — verifica che il file sia quello che ti aspetti prima di scaricarlo.",
    },
    "View archived copy in browser": {
        "pt-PT": "Ver cópia arquivada no navegador",
        "es": "Ver copia archivada en el navegador",
        "fr": "Voir la copie archivée dans le navigateur",
        "de": "Archivierte Kopie im Browser ansehen",
        "it": "Visualizza copia archiviata nel browser",
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
