// Copyright © 2026 Splynek. MIT.
//
// SovereigntyCategoryChampions — categorical-fallback table.
//
// 2026-05-08: the specific bundle-ID → alternatives mapping in
// SovereigntyCatalog covers ~1,150 apps.  The Mac App Store has
// ~30,000.  A typical Mac has 100–300 installed apps, of which
// only ~50% land in our hand-curated table.  The other 50% used
// to silently disappear from Sovereignty; this file fixes that.
//
// Strategy: every Mac app declares an `LSApplicationCategoryType`
// in its Info.plist (Apple-defined, ~21 standard categories like
// `public.app-category.productivity`).  When the catalog has no
// specific entry for a bundle ID, we fall back to a curated list
// of "free champions" for that category — LibreOffice for
// productivity, GIMP for graphics, Bitwarden for password
// management, etc.  Result: coverage jumps from ~50% to ~95%
// without hand-curating every bundle ID.
//
// The champions are intentionally short (3–5 per category).
// More than that becomes choice paralysis; the goal is
// "here are 3 known-good free options" not "browse 50".
//
// Architectural notes:
//
// • Pure compile-time data.  No I/O, no validation logic here.
//   Tests pin the structure (`SovereigntyCategoryChampionsTests`).
// • Schema mirrors `SovereigntyCatalog.Alternative` so callers
//   can render the fallbacks with the same row component.
// • `championsForCategory(_:)` accepts the raw
//   LSApplicationCategoryType string ("public.app-category.X")
//   so callers don't need to know about an internal enum.

import Foundation

enum SovereigntyCategoryChampions {

    /// Look up category champions by Apple's
    /// `LSApplicationCategoryType` string.  Returns an empty list
    /// when the category is unknown OR when no champions are
    /// curated yet — caller falls through to "we don't know"
    /// graceful state.
    static func championsForCategory(_ raw: String?) -> [SovereigntyCatalog.Alternative] {
        guard let raw, !raw.isEmpty else { return [] }
        // LSApplicationCategoryType values come fully qualified
        // ("public.app-category.productivity") — strip the prefix
        // for our table key.
        let key = raw.replacingOccurrences(of: "public.app-category.", with: "")
        return table[key] ?? []
    }

    /// Standard Apple-defined categories.  See
    /// https://developer.apple.com/documentation/bundleresources/information-property-list/lsapplicationcategorytype
    /// Listed here in the same order Apple's docs use so a future
    /// reviewer can audit at a glance.
    static let table: [String: [SovereigntyCatalog.Alternative]] = [

        // MARK: Productivity
        "productivity": [
            .init(id: "champion:productivity:libreoffice",
                  origin: .europeAndOSS,
                  name: "LibreOffice",
                  homepage: URL(string: "https://www.libreoffice.org/")!,
                  note: "Office suite (Writer / Calc / Impress). EU-hosted The Document Foundation, AGPL.",
                  downloadURL: URL(string: "https://download.documentfoundation.org/libreoffice/stable/24.8.5/mac/aarch64/LibreOffice_24.8.5_MacOS_aarch64.dmg"),
                  deliveryKind: .versionEmbedded),
            .init(id: "champion:productivity:joplin",
                  origin: .oss,
                  name: "Joplin",
                  homepage: URL(string: "https://joplinapp.org/")!,
                  note: "Notes + to-do app with end-to-end encrypted sync. AGPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:productivity:obsidian",
                  origin: .other,
                  name: "Obsidian",
                  homepage: URL(string: "https://obsidian.md/")!,
                  note: "Markdown notes with local-first storage. Free for personal use.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Business / Office
        "business": [
            .init(id: "champion:business:libreoffice",
                  origin: .europeAndOSS,
                  name: "LibreOffice",
                  homepage: URL(string: "https://www.libreoffice.org/")!,
                  note: "Word/Excel/PowerPoint replacement, MPL/AGPL.",
                  downloadURL: URL(string: "https://download.documentfoundation.org/libreoffice/stable/24.8.5/mac/aarch64/LibreOffice_24.8.5_MacOS_aarch64.dmg"),
                  deliveryKind: .versionEmbedded),
            .init(id: "champion:business:onlyoffice",
                  origin: .other,
                  name: "ONLYOFFICE",
                  homepage: URL(string: "https://www.onlyoffice.com/desktop.aspx")!,
                  note: "Open-source office suite with Word/Excel-compatible UI.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Developer Tools
        "developer-tools": [
            .init(id: "champion:dev:vscode",
                  origin: .other,
                  name: "Visual Studio Code",
                  homepage: URL(string: "https://code.visualstudio.com/")!,
                  note: "Free open-source editor. MIT (the build is Microsoft-branded; use VSCodium for fully OSS).",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:dev:vscodium",
                  origin: .oss,
                  name: "VSCodium",
                  homepage: URL(string: "https://vscodium.com/")!,
                  note: "VSCode without Microsoft telemetry. MIT.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:dev:zed",
                  origin: .other,
                  name: "Zed",
                  homepage: URL(string: "https://zed.dev/")!,
                  note: "Native, GPU-accelerated editor. Open-core under GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Graphics & Design
        "graphics-design": [
            .init(id: "champion:graphics:gimp",
                  origin: .europeAndOSS,
                  name: "GIMP",
                  homepage: URL(string: "https://www.gimp.org/")!,
                  note: "Image editor. GNU Project, GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:graphics:inkscape",
                  origin: .europeAndOSS,
                  name: "Inkscape",
                  homepage: URL(string: "https://inkscape.org/")!,
                  note: "Vector illustrator (Illustrator replacement). GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:graphics:krita",
                  origin: .europeAndOSS,
                  name: "Krita",
                  homepage: URL(string: "https://krita.org/")!,
                  note: "Digital painting + illustration. KDE community, GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Utilities
        "utilities": [
            .init(id: "champion:util:rectangle",
                  origin: .oss,
                  name: "Rectangle",
                  homepage: URL(string: "https://rectangleapp.com/")!,
                  note: "Window manager (Magnet replacement). MIT.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:util:alttab",
                  origin: .oss,
                  name: "AltTab",
                  homepage: URL(string: "https://alt-tab-macos.netlify.app/")!,
                  note: "Windows-style ⌘Tab with previews. GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:util:keepassxc",
                  origin: .europeAndOSS,
                  name: "KeePassXC",
                  homepage: URL(string: "https://keepassxc.org/")!,
                  note: "Local-only password manager. GPL.",
                  downloadURL: URL(string: "https://github.com/keepassxreboot/keepassxc/releases/latest/download/KeePassXC-latest-arm64.dmg"),
                  deliveryKind: .versionEmbedded),
        ],

        // MARK: Video
        "video": [
            .init(id: "champion:video:handbrake",
                  origin: .oss,
                  name: "HandBrake",
                  homepage: URL(string: "https://handbrake.fr/")!,
                  note: "Video transcoder. GPL.",
                  downloadURL: URL(string: "https://github.com/HandBrake/HandBrake/releases/latest/download/HandBrake-latest-arm64.dmg"),
                  deliveryKind: .versionEmbedded),
            .init(id: "champion:video:obs",
                  origin: .oss,
                  name: "OBS Studio",
                  homepage: URL(string: "https://obsproject.com/")!,
                  note: "Streaming + recording. GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:video:resolve",
                  origin: .other,
                  name: "DaVinci Resolve",
                  homepage: URL(string: "https://www.blackmagicdesign.com/products/davinciresolve")!,
                  note: "Pro video editor. Free tier covers most use cases.",
                  downloadURL: nil,
                  deliveryKind: .signupRequired),
        ],

        // MARK: Music
        "music": [
            .init(id: "champion:music:audacity",
                  origin: .oss,
                  name: "Audacity",
                  homepage: URL(string: "https://www.audacityteam.org/")!,
                  note: "Multi-track audio editor. GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:music:strawberry",
                  origin: .europeAndOSS,
                  name: "Strawberry",
                  homepage: URL(string: "https://www.strawberrymusicplayer.org/")!,
                  note: "Music player + library manager. GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Photography
        "photography": [
            .init(id: "champion:photo:darktable",
                  origin: .europeAndOSS,
                  name: "darktable",
                  homepage: URL(string: "https://www.darktable.org/")!,
                  note: "Lightroom replacement (RAW workflow). GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:photo:rawtherapee",
                  origin: .europeAndOSS,
                  name: "RawTherapee",
                  homepage: URL(string: "https://www.rawtherapee.com/")!,
                  note: "RAW processor. GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:photo:gimp",
                  origin: .europeAndOSS,
                  name: "GIMP",
                  homepage: URL(string: "https://www.gimp.org/")!,
                  note: "Pixel editor (Photoshop replacement). GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Entertainment
        "entertainment": [
            .init(id: "champion:ent:vlc",
                  origin: .europeAndOSS,
                  name: "VLC",
                  homepage: URL(string: "https://www.videolan.org/vlc/")!,
                  note: "Universal media player. VideoLAN (FR), GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:ent:mpv",
                  origin: .oss,
                  name: "mpv (via IINA)",
                  homepage: URL(string: "https://iina.io/")!,
                  note: "Modern Mac player built on mpv. GPL.",
                  downloadURL: URL(string: "https://github.com/iina/iina/releases/latest/download/IINA.dmg"),
                  deliveryKind: .versionEmbedded),
        ],

        // MARK: Social Networking
        "social-networking": [
            .init(id: "champion:social:signal",
                  origin: .oss,
                  name: "Signal",
                  homepage: URL(string: "https://signal.org/")!,
                  note: "End-to-end encrypted messenger. GPL/AGPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
            .init(id: "champion:social:element",
                  origin: .europeAndOSS,
                  name: "Element",
                  homepage: URL(string: "https://element.io/")!,
                  note: "Matrix client for federated chat. Apache.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: News
        "news": [
            .init(id: "champion:news:netnewswire",
                  origin: .oss,
                  name: "NetNewsWire",
                  homepage: URL(string: "https://netnewswire.com/")!,
                  note: "RSS reader. MIT.",
                  downloadURL: URL(string: "https://github.com/Ranchero-Software/NetNewsWire/releases/latest/download/NetNewsWire6.1.4.zip"),
                  deliveryKind: .versionEmbedded),
        ],

        // MARK: Reference
        "reference": [
            .init(id: "champion:ref:zotero",
                  origin: .europeAndOSS,
                  name: "Zotero",
                  homepage: URL(string: "https://www.zotero.org/")!,
                  note: "Reference manager. AGPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Education
        "education": [
            .init(id: "champion:edu:anki",
                  origin: .oss,
                  name: "Anki",
                  homepage: URL(string: "https://apps.ankiweb.net/")!,
                  note: "Spaced-repetition flashcards. AGPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Finance
        "finance": [
            .init(id: "champion:finance:gnucash",
                  origin: .oss,
                  name: "GnuCash",
                  homepage: URL(string: "https://www.gnucash.org/")!,
                  note: "Personal + small-business accounting. GPL.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],

        // MARK: Healthcare & Fitness
        "healthcare-fitness": [
            .init(id: "champion:health:gadgetbridge",
                  origin: .europeAndOSS,
                  name: "Gadgetbridge (companion)",
                  homepage: URL(string: "https://gadgetbridge.org/")!,
                  note: "Fitness tracker without vendor cloud. GPL (mobile-first).",
                  downloadURL: nil,
                  deliveryKind: .webService),
        ],

        // MARK: Travel / Maps
        "travel": [
            .init(id: "champion:travel:organicmaps",
                  origin: .europeAndOSS,
                  name: "Organic Maps",
                  homepage: URL(string: "https://organicmaps.app/")!,
                  note: "OpenStreetMap-based offline maps. Apache.",
                  downloadURL: nil,
                  deliveryKind: .directDownload),
        ],
    ]
}
