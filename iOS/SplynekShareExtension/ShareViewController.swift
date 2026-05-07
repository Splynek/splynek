// Copyright © 2026 Splynek. MIT.
//
// ShareViewController — the Share-Extension entry point.
//
// Apple's Share Extension API is built around UIViewController.  We
// host a SwiftUI sheet inside it via UIHostingController, but the
// extension lifecycle (loadView, didSelectPost, didSelectCancel) lives
// here at the UIKit layer.
//
// What this does:
//
//   1. Reads NSExtensionItem.attachments, walks each NSItemProvider,
//      and asks for any URL-shaped or text-shaped payload.
//   2. Hands those payloads to ShareExtractor.bestURL(...) for the
//      canonical URL.
//   3. Shows a SwiftUI sheet with: the URL preview, the paired-Mac
//      picker (pre-selecting the most-recent), and a Send button.
//   4. On Send, POSTs to the Mac's /api/queue endpoint via
//      PairedMacClient and dismisses with completeRequest.
//
// Failure modes:
//   - No URL found        → show "Couldn't find a URL to share"
//   - No paired Mac       → show "Open Splynek Companion first to pair a Mac"
//   - Mac unreachable     → show retry option
//   - Mac returned 401    → flag the pairing as needing refresh
//
// Apple gives extensions ~30 seconds before iOS terminates them; the
// PairedMacClient uses a 5-second timeout so we have headroom.

#if canImport(UIKit)
import UIKit
import SwiftUI

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await present() }
    }

    @MainActor
    private func present() async {
        let extracted = await extractCandidates()
        let url = ShareExtractor.bestURL(from: extracted)

        let store = PairedMacStore()
        let macs = store?.all() ?? []

        let host = UIHostingController(
            rootView: ShareSheetView(
                url: url,
                macs: macs,
                onSend: { [weak self] selected, target in
                    Task { @MainActor in
                        await self?.send(target, to: selected)
                    }
                },
                onCancel: { [weak self] in
                    self?.cancelRequest()
                }
            )
        )
        host.modalPresentationStyle = .pageSheet
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    /// Walk the extension input items + their NSItemProvider list,
    /// asking each provider for `public.url`, `public.plain-text`, or
    /// `public.text` payloads.  Returns the raw `Any?` results;
    /// ShareExtractor turns them into a canonical URL.
    private func extractCandidates() async -> [Any?] {
        var collected: [Any?] = []
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return collected
        }
        for item in items {
            for provider in item.attachments ?? [] {
                for typeID in ["public.url", "public.plain-text", "public.text"] {
                    if provider.hasItemConformingToTypeIdentifier(typeID) {
                        let payload = await loadProvider(provider, typeID: typeID)
                        collected.append(payload)
                    }
                }
            }
        }
        return collected
    }

    private func loadProvider(_ provider: NSItemProvider, typeID: String) async -> Any? {
        await withCheckedContinuation { (cont: CheckedContinuation<Any?, Never>) in
            provider.loadItem(forTypeIdentifier: typeID, options: nil) { value, _ in
                cont.resume(returning: value)
            }
        }
    }

    @MainActor
    private func send(_ url: URL, to mac: PairedMac) async {
        do {
            try await PairedMacClient(mac: mac).queue(url: url)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            // Surface failures via a quick alert.  More polished UX
            // (toast / retry on different Mac) lives in phase 2.
            let alert = UIAlertController(
                title: "Couldn't reach \(mac.displayName)",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.cancelRequest()
            })
            present(alert, animated: true)
        }
    }

    private func cancelRequest() {
        let err = NSError(domain: "app.splynek.companion", code: 0)
        extensionContext?.cancelRequest(withError: err)
    }
}
#endif
