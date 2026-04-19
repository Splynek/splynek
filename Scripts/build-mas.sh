#!/usr/bin/env bash
# Build + archive the Mac App Store variant of Splynek.
#
# Produces  build/Splynek-MAS.xcarchive  — an Apple-Distribution-signed
# archive ready for Xcode Organizer → Validate → Distribute.
#
# Prerequisites (one-time setup):
#   1. brew install xcodegen
#   2. Xcode 15+ installed with Apple Distribution cert:
#         security find-identity -v -p codesigning
#      should list at least one "Apple Distribution: Paulo ..." entry.
#   3. Sibling private repo checked out:
#         /Users/pcgm/Claude Code/         (this repo)
#         /Users/pcgm/splynek-pro/         (private)
#      The MAS target pulls from ../splynek-pro/Sources/SplynekPro/.
#
# Environment:
#   SKIP_REGEN    — set to 1 to skip `xcodegen generate` (useful when
#                   iterating on code without touching project.yml)
#   NO_SIGN       — set to 1 to archive unsigned (validation + upload
#                   will fail, but the build flow is testable)
#   ARCHIVE_PATH  — override output path (default: build/Splynek-MAS.xcarchive)
#
# For the DMG build (Developer-ID + notarisation), use Scripts/build.sh
# — this script is MAS-only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARCHIVE_PATH="${ARCHIVE_PATH:-build/Splynek-MAS.xcarchive}"
SKIP_REGEN="${SKIP_REGEN:-0}"
NO_SIGN="${NO_SIGN:-0}"

echo "• Splynek-MAS archive build"
echo "  Root:    $ROOT"
echo "  Output:  $ARCHIVE_PATH"
echo

# Sanity: the private repo must be adjacent.
PRIVATE_REPO="$ROOT/../splynek-pro"
if [[ ! -d "$PRIVATE_REPO/Sources/SplynekPro" ]]; then
    cat <<EOF >&2
Error: private repo not found at $PRIVATE_REPO

The MAS target compiles sources from splynek-pro. Check out the
private repo as a sibling directory:

    git clone git@github.com:Splynek/splynek-pro.git $PRIVATE_REPO

(requires private-repo access — GitHub authentication via gh or ssh)

Once checked out, re-run: ./Scripts/build-mas.sh
EOF
    exit 1
fi

# Sanity: xcodegen available
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Error: xcodegen not installed. Run: brew install xcodegen" >&2
    exit 1
fi

# Sanity: a Distribution cert exists (unless NO_SIGN=1)
if [[ "$NO_SIGN" != "1" ]]; then
    if ! security find-identity -v -p codesigning | grep -q "Apple Distribution"; then
        cat <<EOF >&2
Error: no "Apple Distribution" signing certificate found.

Create one via Xcode → Settings → Accounts → (Apple ID) → Manage
Certificates → + → Apple Distribution.

Then verify with:
    security find-identity -v -p codesigning

Or pass NO_SIGN=1 to archive unsigned (test-only).
EOF
        exit 1
    fi
fi

# 1. Regenerate Splynek.xcodeproj (idempotent)
if [[ "$SKIP_REGEN" != "1" ]]; then
    echo "• Regenerating Splynek.xcodeproj"
    xcodegen generate
else
    echo "• Skipping xcodegen (SKIP_REGEN=1)"
fi

# 2. Clean previous archive
rm -rf "$ARCHIVE_PATH"

# 3. Archive
echo "• Archiving (xcodebuild, scheme Splynek-MAS, config Release-MAS)"
XCODE_ARGS=(
    -project Splynek.xcodeproj
    -scheme Splynek-MAS
    -configuration Release-MAS
    -archivePath "$ARCHIVE_PATH"
    archive
)

if [[ "$NO_SIGN" == "1" ]]; then
    XCODE_ARGS+=(CODE_SIGNING_ALLOWED=NO)
    echo "  (NO_SIGN=1 — unsigned archive; won't validate for App Store)"
fi

# Log to file + tail to stdout on failure
LOG="build/build-mas.log"
mkdir -p build
if ! xcodebuild "${XCODE_ARGS[@]}" > "$LOG" 2>&1; then
    echo "Archive failed. Last 40 lines:" >&2
    tail -40 "$LOG" >&2
    exit 1
fi

# 4. Verify archive structure
if [[ ! -d "$ARCHIVE_PATH/Products/Applications/Splynek.app" ]]; then
    echo "Error: archive produced but Splynek.app missing at expected path." >&2
    exit 1
fi

echo
echo "• Archive complete: $ARCHIVE_PATH"
echo "  Size:            $(du -sh "$ARCHIVE_PATH" | awk '{print $1}')"
echo "  Signing:         $(codesign -dv "$ARCHIVE_PATH/Products/Applications/Splynek.app" 2>&1 | grep -E 'Authority|Signature' | head -2 | tr '\n' ' ')"
echo
cat <<EOF

Next steps:

  1. Open Xcode Organizer to validate + upload:
         open $ARCHIVE_PATH
     Or from CLI:
         open -a Xcode $ARCHIVE_PATH

  2. Validate App (in Organizer): confirms signing, entitlements,
     icons, Info.plist keys match App Store Connect expectations.

  3. Distribute App → App Store Connect → Upload. Once uploaded, the
     archive appears in ASC → TestFlight and ASC → App Store within
     5–15 minutes.

  4. Alternative — fully-automated upload via Transporter-style CLI:

         xcodebuild -exportArchive \\
             -archivePath $ARCHIVE_PATH \\
             -exportPath build/Splynek-MAS-Export \\
             -exportOptionsPlist Scripts/export-options-mas.plist
         # then:
         xcrun altool --upload-package \\
             build/Splynek-MAS-Export/Splynek.pkg \\
             --type macos \\
             --apple-id YOUR@APPLE.ID \\
             --team-id 58C6YC5GB5 \\
             --password "@keychain:AC_PASSWORD"

     (Requires an app-specific password at appleid.apple.com for
     altool; Xcode Organizer path is simpler for first submission.)

  5. Review notes + screenshots + description: see MAS_LISTING.md.

EOF
