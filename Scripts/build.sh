#!/usr/bin/env bash
# Build Splynek.app from the SPM executable target.
#
# Environment variables:
#   CONFIG         — "release" (default) or "debug"
#   SIGN_IDENTITY  — codesign identity. Default "-" (ad-hoc).
#                    For distribution, pass a Developer ID:
#                      SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   ENTITLEMENTS   — optional path to an entitlements plist
#
# Three entitlement variants live in Resources/:
#   Splynek.entitlements            — legacy DMG variant (v0.x users)
#   Splynek-DirectSale.entitlements — 2026-06 direct-sale launch
#                                     (see LAUNCH-WITHOUT-APPLE.md)
#   Splynek-MAS.entitlements        — Mac App Store build (used by
#                                     Scripts/build-mas.sh, not here)
#
# Typical direct-sale launch invocation:
#
#   SIGN_IDENTITY="Developer ID Application: Paulo Moura (58C6YC5GB5)" \
#   ENTITLEMENTS="Resources/Splynek-DirectSale.entitlements" \
#     ./Scripts/build.sh release
#
# Produces ./build/Splynek.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# v1.6.1: accept `debug` / `release` as a positional arg too.  The
# env-var-only contract was unfriendly — `./Scripts/build.sh debug`
# is what people instinctively try, and silently building release
# instead is a footgun.  Env var still works and takes precedence
# when both are set, so existing scripts don't break.
case "${1:-}" in
    debug|release) CONFIG="${CONFIG:-$1}" ;;
    "")            ;;
    *)             echo "Unknown arg '$1' — expected 'debug' or 'release'." >&2; exit 2 ;;
esac
CONFIG="${CONFIG:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="${ENTITLEMENTS:-}"
APP="build/Splynek.app"

echo "• Building Splynek target (swift build -c $CONFIG)"
# Build only the app + its library. The test target depends on a
# @testable import of SplynekCore which requires debug-mode enablement;
# building everything under `-c release` fails there and used to
# silently leave a stale .app bundle. Use `swift run splynek-test` for
# the test suite.
swift build -c "$CONFIG" --product Splynek

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
if [[ ! -x "$BIN_PATH/Splynek" ]]; then
    echo "Error: executable not found at $BIN_PATH/Splynek" >&2
    exit 1
fi

echo "• Assembling app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/Splynek" "$APP/Contents/MacOS/Splynek"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Brand icon — referenced by CFBundleIconFile in Info.plist so Finder,
# Dock, and CMD-Tab all pick it up.
if [[ -f Resources/Splynek.icns ]]; then
    cp Resources/Splynek.icns "$APP/Contents/Resources/Splynek.icns"
fi
# v1.6.1: SPM resource bundle for localization.  SwiftPM compiles
# Localizable.xcstrings into a per-target .bundle (Splynek_SplynekCore.bundle).
# At runtime SwiftUI's LocalizedStringKey lookup walks Bundle.module
# which resolves via this bundle.  Without copying it into the .app,
# every locale falls through to source English.
SPM_BUNDLE="$BIN_PATH/Splynek_SplynekCore.bundle"
if [[ -d "$SPM_BUNDLE" ]]; then
    cp -R "$SPM_BUNDLE" "$APP/Contents/Resources/Splynek_SplynekCore.bundle"
    # v1.6.2: compile Localizable.xcstrings → per-locale
    # Localizable.strings.  SwiftPM's `.process()` for .xcstrings
    # ships the raw catalog but Foundation reads only the compiled
    # form (`<locale>.lproj/Localizable.strings`).  Xcode runs the
    # equivalent step automatically; SwiftPM-from-CLI does not.
    # Without this, every locale falls through to source English.
    if command -v python3 > /dev/null; then
        echo "• Compiling localizations"
        python3 "$ROOT/Scripts/compile-xcstrings.py" \
            "$APP/Contents/Resources/Splynek_SplynekCore.bundle"
        # v1.6.2: SwiftUI's `Text("foo")` default-resolves through
        # `Bundle.main` (the .app), NOT `Bundle.module` (the SwiftPM
        # resource bundle).  Most Splynek views use the bare `Text(_:)`
        # without an explicit `bundle: .module` argument.  So the
        # compiled .lproj files inside the SPM bundle aren't reached.
        # Fix: mirror them up to the .app's top-level Resources/ so
        # Bundle.main finds them.  Both bundles now resolve.
        for lproj in "$APP/Contents/Resources/Splynek_SplynekCore.bundle"/*.lproj; do
            [ -d "$lproj" ] || continue
            cp -R "$lproj" "$APP/Contents/Resources/"
        done
        echo "  mirrored .lproj into .app's main Resources"
    else
        echo "  ⚠  python3 not found — localization will fall back to English"
    fi
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

# v1.6.2: App Intents metadata.  SwiftPM's `swift build` does not
# run `appintentsmetadataprocessor`, so the SPM-built .app ships
# without `Contents/Resources/Metadata.appintents` — Shortcuts.app
# and Siri can't discover Splynek's App Intents.  Xcode's build
# pipeline does run it.  If xcodegen + xcodebuild are available,
# do a one-shot Xcode build of the (non-MAS) Splynek scheme into a
# scratch DerivedData, then graft just the metadata file into our
# real .app.  Adds ~60 s to the build; opt out with
# SKIP_APP_INTENTS=1.
if [[ "${SKIP_APP_INTENTS:-0}" != "1" ]] \
   && command -v xcodegen > /dev/null \
   && command -v xcodebuild > /dev/null; then
    echo "• Generating App Intents metadata (via Xcode)"
    XC_DERIVED="$ROOT/.build/AppIntentsMetadata.derivedData"
    rm -rf "$XC_DERIVED"
    xcodegen generate > /dev/null 2>&1
    if xcodebuild -project Splynek.xcodeproj -scheme Splynek \
                  -configuration Debug -derivedDataPath "$XC_DERIVED" \
                  build > /tmp/splynek-appintents-build.log 2>&1; then
        SRC="$XC_DERIVED/Build/Products/Debug/Splynek.app/Contents/Resources/Metadata.appintents"
        if [[ -d "$SRC" || -f "$SRC" ]]; then
            cp -R "$SRC" "$APP/Contents/Resources/Metadata.appintents"
            echo "  ✓ Metadata.appintents grafted into .app"
        else
            echo "  ⚠  Xcode build OK but Metadata.appintents not found — check /tmp/splynek-appintents-build.log"
        fi
    else
        echo "  ⚠  Xcode build for App Intents metadata failed; SPM .app will lack Shortcuts.app discovery"
        echo "     See /tmp/splynek-appintents-build.log"
    fi
else
    echo "  ⚠  Skipping App Intents metadata (no xcodegen / xcodebuild, or SKIP_APP_INTENTS=1)"
    echo "     The SPM-built .app will work but Shortcuts.app won't see Splynek's Intents."
fi

# Ship the browser-integration helpers inside the bundle so the About
# pane can reveal them without any external dependency. Copy only the
# user-facing files — no dev-only markdown that looks like app
# documentation in Finder.
if [[ -d Extensions ]]; then
    echo "• Bundling browser + launcher extensions"
    mkdir -p "$APP/Contents/Resources/Extensions"
    for ext in Chrome Safari Raycast Alfred; do
        if [[ -d "Extensions/$ext" ]]; then
            cp -R "Extensions/$ext" "$APP/Contents/Resources/Extensions/$ext"
        fi
    done
fi

# Legal docs are bundled so the in-app Legal view can render them
# without a network round-trip.
if [[ -d Resources/Legal ]]; then
    echo "• Bundling legal docs"
    mkdir -p "$APP/Contents/Resources/Legal"
    cp Resources/Legal/*.md "$APP/Contents/Resources/Legal/"
fi

# 2026-06 direct-sale launch: bundle Sparkle.framework.  SwiftPM
# links Sparkle (the binary has an @rpath/Sparkle.framework load
# command) but does NOT copy the framework into the .app bundle, and
# the SPM-produced binary has no @executable_path/../Frameworks
# rpath.  Without this step the app crashes on launch with
# "Library not loaded: @rpath/Sparkle.framework".  We copy the
# framework + add the rpath BEFORE signing so codesign --deep signs
# the framework too.  No-op on builds where Sparkle isn't linked
# (e.g. a future MAS variant that excludes it).
SPARKLE_FW="$BIN_PATH/Sparkle.framework"
if [[ -d "$SPARKLE_FW" ]]; then
    echo "• Bundling Sparkle.framework"
    mkdir -p "$APP/Contents/Frameworks"
    cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
    # Add the loader path (idempotent — ignore "would duplicate" errors).
    install_name_tool -add_rpath "@executable_path/../Frameworks" \
        "$APP/Contents/MacOS/Splynek" 2>/dev/null || true
fi

echo "• Signing (identity: $SIGN_IDENTITY)"
# Sparkle must be signed INSIDE-OUT with the same identity as the
# app, or dyld rejects it at launch with "different Team IDs" (the
# framework ships pre-signed by the Sparkle project; `codesign
# --deep` does NOT reliably re-sign an already-valid nested
# framework, so we force-sign each component explicitly first).
# Order matters: nested XPC + helper executables → framework → app.
SPARKLE_BUNDLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_BUNDLE" ]]; then
    echo "• Signing Sparkle.framework (inside-out)"
    SPV="$SPARKLE_BUNDLE/Versions/B"
    for component in \
        "$SPV/XPCServices/Downloader.xpc" \
        "$SPV/XPCServices/Installer.xpc" \
        "$SPV/Updater.app" \
        "$SPV/Autoupdate" ; do
        [[ -e "$component" ]] && codesign --force --options runtime \
            --sign "$SIGN_IDENTITY" "$component"
    done
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$SPARKLE_BUNDLE"
fi

# Sign the app itself.  NOT --deep — we've already signed the nested
# Sparkle framework above with the correct (matching) identity, and a
# second --deep pass can re-stamp it in a way that re-introduces the
# mismatch.  The app-level sign + the explicit framework sign together
# cover the whole bundle.
SIGN_ARGS=(--force --options runtime --sign "$SIGN_IDENTITY")
if [[ -n "$ENTITLEMENTS" ]]; then
    SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"

# Heads-up: an AD-HOC signed build (SIGN_IDENTITY="-") that bundles
# Sparkle will NOT launch — dyld's hardened-runtime library
# validation rejects the ad-hoc framework with a misleading
# "different Team IDs" error (both are ad-hoc = no team ID, which
# library validation treats as untrusted).  This is EXPECTED.  A
# real Developer ID build stamps the app + the Sparkle framework
# with the SAME team ID, library validation passes, and the app
# launches normally.  To smoke-test an ad-hoc build locally, re-sign
# everything ad-hoc WITHOUT --options runtime; for the real release,
# always use the Developer ID identity (which notarization requires
# anyway).
if [[ "$SIGN_IDENTITY" == "-" && -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
    echo "  ⚠  ad-hoc + bundled Sparkle: this build won't launch under hardened"
    echo "     runtime (library validation). Use a Developer ID for a launchable"
    echo "     build. See the note in Scripts/build.sh above this line."
fi

echo "• Done: $APP"
echo
echo "To run:       open $APP"
echo "To install:   cp -R $APP /Applications/"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    cat <<'NOTE'

Note: ad-hoc signed. On another Mac, Gatekeeper will refuse to launch it
unless the user right-click → Open. To distribute publicly:

  SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build.sh

  # then notarize:
  ditto -c -k --keepParent build/Splynek.app build/Splynek.zip
  xcrun notarytool submit build/Splynek.zip \
      --apple-id you@example.com --team-id TEAMID --password "@keychain:AC_PASSWORD" \
      --wait
  xcrun stapler staple build/Splynek.app
NOTE
fi
