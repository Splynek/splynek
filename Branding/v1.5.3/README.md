# Branding/v1.5.3 — Press kit assets

This directory holds the v1.5.3 press / landing screenshots.  It's
empty by default; populate with:

```sh
cd "/Users/pcgm/Claude Code"
./Scripts/capture-screenshots.sh
```

The script walks you through 10 named captures, each ~30 seconds:

| File | Tab | What to set up |
|---|---|---|
| `01-sidebar-tints.png` | (any) | Sidebar visible, click any row so the highlight + StatusPill inversion shows |
| `02-trust-empty.png` | Trust | Empty state ("Public-record audit of your apps" + Scan my Mac) |
| `03-trust-results.png` | Trust | Click Scan, wait, capture the results list |
| `04-trust-detail.png` | Trust | Expand "Details + alternatives" on a high-risk row (Messenger / TikTok / LastPass) |
| `05-sovereignty-results.png` | Sovereignty | Scanned + showing matched apps |
| `06-sovereignty-european-filter.png` | Sovereignty | Click "European only" filter |
| `07-downloads-multiInterface.png` | Downloads | Live download with multi-NIC throughput rows |
| `08-concierge-prompt.png` | Concierge (Pro) | Local LLM running, prompt entered |
| `09-recipes-pro.png` | Recipes | Pro-active or locked-upsell view |
| `10-fleet-discovery.png` | Fleet | Peer list (or empty state) |

## After capturing

1. Preview them (`open *.png`) and re-shoot any with cursor-in-frame
   issues, mid-animation glitches, or wrong scroll position.
2. Compress for the press kit (Apple's macOS keynote-style standard
   is ~150 KB per image):
   ```sh
   for f in *.png; do
       sips -Z 1280 "$f" --out compressed/"$f"
   done
   ```
3. The press templates in `PRESS_KIT.md` reference these files for
   inline embedding.

## Notes

- Each capture is a real running Splynek instance with real installed
  apps showing in scan results.  Don't fake screenshots — reviewers
  WILL try the app and notice if Trust/Sovereignty entries don't
  match what you advertised.
- For the Trust scan, ideally have a real "messy" Mac (some Adobe,
  Microsoft, Google apps installed) so the score badges show variety.
- Use macOS in **Light Mode** for press shots — easier to embed in
  press articles regardless of their site theme.
- Window size 1280×800 (the script sets this) hits the press-friendly
  Retina sweet spot — fits in a typical article column without being
  too dense.
