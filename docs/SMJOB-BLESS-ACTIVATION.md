# SMJobBless v1.8.2 — Activation runbook

> Companion to [`SMJOB-BLESS-DESIGN.md`](SMJOB-BLESS-DESIGN.md).  The
> design doc is the architecture; this is the **maintainer's
> step-by-step runbook** for turning the helper bundle on for actual
> users (it's currently unreached because the helper isn't built yet
> — every `PkgInstaller.install(requireAdmin: true)` call returns
> `.helperUnavailable` and falls through to v1.8.1 osascript).

## Status today

The helper plumbing is fully wired across **9 files**, with no missing
glue:

| File | Role | Bundle-ID present |
|---|---|---|
| `project.yml` (lines 207–230) | XcodeGen target declaration + app's `SMPrivilegedExecutables` key + reciprocal `embed: true` | `app.splynek.Splynek.helper` |
| `project.yml` (line 251) | Helper's `PRODUCT_BUNDLE_IDENTIFIER` | same |
| `project.yml` (lines 257–260) | `OTHER_LDFLAGS` `-sectcreate __TEXT __launchd_plist` | same |
| `Sources/SplynekHelper/main.swift` | Listener bring-up, signing-anchor enforcement | via constant |
| `Sources/SplynekHelper/HelperListenerDelegate.swift` | NSXPCListener delegate, connection-validation | via protocol |
| `Sources/SplynekHelper/HelperService.swift` | Authorization re-check, installer(8) spawn | n/a |
| `Sources/SplynekHelper/Info.plist` | `CFBundleIdentifier` + `SMAuthorizedClients` requirement | `app.splynek.Splynek.helper` |
| `Sources/SplynekHelper/app.splynek.Splynek.helper.plist` | launchd Label + `MachServices` | same |
| `Sources/SplynekHelper/SplynekHelper.entitlements` | Empty — helper runs unsandboxed by design | n/a |
| `Sources/SplynekCore/SplynekHelperProtocol.swift` (line 83) | Shared `SplynekHelperMachServiceName` constant | same |
| `Sources/SplynekCore/Installer/PrivilegedHelperClient.swift` | App-side XPC client + Authorization-rights flow | same |

Cross-direction code-signing requirements:

- **App → helper** (`SMPrivilegedExecutables` in `project.yml`):
  `anchor apple generic and identifier "app.splynek.Splynek.helper" and certificate leaf[subject.OU] = "58C6YC5GB5"`
- **Helper → app** (`SMAuthorizedClients` in `Info.plist`):
  `anchor apple generic and identifier "app.splynek.Splynek" and certificate leaf[subject.OU] = "58C6YC5GB5"`

Both anchor to Apple Developer Team ID `58C6YC5GB5`.  This is fine
for MAS — Apple Distribution leaf certs share the same OU as the
team's Developer ID certs.  See the **Optional: pin to leaf
SubjectKeyIdentifier** section below if you'd rather pin per-cert.

## Pre-flight

```bash
# 1. xcodegen installed
which xcodegen || brew install xcodegen

# 2. Apple-Distribution + helper-signing identities visible
security find-identity -p codesigning -v | grep -E "Apple Distribution|Developer ID Application"
# Expect at least:
#   <hash> "Apple Distribution: Paulo Moura (58C6YC5GB5)"
#   <hash> "Developer ID Application: Paulo Moura (58C6YC5GB5)"

# 3. provisioning profile for app.splynek.Splynek.helper exists
ls ~/Library/MobileDevice/Provisioning\ Profiles/ | head -5
# Apple's "automatic signing" handles the helper profile in step 5.
```

## Step 1 — generate the Xcode project

```bash
cd "/Users/pcgm/Claude Code"
xcodegen generate
# Expect: "Generated project successfully"
```

Verify the helper target landed:

```bash
xcodebuild -project Splynek.xcodeproj -list | grep -E "Splynek$|Splynek-MAS|SplynekHelper"
# Expect three lines.
```

## Step 2 — build the helper target standalone (smoke check)

```bash
xcodebuild -project Splynek.xcodeproj \
           -scheme SplynekHelper \
           -configuration Release \
           -derivedDataPath build/SMJobBless-smoke \
           build
```

Verify the binary has the launchd plist embedded:

```bash
otool -s __TEXT __launchd_plist \
  build/SMJobBless-smoke/Build/Products/Release/SplynekHelper \
  | grep -A1 "Contents of"
# Expect: section is non-empty (a couple hundred bytes of plist hex).
```

If the section is empty, the `OTHER_LDFLAGS` `-sectcreate` from
`project.yml` line 257–260 didn't fire — check the path is correct
and re-generate.

## Step 3 — build the full Splynek-MAS app

```bash
xcodebuild -project Splynek.xcodeproj \
           -scheme Splynek-MAS \
           -configuration Release \
           -derivedDataPath build/MAS \
           archive -archivePath build/MAS/Splynek-MAS.xcarchive
```

Verify the helper landed inside the app bundle:

```bash
APP="build/MAS/Splynek-MAS.xcarchive/Products/Applications/Splynek.app"
test -x "$APP/Contents/Library/LaunchServices/SplynekHelper" \
  && echo "✓ helper executable embedded" \
  || echo "✗ MISSING — check 'embed: true' under app target's dependencies in project.yml"
```

Verify the helper signed cleanly:

```bash
codesign -dvvv "$APP/Contents/Library/LaunchServices/SplynekHelper" 2>&1 \
  | grep -E "Authority|Identifier|TeamIdentifier"
# Expect:
#   Identifier=app.splynek.Splynek.helper
#   TeamIdentifier=58C6YC5GB5
#   Authority=Apple Distribution: Paulo Moura (58C6YC5GB5)
```

Verify the cross-direction requirements satisfy:

```bash
# App's SMPrivilegedExecutables requirement satisfied by the embedded helper
codesign --test-requirement \
  '=anchor apple generic and identifier "app.splynek.Splynek.helper" and certificate leaf[subject.OU] = "58C6YC5GB5"' \
  "$APP/Contents/Library/LaunchServices/SplynekHelper"
# Expect: "test-requirement: satisfies its Designated Requirement"

# Helper's SMAuthorizedClients requirement satisfied by the app
codesign --test-requirement \
  '=anchor apple generic and identifier "app.splynek.Splynek" and certificate leaf[subject.OU] = "58C6YC5GB5"' \
  "$APP"
# Expect: same.
```

If either test-requirement fails: the OU mismatched (most likely) —
the maintainer's signing identity isn't `58C6YC5GB5`.  Update both
`project.yml` line 208 and `Sources/SplynekHelper/Info.plist` line 33
to your team ID.

## Step 4 — install + first-time approval

Install the built app to `/Applications`:

```bash
ditto "$APP" /Applications/Splynek.app
```

Launch it manually (Finder).  In the app, do anything that triggers
`PkgInstaller.install(requireAdmin: true)`.  The shortest path: drop
a system-domain `.pkg` (e.g., a Microsoft Office update) onto the
Install tab + click Install.

**Expected first-launch sequence:**

1. App calls `PrivilegedHelperClient.installHelperIfNeeded()`
2. `SMAppService.daemon(plistName:).register()` fires
3. macOS shows: *"Splynek would like to add a Login Item"* — approve
4. macOS may also open System Settings → Login Items & Extensions —
   the helper appears as a toggleable daemon; ensure it's on
5. `PrivilegedHelperClient.installPkg` makes the XPC call
6. macOS shows the standard auth dialog (Touch ID / password) for the
   `app.splynek.Splynek.installPkg` right
7. Helper spawns `/usr/sbin/installer -pkg <path> -target /` as root
8. Install succeeds, app shows "Installed" in `InstallView`

If any step hangs or errors, see **Troubleshooting** below.

## Step 5 — automated smoke test against a sample .pkg

Build a tiny do-nothing .pkg for testing without depending on a
publisher's actual installer:

```bash
mkdir -p /tmp/smjobbless-smoke/payload/usr/local/share
echo "smoke" > /tmp/smjobbless-smoke/payload/usr/local/share/splynek-smoke.txt

pkgbuild --root /tmp/smjobbless-smoke/payload \
         --identifier app.splynek.smjobbless-smoke \
         --version 1.0 \
         --install-location / \
         /tmp/smjobbless-smoke/SplynekSmoke.pkg

# Sign it so InstallVerification's Gatekeeper check passes.
productsign --sign "Developer ID Installer: Paulo Moura (58C6YC5GB5)" \
            /tmp/smjobbless-smoke/SplynekSmoke.pkg \
            /tmp/smjobbless-smoke/SplynekSmoke-signed.pkg

# Compute the SHA-256 the InstallSpec needs.
shasum -a 256 /tmp/smjobbless-smoke/SplynekSmoke-signed.pkg
```

Drop the signed .pkg onto Splynek's Install tab.  Expected outcome:
helper-elevated install succeeds, `/usr/local/share/splynek-smoke.txt`
exists.  Clean up:

```bash
sudo rm -f /usr/local/share/splynek-smoke.txt
sudo pkgutil --forget app.splynek.smjobbless-smoke
```

## Optional: tighten the requirement strings

The current OU-based anchor is permissive — it accepts any future
cert in the same team.  Two harder-to-spoof variants to consider only
if Apple flags the OU anchor in MAS review (none of this is the
default; the OU anchor is what every Apple sample helper uses):

1. **Pin to the specific cert hash.**  `codesign -dr -` against your
   signed app prints its current Designated Requirement, including a
   `H"…"` hex blob that's the Apple-Distribution leaf cert hash.
   Copy that into both `SMPrivilegedExecutables` and
   `SMAuthorizedClients`.  Tradeoff: every cert rotation breaks
   helper compatibility — users who upgrade past your rotation can't
   use the helper until they re-download a re-signed app.
2. **Add an `info[CFBundleShortVersionString] >= "..."` clause** so
   older versions of the app can't talk to a newer helper.  Useful
   only if you ship a breaking helper-protocol change; ignore until
   then.

For the canonical SecRequirement language reference, see Apple's
[TN2206 — Code Signing Tasks](https://developer.apple.com/library/archive/technotes/tn2206/_index.html).
Don't hand-edit the requirement string without testing via
`codesign --test-requirement` (Step 3 of this runbook).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `SMAppService.register()` returns `.requiresApproval` and never flips to `.enabled` | User dismissed the System Settings approval | `installHelperIfNeeded()` already calls `openSystemSettingsLoginItems()` — instruct the user to enable the toggle |
| `xpcConnectionFailed("XPC error: Couldn't find an instance of …")` | Helper signed by a different team than the app | Rebuild both with the same identity; verify with `codesign -dvvv` |
| Helper registers but `installPkg` hangs forever | Helper crashed silently — check `log show --predicate 'subsystem == "com.apple.SMAppService"' --last 5m` | Inspect `HelperService.installPkg`'s stderr handler — usually a missing entitlement or a target validation failure |
| `errAuthorizationCanceled` even when user approved Touch ID | The right `app.splynek.Splynek.installPkg` was added to `/etc/authorization` with restrictive default — check `security authorizationdb read app.splynek.Splynek.installPkg` | Either remove the right (`security authorizationdb remove`) so the system default applies, or set it to `authenticate-admin` explicitly |
| `installer: The package XYZ is signed with an invalid certificate` | The smoke-test .pkg was signed with `Developer ID Application` instead of `Developer ID Installer` | `productsign` requires the Installer cert specifically |
| Both anchors satisfy locally but `register()` errors in TestFlight / MAS | Apple Distribution leaf certs sometimes diverge from the local Apple Development chain — see "Optional: pin to leaf SubjectKeyIdentifier" above |

## When to flip the activation switch

Today's posture (`PkgInstaller` falls through to v1.8.1 osascript on
`.helperUnavailable`) is **safe to ship**.  No user is missing
functionality; the osascript path works for every admin-domain .pkg
the user is likely to encounter.

Activate the helper when **any** of these triggers fires:

1. Apple flags `do shell script with administrator privileges` in
   Resolution Center (would arrive via App Review communication).
2. Apple deprecates AppleScript admin-elevation in a WWDC
   announcement (12+ month signal).
3. Splynek ships a feature that needs persistent admin-daemon
   operation (background privileged port-binding for non-loopback
   fleet, system-extension activation, kext loading).

Until then, the helper is dormant by design: every commit is
green, every test passes, and the v1.8.1 path serves users.
