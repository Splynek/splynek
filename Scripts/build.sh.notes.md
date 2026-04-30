# Build-system notes for `Scripts/build.sh`

## v1.6.2 todo: App Intents metadata for SPM-built DMG

The SPM build pipeline does NOT run `appintentsmetadataprocessor`,
so the resulting `.app` ships without `Contents/Resources/Metadata.appintents`.

**Symptom:** Shortcuts.app and Siri can't discover Splynek's App Intents
from the SPM-built DMG. The Intents are present in the binary
(verified via `nm`), but macOS uses the metadata bundle to populate
the Shortcuts gallery — without it, our Intents are invisible.

**Affected Intents** (all 10):
- DownloadURLIntent
- QueueURLIntent
- ParseMagnetIntent
- GetDownloadProgressIntent
- CancelAllDownloadsIntent
- PauseAllDownloadsIntent
- ListRecentHistoryIntent
- LookupSovereigntyIntent  ← v1.6
- LookupTrustIntent  ← v1.6
- RunSovereigntyScanIntent  ← v1.6

**MAS build is fine.** Xcode's build pipeline runs the metadata
processor automatically as a build phase. When v1.0 clears review and
we cut MAS updates, those builds carry `Metadata.appintents` correctly.

**Why the SPM build can't run it as-is:** the processor needs:
- `--swift-const-vals-list <file>` — a list of `.swiftconstvalues`
  files. SwiftPM doesn't emit these by default (Xcode passes
  `-emit-const-values-path` to swiftc as part of the
  AppIntentsMetadataProcessor build phase).
- `--source-file-list <file>` — every `.swift` file that defines an
  AppIntent. We can derive this from `find Sources -name "*.swift"`,
  but only the AppIntent-bearing ones matter.
- `--metadata-file-list <file>` — metadata from dependencies. SPM has
  none of these for our target.
- `--module-name SplynekCore`
- `--sdk-root`, `--toolchain-dir`, `--xcode-version`, `--platform-family`,
  `--deployment-target`, `--target-triple` — all derivable from `xcrun`.

**Implementation sketch:**

```bash
# In Scripts/build.sh, AFTER `swift build --product Splynek`:
SWIFTPM_BUILD_DIR=".build/$(swift build -c $CONFIG --show-bin-path | sed 's|.*/||')"
TOOLCHAIN_DIR="$(xcrun --find swift | sed 's|/usr/bin/swift||')"
SDK_ROOT="$(xcrun --show-sdk-path)"
PROCESSOR="$(xcrun --find appintentsmetadataprocessor)"

# 1. Make swift build emit .swiftconstvalues — needs swift build flag:
#    -Xswiftc -emit-const-values-path -Xswiftc <path>
# 2. Collect them into a list file
# 3. Collect AppIntent source files into another list file
# 4. Invoke the processor
"$PROCESSOR" \
    --output "$APP/Contents/Resources/Metadata.appintents" \
    --toolchain-dir "$TOOLCHAIN_DIR" \
    --module-name SplynekCore \
    --sdk-root "$SDK_ROOT" \
    --xcode-version "$(xcrun xcodebuild -version | head -1 | awk '{print $2}')" \
    --platform-family macOS \
    --deployment-target 13.0 \
    --target-triple arm64-apple-macosx13.0 \
    --source-file-list /tmp/splynek-appintent-sources.txt \
    --swift-const-vals-list /tmp/splynek-swiftconstvalues.txt
```

**Validation that the pipe works:**
```bash
# After build, the .app must contain:
ls build/Splynek.app/Contents/Resources/Metadata.appintents
# And `pluginkit -m -A | grep splynek` should return entries.
```

Filed: 2026-04-30. Estimated effort: 1 hour. Priority: medium —
relevant for the SPM/DMG distribution but the MAS path is unaffected.
