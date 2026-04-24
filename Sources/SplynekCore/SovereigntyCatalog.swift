import Foundation

/// v1.2: the alternatives catalog — handwritten seed data that maps
/// installed Mac apps to European or open-source alternatives.
///
/// Framing: the tab is about **EU digital sovereignty**, not about
/// any one country.  An app controlled by a US corporation and an
/// app controlled by a Chinese corporation are in the same bucket
/// from the perspective of a European user concerned with jurisdiction,
/// data residency, GDPR applicability, and supply-chain risk.  We
/// surface the target's origin so the user sees *where control sits*,
/// and we recommend European or open-source alternatives because
/// those are the two buckets that most reduce non-EU dependence.
///
/// The catalog is intentionally modest at launch (~80 entries).  The
/// goal is to cover the common cases with high-quality alts you can
/// vouch for — not to be exhaustive.  Community PRs expand it from
/// there.
///
/// Design principles for new entries:
///
///   1. **Alternatives must be real and shippable.**  No vapourware.
///      Link to an actual download page.
///   2. **European ecosystem = EU member state + EEA + UK + Switzerland.**
///      Pragmatic definition that matches the region users think of
///      as "not-non-EU."  Call out the country in the note —
///      "Mullvad (Sweden)", "Proton (Switzerland)" etc.
///   3. **OSS = genuinely open-source, usable license.**  GPL / MIT /
///      BSD / MPL / Apache.  "Source-available" or "commons clause"
///      doesn't count.
///   4. **One or two alternatives per target.**  Choice paralysis
///      kills action.
///   5. **Never shame the original.**  The tone is "here's a door
///      out if you want one," not "you should feel bad about having
///      Chrome installed."
///   6. **Origin-neutral targeting.**  Any app whose vendor sits
///      outside the European ecosystem is a valid target — not just
///      US apps.  Chinese, Russian, other jurisdictions all count.
enum SovereigntyCatalog {

    /// Where an app (or its alternative) is controlled from.
    ///
    /// For *targets*: any value is valid — describes where the user's
    /// installed app's control sits.
    /// For *alternatives*: we only recommend `.europe`, `.oss`, or
    /// `.europeAndOSS`.  Those are the buckets that reduce non-EU
    /// dependency.
    enum Origin: String, Codable, CaseIterable, Identifiable {
        /// EU member state, EEA, UK, or Switzerland.  The pragmatic
        /// "European tech ecosystem" definition.
        case europe
        /// Open-source (recognized license, jurisdiction-agnostic).
        case oss
        /// Both European AND open-source.
        case europeAndOSS
        /// United States.  The largest single origin of installed
        /// Mac apps, but not the only one flagged.
        case unitedStates
        /// China.
        case china
        /// Russia.
        case russia
        /// Anywhere else (Canada, Japan, Korea, Australia, etc.).
        /// Put the specific country in the entry's note.
        case other

        var id: String { rawValue }

        /// Short UI label — rendered as a coloured badge.
        var label: String {
            switch self {
            case .europe:        return "EU"
            case .oss:           return "OSS"
            case .europeAndOSS:  return "EU + OSS"
            case .unitedStates:  return "US"
            case .china:         return "CN"
            case .russia:        return "RU"
            case .other:         return "OTHER"
            }
        }

        /// True when this origin represents an alternative we'd
        /// positively recommend — i.e. European or open-source.
        /// Used by the UI filter + by guards that prevent us from
        /// accidentally suggesting a US app as an "alternative" to
        /// another US app.
        var isRecommendable: Bool {
            self == .europe || self == .oss || self == .europeAndOSS
        }
    }

    struct Alternative: Identifiable, Hashable {
        let id: String          // stable key, "<targetBundleID>:<slug>"
        let origin: Origin
        let name: String
        let homepage: URL
        /// One-line note shown under the alternative in the UI.
        /// Include country + license so users can decide at a glance.
        let note: String
        /// v1.2: optional direct-download URL for one-click install
        /// via Splynek.  When present, the UI shows an "Install"
        /// button that hands the URL to Splynek's download engine.
        /// When absent, the UI shows a "Visit" button that opens
        /// `homepage` in the default browser.
        ///
        /// We populate this only for alternatives with stable,
        /// canonical download URLs (e.g. `releases.latest/download/
        /// …` patterns).  Apps that require a version-specific path
        /// or a platform picker are left homepage-only to avoid
        /// hallucinating stale URLs — the user takes one click
        /// more but lands on a real page.
        let downloadURL: URL?

        init(id: String, origin: Origin, name: String,
             homepage: URL, note: String, downloadURL: URL? = nil) {
            self.id = id
            self.origin = origin
            self.name = name
            self.homepage = homepage
            self.note = note
            self.downloadURL = downloadURL
        }
    }

    struct Entry: Hashable {
        let targetBundleID: String
        let targetDisplayName: String   // as shown in UI when listing
        /// Where the target app is controlled from.  Surfaced in the
        /// UI as a small badge next to the app name, so the user sees
        /// at a glance *why* we're suggesting an alternative.
        let targetOrigin: Origin
        let alternatives: [Alternative]
    }

    /// The seed catalog.  Targets are grouped by category in comments
    /// but order doesn't matter at runtime (UI sorts alphabetically
    /// by app name at render time).
    ///
    /// Invariant: every target has `targetOrigin` outside the
    /// European ecosystem (never `.europe` / `.oss` / `.europeAndOSS`).
    /// Apps that are already European or open-source aren't "problems
    /// to solve" from the sovereignty angle — they'd only be noise in
    /// the Sovereignty tab.
    ///
    /// Invariant: every alternative has `origin.isRecommendable` —
    /// i.e. `.europe`, `.oss`, or `.europeAndOSS`.  A US alternative
    /// to another US app doesn't help.  Catalog linter should enforce.
    static let entries: [Entry] = [

        // ─── Browsers ─────────────────────────────────────────────
        Entry(targetBundleID: "com.google.Chrome",
              targetDisplayName: "Google Chrome",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "chrome:firefox", origin: .oss,
                      name: "Firefox", homepage: URL(string: "https://www.mozilla.org/firefox")!,
                      note: "Mozilla Foundation (MPL). Gecko engine, strong privacy defaults.",
                      downloadURL: URL(string: "https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-US")),
                .init(id: "chrome:vivaldi", origin: .europe,
                      name: "Vivaldi", homepage: URL(string: "https://vivaldi.com")!,
                      note: "Vivaldi Technologies (Norway). Freeware, privacy-respecting."),
              ]),

        Entry(targetBundleID: "com.microsoft.edgemac",
              targetDisplayName: "Microsoft Edge",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "edge:firefox", origin: .oss,
                      name: "Firefox", homepage: URL(string: "https://www.mozilla.org/firefox")!,
                      note: "Mozilla Foundation (MPL).",
                      downloadURL: URL(string: "https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-US")),
                .init(id: "edge:vivaldi", origin: .europe,
                      name: "Vivaldi", homepage: URL(string: "https://vivaldi.com")!,
                      note: "Vivaldi Technologies (Norway)."),
              ]),

        Entry(targetBundleID: "com.brave.Browser",
              targetDisplayName: "Brave Browser",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "brave:firefox", origin: .oss,
                      name: "Firefox", homepage: URL(string: "https://www.mozilla.org/firefox")!,
                      note: "Mozilla Foundation (MPL).",
                      downloadURL: URL(string: "https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-US")),
                .init(id: "brave:librewolf", origin: .oss,
                      name: "LibreWolf", homepage: URL(string: "https://librewolf.net")!,
                      note: "MPL. Firefox fork, telemetry-free."),
              ]),

        Entry(targetBundleID: "ru.yandex.desktop.yandex-browser",
              targetDisplayName: "Yandex Browser",
              targetOrigin: .russia,
              alternatives: [
                .init(id: "yandex:firefox", origin: .oss,
                      name: "Firefox", homepage: URL(string: "https://www.mozilla.org/firefox")!,
                      note: "Mozilla Foundation (MPL).",
                      downloadURL: URL(string: "https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-US")),
                .init(id: "yandex:vivaldi", origin: .europe,
                      name: "Vivaldi", homepage: URL(string: "https://vivaldi.com")!,
                      note: "Norway. Freeware."),
              ]),

        // ─── Communication / chat / video ─────────────────────────
        Entry(targetBundleID: "com.tinyspeck.slackmacgap",
              targetDisplayName: "Slack",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "slack:element", origin: .europeAndOSS,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK-based. Matrix protocol, fully open-source, self-hostable."),
                .init(id: "slack:mattermost", origin: .oss,
                      name: "Mattermost", homepage: URL(string: "https://mattermost.com")!,
                      note: "MIT-licensed server + clients, team-chat."),
              ]),

        Entry(targetBundleID: "us.zoom.xos",
              targetDisplayName: "Zoom",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "zoom:jitsi", origin: .oss,
                      name: "Jitsi Meet", homepage: URL(string: "https://jitsi.org")!,
                      note: "Apache-licensed. Browser-based, no account needed."),
                .init(id: "zoom:signal", origin: .oss,
                      name: "Signal", homepage: URL(string: "https://signal.org")!,
                      note: "Signal Foundation. E2E-encrypted video calls."),
              ]),

        Entry(targetBundleID: "com.microsoft.teams",
              targetDisplayName: "Microsoft Teams",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "teams:element", origin: .europeAndOSS,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol, self-hostable."),
                .init(id: "teams:jitsi", origin: .oss,
                      name: "Jitsi Meet", homepage: URL(string: "https://jitsi.org")!,
                      note: "Apache-licensed, no account needed."),
              ]),

        Entry(targetBundleID: "com.microsoft.teams2",
              targetDisplayName: "Microsoft Teams (New)",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "teams2:element", origin: .europeAndOSS,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol."),
                .init(id: "teams2:jitsi", origin: .oss,
                      name: "Jitsi Meet", homepage: URL(string: "https://jitsi.org")!,
                      note: "Apache-licensed."),
              ]),

        Entry(targetBundleID: "com.hnc.Discord",
              targetDisplayName: "Discord",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "discord:revolt", origin: .oss,
                      name: "Revolt", homepage: URL(string: "https://revolt.chat")!,
                      note: "AGPL Discord-alike. Self-hostable."),
                .init(id: "discord:element", origin: .europeAndOSS,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol."),
              ]),

        Entry(targetBundleID: "com.whatsapp.WhatsApp",
              targetDisplayName: "WhatsApp",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "wa:signal", origin: .oss,
                      name: "Signal", homepage: URL(string: "https://signal.org")!,
                      note: "Signal Foundation. Gold-standard E2E."),
                .init(id: "wa:threema", origin: .europe,
                      name: "Threema", homepage: URL(string: "https://threema.ch")!,
                      note: "Threema GmbH (Switzerland). Paid, no phone-number required."),
              ]),

        Entry(targetBundleID: "com.facebook.archon.developerID",
              targetDisplayName: "Messenger",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "fbm:signal", origin: .oss,
                      name: "Signal", homepage: URL(string: "https://signal.org")!,
                      note: "Signal Foundation."),
                .init(id: "fbm:threema", origin: .europe,
                      name: "Threema", homepage: URL(string: "https://threema.ch")!,
                      note: "Switzerland."),
              ]),

        Entry(targetBundleID: "com.tencent.xinWeChat",
              targetDisplayName: "WeChat",
              targetOrigin: .china,
              alternatives: [
                .init(id: "wechat:signal", origin: .oss,
                      name: "Signal", homepage: URL(string: "https://signal.org")!,
                      note: "Signal Foundation."),
                .init(id: "wechat:threema", origin: .europe,
                      name: "Threema", homepage: URL(string: "https://threema.ch")!,
                      note: "Switzerland."),
              ]),

        Entry(targetBundleID: "com.tencent.qq",
              targetDisplayName: "QQ",
              targetOrigin: .china,
              alternatives: [
                .init(id: "qq:signal", origin: .oss,
                      name: "Signal", homepage: URL(string: "https://signal.org")!,
                      note: "Signal Foundation."),
                .init(id: "qq:element", origin: .europeAndOSS,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol."),
              ]),

        Entry(targetBundleID: "com.alibaba.DingTalkMac",
              targetDisplayName: "DingTalk",
              targetOrigin: .china,
              alternatives: [
                .init(id: "dingtalk:element", origin: .europeAndOSS,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol."),
                .init(id: "dingtalk:mattermost", origin: .oss,
                      name: "Mattermost", homepage: URL(string: "https://mattermost.com")!,
                      note: "MIT. Team chat."),
              ]),

        Entry(targetBundleID: "com.cisco.webexmeetingsapp",
              targetDisplayName: "Webex",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "webex:jitsi", origin: .oss,
                      name: "Jitsi Meet", homepage: URL(string: "https://jitsi.org")!,
                      note: "Apache-licensed."),
                .init(id: "webex:bbb", origin: .oss,
                      name: "BigBlueButton", homepage: URL(string: "https://bigbluebutton.org")!,
                      note: "LGPL. Web conferencing for education."),
              ]),

        Entry(targetBundleID: "com.loom.desktop-app",
              targetDisplayName: "Loom",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "loom:obs", origin: .oss,
                      name: "OBS Studio", homepage: URL(string: "https://obsproject.com")!,
                      note: "GPL. Screen recording + streaming."),
                .init(id: "loom:tella", origin: .europe,
                      name: "Tella", homepage: URL(string: "https://www.tella.tv")!,
                      note: "Tella (UK)."),
              ]),

        // ─── Productivity / Office ────────────────────────────────
        Entry(targetBundleID: "com.microsoft.Word",
              targetDisplayName: "Microsoft Word",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "word:libreoffice", origin: .oss,
                      name: "LibreOffice", homepage: URL(string: "https://www.libreoffice.org")!,
                      note: "The Document Foundation (Germany). MPL. Drop-in replacement."),
                .init(id: "word:onlyoffice", origin: .europeAndOSS,
                      name: "ONLYOFFICE", homepage: URL(string: "https://www.onlyoffice.com")!,
                      note: "Ascensio System (Latvia). AGPL community edition."),
              ]),

        Entry(targetBundleID: "com.microsoft.Excel",
              targetDisplayName: "Microsoft Excel",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "excel:libreoffice", origin: .oss,
                      name: "LibreOffice Calc", homepage: URL(string: "https://www.libreoffice.org")!,
                      note: "The Document Foundation (Germany). MPL."),
                .init(id: "excel:onlyoffice", origin: .europeAndOSS,
                      name: "ONLYOFFICE", homepage: URL(string: "https://www.onlyoffice.com")!,
                      note: "Latvia. AGPL community edition."),
              ]),

        Entry(targetBundleID: "com.microsoft.Powerpoint",
              targetDisplayName: "Microsoft PowerPoint",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "ppt:libreoffice", origin: .oss,
                      name: "LibreOffice Impress", homepage: URL(string: "https://www.libreoffice.org")!,
                      note: "The Document Foundation (Germany). MPL."),
              ]),

        Entry(targetBundleID: "com.microsoft.outlook",
              targetDisplayName: "Microsoft Outlook",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "outlook:thunderbird", origin: .oss,
                      name: "Thunderbird", homepage: URL(string: "https://www.thunderbird.net")!,
                      note: "MZLA / Mozilla Foundation. MPL."),
                .init(id: "outlook:protonmail", origin: .europe,
                      name: "Proton Mail", homepage: URL(string: "https://proton.me/mail")!,
                      note: "Proton AG (Switzerland). E2E-encrypted webmail."),
              ]),

        Entry(targetBundleID: "com.microsoft.onenote.mac",
              targetDisplayName: "Microsoft OneNote",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "onenote:joplin", origin: .oss,
                      name: "Joplin", homepage: URL(string: "https://joplinapp.org")!,
                      note: "AGPL. E2E-encrypted sync."),
                .init(id: "onenote:obsidian", origin: .oss,
                      name: "Obsidian", homepage: URL(string: "https://obsidian.md")!,
                      note: "Local-first markdown."),
              ]),

        Entry(targetBundleID: "com.kingsoft.wpsoffice.mac",
              targetDisplayName: "WPS Office",
              targetOrigin: .china,
              alternatives: [
                .init(id: "wps:libreoffice", origin: .oss,
                      name: "LibreOffice", homepage: URL(string: "https://www.libreoffice.org")!,
                      note: "Germany. MPL."),
                .init(id: "wps:onlyoffice", origin: .europeAndOSS,
                      name: "ONLYOFFICE", homepage: URL(string: "https://www.onlyoffice.com")!,
                      note: "Latvia. AGPL."),
              ]),

        Entry(targetBundleID: "com.notion.id",
              targetDisplayName: "Notion",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "notion:obsidian", origin: .oss,
                      name: "Obsidian", homepage: URL(string: "https://obsidian.md")!,
                      note: "Local-first markdown, free for personal use."),
                .init(id: "notion:logseq", origin: .oss,
                      name: "Logseq", homepage: URL(string: "https://logseq.com")!,
                      note: "AGPL. Local-first outliner."),
              ]),

        Entry(targetBundleID: "com.evernote.Evernote",
              targetDisplayName: "Evernote",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "evernote:joplin", origin: .oss,
                      name: "Joplin", homepage: URL(string: "https://joplinapp.org")!,
                      note: "AGPL. E2E-encrypted sync."),
                .init(id: "evernote:obsidian", origin: .oss,
                      name: "Obsidian", homepage: URL(string: "https://obsidian.md")!,
                      note: "Local-first markdown."),
              ]),

        Entry(targetBundleID: "com.flexibits.fantastical2.mac",
              targetDisplayName: "Fantastical",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "fantastical:proton-calendar", origin: .europe,
                      name: "Proton Calendar", homepage: URL(string: "https://proton.me/calendar")!,
                      note: "Switzerland. E2E-encrypted."),
              ]),

        Entry(targetBundleID: "com.airtable.airtable",
              targetDisplayName: "Airtable",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "airtable:nocodb", origin: .oss,
                      name: "NocoDB", homepage: URL(string: "https://nocodb.com")!,
                      note: "AGPL. Open-source Airtable alt."),
                .init(id: "airtable:baserow", origin: .europeAndOSS,
                      name: "Baserow", homepage: URL(string: "https://baserow.io")!,
                      note: "Baserow (Netherlands). MIT."),
              ]),

        // ─── Creative / media ─────────────────────────────────────
        Entry(targetBundleID: "com.adobe.Photoshop",
              targetDisplayName: "Adobe Photoshop",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "ps:gimp", origin: .oss,
                      name: "GIMP", homepage: URL(string: "https://www.gimp.org")!,
                      note: "GPL. Open-source image editor."),
                .init(id: "ps:affinity", origin: .europe,
                      name: "Affinity Photo", homepage: URL(string: "https://affinity.serif.com/photo/")!,
                      note: "Serif (UK). One-time purchase."),
              ]),

        Entry(targetBundleID: "com.adobe.Illustrator",
              targetDisplayName: "Adobe Illustrator",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "ai:inkscape", origin: .oss,
                      name: "Inkscape", homepage: URL(string: "https://inkscape.org")!,
                      note: "GPL. Vector graphics editor."),
                .init(id: "ai:affinity-designer", origin: .europe,
                      name: "Affinity Designer", homepage: URL(string: "https://affinity.serif.com/designer/")!,
                      note: "Serif (UK). One-time purchase."),
              ]),

        Entry(targetBundleID: "com.adobe.InDesign",
              targetDisplayName: "Adobe InDesign",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "id:affinity-publisher", origin: .europe,
                      name: "Affinity Publisher", homepage: URL(string: "https://affinity.serif.com/publisher/")!,
                      note: "Serif (UK)."),
                .init(id: "id:scribus", origin: .oss,
                      name: "Scribus", homepage: URL(string: "https://www.scribus.net")!,
                      note: "GPL. Desktop publishing."),
              ]),

        Entry(targetBundleID: "com.adobe.LightroomCC",
              targetDisplayName: "Adobe Lightroom",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "lr:darktable", origin: .oss,
                      name: "darktable", homepage: URL(string: "https://www.darktable.org")!,
                      note: "GPL. RAW photo editor + library."),
                .init(id: "lr:capture-one", origin: .europe,
                      name: "Capture One", homepage: URL(string: "https://www.captureone.com")!,
                      note: "Capture One (Denmark). Pro-grade RAW."),
              ]),

        Entry(targetBundleID: "com.adobe.acc.AdobeCreativeCloud",
              targetDisplayName: "Adobe Creative Cloud",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "cc:affinity-suite", origin: .europe,
                      name: "Affinity Suite (V2)", homepage: URL(string: "https://affinity.serif.com")!,
                      note: "Serif (UK). Photo + Designer + Publisher one-time."),
              ]),

        Entry(targetBundleID: "com.adobe.PremierePro.24",
              targetDisplayName: "Adobe Premiere Pro",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "pr:davinci", origin: .other,
                      name: "DaVinci Resolve", homepage: URL(string: "https://www.blackmagicdesign.com/products/davinciresolve")!,
                      note: "Blackmagic Design (Australia). Free tier exceptionally powerful."),
                .init(id: "pr:kdenlive", origin: .oss,
                      name: "Kdenlive", homepage: URL(string: "https://kdenlive.org")!,
                      note: "GPL. KDE project, non-linear video editor."),
              ]),

        Entry(targetBundleID: "com.figma.Desktop",
              targetDisplayName: "Figma",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "figma:penpot", origin: .europeAndOSS,
                      name: "Penpot", homepage: URL(string: "https://penpot.app")!,
                      note: "Kaleidos (Spain). MPL. Self-hostable design tool."),
                .init(id: "figma:framer", origin: .europe,
                      name: "Framer", homepage: URL(string: "https://www.framer.com")!,
                      note: "Framer (Netherlands). Design + no-code."),
              ]),

        // ─── Dev / tools ──────────────────────────────────────────
        Entry(targetBundleID: "com.microsoft.VSCode",
              targetDisplayName: "Visual Studio Code",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "vscode:vscodium", origin: .oss,
                      name: "VSCodium", homepage: URL(string: "https://vscodium.com")!,
                      note: "MIT. Telemetry-free build of VS Code."),
                .init(id: "vscode:zed", origin: .oss,
                      name: "Zed", homepage: URL(string: "https://zed.dev")!,
                      note: "GPL. Fast native editor."),
              ]),

        Entry(targetBundleID: "com.github.GitHubClient",
              targetDisplayName: "GitHub Desktop",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "ghd:gitui", origin: .oss,
                      name: "GitUI", homepage: URL(string: "https://github.com/gitui-org/gitui")!,
                      note: "MIT. Fast TUI-based git client."),
                .init(id: "ghd:fork", origin: .europe,
                      name: "Fork", homepage: URL(string: "https://git-fork.com")!,
                      note: "DanPristupov (Germany). Free for individuals."),
              ]),

        Entry(targetBundleID: "com.sublimetext.4",
              targetDisplayName: "Sublime Text",
              targetOrigin: .other,  // Australia
              alternatives: [
                .init(id: "sublime:zed", origin: .oss,
                      name: "Zed", homepage: URL(string: "https://zed.dev")!,
                      note: "GPL. Fast native editor."),
                .init(id: "sublime:neovim", origin: .oss,
                      name: "Neovim", homepage: URL(string: "https://neovim.io")!,
                      note: "Apache. Modal editor."),
              ]),

        Entry(targetBundleID: "com.postmanlabs.mac",
              targetDisplayName: "Postman",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "postman:bruno", origin: .oss,
                      name: "Bruno", homepage: URL(string: "https://www.usebruno.com")!,
                      note: "MIT. Git-friendly, no account needed."),
                .init(id: "postman:insomnia", origin: .oss,
                      name: "Insomnia", homepage: URL(string: "https://insomnia.rest")!,
                      note: "Apache. API client."),
              ]),

        Entry(targetBundleID: "com.docker.docker",
              targetDisplayName: "Docker Desktop",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "docker:orbstack", origin: .oss,
                      name: "OrbStack", homepage: URL(string: "https://orbstack.dev")!,
                      note: "Free tier + paid. Native Mac container runtime."),
                .init(id: "docker:colima", origin: .oss,
                      name: "Colima", homepage: URL(string: "https://github.com/abiosoft/colima")!,
                      note: "MIT. Command-line container runtime."),
              ]),

        Entry(targetBundleID: "com.atlassian.sourcetreeapp",
              targetDisplayName: "Sourcetree",
              targetOrigin: .other,  // Atlassian, Australia
              alternatives: [
                .init(id: "sourcetree:fork", origin: .europe,
                      name: "Fork", homepage: URL(string: "https://git-fork.com")!,
                      note: "Germany. Free for individuals."),
                .init(id: "sourcetree:gitui", origin: .oss,
                      name: "GitUI", homepage: URL(string: "https://github.com/gitui-org/gitui")!,
                      note: "MIT. TUI git client."),
              ]),

        // ─── Cloud storage ────────────────────────────────────────
        Entry(targetBundleID: "com.google.drivefs",
              targetDisplayName: "Google Drive",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "gdrive:nextcloud", origin: .europeAndOSS,
                      name: "Nextcloud", homepage: URL(string: "https://nextcloud.com")!,
                      note: "Nextcloud GmbH (Germany). AGPL. Self-hosted or EU providers."),
                .init(id: "gdrive:protondrive", origin: .europe,
                      name: "Proton Drive", homepage: URL(string: "https://proton.me/drive")!,
                      note: "Proton AG (Switzerland). E2E-encrypted."),
              ]),

        Entry(targetBundleID: "com.getdropbox.dropbox",
              targetDisplayName: "Dropbox",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "dropbox:nextcloud", origin: .europeAndOSS,
                      name: "Nextcloud", homepage: URL(string: "https://nextcloud.com")!,
                      note: "Germany. AGPL."),
                .init(id: "dropbox:protondrive", origin: .europe,
                      name: "Proton Drive", homepage: URL(string: "https://proton.me/drive")!,
                      note: "Switzerland. E2E-encrypted."),
              ]),

        Entry(targetBundleID: "com.box.Box",
              targetDisplayName: "Box",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "box:nextcloud", origin: .europeAndOSS,
                      name: "Nextcloud", homepage: URL(string: "https://nextcloud.com")!,
                      note: "Germany. AGPL."),
                .init(id: "box:protondrive", origin: .europe,
                      name: "Proton Drive", homepage: URL(string: "https://proton.me/drive")!,
                      note: "Switzerland."),
              ]),

        Entry(targetBundleID: "com.baidu.BaiduNetdiskMac",
              targetDisplayName: "Baidu Netdisk",
              targetOrigin: .china,
              alternatives: [
                .init(id: "baidu:nextcloud", origin: .europeAndOSS,
                      name: "Nextcloud", homepage: URL(string: "https://nextcloud.com")!,
                      note: "Germany. AGPL."),
                .init(id: "baidu:protondrive", origin: .europe,
                      name: "Proton Drive", homepage: URL(string: "https://proton.me/drive")!,
                      note: "Switzerland."),
              ]),

        // ─── Passwords ────────────────────────────────────────────
        Entry(targetBundleID: "com.1password.1password",
              targetDisplayName: "1Password",
              targetOrigin: .other,  // Canada
              alternatives: [
                .init(id: "1p:bitwarden", origin: .oss,
                      name: "Bitwarden", homepage: URL(string: "https://bitwarden.com")!,
                      note: "AGPL. Free tier generous, self-hostable via Vaultwarden."),
                .init(id: "1p:keepassxc", origin: .oss,
                      name: "KeePassXC", homepage: URL(string: "https://keepassxc.org")!,
                      note: "GPL. Fully local .kdbx file."),
              ]),

        Entry(targetBundleID: "com.1password.1password7",
              targetDisplayName: "1Password 7",
              targetOrigin: .other,
              alternatives: [
                .init(id: "1p7:bitwarden", origin: .oss,
                      name: "Bitwarden", homepage: URL(string: "https://bitwarden.com")!,
                      note: "AGPL."),
                .init(id: "1p7:keepassxc", origin: .oss,
                      name: "KeePassXC", homepage: URL(string: "https://keepassxc.org")!,
                      note: "GPL."),
              ]),

        Entry(targetBundleID: "com.lastpass.LastPass",
              targetDisplayName: "LastPass",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "lp:bitwarden", origin: .oss,
                      name: "Bitwarden", homepage: URL(string: "https://bitwarden.com")!,
                      note: "AGPL."),
                .init(id: "lp:keepassxc", origin: .oss,
                      name: "KeePassXC", homepage: URL(string: "https://keepassxc.org")!,
                      note: "GPL."),
              ]),

        Entry(targetBundleID: "com.dashlane.dashlanephonefinal",
              targetDisplayName: "Dashlane",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "dashlane:bitwarden", origin: .oss,
                      name: "Bitwarden", homepage: URL(string: "https://bitwarden.com")!,
                      note: "AGPL."),
                .init(id: "dashlane:proton-pass", origin: .europe,
                      name: "Proton Pass", homepage: URL(string: "https://proton.me/pass")!,
                      note: "Switzerland. E2E-encrypted."),
              ]),

        // ─── AI / ML ──────────────────────────────────────────────
        Entry(targetBundleID: "com.openai.chat",
              targetDisplayName: "ChatGPT Desktop",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "chatgpt:lmstudio", origin: .oss,
                      name: "LM Studio", homepage: URL(string: "https://lmstudio.ai")!,
                      note: "Run open-weight models (Llama, Mistral, Qwen) fully local."),
                .init(id: "chatgpt:ollama", origin: .oss,
                      name: "Ollama", homepage: URL(string: "https://ollama.com")!,
                      note: "MIT. CLI + API for local model inference."),
                .init(id: "chatgpt:mistral", origin: .europe,
                      name: "Mistral Le Chat", homepage: URL(string: "https://chat.mistral.ai")!,
                      note: "Mistral AI (France). EU-hosted chat."),
              ]),

        Entry(targetBundleID: "com.todesktop.230313mzl4w4u92",
              targetDisplayName: "Cursor",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "cursor:zed", origin: .oss,
                      name: "Zed", homepage: URL(string: "https://zed.dev")!,
                      note: "GPL. Native editor with AI integration."),
                .init(id: "cursor:vscodium", origin: .oss,
                      name: "VSCodium", homepage: URL(string: "https://vscodium.com")!,
                      note: "MIT. Plus Continue.dev for AI."),
              ]),

        Entry(targetBundleID: "com.anthropic.claudefordesktop",
              targetDisplayName: "Claude Desktop",
              targetOrigin: .unitedStates,
              alternatives: [
                .init(id: "claude:lmstudio", origin: .oss,
                      name: "LM Studio", homepage: URL(string: "https://lmstudio.ai")!,
                      note: "Run open-weight models locally."),
                .init(id: "claude:mistral", origin: .europe,
                      name: "Mistral Le Chat", homepage: URL(string: "https://chat.mistral.ai")!,
                      note: "France."),
              ]),

        // ─── Misc / utilities ─────────────────────────────────────
        Entry(targetBundleID: "com.kaspersky.kes",
              targetDisplayName: "Kaspersky Endpoint Security",
              targetOrigin: .russia,
              alternatives: [
                .init(id: "kas:clamav", origin: .oss,
                      name: "ClamAV", homepage: URL(string: "https://www.clamav.net")!,
                      note: "GPL. Open-source anti-malware scanner."),
                .init(id: "kas:f-secure", origin: .europe,
                      name: "F-Secure", homepage: URL(string: "https://www.f-secure.com")!,
                      note: "F-Secure (Finland). Commercial AV."),
              ]),

        Entry(targetBundleID: "com.avast.AAFM",
              targetDisplayName: "Avast Security",
              targetOrigin: .other,  // Czech, but owned by US Gen Digital
              alternatives: [
                .init(id: "avast:clamav", origin: .oss,
                      name: "ClamAV", homepage: URL(string: "https://www.clamav.net")!,
                      note: "GPL."),
                .init(id: "avast:f-secure", origin: .europe,
                      name: "F-Secure", homepage: URL(string: "https://www.f-secure.com")!,
                      note: "Finland."),
              ]),

        Entry(targetBundleID: "com.tencent.meeting.mac",
              targetDisplayName: "Tencent Meeting",
              targetOrigin: .china,
              alternatives: [
                .init(id: "tmeet:jitsi", origin: .oss,
                      name: "Jitsi Meet", homepage: URL(string: "https://jitsi.org")!,
                      note: "Apache."),
                .init(id: "tmeet:element", origin: .europeAndOSS,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol."),
              ]),

        Entry(targetBundleID: "com.zhiliaoapp.musically",
              targetDisplayName: "TikTok",
              targetOrigin: .china,
              alternatives: [
                .init(id: "tiktok:peertube", origin: .oss,
                      name: "PeerTube", homepage: URL(string: "https://joinpeertube.org")!,
                      note: "Framasoft (France). AGPL. Federated video."),
              ]),

        Entry(targetBundleID: "com.alibaba.aliwork",
              targetDisplayName: "AliWork",
              targetOrigin: .china,
              alternatives: [
                .init(id: "aliwork:element", origin: .europeAndOSS,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK."),
                .init(id: "aliwork:onlyoffice", origin: .europeAndOSS,
                      name: "ONLYOFFICE", homepage: URL(string: "https://www.onlyoffice.com")!,
                      note: "Latvia. Office collaboration."),
              ]),
    ]

    /// Build a fast lookup map by bundle ID.  Done lazily because
    /// `entries` has potential duplicates for rebranded bundle IDs
    /// (Teams new/old, 1Password 7/8) — first-match-wins here.
    private static let byBundleID: [String: Entry] = {
        var m: [String: Entry] = [:]
        for e in entries where m[e.targetBundleID] == nil {
            m[e.targetBundleID] = e
        }
        return m
    }()

    /// Look up alternatives for a specific bundle ID.  Returns nil if
    /// the app isn't in the catalog — the UI can then optionally ask
    /// the local LLM for suggestions (v1.3 feature).
    static func alternatives(for bundleID: String) -> Entry? {
        byBundleID[bundleID]
    }
}
