import Foundation

/// v1.2: the alternatives catalog — handwritten seed data mapping
/// common American/closed-source Mac apps to their European and
/// open-source alternatives.
///
/// The catalog is intentionally modest at launch (~30 entries).  The
/// goal is to cover the 80% case (Office, Adobe, Zoom, Slack, Chrome,
/// etc.) with high-quality alts you can vouch for — not to be
/// exhaustive.  Community PRs expand it from there.
///
/// Design principles for new entries:
///
///   1. **Alternatives must be real and shippable.**  No vapourware.
///      Link to an actual download page or installer.
///   2. **EU = EU member state + EEA + Switzerland.**  Splynek takes
///      the pragmatic "European tech ecosystem" definition rather
///      than the strict 27-member one.  Call out the country in the
///      note — "Mullvad (Sweden)", "Proton (Switzerland)" etc.
///   3. **OSS = genuinely open-source, usable license.**  GPL / MIT /
///      BSD / MPL.  "Source-available" or "commons clause" doesn't
///      count.
///   4. **One or two alternatives per target.**  If there are ten
///      good options, pick the two most widely used.  Users don't
///      want choice paralysis.
///   5. **Never shame the original.**  The tone is "here's a door
///      out if you want one," not "you should feel bad about using
///      Chrome."
///
/// Match is by bundle ID exact-match.  Display name matching is
/// avoided — too easily false-matches ("Photos" Mac app vs "Google
/// Photos" uploader).
enum SovereigntyCatalog {

    struct Alternative: Identifiable, Hashable {
        let id: String          // stable key, "<targetBundleID>:<slug>"
        let origin: Origin
        let name: String
        let homepage: URL
        /// One-line note shown under the alternative in the UI.
        /// Include country + license so users can decide at a glance.
        let note: String

        enum Origin: String, Codable, CaseIterable, Identifiable {
            case eu, oss, both
            var id: String { rawValue }
            var label: String {
                switch self {
                case .eu:   return "EU"
                case .oss:  return "OSS"
                case .both: return "EU + OSS"
                }
            }
        }
    }

    struct Entry: Hashable {
        let targetBundleID: String
        let targetDisplayName: String   // as shown in UI when listing
        let alternatives: [Alternative]
    }

    /// The seed catalog.  ~30 entries — cover the most common apps
    /// users will see on their Mac that have good alternatives.
    ///
    /// Grouped visually by category in the comments; order doesn't
    /// matter at runtime (UI filters + sorts).
    static let entries: [Entry] = [

        // ─── Browsers ─────────────────────────────────────────────
        Entry(targetBundleID: "com.google.Chrome",
              targetDisplayName: "Google Chrome",
              alternatives: [
                .init(id: "chrome:firefox", origin: .oss,
                      name: "Firefox", homepage: URL(string: "https://www.mozilla.org/firefox")!,
                      note: "Mozilla Foundation (MPL). Gecko engine, strong privacy defaults."),
                .init(id: "chrome:vivaldi", origin: .eu,
                      name: "Vivaldi", homepage: URL(string: "https://vivaldi.com")!,
                      note: "Vivaldi Technologies (Norway). Freeware, privacy-respecting."),
              ]),

        Entry(targetBundleID: "com.microsoft.edgemac",
              targetDisplayName: "Microsoft Edge",
              alternatives: [
                .init(id: "edge:firefox", origin: .oss,
                      name: "Firefox", homepage: URL(string: "https://www.mozilla.org/firefox")!,
                      note: "Mozilla Foundation (MPL)."),
                .init(id: "edge:vivaldi", origin: .eu,
                      name: "Vivaldi", homepage: URL(string: "https://vivaldi.com")!,
                      note: "Vivaldi Technologies (Norway)."),
              ]),

        // ─── Communication ────────────────────────────────────────
        Entry(targetBundleID: "com.tinyspeck.slackmacgap",
              targetDisplayName: "Slack",
              alternatives: [
                .init(id: "slack:element", origin: .both,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK-based. Matrix protocol, fully open-source, self-hostable."),
                .init(id: "slack:mattermost", origin: .oss,
                      name: "Mattermost", homepage: URL(string: "https://mattermost.com")!,
                      note: "MIT-licensed server + clients, team-chat."),
              ]),

        Entry(targetBundleID: "us.zoom.xos",
              targetDisplayName: "Zoom",
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
              alternatives: [
                .init(id: "teams:element", origin: .both,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol, self-hostable."),
                .init(id: "teams:jitsi", origin: .oss,
                      name: "Jitsi Meet", homepage: URL(string: "https://jitsi.org")!,
                      note: "Apache-licensed, no account needed."),
              ]),

        Entry(targetBundleID: "com.microsoft.teams2",
              targetDisplayName: "Microsoft Teams (New)",
              alternatives: [
                .init(id: "teams2:element", origin: .both,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol."),
                .init(id: "teams2:jitsi", origin: .oss,
                      name: "Jitsi Meet", homepage: URL(string: "https://jitsi.org")!,
                      note: "Apache-licensed."),
              ]),

        Entry(targetBundleID: "com.hnc.Discord",
              targetDisplayName: "Discord",
              alternatives: [
                .init(id: "discord:revolt", origin: .oss,
                      name: "Revolt", homepage: URL(string: "https://revolt.chat")!,
                      note: "AGPL-licensed Discord-alike. Self-hostable."),
                .init(id: "discord:element", origin: .both,
                      name: "Element", homepage: URL(string: "https://element.io")!,
                      note: "UK. Matrix protocol."),
              ]),

        Entry(targetBundleID: "com.whatsapp.WhatsApp",
              targetDisplayName: "WhatsApp",
              alternatives: [
                .init(id: "wa:signal", origin: .oss,
                      name: "Signal", homepage: URL(string: "https://signal.org")!,
                      note: "Signal Foundation. Gold-standard E2E."),
                .init(id: "wa:threema", origin: .eu,
                      name: "Threema", homepage: URL(string: "https://threema.ch")!,
                      note: "Threema GmbH (Switzerland). Paid, no phone-number required."),
              ]),

        // ─── Productivity / Office ────────────────────────────────
        Entry(targetBundleID: "com.microsoft.Word",
              targetDisplayName: "Microsoft Word",
              alternatives: [
                .init(id: "word:libreoffice", origin: .oss,
                      name: "LibreOffice", homepage: URL(string: "https://www.libreoffice.org")!,
                      note: "The Document Foundation (Germany). MPL. Drop-in replacement."),
                .init(id: "word:onlyoffice", origin: .both,
                      name: "ONLYOFFICE", homepage: URL(string: "https://www.onlyoffice.com")!,
                      note: "Ascensio System (Latvia). AGPL community edition."),
              ]),

        Entry(targetBundleID: "com.microsoft.Excel",
              targetDisplayName: "Microsoft Excel",
              alternatives: [
                .init(id: "excel:libreoffice", origin: .oss,
                      name: "LibreOffice Calc", homepage: URL(string: "https://www.libreoffice.org")!,
                      note: "The Document Foundation (Germany). MPL."),
                .init(id: "excel:onlyoffice", origin: .both,
                      name: "ONLYOFFICE", homepage: URL(string: "https://www.onlyoffice.com")!,
                      note: "Latvia. AGPL community edition."),
              ]),

        Entry(targetBundleID: "com.microsoft.Powerpoint",
              targetDisplayName: "Microsoft PowerPoint",
              alternatives: [
                .init(id: "ppt:libreoffice", origin: .oss,
                      name: "LibreOffice Impress", homepage: URL(string: "https://www.libreoffice.org")!,
                      note: "The Document Foundation (Germany). MPL."),
              ]),

        Entry(targetBundleID: "com.microsoft.outlook",
              targetDisplayName: "Microsoft Outlook",
              alternatives: [
                .init(id: "outlook:thunderbird", origin: .oss,
                      name: "Thunderbird", homepage: URL(string: "https://www.thunderbird.net")!,
                      note: "MZLA / Mozilla Foundation. MPL."),
                .init(id: "outlook:protonmail", origin: .eu,
                      name: "Proton Mail", homepage: URL(string: "https://proton.me/mail")!,
                      note: "Proton AG (Switzerland). E2E-encrypted webmail."),
              ]),

        Entry(targetBundleID: "com.notion.id",
              targetDisplayName: "Notion",
              alternatives: [
                .init(id: "notion:obsidian", origin: .oss,
                      name: "Obsidian", homepage: URL(string: "https://obsidian.md")!,
                      note: "Dynalist Inc. Local-first markdown, free for personal use."),
                .init(id: "notion:logseq", origin: .oss,
                      name: "Logseq", homepage: URL(string: "https://logseq.com")!,
                      note: "AGPL. Local-first outliner + graph."),
              ]),

        Entry(targetBundleID: "com.evernote.Evernote",
              targetDisplayName: "Evernote",
              alternatives: [
                .init(id: "evernote:joplin", origin: .oss,
                      name: "Joplin", homepage: URL(string: "https://joplinapp.org")!,
                      note: "AGPL. E2E-encrypted sync."),
                .init(id: "evernote:obsidian", origin: .oss,
                      name: "Obsidian", homepage: URL(string: "https://obsidian.md")!,
                      note: "Local-first markdown notes."),
              ]),

        // ─── Creative / Media ─────────────────────────────────────
        Entry(targetBundleID: "com.adobe.Photoshop",
              targetDisplayName: "Adobe Photoshop",
              alternatives: [
                .init(id: "ps:gimp", origin: .oss,
                      name: "GIMP", homepage: URL(string: "https://www.gimp.org")!,
                      note: "GPL. Open-source image editor."),
                .init(id: "ps:affinity", origin: .eu,
                      name: "Affinity Photo", homepage: URL(string: "https://affinity.serif.com/photo/")!,
                      note: "Serif (UK). One-time purchase, no subscription."),
              ]),

        Entry(targetBundleID: "com.adobe.Illustrator",
              targetDisplayName: "Adobe Illustrator",
              alternatives: [
                .init(id: "ai:inkscape", origin: .oss,
                      name: "Inkscape", homepage: URL(string: "https://inkscape.org")!,
                      note: "GPL. Vector graphics editor."),
                .init(id: "ai:affinity-designer", origin: .eu,
                      name: "Affinity Designer", homepage: URL(string: "https://affinity.serif.com/designer/")!,
                      note: "Serif (UK). One-time purchase."),
              ]),

        Entry(targetBundleID: "com.adobe.InDesign",
              targetDisplayName: "Adobe InDesign",
              alternatives: [
                .init(id: "id:affinity-publisher", origin: .eu,
                      name: "Affinity Publisher", homepage: URL(string: "https://affinity.serif.com/publisher/")!,
                      note: "Serif (UK). One-time purchase."),
                .init(id: "id:scribus", origin: .oss,
                      name: "Scribus", homepage: URL(string: "https://www.scribus.net")!,
                      note: "GPL. Desktop publishing."),
              ]),

        Entry(targetBundleID: "com.adobe.LightroomCC",
              targetDisplayName: "Adobe Lightroom",
              alternatives: [
                .init(id: "lr:darktable", origin: .oss,
                      name: "darktable", homepage: URL(string: "https://www.darktable.org")!,
                      note: "GPL. RAW photo editor + library."),
                .init(id: "lr:capture-one", origin: .eu,
                      name: "Capture One", homepage: URL(string: "https://www.captureone.com")!,
                      note: "Capture One (Denmark). Pro-grade RAW."),
              ]),

        // ─── Dev / Productivity tools ─────────────────────────────
        Entry(targetBundleID: "com.microsoft.VSCode",
              targetDisplayName: "Visual Studio Code",
              alternatives: [
                .init(id: "vscode:vscodium", origin: .oss,
                      name: "VSCodium", homepage: URL(string: "https://vscodium.com")!,
                      note: "MIT. Telemetry-free build of VS Code."),
                .init(id: "vscode:zed", origin: .oss,
                      name: "Zed", homepage: URL(string: "https://zed.dev")!,
                      note: "GPL. Fast native editor."),
              ]),

        Entry(targetBundleID: "com.postmanlabs.mac",
              targetDisplayName: "Postman",
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
              alternatives: [
                .init(id: "docker:orbstack", origin: .oss,
                      name: "OrbStack", homepage: URL(string: "https://orbstack.dev")!,
                      note: "Free tier + paid. Native Mac container runtime."),
                .init(id: "docker:colima", origin: .oss,
                      name: "Colima", homepage: URL(string: "https://github.com/abiosoft/colima")!,
                      note: "MIT. Command-line container runtime."),
              ]),

        // ─── Cloud storage ────────────────────────────────────────
        Entry(targetBundleID: "com.google.drivefs",
              targetDisplayName: "Google Drive",
              alternatives: [
                .init(id: "gdrive:nextcloud", origin: .oss,
                      name: "Nextcloud", homepage: URL(string: "https://nextcloud.com")!,
                      note: "Nextcloud GmbH (Germany). AGPL. Self-hosted or via EU providers."),
                .init(id: "gdrive:protondrive", origin: .eu,
                      name: "Proton Drive", homepage: URL(string: "https://proton.me/drive")!,
                      note: "Proton AG (Switzerland). E2E-encrypted."),
              ]),

        Entry(targetBundleID: "com.getdropbox.dropbox",
              targetDisplayName: "Dropbox",
              alternatives: [
                .init(id: "dropbox:nextcloud", origin: .oss,
                      name: "Nextcloud", homepage: URL(string: "https://nextcloud.com")!,
                      note: "Germany. AGPL. Self-hosted or via EU providers."),
                .init(id: "dropbox:protondrive", origin: .eu,
                      name: "Proton Drive", homepage: URL(string: "https://proton.me/drive")!,
                      note: "Switzerland. E2E-encrypted."),
              ]),

        // ─── Passwords ────────────────────────────────────────────
        Entry(targetBundleID: "com.1password.1password",
              targetDisplayName: "1Password 7",
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
              alternatives: [
                .init(id: "1p7:bitwarden", origin: .oss,
                      name: "Bitwarden", homepage: URL(string: "https://bitwarden.com")!,
                      note: "AGPL."),
                .init(id: "1p7:keepassxc", origin: .oss,
                      name: "KeePassXC", homepage: URL(string: "https://keepassxc.org")!,
                      note: "GPL."),
              ]),

        // ─── Misc ────────────────────────────────────────────────
        Entry(targetBundleID: "com.spotify.client",
              targetDisplayName: "Spotify",
              alternatives: [
                .init(id: "spotify:deezer", origin: .eu,
                      name: "Deezer", homepage: URL(string: "https://www.deezer.com")!,
                      note: "Deezer (France). Music streaming, similar catalog."),
                .init(id: "spotify:tidal", origin: .eu,
                      name: "Tidal", homepage: URL(string: "https://tidal.com")!,
                      note: "Aspiro (Norway). Hi-res music streaming."),
              ]),

        Entry(targetBundleID: "com.todesktop.230313mzl4w4u92",
              targetDisplayName: "Cursor",
              alternatives: [
                .init(id: "cursor:zed", origin: .oss,
                      name: "Zed", homepage: URL(string: "https://zed.dev")!,
                      note: "GPL. Native editor with AI integration."),
                .init(id: "cursor:vscodium", origin: .oss,
                      name: "VSCodium", homepage: URL(string: "https://vscodium.com")!,
                      note: "MIT. Plus Continue.dev for AI."),
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
