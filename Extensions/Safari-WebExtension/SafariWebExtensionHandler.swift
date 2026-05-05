import SafariServices
import os.log

/// Strategy Bet S5 — Safari WebExtension handler.
///
/// Apple requires Safari extensions to be packaged as `.appex` bundles
/// inside a host app.  The host app (Splynek itself) declares the
/// extension; macOS installs it when the user opens
/// Safari → Settings → Extensions and ticks "Splynek".
///
/// This handler is the bridge between the WebExtension's JavaScript
/// (which runs in Safari's WKWebView) and any native APIs we need —
/// today there are NONE.  All extension logic lives in the bundled
/// JS files (background.js / popup.js / options.js); this Swift
/// stub just satisfies Apple's appex contract.
///
/// If we later need to call native Splynek APIs from the extension
/// (e.g., a "show in Splynek History" action that needs to ping the
/// running app's MCP endpoint), this is where that bridge lives.
/// For now the JS uses the splynek:// URL scheme + chrome.storage
/// for everything, so this stays a pure shim.
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    private static let log = Logger(subsystem: "app.splynek.Splynek.SafariWebExtension",
                                    category: "Handler")

    func beginRequest(with context: NSExtensionContext) {
        // The native handler currently has nothing to do.  Apple's
        // sample stubs typically echo a hello-world message back —
        // we drop it on the floor because no JS callers exist that
        // talk to native via runtime.sendNativeMessage.  If a future
        // version of the extension needs that bridge, build the
        // request handling here.
        Self.log.debug("Safari extension native handler invoked (no-op)")
        let response = NSExtensionItem()
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
