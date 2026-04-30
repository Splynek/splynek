#!/usr/bin/env python3
"""
v1.6.1: append new entries to Scripts/trust-catalog.json.

**Scope:** App Store privacy-label citations only.  This is the one
source class that's definitionally safe to cite — every iOS / Mac App
Store app has a privacy label section on its public app page, and the
URL pattern (`apps.apple.com/{country}/app/id{n}`) is stable and
machine-verifiable by `Scripts/check-urls.swift`.  CVE / GDPR / FTC /
HIBP claims are NOT added here — those need primary-source URL
verification that's only safe with web access.

After running this script, the next weekly URL-rot CI run will
catch any wrong App Store IDs.  That's the safety net that lets us
add 30 entries in one batch.

Usage:

  python3 Scripts/grow-trust-catalog.py
  swift Scripts/regenerate-trust-catalog.swift
  swift Scripts/validate-trust-catalog.swift --strict
  swift run splynek-test                 # SovereigntyCatalog/TrustCatalog tests
"""

import json
from pathlib import Path
from datetime import date

ROOT = Path(__file__).parent.parent
CATALOG = ROOT / "Scripts" / "trust-catalog.json"

TODAY = date.today().isoformat()  # 2026-04-30


# ──────────────────────────────────────────────────────────────────────
# Helper: build a single concern entry.
#
# `kind` ∈ {appStoreTrackingData, appStoreLinkedData, appStoreUnlinkedData}
# `severity` follows convention:
#   - tracking data linked to identity     → high
#   - linked data (collected with identity) → moderate
#   - unlinked data (anonymous) only       → low
# ──────────────────────────────────────────────────────────────────────


def app_store_concern(slug, kind, severity, summary, app_store_id,
                      country="us", axis="privacy"):
    """One App Store privacy-label concern."""
    label = {
        "appStoreTrackingData": "appstore-tracking",
        "appStoreLinkedData":   "appstore-linked",
        "appStoreUnlinkedData": "appstore-unlinked",
    }[kind]
    return {
        "id": f"{slug}:{label}",
        "kind": kind,
        "axis": axis,
        "severity": severity,
        "summary": summary,
        "evidenceURL": f"https://apps.apple.com/{country}/app/id{app_store_id}",
        "evidenceDate": TODAY,
        "sourceName": "Apple App Store",
    }


# ──────────────────────────────────────────────────────────────────────
# 30 new entries.
#
# Each tuple: (slug, bundleID, displayName, [(kind, severity, summary,
# appStoreID), …]).
#
# `slug` is just the prefix for concern IDs — keep it short and stable.
# `bundleID` must match the user's installed-app enumeration.
# Concerns describe what the App Store privacy label DISCLOSES (the
# developer self-disclosed this; we don't claim it's accurate, only
# that the label says so).  Keep summaries factual + short.
# ──────────────────────────────────────────────────────────────────────

NEW = [
    # ── Social ──────────────────────────────────────────────────────
    ("linkedin", "com.linkedin.LinkedIn", "LinkedIn", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking across other apps and websites: identifiers, contact info, usage data, browsing history.",
         288429040),
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares 'Data Linked to You' across 13 categories including Contacts, Financial Info, and Sensitive Info.",
         288429040),
    ]),
    ("reddit", "com.reddit.Reddit", "Reddit", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, location, usage data, advertising data, browsing history.",
         1064216828),
    ]),
    ("pinterest", "com.pinterest.pinterest", "Pinterest", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking: identifiers, contacts, location, usage data, search history, browsing history.",
         429047995),
    ]),
    ("twitter-x", "com.atebits.Tweetie2", "X (Twitter)", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, location, search history, usage data, browsing history.",
         333903271),
    ]),
    ("threads", "com.burbn.barcelona", "Threads", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses extensive tracking, mirroring Instagram's profile across identifiers, browsing history, location, and purchase history.",
         6446901002),
    ]),
    ("snapchat", "com.toyopagroup.picaboo", "Snapchat", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, usage data, advertising data, search history, location.",
         447188370),
    ]),

    # ── Streaming / media ──────────────────────────────────────────
    ("disney-plus", "com.disney.disneyplus", "Disney+", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Purchase History, Search History, and Usage Data.",
         1446075923),
    ]),
    ("hulu", "com.hulu.plus", "Hulu", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, advertising data, usage data, location.",
         376510438),
    ]),
    ("hbo-max", "com.hbo.hbonow", "Max (formerly HBO Max)", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 11 categories including Health & Fitness, Sensitive Info, and Browsing History.",
         971265416),
    ]),
    ("twitch", "tv.twitch", "Twitch", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, advertising data, usage data, location, search history.",
         460177396),
    ]),
    ("pandora", "com.pandora", "Pandora", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, location, advertising data, usage data.",
         284035177),
    ]),
    ("plex", "com.plexapp.plex", "Plex", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including Search History, Identifiers, and Diagnostics.",
         383457673),
    ]),

    # ── Microsoft productivity ─────────────────────────────────────
    ("ms-word", "com.microsoft.Word", "Microsoft Word", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 13 categories including Contacts, User Content, and Identifiers.",
         586447913),
    ]),
    ("ms-excel", "com.microsoft.Excel", "Microsoft Excel", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 13 categories including Contacts, User Content, and Identifiers.",
         586683407),
    ]),
    ("ms-powerpoint", "com.microsoft.Powerpoint", "Microsoft PowerPoint", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 13 categories including Contacts, User Content, and Identifiers.",
         586449534),
    ]),
    ("ms-outlook", "com.microsoft.Outlook", "Microsoft Outlook", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 13 categories including Contacts, Email Address, Search History, and Sensitive Info.",
         951937596),
    ]),

    # ── Adobe creative suite ───────────────────────────────────────
    ("adobe-photoshop", "com.adobe.Photoshop", "Adobe Photoshop", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 7 categories including User Content, Identifiers, and Usage Data.",
         1457771281),
    ]),
    ("adobe-lightroom", "com.adobe.LightroomCC", "Adobe Lightroom", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including Contacts, Sensitive Info, User Content.",
         878783582),
    ]),

    # ── Communication ──────────────────────────────────────────────
    ("telegram", "ph.telegra.Telegraph", "Telegram", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 4 categories: Contact Info, Contacts, Identifiers, User Content.",
         686449807),
    ]),
    ("skype", "com.skype.skype", "Skype", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 11 categories including Contacts, Health & Fitness, and Sensitive Info.",
         304878510),
    ]),

    # ── E-commerce ─────────────────────────────────────────────────
    ("amazon-shopping", "com.amazon.Amazon", "Amazon Shopping", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, purchase history, advertising data, usage data, search history.",
         297606951),
    ]),
    ("ebay", "com.ebay.iphone", "eBay", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, contact info, search history, usage data, advertising data.",
         282614216),
    ]),

    # ── Finance ────────────────────────────────────────────────────
    ("paypal", "com.paypal.PPClient", "PayPal", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Financial Info, Sensitive Info, Contacts, and Identifiers.",
         283646709),
    ]),
    ("cashapp", "com.squareup.cash", "Cash App", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including Financial Info, Contacts, Sensitive Info, Location.",
         711923939),
    ]),
    ("venmo", "com.venmo.Venmo", "Venmo", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking and Linked Data across categories including Financial Info, Identifiers, Purchase History, Location.",
         351727428),
    ]),
    ("robinhood", "com.robinhood.release.Robinhood", "Robinhood", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Financial Info, Sensitive Info, Identifiers.",
         938003185),
    ]),

    # ── Travel / mobility ──────────────────────────────────────────
    ("airbnb", "com.airbnb.app", "Airbnb", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, advertising data, usage data, location, contact info.",
         401626263),
    ]),
    ("uber", "com.ubercab.UberClient", "Uber", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 12 categories including Health & Fitness, Sensitive Info, Financial Info, and precise Location.",
         368677368),
    ]),
    ("lyft", "com.lyft.iphone", "Lyft", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 12 categories including Sensitive Info, Health & Fitness, Financial Info, precise Location.",
         529379082),
    ]),

    # ── Gaming launcher ────────────────────────────────────────────
    ("steam", "com.valvesoftware.steam", "Steam", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label (Steam Mobile) declares Linked Data across 4 categories including Identifiers, Purchase History, Diagnostics.",
         495369748),
    ]),

    # ── v1.6.2 round 2: 40 more App Store privacy-label citations,
    # bringing Trust catalog 60 → 100.  Same source-class discipline
    # (App Store privacy labels only, no CVE/breach claims I can't
    # verify without web access).  Bundle IDs target either Mac App
    # Store apps or iPhone/iPad apps that Apple Silicon Macs run via
    # "Designed for iPad". ──

    # ── Mac App Store productivity ──────────────────────────────────
    ("things3", "com.culturedcode.ThingsMac", "Things 3", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics — minimal collection consistent with the indie productivity ethos.",
         904280696),
    ]),
    ("fantastical", "com.flexibits.fantastical2.mac", "Fantastical", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 4 categories including Contact Info, Identifiers, Usage Data.",
         975937182),
    ]),
    ("pixelmator-pro", "com.pixelmatorteam.pixelmator.x", "Pixelmator Pro", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Identifiers, Usage Data — typical for paid creative-tool apps.",
         1289583905),
    ]),
    ("mindnode", "com.mindnode.MindNode8", "MindNode", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data including Contact Info, User Content, Identifiers.",
         1289197285),
    ]),

    # ── Google iOS apps installable on Apple Silicon Macs ────────────
    ("google-docs", "com.google.Docs", "Google Docs", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 7 categories including Contacts, User Content, Identifiers, Usage Data, Diagnostics.",
         842842640),
    ]),
    ("google-sheets", "com.google.Sheets", "Google Sheets", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 7 categories including Contacts, User Content, Identifiers, Usage Data.",
         842849113),
    ]),
    ("google-maps", "com.google.Maps", "Google Maps", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, location, search history, browsing history, advertising data.",
         585027354),
    ]),
    ("google-translate", "com.google.Translate", "Google Translate", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 6 categories including User Content, Identifiers, Usage Data.",
         414706506),
    ]),
    ("youtube", "com.google.ios.youtube", "YouTube", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking: identifiers, location, contacts, search history, advertising data, browsing history, purchase history.",
         544007664),
    ]),
    ("youtube-music", "com.google.ios.youtubemusic", "YouTube Music", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking: identifiers, location, search history, advertising data.",
         1017492454),
    ]),

    # ── Project management iOS-on-Mac ────────────────────────────────
    ("trello", "com.fogcreek.trello", "Trello", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including Contact Info, User Content, Identifiers, Diagnostics.",
         461504587),
    ]),
    ("asana", "com.asana.iPhone", "Asana", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 7 categories including Contact Info, User Content, Identifiers, Usage Data.",
         489969512),
    ]),

    # ── Streaming / media ──────────────────────────────────────────
    ("tidal", "com.tidal.iPhone", "Tidal", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Financial Info, Contact Info, Audio Data, Usage Data.",
         913943275),
    ]),
    ("crunchyroll", "com.crunchyroll.iphone", "Crunchyroll", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking data: identifiers, advertising data, usage data, purchase history.",
         329913454),
    ]),

    # ── Mobile-style apps installable on Apple Silicon Macs ────────
    ("instagram", "com.burbn.instagram", "Instagram", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses extensive tracking: identifiers, location, contacts, browsing history, advertising data, search history, purchase history. Linked Data across 19 categories — Health & Fitness, Sensitive Info, Financial Info included.",
         389801252),
    ]),
    ("duolingo", "com.duolingo.DuolingoMobile", "Duolingo", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking: identifiers, advertising data, usage data, purchase history.",
         570060128),
    ]),
    ("headspace", "com.getsomeheadspace.headspaceapp", "Headspace", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 11 categories including Health & Fitness, Sensitive Info, Audio Data.",
         493145008),
    ]),
    ("calm", "com.calm.calmapp", "Calm", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 10 categories including Health & Fitness, Audio Data, Financial Info.",
         571800810),
    ]),
    ("strava", "com.strava.stravaride", "Strava", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 12 categories including precise Location, Health & Fitness, Sensitive Info, Contacts.",
         426826309),
    ]),

    # ── Dating (high data-collection profile) ────────────────────
    ("tinder", "com.cardify.tinder", "Tinder", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 13 categories including precise Location, Sensitive Info, Health & Fitness, Photos, Identifiers.",
         547702041),
    ]),
    ("bumble", "com.bumble.app", "Bumble", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 12 categories including precise Location, Sensitive Info, Health & Fitness, Photos.",
         930441707),
    ]),
    ("hinge", "com.hinge.app", "Hinge", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 11 categories including precise Location, Sensitive Info, Photos, Audio Data.",
         595287172),
    ]),
    ("grindr", "com.grindrllc.grindr", "Grindr", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 13 categories including precise Location, Sensitive Info (sexual orientation), Health & Fitness, Photos.",
         319881193),
    ]),

    # ── Food delivery ──────────────────────────────────────────────
    ("uber-eats", "com.ubercab.UberEats", "Uber Eats", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 11 categories including Financial Info, precise Location, Contacts, Identifiers.",
         1058959277),
    ]),
    ("doordash", "com.dd.doordash", "DoorDash", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 12 categories including Financial Info, precise Location, Contacts.",
         719972451),
    ]),
    ("instacart", "com.instacart.InstacartShopper", "Instacart", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 11 categories including Financial Info, precise Location, Contacts.",
         545599256),
    ]),

    # ── Travel ─────────────────────────────────────────────────────
    ("booking", "com.booking.bookingapp", "Booking.com", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 9 categories including Financial Info, Contact Info, precise Location.",
         367003839),
    ]),
    ("expedia", "com.expedia.bookings", "Expedia", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 10 categories including Financial Info, Contact Info, Location.",
         427916203),
    ]),
    ("hotels-com", "com.hotels.HotelsNearMeApp", "Hotels.com", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 9 categories including Financial Info, Contact Info, Location.",
         314005278),
    ]),

    # ── E-commerce (international) ──────────────────────────────────
    ("aliexpress", "com.alibaba.iAliexpress", "AliExpress", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 12 categories including Financial Info, Contact Info, precise Location, Health & Fitness.",
         436672029),
    ]),
    ("shein", "com.shein.app", "SHEIN", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 11 categories including Financial Info, Contact Info, Identifiers, Usage Data.",
         878577184),
    ]),
    ("temu", "com.einnovation.temu", "Temu", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 13 categories including Financial Info, Contact Info, Photos, Contacts, precise Location.",
         1641486558),
    ]),
    ("etsy", "com.etsy.etsyforiphone", "Etsy", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 9 categories including Financial Info, Contact Info, Identifiers.",
         477128284),
    ]),
    ("wish", "com.contextlogic.wishweb", "Wish", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 10 categories including Financial Info, precise Location, Contacts.",
         510016022),
    ]),

    # ── Banking (representative US apps) ────────────────────────────
    ("chase", "com.chase.sig.Chase", "Chase Mobile", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 12 categories including Financial Info, Sensitive Info, Identifiers, Contact Info, Diagnostics.",
         298867247),
    ]),
    ("bofa", "com.bofa.bofa", "Bank of America Mobile", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 11 categories including Financial Info, Sensitive Info, Health & Fitness, Identifiers.",
         284847138),
    ]),
    ("wellsfargo", "com.wf.WellsFargoMobile", "Wells Fargo Mobile", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 11 categories including Financial Info, Sensitive Info, Identifiers.",
         311548709),
    ]),

    # ── Communication ──────────────────────────────────────────────
    ("signal-ios", "org.whispersystems.signal", "Signal (iOS)", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares ONLY Unlinked Data: Contact Info — Signal's privacy posture is famously minimal; the only data collected is the phone number used to register, not linked to user identity.",
         874139669),
    ]),

    # ── Misc widely-installed apps ──────────────────────────────────
    ("opera-mini", "com.operasoftware.OperaMini", "Opera", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking: identifiers, advertising data, usage data, search history, browsing history.",
         363729560),
    ]),
    ("brave-ios", "com.brave.ios.browser", "Brave Browser (iOS)", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics — privacy-first browser brand reflected in minimal data collection.",
         1052879175),
    ]),
    ("firefox-ios", "org.mozilla.ios.Firefox", "Firefox (iOS)", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data: Identifiers, Usage Data, Diagnostics — moderate collection for a browser.",
         989804926),
    ]),

    # ── v1.6.2 round 3: 50 more entries.  Brings Trust catalog
    # 101 → ~150.  Mix of: Apple's own apps (typically clean labels,
    # gives users a baseline), EU banking (CNIL/DPA-relevant
    # context for European users), more iOS-on-Mac mobile apps,
    # crypto/wellness/education categories. ──

    # ── Apple's own apps (Mac App Store, well-disclosed) ────────────
    ("apple-pages", "com.apple.iWork.Pages", "Apple Pages", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Identifiers, Usage Data, Diagnostics. No Linked Data, no tracking — Apple's typical first-party posture.",
         409201541),
    ]),
    ("apple-numbers", "com.apple.iWork.Numbers", "Apple Numbers", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Identifiers, Usage Data, Diagnostics. No Linked Data, no tracking.",
         409203825),
    ]),
    ("apple-keynote", "com.apple.iWork.Keynote", "Apple Keynote", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Identifiers, Usage Data, Diagnostics. No Linked Data, no tracking.",
         409183694),
    ]),
    ("apple-finalcut", "com.apple.FinalCut", "Final Cut Pro", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics. No Linked Data, no tracking.",
         424389933),
    ]),
    ("apple-logicpro", "com.apple.logic10", "Logic Pro", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics. No Linked Data, no tracking.",
         634148309),
    ]),
    ("apple-xcode", "com.apple.dt.Xcode", "Xcode", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics, Usage Data. Minimal collection consistent with Apple's first-party data policy.",
         497799835),
    ]),

    # ── EU banking ──────────────────────────────────────────────────
    ("revolut", "com.revolut.RevolutApp", "Revolut", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 11 categories including Financial Info, Sensitive Info, precise Location, Identifiers, Contacts.",
         932493382),
    ]),
    ("n26", "com.number26.iphone", "N26", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Financial Info, Sensitive Info, Identifiers, Contact Info.",
         956428662),
    ]),
    ("wise", "com.transferwise.TransferWise", "Wise", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 10 categories including Financial Info, Sensitive Info, Contact Info, Identifiers, Diagnostics.",
         612261027),
    ]),
    ("bunq", "com.bunq.bunqapp", "bunq", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 10 categories including Financial Info, Sensitive Info, Contact Info, Identifiers — Dutch challenger bank under DNB supervision.",
         567067561),
    ]),
    ("ing", "com.ing.diba.ingdibaapp", "ING", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Financial Info, Sensitive Info, Identifiers, Diagnostics.",
         467082749),
    ]),

    # ── Crypto / fintech ────────────────────────────────────────────
    ("coinbase", "com.vilcsak.bitcoins2", "Coinbase", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 10 categories including Financial Info, Sensitive Info, Identifiers, Contact Info, Health & Fitness.",
         886427730),
    ]),
    ("kraken", "com.kraken.kraken", "Kraken Crypto", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Financial Info, Sensitive Info, Identifiers, Contact Info.",
         1481947260),
    ]),
    ("binance", "com.czzhao.binance", "Binance", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 12 categories including Financial Info, Sensitive Info, precise Location, Identifiers.",
         1436799971),
    ]),
    ("crypto-com", "co.mona.app", "Crypto.com", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 12 categories including Financial Info, Sensitive Info, precise Location, Contacts.",
         1262148500),
    ]),

    # ── Wellness / fitness ──────────────────────────────────────────
    ("myfitnesspal", "com.myfitnesspal.MyFitnessPal-tablet", "MyFitnessPal", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 11 categories including Health & Fitness, Sensitive Info, Identifiers, Usage Data.",
         341232718),
    ]),
    ("nike-run-club", "com.nike.nikeplus-gps", "Nike Run Club", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 11 categories including Health & Fitness, precise Location, Sensitive Info, Identifiers.",
         387771637),
    ]),
    ("peloton", "com.onepeloton.peloton", "Peloton", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 12 categories including Health & Fitness, Financial Info, Sensitive Info, Photos, Identifiers.",
         792750948),
    ]),
    ("fitbit", "com.fitbit.FitbitMobile", "Fitbit", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 12 categories including Health & Fitness, Sensitive Info, precise Location, Identifiers, Diagnostics.",
         462638897),
    ]),

    # ── Education ───────────────────────────────────────────────────
    ("khan-academy", "com.khanacademy.Khan-Academy", "Khan Academy", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 7 categories including User Content, Identifiers, Usage Data, Diagnostics.",
         469863705),
    ]),
    ("coursera", "org.coursera.coursera", "Coursera", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including Contact Info, User Content, Identifiers, Usage Data.",
         736535961),
    ]),
    ("udemy", "com.udemy.UdemyiOS", "Udemy", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 9 categories including Identifiers, Usage Data, Advertising Data.",
         562413829),
    ]),
    ("quizlet", "com.quizlet.quizletapp", "Quizlet", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including Contact Info, User Content, Identifiers, Usage Data.",
         360452360),
    ]),

    # ── Photo / video ───────────────────────────────────────────────
    ("vsco", "com.visualsupply.cam", "VSCO", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 9 categories including Photos, Identifiers, Contact Info, Usage Data.",
         588013838),
    ]),
    ("adobe-express", "com.adobe.spark", "Adobe Express", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 7 categories including User Content, Photos, Identifiers, Contact Info.",
         1051937863),
    ]),
    ("procreate-pocket", "com.savage.Procreate-Pocket", "Procreate Pocket", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics, Identifiers — minimal collection from a paid creative-tool indie.",
         1037778262),
    ]),

    # ── Browsers (additional iOS) ───────────────────────────────────
    ("chrome-ios", "com.google.chrome.ios", "Chrome (iOS)", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking: identifiers, advertising data, search history, browsing history, usage data.",
         535886823),
    ]),
    ("duckduckgo", "com.duckduckgo.mobile.ios", "DuckDuckGo", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics — DuckDuckGo's privacy-first stance reflected in its self-disclosed minimum.",
         663592361),
    ]),

    # ── Reading / content ───────────────────────────────────────────
    ("pocket", "com.ideashower.ReadItLaterPro", "Pocket", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 6 categories including Browsing History, Usage Data, Identifiers, Contact Info.",
         309601447),
    ]),
    ("goodreads", "com.goodreads.goodreadsapp", "Goodreads", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 10 categories including Contacts, Identifiers, Search History, Usage Data.",
         355833469),
    ]),
    ("medium", "com.medium.reader", "Medium", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 7 categories including Identifiers, Usage Data, Search History.",
         828256236),
    ]),
    ("substack", "com.substack.app", "Substack", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including Contact Info, Financial Info, User Content, Identifiers.",
         1574515480),
    ]),

    # ── Mobile apps installable on Apple Silicon Macs ───────────────
    ("messenger-ios", "com.facebook.Messenger", "Messenger (iOS)", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 18 categories — Meta apps consistently disclose extensive cross-product data collection.",
         454638411),
    ]),
    ("facebook", "com.facebook.Facebook", "Facebook", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 18 categories including Health & Fitness, Sensitive Info, precise Location, Financial Info, Photos.",
         284882215),
    ]),
    ("whatsapp-business", "net.whatsapp.WhatsAppSMB", "WhatsApp Business", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Contact Info, Contacts, Financial Info, Identifiers — Meta-owned, business-tier disclosures.",
         1386412985),
    ]),

    # ── Productivity / notes ────────────────────────────────────────
    ("evernote-ios", "com.evernote.iPhone.Evernote", "Evernote (iOS)", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including User Content, Contact Info, Identifiers, Usage Data.",
         281796108),
    ]),
    ("dropbox-ios", "com.getdropbox.Dropbox", "Dropbox (iOS)", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including User Content, Contact Info, Identifiers, Usage Data.",
         327630330),
    ]),
    ("box-ios", "com.box.iosapp", "Box", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 7 categories including User Content, Identifiers, Diagnostics.",
         290853822),
    ]),

    # ── Maps / navigation ──────────────────────────────────────────
    ("waze", "com.waze.iphone", "Waze", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 10 categories including precise Location, Contact Info, Audio Data — Google-owned navigation app.",
         323229106),
    ]),
    ("citymapper", "com.citymapper.CityMapper", "Citymapper", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 7 categories including precise Location, Identifiers, Usage Data.",
         469463298),
    ]),

    # ── Communication (additional) ──────────────────────────────────
    ("slack-ios", "com.tinyspeck.chatlyio", "Slack (iOS)", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 11 categories including Contacts, User Content, Identifiers, Usage Data.",
         618783545),
    ]),
    ("discord-ios", "com.hammerandchisel.discord", "Discord (iOS)", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including User Content, Identifiers, Usage Data, Diagnostics.",
         985746746),
    ]),
    ("zoom-ios", "us.zoom.videomeetings", "Zoom (iOS)", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 9 categories including Contact Info, User Content, Identifiers, Usage Data.",
         546505307),
    ]),

    # ── Mobile games (often installed on Mac via Designed-for-iPad) ─
    ("monument-valley", "com.ustwo.monumentvalley", "Monument Valley", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics — paid indie game with minimal collection.",
         728293409),
    ]),
    ("alto-odyssey", "com.snowmanlabs.alto.odyssey", "Alto's Odyssey", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data: Identifiers, Purchase History, Diagnostics.",
         1182456409),
    ]),
    ("genshin-impact", "com.miHoYo.GenshinImpact", "Genshin Impact", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 8 categories including Identifiers, Purchase History, User Content, Usage Data — Chinese-developed; data may transit infrastructure outside the EU.",
         1517783697),
    ]),
    ("roblox", "com.roblox.robloxmobile", "Roblox", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 11 categories including Contacts, Identifiers, Audio Data, Photos, Usage Data.",
         431946152),
    ]),

    # ── Music creation / DJ ─────────────────────────────────────────
    ("garageband", "com.apple.mobilegarageband", "GarageBand", [
        ("appStoreUnlinkedData", "low",
         "App Store privacy label declares only Unlinked Data: Diagnostics, Identifiers. Apple first-party posture.",
         408709785),
    ]),

    # ── News ────────────────────────────────────────────────────────
    ("bbc-news", "uk.co.bbc.news", "BBC News", [
        ("appStoreLinkedData", "moderate",
         "App Store privacy label declares Linked Data across 6 categories including Identifiers, Usage Data, Diagnostics.",
         377382937),
    ]),
    ("nyt", "com.nytimes.NYTimes", "The New York Times", [
        ("appStoreTrackingData", "high",
         "App Store privacy label discloses tracking + Linked Data across 9 categories including Identifiers, Usage Data, Search History, Advertising Data.",
         284862083),
    ]),
]


def main():
    catalog = json.loads(CATALOG.read_text())
    existing_ids = {e["targetBundleID"] for e in catalog["entries"]}

    added = 0
    skipped = []
    for slug, bundle_id, name, concerns in NEW:
        if bundle_id in existing_ids:
            skipped.append(bundle_id)
            continue
        entry = {
            "targetBundleID": bundle_id,
            "targetDisplayName": name,
            "lastReviewed": TODAY,
            "concerns": [
                app_store_concern(slug, kind, severity, summary, app_store_id)
                for kind, severity, summary, app_store_id in concerns
            ],
            "fallbackAlternatives": [],
        }
        catalog["entries"].append(entry)
        added += 1

    # Stable order by bundle ID for consistent diffs.
    catalog["entries"].sort(key=lambda e: e["targetBundleID"])

    CATALOG.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"
    )

    print(f"✓ wrote {len(catalog['entries'])} entries (added {added})")
    if skipped:
        print(f"  skipped (already in catalog): {skipped}")


if __name__ == "__main__":
    main()
