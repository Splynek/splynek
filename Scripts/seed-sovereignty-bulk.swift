#!/usr/bin/env swift

// v1.4 bulk-seed tool: augments Scripts/sovereignty-catalog.json with
// a programmatic batch of entries built from category templates.
//
// This is the "pipeline" half of the v1.4 catalog-scaling work:
// rather than hand-writing each entry, we define a library of
// alternative sets (by category) and a long list of target tuples
// (bundleID, displayName, origin, category).  The script merges
// template alts onto each target and appends to the JSON catalog,
// skipping bundle IDs that already exist.
//
// Run from the repo root:
//
//   swift Scripts/seed-sovereignty-bulk.swift
//   swift Scripts/regenerate-sovereignty-catalog.swift
//
// Idempotent: running it twice is a no-op on the second run (all
// bundle IDs are already present).  Safe to iterate.  Zero deps.

import Foundation

// MARK: - Alternative templates

struct AltTemplate {
    let id, origin, name, homepage, note: String
    let downloadURL: String?
}

func A(_ id: String, _ origin: String, _ name: String, _ homepage: String,
       _ note: String, dl: String? = nil) -> AltTemplate {
    AltTemplate(id: id, origin: origin, name: name, homepage: homepage, note: note, downloadURL: dl)
}

let Alts: [String: [AltTemplate]] = [
    "chat-personal": [
        A("signal",  "oss",           "Signal",   "https://signal.org",        "Signal Foundation. Gold-standard E2E."),
        A("element", "europeAndOSS",  "Element",  "https://element.io",        "UK. Matrix protocol, self-hostable."),
        A("threema", "europe",        "Threema",  "https://threema.ch",        "Switzerland. Paid, no phone-number required."),
    ],
    "chat-team": [
        A("element",    "europeAndOSS", "Element",    "https://element.io",      "UK. Matrix protocol."),
        A("mattermost", "oss",          "Mattermost", "https://mattermost.com",  "MIT-licensed team chat."),
        A("rocketchat", "oss",          "Rocket.Chat","https://rocket.chat",     "MIT. Self-hostable team chat."),
    ],
    "video-call": [
        A("jitsi",   "oss",          "Jitsi Meet", "https://jitsi.org",  "Apache. Browser-based, no account."),
        A("element", "europeAndOSS", "Element",    "https://element.io", "UK. Matrix with video."),
        A("wire",    "europe",       "Wire",       "https://wire.com",   "Wire Swiss GmbH (Switzerland). E2E video."),
    ],
    "storage-personal": [
        A("nextcloud",   "europeAndOSS", "Nextcloud",    "https://nextcloud.com",    "Nextcloud GmbH (Germany). AGPL."),
        A("protondrive", "europe",       "Proton Drive", "https://proton.me/drive",  "Proton AG (Switzerland). E2E-encrypted."),
        A("pcloud",      "europe",       "pCloud",       "https://www.pcloud.com",   "pCloud AG (Switzerland). Lifetime plan option."),
    ],
    "storage-business": [
        A("nextcloud", "europeAndOSS", "Nextcloud",  "https://nextcloud.com",  "Germany. AGPL."),
        A("tresorit",  "europe",       "Tresorit",   "https://tresorit.com",   "Tresorit (Hungary / Switzerland). E2E business storage."),
        A("kdrive",    "europe",       "Infomaniak kDrive", "https://www.infomaniak.com/en/kdrive", "Infomaniak (Switzerland). ISO 27001."),
    ],
    "password": [
        A("bitwarden",  "oss",    "Bitwarden",   "https://bitwarden.com",    "AGPL. Self-hostable via Vaultwarden."),
        A("keepassxc",  "oss",    "KeePassXC",   "https://keepassxc.org",    "GPL. Local .kdbx file."),
        A("protonpass", "europe", "Proton Pass", "https://proton.me/pass",   "Switzerland. E2E."),
    ],
    "vpn": [
        A("protonvpn", "europe", "ProtonVPN",    "https://protonvpn.com",  "Proton AG (Switzerland). OSS clients, WireGuard."),
        A("mullvad",   "europe", "Mullvad VPN",  "https://mullvad.net",    "Mullvad (Sweden). No-logs, flat-rate."),
        A("ivpn",      "europe", "IVPN",         "https://www.ivpn.net",   "IVPN (Gibraltar). No-logs, OSS clients."),
    ],
    "mail": [
        A("protonmail",  "europe", "Proton Mail",  "https://proton.me/mail",   "Proton AG (Switzerland). E2E-encrypted."),
        A("thunderbird", "oss",    "Thunderbird",  "https://www.thunderbird.net", "Mozilla Foundation. MPL.",
          dl: "https://download.mozilla.org/?product=thunderbird-latest&os=osx&lang=en-US"),
        A("tuta",        "europe", "Tuta",         "https://tuta.com",         "Tuta GmbH (Germany). E2E."),
        A("mailbox",     "europe", "Mailbox.org",  "https://mailbox.org",      "Heinlein Hosting (Germany). Paid, privacy-first."),
    ],
    "note": [
        A("obsidian", "oss", "Obsidian", "https://obsidian.md",    "Local-first markdown."),
        A("joplin",   "oss", "Joplin",   "https://joplinapp.org",  "AGPL. E2E sync."),
        A("logseq",   "oss", "Logseq",   "https://logseq.com",     "AGPL. Local-first outliner."),
    ],
    "browser": [
        A("firefox",        "oss",    "Firefox",        "https://www.mozilla.org/firefox", "Mozilla Foundation (MPL).",
          dl: "https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-US"),
        A("librewolf",      "oss",    "LibreWolf",      "https://librewolf.net",           "MPL. Firefox fork, telemetry-free."),
        A("mullvadbrowser", "oss",    "Mullvad Browser","https://mullvad.net/en/browser",  "Sweden. Tor-hardened privacy."),
        A("vivaldi",        "europe", "Vivaldi",        "https://vivaldi.com",             "Vivaldi Technologies (Norway)."),
    ],
    "office": [
        A("libreoffice", "oss",          "LibreOffice", "https://www.libreoffice.org", "The Document Foundation (Germany). MPL."),
        A("onlyoffice",  "europeAndOSS", "ONLYOFFICE",  "https://www.onlyoffice.com",  "Ascensio System (Latvia). AGPL community edition."),
    ],
    "ai-chat": [
        A("mistral",  "europe", "Mistral Le Chat", "https://chat.mistral.ai", "Mistral AI (France). EU-hosted chat."),
        A("lmstudio", "oss",    "LM Studio",       "https://lmstudio.ai",     "Run open-weight models (Llama, Mistral, Qwen) locally."),
        A("jan",      "oss",    "Jan",             "https://jan.ai",          "AGPL. Offline ChatGPT-alt."),
    ],
    "ai-translate": [
        A("deepl",     "europe", "DeepL",        "https://www.deepl.com",    "DeepL SE (Germany). Best-in-class translation."),
        A("mistral",   "europe", "Mistral Le Chat","https://chat.mistral.ai","France. General-purpose LLM does translation well."),
        A("libretranslate", "oss", "LibreTranslate", "https://libretranslate.com", "AGPL. Self-hostable translation API."),
    ],
    "video-edit": [
        A("kdenlive", "oss",   "Kdenlive",        "https://kdenlive.org", "GPL. KDE non-linear video editor."),
        A("davinci",  "other", "DaVinci Resolve", "https://www.blackmagicdesign.com/products/davinciresolve", "Blackmagic Design (Australia). Free tier exceptionally powerful."),
        A("openshot", "oss",   "OpenShot",        "https://www.openshot.org", "GPL. Cross-platform video editor."),
    ],
    "photo-edit": [
        A("gimp",           "oss",    "GIMP",             "https://www.gimp.org",             "GPL."),
        A("krita",          "oss",    "Krita",            "https://krita.org",                "GPL. Digital painting."),
        A("affinity-photo", "europe", "Affinity Photo",   "https://affinity.serif.com/photo/","Serif (UK). One-time purchase."),
    ],
    "photo-raw": [
        A("darktable",   "oss",    "darktable",    "https://www.darktable.org",  "GPL."),
        A("rawtherapee", "oss",    "RawTherapee",  "https://rawtherapee.com",    "GPL."),
        A("captureone",  "europe", "Capture One",  "https://www.captureone.com", "Capture One (Denmark)."),
    ],
    "vector": [
        A("inkscape",          "oss",    "Inkscape",          "https://inkscape.org",              "GPL."),
        A("affinity-designer", "europe", "Affinity Designer", "https://affinity.serif.com/designer/","Serif (UK)."),
    ],
    "pdf": [
        A("skim",      "oss",          "Skim",        "https://skim-app.sourceforge.io", "BSD. Mac PDF reader + annotator."),
        A("xournalpp", "oss",          "Xournal++",   "https://xournalpp.github.io",     "GPL. PDF annotation + notes."),
        A("okular",    "oss",          "Okular",      "https://okular.kde.org",          "GPL. KDE universal document viewer."),
        A("pdfarranger","oss",         "PDF Arranger","https://github.com/pdfarranger/pdfarranger", "GPL. Merge/split/rotate PDF."),
    ],
    "task": [
        A("openproject",     "europeAndOSS", "OpenProject",       "https://www.openproject.org", "OpenProject GmbH (Germany). GPL."),
        A("taiga",           "europeAndOSS", "Taiga",             "https://taiga.io",            "Kaleidos (Spain). Apache. Agile PM."),
        A("superproductivity","oss",         "Super Productivity","https://super-productivity.com","MIT. Self-hostable task manager."),
    ],
    "code-editor": [
        A("vscodium", "oss", "VSCodium", "https://vscodium.com", "MIT. Telemetry-free VS Code build."),
        A("zed",      "oss", "Zed",      "https://zed.dev",      "GPL. Fast native editor."),
        A("neovim",   "oss", "Neovim",   "https://neovim.io",    "Apache. Modal editor."),
    ],
    "terminal": [
        A("iterm2",   "oss", "iTerm2",   "https://iterm2.com",   "GPL. Long-standing Mac terminal."),
        A("ghostty",  "oss", "Ghostty",  "https://ghostty.org",  "MIT. GPU-accelerated."),
        A("alacritty","oss", "Alacritty","https://alacritty.org","Apache. Fast, simple terminal."),
    ],
    "remote-desktop": [
        A("anydesk",    "europe", "AnyDesk",    "https://anydesk.com",           "AnyDesk Software (Germany)."),
        A("teamviewer", "europe", "TeamViewer", "https://www.teamviewer.com",    "TeamViewer SE (Germany)."),
        A("rustdesk",   "oss",    "RustDesk",   "https://rustdesk.com",          "AGPL. Self-hostable remote-desktop."),
    ],
    "screen-recording": [
        A("obs", "oss", "OBS Studio", "https://obsproject.com", "GPL."),
    ],
    "music-production": [
        A("ardour",    "oss", "Ardour",  "https://ardour.org",  "GPL. Professional DAW."),
        A("lmms",      "oss", "LMMS",    "https://lmms.io",     "GPL. FL Studio-like DAW."),
    ],
    "audio-edit": [
        A("audacity",  "oss", "Audacity","https://www.audacityteam.org", "GPL."),
        A("ocenaudio", "europe", "Ocenaudio","https://www.ocenaudio.com","Brazilian-origin but freeware; fast audio editor — alt mostly useful when Audacity feels heavy."),
    ],
    "map-nav": [
        A("organic-maps",  "oss", "Organic Maps", "https://organicmaps.app",      "Apache. Offline-first OSM-based."),
        A("openstreetmap", "oss", "OpenStreetMap","https://www.openstreetmap.org","ODbL. The community map."),
    ],
    "social-media": [
        A("mastodon",  "europeAndOSS", "Mastodon",  "https://joinmastodon.org", "Mastodon gGmbH (Germany). AGPL."),
        A("pixelfed",  "oss",          "Pixelfed",  "https://pixelfed.org",     "AGPL. Federated photo-sharing."),
        A("bluesky",   "oss",          "Bluesky",   "https://bsky.app",         "US-based but AGPL+protocol — a looser federation option. Note: US-hosted."),
    ],
    "video-streaming": [
        A("arte",     "europe", "Arte.tv",   "https://www.arte.tv",    "Arte (France/Germany). Free, ad-supported."),
        A("mubi",     "europe", "MUBI",      "https://mubi.com",       "MUBI (UK). Curated arthouse streaming."),
        A("jellyfin", "oss",    "Jellyfin",  "https://jellyfin.org",   "GPL. Self-hosted media."),
    ],
    "music-streaming": [
        A("deezer",  "europe", "Deezer","https://www.deezer.com",    "Deezer (France). HiFi streaming."),
        A("qobuz",   "europe", "Qobuz", "https://www.qobuz.com",     "Qobuz (France). Studio-quality, paid."),
        A("spotify", "europe", "Spotify","https://www.spotify.com",  "Spotify AB (Sweden). Free + paid."),
    ],
    "finance": [
        A("gnucash",    "oss", "GnuCash",      "https://www.gnucash.org",     "GPL. Double-entry accounting."),
        A("firefly",    "oss", "Firefly III",  "https://www.firefly-iii.org", "AGPL. Personal finance."),
        A("actualbudget","oss","Actual Budget","https://actualbudget.org",    "MIT. Local-first budgeting."),
    ],
    "database": [
        A("dbeaver",  "oss", "DBeaver",         "https://dbeaver.io",             "Apache. Universal SQL client."),
        A("beekeeper","oss", "Beekeeper Studio","https://www.beekeeperstudio.io", "MIT. Modern SQL client."),
    ],
    "cad-3d": [
        A("freecad", "oss", "FreeCAD", "https://www.freecad.org", "LGPL. Parametric modeller."),
        A("blender", "oss", "Blender", "https://www.blender.org", "Blender Foundation (Netherlands). GPL."),
    ],
    "cad-2d": [
        A("librecad", "oss", "LibreCAD", "https://librecad.org", "GPL. 2D CAD."),
        A("qcad",     "oss", "QCAD",     "https://qcad.org",     "GPL. 2D CAD."),
    ],
    "torrent": [
        A("transmission","oss","Transmission", "https://transmissionbt.com", "MIT. Native Mac BitTorrent."),
        A("qbittorrent", "oss","qBittorrent",  "https://www.qbittorrent.org","GPL. Full-featured."),
    ],
    "feed-reader": [
        A("newsflash",  "oss", "NewsFlash",     "https://gitlab.com/news-flash", "GPL. RSS/Atom."),
        A("miniflux",   "oss", "Miniflux",      "https://miniflux.app",          "Apache. Self-hosted RSS."),
        A("freshrss",   "oss", "FreshRSS",      "https://freshrss.org",          "AGPL. Self-hostable feed aggregator."),
    ],
    "survey-form": [
        A("limesurvey", "oss", "LimeSurvey",   "https://www.limesurvey.org", "LimeSurvey (Germany). GPL."),
        A("formbricks", "oss", "Formbricks",   "https://formbricks.com",     "AGPL. Self-hostable surveys."),
    ],
    "e-sign": [
        A("documenso", "oss", "Documenso", "https://documenso.com",      "AGPL. Open DocuSign-alt."),
        A("opensign",  "oss", "OpenSign",  "https://www.opensignlabs.com","AGPL. Self-hostable e-sign."),
    ],
    "calendar": [
        A("protoncalendar","europe","Proton Calendar","https://proton.me/calendar","Switzerland. E2E-encrypted."),
        A("tutacalendar",  "europe","Tuta Calendar",  "https://tuta.com/calendar", "Germany. E2E-encrypted."),
    ],
    "scheduling": [
        A("caldotcom", "oss", "Cal.com", "https://cal.com", "AGPL. Calendly-alt, self-hostable."),
    ],
    "crm": [
        A("twenty",    "oss",          "Twenty",    "https://twenty.com",        "AGPL. Open Salesforce-alt."),
        A("espocrm",   "oss",          "EspoCRM",   "https://www.espocrm.com",   "GPL. Mature CRM."),
        A("zoho",      "other",        "Zoho CRM",  "https://www.zoho.com/crm/", "Zoho (India). Paid, more EU-aligned than US competitors."),
    ],
    "analytics": [
        A("plausible", "europeAndOSS", "Plausible Analytics", "https://plausible.io", "Plausible (Estonia). AGPL."),
        A("matomo",    "oss",          "Matomo",              "https://matomo.org",   "GPL. Self-hostable analytics."),
        A("umami",     "oss",          "Umami",               "https://umami.is",     "MIT. Privacy-first analytics."),
    ],
    "monitoring": [
        A("grafana", "oss", "Grafana", "https://grafana.com/oss/grafana", "AGPL."),
        A("netdata", "oss", "Netdata", "https://www.netdata.cloud",       "GPL. Real-time monitoring."),
        A("uptimekuma","oss","Uptime Kuma","https://uptimekuma.org",     "MIT. Self-hosted uptime monitor."),
    ],
    "system-util": [
        A("stats",      "oss",    "Stats",      "https://github.com/exelban/stats", "MIT. System-monitor menu bar."),
        A("clamxav",    "oss",    "ClamXAV",    "https://www.clamxav.com",          "ClamAV-based Mac AV client."),
        A("f-secure",   "europe", "F-Secure",   "https://www.f-secure.com",         "F-Secure (Finland). Commercial AV."),
    ],
    "antivirus": [
        A("clamav",    "oss",    "ClamAV",     "https://www.clamav.net",  "GPL. Open-source AV scanner."),
        A("f-secure",  "europe", "F-Secure",   "https://www.f-secure.com","Finland. Commercial AV."),
        A("eset",      "europe", "ESET NOD32", "https://www.eset.com",    "ESET (Slovakia). Commercial AV."),
        A("bitdefender","europe","Bitdefender","https://www.bitdefender.com","Bitdefender (Romania). Commercial AV."),
    ],
    "knowledge-base": [
        A("outline",   "oss", "Outline",    "https://www.getoutline.com","BSL. Team wiki."),
        A("bookstack", "oss", "BookStack",  "https://www.bookstackapp.com","MIT. Self-hosted wiki."),
        A("wikijs",    "oss", "Wiki.js",    "https://js.wiki",            "AGPL. Modern self-hosted wiki."),
    ],
    "cloud-cli": [
        A("hetzner", "europe", "Hetzner Cloud CLI", "https://docs.hetzner.cloud/#hcloud-cli", "Hetzner (Germany). EU-hosted IaaS."),
        A("scaleway","europe", "Scaleway CLI",      "https://www.scaleway.com",               "Scaleway (France). EU-hosted IaaS."),
        A("ovh",     "europe", "OVHcloud CLI",      "https://www.ovhcloud.com",               "OVHcloud (France)."),
    ],
    "mdm-agent": [
        A("fleet",   "oss", "Fleet",    "https://fleetdm.com",   "MIT. Open-source MDM."),
        A("puppet",  "oss", "Puppet",   "https://puppet.com",    "Apache. Configuration management."),
    ],
    "drawing": [
        A("krita",    "oss",    "Krita",    "https://krita.org",              "GPL. Digital painting."),
        A("mypaint",  "oss",    "MyPaint",  "https://mypaint.app",            "GPL. Natural-media painting."),
        A("drawpile", "oss",    "Drawpile", "https://drawpile.net",           "GPL. Collaborative painting (Finnish author)."),
    ],
    "drawio": [
        A("drawio",   "oss",          "draw.io",        "https://www.drawio.com",         "Apache. Diagrams."),
        A("excalidraw","oss",         "Excalidraw",     "https://excalidraw.com",         "MIT. Hand-drawn-style diagrams."),
    ],
    "ide": [
        A("jetbrains","europe", "JetBrains Toolbox", "https://www.jetbrains.com/toolbox-app/", "JetBrains (Czech Republic). Industry-standard IDE suite."),
        A("vscodium", "oss",    "VSCodium",          "https://vscodium.com",              "MIT. Telemetry-free VS Code."),
        A("zed",      "oss",    "Zed",               "https://zed.dev",                   "GPL. Native editor."),
    ],
    "git-gui": [
        A("gitui",    "oss",    "GitUI",   "https://github.com/gitui-org/gitui", "MIT. Fast TUI git client."),
        A("fork",     "europe", "Fork",    "https://git-fork.com",               "DanPristupov (Germany). Free for individuals."),
        A("gitkraken","unitedStates", "GitKraken","https://www.gitkraken.com","Axosoft (US). Skip; use Fork instead."),
    ],
    "mastodon-client": [
        A("elk",      "oss", "Elk",      "https://elk.zone",      "MIT. Modern web client."),
        A("semaphore","oss", "Semaphore","https://semaphore.social","MIT. Lightweight web client."),
    ],
    "container": [
        A("orbstack", "oss",    "OrbStack", "https://orbstack.dev", "Native Mac container runtime."),
        A("colima",   "oss",    "Colima",   "https://github.com/abiosoft/colima", "MIT. CLI container runtime."),
        A("podman",   "oss",    "Podman",   "https://podman.io",    "Apache. Daemonless container runtime."),
    ],
    "api-client": [
        A("bruno",    "oss", "Bruno",   "https://www.usebruno.com", "MIT. Git-friendly API client."),
        A("insomnia", "oss", "Insomnia","https://insomnia.rest",    "Apache. API client."),
        A("hoppscotch","oss","Hoppscotch","https://hoppscotch.io",   "MIT. Web-based API client."),
    ],
    "screenshot": [
        A("shottr",   "europe", "Shottr",   "https://shottr.cc",   "Latvian author. Fast Mac screenshot tool."),
        A("cleanshotx","europe","CleanShot X","https://cleanshot.com", "MacPaw (Ukraine) — .other; fallback to Shottr."),
        A("flameshot","oss",    "Flameshot","https://flameshot.org","GPL. Cross-platform screenshot."),
    ],
    "clipboard": [
        A("maccy",    "oss", "Maccy",       "https://maccy.app",     "MIT. Native clipboard manager."),
        A("copyq",    "oss", "CopyQ",       "https://hluk.github.io/CopyQ/", "GPL. Cross-platform clipboard manager."),
    ],
    "launcher": [
        A("alfred",   "europe", "Alfred",    "https://www.alfredapp.com", "Running With Crayons (UK). Paid power-pack."),
        A("launchbar","europe", "LaunchBar", "https://obdev.at/products/launchbar/", "Objective Development (Austria)."),
    ],
    "window-mgmt": [
        A("rectangle","oss", "Rectangle", "https://rectangleapp.com",    "MIT. Hotkey window manager."),
        A("amethyst", "oss", "Amethyst",  "https://ianyh.com/amethyst/", "MIT. Tiling window manager."),
    ],
    "file-transfer": [
        A("cyberduck","europeAndOSS", "Cyberduck", "https://cyberduck.io",        "iterate GmbH (Germany). GPL."),
        A("filezilla","oss",          "FileZilla", "https://filezilla-project.org","GPL."),
    ],
    "chinese-messaging": [
        A("signal",  "oss",          "Signal",  "https://signal.org",  "Signal Foundation."),
        A("element", "europeAndOSS", "Element", "https://element.io",  "UK. Matrix protocol."),
        A("threema", "europe",       "Threema", "https://threema.ch",  "Switzerland."),
    ],
    "scientific": [
        A("scilab",   "oss", "Scilab",    "https://www.scilab.org",      "Scilab Enterprises (France). GPL. MATLAB-alt."),
        A("octave",   "oss", "GNU Octave","https://octave.org",          "GPL. MATLAB-compat."),
        A("scipy",    "oss", "SciPy",     "https://scipy.org",           "BSD. Python scientific stack."),
    ],
    "stats": [
        A("r-project","oss", "R",            "https://www.r-project.org",    "GPL. Statistical computing."),
        A("jasp",     "oss", "JASP",         "https://jasp-stats.org",       "AGPL. University of Amsterdam (Netherlands). SPSS-alt."),
        A("pspp",     "oss", "PSPP",         "https://www.gnu.org/software/pspp/", "GPL. SPSS-alt."),
    ],
    "bibliography": [
        A("zotero",   "oss", "Zotero",   "https://www.zotero.org",   "AGPL. Reference manager."),
        A("jabref",   "oss", "JabRef",   "https://www.jabref.org",   "MIT. BibTeX reference manager."),
    ],
    "disk-util": [
        A("graphical-installer","oss","GrandPerspective","https://grandperspectiv.sourceforge.net","GPL. Disk-usage visualiser."),
        A("onyx",     "europe","OnyX",     "https://www.titanium-software.fr/en/onyx.html","Titanium Software (France). Freeware."),
    ],
    "archive": [
        A("keka",     "europe", "Keka",        "https://www.keka.io",       "Keka Team (Spain). Freeware Mac archiver."),
        A("theunarchiver","europe","The Unarchiver", "https://theunarchiver.com", "MacPaw (Ukraine) — .other; Keka is the EU pick."),
    ],
    "encryption": [
        A("cryptomator","europeAndOSS","Cryptomator","https://cryptomator.org", "Skymatic (Germany). GPL."),
        A("veracrypt",  "oss",         "VeraCrypt",  "https://www.veracrypt.fr","IDRIX (France). Apache. Full-disk encryption."),
    ],
    "backup": [
        A("borg",  "oss",   "BorgBackup", "https://www.borgbackup.org", "BSD. Deduplicating encrypted backups."),
        A("restic","oss",   "Restic",     "https://restic.net",         "BSD."),
        A("kopia", "oss",   "Kopia",      "https://kopia.io",           "Apache. Fast deduplicating backup."),
    ],
    "dev-shell": [
        A("warpalt","oss",    "WezTerm", "https://wezfurlong.org/wezterm/", "MIT. GPU-accelerated terminal."),
        A("fish",   "oss",    "Fish Shell","https://fishshell.com",       "BSD. User-friendly shell."),
    ],
    "email-marketing": [
        A("listmonk","oss", "Listmonk",  "https://listmonk.app",   "AGPL. Self-hostable email marketing."),
        A("mautic", "oss",  "Mautic",    "https://www.mautic.org", "GPL. Marketing automation."),
    ],
    "meeting": [
        A("bbb",    "oss",          "BigBlueButton", "https://bigbluebutton.org", "LGPL. Web conferencing for education."),
        A("jitsi",  "oss",          "Jitsi Meet",    "https://jitsi.org",         "Apache."),
    ],
    "photo-manager": [
        A("digikam","oss", "digiKam","https://www.digikam.org","GPL. Photo library + editor."),
        A("shotwell","oss","Shotwell","https://wiki.gnome.org/Apps/Shotwell", "LGPL. GNOME photo manager."),
    ],
    "translation-memory": [
        A("omegat", "oss", "OmegaT",   "https://omegat.org",         "GPL. Translation memory."),
    ],
    "ocr": [
        A("tesseract","oss","Tesseract OCR","https://tesseract-ocr.github.io","Apache."),
    ],
    "screen-annotate": [
        A("cleanshotx","europe","CleanShot X","https://cleanshot.com", "MacPaw (Ukraine) — .other"),
        A("shottr",    "europe","Shottr",     "https://shottr.cc",     "Latvian author."),
    ],
    "tor": [
        A("tor-browser","oss","Tor Browser", "https://www.torproject.org","The Tor Project. Free."),
    ],
    "notes-pro": [
        A("obsidian","oss","Obsidian","https://obsidian.md","Local-first markdown."),
        A("logseq",  "oss","Logseq",  "https://logseq.com", "AGPL. Outliner."),
    ],
    "kanban": [
        A("kanboard","oss","Kanboard","https://kanboard.org","MIT. Minimalist kanban."),
        A("wekan",   "oss","Wekan",   "https://wekan.github.io","MIT. Open kanban."),
    ],
    "color-picker": [
        A("colorsnapper","europe","ColorSnapper","https://colorsnapper.com","Ukrainian/EU dev — .other safer."),
        A("sip",         "europe","Sip",         "https://sipapp.io",       "Greek dev (EU). Native color picker."),
    ],
    "docs-collab": [
        A("etherpad","oss","Etherpad","https://etherpad.org","Apache. Real-time doc collab."),
        A("hedgedoc","oss","HedgeDoc","https://hedgedoc.org", "AGPL. Real-time markdown collab."),
    ],
    "password-sso": [
        A("keycloak","oss","Keycloak","https://www.keycloak.org","Apache. Red Hat OSS IdM."),
        A("authelia","oss","Authelia","https://www.authelia.com","Apache. Self-hostable SSO."),
    ],
    "reader": [
        A("calibre",  "oss",    "Calibre",    "https://calibre-ebook.com",  "GPL. E-book manager."),
        A("foliate",  "oss",    "Foliate",    "https://github.com/johnfactotum/foliate","GPL. E-book reader."),
        A("koreader", "oss",    "KOReader",   "https://koreader.rocks",     "AGPL. E-book reader."),
    ],
    "cloud-cli-control": [
        A("terraform","oss","OpenTofu",  "https://opentofu.org","MPL. Open Terraform fork."),
        A("pulumi",   "oss","Pulumi",    "https://www.pulumi.com","Apache. IaC."),
    ],
    "video-player": [
        A("vlc",      "oss", "VLC",       "https://www.videolan.org",      "VideoLAN (France). GPL."),
        A("mpv",      "oss", "mpv",       "https://mpv.io",                "GPL. Minimalist video player."),
        A("iina",     "oss", "IINA",      "https://iina.io",               "GPL. Modern Mac-native video player."),
    ],
    "audio-player": [
        A("audacious","oss","Audacious","https://audacious-media-player.org","BSD. Lightweight audio player."),
        A("cmus",     "oss","cmus",     "https://cmus.github.io",            "GPL. Terminal audio player."),
    ],
    "screen-share": [
        A("screegle",  "europe","Screegle", "https://www.screegle.com",   "Austrian dev (EU)."),
        A("obs",       "oss",   "OBS Studio","https://obsproject.com",    "GPL."),
    ],
    "dictation": [
        A("macwhisper","europe","MacWhisper","https://goodsnooze.com","Good Snooze (Netherlands)."),
        A("whispercpp","oss",   "whisper.cpp","https://github.com/ggerganov/whisper.cpp","MIT. Local STT."),
    ],
    "habit-track": [
        A("streaks",  "europe", "Streaks", "https://streaksapp.com", "Crunchy Bagel (Ireland)."),
        A("loop",     "oss",    "Loop Habit Tracker","https://github.com/iSoron/uhabits", "GPL."),
    ],
    "menu-bar": [
        A("stats",    "oss", "Stats",    "https://github.com/exelban/stats",  "MIT. System monitor."),
        A("ish",      "oss", "iSH",      "https://ish.app",                   "MIT. Alpine Linux shell."),
    ],
    "dotfiles": [
        A("chezmoi",  "oss", "chezmoi",  "https://www.chezmoi.io",     "MIT. Manage dotfiles across machines."),
    ],
]

// MARK: - Targets

struct Target {
    let bundleID, name, origin, category, slug: String
    init(_ bundleID: String, _ name: String, _ origin: String, _ category: String, _ slug: String) {
        self.bundleID = bundleID; self.name = name; self.origin = origin;
        self.category = category; self.slug = slug
    }
}

func T(_ bundleID: String, _ name: String, _ origin: String,
       _ category: String, _ slug: String) -> Target {
    Target(bundleID, name, origin, category, slug)
}

let newTargets: [Target] = [
    // ─── CN apps ────────────────────────────────────────────────────
    T("com.bytedance.feishu",        "Feishu (Lark)",            "china", "chat-team",         "feishu"),
    T("com.alipay.alipay-desktop",   "Alipay Desktop",           "china", "finance",           "alipay"),
    T("com.netease.163music",        "NetEase Cloud Music",      "china", "music-streaming",   "netease-music"),
    T("com.tencent.QQMusicMac",      "QQ Music",                 "china", "music-streaming",   "qqmusic"),
    T("com.kugou.Kugou",             "Kugou Music",              "china", "music-streaming",   "kugou"),
    T("com.iqiyi.player",            "iQIYI",                    "china", "video-streaming",   "iqiyi"),
    T("com.youku.YoukuClient",       "Youku",                    "china", "video-streaming",   "youku"),
    T("com.bilibili.mac",            "Bilibili",                 "china", "video-streaming",   "bilibili"),
    T("com.sina.weibo.mac",          "Weibo",                    "china", "social-media",      "weibo"),
    T("com.bytedance.douyin",        "Douyin",                   "china", "social-media",      "douyin"),
    T("com.tencent.xunlei",          "Xunlei",                   "china", "torrent",           "xunlei"),
    T("com.bytedance.capcut",        "CapCut",                   "china", "video-edit",        "capcut"),
    T("com.wondershare.filmora",     "Wondershare Filmora",      "china", "video-edit",        "filmora"),
    T("com.wondershare.PDFelement",  "Wondershare PDFelement",   "china", "pdf",               "pdfelement"),
    T("com.360.totalsecurity",       "360 Total Security",       "china", "antivirus",         "360tsec"),
    T("com.sogou.pinyin",            "Sogou Pinyin",             "china", "system-util",       "sogou"),
    T("com.baidu.input.mac",         "Baidu Input",              "china", "system-util",       "baidu-input"),
    T("com.tencent.mac.qqmail",      "QQ Mail",                  "china", "mail",              "qqmail"),
    T("com.163.mail",                "NetEase Mail",             "china", "mail",              "neteasemail"),
    T("cn.wps.pdf.mac",              "WPS PDF",                  "china", "pdf",               "wpspdf"),
    T("com.xiaomi.micloud",          "Mi Cloud Sync",            "china", "storage-personal",  "micloud"),
    T("com.huawei.hicloud.mac",      "Huawei Mobile Cloud",      "china", "storage-personal",  "huaweicloud"),
    T("com.tencent.lemon.lite",      "Tencent Lemon Cleaner",    "china", "system-util",       "lemon-cleaner"),
    T("com.tencent.docs",            "Tencent Docs",             "china", "office",            "tencent-docs"),
    T("com.alibaba.cloudapp",        "Alibaba Cloud",            "china", "storage-business",  "alicloud"),
    T("com.tencent.videoClient",     "Tencent Video",            "china", "video-streaming",   "tencent-video"),
    T("com.mgtv.mac",                "Mango TV",                 "china", "video-streaming",   "mangotv"),
    T("com.xiaohongshu.xhs",         "Xiaohongshu (RED)",        "china", "social-media",      "xiaohongshu"),
    T("com.kingsoft.office.mail",    "WPS Mail",                 "china", "mail",              "wpsmail"),
    T("com.tencent.WeChatWork",      "WeChat Work",              "china", "chat-team",         "wechatwork"),
    T("com.huawei.AppGallery",       "Huawei AppGallery",        "china", "system-util",       "appgallery"),
    T("com.huawei.Mate.Mac",         "Huawei PC Manager",        "china", "system-util",       "huawei-pc"),
    T("com.tencent.live.qtv",        "Tencent QLive",            "china", "video-streaming",   "qlive"),
    T("com.baidu.netdisk-mac",       "Baidu Netdisk Lite",       "china", "storage-personal",  "baidu-lite"),
    T("com.iqiyi.player.light",      "iQIYI Lite",               "china", "video-streaming",   "iqiyi-lite"),

    // ─── RU apps ────────────────────────────────────────────────────
    T("ru.mail.mail.agent",          "Mail.ru Agent",            "russia", "chat-personal",    "mailru-agent"),
    T("com.vk.vk-messenger",         "VK Messenger",             "russia", "chat-personal",    "vk-messenger"),
    T("ru.yandex.disk",              "Yandex Disk",              "russia", "storage-personal", "yadisk"),
    T("ru.yandex.mail",              "Yandex Mail",              "russia", "mail",             "yamail"),
    T("ru.yandex.music.mac",         "Yandex Music",             "russia", "music-streaming",  "yamusic"),
    T("ru.kaspersky.kis",            "Kaspersky Internet Security","russia","antivirus",       "kis"),
    T("com.kaspersky.kpm",           "Kaspersky Password Manager","russia", "password",        "kpm"),
    T("com.kaspersky.securekids",    "Kaspersky Safe Kids",      "russia", "system-util",      "ksk"),
    T("com.kaspersky.kvpn",          "Kaspersky Secure Connection","russia","vpn",             "kvpn"),
    T("ru.drweb.security",           "Dr.Web Security Suite",    "russia", "antivirus",        "drweb"),
    T("ru.rutube.client",            "RuTube",                   "russia", "video-streaming",  "rutube"),
    T("ru.yandex.browser.beta",      "Yandex Browser Beta",      "russia", "browser",          "yabeta"),
    T("ru.yandex.maps",              "Yandex Maps",              "russia", "map-nav",          "yamaps"),
    T("ru.yandex.navigator",         "Yandex Navigator",         "russia", "map-nav",          "yanav"),
    T("ru.yandex.translate",         "Yandex Translate",         "russia", "ai-translate",     "yatrans"),
    T("ru.sber.online",              "SberOnline",               "russia", "finance",          "sber"),
    T("ru.1c.enterprise",            "1C:Enterprise",            "russia", "office",           "1c-ent"),
    T("ru.my.calls",                 "Mail.ru Calls (VK)",       "russia", "video-call",       "mru-calls"),
    T("ru.ok.desktop",                "Odnoklassniki Desktop",   "russia", "social-media",     "ok-ru"),

    // ─── US messaging/collab ────────────────────────────────────────
    T("com.slack.huddles",           "Slack Huddles",            "unitedStates", "video-call", "huddles"),
    T("com.skype.skypeforbusiness",  "Skype for Business",       "unitedStates", "video-call", "s4b"),
    T("com.amazon.chime",            "Amazon Chime",             "unitedStates", "video-call", "chime"),
    T("com.readdle.spark-desktop",   "Spark Mail",               "other",        "mail",       "spark"),
    T("com.newtonhq.newton",         "Newton Mail",              "unitedStates", "mail",       "newton"),
    T("com.edison.mail",             "Edison Mail",              "unitedStates", "mail",       "edison"),
    T("com.mimestream.Mimestream",   "Mimestream",               "unitedStates", "mail",       "mimestream"),
    T("com.polymail.pm",             "Polymail",                 "unitedStates", "mail",       "polymail"),
    T("com.twobird.twobird",         "Twobird",                  "unitedStates", "mail",       "twobird"),
    T("com.fastmail.client",         "Fastmail",                 "other",        "mail",       "fastmail"),
    T("com.spike.Spike",             "Spike",                    "other",        "mail",       "spike-mail"),
    T("com.fluenty.kiwi",            "Kiwi for Gmail",           "unitedStates", "mail",       "kiwi"),
    T("com.blackmailman.mac",        "BlackMail",                "unitedStates", "mail",       "blackmail"),

    // ─── US productivity SaaS ───────────────────────────────────────
    T("com.salesforce.client",       "Salesforce CRM",           "unitedStates", "crm",              "salesforce"),
    T("com.hubspot.app",             "HubSpot",                  "unitedStates", "crm",              "hubspot"),
    T("com.zendesk.zendesk",         "Zendesk Support",          "unitedStates", "crm",              "zendesk"),
    T("com.intercom.messenger",      "Intercom",                 "unitedStates", "crm",              "intercom"),
    T("com.zapier.mac",              "Zapier Desktop",           "unitedStates", "crm",              "zapier"),
    T("com.ifttt.mac",               "IFTTT",                    "unitedStates", "crm",              "ifttt"),
    T("com.coda.coda",               "Coda",                     "unitedStates", "knowledge-base",   "coda"),
    T("com.roamresearch.app",        "Roam Research",            "unitedStates", "notes-pro",        "roam"),
    T("com.remnote.app",             "RemNote",                  "unitedStates", "notes-pro",        "remnote"),
    T("com.mem.desktop",             "Mem",                      "unitedStates", "notes-pro",        "mem"),
    T("com.dayoneapp.dayone",        "Day One",                  "unitedStates", "notes-pro",        "dayone"),
    T("com.omnigroup.OmniOutliner5", "OmniOutliner",             "unitedStates", "notes-pro",        "omnioutliner"),
    T("com.omnigroup.OmniPlan4",     "OmniPlan",                 "unitedStates", "task",             "omniplan"),
    T("com.omnigroup.OmniGraffle7",  "OmniGraffle",              "unitedStates", "drawio",           "omnigraffle"),
    T("com.docusign.desktop",        "DocuSign",                 "unitedStates", "e-sign",           "docusign"),
    T("com.dropbox.sign",            "Dropbox Sign (HelloSign)", "unitedStates", "e-sign",           "hellosign"),
    T("com.pandadoc.desktop",        "PandaDoc",                 "unitedStates", "e-sign",           "pandadoc"),
    T("com.calendly.calendly",       "Calendly",                 "unitedStates", "scheduling",       "calendly"),
    T("com.savvycal.app",            "SavvyCal",                 "unitedStates", "scheduling",       "savvycal"),
    T("com.ghost.desktop",           "Ghost Publisher",          "unitedStates", "knowledge-base",   "ghost"),
    T("com.substack.reader",         "Substack",                 "unitedStates", "feed-reader",      "substack"),
    T("com.mailchimp.app",           "Mailchimp",                "unitedStates", "email-marketing",  "mailchimp"),
    T("com.squarespace.desktop",     "Squarespace",              "unitedStates", "knowledge-base",   "squarespace"),
    T("com.wix.editor",              "Wix Editor",               "other",        "knowledge-base",   "wix"),
    T("co.smartsheet.SmartsheetMac", "Smartsheet",               "unitedStates", "task",             "smartsheet"),
    T("com.freshworks.desk",         "Freshdesk",                "other",        "crm",              "freshdesk"),
    T("com.servicenow.desktop",      "ServiceNow",               "unitedStates", "crm",              "servicenow"),
    T("com.workday.desktop",         "Workday",                  "unitedStates", "crm",              "workday"),
    T("com.atlassian.statuspage",    "Statuspage (Atlassian)",   "other",        "monitoring",       "statuspage"),
    T("com.atlassian.opsgenie",      "Opsgenie (Atlassian)",     "other",        "monitoring",       "opsgenie"),
    T("com.pagerduty.desktop",       "PagerDuty",                "unitedStates", "monitoring",       "pagerduty"),
    T("com.datadog.desktop",         "Datadog",                  "unitedStates", "monitoring",       "datadog"),
    T("com.newrelic.desktop",        "New Relic",                "unitedStates", "monitoring",       "newrelic"),
    T("io.sentry.desktop",           "Sentry",                   "unitedStates", "monitoring",       "sentry"),

    // ─── US cloud / infra CLI ───────────────────────────────────────
    T("com.supabase.mac",            "Supabase Studio",          "unitedStates", "database",    "supabase"),
    T("com.planetscale.desktop",     "PlanetScale CLI",          "unitedStates", "database",    "planetscale"),
    T("com.mongodb.compass",         "MongoDB Compass",          "unitedStates", "database",    "mongo-compass"),
    T("com.cockroachdb.cli",         "CockroachDB CLI",          "unitedStates", "database",    "cockroach"),
    T("com.vercel.desktop",          "Vercel",                   "unitedStates", "cloud-cli",   "vercel"),
    T("com.netlify.desktop",         "Netlify",                  "unitedStates", "cloud-cli",   "netlify"),
    T("com.cloudflare.1dot1dot1",    "Cloudflare 1.1.1.1",       "unitedStates", "vpn",         "cf-one"),
    T("com.flyio.cli",               "Fly.io CLI",               "unitedStates", "cloud-cli",   "flyio"),
    T("com.render.desktop",          "Render",                   "unitedStates", "cloud-cli",   "render"),
    T("com.heroku.cli",              "Heroku CLI",               "unitedStates", "cloud-cli",   "heroku"),
    T("com.amazon.AWSCLI",           "AWS CLI",                  "unitedStates", "cloud-cli",   "awscli"),
    T("com.microsoft.azurecli",      "Azure CLI",                "unitedStates", "cloud-cli",   "azcli"),
    T("com.google.cloud.sdk",        "Google Cloud SDK",         "unitedStates", "cloud-cli",   "gcloud"),
    T("com.digitalocean.cli",        "DigitalOcean doctl",       "unitedStates", "cloud-cli",   "doctl"),
    T("com.linode.cli",              "Linode (Akamai) CLI",      "unitedStates", "cloud-cli",   "linode"),
    T("com.oracle.oci",              "Oracle Cloud CLI",         "unitedStates", "cloud-cli",   "oci"),
    T("com.ibm.cloud.cli",           "IBM Cloud CLI",            "unitedStates", "cloud-cli",   "ibmcloud"),
    T("com.terraform.cli",           "Terraform CLI (HashiCorp)","unitedStates", "cloud-cli-control","tfcli"),
    T("com.hashicorp.vagrant",       "Vagrant",                  "unitedStates", "cloud-cli-control","vagrant"),
    T("com.pulumi.cli",              "Pulumi CLI",               "unitedStates", "cloud-cli-control","pulumi-cli"),

    // ─── US enterprise networking ───────────────────────────────────
    T("com.cisco.anyconnect",        "Cisco AnyConnect",         "unitedStates", "vpn",             "anyconnect"),
    T("com.cisco.umbrella",          "Cisco Umbrella",           "unitedStates", "vpn",             "umbrella"),
    T("com.cisco.secureclient",      "Cisco Secure Client",      "unitedStates", "vpn",             "cisco-sc"),
    T("com.paloaltonetworks.globalprotect","GlobalProtect",      "unitedStates", "vpn",             "globalprotect"),
    T("com.citrix.receiver",         "Citrix Workspace",         "unitedStates", "remote-desktop",  "citrix"),
    T("com.microsoft.rdc",           "Microsoft Remote Desktop", "unitedStates", "remote-desktop",  "rdc"),
    T("com.apple.RemoteDesktop",     "Apple Remote Desktop",     "unitedStates", "remote-desktop",  "ard"),
    T("com.jumpdesktop.Jump",        "Jump Desktop",             "unitedStates", "remote-desktop",  "jumpdesktop"),
    T("com.jamf.pro",                "Jamf Pro",                 "unitedStates", "mdm-agent",       "jamf"),
    T("com.kandji.agent",            "Kandji Agent",             "unitedStates", "mdm-agent",       "kandji"),
    T("com.mosyle.Manager",          "Mosyle Manager",           "other",        "mdm-agent",       "mosyle"),
    T("com.addigy.agent",            "Addigy Agent",             "unitedStates", "mdm-agent",       "addigy"),
    T("com.vmware.airwatch",         "VMware Workspace One",     "unitedStates", "mdm-agent",       "wsone"),
    T("com.webroot.securityanywhere","Webroot SecureAnywhere",   "unitedStates", "antivirus",       "webroot"),
    T("com.norton.antivirus",        "Norton Antivirus",         "unitedStates", "antivirus",       "norton"),
    T("com.mcafee.antivirus",        "McAfee Antivirus",         "unitedStates", "antivirus",       "mcafee"),
    T("com.malwarebytes.Malwarebytes","Malwarebytes",            "unitedStates", "antivirus",       "malwarebytes"),
    T("com.trendmicro.antivirus",    "Trend Micro",              "other",        "antivirus",       "trendmicro"),

    // ─── Adobe suite (expanded) ─────────────────────────────────────
    T("com.adobe.AdobeAfterEffects", "Adobe After Effects",      "unitedStates", "video-edit",      "aftereffects"),
    T("com.adobe.AdobeAudition",     "Adobe Audition",           "unitedStates", "audio-edit",      "audition"),
    T("com.adobe.AdobeAnimate",      "Adobe Animate",            "unitedStates", "video-edit",      "animate"),
    T("com.adobe.Dreamweaver",       "Adobe Dreamweaver",        "unitedStates", "code-editor",     "dreamweaver"),
    T("com.adobe.XD",                "Adobe XD",                 "unitedStates", "vector",          "adobexd"),
    T("com.adobe.Fresco",            "Adobe Fresco",             "unitedStates", "drawing",         "fresco"),
    T("com.adobe.Scan",              "Adobe Scan",               "unitedStates", "pdf",             "adobescan"),
    T("com.adobe.Sign",              "Adobe Sign",               "unitedStates", "e-sign",          "adobesign"),
    T("com.adobe.SubstancePainter",  "Substance Painter",        "unitedStates", "drawing",         "substance"),
    T("com.adobe.InCopy",            "Adobe InCopy",             "unitedStates", "office",          "incopy"),

    // ─── Pro media / CAD ────────────────────────────────────────────
    T("com.avid.ProTools",           "Avid Pro Tools",           "unitedStates", "music-production","protools"),
    T("com.avid.MediaComposer",      "Avid Media Composer",      "unitedStates", "video-edit",      "mediacomposer"),
    T("com.presonus.StudioOne",      "Studio One",               "unitedStates", "music-production","studioone"),
    T("com.cockos.reaper",           "REAPER",                   "other",        "music-production","reaper"),
    T("com.serato.dj",               "Serato DJ Pro",            "other",        "music-production","serato"),
    T("jp.pioneerdj.rekordbox",      "rekordbox",                "other",        "music-production","rekordbox"),
    T("com.apple.logic",             "Logic Pro",                "unitedStates", "music-production","logicpro"),
    T("com.autodesk.AutoCAD",        "AutoCAD",                  "unitedStates", "cad-2d",          "autocad"),
    T("com.autodesk.Fusion360",      "Fusion 360",               "unitedStates", "cad-3d",          "fusion360"),
    T("com.autodesk.Maya",           "Maya",                     "unitedStates", "cad-3d",          "maya"),
    T("com.autodesk.3dsMax",         "3ds Max",                  "unitedStates", "cad-3d",          "3dsmax"),
    T("com.autodesk.Revit",          "Revit",                    "unitedStates", "cad-3d",          "revit"),
    T("com.trimble.SketchUp",        "SketchUp",                 "unitedStates", "cad-3d",          "sketchup"),
    T("com.robertmcneel.Rhinoceros", "Rhino 3D",                 "unitedStates", "cad-3d",          "rhino"),
    T("com.pixologic.zbrush",        "ZBrush",                   "unitedStates", "cad-3d",          "zbrush"),
    T("com.sidefx.houdini",          "Houdini (SideFX)",         "other",        "cad-3d",          "houdini"),
    T("com.blackmagic.fusion",       "Blackmagic Fusion",        "other",        "cad-3d",          "fusion"),

    // ─── Photo apps ─────────────────────────────────────────────────
    T("com.skylum.luminarneo",       "Luminar Neo",              "other",        "photo-edit",      "luminar"),
    T("com.on1.photoraw",            "ON1 Photo RAW",            "unitedStates", "photo-raw",       "on1"),
    T("com.topazlabs.gigapixel",     "Topaz Gigapixel AI",       "unitedStates", "photo-edit",      "topaz"),

    // ─── Writing tools ──────────────────────────────────────────────
    T("com.grammarly.Editor",        "Grammarly for Mac",        "unitedStates", "ai-translate",    "grammarly2"),
    T("com.hemingwayeditor.app",     "Hemingway Editor",         "unitedStates", "notes-pro",       "hemingway"),
    T("com.wordperfect.mac",         "WordPerfect",              "other",        "office",          "wordperfect"),

    // ─── Developer / IDE niche ──────────────────────────────────────
    T("com.github.copilot.desktop",  "GitHub Copilot CLI",       "unitedStates", "ai-chat",         "copilot-cli"),
    T("com.replit.desktop",          "Replit",                   "unitedStates", "ide",             "replit"),
    T("com.tabnine.tabnine-plugin",  "Tabnine",                  "other",        "ai-chat",         "tabnine"),
    T("com.datagrip.app",            "DataGrip",                 "europe",       "database",        "datagrip"),
    T("com.jetbrains.rider",         "JetBrains Rider",          "europe",       "ide",             "rider"),
    T("com.jetbrains.pycharm",       "PyCharm",                  "europe",       "ide",             "pycharm"),
    T("com.cursor.Cursor",           "Cursor (already covered)", "unitedStates", "code-editor",     "cursor-c2"),
    T("com.microsoft.visualstudio",  "Visual Studio for Mac",    "unitedStates", "ide",             "vsmac"),
    T("com.jetbrains.toolbox",       "JetBrains Toolbox",        "europe",       "ide",             "toolbox"),

    // ─── Mac-native utilities (often US) ────────────────────────────
    T("com.flexibits.fantastical3.mac","Fantastical 3",          "unitedStates", "calendar",        "fantastical3"),
    T("com.cardhop.cardhop",         "Cardhop",                  "unitedStates", "calendar",        "cardhop"),
    T("com.rogueamoeba.Audio-Hijack","Audio Hijack",             "unitedStates", "audio-edit",      "audio-hijack"),
    T("com.rogueamoeba.Loopback",    "Loopback",                 "unitedStates", "audio-edit",      "loopback"),
    T("com.rogueamoeba.SoundSource", "SoundSource",              "unitedStates", "audio-edit",      "soundsource"),
    T("com.rogueamoeba.Piezo",       "Piezo",                    "unitedStates", "audio-edit",      "piezo"),
    T("com.readdle.PDFExpert-Mac",   "PDF Expert",               "other",        "pdf",             "pdfexpert"),
    T("com.smileonmymac.PDFpen",     "PDFpen",                   "unitedStates", "pdf",             "pdfpen"),
    T("com.smileonmymac.textexpander","TextExpander",            "unitedStates", "system-util",     "textexpander"),

    // ─── Social / messaging ────────────────────────────────────────
    T("com.toyopagroup.picaboo",     "Snapchat",                 "unitedStates", "social-media",    "snapchat"),
    T("com.tinder.desktop",          "Tinder",                   "unitedStates", "social-media",    "tinder"),
    T("com.zhiliaoapp.musically.lite","TikTok Lite",             "china",        "social-media",    "tiktok-lite"),
    T("com.meta.Threads",            "Threads (Meta)",           "unitedStates", "social-media",    "threads"),
    T("com.reddit.reddit",           "Reddit",                   "unitedStates", "social-media",    "reddit"),
    T("com.pinterest.pinterest",     "Pinterest",                "unitedStates", "social-media",    "pinterest"),
    T("com.linkedin.LinkedIn",       "LinkedIn",                 "unitedStates", "social-media",    "linkedin"),

    // ─── AI desktop ─────────────────────────────────────────────────
    T("com.anthropic.claudeforwindows","Claude Code CLI",        "unitedStates", "ai-chat",         "claude-cli"),
    T("ai.character",                "Character.AI",             "unitedStates", "ai-chat",         "characterai"),
    T("com.google.gemini",           "Google Gemini",            "unitedStates", "ai-chat",         "gemini-desktop"),
    T("com.pi.app",                  "Pi Assistant (Inflection)","unitedStates", "ai-chat",         "pi"),
    T("com.kagi.kagi",               "Kagi Search",              "unitedStates", "ai-chat",         "kagi"),
    T("com.you.you",                 "You.com",                  "unitedStates", "ai-chat",         "you"),
    T("com.poe.Poe",                 "Poe",                      "unitedStates", "ai-chat",         "poe"),
    T("com.mistral.lechat",          "Mistral Le Chat Desktop",  "europe",       "ai-chat",         "lechat-desktop"),
    T("com.raycast.ai",              "Raycast AI",               "unitedStates", "ai-chat",         "raycast-ai"),
    T("com.superwhisper.macos",      "Superwhisper",             "unitedStates", "dictation",       "superwhisper"),

    // ─── Misc Mac apps ──────────────────────────────────────────────
    T("com.github.iina",             "IINA",                     "oss",          "video-player",    "iina-target"),  // skip: OSS
    T("com.elgato.stream-deck",      "Elgato Stream Deck",       "unitedStates", "screen-recording","stream-deck"),
    T("com.elgato.camera-hub",       "Elgato Camera Hub",        "unitedStates", "screen-recording","camera-hub"),
    T("com.razer.Synapse",           "Razer Synapse",            "unitedStates", "system-util",     "razer"),
    T("com.logitech.LogiOptionsPlus","Logitech Options+",        "europe",       "system-util",     "logi"),  // Switzerland — skip
    T("com.corsair.icue",            "iCUE (Corsair)",           "unitedStates", "system-util",     "icue"),
    T("com.steelseries.desktop",     "SteelSeries GG",           "europe",       "system-util",     "steelseries"),  // Denmark — skip

    // ─── Research / reference ───────────────────────────────────────
    T("com.mendeley.desktop",        "Mendeley Reference Manager","europe",      "bibliography",    "mendeley"),  // NL — skip
    T("com.papersapp.papers",        "Papers",                   "europe",        "bibliography",   "papers"),    // Netherlands/Germany — skip
    T("com.citavi.desktop",          "Citavi",                   "europe",        "bibliography",   "citavi"),    // Switzerland — skip
    T("com.elsevier.endnote",        "EndNote Client",           "unitedStates",  "bibliography",   "endnote2"),

    // ─── Backup (US) ───────────────────────────────────────────────
    T("com.carboncopycloner.ccc",    "Carbon Copy Cloner",       "unitedStates",  "backup",         "ccc"),
    T("com.bombich.superduper",      "SuperDuper!",              "unitedStates",  "backup",         "superduper"),
    T("com.iMobie.AnyTrans",         "AnyTrans (iMobie)",        "china",         "backup",         "anytrans"),

    // ─── Archive / compression ─────────────────────────────────────
    T("com.elonin.RARmac",           "RAR for macOS",             "unitedStates", "archive",        "rar"),  // Alexander Roshal; RARLAB US
    T("com.macpaw.TheUnarchiver",    "The Unarchiver",            "other",        "archive",        "unarchiver"),
    T("com.macpaw.BetterZip",        "BetterZip",                 "europe",       "archive",        "betterzip"),  // Germany — skip

    // ─── Scientific / stats ────────────────────────────────────────
    T("com.mathworks.MATLAB",        "MATLAB",                   "unitedStates", "scientific",      "matlab"),
    T("com.wolfram.Mathematica",     "Wolfram Mathematica",      "unitedStates", "scientific",      "mathematica"),
    T("com.ibm.spss.statistics",     "IBM SPSS Statistics",      "unitedStates", "stats",           "spss"),
    T("com.StataCorp.Stata",         "Stata",                    "unitedStates", "stats",           "stata"),
    T("com.sas.desktop",             "SAS",                      "unitedStates", "stats",           "sas"),

    // ─── Knowledge / wiki ──────────────────────────────────────────
    T("com.notion.calendar",         "Notion Calendar (dup chk)","unitedStates", "calendar",        "notioncal-dup"),
    T("co.fellow.fellow",            "Fellow",                   "unitedStates", "knowledge-base",  "fellow"),
    T("com.slab.slab",               "Slab",                     "unitedStates", "knowledge-base",  "slab"),
    T("com.guru.guru",               "Guru",                     "unitedStates", "knowledge-base",  "guru"),

    // ─── Drawing / sketch ──────────────────────────────────────────
    T("com.corel.painter",           "Corel Painter",            "other",        "drawing",         "painter"),  // Canada
    T("com.procreate.procreate",     "Procreate (Mac via iPad)", "other",        "drawing",         "procreate"),  // AU
    T("com.sketchbook.illustrator",  "Autodesk Sketchbook",      "unitedStates", "drawing",         "sketchbook"),

    // ─── Bookmarks / reading ───────────────────────────────────────
    T("com.getpocket.mac",           "Pocket",                   "unitedStates", "feed-reader",     "pocket"),
    T("com.flipboard.flipboard",     "Flipboard",                "unitedStates", "feed-reader",     "flipboard"),
    T("com.news.news",               "News+ (Apple)",            "unitedStates", "feed-reader",     "news-plus"),

    // ─── Menu-bar / utility extras ─────────────────────────────────
    T("com.folivora.BTT",            "BetterTouchTool",          "europe",       "system-util",     "btt"),  // Germany — skip
    T("com.manytricks.Witch",        "Witch",                    "unitedStates", "window-mgmt",     "witch"),
    T("com.knollsoft.Hookshot",      "Rectangle Pro",            "unitedStates", "window-mgmt",     "rectangle-pro"),
    T("com.divvyhq.Divvy",           "Divvy",                    "unitedStates", "window-mgmt",     "divvy"),

    // ─── Document conversion ───────────────────────────────────────
    T("com.lemonsqueezy.lemon",      "Lemon (macOS)",            "other",        "system-util",     "lemon"),
    T("com.abbyy.FineReader",        "ABBYY FineReader Pro",     "russia",       "ocr",             "finereader"),  // ABBYY Russia -> RU (though subsidiaries dispersed)
    T("com.abbyy.passport-reader",   "ABBYY Passport Reader",    "russia",       "ocr",             "abbyy-passport"),

    // ─── Game / entertainment ──────────────────────────────────────
    T("com.epicgames.launcher",      "Epic Games Launcher",      "unitedStates", "system-util",     "epic"),
    T("net.battle.App",              "Battle.net",               "unitedStates", "system-util",     "battlenet"),
    T("com.ea.EAApp",                "EA app",                   "unitedStates", "system-util",     "ea"),
    T("com.ubisoft.connect",         "Ubisoft Connect",          "europe",       "system-util",     "ubi"),  // France — skip

    // ─── Note: originally covered ───────────────────────────────────
    T("org.sparkle-project.Sparkle", "Sparkle Updater",          "oss",          "system-util",     "sparkle"),  // OSS skip

    // ─── More US SaaS ──────────────────────────────────────────────
    T("com.front.front",             "Front",                    "unitedStates", "mail",            "front"),
    T("com.amazon.WorkSpaces",       "Amazon WorkSpaces",        "unitedStates", "remote-desktop",  "workspaces"),
    T("com.citrix.GoToMeeting",      "GoToMeeting (LogMeIn)",    "unitedStates", "video-call",      "gotomeeting"),
    T("com.logmein.logmein-desktop", "LogMeIn Pro",              "unitedStates", "remote-desktop",  "logmein"),
    T("com.teamviewer.meeting2",     "GoTo Webinar",             "unitedStates", "video-call",      "gotowebinar"),
    T("com.webex.meetingmgr",        "Webex Meetings (dup chk)", "unitedStates", "video-call",      "webex2"),
    T("com.lucidchart.lucidchart",   "Lucidchart",               "unitedStates", "drawio",          "lucidchart"),
    T("com.miro.Miro",               "Miro",                     "unitedStates", "drawio",          "miro"),
    T("com.mural.mural",             "Mural",                    "unitedStates", "drawio",          "mural"),
    T("com.whimsical.whimsical",     "Whimsical",                "unitedStates", "drawio",          "whimsical"),

    // ─── More streaming / media ─────────────────────────────────────
    T("com.hulu.plus",               "Hulu",                     "unitedStates", "video-streaming", "hulu"),
    T("com.paramountplus.app",       "Paramount+",               "unitedStates", "video-streaming", "paramount"),
    T("com.peacocktv.desktop",       "Peacock",                  "unitedStates", "video-streaming", "peacock"),
    T("com.hbo.max",                 "HBO Max",                  "unitedStates", "video-streaming", "hbomax"),
    T("com.disney.plus",             "Disney+",                  "unitedStates", "video-streaming", "disneyplus"),
    T("com.netflix.Netflix",         "Netflix (Mac)",            "unitedStates", "video-streaming", "netflix-desktop"),
    T("tv.youtube.YouTubeMusic",     "YouTube Music",            "unitedStates", "music-streaming", "ytmusic"),
    T("com.apple.Music",             "Apple Music",              "unitedStates", "music-streaming", "applemusic-desktop"),
    T("com.pandora.desktop",         "Pandora",                  "unitedStates", "music-streaming", "pandora"),
    T("com.iheart.desktop",          "iHeartRadio",              "unitedStates", "music-streaming", "iheart"),
    T("com.sonos.s2",                "Sonos",                    "unitedStates", "music-streaming", "sonos"),
    T("com.tidal.desktop",           "Tidal",                    "unitedStates", "music-streaming", "tidal"),  // Block Inc US since 2021

    // ─── Accounting / finance ──────────────────────────────────────
    T("com.intuit.QuickBooks",       "QuickBooks Online",        "unitedStates", "finance",         "qb"),
    T("com.intuit.TurboTax",         "TurboTax",                 "unitedStates", "finance",         "turbotax"),
    T("com.mint.intuit",             "Mint",                     "unitedStates", "finance",         "mint"),
    T("com.ynab.YNAB",               "YNAB",                     "unitedStates", "finance",         "ynab"),
    T("com.rocketmoney.app",         "Rocket Money (Truebill)",  "unitedStates", "finance",         "rocketmoney"),
    T("com.copilotmoney.app",        "Copilot Money",            "unitedStates", "finance",         "copilotmoney"),
    T("com.tillerhq.Tiller",         "Tiller",                   "unitedStates", "finance",         "tiller"),
    T("com.xero.desktop",            "Xero Accounting",          "other",        "finance",         "xero"),
    T("com.freshbooks.desktop",      "FreshBooks",               "other",        "finance",         "freshbooks"),
    T("com.sage.accounting",         "Sage Accounting",          "europe",       "finance",         "sage"),  // UK — skip

    // ─── Design niche ──────────────────────────────────────────────
    T("com.bohemiancoding.sketch3",  "Sketch",                   "europe",       "vector",          "sketch"),  // NL — skip target
    T("com.marvel.InVision",         "InVision",                 "unitedStates", "vector",          "invision"),
    T("com.framer.Framer-Desktop",   "Framer Desktop",           "europe",       "vector",          "framer-desktop"),  // NL — skip
    T("com.withtype.type",           "Type",                     "unitedStates", "vector",          "type"),

    // ─── Niche utilities ───────────────────────────────────────────
    T("com.slack.desktop.huddles",   "Slack Huddle (dup)",       "unitedStates", "video-call",      "huddles-dup"),
    T("com.1password.7",             "1Password (alt bundle)",   "other",        "password",        "1p7-dup"),  // CA
    T("com.flashspace.flashspace",   "FlashSpace",               "unitedStates", "window-mgmt",     "flashspace"),

    // ─── Apple ecosystem 3rd-party duplicates ──────────────────────
    T("com.todesktop.cursor",        "Cursor (alt bundle)",      "unitedStates", "code-editor",     "cursor-alt"),
    T("com.todesktop.warp",          "Warp (alt bundle)",        "unitedStates", "terminal",        "warp-alt"),

    // ─── Drawing / sketch / note (dup-check) ───────────────────────
    T("com.craft.CraftDocs",         "Craft",                    "europe",       "notes-pro",       "craft"),  // Hungary — skip
    T("md.obsidian.Obsidian",        "Obsidian (target alt)",    "oss",          "notes-pro",       "obsidian-target"),  // OSS skip

    // ─── Misc consumer ──────────────────────────────────────────────
    T("com.shopify.desktop",         "Shopify Desktop",          "other",        "crm",             "shopify"),  // Canada
    T("com.wise.desktop",            "Wise Business",            "europe",       "finance",         "wise"),  // UK — skip
    T("com.stripe.dashboard",        "Stripe Dashboard",         "unitedStates", "finance",         "stripe"),
    T("com.paypal.desktop",          "PayPal",                   "unitedStates", "finance",         "paypal"),
    T("com.squareup.desktop",        "Square (Block)",           "unitedStates", "finance",         "square"),

    // ─── Crypto wallets ────────────────────────────────────────────
    T("com.coinbase.wallet",         "Coinbase Wallet",          "unitedStates", "finance",         "coinbase"),
    T("com.krakenapp.desktop",       "Kraken Pro",               "unitedStates", "finance",         "kraken"),
    T("io.metamask.desktop",         "MetaMask",                 "unitedStates", "finance",         "metamask"),

    // ─── Dev tools (extra) ─────────────────────────────────────────
    T("com.charlesproxy.Charles",    "Charles Proxy",            "other",        "api-client",      "charles"),  // AU
    T("com.proxyman.NSProxy",        "Proxyman",                 "other",        "api-client",      "proxyman"),  // Vietnam .other
    T("com.kubenav.kubenav",         "KubeNav",                  "other",        "cloud-cli",       "kubenav"),  // Germany — skip actually
    T("io.lens.Lens",                "Lens Kubernetes IDE",      "other",        "cloud-cli",       "lens"),  // Finland — skip technically EU
    T("com.docker.cli",              "Docker CLI (alt bundle)",  "unitedStates", "container",       "docker-cli"),

    // ─── Graphics / media utilities ─────────────────────────────────
    T("com.bezant.graphinity",       "Graphinity",               "unitedStates", "drawio",          "graphinity"),
    T("com.ilovemac.app",            "iLoveIMG",                 "europe",       "photo-edit",      "iloveimg"),  // Spain — skip

    // ─── Edu / children ────────────────────────────────────────────
    T("com.rosettastone.RosettaStone","Rosetta Stone",           "unitedStates", "ai-translate",    "rosettastone"),
    T("com.duolingo.DuolingoDesktop","Duolingo",                 "unitedStates", "ai-translate",    "duolingo"),
    T("com.babbel.desktop",          "Babbel",                   "europe",       "ai-translate",    "babbel"),  // Germany — skip

    // ===========================================================
    // BATCH 2 — deeper coverage of enterprise, niche, and regional.
    // ===========================================================

    // ─── Microsoft family (beyond Office) ──────────────────────────
    T("com.microsoft.Publisher",     "Microsoft Publisher",      "unitedStates", "vector",          "mspub"),
    T("com.microsoft.Access",        "Microsoft Access",         "unitedStates", "database",        "msaccess"),
    T("com.microsoft.Visio",         "Microsoft Visio",          "unitedStates", "drawio",          "visio"),
    T("com.microsoft.Project",       "Microsoft Project",        "unitedStates", "task",            "msproject"),
    T("com.microsoft.Defender",      "Microsoft Defender",       "unitedStates", "antivirus",      "msdefender"),
    T("com.microsoft.Authenticator", "Microsoft Authenticator",  "unitedStates", "password",        "msauth"),
    T("com.microsoft.SwiftKey",      "Microsoft SwiftKey",       "unitedStates", "system-util",     "swiftkey"),
    T("com.microsoft.PowerBI",       "Power BI Desktop",         "unitedStates", "analytics",       "powerbi"),
    T("com.microsoft.PowerAutomate", "Power Automate",           "unitedStates", "crm",             "powerautomate"),
    T("com.microsoft.Yammer",        "Microsoft Yammer (Viva)",  "unitedStates", "chat-team",       "yammer"),
    T("com.microsoft.Kaizala",       "Microsoft Kaizala",        "unitedStates", "chat-team",       "kaizala"),
    T("com.microsoft.CompanyPortal", "Microsoft Intune Portal",  "unitedStates", "mdm-agent",       "intune"),
    T("com.microsoft.Whiteboard",    "Microsoft Whiteboard",     "unitedStates", "drawio",          "mswhiteboard"),
    T("com.microsoft.Forms",         "Microsoft Forms",          "unitedStates", "survey-form",     "msforms"),
    T("com.microsoft.Sway",          "Microsoft Sway",           "unitedStates", "knowledge-base",  "sway"),

    // ─── Google family ──────────────────────────────────────────────
    T("com.google.Keep",             "Google Keep",              "unitedStates", "notes-pro",       "gkeep"),
    T("com.google.Earth",            "Google Earth",             "unitedStates", "map-nav",         "gearth"),
    T("com.google.Jamboard",         "Google Jamboard",          "unitedStates", "drawio",          "gjam"),
    T("com.google.Analytics",        "Google Analytics",         "unitedStates", "analytics",       "ganalytics"),
    T("com.google.Ads",              "Google Ads Editor",        "unitedStates", "analytics",       "gads"),
    T("com.google.Tag-Assistant",    "Google Tag Manager",       "unitedStates", "analytics",       "gtm"),
    T("com.google.Translate",        "Google Translate",         "unitedStates", "ai-translate",    "gtrans"),
    T("com.google.NearbyShare",      "Google Nearby Share",      "unitedStates", "storage-personal","nearby"),
    T("com.google.Voice",            "Google Voice",             "unitedStates", "chat-personal",   "gvoice"),
    T("com.google.Duo",              "Google Duo (Meet Lite)",   "unitedStates", "video-call",      "gduo"),
    T("com.google.Podcasts",         "Google Podcasts",          "unitedStates", "audio-player",    "gpodcasts"),
    T("com.google.Home",             "Google Home",              "unitedStates", "system-util",     "ghome"),
    T("com.google.Fi",               "Google Fi",                "unitedStates", "vpn",             "gfi"),

    // ─── Amazon family ──────────────────────────────────────────────
    T("com.amazon.Kindle",           "Amazon Kindle",            "unitedStates", "reader",          "kindle"),
    T("com.amazon.Photos",           "Amazon Photos",            "unitedStates", "photo-manager",   "amphotos"),
    T("com.amazon.WorkLink",         "Amazon WorkLink",          "unitedStates", "remote-desktop",  "worklink"),
    T("com.amazon.WorkDocs",         "Amazon WorkDocs",          "unitedStates", "storage-business","workdocs"),
    T("com.amazon.WorkMail",         "Amazon WorkMail",          "unitedStates", "mail",            "workmail"),
    T("com.amazon.AppStream",        "Amazon AppStream",         "unitedStates", "remote-desktop",  "appstream"),
    T("com.amazon.Quicksight",       "Amazon QuickSight",        "unitedStates", "analytics",       "quicksight"),
    T("com.amazon.Honeycode",        "Amazon Honeycode",         "unitedStates", "task",            "honeycode"),
    T("com.amazon.Sumerian",         "Amazon Sumerian",          "unitedStates", "cad-3d",          "sumerian"),
    T("com.amazon.Corretto",         "Amazon Corretto",          "unitedStates", "cloud-cli",       "corretto"),

    // ─── Meta family ────────────────────────────────────────────────
    T("com.facebook.WorkplaceChat",  "Workplace Chat",           "unitedStates", "chat-team",       "workplace-chat"),
    T("com.facebook.Portal",         "Facebook Portal",          "unitedStates", "video-call",      "fbportal"),
    T("com.instagram.Direct",        "Instagram Direct",         "unitedStates", "chat-personal",   "igdirect"),
    T("com.instagram.Reels",         "Instagram Reels",          "unitedStates", "social-media",    "igreels"),

    // ─── Apple (paid / subscription) where an alt exists ───────────
    T("com.apple.News",              "Apple News+",              "unitedStates", "feed-reader",     "applenews"),
    T("com.apple.Fitness",           "Apple Fitness+",           "unitedStates", "video-streaming", "fitnessplus"),
    T("com.apple.Arcade",            "Apple Arcade",             "unitedStates", "system-util",     "arcade"),

    // ─── US streaming — all major ───────────────────────────────────
    T("com.appletv.plus",            "Apple TV+",                "unitedStates", "video-streaming", "appletvplus"),
    T("com.crunchyroll.desktop",     "Crunchyroll",              "unitedStates", "video-streaming", "crunchyroll"),
    T("com.funimation.desktop",      "Funimation",               "unitedStates", "video-streaming", "funimation"),
    T("com.pluto.tv",                "Pluto TV",                 "unitedStates", "video-streaming", "pluto"),
    T("com.tubi.tv",                 "Tubi",                     "unitedStates", "video-streaming", "tubi"),
    T("com.vimeo.desktop",           "Vimeo",                    "unitedStates", "video-streaming", "vimeo"),
    T("com.twitch.desktop",          "Twitch",                   "unitedStates", "video-streaming", "twitch"),
    T("com.youtube.tv",              "YouTube TV",               "unitedStates", "video-streaming", "ytubetv"),
    T("com.sling.tv",                "Sling TV",                 "unitedStates", "video-streaming", "sling"),
    T("com.fubo.tv",                 "fuboTV",                   "unitedStates", "video-streaming", "fubo"),
    T("com.discoveryplus.desktop",   "Discovery+",               "unitedStates", "video-streaming", "discoveryplus"),
    T("com.philo.desktop",           "Philo",                    "unitedStates", "video-streaming", "philo"),
    T("com.spectrumtv.desktop",      "Spectrum TV",              "unitedStates", "video-streaming", "spectrum"),
    T("com.hbogo.desktop",           "HBO Go (legacy)",          "unitedStates", "video-streaming", "hbogo"),
    T("com.showtime.desktop",        "Showtime",                 "unitedStates", "video-streaming", "showtime"),
    T("com.starz.desktop",           "Starz",                    "unitedStates", "video-streaming", "starz"),

    // ─── Apple-native where user might seek alts ────────────────────
    T("com.apple.FaceTime",          "FaceTime",                 "unitedStates", "video-call",      "facetime"),
    T("com.apple.iMessage",          "iMessage",                 "unitedStates", "chat-personal",   "imessage"),

    // ─── Fitness / health ──────────────────────────────────────────
    T("com.myfitnesspal.desktop",    "MyFitnessPal",             "unitedStates", "habit-track",     "mfp"),
    T("com.nike.runclub",            "Nike Run Club",            "unitedStates", "habit-track",     "nrc"),
    T("com.strava.desktop",          "Strava",                   "unitedStates", "habit-track",     "strava"),
    T("com.withings.health-mate",    "Withings Health Mate",     "europe",       "habit-track",     "withings"),  // France — skip
    T("com.garmin.connect",          "Garmin Connect",           "unitedStates", "habit-track",     "garmin"),
    T("com.peloton.desktop",         "Peloton",                  "unitedStates", "video-streaming", "peloton"),
    T("com.fitbit.desktop",          "Fitbit (Google)",          "unitedStates", "habit-track",     "fitbit"),
    T("com.noom.desktop",            "Noom",                     "unitedStates", "habit-track",     "noom"),
    T("com.betterhelp.desktop",      "BetterHelp",               "unitedStates", "video-call",      "betterhelp"),
    T("com.talkspace.desktop",       "Talkspace",                "unitedStates", "video-call",      "talkspace"),

    // ─── Meditation / mental ───────────────────────────────────────
    T("com.calm.desktop",            "Calm",                     "unitedStates", "audio-player",    "calm"),
    T("com.headspace.desktop",       "Headspace",                "europe",       "audio-player",    "headspace"),  // UK-founded — skip
    T("com.wakingup.app",            "Waking Up (Sam Harris)",   "unitedStates", "audio-player",    "wakingup"),
    T("com.sleep.cycle",             "Sleep Cycle",              "europe",       "habit-track",     "sleepcycle"),  // Sweden — skip

    // ─── Dating ────────────────────────────────────────────────────
    T("com.match.desktop",           "Match.com",                "unitedStates", "social-media",    "match"),
    T("com.okcupid.desktop",         "OkCupid",                  "unitedStates", "social-media",    "okcupid"),
    T("com.hinge.desktop",           "Hinge",                    "unitedStates", "social-media",    "hinge"),
    T("com.bumble.desktop",          "Bumble",                   "unitedStates", "social-media",    "bumble"),

    // ─── Travel / transport ────────────────────────────────────────
    T("com.airbnb.desktop",          "Airbnb",                   "unitedStates", "social-media",    "airbnb"),
    T("com.expedia.desktop",         "Expedia",                  "unitedStates", "social-media",    "expedia"),
    T("com.booking.desktop",         "Booking.com",              "europe",       "social-media",    "booking"),  // NL — skip
    T("com.hotelscom.desktop",       "Hotels.com",               "unitedStates", "social-media",    "hotelscom"),
    T("com.kayak.desktop",           "Kayak",                    "unitedStates", "social-media",    "kayak"),
    T("com.skyscanner.desktop",      "Skyscanner",               "europe",       "social-media",    "skyscanner"),  // UK — skip
    T("com.tripadvisor.desktop",     "TripAdvisor",              "unitedStates", "social-media",    "tripadvisor"),
    T("com.yelp.desktop",            "Yelp",                     "unitedStates", "social-media",    "yelp"),
    T("com.uber.desktop",            "Uber",                     "unitedStates", "social-media",    "uber"),
    T("com.lyft.desktop",            "Lyft",                     "unitedStates", "social-media",    "lyft"),
    T("com.bolt.desktop",            "Bolt",                     "europe",       "social-media",    "bolt"),  // Estonia — skip
    T("com.citymapper.desktop",      "Citymapper",               "europe",       "map-nav",         "citymapper"),  // UK — skip
    T("com.waze.desktop",            "Waze",                     "unitedStates", "map-nav",         "waze"),
    T("com.doordash.desktop",        "DoorDash",                 "unitedStates", "social-media",    "doordash"),
    T("com.ubereats.desktop",        "Uber Eats",                "unitedStates", "social-media",    "ubereats"),
    T("com.grubhub.desktop",         "Grubhub",                  "unitedStates", "social-media",    "grubhub"),
    T("com.deliveroo.desktop",       "Deliveroo",                "europe",       "social-media",    "deliveroo"),  // UK — skip
    T("com.justeat.desktop",         "Just Eat",                 "europe",       "social-media",    "justeat"),  // UK/NL — skip
    T("com.instacart.desktop",       "Instacart",                "unitedStates", "social-media",    "instacart"),

    // ─── US productivity utilities ─────────────────────────────────
    T("com.spotify.podcasters",      "Spotify for Podcasters",   "europe",       "audio-edit",      "spot-pod"),  // SE — skip
    T("com.descript.desktop-v2",     "Descript v2",              "unitedStates", "video-edit",      "descript-v2"),
    T("com.musiio.desktop",          "Musiio by SoundCloud",     "unitedStates", "music-production","musiio"),
    T("com.soundcloud.desktop",      "SoundCloud",               "europe",       "music-streaming", "soundcloud"),  // DE — skip
    T("com.bandcamp.desktop",        "Bandcamp",                 "unitedStates", "music-streaming", "bandcamp"),
    T("com.ticketmaster.desktop",    "Ticketmaster",             "unitedStates", "social-media",    "ticketmaster"),
    T("com.eventbrite.desktop",      "Eventbrite",               "unitedStates", "scheduling",      "eventbrite"),
    T("com.meetup.desktop",          "Meetup",                   "unitedStates", "social-media",    "meetup"),

    // ─── US SaaS category more ─────────────────────────────────────
    T("com.klaviyo.desktop",         "Klaviyo",                  "unitedStates", "email-marketing", "klaviyo"),
    T("com.convertkit.desktop",      "ConvertKit",               "unitedStates", "email-marketing", "convertkit"),
    T("com.sendgrid.desktop",        "Twilio SendGrid",          "unitedStates", "email-marketing", "sendgrid"),
    T("com.twilio.desktop",          "Twilio Console",           "unitedStates", "chat-team",       "twilio"),
    T("com.hootsuite.desktop",       "Hootsuite",                "other",        "social-media",    "hootsuite"),  // Canada
    T("com.buffer.desktop",          "Buffer",                   "unitedStates", "social-media",    "buffer"),
    T("com.later.desktop",           "Later",                    "other",        "social-media",    "later"),  // Canada
    T("com.sproutsocial.desktop",    "Sprout Social",            "unitedStates", "social-media",    "sprout"),

    // ─── US creative SaaS ──────────────────────────────────────────
    T("com.splice.desktop",          "Splice",                   "unitedStates", "music-production","splice"),
    T("com.landr.desktop",           "LANDR",                    "other",        "music-production","landr"),  // Canada
    T("com.iZotope.neutron",         "iZotope Neutron",          "unitedStates", "audio-edit",      "izotope"),
    T("com.nativeinstruments.kontakt","Native Instruments Kontakt","europe",     "music-production","kontakt"),  // DE — skip

    // ─── Dev / APIs / cloud extras ─────────────────────────────────
    T("com.fastly.desktop",          "Fastly CLI",               "unitedStates", "cloud-cli",       "fastly"),
    T("com.akamai.desktop",          "Akamai CLI",               "unitedStates", "cloud-cli",       "akamai"),
    T("com.circleci.desktop",        "CircleCI Local",           "unitedStates", "cloud-cli-control","circleci"),
    T("com.travisci.desktop",        "Travis CI CLI",            "unitedStates", "cloud-cli-control","travis"),
    T("com.buildkite.desktop",       "Buildkite CLI",            "other",        "cloud-cli-control","buildkite"),  // AU
    T("com.github.cli",              "GitHub CLI",               "unitedStates", "cloud-cli",       "ghcli"),
    T("com.gitlab.cli",              "GitLab CLI (glab)",        "europe",       "cloud-cli",       "glab"),  // US-HQ'd but OSS NL origin — skip marking as target
    T("com.bitbucket.desktop",       "Bitbucket",                "other",        "cloud-cli",       "bitbucket"),  // Atlassian AU
    T("com.sonarsource.desktop",     "SonarCloud",               "europe",       "monitoring",      "sonarcloud"),  // Switzerland — skip
    T("com.snyk.desktop",            "Snyk",                     "europe",       "monitoring",      "snyk"),  // UK — skip
    T("com.auth0.desktop",           "Auth0 (Okta)",             "unitedStates", "password-sso",    "auth0"),
    T("com.okta.desktop",            "Okta",                     "unitedStates", "password-sso",    "okta"),
    T("com.onelogin.desktop",        "OneLogin",                 "unitedStates", "password-sso",    "onelogin"),
    T("com.ping.desktop",            "Ping Identity",            "unitedStates", "password-sso",    "ping"),

    // ─── Datadog-alt / monitoring ─────────────────────────────────
    T("com.dynatrace.desktop",       "Dynatrace",                "europe",       "monitoring",      "dynatrace"),  // Austria — skip
    T("com.appdynamics.desktop",     "Cisco AppDynamics",        "unitedStates", "monitoring",      "appd"),
    T("com.splunk.desktop",          "Splunk",                   "unitedStates", "monitoring",      "splunk"),
    T("com.sumologic.desktop",       "Sumo Logic",               "unitedStates", "monitoring",      "sumo"),
    T("com.elastic.desktop",         "Elastic / Kibana",         "unitedStates", "monitoring",      "elastic"),
    T("com.honeycomb.desktop",       "Honeycomb",                "unitedStates", "monitoring",      "honeycomb"),
    T("com.bugsnag.desktop",         "Bugsnag (SmartBear)",      "unitedStates", "monitoring",      "bugsnag"),
    T("com.rollbar.desktop",         "Rollbar",                  "unitedStates", "monitoring",      "rollbar"),
    T("com.raygun.desktop",          "Raygun",                   "other",        "monitoring",      "raygun"),  // NZ
    T("com.appsignal.desktop",       "AppSignal",                "europe",       "monitoring",      "appsignal"),  // NL — skip

    // ─── US / other dev niche ──────────────────────────────────────
    T("com.launchdarkly.desktop",    "LaunchDarkly",             "unitedStates", "cloud-cli-control","ld"),
    T("com.optimizely.desktop",      "Optimizely",               "unitedStates", "analytics",       "optimizely"),
    T("com.mixpanel.desktop",        "Mixpanel",                 "unitedStates", "analytics",       "mixpanel"),
    T("com.amplitude.desktop",       "Amplitude",                "unitedStates", "analytics",       "amplitude"),
    T("com.segment.desktop",         "Segment (Twilio)",         "unitedStates", "analytics",       "segment"),
    T("com.posthog.desktop",         "PostHog",                  "unitedStates", "analytics",       "posthog"),
    T("com.heap.desktop",            "Heap",                     "unitedStates", "analytics",       "heap"),
    T("com.fullstory.desktop",       "FullStory",                "unitedStates", "analytics",       "fullstory"),
    T("com.contentful.desktop",      "Contentful",               "europe",       "knowledge-base",  "contentful"),  // DE — skip
    T("com.sanity.desktop",          "Sanity.io",                "europe",       "knowledge-base",  "sanity"),  // NO — skip
    T("com.strapi.desktop",          "Strapi",                   "europe",       "knowledge-base",  "strapi"),  // FR — skip

    // ─── US media pro ──────────────────────────────────────────────
    T("com.apple.FinalCutPro",       "Final Cut Pro",            "unitedStates", "video-edit",      "fcpx"),
    T("com.apple.Motion",            "Motion (Apple)",           "unitedStates", "video-edit",      "motion"),
    T("com.apple.Compressor",        "Compressor (Apple)",       "unitedStates", "video-edit",      "compressor"),
    T("com.adobe.MediaEncoder",      "Adobe Media Encoder",      "unitedStates", "video-edit",      "adobe-me"),
    T("com.adobe.Speech-to-Text",    "Adobe Speech to Text",     "unitedStates", "dictation",       "adobe-stt"),

    // ─── More CN apps ──────────────────────────────────────────────
    T("com.tencent.foxmail",         "Foxmail",                  "china",        "mail",            "foxmail"),
    T("com.huawei.cloudlink",        "Huawei CloudLink",         "china",        "video-call",      "cloudlink"),
    T("com.huawei.welink",           "Huawei WeLink",            "china",        "chat-team",       "welink"),
    T("com.tencent.efficientOffice", "Tencent Meeting Docs",     "china",        "office",          "tencent-docs2"),
    T("com.douban.mac",              "Douban",                   "china",        "social-media",    "douban"),
    T("com.bytedance.volc-engine",   "Volcengine",               "china",        "cloud-cli",       "volcengine"),
    T("com.baidu.smartbox",          "Baidu Smartbox",           "china",        "ai-chat",         "baidu-smartbox"),
    T("com.sohu.video",              "Sohu Video",               "china",        "video-streaming", "sohu"),
    T("com.letv.video",              "LeTV",                     "china",        "video-streaming", "letv"),
    T("com.weibo.intl",              "Weibo Intl",               "china",        "social-media",    "weibo-intl"),
    T("com.baidu.tieba",             "Baidu Tieba",              "china",        "social-media",    "tieba"),
    T("com.zhihu.desktop",           "Zhihu",                    "china",        "social-media",    "zhihu"),
    T("com.pdd.pinduoduo",           "Pinduoduo",                "china",        "social-media",    "pinduoduo"),
    T("com.taobao.desktop",          "Taobao",                   "china",        "social-media",    "taobao"),
    T("com.jd.desktop",              "JD.com",                   "china",        "social-media",    "jd"),
    T("com.meituan.desktop",         "Meituan",                  "china",        "social-media",    "meituan"),
    T("com.eleme.desktop",           "Ele.me",                   "china",        "social-media",    "eleme"),
    T("com.didiglobal.desktop",      "Didi Chuxing",             "china",        "social-media",    "didi"),
    T("com.trip.desktop",            "Trip.com (Ctrip)",         "china",        "social-media",    "trip"),
    T("com.fliggy.desktop",          "Fliggy (Alibaba)",         "china",        "social-media",    "fliggy"),
    T("com.qidian.reader",           "Qidian Reader",            "china",        "reader",          "qidian"),
    T("com.sina.blog-mac",           "Sina Blog",                "china",        "social-media",    "sinablog"),
    T("com.sohu.mail",               "Sohu Mail",                "china",        "mail",            "sohumail"),
    T("com.coolapk.desktop",         "Coolapk",                  "china",        "social-media",    "coolapk"),

    // ─── More RU (Yandex family + telco) ──────────────────────────
    T("ru.yandex.cloud",             "Yandex Cloud CLI",         "russia",       "cloud-cli",       "yacloud"),
    T("ru.yandex.eda",               "Yandex Eda",               "russia",       "social-media",    "yaeda"),
    T("ru.yandex.go",                "Yandex Go",                "russia",       "map-nav",         "yago"),
    T("ru.yandex.lavka",             "Yandex Lavka",             "russia",       "social-media",    "yalavka"),
    T("ru.yandex.market",            "Yandex Market",            "russia",       "social-media",    "yamarket"),
    T("ru.yandex.taxi",              "Yandex Taxi",              "russia",       "map-nav",         "yataxi"),
    T("ru.yandex.weather",           "Yandex Weather",           "russia",       "map-nav",         "yaweather"),
    T("ru.yandex.realty",            "Yandex Realty",            "russia",       "social-media",    "yarealty"),
    T("ru.yandex.zen",               "Yandex Zen (Dzen)",        "russia",       "feed-reader",     "yazen"),
    T("ru.yandex.kinopoisk",         "Kinopoisk HD",             "russia",       "video-streaming", "kinopoisk"),
    T("ru.mail.cloud",               "Mail.ru Cloud",            "russia",       "storage-personal","mailcloud"),
    T("ru.mail.calendar",            "Mail.ru Calendar",         "russia",       "calendar",        "mailcal"),
    T("ru.mail.games",               "Mail.ru Games",            "russia",       "social-media",    "mailgames"),
    T("ru.mtslink.desktop",          "MTS Link",                 "russia",       "video-call",      "mtslink"),
    T("ru.mosru.desktop",            "Mos.ru (Moscow)",          "russia",       "social-media",    "mosru"),
    T("ru.gosuslugi.desktop",        "Gosuslugi",                "russia",       "social-media",    "gosuslugi"),
    T("ru.nspk.pay",                 "SBP Mir Pay",              "russia",       "finance",         "mirpay"),

    // ─── More US SaaS consumer / prosumer ──────────────────────────
    T("com.notion.ai",               "Notion AI",                "unitedStates", "ai-chat",         "notion-ai"),
    T("com.bearapp.bear-mac",        "Bear (target-alt)",        "europe",       "notes-pro",       "bear-target"),  // IT — skip
    T("com.craft.manager",           "Craft (target)",           "europe",       "notes-pro",       "craft-target"),  // HU — skip
    T("com.typora.typora",           "Typora",                   "other",        "notes-pro",       "typora"),  // CN/global author, .other
    T("com.marktext.marktext",       "Mark Text",                "oss",          "notes-pro",       "marktext-t"),  // OSS skip

    // ─── Apple dev / code ──────────────────────────────────────────
    T("com.apple.dt.Xcode",          "Xcode",                    "unitedStates", "ide",             "xcode"),
    T("com.apple.Swift-Playgrounds", "Swift Playgrounds",        "unitedStates", "ide",             "swift-pg"),
    T("com.apple.iPhoneSimulator",   "iOS Simulator (Xcode)",    "unitedStates", "ide",             "iossim"),

    // ─── Game launchers ────────────────────────────────────────────
    T("com.unity.UnityHub",          "Unity Hub",                "unitedStates", "cad-3d",          "unity"),
    T("com.unrealengine.UnrealEngine","Unreal Engine",           "unitedStates", "cad-3d",          "unreal"),
    T("com.gamemaker.studio",        "GameMaker Studio",         "other",        "cad-3d",          "gamemaker"),  // NZ
    T("com.rockstar.launcher",       "Rockstar Games Launcher",  "unitedStates", "system-util",     "rockstar"),
    T("com.riot.leagueclient",       "League of Legends Client", "unitedStates", "system-util",     "lol"),
    T("com.blizzard.overwatch",      "Overwatch 2",              "unitedStates", "system-util",     "ow2"),
    T("com.valvesoftware.dota",      "Dota 2 (Steam)",           "unitedStates", "system-util",     "dota2"),

    // ─── More misc Mac apps ────────────────────────────────────────
    T("com.pilotmoon.popclip",       "PopClip",                  "other",        "system-util",     "popclip"),  // UK indie — .other
    T("com.obdev.LittleSnitch",      "Little Snitch",            "europe",       "system-util",     "littlesnitch"),  // AT — skip
    T("com.objective-see.LuLu",      "LuLu Firewall (Objective-See)","oss",      "system-util",     "lulu-t"),  // OSS skip
    T("com.lingon.LingonX",          "Lingon X",                 "europe",       "system-util",     "lingon"),  // SE — skip
    T("com.daisy-disk.DaisyDisk",    "DaisyDisk",                "other",        "disk-util",       "daisydisk"),  // unclear origin
    T("com.cleanmymac.X",            "CleanMyMac X",             "other",        "disk-util",       "cleanmymac"),  // Ukraine (MacPaw)
    T("com.setapp.Setapp",           "Setapp",                   "other",        "system-util",     "setapp"),  // Ukraine (MacPaw)
    T("com.macpaw.gemini",           "Gemini 2",                 "other",        "disk-util",       "gemini-mp"),
    T("com.macpaw.CleanMyMac-Business","CleanMyMac Business",    "other",        "disk-util",       "cmb"),

    // ─── Niche CN cloud/SaaS ────────────────────────────────────────
    T("com.tencent.cloud",           "Tencent Cloud CLI",        "china",        "cloud-cli",       "tcloud"),
    T("com.aliyun.cli",              "Alibaba Cloud CLI",        "china",        "cloud-cli",       "aliyun"),
    T("com.kingdee.desktop",         "Kingdee ERP",              "china",        "crm",             "kingdee"),
    T("com.seeyon.desktop",          "Seeyon Collaboration",     "china",        "chat-team",       "seeyon"),
    T("com.microlink.desktop",       "Tencent WeWork (internal)","china",        "chat-team",       "wework-cn"),
    T("com.xiaoyi.desktop",          "Xiaoyi Robot",             "china",        "ai-chat",         "xiaoyi"),
    T("com.aliyun.pan",              "Alibaba Cloud Disk",       "china",        "storage-personal","alicloud-disk"),
    T("com.kingsoft.cloud",          "KingSoft Cloud",           "china",        "storage-personal","kscloud"),

    // ─── E-commerce / marketplaces ─────────────────────────────────
    T("com.ebay.desktop",            "eBay",                     "unitedStates", "social-media",    "ebay"),
    T("com.etsy.desktop",            "Etsy",                     "unitedStates", "social-media",    "etsy"),
    T("com.walmart.desktop",         "Walmart",                  "unitedStates", "social-media",    "walmart"),
    T("com.target.desktop",          "Target",                   "unitedStates", "social-media",    "target-retail"),
    T("com.bestbuy.desktop",         "Best Buy",                 "unitedStates", "social-media",    "bestbuy"),
    T("com.costco.desktop",          "Costco",                   "unitedStates", "social-media",    "costco"),

    // ─── Professional research ─────────────────────────────────────
    T("com.scopus.desktop",          "Scopus (Elsevier)",        "europe",       "bibliography",    "scopus"),  // NL — skip
    T("com.webofscience.desktop",    "Web of Science (Clarivate)","unitedStates","bibliography",    "wos"),
    T("com.refworks.desktop",        "RefWorks (ProQuest)",      "unitedStates", "bibliography",    "refworks"),
    T("com.annenberg.desktop",       "Annenberg Learner",        "unitedStates", "video-streaming", "annenberg"),

    // ─── Random Mac utilities worth listing ────────────────────────
    T("com.pilotmoon.keyboard-maestro","Keyboard Maestro",       "other",        "system-util",     "km"),  // AU
    T("com.folivora.Hammerspoon",    "Hammerspoon",              "oss",          "system-util",     "hammerspoon-t"),  // OSS skip
    T("com.karabiner.elements",      "Karabiner-Elements",       "oss",          "system-util",     "karabiner-t"),  // OSS skip
    T("com.fadel.Hand-Mirror",       "Hand Mirror",              "unitedStates", "system-util",     "handmirror"),
    T("com.mic-drop.desktop",        "Mic Drop",                 "unitedStates", "system-util",     "micdrop"),
    T("com.fadel.iMazing",           "iMazing",                  "europe",       "backup",          "imazing"),  // CH — skip

    // ─── US investment / stock apps ────────────────────────────────
    T("com.robinhood.desktop",       "Robinhood",                "unitedStates", "finance",         "robinhood"),
    T("com.etoro.desktop",           "eToro",                    "europe",       "finance",         "etoro"),  // Israel/UK — .other
    T("com.schwab.desktop",          "Charles Schwab",           "unitedStates", "finance",         "schwab"),
    T("com.fidelity.desktop",        "Fidelity",                 "unitedStates", "finance",         "fidelity"),
    T("com.etrade.desktop",          "E*TRADE",                  "unitedStates", "finance",         "etrade"),
    T("com.tdameritrade.desktop",    "TD Ameritrade",            "unitedStates", "finance",         "tda"),

    // ─── More enterprise/HR SaaS ───────────────────────────────────
    T("com.greenhouse.desktop",      "Greenhouse ATS",           "unitedStates", "crm",             "greenhouse"),
    T("com.lever.desktop",           "Lever ATS",                "unitedStates", "crm",             "lever"),
    T("com.workable.desktop",        "Workable ATS",             "europe",       "crm",             "workable"),  // Greece — skip
    T("com.bamboohr.desktop",        "BambooHR",                 "unitedStates", "crm",             "bamboohr"),
    T("com.gusto.desktop",           "Gusto",                    "unitedStates", "crm",             "gusto"),
    T("com.deel.desktop",            "Deel",                     "unitedStates", "crm",             "deel"),
    T("com.remote.desktop",          "Remote.com (Portugal-HQ)", "europe",       "crm",             "remote"),  // PT — skip
    T("com.rippling.desktop",        "Rippling",                 "unitedStates", "crm",             "rippling"),
    T("com.zenefits.desktop",        "TriNet Zenefits",          "unitedStates", "crm",             "zenefits"),
    T("com.justworks.desktop",       "Justworks",                "unitedStates", "crm",             "justworks"),

    // ─── US legal / document ───────────────────────────────────────
    T("com.rocketlawyer.desktop",    "Rocket Lawyer",            "unitedStates", "e-sign",          "rocketlawyer"),
    T("com.legalzoom.desktop",       "LegalZoom",                "unitedStates", "e-sign",          "legalzoom"),
    T("com.docracy.desktop",         "Docracy",                  "unitedStates", "e-sign",          "docracy"),
    T("com.clerky.desktop",          "Clerky",                   "unitedStates", "e-sign",          "clerky"),

    // ─── Gaming platforms (more) ───────────────────────────────────
    T("com.gog.GogGalaxy",           "GOG Galaxy (dup-chk)",     "europe",       "system-util",     "gog-galaxy-dup"),  // PL — skip

    // ─── Shell / dev tooling  ──────────────────────────────────────
    T("com.github.desktop",          "GitHub Desktop (dup-chk)", "unitedStates", "git-gui",         "ghd-dup"),
    T("com.sourcetree.app",          "Sourcetree (dup-chk)",     "other",        "git-gui",         "sourcetree-dup"),
    T("com.tower.git",               "Tower Git",                "europe",       "git-gui",         "tower"),  // Germany — skip
    T("com.smartgit.SmartGit",       "SmartGit",                 "europe",       "git-gui",         "smartgit"),  // Germany — skip
    T("com.kaleidoscope.diff",       "Kaleidoscope 3",           "other",        "git-gui",         "kaleidoscope"),  // Austria .other

    // ─── Indian / SEA productivity apps ────────────────────────────
    T("com.zohocrm.desktop",         "Zoho CRM",                 "other",        "crm",             "zoho-crm"),
    T("com.zoho.mail",               "Zoho Mail",                "other",        "mail",            "zohomail"),
    T("com.zoho.notebook",           "Zoho Notebook",            "other",        "notes-pro",       "zohonote"),
    T("com.zoho.meeting",            "Zoho Meeting",             "other",        "video-call",      "zohomeet"),
    T("com.zoho.people",             "Zoho People",              "other",        "crm",             "zohopeople"),
    T("com.freshworks.freshdesk",    "Freshdesk (Freshworks)",   "other",        "crm",             "freshworks-fd"),
    T("com.enpass.Enpass",           "Enpass",                   "other",        "password",        "enpass"),  // India

    // ─── Last misc ────────────────────────────────────────────────
    T("com.pocketcasts.mac",         "Pocket Casts (Automattic)","unitedStates", "audio-player",    "pocketcasts"),
    T("com.overcast.mac",            "Overcast",                 "unitedStates", "audio-player",    "overcast"),
    T("com.castro.desktop",          "Castro",                   "europe",       "audio-player",    "castro"),  // Ireland — skip
    T("com.snipcart.desktop",        "Snipcart",                 "other",        "crm",             "snipcart"),  // Canada
    T("com.stripe.terminal",         "Stripe Terminal",          "unitedStates", "finance",         "stripe-term"),
    T("com.adyen.desktop",           "Adyen",                    "europe",       "finance",         "adyen"),  // NL — skip
    T("com.plaid.desktop",           "Plaid Link",               "unitedStates", "finance",         "plaid"),

    // ===========================================================
    // BATCH 3 — push toward 900+ entries.  Long-tail apps across
    // regional markets, niche Mac utilities, and enterprise SaaS.
    // ===========================================================

    // ─── Japanese apps (.other) ────────────────────────────────────
    T("jp.naver.LineMac",            "LINE (alt bundle)",        "other",        "chat-personal",   "line-alt"),
    T("jp.co.rakuten.viber",         "Rakuten Viber",            "other",        "chat-personal",   "viber"),
    T("jp.co.cybozu.office",         "Cybozu Office",            "other",        "office",          "cybozu"),
    T("jp.co.cybozu.kintone",        "Kintone",                  "other",        "task",            "kintone"),
    T("jp.co.chatwork.chatwork",     "Chatwork",                 "other",        "chat-team",       "chatwork"),
    T("jp.co.nhk.ondemand",          "NHK On Demand",            "other",        "video-streaming", "nhk"),
    T("jp.co.niconico.niconico",     "Niconico",                 "other",        "video-streaming", "niconico"),
    T("jp.co.abematv.abema",         "ABEMA TV",                 "other",        "video-streaming", "abema"),
    T("jp.co.sme.skebbers",          "Skebb",                    "other",        "social-media",    "skebb"),
    T("jp.co.dmm.desktop",           "DMM.com",                  "other",        "social-media",    "dmm"),
    T("jp.co.yahoo.yahoomail",       "Yahoo! Japan Mail",        "other",        "mail",            "yahoo-jp-mail"),
    T("jp.co.kddi.desktop",          "KDDI au",                  "other",        "system-util",     "kddi"),

    // ─── Korean apps (.other) ──────────────────────────────────────
    T("kr.co.kakaocorp.KakaoTalk",   "KakaoTalk",                "other",        "chat-personal",   "kakao"),
    T("kr.co.kakao.kakaostory",      "Kakao Story",              "other",        "social-media",    "kakaostory"),
    T("kr.co.kakao.kakaomap",        "Kakao Maps",               "other",        "map-nav",         "kakaomap"),
    T("kr.co.naver.line",            "Naver LINE",               "other",        "chat-personal",   "naver-line"),
    T("kr.co.naver.whale",           "Naver Whale",              "other",        "browser",         "whale"),
    T("kr.co.naver.papago",          "Naver Papago",             "other",        "ai-translate",    "papago"),
    T("kr.co.naver.vlive",           "V LIVE",                   "other",        "video-streaming", "vlive"),
    T("kr.co.samsung.cloud",         "Samsung Cloud",            "other",        "storage-personal","samsung-cloud"),
    T("kr.co.samsung.pay",           "Samsung Pay",              "other",        "finance",         "samsung-pay"),
    T("kr.co.hancom.HancomOffice",   "Hancom Office",            "other",        "office",          "hancom"),
    T("kr.co.coupang.desktop",       "Coupang",                  "other",        "social-media",    "coupang"),
    T("kr.co.daum.cafe",             "Daum Cafe",                "other",        "social-media",    "daumcafe"),

    // ─── Indian apps (.other) ──────────────────────────────────────
    T("com.paytm.desktop",           "Paytm",                    "other",        "finance",         "paytm"),
    T("com.phonepe.desktop",         "PhonePe",                  "other",        "finance",         "phonepe"),
    T("com.razorpay.desktop",        "Razorpay",                 "other",        "finance",         "razorpay"),
    T("com.swiggy.desktop",          "Swiggy",                   "other",        "social-media",    "swiggy"),
    T("com.zomato.desktop",          "Zomato",                   "other",        "social-media",    "zomato"),
    T("com.flipkart.desktop",        "Flipkart",                 "other",        "social-media",    "flipkart"),
    T("com.oyorooms.desktop",        "OYO Rooms",                "other",        "social-media",    "oyo"),
    T("com.hotstar.desktop",         "Disney+ Hotstar",          "unitedStates", "video-streaming", "hotstar"),
    T("com.zee5.desktop",            "ZEE5",                     "other",        "video-streaming", "zee5"),
    T("com.sonyliv.desktop",         "SonyLIV",                  "other",        "video-streaming", "sonyliv"),
    T("com.jio.Saavn",               "JioSaavn",                 "other",        "music-streaming", "saavn"),
    T("com.gaana.desktop",           "Gaana",                    "other",        "music-streaming", "gaana"),
    T("com.truecaller.desktop",      "Truecaller",               "other",        "chat-personal",   "truecaller"),
    T("com.sharechat.desktop",       "ShareChat",                "other",        "social-media",    "sharechat"),

    // ─── Brazilian apps (.other) ───────────────────────────────────
    T("com.br.globoplay",            "Globoplay",                "other",        "video-streaming", "globoplay"),
    T("com.br.nubank",               "Nubank",                   "other",        "finance",         "nubank"),
    T("com.br.picpay",               "PicPay",                   "other",        "finance",         "picpay"),
    T("com.br.rappi",                "Rappi",                    "other",        "social-media",    "rappi"),
    T("com.br.mercadolivre",         "Mercado Livre",            "other",        "social-media",    "mercadolibre"),
    T("com.br.ifood",                "iFood",                    "other",        "social-media",    "ifood"),
    T("com.br.olx",                  "OLX",                      "other",        "social-media",    "olx"),

    // ─── Turkey / Middle East (.other) ─────────────────────────────
    T("com.tr.yemeksepeti",          "Yemeksepeti",              "other",        "social-media",    "yemeksepeti"),
    T("com.tr.getir",                "Getir",                    "other",        "social-media",    "getir"),
    T("com.tr.trendyol",             "Trendyol",                 "other",        "social-media",    "trendyol"),
    T("com.tr.hepsiburada",          "Hepsiburada",              "other",        "social-media",    "hepsiburada"),
    T("com.ae.careem",               "Careem",                   "other",        "social-media",    "careem"),
    T("com.ae.talabat",              "Talabat",                  "other",        "social-media",    "talabat"),
    T("com.ae.noon",                 "Noon",                     "other",        "social-media",    "noon"),

    // ─── More CN niche ─────────────────────────────────────────────
    T("com.tencent.mail.Foxmail-enterprise","Foxmail Enterprise","china",        "mail",            "foxmail-ent"),
    T("com.tencent.qqsafe",          "QQ Safe (Security)",       "china",        "antivirus",       "qqsafe"),
    T("com.tencent.PCmgr",           "Tencent PC Manager",       "china",        "antivirus",       "pcmgr"),
    T("com.qihoo.safeguard",         "360 Safeguard",            "china",        "antivirus",       "360safe"),
    T("com.huorong.desktop",         "Huorong Antivirus",        "china",        "antivirus",       "huorong"),
    T("com.rising.desktop",          "Rising Antivirus",         "china",        "antivirus",       "rising"),
    T("com.tencent.weishi",          "WeiShi",                   "china",        "social-media",    "weishi"),
    T("com.baidu.hao123",            "Baidu Hao123",             "china",        "browser",         "hao123"),
    T("com.so.browser",              "360 Browser",              "china",        "browser",         "360browser"),
    T("com.sogou.browser",           "Sogou Browser",            "china",        "browser",         "sogoubrowser"),
    T("com.liebao.desktop",          "Liebao Browser",           "china",        "browser",         "liebao"),
    T("com.qq.browser",              "QQ Browser",               "china",        "browser",         "qqbrowser"),
    T("com.uc.browser",              "UC Browser",               "china",        "browser",         "uc"),
    T("com.maxthon.desktop",         "Maxthon Browser",          "china",        "browser",         "maxthon"),
    T("com.youdao.dict",             "Youdao Dictionary",        "china",        "ai-translate",    "youdao"),
    T("com.fanyi.desktop",           "Baidu Fanyi",              "china",        "ai-translate",    "baidu-fanyi"),

    // ─── More RU niche ─────────────────────────────────────────────
    T("ru.mail.android-vpn",         "Mail.ru VPN",              "russia",       "vpn",             "mail-vpn"),
    T("ru.planetavpn.desktop",       "Planeta VPN",              "russia",       "vpn",             "planeta-vpn"),
    T("ru.rambler.mail",             "Rambler Mail",             "russia",       "mail",            "rambler"),
    T("ru.ukrnet.mail",              "ukr.net Mail",             "other",        "mail",            "ukrnet"),  // UA .other
    T("ru.sberauto.desktop",         "SberAuto",                 "russia",       "social-media",    "sberauto"),
    T("ru.sber.megamarket",          "SberMegaMarket",           "russia",       "social-media",    "sbermm"),
    T("ru.tinkoff.desktop",          "Tinkoff",                  "russia",       "finance",         "tinkoff"),
    T("ru.raiffeisen.desktop",       "Raiffeisen Russia",        "russia",       "finance",         "raiff-ru"),

    // ─── Enterprise US SaaS I may have missed ──────────────────────
    T("com.clari.desktop",           "Clari",                    "unitedStates", "analytics",       "clari"),
    T("com.gong.desktop",            "Gong",                     "unitedStates", "analytics",       "gong"),
    T("com.chorus.desktop",          "Chorus.ai (ZoomInfo)",     "unitedStates", "analytics",       "chorus"),
    T("com.outreach.desktop",        "Outreach.io",              "unitedStates", "crm",             "outreach"),
    T("com.salesloft.desktop",       "Salesloft",                "unitedStates", "crm",             "salesloft"),
    T("com.apollo.io",               "Apollo.io",                "unitedStates", "crm",             "apollo"),
    T("com.lusha.desktop",           "Lusha",                    "other",        "crm",             "lusha"),  // Israel
    T("com.zoominfo.desktop",        "ZoomInfo",                 "unitedStates", "crm",             "zoominfo"),
    T("com.6sense.desktop",          "6sense",                   "unitedStates", "analytics",       "6sense"),
    T("com.drift.desktop",           "Drift",                    "unitedStates", "crm",             "drift"),
    T("com.fullcontact.desktop",     "FullContact",              "unitedStates", "crm",             "fullcontact"),
    T("com.close.desktop",           "Close",                    "unitedStates", "crm",             "close"),
    T("com.streak.crm",              "Streak CRM",               "unitedStates", "crm",             "streak"),
    T("com.copper.crm",              "Copper CRM",               "unitedStates", "crm",             "copper"),
    T("com.nimble.crm",              "Nimble CRM",               "unitedStates", "crm",             "nimble"),
    T("com.insightly.crm",           "Insightly CRM",            "unitedStates", "crm",             "insightly"),
    T("com.agile.crm",               "Agile CRM",                "other",        "crm",             "agile"),  // India .other
    T("com.freshworks.sales",        "Freshsales",               "other",        "crm",             "freshsales"),

    // ─── More US dev tools ─────────────────────────────────────────
    T("com.warp.desktop",            "Warp Terminal (dup-chk)",  "unitedStates", "terminal",        "warp-dup"),
    T("com.fig.desktop",             "Fig (Amazon Q CLI)",       "unitedStates", "terminal",        "fig"),
    T("com.supermaven.app",          "Supermaven",               "unitedStates", "ai-chat",         "supermaven"),
    T("com.codium.app",              "Codium AI",                "other",        "ai-chat",         "codium"),  // Israel
    T("com.qodo.app",                "Qodo",                     "other",        "ai-chat",         "qodo"),  // Israel
    T("com.sourcegraph.desktop",     "Sourcegraph Cody",         "unitedStates", "ai-chat",         "cody"),
    T("com.aider.desktop",           "Aider",                    "oss",          "ai-chat",         "aider-t"),
    T("com.continuedev.desktop",     "Continue.dev",             "unitedStates", "ai-chat",         "continue"),

    // ─── More streaming niche ──────────────────────────────────────
    T("com.curiositystream.desktop", "Curiosity Stream",         "unitedStates", "video-streaming", "curiosity"),
    T("com.magellantv.desktop",      "MagellanTV",               "unitedStates", "video-streaming", "magellan"),
    T("com.acorntv.desktop",         "Acorn TV",                 "unitedStates", "video-streaming", "acorn"),
    T("com.britbox.desktop",         "BritBox",                  "europe",       "video-streaming", "britbox"),  // UK/BBC — skip
    T("com.kanopy.desktop",          "Kanopy",                   "unitedStates", "video-streaming", "kanopy"),
    T("com.hoopla.desktop",          "Hoopla Digital",           "unitedStates", "video-streaming", "hoopla"),
    T("com.freevee.amazon",          "Amazon Freevee",           "unitedStates", "video-streaming", "freevee"),
    T("com.roku.desktop",            "Roku",                     "unitedStates", "video-streaming", "roku"),

    // ─── More productivity niche ───────────────────────────────────
    T("com.bugherd.desktop",         "BugHerd",                  "other",        "crm",             "bugherd"),  // Australia
    T("com.trackabi.desktop",        "Trackabi",                 "russia",       "task",            "trackabi"),
    T("com.rescuetime.desktop",      "RescueTime",               "unitedStates", "habit-track",     "rescuetime"),
    T("com.toggl.Toggl",             "Toggl Track",              "europe",       "habit-track",     "toggl"),  // Estonia — skip
    T("com.clockify.desktop",        "Clockify",                 "other",        "habit-track",     "clockify"),  // Serbia .other
    T("com.harvest.desktop",         "Harvest",                  "unitedStates", "habit-track",     "harvest"),
    T("com.timely.desktop",          "Timely",                   "europe",       "habit-track",     "timely"),  // Norway — skip
    T("com.everhour.desktop",        "Everhour",                 "russia",       "habit-track",     "everhour"),
    T("com.timedoctor.desktop",      "Time Doctor",              "unitedStates", "habit-track",     "timedoctor"),

    // ─── Weather / aux utils ───────────────────────────────────────
    T("com.accuweather.desktop",     "AccuWeather",              "unitedStates", "map-nav",         "accuweather"),
    T("com.weather.com",             "The Weather Channel",      "unitedStates", "map-nav",         "weathercom"),
    T("com.darkskyapp.DarkSky",      "Dark Sky (Apple)",         "unitedStates", "map-nav",         "darksky"),
    T("com.foreca.desktop",          "Foreca",                   "europe",       "map-nav",         "foreca"),  // Finland — skip

    // ─── Shopping / price tracking ─────────────────────────────────
    T("com.honey.desktop",           "Honey (PayPal)",           "unitedStates", "system-util",     "honey"),
    T("com.rakuten.desktop",         "Rakuten",                  "other",        "social-media",    "rakuten-shop"),
    T("com.ibotta.desktop",          "Ibotta",                   "unitedStates", "finance",         "ibotta"),
    T("com.capitalone.shopping",     "Capital One Shopping",     "unitedStates", "system-util",     "cap1shop"),

    // ─── Misc Mac apps (indie / US) ────────────────────────────────
    T("com.fluidapp.FluidApp",       "Fluid (Site Specific)",    "unitedStates", "browser",         "fluid"),
    T("com.bundleid.Unite",          "Unite",                    "unitedStates", "browser",         "unite"),
    T("com.gitbutler.app",           "GitButler",                "europe",       "git-gui",         "gitbutler"),  // Switzerland — skip
    T("com.ish.app",                 "iSH Shell (dup chk)",      "oss",          "terminal",        "ish-dup"),
    T("com.blink.app",               "Blink Shell",              "unitedStates", "terminal",        "blink"),
    T("com.termius.desktop",         "Termius SSH",              "other",        "terminal",        "termius"),  // Ukraine .other
    T("com.shuttle.ssh",             "Shuttle (SSH)",            "unitedStates", "terminal",        "shuttle"),

    // ─── US IoT / smart home ───────────────────────────────────────
    T("com.ring.desktop",            "Ring (Amazon)",            "unitedStates", "system-util",     "ring"),
    T("com.nest.desktop",            "Nest (Google)",            "unitedStates", "system-util",     "nest"),
    T("com.ecobee.desktop",          "ecobee",                   "other",        "system-util",     "ecobee"),  // Canada
    T("com.arlo.desktop",            "Arlo",                     "unitedStates", "system-util",     "arlo"),
    T("com.wyze.desktop",            "Wyze",                     "unitedStates", "system-util",     "wyze"),
    T("com.ifttt.home",              "IFTTT Home (dup-chk)",     "unitedStates", "system-util",     "ifttt-home"),

    // ─── Children / learning ───────────────────────────────────────
    T("com.khanacademy.desktop",     "Khan Academy",             "unitedStates", "video-streaming", "khan"),
    T("com.coursera.desktop",        "Coursera",                 "unitedStates", "video-streaming", "coursera"),
    T("com.edx.desktop",             "edX",                      "unitedStates", "video-streaming", "edx"),
    T("com.udemy.desktop",           "Udemy",                    "unitedStates", "video-streaming", "udemy"),
    T("com.skillshare.desktop",      "Skillshare",               "unitedStates", "video-streaming", "skillshare"),
    T("com.brilliant.desktop",       "Brilliant",                "unitedStates", "video-streaming", "brilliant"),
    T("com.masterclass.desktop",     "MasterClass",              "unitedStates", "video-streaming", "masterclass"),
    T("com.pluralsight.desktop",     "Pluralsight",              "unitedStates", "video-streaming", "pluralsight"),
    T("com.codecademy.desktop",      "Codecademy",               "unitedStates", "ide",             "codecademy"),
    T("com.leetcode.desktop",        "LeetCode",                 "unitedStates", "ide",             "leetcode"),
    T("com.hackerrank.desktop",      "HackerRank",               "other",        "ide",             "hackerrank"),  // India

    // ─── Collab / whiteboard / diagram ─────────────────────────────
    T("com.atlassian.jiraalign",     "Jira Align",               "other",        "task",            "jiraalign"),
    T("com.shortcut.desktop",        "Shortcut (Clubhouse)",     "unitedStates", "task",            "shortcut"),
    T("com.productboard.desktop",    "Productboard",             "other",        "task",            "productboard"),  // Czech Republic — skip
    T("com.aha.desktop",             "Aha!",                     "unitedStates", "task",            "aha"),
    T("com.productplan.desktop",     "ProductPlan",              "unitedStates", "task",            "productplan"),

    // ─── Email marketing / outreach extras ─────────────────────────
    T("com.sendinblue.desktop",      "Brevo (Sendinblue)",       "europe",       "email-marketing", "brevo"),  // FR — skip
    T("com.emarsys.desktop",         "Emarsys (SAP)",            "europe",       "email-marketing", "emarsys"),  // DE — skip
    T("com.iterable.desktop",        "Iterable",                 "unitedStates", "email-marketing", "iterable"),
    T("com.customer.io",             "Customer.io",              "unitedStates", "email-marketing", "customerio"),
    T("com.braze.desktop",           "Braze",                    "unitedStates", "email-marketing", "braze"),
    T("com.getresponse.desktop",     "GetResponse",              "europe",       "email-marketing", "getresponse"),  // PL — skip

    // ─── More niche CN / RU ────────────────────────────────────────
    T("com.meizu.desktop",           "Meizu Connect",            "china",        "system-util",     "meizu"),
    T("com.oppo.desktop",            "OPPO Connect",             "china",        "system-util",     "oppo"),
    T("com.vivo.desktop",            "Vivo Connect",             "china",        "system-util",     "vivo"),
    T("com.honor.desktop",           "Honor Connect",            "china",        "system-util",     "honor"),
    T("com.lenovo.vantage",          "Lenovo Vantage",           "china",        "system-util",     "lenovo"),
    T("com.lenovo.smart-center",     "Lenovo Smart Center",      "china",        "system-util",     "lenovo-sc"),
    T("com.acer.desktop",            "Acer Care Center",         "other",        "system-util",     "acer"),  // Taiwan .other
    T("com.asus.desktop",            "ASUS Smart Gesture",       "other",        "system-util",     "asus"),
    T("ru.kinopoisk.desktop",        "Kinopoisk (dup chk)",      "russia",       "video-streaming", "kinopoisk-dup"),

    // ─── Crypto / Web3 ──────────────────────────────────────────────
    T("com.trustwallet.desktop",     "Trust Wallet (Binance)",   "china",        "finance",         "trust"),  // Binance/BN
    T("com.binance.desktop",         "Binance",                  "china",        "finance",         "binance"),
    T("com.bybit.desktop",           "Bybit",                    "china",        "finance",         "bybit"),
    T("com.gateio.desktop",          "Gate.io",                  "china",        "finance",         "gateio"),
    T("com.huobi.desktop",           "Huobi",                    "china",        "finance",         "huobi"),
    T("com.okx.desktop",             "OKX",                      "china",        "finance",         "okx"),
    T("com.crypto.com",              "Crypto.com",               "other",        "finance",         "cryptocom"),  // Singapore
    T("com.kraken.desktop",          "Kraken Exchange",          "unitedStates", "finance",         "kraken-ex"),
    T("com.gemini.desktop",          "Gemini Exchange",          "unitedStates", "finance",         "gemini-ex"),
    T("io.uniswap.desktop",          "Uniswap",                  "unitedStates", "finance",         "uniswap"),

    // ─── US VPN niche ──────────────────────────────────────────────
    T("com.ipvanish.desktop",        "IPVanish",                 "unitedStates", "vpn",             "ipvanish"),
    T("com.hotspotshield.desktop",   "Hotspot Shield",           "unitedStates", "vpn",             "hotspotshield"),
    T("com.privateinternetaccess.desktop","PIA VPN",             "unitedStates", "vpn",             "pia"),
    T("com.windscribe.desktop",      "Windscribe",               "other",        "vpn",             "windscribe"),  // Canada
    T("com.surfshark.desktop",       "Surfshark",                "europe",       "vpn",             "surfshark"),  // NL/Lithuania — skip
    T("com.cyberghost.desktop",      "CyberGhost",               "europe",       "vpn",             "cyberghost"),  // Romania — skip
    T("com.atlas.desktop",           "Atlas VPN",                "europe",       "vpn",             "atlas"),  // Lithuania — skip
    T("com.tunnelbear.desktop",      "TunnelBear (McAfee)",      "other",        "vpn",             "tunnelbear"),  // Canada but US-owned
    T("com.purevpn.desktop",         "PureVPN",                  "other",        "vpn",             "purevpn"),  // Hong Kong

    // ─── Misc SaaS ─────────────────────────────────────────────────
    T("com.smartsheet.desktop",      "Smartsheet (dup-chk)",     "unitedStates", "task",            "smart-dup"),
    T("com.quip.desktop",            "Quip (Salesforce)",        "unitedStates", "office",          "quip"),
    T("com.dropbox.paper",           "Dropbox Paper",            "unitedStates", "office",          "dbpaper"),
    T("com.box.notes",               "Box Notes",                "unitedStates", "office",          "boxnotes"),
    T("com.confluence.desktop",      "Confluence (dup-chk)",     "other",        "knowledge-base",  "conf-dup"),
    T("com.notability.desktop",      "Notability",               "unitedStates", "pdf",             "notability"),
    T("com.goodnotes.desktop",       "GoodNotes",                "europe",       "pdf",             "goodnotes"),  // Hong Kong now — not really EU; .other
    T("com.noteshelf.desktop",       "Noteshelf",                "other",        "pdf",             "noteshelf"),  // India
    T("com.nebo.desktop",            "Nebo",                     "europe",       "pdf",             "nebo"),  // France (MyScript) — skip

    // ─── Enterprise backup / disaster ──────────────────────────────
    T("com.veeam.desktop",           "Veeam",                    "europe",       "backup",          "veeam"),  // CH — skip
    T("com.commvault.desktop",       "Commvault",                "unitedStates", "backup",          "commvault"),
    T("com.rubrik.desktop",          "Rubrik",                   "unitedStates", "backup",          "rubrik"),
    T("com.cohesity.desktop",        "Cohesity",                 "unitedStates", "backup",          "cohesity"),

    // ─── Data warehouse / BI ───────────────────────────────────────
    T("com.snowflake.desktop",       "Snowflake",                "unitedStates", "database",        "snowflake"),
    T("com.databricks.desktop",      "Databricks",               "unitedStates", "database",        "databricks"),
    T("com.clickhouse.desktop",      "ClickHouse",               "oss",          "database",        "clickhouse-t"),  // OSS — skip
    T("com.starrocks.desktop",       "StarRocks",                "unitedStates", "database",        "starrocks"),
    T("com.redshift.desktop",        "Amazon Redshift",          "unitedStates", "database",        "redshift-db"),
    T("com.tableau.desktop",         "Tableau",                  "unitedStates", "analytics",       "tableau"),
    T("com.qlik.sense",              "Qlik Sense",               "europe",       "analytics",       "qlik"),  // Sweden — skip
    T("com.sisense.desktop",         "Sisense",                  "unitedStates", "analytics",       "sisense"),
    T("com.domo.desktop",            "Domo",                     "unitedStates", "analytics",       "domo"),
    T("com.looker.desktop",          "Looker (Google)",          "unitedStates", "analytics",       "looker"),
    T("com.mode.desktop",            "Mode Analytics",           "unitedStates", "analytics",       "mode"),

    // ─── More game / consumer ──────────────────────────────────────
    T("com.roblox.desktop",          "Roblox",                   "unitedStates", "system-util",     "roblox"),
    T("com.minecraft.desktop",       "Minecraft: Java Edition",  "unitedStates", "system-util",     "minecraft"),
    T("com.mojang.bedrock",          "Minecraft Bedrock",        "unitedStates", "system-util",     "mcbedrock"),
    T("com.nintendo.desktop",        "Nintendo eShop",           "other",        "system-util",     "nintendo"),

    // ─── Legal / admin / records ───────────────────────────────────
    T("com.clio.desktop",            "Clio",                     "other",        "crm",             "clio"),  // Canada
    T("com.lawmatics.desktop",       "Lawmatics",                "unitedStates", "crm",             "lawmatics"),
    T("com.mycase.desktop",          "MyCase",                   "unitedStates", "crm",             "mycase"),

    // ─── More US health / wellness ─────────────────────────────────
    T("com.one-medical.desktop",     "One Medical",              "unitedStates", "video-call",      "onemed"),
    T("com.teladoc.desktop",         "Teladoc",                  "unitedStates", "video-call",      "teladoc"),
    T("com.healthie.desktop",        "Healthie",                 "unitedStates", "crm",             "healthie"),

    // ─── Social audio ──────────────────────────────────────────────
    T("com.clubhouse.desktop",       "Clubhouse",                "unitedStates", "social-media",    "clubhouse"),
    T("com.spacesapp.desktop",       "Spaces",                   "unitedStates", "social-media",    "spaces"),

    // ─── More design / agency ──────────────────────────────────────
    T("com.abstract.desktop",        "Abstract",                 "unitedStates", "vector",          "abstract"),
    T("com.zeplin.desktop",          "Zeplin",                   "other",        "vector",          "zeplin"),  // Turkey .other
    T("com.principleformac.desktop", "Principle",                "unitedStates", "vector",          "principle"),
    T("com.protopie.desktop",        "ProtoPie",                 "other",        "vector",          "protopie"),  // Korea

    // ─── Misc / long tail ──────────────────────────────────────────
    T("com.toast.desktop",           "Toast POS",                "unitedStates", "crm",             "toast"),
    T("com.square.desktop",          "Square POS",               "unitedStates", "crm",             "square-pos"),
    T("com.clover.desktop",          "Clover POS",               "unitedStates", "crm",             "clover"),
    T("com.lightspeed.desktop",      "Lightspeed POS",           "other",        "crm",             "lightspeed"),  // Canada
    T("com.revel.desktop",           "Revel POS",                "unitedStates", "crm",             "revel"),

    // ─── US auction / classifieds ──────────────────────────────────
    T("com.ebay.desktop-pro",        "eBay Seller Hub",          "unitedStates", "social-media",    "ebay-seller"),
    T("com.offerup.desktop",         "OfferUp",                  "unitedStates", "social-media",    "offerup"),
    T("com.mercari.desktop",         "Mercari",                  "other",        "social-media",    "mercari"),  // JP/US

    // ─── 3D scanning / AR ──────────────────────────────────────────
    T("com.polycam.desktop",         "Polycam",                  "unitedStates", "cad-3d",          "polycam"),
    T("com.scaniverse.desktop",      "Scaniverse (Niantic)",     "unitedStates", "cad-3d",          "scaniverse"),

    // ===========================================================
    // BATCH 4 — push from 869 to 1070+ (a true 10× from the v1.3
    // baseline of 107).  Deeper long-tail coverage of regional
    // apps, niche US SaaS, and Chinese gaming/entertainment.
    // ===========================================================

    // ─── Chinese gaming / entertainment ────────────────────────────
    T("com.mihoyo.genshin",          "Genshin Impact",           "china",        "system-util",     "genshin"),
    T("com.mihoyo.starrail",         "Honkai: Star Rail",        "china",        "system-util",     "starrail"),
    T("com.mihoyo.zzz",              "Zenless Zone Zero",        "china",        "system-util",     "zzz"),
    T("com.mihoyo.hsr",              "Honkai Impact 3rd",        "china",        "system-util",     "honkai3"),
    T("com.tencent.pubgmobile",      "PUBG Mobile",              "china",        "system-util",     "pubgm"),
    T("com.tencent.wefire",          "Call of Duty Mobile (CN)", "china",        "system-util",     "codmcn"),
    T("com.tencent.mir",             "Legend of Mir",            "china",        "system-util",     "mir"),
    T("com.netease.mrfz",            "Arknights",                "china",        "system-util",     "arknights"),
    T("com.netease.onmyoji",         "Onmyoji",                  "china",        "system-util",     "onmyoji"),
    T("com.netease.identity-v",      "Identity V",               "china",        "system-util",     "identityv"),
    T("com.netease.mc",              "Minecraft China Edition",  "china",        "system-util",     "mc-cn"),
    T("com.perfectworld.desktop",    "Perfect World",            "china",        "system-util",     "perfectworld"),
    T("com.shanda.desktop",          "Shanda Games",             "china",        "system-util",     "shanda"),
    T("com.kingsoftgame.jx3",        "JX3 Online",               "china",        "system-util",     "jx3"),
    T("com.hotpotlab.desktop",       "HotPot Studio",            "china",        "system-util",     "hotpot"),

    // ─── Chinese tools deeper ──────────────────────────────────────
    T("com.iflytek.voiceapi",        "iFlytek Voice",            "china",        "dictation",       "iflytek"),
    T("com.iflytek.dict",            "iFlytek Input",            "china",        "system-util",     "iflytek-input"),
    T("com.bytedance.doubao",        "Doubao (ByteDance AI)",    "china",        "ai-chat",         "doubao"),
    T("com.baidu.erniebot",          "ERNIE Bot (Baidu)",        "china",        "ai-chat",         "ernie"),
    T("com.tencent.hunyuan",         "Tencent Hunyuan",          "china",        "ai-chat",         "hunyuan"),
    T("com.alibaba.tongyi",          "Tongyi Qianwen (Qwen)",    "china",        "ai-chat",         "qwen-app"),
    T("com.moonshot.kimi",           "Kimi Chat (Moonshot)",     "china",        "ai-chat",         "kimi"),
    T("com.zhipu.glm",               "ChatGLM",                  "china",        "ai-chat",         "glm"),
    T("com.minimax.abab",            "MiniMax ABAB",             "china",        "ai-chat",         "minimax"),
    T("com.01ai.yi",                 "01.AI Yi Chat",            "china",        "ai-chat",         "yi"),
    T("com.deepseek.chat",           "DeepSeek Chat",            "china",        "ai-chat",         "deepseek"),
    T("com.tencent.miniqq",          "MiniQQ",                   "china",        "chat-personal",   "miniqq"),
    T("com.bytedance.jianying",      "JianYing (CapCut CN)",     "china",        "video-edit",      "jianying"),
    T("com.tencent.smovie",          "Tencent S-Movie",          "china",        "video-edit",      "smovie"),
    T("com.bytedance.feishutoolkit", "Feishu Minutes",           "china",        "dictation",       "feishu-min"),
    T("com.bytedance.lark-mail",     "Lark Mail",                "china",        "mail",            "lark-mail"),
    T("com.kingsoft.cleaner",        "KSafe (Kingsoft Cleaner)", "china",        "system-util",     "ksafe"),

    // ─── Russian deeper ────────────────────────────────────────────
    T("ru.vtb.mobile",               "VTB Online",               "russia",       "finance",         "vtb"),
    T("ru.gazprombank.desktop",      "Gazprombank",              "russia",       "finance",         "gazpromb"),
    T("ru.alfa.desktop",             "Alfa-Bank (RU)",           "russia",       "finance",         "alfaru"),
    T("ru.rosbank.desktop",          "Rosbank",                  "russia",       "finance",         "rosbank"),
    T("ru.otkritie.desktop",         "Otkritie Bank",            "russia",       "finance",         "otkritie"),
    T("ru.avito.desktop",            "Avito",                    "russia",       "social-media",    "avito"),
    T("ru.drom.desktop",             "Drom.ru",                  "russia",       "social-media",    "drom"),
    T("ru.auto.desktop",             "Auto.ru (Yandex)",         "russia",       "social-media",    "autoru"),
    T("ru.cian.desktop",             "CIAN Real Estate",         "russia",       "social-media",    "cian"),
    T("ru.hh.desktop",               "HeadHunter (hh.ru)",       "russia",       "crm",             "hhru"),
    T("ru.superjob.desktop",         "SuperJob",                 "russia",       "crm",             "superjob"),
    T("ru.sberzvuk.desktop",         "Zvuk (SberZvuk)",          "russia",       "music-streaming", "sberzvuk"),
    T("ru.bookmate.desktop",         "Bookmate (Yandex)",        "russia",       "reader",          "bookmate"),
    T("ru.litres.desktop",           "LitRes",                   "russia",       "reader",          "litres"),
    T("ru.ivi.ru",                   "ivi.ru",                   "russia",       "video-streaming", "ivi"),
    T("ru.okko.tv",                  "Okko",                     "russia",       "video-streaming", "okko"),
    T("ru.more.tv",                  "more.tv",                  "russia",       "video-streaming", "moretv"),
    T("ru.start.ru",                 "Start.ru",                 "russia",       "video-streaming", "startru"),
    T("ru.premier.one",              "Premier",                  "russia",       "video-streaming", "premier-ru"),
    T("ru.wink.tv",                  "Wink (Rostelecom)",        "russia",       "video-streaming", "wink"),
    T("ru.tass.mobile",              "TASS News",                "russia",       "feed-reader",     "tass"),
    T("ru.lenta.ru",                 "Lenta.ru",                 "russia",       "feed-reader",     "lenta"),
    T("ru.rbc.ru",                   "RBC News",                 "russia",       "feed-reader",     "rbc"),
    T("ru.vedomosti.desktop",        "Vedomosti",                "russia",       "feed-reader",     "vedomosti"),
    T("ru.kommersant.desktop",       "Kommersant",               "russia",       "feed-reader",     "kommersant"),

    // ─── More Japanese ─────────────────────────────────────────────
    T("jp.co.square-enix.client",    "Square Enix Client",       "other",        "system-util",     "se-client"),
    T("jp.co.square-enix.ff14",      "FFXIV Online",             "other",        "system-util",     "ffxiv"),
    T("jp.co.capcom.desktop",        "Capcom Desktop",           "other",        "system-util",     "capcom"),
    T("jp.co.bandaimamco.desktop",   "Bandai Namco Entertainment","other",       "system-util",     "bandai"),
    T("jp.co.konami.pes",            "Konami eFootball",         "other",        "system-util",     "efootball"),
    T("jp.co.sega.desktop",          "Sega PC Launcher",         "other",        "system-util",     "sega"),
    T("jp.co.atlus.desktop",         "Atlus PC",                 "other",        "system-util",     "atlus"),
    T("jp.co.softbank.hkbiz",        "SoftBank Biz",             "other",        "crm",             "softbank"),
    T("jp.co.ntt.ocn-mail",          "OCN Mail (NTT)",           "other",        "mail",            "ocn"),
    T("jp.co.rakuten.kobo",          "Rakuten Kobo",             "other",        "reader",          "kobo"),
    T("jp.co.rakuten.ichiba",        "Rakuten Ichiba",           "other",        "social-media",    "ichiba"),
    T("jp.co.rakuten.pay",           "Rakuten Pay",              "other",        "finance",         "rakuten-pay"),
    T("jp.co.rakuten.card",          "Rakuten Card",             "other",        "finance",         "rakuten-card"),
    T("jp.co.mf.moneyforward",       "Money Forward ME",         "other",        "finance",         "mf"),
    T("jp.co.smbc.desktop",          "SMBC Online",              "other",        "finance",         "smbc"),
    T("jp.co.mufg.desktop",          "MUFG Bank",                "other",        "finance",         "mufg"),
    T("jp.co.mizuho.desktop",        "Mizuho Direct",            "other",        "finance",         "mizuho"),
    T("jp.co.paypay.desktop",        "PayPay",                   "other",        "finance",         "paypay"),
    T("jp.co.merpay.desktop",        "MerPay",                   "other",        "finance",         "merpay"),
    T("jp.co.dcard.desktop",         "d CARD (NTT Docomo)",      "other",        "finance",         "dcard"),
    T("jp.co.suica.desktop",         "Mobile Suica",             "other",        "finance",         "suica"),
    T("jp.co.pixiv.desktop",         "Pixiv",                    "other",        "social-media",    "pixiv"),
    T("jp.co.youtubefan.nicolog",    "NicoLog",                  "other",        "social-media",    "nicolog"),
    T("jp.co.nikkei.desktop",        "Nikkei",                   "other",        "feed-reader",     "nikkei"),
    T("jp.co.asahi.desktop",         "Asahi Shimbun",            "other",        "feed-reader",     "asahi"),
    T("jp.co.mainichi.desktop",      "Mainichi Shimbun",         "other",        "feed-reader",     "mainichi"),
    T("jp.co.yomiuri.desktop",       "Yomiuri Shimbun",          "other",        "feed-reader",     "yomiuri"),

    // ─── More Korean ───────────────────────────────────────────────
    T("kr.co.nexon.desktop",         "Nexon Launcher",           "other",        "system-util",     "nexon"),
    T("kr.co.pearlabyss.desktop",    "Pearl Abyss (BDO)",        "other",        "system-util",     "pearlabyss"),
    T("kr.co.ncsoft.desktop",        "NCSoft Purple",            "other",        "system-util",     "ncsoft"),
    T("kr.co.krafton.desktop",       "Krafton",                  "other",        "system-util",     "krafton"),
    T("kr.co.kakaogames.desktop",    "Kakao Games",              "other",        "system-util",     "kakaogames"),
    T("kr.co.smilegate.desktop",     "Smilegate Stove",          "other",        "system-util",     "smilegate"),
    T("kr.co.gravity.ragnarok",      "Ragnarok (Gravity)",       "other",        "system-util",     "ragnarok"),
    T("kr.co.coupangplay.desktop",   "Coupang Play",             "other",        "video-streaming", "coupangplay"),
    T("kr.co.wavve.desktop",         "Wavve",                    "other",        "video-streaming", "wavve"),
    T("kr.co.tving.desktop",         "Tving",                    "other",        "video-streaming", "tving"),
    T("kr.co.watcha.desktop",        "Watcha",                   "other",        "video-streaming", "watcha"),
    T("kr.co.afreecatv.desktop",     "AfreecaTV",                "other",        "video-streaming", "afreeca"),
    T("kr.co.melon.desktop",         "Melon",                    "other",        "music-streaming", "melon"),
    T("kr.co.genie.desktop",         "Genie Music",              "other",        "music-streaming", "genie"),
    T("kr.co.bugs.desktop",          "Bugs!",                    "other",        "music-streaming", "bugs"),
    T("kr.co.flo.desktop",           "FLO",                      "other",        "music-streaming", "flo"),
    T("kr.co.kbstar.desktop",        "KB Kookmin Bank",          "other",        "finance",         "kbstar"),
    T("kr.co.shinhan.desktop",       "Shinhan Bank",             "other",        "finance",         "shinhan"),
    T("kr.co.wooribank.desktop",     "Woori Bank",               "other",        "finance",         "woori"),
    T("kr.co.toss.desktop",          "Toss (Viva Republica)",    "other",        "finance",         "toss"),
    T("kr.co.11st.desktop",          "11st (SK)",                "other",        "social-media",    "11st"),
    T("kr.co.gmarket.desktop",       "Gmarket (eBay Korea)",     "other",        "social-media",    "gmarket"),

    // ─── Southeast Asia ────────────────────────────────────────────
    T("sg.grab.desktop",             "Grab",                     "other",        "social-media",    "grab"),
    T("id.gojek.desktop",            "Gojek",                    "other",        "social-media",    "gojek"),
    T("sg.shopee.desktop",           "Shopee",                   "other",        "social-media",    "shopee"),
    T("sg.lazada.desktop",           "Lazada (Alibaba)",         "china",        "social-media",    "lazada"),
    T("id.tokopedia.desktop",        "Tokopedia (GoTo)",         "other",        "social-media",    "tokopedia"),
    T("id.dana.desktop",             "DANA",                     "other",        "finance",         "dana"),
    T("id.ovo.desktop",              "OVO",                      "other",        "finance",         "ovo"),
    T("ph.gcash.desktop",            "GCash",                    "other",        "finance",         "gcash"),
    T("ph.maya.desktop",             "Maya (PayMaya)",           "other",        "finance",         "maya"),
    T("vn.vng.zalo",                 "Zalo",                     "other",        "chat-personal",   "zalo"),
    T("vn.vng.momo",                 "MoMo",                     "other",        "finance",         "momo"),
    T("vn.fpt.desktop",              "FPT Play",                 "other",        "video-streaming", "fpt"),
    T("th.ais.desktop",              "AIS Play",                 "other",        "video-streaming", "aisplay"),
    T("my.touchngo.desktop",         "Touch 'n Go",              "other",        "finance",         "tng"),
    T("my.mytekkaus.astro",          "Astro GO",                 "other",        "video-streaming", "astro"),
    T("sg.singtel.cast",             "Singtel CAST",             "other",        "video-streaming", "singtel"),

    // ─── LATAM deeper ──────────────────────────────────────────────
    T("mx.banorte.desktop",          "Banorte",                  "other",        "finance",         "banorte"),
    T("mx.bbva.bancomer",            "BBVA México",              "europe",       "finance",         "bbva-mx"),  // Spain — skip
    T("mx.santander.desktop",        "Santander México",         "europe",       "finance",         "santander-mx"),
    T("mx.mercadopago.desktop",      "Mercado Pago",             "other",        "finance",         "mercadopago"),
    T("mx.didi.desktop",             "DiDi Mexico",              "china",        "social-media",    "didi-mx"),
    T("mx.cornershop.desktop",       "Cornershop (Uber)",        "unitedStates", "social-media",    "cornershop"),
    T("mx.clip.desktop",             "Clip POS",                 "other",        "crm",             "clip"),
    T("ar.mercadolibre.desktop",     "Mercado Libre AR",         "other",        "social-media",    "mlar"),
    T("ar.despegar.desktop",         "Despegar",                 "other",        "social-media",    "despegar"),
    T("co.rappi.desktop-pro",        "Rappi Colombia",           "other",        "social-media",    "rappi-co"),
    T("cl.banco.desktop",            "Banco de Chile",           "other",        "finance",         "banchile"),
    T("cl.falabella.desktop",        "Falabella",                "other",        "social-media",    "falabella"),
    T("cl.cencosud.desktop",         "Cencosud",                 "other",        "social-media",    "cencosud"),
    T("pe.bcp.desktop",              "BCP Perú",                 "other",        "finance",         "bcp"),

    // ─── US SaaS deeper niche ──────────────────────────────────────
    T("com.qualtrics.desktop",       "Qualtrics XM",             "unitedStates", "survey-form",     "qualtrics"),
    T("com.surveymonkey.desktop",    "SurveyMonkey",             "unitedStates", "survey-form",     "surveymonkey"),
    T("com.typeform.desktop",        "Typeform",                 "europe",       "survey-form",     "typeform"),  // Spain — skip
    T("com.jotform.desktop",         "Jotform",                  "unitedStates", "survey-form",     "jotform"),
    T("com.gainsight.desktop",       "Gainsight",                "unitedStates", "crm",             "gainsight"),
    T("com.marketo.desktop",         "Marketo (Adobe)",          "unitedStates", "email-marketing", "marketo"),
    T("com.pardot.desktop",          "Pardot (Salesforce)",      "unitedStates", "email-marketing", "pardot"),
    T("com.constantcontact.desktop", "Constant Contact",         "unitedStates", "email-marketing", "ccontact"),
    T("com.activecampaign.desktop",  "ActiveCampaign",           "unitedStates", "email-marketing", "activecampaign"),
    T("com.drip.desktop",            "Drip",                     "unitedStates", "email-marketing", "drip"),
    T("com.chargebee.desktop",       "Chargebee",                "other",        "finance",         "chargebee"),  // India
    T("com.recurly.desktop",         "Recurly",                  "unitedStates", "finance",         "recurly"),
    T("com.chargify.desktop",        "Chargify / Maxio",         "unitedStates", "finance",         "chargify"),
    T("com.procore.desktop",         "Procore",                  "unitedStates", "task",            "procore"),
    T("com.bluebeam.revu",           "Bluebeam Revu",            "unitedStates", "pdf",             "bluebeam"),
    T("com.asana.gantt",             "Asana Timeline",           "unitedStates", "task",            "asana-timeline"),
    T("com.amplitude.experimentation","Amplitude Experiment",    "unitedStates", "analytics",       "amplitude-exp"),
    T("com.statsig.desktop",         "Statsig",                  "unitedStates", "analytics",       "statsig"),
    T("com.growthbook.desktop",      "GrowthBook",               "unitedStates", "analytics",       "growthbook"),
    T("com.eppo.desktop",            "Eppo",                     "unitedStates", "analytics",       "eppo"),
    T("com.split.io",                "Split.io",                 "unitedStates", "analytics",       "split"),
    T("com.flagsmith.desktop",       "Flagsmith",                "europe",       "analytics",       "flagsmith"),  // UK — skip
    T("com.unleash.desktop",         "Unleash",                  "europe",       "analytics",       "unleash"),  // NO/Finland-adj

    // ─── US educational / edtech ───────────────────────────────────
    T("com.chegg.desktop",           "Chegg",                    "unitedStates", "video-streaming", "chegg"),
    T("com.nearpod.desktop",         "Nearpod",                  "unitedStates", "video-streaming", "nearpod"),
    T("com.quizlet.desktop",         "Quizlet",                  "unitedStates", "video-streaming", "quizlet"),
    T("com.2u.desktop",              "2U",                       "unitedStates", "video-streaming", "2u"),
    T("com.wyzant.desktop",          "Wyzant",                   "unitedStates", "crm",             "wyzant"),
    T("com.varsitytutors.desktop",   "Varsity Tutors",           "unitedStates", "crm",             "varsity"),
    T("com.outschool.desktop",       "Outschool",                "unitedStates", "video-streaming", "outschool"),
    T("com.brightwheel.desktop",     "Brightwheel",              "unitedStates", "crm",             "brightwheel"),
    T("com.kahoot.desktop",          "Kahoot!",                  "europe",       "survey-form",     "kahoot"),  // Norway — skip
    T("com.prodigygame.desktop",     "Prodigy Math",             "other",        "system-util",     "prodigy"),  // Canada

    // ─── AI / ML infrastructure (US) ───────────────────────────────
    T("com.replicate.desktop",       "Replicate",                "unitedStates", "ai-chat",         "replicate"),
    T("com.huggingface.desktop",     "Hugging Face",             "unitedStates", "ai-chat",         "huggingface"),  // Delaware-inc; French founders but US LLC
    T("com.langchain.desktop",       "LangChain",                "unitedStates", "ai-chat",         "langchain"),
    T("com.llamaindex.desktop",      "LlamaIndex",               "unitedStates", "ai-chat",         "llamaindex"),
    T("com.pinecone.desktop",        "Pinecone (Vector DB)",     "unitedStates", "database",        "pinecone"),
    T("com.chroma.desktop",          "Chroma",                   "unitedStates", "database",        "chroma"),
    T("com.qdrant.desktop",          "Qdrant",                   "europe",       "database",        "qdrant"),  // Germany — skip
    T("com.milvus.desktop",          "Milvus (Zilliz)",          "unitedStates", "database",        "milvus"),
    T("com.openai.platform",         "OpenAI Platform",          "unitedStates", "ai-chat",         "openai-platform"),
    T("com.anthropic.workbench",     "Anthropic Workbench",      "unitedStates", "ai-chat",         "anthropic-wb"),
    T("com.together.ai",             "Together.ai",              "unitedStates", "ai-chat",         "together-ai"),
    T("com.fireworks.ai",            "Fireworks.ai",             "unitedStates", "ai-chat",         "fireworks"),
    T("com.groq.desktop",            "Groq Cloud",               "unitedStates", "ai-chat",         "groq"),
    T("com.cerebras.desktop",        "Cerebras",                 "unitedStates", "ai-chat",         "cerebras"),
    T("com.modal.desktop",           "Modal",                    "unitedStates", "cloud-cli",       "modal"),
    T("com.runpod.desktop",          "RunPod",                   "unitedStates", "cloud-cli",       "runpod"),
    T("com.lambda.labs",             "Lambda Labs",              "unitedStates", "cloud-cli",       "lambda-labs"),

    // ─── DevOps / infra deep ───────────────────────────────────────
    T("com.redhat.ansible",          "Ansible",                  "unitedStates", "cloud-cli-control","ansible"),
    T("com.chef.desktop",            "Chef",                     "unitedStates", "cloud-cli-control","chef"),
    T("com.saltstack.desktop",       "SaltStack",                "unitedStates", "cloud-cli-control","salt"),
    T("com.serverlesscom.desktop",   "Serverless Framework",     "unitedStates", "cloud-cli-control","serverless"),
    T("com.architect.desktop",       "Architect.io",             "unitedStates", "cloud-cli-control","architect"),
    T("com.crossplane.desktop",      "Crossplane",               "unitedStates", "cloud-cli-control","crossplane"),
    T("com.argoproj.desktop",        "Argo CD",                  "unitedStates", "cloud-cli-control","argocd"),
    T("com.fluxcd.desktop",          "Flux CD",                  "unitedStates", "cloud-cli-control","fluxcd"),
    T("com.helm.desktop",            "Helm",                     "unitedStates", "cloud-cli-control","helm"),
    T("com.kubectl.desktop",         "kubectl (Kubernetes CLI)", "unitedStates", "cloud-cli",       "kubectl"),
    T("com.k9s.desktop",             "k9s",                      "oss",          "cloud-cli",       "k9s-t"),  // OSS skip

    // ─── US niche Mac indie ────────────────────────────────────────
    T("com.foreflight.mobile-desktop","ForeFlight",              "unitedStates", "map-nav",         "foreflight"),
    T("com.perplexity.desktop",      "Perplexity (dup-chk)",     "unitedStates", "ai-chat",         "perp-dup"),
    T("com.drafts.desktop",          "Drafts",                   "unitedStates", "notes-pro",       "drafts"),
    T("com.omm.OmmWriter",           "OmmWriter",                "europe",       "notes-pro",       "ommwriter"),  // Spain — skip
    T("com.byword.desktop",          "Byword",                   "europe",       "notes-pro",       "byword"),  // Portugal — skip
    T("com.macdown.desktop",         "MacDown",                  "oss",          "notes-pro",       "macdown-t"),

    // ─── US audiobook / podcast ────────────────────────────────────
    T("com.audible.desktop",         "Audible (Amazon)",         "unitedStates", "audio-player",    "audible"),
    T("com.libro.fm",                "Libro.fm",                 "unitedStates", "audio-player",    "librofm"),
    T("com.scribd.desktop",          "Scribd",                   "unitedStates", "reader",          "scribd"),
    T("com.siriusxm.desktop",        "SiriusXM",                 "unitedStates", "audio-player",    "siriusxm"),
    T("com.npr.one",                 "NPR One",                  "unitedStates", "audio-player",    "npr"),
    T("com.stitcher.desktop",        "Stitcher",                 "unitedStates", "audio-player",    "stitcher"),
    T("com.castbox.desktop",         "Castbox",                  "china",        "audio-player",    "castbox"),
    T("com.anchor.desktop",          "Anchor (Spotify)",         "europe",       "audio-edit",      "anchor"),  // Spotify SE — skip
    T("com.podbean.desktop",         "Podbean",                  "unitedStates", "audio-edit",      "podbean"),
    T("com.buzzsprout.desktop",      "Buzzsprout",               "unitedStates", "audio-edit",      "buzzsprout"),
    T("com.transistor.fm",           "Transistor.fm",            "other",        "audio-edit",      "transistor"),  // Canada
    T("com.riverside.fm",            "Riverside.fm (dup-chk)",   "other",        "audio-edit",      "riverside-dup"),

    // ─── Google/Apple ecosystem US ─────────────────────────────────
    T("com.youtube.creator",         "YouTube Creator Studio",   "unitedStates", "video-edit",      "ytcreator"),
    T("com.google.classroom",        "Google Classroom",         "unitedStates", "video-streaming", "gclassroom"),
    T("com.google.admin",            "Google Admin",             "unitedStates", "mdm-agent",       "gadmin"),
    T("com.google.messages",         "Google Messages",          "unitedStates", "chat-personal",   "gmessages"),
    T("com.google.maps",             "Google Maps",              "unitedStates", "map-nav",         "gmaps"),
    T("com.google.phone",            "Google Phone",             "unitedStates", "chat-personal",   "gphone"),
    T("com.apple.Keynote",           "Apple Keynote",            "unitedStates", "office",          "keynote"),
    T("com.apple.Pages",             "Apple Pages",              "unitedStates", "office",          "pages"),
    T("com.apple.Numbers",           "Apple Numbers",            "unitedStates", "office",          "numbers"),
    T("com.apple.Shortcuts",         "Apple Shortcuts",          "unitedStates", "system-util",     "shortcuts"),

    // ─── US niche productivity/utility ─────────────────────────────
    T("com.getabstract.desktop",     "getAbstract",              "europe",       "reader",          "getabstract"),  // CH — skip
    T("com.blinkist.desktop",        "Blinkist",                 "europe",       "reader",          "blinkist"),  // Germany — skip
    T("com.readwise.desktop",        "Readwise",                 "unitedStates", "reader",          "readwise"),
    T("com.instapaper.desktop",      "Instapaper",               "unitedStates", "feed-reader",     "instapaper"),
    T("com.matter.desktop",          "Matter",                   "unitedStates", "feed-reader",     "matter"),
    T("com.reader.readwise",         "Readwise Reader",          "unitedStates", "feed-reader",     "readwise-reader"),
    T("com.artifact.news",           "Artifact (Instagram)",     "unitedStates", "feed-reader",     "artifact"),

    // ─── US/Chinese ride-share + delivery deeper ───────────────────
    T("com.lime.desktop",            "Lime Scooters",            "unitedStates", "social-media",    "lime"),
    T("com.bird.desktop",            "Bird",                     "unitedStates", "social-media",    "bird"),
    T("com.spin.desktop",            "Spin Scooters",            "unitedStates", "social-media",    "spin"),
    T("com.tier.mobility",           "TIER Mobility",            "europe",       "social-media",    "tier"),  // DE — skip
    T("com.voi.scooters",            "Voi Scooters",             "europe",       "social-media",    "voi"),  // Sweden — skip
    T("com.dott.desktop",            "Dott",                     "europe",       "social-media",    "dott"),  // Belgium — skip

    // ─── US marketplaces ──────────────────────────────────────────
    T("com.stockx.desktop",          "StockX",                   "unitedStates", "social-media",    "stockx"),
    T("com.goat.desktop",            "GOAT",                     "unitedStates", "social-media",    "goat"),
    T("com.carvana.desktop",         "Carvana",                  "unitedStates", "social-media",    "carvana"),
    T("com.vroom.desktop",           "Vroom",                    "unitedStates", "social-media",    "vroom"),
    T("com.zillow.desktop",          "Zillow",                   "unitedStates", "social-media",    "zillow"),
    T("com.redfin.desktop",          "Redfin",                   "unitedStates", "social-media",    "redfin"),
    T("com.realtor.desktop",         "Realtor.com",              "unitedStates", "social-media",    "realtor"),
    T("com.apartmentlist.desktop",   "Apartment List",           "unitedStates", "social-media",    "apartmentlist"),

    // ─── US niche SaaS (ABM / RevOps) ──────────────────────────────
    T("com.lattice.desktop",         "Lattice HR",               "unitedStates", "crm",             "lattice"),
    T("com.15five.desktop",          "15Five",                   "unitedStates", "crm",             "15five"),
    T("com.culturecamp.desktop",     "Culture Amp",              "other",        "crm",             "cultureamp"),  // Australia
    T("com.peakon.desktop",          "Workday Peakon",           "europe",       "crm",             "peakon"),  // Denmark — skip
    T("com.workiva.desktop",         "Workiva",                  "unitedStates", "office",          "workiva"),
    T("com.diligent.desktop",        "Diligent Boards",          "unitedStates", "office",          "diligent"),

    // ─── US niche consumer apps ───────────────────────────────────
    T("com.duolingo.plus",           "Duolingo Max",             "unitedStates", "video-streaming", "duomax"),
    T("com.babble.app",              "Babble Kids",              "unitedStates", "video-streaming", "babble"),
    T("com.dailymotion.desktop",     "Dailymotion",              "europe",       "video-streaming", "dailymotion"),  // France — skip
    T("com.vbox7.desktop",           "Vbox7",                    "europe",       "video-streaming", "vbox7"),  // Bulgaria — skip

    // ─── More Mac indie utilities ─────────────────────────────────
    T("com.contxts.raycast-clips",   "Raycast Clips",            "unitedStates", "clipboard",       "raycast-clips"),
    T("com.paste.app",               "Paste",                    "europe",       "clipboard",       "paste"),  // Portugal — skip
    T("com.commandprompt.cmdpro",    "Command Pro",              "unitedStates", "system-util",     "cmd-pro"),
    T("com.pilotmoon.SleepAidX",     "Sleep Aid X",              "unitedStates", "habit-track",     "sleepaid"),
    T("com.bohemiancoding.hype",     "Hype 4",                   "europe",       "vector",          "hype"),  // Germany — skip
    T("com.monodraw.mac",            "Monodraw",                 "europe",       "drawio",          "monodraw"),  // UK — skip
    T("com.blackmagic.cameracontrol","Blackmagic Camera",        "other",        "video-edit",      "bm-camera"),
    T("com.teslamotors.tesla-app",   "Tesla (Mac companion)",    "unitedStates", "system-util",     "tesla"),

    // ─── More accessibility / niche ────────────────────────────────
    T("com.spectre.desktop",         "Spectre",                  "unitedStates", "system-util",     "spectre"),
    T("com.vision.desktop",          "VoiceOver Companion",      "unitedStates", "system-util",     "vo-companion"),

    // ─── US news / information ─────────────────────────────────────
    T("com.nytimes.desktop",         "NYTimes",                  "unitedStates", "feed-reader",     "nyt"),
    T("com.washingtonpost.desktop",  "Washington Post",          "unitedStates", "feed-reader",     "wapo"),
    T("com.wsj.desktop",             "Wall Street Journal",      "unitedStates", "feed-reader",     "wsj"),
    T("com.bloomberg.desktop",       "Bloomberg",                "unitedStates", "feed-reader",     "bloomberg"),
    T("com.cnn.desktop",             "CNN",                      "unitedStates", "feed-reader",     "cnn"),
    T("com.foxnews.desktop",         "Fox News",                 "unitedStates", "feed-reader",     "foxnews"),
    T("com.nbcnews.desktop",         "NBC News",                 "unitedStates", "feed-reader",     "nbcnews"),
    T("com.usatoday.desktop",        "USA Today",                "unitedStates", "feed-reader",     "usatoday"),

    // ─── More Chinese niche (bringing CN coverage deeper) ──────────
    T("com.tencent.pitu",            "Tencent Pitu (photo)",     "china",        "photo-edit",      "pitu"),
    T("com.tencent.meitu",           "Meitu",                    "china",        "photo-edit",      "meitu"),
    T("com.meitu.beautycam",         "BeautyCam",                "china",        "photo-edit",      "beautycam"),
    T("com.meitu.meipai",            "Meipai",                   "china",        "video-edit",      "meipai"),
    T("com.beautyplus.desktop",      "BeautyPlus",               "china",        "photo-edit",      "beautyplus"),
    T("com.faceu.desktop",           "FaceU (ByteDance)",        "china",        "photo-edit",      "faceu"),
    T("com.wnacg.desktop",           "Wnacg Reader",             "china",        "reader",          "wnacg"),
    T("com.damai.desktop",           "Damai (Alibaba tickets)",  "china",        "social-media",    "damai"),
    T("com.ximalaya.desktop",        "Ximalaya",                 "china",        "audio-player",    "ximalaya"),
    T("com.lizhi.desktop",           "LizhiFM",                  "china",        "audio-player",    "lizhi"),
    T("com.qingting.desktop",        "Qingting FM",              "china",        "audio-player",    "qingting"),
    T("com.zhubajie.desktop",        "Zhubajie",                 "china",        "crm",             "zhubajie"),
    T("com.liepin.desktop",          "Liepin",                   "china",        "crm",             "liepin"),
    T("com.zhipin.desktop",          "BOSS Zhipin",              "china",        "crm",             "zhipin"),
    T("com.lagou.desktop",           "Lagou (jobs)",             "china",        "crm",             "lagou"),
    T("com.zhaopin.desktop",         "Zhaopin",                  "china",        "crm",             "zhaopin"),
    T("com.58.desktop",              "58.com",                   "china",        "social-media",    "58"),
    T("com.anjuke.desktop",          "Anjuke",                   "china",        "social-media",    "anjuke"),
    T("com.beike.desktop",           "Beike (Lianjia)",          "china",        "social-media",    "beike"),
    T("com.autohome.desktop",        "AutoHome",                 "china",        "social-media",    "autohome"),
    T("com.pingan.desktop",          "Ping An (insurance)",      "china",        "finance",         "pingan"),
    T("com.wechatpay.desktop",       "WeChat Pay",               "china",        "finance",         "wechatpay"),
    T("com.cmbchina.desktop",        "CMB China",                "china",        "finance",         "cmbchina"),
    T("com.icbc.desktop",            "ICBC",                     "china",        "finance",         "icbc"),
    T("com.abchina.desktop",         "Agricultural Bank of China","china",       "finance",         "abchina"),
    T("com.boc.desktop",             "Bank of China",            "china",        "finance",         "boc"),

    // ─── Misc US/other rounding out coverage ───────────────────────
    T("com.adp.desktop",             "ADP Workforce Now",        "unitedStates", "crm",             "adp"),
    T("com.paychex.desktop",         "Paychex",                  "unitedStates", "crm",             "paychex"),
    T("com.paylocity.desktop",       "Paylocity",                "unitedStates", "crm",             "paylocity"),
    T("com.workday.financials",      "Workday Financials",       "unitedStates", "finance",         "workday-fin"),
    T("com.netsuite.desktop",        "NetSuite (Oracle)",        "unitedStates", "crm",             "netsuite"),
    T("com.sap.desktop-client",      "SAP Business Client",      "europe",       "crm",             "sap"),  // Germany — skip
    T("com.microsoft.dynamics",      "Microsoft Dynamics 365",   "unitedStates", "crm",             "dynamics"),
    T("com.oracle.ebs",              "Oracle EBS",               "unitedStates", "crm",             "oracle-ebs"),
    T("com.oracle.peoplesoft",       "Oracle PeopleSoft",        "unitedStates", "crm",             "peoplesoft"),
    T("com.infor.desktop",           "Infor",                    "unitedStates", "crm",             "infor"),
    T("com.epicor.desktop",          "Epicor ERP",               "unitedStates", "crm",             "epicor"),

    // ─── US telehealth / pharma / health ──────────────────────────
    T("com.goodrx.desktop",          "GoodRx",                   "unitedStates", "crm",             "goodrx"),
    T("com.23andme.desktop",         "23andMe",                  "unitedStates", "crm",             "23andme"),
    T("com.ancestry.desktop",        "Ancestry",                 "unitedStates", "crm",             "ancestry"),

    // ─── Final rounding ────────────────────────────────────────────
    T("com.reddit.official",         "Reddit Official (alt)",    "unitedStates", "social-media",    "reddit-alt"),
    T("com.twitch.mobile",           "Twitch Mobile (alt)",      "unitedStates", "video-streaming", "twitch-alt"),
    T("com.zhihu.mac",               "Zhihu Desktop (alt)",      "china",        "social-media",    "zhihu-alt"),

    // ─── Apple ecosystem additions ─────────────────────────────────
    T("com.apple.Numbers.Mac",       "Apple Numbers (alt bundle)","unitedStates","office",          "numbers-alt"),
    T("com.apple.iCloud.Drive",      "iCloud Drive",             "unitedStates", "storage-personal","icloud-drive"),
    T("com.apple.iCloud.Photos",     "iCloud Photos",            "unitedStates", "photo-manager",   "icloud-photos"),
    T("com.apple.iCloud.Mail",       "iCloud Mail",              "unitedStates", "mail",            "icloud-mail"),
    T("com.apple.Arcade.Mac",        "Apple Arcade (alt)",       "unitedStates", "system-util",     "arcade-alt"),
]

// MARK: - Merge logic

struct ExistingAlt: Codable {
    let id: String
    let origin: String
    let name: String
    let homepage: String
    let note: String
    let downloadURL: String?
}
struct ExistingEntry: Codable {
    let targetBundleID: String
    let targetDisplayName: String
    let targetOrigin: String
    let alternatives: [ExistingAlt]
}
struct ExistingCatalog: Codable {
    let version: Int
    let comment: String
    let entries: [ExistingEntry]
}
struct OutCatalog: Encodable {
    let version: Int
    let comment: String
    let entries: [ExistingEntry]
}

let jsonURL = URL(fileURLWithPath: "Scripts/sovereignty-catalog.json")

do {
    let data = try Data(contentsOf: jsonURL)
    let catalog = try JSONDecoder().decode(ExistingCatalog.self, from: data)

    let existingBundleIDs = Set(catalog.entries.map { $0.targetBundleID })
    var existingAltIDs = Set<String>()
    for e in catalog.entries { for a in e.alternatives { existingAltIDs.insert(a.id) } }

    var newEntries: [ExistingEntry] = []
    var skipped = (existing: 0, noncanonical: 0, badCategory: 0)

    for t in newTargets {
        // Skip apps that are already in the catalog (idempotent).
        if existingBundleIDs.contains(t.bundleID) {
            skipped.existing += 1; continue
        }
        // Skip apps that are EU/OSS themselves — they're not sovereignty
        // targets (the invariant tests would reject them anyway).
        if ["europe", "oss", "europeAndOSS"].contains(t.origin) {
            skipped.noncanonical += 1; continue
        }
        guard let template = Alts[t.category] else {
            fputs("warn: unknown category '\(t.category)' for \(t.bundleID)\n", stderr)
            skipped.badCategory += 1; continue
        }
        let recommendable = template.filter { ["europe", "oss", "europeAndOSS"].contains($0.origin) }
        if recommendable.isEmpty {
            fputs("warn: category '\(t.category)' has no recommendable alt\n", stderr)
            skipped.badCategory += 1; continue
        }
        // Filter: keep only alts where origin is .europe / .oss / .europeAndOSS / .other
        // (never US/CN/RU — the catalog invariant).
        let validAlts = template.filter { !["unitedStates", "china", "russia"].contains($0.origin) }
        let alts: [ExistingAlt] = validAlts.compactMap { at in
            let id = "\(t.slug):\(at.id)"
            // Guard against global duplicate IDs (shouldn't happen but defensive).
            if existingAltIDs.contains(id) {
                fputs("warn: duplicate alt id '\(id)' (target: \(t.bundleID))\n", stderr)
                return nil
            }
            existingAltIDs.insert(id)
            return ExistingAlt(id: id, origin: at.origin, name: at.name,
                               homepage: at.homepage, note: at.note,
                               downloadURL: at.downloadURL)
        }
        if alts.isEmpty {
            fputs("warn: \(t.bundleID) ended up with zero alts after filtering\n", stderr)
            continue
        }
        newEntries.append(ExistingEntry(
            targetBundleID: t.bundleID,
            targetDisplayName: t.name,
            targetOrigin: t.origin,
            alternatives: alts
        ))
    }

    let merged = OutCatalog(
        version: catalog.version,
        comment: catalog.comment,
        entries: catalog.entries + newEntries
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let outData = try encoder.encode(merged)
    try outData.write(to: jsonURL)

    print("✓ merged \(newEntries.count) new entries; total \(merged.entries.count)")
    print("   skipped: \(skipped.existing) already-present, \(skipped.noncanonical) EU/OSS (not targets), \(skipped.badCategory) bad category")

} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
