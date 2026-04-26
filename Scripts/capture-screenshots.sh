#!/usr/bin/env bash
#
# capture-screenshots.sh — semi-automated screenshot capture for the
# v1.5.3 press kit.  Walks you through opening Splynek and capturing
# each tab in a consistent style: dark sidebar, light background,
# 1280×800 window pinned in centre.
#
# Output: Branding/v1.5.3/<name>.png
#
# Why semi-automated: macOS doesn't let scripts capture other apps'
# windows reliably under SIP.  This script:
#   1. Sets the window size + position via osascript
#   2. Pauses for you to navigate to the right tab + scan
#   3. Captures via `screencapture` and saves to the right name
#   4. Loops to the next shot
#
# Run: ./Scripts/capture-screenshots.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Branding/v1.5.3"
mkdir -p "$OUT"

APP_PATH="${SPLYNEK_APP:-$ROOT/build/Splynek.app}"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_PATH not found.  Run ./Scripts/build.sh first," >&2
    echo "       or set SPLYNEK_APP=/Applications/Splynek.app." >&2
    exit 1
fi

# Open Splynek (idempotent — won't double-launch)
echo "→ Opening Splynek…"
open -a "$APP_PATH"
sleep 2

# Resize window to 1280×800 centred (good for press shots — wide enough
# for the sidebar + content, not so wide it fills 5K monitors).
echo "→ Sizing window to 1280×800 centred…"
osascript <<'APPLESCRIPT'
tell application "Splynek" to activate
delay 1
tell application "System Events"
    tell process "Splynek"
        try
            set frontmost to true
            tell window 1
                set position to {320, 140}
                set size to {1280, 800}
            end tell
        end try
    end tell
end tell
APPLESCRIPT

# Capture helper
capture () {
    local name="$1"
    local prompt="$2"
    echo
    echo "═══════════════════════════════════════════════════════════"
    echo "  Capture: $name"
    echo "  Setup:   $prompt"
    echo "═══════════════════════════════════════════════════════════"
    read -p "  Press Enter when ready (or 's' to skip)... " ans
    if [[ "$ans" == "s" ]]; then
        echo "  ↳ skipped"
        return
    fi
    # Window-only capture, no shadow, no cursor
    osascript -e 'tell application "Splynek" to activate' >/dev/null 2>&1 || true
    sleep 1
    # Find the window and capture it
    local wid
    wid=$(osascript -e 'tell application "System Events" to tell process "Splynek" to id of window 1' 2>/dev/null || echo "")
    if [ -n "$wid" ]; then
        screencapture -l "$wid" -o -t png "$OUT/$name.png"
    else
        # Fallback: interactive selection
        screencapture -i -o -t png "$OUT/$name.png"
    fi
    echo "  ↳ saved: $OUT/$name.png"
}

# Reasonably ordered: chrome shots first, then per-feature.
capture "01-sidebar-tints" \
    "Click any tab so the sidebar is highlighted.  Goal: show the per-tab tint variety + the new Settings gear in the brand footer."

capture "02-trust-empty" \
    "Click 'Trust' tab.  The empty state with 'Public-record audit of your apps' heading + 'Scan my Mac' button should be visible."

capture "03-trust-results" \
    "Inside Trust: click 'Scan my Mac'.  Wait for results to populate.  Goal: show the score badges + cited concern pills + the 'Alternatives' section expanded on at least one row."

capture "04-trust-detail" \
    "Click 'Details + alternatives' on a row with multiple high-severity concerns (Messenger, TikTok, LastPass are good candidates).  Show the expanded concern list with primary-source links."

capture "05-sovereignty-results" \
    "Click 'Sovereignty' tab.  If not yet scanned, click 'Scan my Mac'.  Goal: show the result rows + filter chips at the top."

capture "06-sovereignty-european-filter" \
    "Same Sovereignty view, click 'Européennes uniquement' / 'European only' filter chip.  Show only EU alternatives."

capture "07-downloads-multiInterface" \
    "Click 'Downloads' tab.  Paste a large URL (Linux ISO is ideal) and start the download so the per-interface throughput rows are visible."

capture "08-concierge-prompt" \
    "Click 'Concierge' tab (Pro).  If you're on Pro and have Apple Intelligence / Ollama / LM Studio running, type a prompt like 'latest Ubuntu 24.04 ISO'.  Show the response."

capture "09-recipes-pro" \
    "Click 'Recipes' tab.  Either show the unlocked Pro view with a recent recipe, or the locked upsell."

capture "10-fleet-discovery" \
    "Click 'Fleet' tab.  If you have another Splynek on the LAN, capture the peer list; otherwise the 'no peers' state."

echo
echo "═══════════════════════════════════════════════════════════"
echo "Done.  Output in $OUT/"
echo "Files captured:"
ls -1 "$OUT/" 2>/dev/null | grep -E '\.png$' | sed 's/^/  /'
echo
echo "Recommended next:  open $OUT/  to preview, then upload to the"
echo "press kit channels per PRESS_KIT.md."
echo "═══════════════════════════════════════════════════════════"
