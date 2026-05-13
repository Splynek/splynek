#!/usr/bin/env bash
# release-smoke.sh — verify a freshly-built DMG actually launches.
#
# Why this exists: v2.0.0 shipped with `com.apple.security.app-sandbox
# = true` + iCloud container entitlements but no provisioning profile.
# The signature passed.  Notarisation passed.  Launchd refused to spawn
# the binary on every fresh user machine with `RBSRequestErrorDomain
# Code=5 / POSIX 163`.  The only way to catch that was to *launch the
# app*.  This script bakes that step into the release runbook so it
# can never silently happen again.
#
# What it does (in order):
#   1.  Verify build/Splynek.dmg exists and is a valid DMG.
#   2.  Verify codesign + Gatekeeper accept the .app inside.
#   3.  Mount the DMG, copy the .app to /tmp/, unmount.
#   4.  `open` the /tmp/ copy.
#   5.  Wait up to 10 s for the process to be alive AND for the
#       HTTP listener to bind a port.
#   6.  Activate the app, wait, assert a window is visible.
#   7.  Kill the process, clean /tmp/, report pass/fail.
#
# Exit codes:
#   0  — every assertion passed
#   1  — DMG missing / corrupt
#   2  — codesign or Gatekeeper rejection
#   3  — Launchd refused to spawn (POSIX 163-style failure)
#   4  — process spawned but never bound HTTP listener
#   5  — process bound listener but never opened a window
#
# Usage (typical release flow):
#     ./Scripts/build.sh release
#     ./Scripts/dmg.sh
#     # notarise + staple ...
#     ./Scripts/release-smoke.sh        # ← MUST PASS before tagging
#     git tag -a vX.Y.Z ...

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DMG="${DMG:-build/Splynek.dmg}"
APP_NAME="${APP_NAME:-Splynek}"
TEST_DIR="/tmp/splynek-smoke-$$"
TIMEOUT_SECS="${TIMEOUT_SECS:-15}"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

cleanup() {
    # Kill any /tmp/-launched Splynek before tearing down.
    pkill -f "$TEST_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    # Detach any leftover Splynek-2.* volume we mounted.
    for vol in /Volumes/Splynek*; do
        case "$vol" in
            *Splynek*)
                hdiutil detach "$vol" -force 2>/dev/null || true
                ;;
        esac
    done
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

bold "▶ release-smoke.sh — verifying $DMG launches end-to-end"
echo

# ────────────────────────────────────────────────────────────────────
# 1. DMG presence + format
# ────────────────────────────────────────────────────────────────────
if [[ ! -f "$DMG" ]]; then
    red "✗ $DMG not found.  Run ./Scripts/build.sh && ./Scripts/dmg.sh first."
    exit 1
fi
if ! hdiutil verify "$DMG" >/dev/null 2>&1; then
    red "✗ $DMG fails hdiutil verify (corrupt)."
    exit 1
fi
green "✓ DMG present + verifies"

# ────────────────────────────────────────────────────────────────────
# 2. Mount + Gatekeeper check on the .app inside
# ────────────────────────────────────────────────────────────────────
MOUNT_OUTPUT="$(hdiutil attach "$DMG" -nobrowse -noverify 2>&1 || true)"
# Volume names can contain spaces ("Splynek 2.0.1"), so the
# mount-point token is the final tab-delimited field of the line
# whose last column starts with /Volumes/.  Awk on tab keeps it
# resilient to multi-word volume names.
MOUNT_POINT="$(echo "$MOUNT_OUTPUT" \
    | awk -F'\t' '$NF ~ /^\/Volumes\// { print $NF; exit }')"
if [[ -z "$MOUNT_POINT" ]] || [[ ! -d "$MOUNT_POINT" ]]; then
    red "✗ Couldn't mount $DMG"
    echo "$MOUNT_OUTPUT"
    exit 1
fi

MOUNTED_APP="$MOUNT_POINT/$APP_NAME.app"
if [[ ! -d "$MOUNTED_APP" ]]; then
    red "✗ $APP_NAME.app not found inside mounted DMG"
    hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || true
    exit 1
fi

CS_VERIFY="$(codesign --verify --deep --strict "$MOUNTED_APP" 2>&1 || echo "FAIL")"
if [[ "$CS_VERIFY" == *FAIL* ]]; then
    red "✗ codesign rejects mounted .app:"
    echo "$CS_VERIFY"
    hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || true
    exit 2
fi

SPCTL_OUTPUT="$(spctl -a -t exec -vv "$MOUNTED_APP" 2>&1)"
if ! echo "$SPCTL_OUTPUT" | grep -q "accepted"; then
    red "✗ Gatekeeper rejects mounted .app:"
    echo "$SPCTL_OUTPUT"
    hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || true
    exit 2
fi
green "✓ codesign + Gatekeeper accept the .app inside the DMG"
echo "  $SPCTL_OUTPUT" | sed 's/^/    /'

# ────────────────────────────────────────────────────────────────────
# 3. Copy to /tmp/ and unmount
# ────────────────────────────────────────────────────────────────────
mkdir -p "$TEST_DIR"
cp -R "$MOUNTED_APP" "$TEST_DIR/"
hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1
green "✓ Copied to $TEST_DIR/$APP_NAME.app"

# ────────────────────────────────────────────────────────────────────
# 4. Try to launch.  This is the v2.0.0-fail check.
# ────────────────────────────────────────────────────────────────────
# Kill any pre-existing instance first so PID detection is unambiguous.
pkill -f "MacOS/$APP_NAME$" 2>/dev/null || true
sleep 1

OPEN_OUTPUT="$(open "$TEST_DIR/$APP_NAME.app" 2>&1 || echo "OPEN_FAILED")"
if [[ "$OPEN_OUTPUT" == *OPEN_FAILED* ]] || [[ "$OPEN_OUTPUT" == *"Launchd job spawn failed"* ]]; then
    red "✗ Launchd refused to spawn the .app — likely entitlement-coherence regression"
    echo "  $OPEN_OUTPUT"
    red "  This is exactly the v2.0.0 failure mode.  Inspect Resources/Splynek.entitlements"
    red "  for sandbox + iCloud combos without a provisioning profile."
    exit 3
fi
green "✓ open succeeded — no spawn rejection"

# ────────────────────────────────────────────────────────────────────
# 5. Wait for process + HTTP listener
# ────────────────────────────────────────────────────────────────────
TARGET="$TEST_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
DEADLINE=$(( $(date +%s) + TIMEOUT_SECS ))
PID=""
PORT=""
while [[ $(date +%s) -lt $DEADLINE ]]; do
    PID="$(pgrep -f "$TARGET$" | head -1 || true)"
    if [[ -n "$PID" ]]; then
        PORT="$(lsof -p "$PID" -iTCP -sTCP:LISTEN -P 2>/dev/null \
                | awk 'NR>1 {split($9, a, ":"); print a[length(a)]; exit}')"
        [[ -n "$PORT" ]] && break
    fi
    sleep 0.5
done
if [[ -z "$PID" ]]; then
    red "✗ Process never appeared (PID search of $TARGET)"
    exit 4
fi
if [[ -z "$PORT" ]]; then
    red "✗ Process (PID $PID) running but never bound a TCP listener within ${TIMEOUT_SECS}s"
    exit 4
fi
green "✓ Process alive (PID $PID), HTTP listener bound on port $PORT"

# ────────────────────────────────────────────────────────────────────
# 6. Activate + assert window
# ────────────────────────────────────────────────────────────────────
# Some Splynek builds default to LSUIElement / menubar-style and
# don't create a window until the user activates the app.  Mirror
# that activation via AppleScript so the smoke also verifies the
# WindowGroup actually instantiates.
osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null || true
sleep 2

WINDOW_COUNT=$(osascript -e \
    "tell application \"System Events\" to tell process \"$APP_NAME\" to return (count of windows)" \
    2>/dev/null || echo "0")
if [[ "$WINDOW_COUNT" -lt 1 ]]; then
    red "✗ Process running but never opened a window (got $WINDOW_COUNT)"
    exit 5
fi
green "✓ Window count: $WINDOW_COUNT"

# ────────────────────────────────────────────────────────────────────
# Done
# ────────────────────────────────────────────────────────────────────
echo
green "✓✓✓ release-smoke PASSED — $APP_NAME launches cleanly from the DMG."
echo
echo "  Artifact:    $DMG"
echo "  SHA-256:     $(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "  Size:        $(du -h "$DMG" | cut -f1)"
echo "  Test PID:    $PID (killed by cleanup)"
echo "  Test port:   $PORT"
echo
yellow "Safe to tag the release."
