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

echo "• Signing (identity: $SIGN_IDENTITY)"
SIGN_ARGS=(--force --deep --options runtime --sign "$SIGN_IDENTITY")
if [[ -n "$ENTITLEMENTS" ]]; then
    SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
fi
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"

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
