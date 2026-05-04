import Foundation

// =====================================================================
// v1.7.x: localized-string lookup via direct .strings-file plist read
// =====================================================================
//
// **The problem.**  Six Foundation/SwiftUI APIs all return English
// in the SwiftPM-built .app under a non-development locale.  See
// `splynek_localization_gotcha.md` (memory) for the long-form
// rationale.  SwiftUI's `Text(LocalizedStringKey)` works because
// it goes through the LocalizedStringResource pipeline with
// SwiftUI environment context.  AppKit-side String extraction
// goes through Bundle's default-locale-resolution chain which
// returns ["en"] inside the running .app despite system pref.
//
// **The fix.**  Read the `.strings` file as a plist directly + look
// up the key by exact string match.  `.strings` files in text format
// are valid plists with String:String entries.  This sidesteps
// Foundation's broken locale resolution by manually picking the
// locale (via `Locale.current` or any explicit string), constructing
// the path to the right `<locale>.lproj/Localizable.strings`, and
// parsing it as a plist.
//
// Why this works when `Bundle(path: lprojPath).localizedString(...)`
// doesn't: the lproj-direct lookup STILL goes through Foundation's
// internal CFCopyLocalizedStringFromTableInBundle path which has
// the broken locale-base resolution.  Reading the file ourselves
// as a plist bypasses that entirely — we go from URL → Data →
// dictionary → key lookup, no Foundation locale machinery in
// the loop.

extension Bundle {

    /// v1.7.x: cross-build-system bundle reference.  In SwiftPM builds
    /// (`./Scripts/build.sh`), `Bundle.module` is auto-synthesized
    /// for the SplynekCore module + points to the build cache.  In
    /// Xcode-managed MAS builds (`./Scripts/build-mas.sh`),
    /// `Bundle.module` doesn't exist — Xcode targets bundle their
    /// resources at the .app's main bundle.  This wrapper picks the
    /// right one at compile time so call sites can be build-agnostic.
    /// `localizedStringForAppKit` searches both Bundle.main + the
    /// embedded SplynekCore.bundle internally, so even when this
    /// returns Bundle.main (Xcode build), the lookup still finds
    /// the .strings files.
    static var splynekCore: Bundle {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }

    /// Read the `<locale>.lproj/Localizable.strings` file inside
    /// this bundle as a plist + look up `key` by exact match.
    /// Bypasses Foundation's broken default-locale resolution by
    /// manually picking the locale.
    ///
    /// - Parameters:
    ///   - key: source-language string (the same key SwiftUI uses).
    ///   - locale: BCP 47 locale identifier ("pt-PT", "en", etc).
    ///     Caller decides which locale to look up — typically
    ///     `Locale.current.identifier` or the first entry in
    ///     `Locale.preferredLanguages`.  Returns the value verbatim
    ///     from the .strings file or nil if the key isn't there.
    ///
    /// - Returns: the localized value, or nil on miss (no .lproj
    ///   directory, no .strings file, key not in dict).
    func directPlistLookup(forKey key: String, locale: String) -> String? {
        // ROOT CAUSE OF THE LONG-RUNNING LOCALIZATION GOTCHA:
        // Bundle.module.bundleURL resolves to SwiftPM's build-cache
        // path (.build/<arch>/<config>/Splynek_SplynekCore.bundle/)
        // — NOT the bundle copied into Splynek.app/Contents/
        // Resources/.  The build-cache path has only Info.plist +
        // Localizable.xcstrings (no .lproj subdirs); compile-
        // xcstrings.py runs as part of build.sh + writes the .strings
        // files into the .app-internal bundle, NOT the build cache.
        // Foundation's Bundle.localizedString (and every variant) was
        // looking at the build cache, found no .lproj, fell through
        // to en source.
        //
        // Fix: search a list of candidate bundle bases — the receiver
        // itself first (works in script context against the .app
        // bundle), then Bundle.main + Contents/Resources/Splynek_
        // SplynekCore.bundle (the in-app location), then Bundle.main
        // alone (top-level lproj also gets compiled by build.sh).
        let candidateBases: [URL] = [
            self.bundleURL,  // Bundle.module's build-cache path (usually empty for .app builds)
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources/Splynek_SplynekCore.bundle"),
            Bundle.main.bundleURL
                .appendingPathComponent("Contents/Resources"),
        ]
        for base in candidateBases {
            let stringsURL = base
                .appendingPathComponent("\(locale).lproj")
                .appendingPathComponent("Localizable.strings")
            guard FileManager.default.fileExists(atPath: stringsURL.path) else {
                continue
            }
            guard let dict = NSDictionary(contentsOf: stringsURL) as? [String: String]
            else { continue }
            if let result = dict[key] { return result }
        }
        return nil
    }

    /// User-facing convenience: walk preferred locales (system + app
    /// `AppleLanguages`), try each via `directPlistLookup`, return
    /// the first non-nil + non-key result.  Falls back to the key
    /// itself on full miss (matches SwiftUI Text behaviour).
    ///
    /// **The reliable AppKit-side localization path** for SwiftPM
    /// .apps where the standard Foundation/SwiftUI APIs fail to
    /// resolve.  See `splynek_localization_gotcha.md`.
    func localizedStringForAppKit(_ key: String, fallback: String? = nil) -> String {
        // Empirically inside the sandboxed SwiftPM-built .app:
        //   - `UserDefaults.standard.array(forKey: "AppleLanguages")`
        //     returns nil (the sandbox per-app domain doesn't have
        //     it set unless the user explicitly overrode it for
        //     this app)
        //   - `Locale.preferredLanguages` returns ["en"] (filtered
        //     by Foundation against the broken default-base chain)
        //   - `Locale.current.identifier` DOES return the user's
        //     real locale (e.g. "pt_PT" with POSIX underscore)
        //   - `CFPreferencesCopyAppValue("AppleLanguages",
        //     kCFPreferencesAnyApplication)` reads the SYSTEM-level
        //     NSGlobalDomain pref — sandbox-friendly, returns
        //     ["pt-PT"] correctly.
        // Walk every plausible source + try each candidate; first
        // hit wins.
        var candidates: [String] = []
        // 1. CFPreferences AnyApplication (system-level NSGlobalDomain
        //    AppleLanguages — works through sandbox).
        if let langs = CFPreferencesCopyAppValue(
            "AppleLanguages" as CFString,
            kCFPreferencesAnyApplication
        ) as? [String] {
            candidates.append(contentsOf: langs)
        }
        // 2. Locale.current — the user's real locale, not the
        //    bundle-filtered preferred-languages list.  Identifier
        //    uses POSIX underscores ("pt_PT"); also try the BCP 47
        //    hyphen form which is what .lproj directories use.
        let id = Locale.current.identifier
        candidates.append(id)
        let bcp47 = id.replacingOccurrences(of: "_", with: "-")
        if bcp47 != id { candidates.append(bcp47) }
        // 3. Language code only ("pt") — for users on "pt-BR" who
        //    might share a "pt" table.
        if let lang = Locale.current.language.languageCode?.identifier {
            candidates.append(lang)
        }
        // 4. Per-app UserDefaults (last because rarely set).
        if let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String] {
            candidates.append(contentsOf: langs)
        }
        // 5. Locale.preferredLanguages (last because filtered).
        candidates.append(contentsOf: Locale.preferredLanguages)

        // Walk uniquified candidates.
        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            // Try exact form first then language-only form
            // (e.g. "pt-PT" → "pt").
            let langOnly = candidate.split(separator: "-").first.map(String.init)
                ?? candidate.split(separator: "_").first.map(String.init)
                ?? candidate
            let toTry = candidate == langOnly ? [candidate] : [candidate, langOnly]
            for c in toTry {
                if let result = directPlistLookup(forKey: key, locale: c),
                   result != key {
                    return result
                }
            }
        }
        return fallback ?? key
    }
}
