# Splynek admin-domain installer — design doc (v1.8.2 SMJobBless path)

> Status: **design only**. v1.8.1 ships osascript-elevated `installer(8)`
> as the admin path.  This doc plans the v1.8.2 SMJobBless replacement
> for the day osascript-elevation gets flagged in MAS review or the
> macOS sandbox tightens further.  Estimated work: 3–5 days end-to-end.

## TL;DR

- v1.8.1 path: `osascript -e 'do shell script "..." with administrator privileges'` → macOS authorization dialog → `installer(8)` runs as root.  Works today; well-precedented; ships.
- v1.8.2 path: a separate signed helper bundle installed via `SMAppService.daemon` (post-macOS 13) or `SMJobBless` (pre-macOS 13).  Helper holds the privileged install logic; app talks to helper via XPC.
- Both paths use the same `PkgInstaller.install(pkg:target:requireAdmin:)` API surface; `requireAdmin: true` dispatches to whichever helper-tooling Splynek can find / install at runtime.

## Why we need it (eventually)

`AuthorizationExecuteWithPrivileges` was deprecated in macOS 10.7 (2011).  `do shell script ... with administrator privileges` works through the same OS authorization dialog and is widely-used + Apple-accepted in the MAS for now.  But:

- Apple has tightened sandbox policy multiple times since 2020 (NetworkExtension entitlement requirements, Camera/Mic prompts, screen-recording opt-in, etc.).  AppleScript-driven elevation is on the "deprecated-but-tolerated" list and may eventually require a private entitlement.
- A reviewer who reads the codebase carefully and sees `osascript -e "do shell script … with administrator privileges"` may pattern-match it as legacy.
- For "Splynek as a verified installer" positioning, the long-term right answer is a privileged helper Apple actually documents.

## Current state (v1.8.1)

`Sources/SplynekCore/Installer/PkgInstaller.swift` — when `requireAdmin: true`:

```swift
do shell script "/usr/sbin/installer -pkg <quoted-path> -target /"
with administrator privileges
```

User sees: macOS standard authorization dialog with Touch ID / password.

## Target state (v1.8.2)

### Architecture

```
   ┌────────────────────────────────────────────────────────┐
   │  Splynek.app                                           │
   │                                                        │
   │  PkgInstaller.install(requireAdmin: true)              │
   │     │                                                   │
   │     │  1) ensure helper installed (SMAppService.daemon  │
   │     │     .register(); first-run prompts user once)     │
   │     │                                                   │
   │     │  2) connect to helper via XPC                     │
   │     │                                                   │
   │     ▼                                                   │
   │  SplynekHelper.xpcSession                              │
   │     │                                                   │
   └─────┼──────────────────────────────────────────────────┘
         │ XPC
   ┌─────┼──────────────────────────────────────────────────┐
   │  app.splynek.Splynek.helper  (separate signed bundle)  │
   │     │                                                   │
   │     ▼                                                   │
   │  HelperService.installPkg(at: URL, target: String,      │
   │                            authData: AuthorizationRef)  │
   │     │                                                   │
   │     │  Authorization framework verifies the user        │
   │     │  authorised this specific operation.              │
   │     │                                                   │
   │     ▼                                                   │
   │  Process(/usr/sbin/installer)                          │
   │  args: -pkg <path> -target <target>                    │
   │  runs as root (helper is launchd daemon)               │
   │                                                         │
   └─────────────────────────────────────────────────────────┘
```

### Components needed

1. **Helper bundle target** — a separate `.app` (or `.bundle` actually; helpers don't need full app metadata) bundled inside Splynek's Resources/.  Bundle ID: `app.splynek.Splynek.helper`.  Code-signed with Apple Distribution; SMAppService entitlement granted by Apple Developer Program.
2. **Embedded launchd plist** — `Contents/Library/LaunchDaemons/app.splynek.Splynek.helper.plist`.  Defines the helper as a launchd service: `Label = "app.splynek.Splynek.helper"`; `MachServices = { "app.splynek.Splynek.helper" = true }`; `ProgramArguments` points at the helper binary inside the bundle.
3. **App-side install code** — `SMAppService.daemon(plistName: "app.splynek.Splynek.helper.plist").register()` at first need (NOT at app launch — only when the user clicks "Install" against an admin-domain pkg).  Surface the system-wide auth prompt via this call.
4. **App-side XPC client** — `NSXPCConnection` to `app.splynek.Splynek.helper`.  Remote-object protocol declared in a header shared between app + helper.
5. **Helper-side XPC server** — `NSXPCListener.init(machServiceName: "app.splynek.Splynek.helper")`; `delegate` accepts new connections and exports the install protocol.
6. **Helper install logic** — `func installPkg(at: URL, target: String, authData: AuthorizationRef)`.  Verify the Authorization right (`PkgInstaller.adminInstallRight` — define in Authorization plist), then `Process(/usr/sbin/installer)` synchronously, then return result.
7. **Code-signing reciprocal trust** — app's Info.plist `SMPrivilegedExecutables` lists the helper bundle ID + the SHA-256 of its code-signing requirement.  Helper's `Info.plist` `SMAuthorizedClients` lists the app's bundle ID + signing-requirement SHA-256.  Both anchor to Apple Developer Program Team ID `58C6YC5GB5`.

### Protocol shape

```swift
@objc protocol SplynekHelperProtocol {
    func installPkg(
        atPath path: String,
        target: String,
        authData: NSData,                        // AuthorizationCopyData wrapped
        reply: @escaping (Int32, String?) -> Void  // (exitCode, errorMessage)
    )

    func helperVersion(
        reply: @escaping (String) -> Void
    )

    /// Future-proof: the helper can perform other privileged ops
    /// (kext-load, /Library/LaunchDaemons rotate, etc.) — declared
    /// here so the app↔helper protocol stays stable across v1.8.x.
    /// v1.8.2 implements only `installPkg`; others throw "not yet
    /// supported" until the corresponding feature work lands.
}
```

### Failure modes the v1.8.2 PkgInstaller must handle

| Outcome | Surface as | Recovery |
|---|---|---|
| Helper not yet installed → user-cancelled the SMAppService prompt | `Failure.adminDeclined` | Prompt next time |
| Helper installed but XPC connection refused | `Failure.helperUnavailable` (new case) | `SMAppService.uninstall()` → re-register → retry |
| Helper running but installer(8) returned non-zero | `Failure.installerFailed(exitCode:stderr:)` | Pass through to the user |
| Helper running but Authorization right expired | `Failure.adminDeclined` | Re-acquire right |

## Project.yml changes

```yaml
targets:
  Splynek-MAS:
    settings:
      INFO_PLIST_FILE: Resources/Generated-Info-MAS.plist
      # Add to Info.plist programmatically:
      #   SMPrivilegedExecutables = {
      #     "app.splynek.Splynek.helper" =
      #       "anchor apple generic and identifier
      #        \"app.splynek.Splynek.helper\" and
      #        certificate leaf [subject.OU] = \"58C6YC5GB5\""
      #   }

  SplynekHelper:
    type: tool
    platform: macOS
    sources:
      - Sources/SplynekHelper
    info:
      path: Sources/SplynekHelper/Info.plist
      properties:
        CFBundleIdentifier: app.splynek.Splynek.helper
        CFBundleName: SplynekHelper
        CFBundleVersion: $(MARKETING_VERSION)
        SMAuthorizedClients:
          - "anchor apple generic and identifier \"app.splynek.Splynek\" and
             certificate leaf [subject.OU] = \"58C6YC5GB5\""
    settings:
      INSTALL_PATH: $(LOCAL_LIBRARY_DIR)/PrivilegedHelperTools
      SKIP_INSTALL: NO

  Splynek-MAS:
    dependencies:
      - target: SplynekHelper
        copy: true
```

The `copy: true` on the dependency embeds the helper bundle inside `Splynek.app/Contents/Library/LaunchServices/`, which `SMAppService.daemon` reads at register time.

## Step-by-step implementation plan

1. **Day 1 — bundle scaffolding.**  Add `SplynekHelper` target to `project.yml`.  Create `Sources/SplynekHelper/main.swift` with the bare XPC listener.  Local build via `xcodegen generate && xcodebuild -scheme SplynekHelper`.  Verify the helper bundle ends up in `Splynek.app/Contents/Library/LaunchServices/`.
2. **Day 2 — XPC protocol.**  Define `SplynekHelperProtocol.h` (Objective-C header so it can be `@objc`-imported on both sides).  Implement skeleton helper service that returns "not yet implemented" for `installPkg`.  Implement app-side client in a new `Sources/SplynekCore/Installer/PrivilegedHelperClient.swift` that connects + calls `helperVersion` as a smoke test.
3. **Day 3 — Authorization rights.**  Define `app.splynek.Splynek.installPkg` right in `/etc/authorization` via the `AuthorizationDB.set(...)` API on first use.  App side: `AuthorizationCopyRights` requesting that right.  Helper side: `AuthorizationCopyRights(.kAuthorizationFlagExtendRights)` to verify.
4. **Day 4 — installer(8) integration.**  Helper's `installPkg` impl: spawn `/usr/sbin/installer` with `-pkg path -target target`.  Helper runs as root via launchd; no further privilege escalation needed.  Wire to `PkgInstaller.installWithSMJobBlessIfAvailable` as the new admin-domain primary path.
5. **Day 5 — fallback + tests.**  PkgInstaller's `requireAdmin: true` path: try SMJobBless first; on `helperUnavailable` or `adminDeclined`, fall back to the v1.8.1 osascript path (existing code).  Tests: helper-version smoke test, error-path mocking, fallback decision.

## Activation runbook

The implementation plan above describes how the helper was BUILT.
[`SMJOB-BLESS-ACTIVATION.md`](SMJOB-BLESS-ACTIVATION.md) is the
companion runbook for the maintainer turning it ON for users —
xcodegen, xcodebuild, code-signing verification, first-launch
approval flow, smoke-testing against a sample admin .pkg, and
troubleshooting common failures.  Until the activation gate
completes, every `PkgInstaller.install(requireAdmin: true)` call
returns `.helperUnavailable` and falls through to the v1.8.1
osascript path — zero behavioural change for users today.

## Why this is "deferred not skipped"

The v1.8.1 osascript path works for users today.  The v1.8.2 SMJobBless path is the long-term-correct architecture for an MAS app that increasingly needs privileged operations (admin pkg installs, future kext-loaders, future system-extension activations).

Concrete triggers that should prompt v1.8.2 work:
1. MAS reviewer flags `do shell script with administrator privileges` (we'd hear about it through Resolution Center).
2. Apple deprecates AppleScript admin-elevation in a future macOS (announced in a WWDC; would be a 12+ month signal).
3. Splynek ships a feature that needs persistent admin daemon operation (e.g. background privileged port-binding for non-loopback fleet exposure) — that requires the helper anyway.

Until any of those fires, v1.8.1 osascript ships.

## References

- [Apple — Service Management Framework](https://developer.apple.com/documentation/servicemanagement)
- [Apple — Updating Helper Executables from Earlier Versions of macOS](https://developer.apple.com/documentation/servicemanagement/updating-helper-executables-from-earlier-versions-of-macos)
- [SMAppService docs (macOS 13+)](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [WWDC 2022 — What's new in privacy](https://developer.apple.com/videos/play/wwdc2022/10096/) — covers SMAppService introduction
- [SMJobBlessSample (Apple)](https://developer.apple.com/library/archive/samplecode/SMJobBlessXPC/Introduction/Intro.html) — pre-macOS-13 reference; still useful for the XPC protocol shape
