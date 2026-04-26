// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Source:     Scripts/trust-catalog.json
// Generator:  swift Scripts/regenerate-trust-catalog.swift
// Count:      30 Trust profiles
//
// To add or update entries, edit the JSON source and regenerate.
// EVERY concern MUST cite a primary source (Apple App Store
// privacy label, EU DPA / FTC / SEC ruling, NVD CVE, HIBP
// breach, or vendor security advisory).  See TRUST-CONTRIBUTING.md.

import Foundation

extension TrustCatalog {

    /// The full Trust catalog — generated from Scripts/trust-catalog.json.
    static let entries: [Entry] = [
        Entry(
            targetBundleID: "com.google.Chrome",
            targetDisplayName: "Google Chrome",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "chrome:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: contact info, identifiers, usage data, and search history linked across apps and websites.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/google-chrome/id535886823")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
                Concern(
                    id: "chrome:ftc-cookie-consent",
                    kind: .regulatoryFineFTC,
                    axis: .trust,
                    severity: .high,
                    summary: "Google paid $391.5M to 40 US state attorneys general in 2022 over location-tracking practices in Chrome and other products.",
                    evidenceURL: URL(string: "https://www.oag.ca.gov/news/press-releases/attorney-general-bonta-announces-multistate-3915-million-settlement-google")!,
                    evidenceDate: "2022-11-14",
                    sourceName: "California AG"
                ),
                Concern(
                    id: "chrome:cnil-fine-2022",
                    kind: .regulatoryFineGDPR,
                    axis: .trust,
                    severity: .high,
                    summary: "CNIL fined Google €150M in 2022 for cookie-consent UX in Chrome that made refusing cookies harder than accepting.",
                    evidenceURL: URL(string: "https://www.cnil.fr/en/cookies-cnil-fines-google-total-150-million-euros-and-facebook-60-million-euros-non-compliance")!,
                    evidenceDate: "2022-01-06",
                    sourceName: "CNIL"
                ),
            ],
            fallbackAlternatives: [
                FallbackAlternative(
                    id: "chrome:safari",
                    name: "Safari",
                    homepage: URL(string: "https://www.apple.com/safari/")!,
                    note: "Apple-built; on-device intelligence; default browser."
                ),
            ]),
        Entry(
            targetBundleID: "com.microsoft.edgemac",
            targetDisplayName: "Microsoft Edge",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "edge:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: contact info, identifiers, usage data, browsing history, search history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/microsoft-edge-ai-browser/id1288723196")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
                FallbackAlternative(
                    id: "edge:safari",
                    name: "Safari",
                    homepage: URL(string: "https://www.apple.com/safari/")!,
                    note: "Apple-built; default macOS browser; no cross-app tracking on Apple ID."
                ),
            ]),
        Entry(
            targetBundleID: "com.facebook.archon.developerID",
            targetDisplayName: "Messenger",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "messenger:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .severe,
                    summary: "App Store privacy label discloses tracking across other companies' apps and websites: identifiers, usage, location, contact info, purchases.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/messenger/id454638411")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
                Concern(
                    id: "messenger:dpc-ireland-2023",
                    kind: .regulatoryFineGDPR,
                    axis: .trust,
                    severity: .severe,
                    summary: "Ireland's DPC fined Meta €1.2B in 2023 for unlawful EU-to-US data transfers — largest GDPR fine to date.",
                    evidenceURL: URL(string: "https://www.dataprotection.ie/en/news-media/press-releases/Data-Protection-Commission-announces-conclusion-of-inquiry-into-Meta-Ireland")!,
                    evidenceDate: "2023-05-22",
                    sourceName: "Irish DPC"
                ),
                Concern(
                    id: "messenger:ftc-2019",
                    kind: .regulatoryFineFTC,
                    axis: .trust,
                    severity: .severe,
                    summary: "FTC imposed a $5B fine on Facebook (now Meta) in 2019 over privacy violations including Cambridge Analytica.",
                    evidenceURL: URL(string: "https://www.ftc.gov/news-events/news/press-releases/2019/07/ftc-imposes-5-billion-penalty-sweeping-new-privacy-restrictions-facebook")!,
                    evidenceDate: "2019-07-24",
                    sourceName: "FTC"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.whatsapp.WhatsApp",
            targetDisplayName: "WhatsApp",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "whatsapp:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: device ID, advertising data, usage data, purchase history, contact info, location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/whatsapp-messenger/id310633997")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
                Concern(
                    id: "whatsapp:dpc-ireland-2021",
                    kind: .regulatoryFineGDPR,
                    axis: .trust,
                    severity: .high,
                    summary: "Ireland's DPC fined WhatsApp €225M in 2021 for transparency failures under GDPR Article 13 and 14.",
                    evidenceURL: URL(string: "https://www.dataprotection.ie/en/news-media/press-releases/data-protection-commission-announces-decision-whatsapp-inquiry")!,
                    evidenceDate: "2021-09-02",
                    sourceName: "Irish DPC"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.tinyspeck.slackmacgap",
            targetDisplayName: "Slack",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "slack:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label discloses linked data: contact info, identifiers, usage data, diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/slack/id803453959")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
                Concern(
                    id: "slack:breach-2022",
                    kind: .dataBreachConfirmed,
                    axis: .security,
                    severity: .moderate,
                    summary: "Confirmed breach in 2022: source-code repository access via stolen employee tokens. No customer data accessed per Slack's disclosure.",
                    evidenceURL: URL(string: "https://slack.com/blog/news/slack-security-update")!,
                    evidenceDate: "2022-12-31",
                    sourceName: "Slack security advisory"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "us.zoom.xos",
            targetDisplayName: "Zoom",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "zoom:ftc-2020",
                    kind: .regulatoryFineFTC,
                    axis: .trust,
                    severity: .high,
                    summary: "FTC settlement in 2020: Zoom misled users about end-to-end encryption and installed software circumventing browser security.",
                    evidenceURL: URL(string: "https://www.ftc.gov/news-events/news/press-releases/2020/11/ftc-requires-zoom-enhance-its-security-practices-part-settlement")!,
                    evidenceDate: "2020-11-09",
                    sourceName: "FTC"
                ),
                Concern(
                    id: "zoom:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, contact info, usage data, audio data, financial info.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/zoom-workplace/id546505307")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.microsoft.teams",
            targetDisplayName: "Microsoft Teams",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "teams:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, contact info, contacts, usage data, diagnostics, audio data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/microsoft-teams/id1113153706")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.hnc.Discord",
            targetDisplayName: "Discord",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "discord:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses tracking data: identifiers and usage data used to track across other companies' apps and websites.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/discord-chat-talk-hangout/id985746746")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.getdropbox.dropbox",
            targetDisplayName: "Dropbox",
            lastReviewed: "2026-04-26",
            concerns: [
                Concern(
                    id: "dropbox:breach-2012",
                    kind: .dataBreachConfirmed,
                    axis: .security,
                    severity: .high,
                    summary: "Confirmed breach in 2012 affecting 68M users; credentials including hashed passwords exposed. Indexed by HIBP.",
                    evidenceURL: URL(string: "https://haveibeenpwned.com/PwnedWebsites#Dropbox")!,
                    evidenceDate: "2012-07-01",
                    sourceName: "HIBP"
                ),
                Concern(
                    id: "dropbox:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, usage data, contact info, financial info, contacts, location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/dropbox/id327630330")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.lastpass.LastPass",
            targetDisplayName: "LastPass",
            lastReviewed: "2026-04-26",
            concerns: [
                Concern(
                    id: "lastpass:breach-2022",
                    kind: .dataBreachConfirmed,
                    axis: .security,
                    severity: .severe,
                    summary: "Confirmed breach in 2022: encrypted password vaults exfiltrated. Vendor confirmed in formal disclosure.",
                    evidenceURL: URL(string: "https://blog.lastpass.com/posts/notice-of-recent-security-incident")!,
                    evidenceDate: "2022-12-22",
                    sourceName: "LastPass security advisory"
                ),
                Concern(
                    id: "lastpass:hibp",
                    kind: .dataBreachConfirmed,
                    axis: .security,
                    severity: .high,
                    summary: "HIBP indexed multiple LastPass-related breaches involving customer-vault metadata and source-code access.",
                    evidenceURL: URL(string: "https://haveibeenpwned.com/PwnedWebsites#LastPass")!,
                    evidenceDate: "2022-12-22",
                    sourceName: "HIBP"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.zhiliaoapp.musically",
            targetDisplayName: "TikTok",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "tiktok:dpc-ireland-2023",
                    kind: .regulatoryFineGDPR,
                    axis: .trust,
                    severity: .severe,
                    summary: "Irish DPC fined TikTok €345M in 2023 over child-data processing — public-by-default settings and improper handling of child data.",
                    evidenceURL: URL(string: "https://www.dataprotection.ie/en/news-media/press-releases/data-protection-commission-announces-345-million-euro-fine-of-tiktok")!,
                    evidenceDate: "2023-09-15",
                    sourceName: "Irish DPC"
                ),
                Concern(
                    id: "tiktok:dpc-ireland-2025",
                    kind: .regulatoryFineGDPR,
                    axis: .trust,
                    severity: .severe,
                    summary: "Irish DPC fined TikTok €530M in 2025 for unlawful EEA-to-China data transfers and transparency failures.",
                    evidenceURL: URL(string: "https://www.dataprotection.ie/en/news-media/press-releases/data-protection-commission-announces-decision-tiktok-inquiry")!,
                    evidenceDate: "2025-05-02",
                    sourceName: "Irish DPC"
                ),
                Concern(
                    id: "tiktok:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, location, browsing history, purchases used to track across apps and websites.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/tiktok/id835599320")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.tencent.xinWeChat",
            targetDisplayName: "WeChat",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "wechat:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking and linked data: identifiers, contact info, usage data, contacts.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/wechat/id414478124")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "ru.yandex.desktop.yandex-browser",
            targetDisplayName: "Yandex Browser",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "yandex:ofac",
                    kind: .governmentSanction,
                    axis: .trust,
                    severity: .severe,
                    summary: "US OFAC has sanctioned multiple Russian-affiliated entities since 2022; Yandex was split in 2024 with Russian operations under sanctions risk.",
                    evidenceURL: URL(string: "https://ofac.treasury.gov/recent-actions")!,
                    evidenceDate: "2024-02-23",
                    sourceName: "US OFAC"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.kaspersky.kes",
            targetDisplayName: "Kaspersky Endpoint Security",
            lastReviewed: "2026-04-26",
            concerns: [
                Concern(
                    id: "kaspersky:cisa-2017",
                    kind: .governmentSanction,
                    axis: .trust,
                    severity: .severe,
                    summary: "US CISA Binding Operational Directive 17-01 (2017) ordered removal of Kaspersky products from federal systems; expanded by Commerce Dept ban in 2024.",
                    evidenceURL: URL(string: "https://www.cisa.gov/news-events/directives/bod-17-01-removal-kaspersky-branded-products")!,
                    evidenceDate: "2017-09-13",
                    sourceName: "US CISA"
                ),
                Concern(
                    id: "kaspersky:bis-2024-final-determination",
                    kind: .governmentSanction,
                    axis: .trust,
                    severity: .severe,
                    summary: "Federal Register Final Determination 2024-13869 (BIS): prohibits Kaspersky software sales in the US effective September 29, 2024.",
                    evidenceURL: URL(string: "https://www.federalregister.gov/documents/2024/06/24/2024-13869/securing-the-information-and-communications-technology-and-services-supply-chain-final-determination")!,
                    evidenceDate: "2024-06-24",
                    sourceName: "Federal Register"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.adobe.acc.AdobeCreativeCloud",
            targetDisplayName: "Adobe Creative Cloud",
            lastReviewed: "2026-04-26",
            concerns: [
                Concern(
                    id: "adobe:breach-2013",
                    kind: .dataBreachConfirmed,
                    axis: .security,
                    severity: .high,
                    summary: "Confirmed 2013 breach affecting 153M user records: usernames, encrypted passwords, hint plaintexts. Indexed by HIBP.",
                    evidenceURL: URL(string: "https://haveibeenpwned.com/PwnedWebsites#Adobe")!,
                    evidenceDate: "2013-10-04",
                    sourceName: "HIBP"
                ),
                Concern(
                    id: "adobe:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label discloses linked data: identifiers, usage data, contact info, purchases, diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/adobe-creative-cloud/id1481430488")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.adobe.Acrobat.Pro",
            targetDisplayName: "Adobe Acrobat Pro",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "acrobat:cve-2024-recurring",
                    kind: .vendorSecurityAdvisory,
                    axis: .security,
                    severity: .high,
                    summary: "Adobe issued multiple Acrobat security bulletins in 2024 patching critical RCE CVEs (e.g. APSB24-29, APSB24-86).",
                    evidenceURL: URL(string: "https://helpx.adobe.com/security.html")!,
                    evidenceDate: "2024-12-10",
                    sourceName: "Adobe Security Bulletin"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.notion.id",
            targetDisplayName: "Notion",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "notion:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label discloses linked data: identifiers, usage data, contact info, diagnostics, user content.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/notion-notes-docs-tasks/id1232780281")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.evernote.Evernote",
            targetDisplayName: "Evernote",
            lastReviewed: "2026-04-26",
            concerns: [
                Concern(
                    id: "evernote:breach-2013",
                    kind: .dataBreachConfirmed,
                    axis: .security,
                    severity: .moderate,
                    summary: "Confirmed 2013 breach: usernames, hashed passwords, email addresses for 50M users exposed. Indexed by HIBP.",
                    evidenceURL: URL(string: "https://haveibeenpwned.com/PwnedWebsites#Evernote")!,
                    evidenceDate: "2013-03-02",
                    sourceName: "HIBP"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.microsoft.OneDrive",
            targetDisplayName: "Microsoft OneDrive",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "onedrive:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, location, contact info, contacts, user content, diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/microsoft-onedrive/id823766827")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.google.drivefs",
            targetDisplayName: "Google Drive",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "gdrive:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, location, contact info, usage data, search history, user content.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/google-drive/id507874739")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.openai.chat",
            targetDisplayName: "ChatGPT Desktop",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "chatgpt:garante-2023",
                    kind: .regulatoryFineGDPR,
                    axis: .trust,
                    severity: .high,
                    summary: "Italy's Garante temporarily banned ChatGPT in 2023 over GDPR concerns; OpenAI fined €15M in 2024.",
                    evidenceURL: URL(string: "https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/10085455")!,
                    evidenceDate: "2024-12-20",
                    sourceName: "Garante per la protezione dei dati personali"
                ),
                Concern(
                    id: "chatgpt:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, contact info, usage data, user content.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/chatgpt/id6448311069")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.spotify.client",
            targetDisplayName: "Spotify",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "spotify:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label discloses tracking data: identifiers and usage data used to track across other companies' apps and websites.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/spotify-music-and-podcasts/id324684580")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.todesktop.230313mzl4w4u92",
            targetDisplayName: "Cursor",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "cursor:business-model",
                    kind: .telemetryDefaultOn,
                    axis: .businessModel,
                    severity: .low,
                    summary: "Cursor's privacy policy discloses default-on telemetry; Privacy Mode toggle exists but is opt-in.",
                    evidenceURL: URL(string: "https://cursor.com/privacy")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Cursor privacy policy"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.grammarly.ProjectLlama",
            targetDisplayName: "Grammarly",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "grammarly:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, contact info, usage data, user content, diagnostics, search history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/grammarly-grammar-keyboard/id1462114288")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.airtable.airtable",
            targetDisplayName: "Airtable",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "airtable:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label discloses linked data: identifiers, usage data, contact info, contacts, user content, diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/airtable/id914172636")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.dashlane.dashlanephonefinal",
            targetDisplayName: "Dashlane",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "dashlane:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label discloses linked data: identifiers, usage data, contact info, financial info, search history, diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/dashlane-password-manager/id517914548")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.linear",
            targetDisplayName: "Linear",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "linear:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label discloses linked data: identifiers, usage data, contact info, user content.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/linear/id1500768148")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.amazon.Kindle",
            targetDisplayName: "Amazon Kindle",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "kindle:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, location, contact info, usage data, browsing history, purchases, search history, diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/amazon-kindle/id302584613")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.amazon.music.mac",
            targetDisplayName: "Amazon Music",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "amazon-music:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label discloses linked data: identifiers, location, contact info, usage data, purchases, diagnostics, audio data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/amazon-music-songs-podcasts/id510855668")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.netflix.Netflix",
            targetDisplayName: "Netflix",
            lastReviewed: "2026-04-25",
            concerns: [
                Concern(
                    id: "netflix:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label discloses linked data: identifiers, usage data, financial info, contact info, diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/netflix/id363590051")!,
                    evidenceDate: "2025-09-15",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
    ]
}
