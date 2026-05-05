# Splynek — Safari WebExtension

Strategy Bet S5 — Safari parity with the Chrome extension.  Same
two features (manual hand-off + Accelerator intercept), same UX,
ported to Apple's WebExtensions API.

> **Status: scaffolding shipped 2026-05-05.**  The JavaScript +
> manifest are complete and pass `node -c` syntax checks.  The
> appex Swift stub is in place.  The `xcodegen` target wiring to
> produce `Splynek-Safari-Extension.appex` is NOT yet hooked up —
> that's the next step (~30 min of `project.yml` editing + a
> smoke build).  Until then, this directory is read-only design.

## Why a separate directory

Chrome and Safari diverge on several manifest fields:

| Field | Chrome | Safari |
|---|---|---|
| `background` | `service_worker: "background.js"` | `scripts: ["background.js"]` |
| `permissions` | Same | Same |
| `host_permissions` | Same | Same |
| `web_accessible_resources` | Required for Manifest V3 | Optional (Safari is more permissive) |
| Native handler | None | Required `appex` |
| Distribution | Chrome Web Store / unpacked | Mac App Store / TestFlight |

Plus the API namespace: Chrome uses `chrome.*`, Safari uses
`browser.*` (Chrome accepts both since 2022 but Safari doesn't yet
expose the `chrome` global).  The JS files in `Resources/` open
with `const X = (typeof browser !== "undefined") ? browser : chrome;`
so the same source compiles + loads in either browser.

We ship two extension folders rather than one shared directory
because (a) the manifest fields actually differ, (b) the .appex
contract pins file paths inside the Resources/ subdirectory, and
(c) divergence is small enough that double-shipping costs less
than a build-time sharing layer.

## Layout

```
Extensions/Safari-WebExtension/
├── README.md                          ← you are here
├── SafariWebExtensionHandler.swift    ← native appex stub
└── Resources/                         ← the WebExtension itself
    ├── manifest.json
    ├── background.js
    ├── popup.html
    ├── popup.js
    ├── options.html
    ├── options.js
    └── icons/
        ├── icon-16.png
        ├── icon-32.png
        ├── icon-48.png
        └── icon-128.png
```

The JS port: `Resources/background.js` is functionally identical to
`Extensions/Chrome/background.js` with `chrome.*` rewritten to `X.*`
where `X` is the namespace shim.  Same for `popup.js` + `options.js`.

## Next steps to ship

### 1. Wire the appex target in xcodegen (~30 min)

Add to `project.yml` at the same level as the existing
`SplynekHelper` target:

```yaml
  Splynek-Safari-Extension:
    type: app-extension.safari-web-extension
    platform: macOS
    sources:
      - path: Extensions/Safari-WebExtension/SafariWebExtensionHandler.swift
      - path: Extensions/Safari-WebExtension/Resources
        type: folder  # ship as opaque folder so manifest paths resolve
    info:
      path: Extensions/Safari-WebExtension/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.Safari.web-extension
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).SafariWebExtensionHandler
        SFSafariWebExtensionConverterVersion: "16"
    settings:
      base:
        PRODUCT_NAME: SplynekSafariExtension
        PRODUCT_BUNDLE_IDENTIFIER: app.splynek.Splynek.SafariExtension
        CODE_SIGN_ENTITLEMENTS: Extensions/Safari-WebExtension/Splynek-Safari.entitlements
        SKIP_INSTALL: NO
```

Then declare the dependency on the main `Splynek` target:

```yaml
  Splynek:
    dependencies:
      - target: Splynek-Safari-Extension
        copy: true
        codeSign: true
        embed: true
```

### 2. Create the entitlements file

Minimal — Safari WebExtensions need no special entitlements.
`Extensions/Safari-WebExtension/Splynek-Safari.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
</dict>
</plist>
```

### 3. Smoke test

```bash
xcodegen generate
xcodebuild -scheme Splynek -configuration Debug -derivedDataPath build/dd
open build/dd/Build/Products/Debug/Splynek.app
# Then: Safari → Settings → Extensions → tick Splynek
# Then: visit a page, right-click any link → "Download with Splynek"
```

The first invocation triggers Safari's "Allow Splynek to open?"
dialog for the `splynek://` URL scheme.  Tick "Always allow" and
the extension behaves identically to the Chrome version.

### 4. (Optional) Mac App Store distribution

Once shipping the host Splynek app via MAS, the Safari extension
ships inside it automatically — Apple's App Review may flag the
extension's `<all_urls>` host permission for `webRequest`.  Mitigation:
the App Review Notes already explain Splynek is a download manager;
the Accelerator intercept feature description fits the existing
review narrative.

## Why this isn't shipped yet

Three reasons:

1. **Apple v1.0 still in MAS re-review.**  Adding a new bundled
   extension changes the binary's surface; reviewers may want to
   re-evaluate.  Safer to ship the Safari extension AFTER v1.0
   clears + then submit v1.0.1 with the extension included.
2. **xcodegen edits ripple into build-mas.sh.**  Need to validate
   the appex builds + signs cleanly before committing the project.yml
   change to main.
3. **Smoke testing requires a Safari session + manual click-through.**
   Browser apps run tier=read for Claude — I can write the code but
   not drive Safari interactively to verify the install.

The scaffolding committed today gives a clear path to "next session
spends 1 day wiring the xcodegen target + smoke testing"; everything
upstream is done.

## Privacy + permissions

Identical to the Chrome extension — see [Extensions/Chrome/README.md](../Chrome/README.md)
and [Extensions/Chrome/ACCELERATOR-DESIGN.md](../Chrome/ACCELERATOR-DESIGN.md)
for the threat model.  Safari WebExtensions run in the same
isolated WKWebView sandbox as web pages, so the privacy posture
is the same — no native messaging, no cross-origin fetches by us,
splynek:// URL scheme is the integration contract.
