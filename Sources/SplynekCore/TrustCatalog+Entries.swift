// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Source:     Scripts/trust-catalog.json
// Generator:  swift Scripts/regenerate-trust-catalog.swift
// Count:      101 Trust profiles
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
            targetBundleID: "com.adobe.LightroomCC",
            targetDisplayName: "Adobe Lightroom",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "adobe-lightroom:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 8 categories including Contacts, Sensitive Info, User Content.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id878783582")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.adobe.Photoshop",
            targetDisplayName: "Adobe Photoshop",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "adobe-photoshop:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 7 categories including User Content, Identifiers, and Usage Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1457771281")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
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
            targetBundleID: "com.airbnb.app",
            targetDisplayName: "Airbnb",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "airbnb:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, advertising data, usage data, location, contact info.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id401626263")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.alibaba.iAliexpress",
            targetDisplayName: "AliExpress",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "aliexpress:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 12 categories including Financial Info, Contact Info, precise Location, Health & Fitness.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id436672029")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.amazon.Amazon",
            targetDisplayName: "Amazon Shopping",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "amazon-shopping:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, purchase history, advertising data, usage data, search history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id297606951")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.asana.iPhone",
            targetDisplayName: "Asana",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "asana:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 7 categories including Contact Info, User Content, Identifiers, Usage Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id489969512")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.atebits.Tweetie2",
            targetDisplayName: "X (Twitter)",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "twitter-x:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, location, search history, usage data, browsing history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id333903271")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.bofa.bofa",
            targetDisplayName: "Bank of America Mobile",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "bofa:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 11 categories including Financial Info, Sensitive Info, Health & Fitness, Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id284847138")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.booking.bookingapp",
            targetDisplayName: "Booking.com",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "booking:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 9 categories including Financial Info, Contact Info, precise Location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id367003839")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.brave.ios.browser",
            targetDisplayName: "Brave Browser (iOS)",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "brave-ios:appstore-unlinked",
                    kind: .appStoreUnlinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label declares only Unlinked Data: Diagnostics — privacy-first browser brand reflected in minimal data collection.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1052879175")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.bumble.app",
            targetDisplayName: "Bumble",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "bumble:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 12 categories including precise Location, Sensitive Info, Health & Fitness, Photos.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id930441707")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.burbn.barcelona",
            targetDisplayName: "Threads",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "threads:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses extensive tracking, mirroring Instagram's profile across identifiers, browsing history, location, and purchase history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id6446901002")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.burbn.instagram",
            targetDisplayName: "Instagram",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "instagram:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses extensive tracking: identifiers, location, contacts, browsing history, advertising data, search history, purchase history. Linked Data across 19 categories — Health & Fitness, Sensitive Info, Financial Info included.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id389801252")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.calm.calmapp",
            targetDisplayName: "Calm",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "calm:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 10 categories including Health & Fitness, Audio Data, Financial Info.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id571800810")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.cardify.tinder",
            targetDisplayName: "Tinder",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "tinder:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 13 categories including precise Location, Sensitive Info, Health & Fitness, Photos, Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id547702041")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.chase.sig.Chase",
            targetDisplayName: "Chase Mobile",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "chase:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 12 categories including Financial Info, Sensitive Info, Identifiers, Contact Info, Diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id298867247")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.contextlogic.wishweb",
            targetDisplayName: "Wish",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "wish:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 10 categories including Financial Info, precise Location, Contacts.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id510016022")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.crunchyroll.iphone",
            targetDisplayName: "Crunchyroll",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "crunchyroll:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, advertising data, usage data, purchase history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id329913454")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.culturedcode.ThingsMac",
            targetDisplayName: "Things 3",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "things3:appstore-unlinked",
                    kind: .appStoreUnlinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label declares only Unlinked Data: Diagnostics — minimal collection consistent with the indie productivity ethos.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id904280696")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.dd.doordash",
            targetDisplayName: "DoorDash",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "doordash:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 12 categories including Financial Info, precise Location, Contacts.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id719972451")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.disney.disneyplus",
            targetDisplayName: "Disney+",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "disney-plus:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 9 categories including Purchase History, Search History, and Usage Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1446075923")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.duolingo.DuolingoMobile",
            targetDisplayName: "Duolingo",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "duolingo:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking: identifiers, advertising data, usage data, purchase history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id570060128")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.ebay.iphone",
            targetDisplayName: "eBay",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "ebay:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, contact info, search history, usage data, advertising data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id282614216")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.einnovation.temu",
            targetDisplayName: "Temu",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "temu:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 13 categories including Financial Info, Contact Info, Photos, Contacts, precise Location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1641486558")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.etsy.etsyforiphone",
            targetDisplayName: "Etsy",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "etsy:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 9 categories including Financial Info, Contact Info, Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id477128284")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.expedia.bookings",
            targetDisplayName: "Expedia",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "expedia:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 10 categories including Financial Info, Contact Info, Location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id427916203")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
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
            targetBundleID: "com.flexibits.fantastical2.mac",
            targetDisplayName: "Fantastical",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "fantastical:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 4 categories including Contact Info, Identifiers, Usage Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id975937182")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.fogcreek.trello",
            targetDisplayName: "Trello",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "trello:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 8 categories including Contact Info, User Content, Identifiers, Diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id461504587")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.getsomeheadspace.headspaceapp",
            targetDisplayName: "Headspace",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "headspace:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 11 categories including Health & Fitness, Sensitive Info, Audio Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id493145008")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
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
            targetBundleID: "com.google.Docs",
            targetDisplayName: "Google Docs",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "google-docs:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 7 categories including Contacts, User Content, Identifiers, Usage Data, Diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id842842640")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.google.Maps",
            targetDisplayName: "Google Maps",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "google-maps:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, location, search history, browsing history, advertising data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id585027354")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.google.Sheets",
            targetDisplayName: "Google Sheets",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "google-sheets:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 7 categories including Contacts, User Content, Identifiers, Usage Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id842849113")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.google.Translate",
            targetDisplayName: "Google Translate",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "google-translate:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 6 categories including User Content, Identifiers, Usage Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id414706506")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.google.ios.youtube",
            targetDisplayName: "YouTube",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "youtube:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking: identifiers, location, contacts, search history, advertising data, browsing history, purchase history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id544007664")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.google.ios.youtubemusic",
            targetDisplayName: "YouTube Music",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "youtube-music:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking: identifiers, location, search history, advertising data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1017492454")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
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
            targetBundleID: "com.grindrllc.grindr",
            targetDisplayName: "Grindr",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "grindr:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 13 categories including precise Location, Sensitive Info (sexual orientation), Health & Fitness, Photos.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id319881193")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.hbo.hbonow",
            targetDisplayName: "Max (formerly HBO Max)",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "hbo-max:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 11 categories including Health & Fitness, Sensitive Info, and Browsing History.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id971265416")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.hinge.app",
            targetDisplayName: "Hinge",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "hinge:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 11 categories including precise Location, Sensitive Info, Photos, Audio Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id595287172")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.hotels.HotelsNearMeApp",
            targetDisplayName: "Hotels.com",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "hotels-com:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 9 categories including Financial Info, Contact Info, Location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id314005278")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.hulu.plus",
            targetDisplayName: "Hulu",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "hulu:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, advertising data, usage data, location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id376510438")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.instacart.InstacartShopper",
            targetDisplayName: "Instacart",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "instacart:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 11 categories including Financial Info, precise Location, Contacts.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id545599256")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
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
            targetBundleID: "com.linkedin.LinkedIn",
            targetDisplayName: "LinkedIn",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "linkedin:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking across other apps and websites: identifiers, contact info, usage data, browsing history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id288429040")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
                Concern(
                    id: "linkedin:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares 'Data Linked to You' across 13 categories including Contacts, Financial Info, and Sensitive Info.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id288429040")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.lyft.iphone",
            targetDisplayName: "Lyft",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "lyft:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 12 categories including Sensitive Info, Health & Fitness, Financial Info, precise Location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id529379082")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.microsoft.Excel",
            targetDisplayName: "Microsoft Excel",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "ms-excel:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 13 categories including Contacts, User Content, and Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id586683407")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
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
            targetBundleID: "com.microsoft.Outlook",
            targetDisplayName: "Microsoft Outlook",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "ms-outlook:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 13 categories including Contacts, Email Address, Search History, and Sensitive Info.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id951937596")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.microsoft.Powerpoint",
            targetDisplayName: "Microsoft PowerPoint",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "ms-powerpoint:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 13 categories including Contacts, User Content, and Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id586449534")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.microsoft.Word",
            targetDisplayName: "Microsoft Word",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "ms-word:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 13 categories including Contacts, User Content, and Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id586447913")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
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
            targetBundleID: "com.mindnode.MindNode8",
            targetDisplayName: "MindNode",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "mindnode:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data including Contact Info, User Content, Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1289197285")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.operasoftware.OperaMini",
            targetDisplayName: "Opera",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "opera-mini:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking: identifiers, advertising data, usage data, search history, browsing history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id363729560")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.pandora",
            targetDisplayName: "Pandora",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "pandora:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, location, advertising data, usage data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id284035177")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.paypal.PPClient",
            targetDisplayName: "PayPal",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "paypal:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 9 categories including Financial Info, Sensitive Info, Contacts, and Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id283646709")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.pinterest.pinterest",
            targetDisplayName: "Pinterest",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "pinterest:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking: identifiers, contacts, location, usage data, search history, browsing history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id429047995")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.pixelmatorteam.pixelmator.x",
            targetDisplayName: "Pixelmator Pro",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "pixelmator-pro:appstore-unlinked",
                    kind: .appStoreUnlinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label declares only Unlinked Data: Identifiers, Usage Data — typical for paid creative-tool apps.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1289583905")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.plexapp.plex",
            targetDisplayName: "Plex",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "plex:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 8 categories including Search History, Identifiers, and Diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id383457673")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.reddit.Reddit",
            targetDisplayName: "Reddit",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "reddit:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, location, usage data, advertising data, browsing history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1064216828")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.robinhood.release.Robinhood",
            targetDisplayName: "Robinhood",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "robinhood:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 9 categories including Financial Info, Sensitive Info, Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id938003185")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.shein.app",
            targetDisplayName: "SHEIN",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "shein:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 11 categories including Financial Info, Contact Info, Identifiers, Usage Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id878577184")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.skype.skype",
            targetDisplayName: "Skype",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "skype:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 11 categories including Contacts, Health & Fitness, and Sensitive Info.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id304878510")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.squareup.cash",
            targetDisplayName: "Cash App",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "cashapp:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 8 categories including Financial Info, Contacts, Sensitive Info, Location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id711923939")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.strava.stravaride",
            targetDisplayName: "Strava",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "strava:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 12 categories including precise Location, Health & Fitness, Sensitive Info, Contacts.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id426826309")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "com.tidal.iPhone",
            targetDisplayName: "Tidal",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "tidal:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 9 categories including Financial Info, Contact Info, Audio Data, Usage Data.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id913943275")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
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
            targetBundleID: "com.toyopagroup.picaboo",
            targetDisplayName: "Snapchat",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "snapchat:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, usage data, advertising data, search history, location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id447188370")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.ubercab.UberClient",
            targetDisplayName: "Uber",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "uber:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 12 categories including Health & Fitness, Sensitive Info, Financial Info, and precise Location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id368677368")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.ubercab.UberEats",
            targetDisplayName: "Uber Eats",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "uber-eats:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking + Linked Data across 11 categories including Financial Info, precise Location, Contacts, Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id1058959277")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.valvesoftware.steam",
            targetDisplayName: "Steam",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "steam:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label (Steam Mobile) declares Linked Data across 4 categories including Identifiers, Purchase History, Diagnostics.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id495369748")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.venmo.Venmo",
            targetDisplayName: "Venmo",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "venmo:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking and Linked Data across categories including Financial Info, Identifiers, Purchase History, Location.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id351727428")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "com.wf.WellsFargoMobile",
            targetDisplayName: "Wells Fargo Mobile",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "wellsfargo:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 11 categories including Financial Info, Sensitive Info, Identifiers.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id311548709")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
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
            targetBundleID: "org.mozilla.ios.Firefox",
            targetDisplayName: "Firefox (iOS)",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "firefox-ios:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data: Identifiers, Usage Data, Diagnostics — moderate collection for a browser.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id989804926")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "org.whispersystems.signal",
            targetDisplayName: "Signal (iOS)",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "signal-ios:appstore-unlinked",
                    kind: .appStoreUnlinkedData,
                    axis: .privacy,
                    severity: .low,
                    summary: "App Store privacy label declares ONLY Unlinked Data: Contact Info — Signal's privacy posture is famously minimal; the only data collected is the phone number used to register, not linked to user identity.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id874139669")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
                ),
            ],
            fallbackAlternatives: [
            ]),
        Entry(
            targetBundleID: "ph.telegra.Telegraph",
            targetDisplayName: "Telegram",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "telegram:appstore-linked",
                    kind: .appStoreLinkedData,
                    axis: .privacy,
                    severity: .moderate,
                    summary: "App Store privacy label declares Linked Data across 4 categories: Contact Info, Contacts, Identifiers, User Content.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id686449807")!,
                    evidenceDate: "2026-04-30",
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
            targetBundleID: "tv.twitch",
            targetDisplayName: "Twitch",
            lastReviewed: "2026-04-30",
            concerns: [
                Concern(
                    id: "twitch:appstore-tracking",
                    kind: .appStoreTrackingData,
                    axis: .privacy,
                    severity: .high,
                    summary: "App Store privacy label discloses tracking data: identifiers, advertising data, usage data, location, search history.",
                    evidenceURL: URL(string: "https://apps.apple.com/us/app/id460177396")!,
                    evidenceDate: "2026-04-30",
                    sourceName: "Apple App Store"
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
    ]
}
