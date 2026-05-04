import Foundation

// =====================================================================
// v1.7.x: localized-string lookup workaround for AppKit-side APIs
// =====================================================================
//
// **Status: best-effort fallback.**  Live testing on a SwiftPM-built
// .app launched on a pt-PT system reveals that NEITHER this
// workaround NOR the three obvious Foundation APIs resolve the
// .strings-file translations:
//
//   - `String(localized: "key", bundle: .module)` → English
//   - `NSLocalizedString("key", bundle: .module, comment: "")` → English
//   - `Bundle.module.localizedString(forKey: "key", value: nil, table: nil)` → English
//   - `Bundle(path: lprojPath).localizedString(forKey:value:table:)`
//     directly against the lproj subdirectory → also English
//
// What works: `Bundle.preferredLocalizations(from: locs,
// forPreferences: ["pt-PT"])` returns `["pt-PT"]` correctly when
// explicit prefs are passed.  But inside the running sandboxed
// .app, both `Locale.preferredLanguages` and `UserDefaults.standard
// .array(forKey: "AppleLanguages")` return values that don't include
// pt-PT — even though `defaults read NSGlobalDomain AppleLanguages`
// at the user level returns `["pt-PT"]` and SwiftUI's
// `Text(LocalizedStringKey)` localizes correctly throughout the same
// running app.
//
// **Best guess at root cause.**  SwiftUI's `Text` uses
// `LocalizedStringResource` which performs lookup via a different
// code path that DOES see the user's pt-PT preference, while
// AppKit-side `Bundle.localizedString` reads the sandboxed app's
// per-process `AppleLanguages` defaults (which apparently default
// to `[en]` for ad-hoc-signed SwiftPM debug builds even when the
// system pref is pt-PT).  A definitive fix would need either:
//
//   - Run `defaults write app.splynek.Splynek AppleLanguages -array pt-PT`
//     before launch (works at the OS level, doesn't fix code)
//   - Use `LocalizedStringResource` end-to-end + render it via
//     SwiftUI rather than passing through AppKit's String surface
//   - Swizzle Bundle.localizedString to honour Locale.preferredLanguages
//
// **What this extension does today.**  Walks
// `UserDefaults.standard.array(forKey: "AppleLanguages")` (with
// `Locale.preferredLanguages` as fallback) + tries each candidate
// `.lproj` subdirectory as its own Bundle.  When this succeeds, the
// lookup returns the localized value; when it fails (the live-test
// case), returns the English fallback — which is no worse than
// hardcoding English.  Kept here as the right-shaped scaffolding
// for the next iteration of localization work.
//
// **Where to use this.**  Anywhere AppKit takes a plain `String` for
// user-visible text.  Don't use from SwiftUI — `Text("...")` works
// natively.

extension Bundle {

    /// Look up a localized string respecting the user's
    /// `Locale.preferredLanguages` — works around the SwiftPM-
    /// built .app's broken default localized-string-lookup behaviour.
    /// See file header for the long-form rationale.
    ///
    /// - Parameters:
    ///   - key: the source-language string (the same key SwiftUI uses).
    ///   - fallback: returned if no preferred locale's `.strings` table
    ///     contains `key`.  Defaults to `key` itself, which matches
    ///     SwiftUI's behaviour for un-translated keys.
    ///
    /// - Returns: the localized value, or `fallback` on miss.
    func localizedStringRespectingLocale(
        forKey key: String,
        fallback: String? = nil
    ) -> String {
        let resolvedFallback = fallback ?? key
        // v1.7.x audit: read `AppleLanguages` directly from
        // UserDefaults rather than via Locale.preferredLanguages.
        // Empirically, inside a SwiftPM-built .app launched on a
        // pt-PT system, `Locale.preferredLanguages` can return
        // `["en"]` even when the user's system-wide preference is
        // `["pt-PT"]` and SwiftUI's Text(LocalizedStringKey)
        // localizes correctly.  Reading AppleLanguages directly
        // sidesteps that mystery.
        let prefs = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])
            ?? Locale.preferredLanguages
        for lang in prefs {
            // Try the exact preference first ("pt-PT") then the
            // language-only form ("pt") so a user with "pt-BR" set
            // would still pick up "pt" tables if available.
            let languageOnly = lang.split(separator: "-").first.map(String.init) ?? lang
            let candidates = lang == languageOnly ? [lang] : [lang, languageOnly]
            for candidate in candidates {
                guard let lprojPath = self.path(forResource: candidate, ofType: "lproj"),
                      let localized = Bundle(path: lprojPath)
                else { continue }
                let result = localized.localizedString(
                    forKey: key, value: nil, table: nil
                )
                // Foundation returns the input key on miss — distinguish
                // by comparing.  If we got something different, it's a hit.
                if result != key { return result }
            }
        }
        return resolvedFallback
    }
}
