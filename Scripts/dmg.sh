#!/usr/bin/env bash
# Package build/Splynek.app into a distributable DMG.
#
# Run ./Scripts/build.sh first. This script assumes build/Splynek.app
# is signed (ad-hoc or Developer ID) and produces build/Splynek.dmg.
#
# Usage:
#   ./Scripts/dmg.sh                     # defaults
#   VOLNAME="Splynek 0.27" ./Scripts/dmg.sh
#
# The DMG is compressed (UDZO) and includes a symlink to /Applications
# so users can drag-install. No DMG-layout frills (no background image,
# no positioned icons) because that needs an applescript roundtrip
# that adds a ton of script complexity; fancy DMG artwork can come in
# a follow-up if we start caring about first-run aesthetics.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="build/Splynek.app"
if [[ ! -d "$APP" ]]; then
    echo "Error: $APP missing. Run ./Scripts/build.sh first." >&2
    exit 1
fi

VERSION=$(defaults read "$ROOT/Resources/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "0.0.0")
VOLNAME="${VOLNAME:-Splynek $VERSION}"
DMG="build/Splynek.dmg"
STAGING="build/dmg-staging"

echo "• Staging DMG contents (volume name: $VOLNAME)"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "• Building DMG"
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG" >/dev/null

rm -rf "$STAGING"

# Verify.
hdiutil verify "$DMG" >/dev/null
echo "• Done: $DMG ($(du -h "$DMG" | cut -f1))"
echo
echo "Next:"
echo "  open $DMG                  # preview locally"
echo "  shasum -a 256 $DMG         # hash for release notes / Homebrew cask"
