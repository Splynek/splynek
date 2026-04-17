import AppKit
import SwiftUI

/// Menu-bar status item.
///
/// Two layers of UI live on the status button:
///
/// 1. **Left-click** opens an `NSPopover` with a minimal "paste URL →
///    download / queue" surface. Lets the user hand a URL to Splynek
///    without bringing the main window up — the defining affordance of
///    background-first mode.
/// 2. **Right-click** (or ctrl-click) pops up a context menu with
///    *Show Splynek*, *Cancel All*, and *Quit*.
///
/// Dropping a URL (or plain-text magnet / HTTP URL) onto the status
/// item routes to the same ingest closure the popover uses. This means
/// Splynek is reachable from the desktop even when the window is
/// hidden — drag a link out of Safari onto the menu bar icon, done.
///
/// Wired via two callbacks rather than direct VM access so the controller
/// stays UI-framework-independent.
@MainActor
final class MenuBarController {

    private let item: NSStatusItem
    private var timer: Timer?
    private var source: () -> (throughput: Double, active: Int, seedingPeers: Int, fraction: Double)
    private let popover = NSPopover()
    private var dragView: MenuBarDragView?

    /// Called with a dragged / pasted / typed input. Pure passthrough to
    /// the VM's `handleDrop(providers:)` or equivalent ingestion path.
    var onIngest: ((String) -> Void)?
    /// Called when the user picks *Cancel All* from the context menu.
    var onCancelAll: (() -> Void)?

    init(source: @escaping () -> (Double, Int, Int, Double)) {
        self.source = source
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        configurePopover()
        render()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.render() }
        }
    }

    deinit {
        timer?.invalidate()
        NSStatusBar.system.removeStatusItem(item)
    }

    // MARK: Configuration

    private func configureButton() {
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Drag overlay that fills the button and accepts URL / text drops.
        let drag = MenuBarDragView(frame: button.bounds)
        drag.autoresizingMask = [.width, .height]
        drag.onIngest = { [weak self] raw in
            self?.onIngest?(raw)
            self?.showBriefAcceptHint()
        }
        button.addSubview(drag)
        dragView = drag
    }

    private func configurePopover() {
        popover.behavior = .transient      // auto-dismiss on outside click
        popover.animates = true
    }

    // MARK: Click handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp ||
            (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        if isRight {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        let host = NSHostingController(
            rootView: MenuBarDropView(
                onIngest: { [weak self] raw in
                    self?.onIngest?(raw)
                    self?.popover.performClose(nil)
                },
                onOpenMain: { [weak self] in
                    self?.showMain()
                    self?.popover.performClose(nil)
                }
            )
        )
        host.view.frame = NSRect(x: 0, y: 0, width: 340, height: 170)
        popover.contentViewController = host
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Splynek",
                     action: #selector(showMainAction(_:)),
                     keyEquivalent: "").target = self
        menu.addItem(.separator())
        let cancel = menu.addItem(withTitle: "Cancel All Downloads",
                                  action: #selector(cancelAllAction(_:)),
                                  keyEquivalent: "")
        cancel.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Splynek",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        // Popup positioning: directly under the status button.
        guard let button = item.button else { return }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 4),
                   in: button)
    }

    @objc private func showMainAction(_ sender: Any?) { showMain() }

    @objc private func cancelAllAction(_ sender: Any?) { onCancelAll?() }

    private func showMain() {
        // If we're in accessory mode, temporarily surface the dock icon
        // so `activate(ignoringOtherApps:)` actually focuses us. We leave
        // the policy at .regular once the user interacts; the
        // BackgroundModeController restores .accessory next time they
        // opt back in via preferences.
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        (NSApp.windows.first { $0.canBecomeMain } ?? NSApp.windows.first)?
            .makeKeyAndOrderFront(nil)
    }

    /// Briefly flash the button title green after a successful drop so
    /// the user has visual confirmation without the popover opening.
    private func showBriefAcceptHint() {
        guard let button = item.button else { return }
        let prev = button.attributedTitle
        let accepted = NSAttributedString(
            string: "✓ queued",
            attributes: [.foregroundColor: NSColor.systemGreen]
        )
        button.attributedTitle = accepted
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            button.attributedTitle = prev
            self?.render()
        }
    }

    // MARK: Rendering

    private func render() {
        let (bps, active, seedingPeers, fraction) = source()
        let button = item.button
        guard let button else { return }
        if active == 0 && seedingPeers == 0 {
            button.title = "Splynek"
            button.image = nil
            return
        }
        let parts: [String] = [
            active > 0 ? "↓\(Self.rateShort(bps))" : nil,
            active > 0 ? "×\(active)" : nil,
            seedingPeers > 0 ? "↑\(seedingPeers) peers" : nil
        ].compactMap { $0 }
        button.title = parts.joined(separator: "  ")
        button.image = active > 0 ? Self.progressIcon(fraction: fraction) : nil
        button.imagePosition = .imageLeading
    }

    private static func progressIcon(fraction: Double) -> NSImage {
        let size = NSSize(width: 22, height: 10)
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 1)
        let clamped = max(0, min(1, fraction))
        NSColor.secondaryLabelColor.withAlphaComponent(0.35).setStroke()
        let track = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        track.lineWidth = 1
        track.stroke()
        if clamped > 0 {
            let filledWidth = max(2, rect.width * clamped)
            let filled = NSRect(x: rect.minX, y: rect.minY,
                                width: filledWidth, height: rect.height)
            NSColor.labelColor.withAlphaComponent(0.85).setFill()
            NSBezierPath(roundedRect: filled, xRadius: 3, yRadius: 3).fill()
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func rateShort(_ bps: Double) -> String {
        let units: [(Double, String)] = [(1_000_000_000, "GB/s"), (1_000_000, "MB/s"), (1_000, "KB/s")]
        for (threshold, unit) in units where bps >= threshold {
            return String(format: "%.1f%@", bps / threshold, unit)
        }
        return String(format: "%.0fB/s", bps)
    }
}

// MARK: - Drag overlay

/// Transparent NSView installed on top of the status button. Registers
/// for URL / text / fileURL drags. Forwards the dropped content as a
/// raw string to the injected `onIngest` callback; the VM's regular
/// ingest path (magnet vs. http URL vs. .torrent file URL) takes it
/// from there.
private final class MenuBarDragView: NSView {
    var onIngest: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.URL, .fileURL, .string])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL],
           let first = urls.first {
            onIngest?(first.absoluteString)
            return true
        }
        if let s = pb.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !s.isEmpty {
            onIngest?(s)
            return true
        }
        return false
    }
}

// MARK: - Popover content

private struct MenuBarDropView: View {
    let onIngest: (String) -> Void
    let onOpenMain: () -> Void

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.tint)
                Text("Paste a URL or magnet")
                    .font(.headline)
                Spacer()
                Button {
                    onOpenMain()
                } label: {
                    Image(systemName: "rectangle.stack")
                        .help("Open main window")
                }
                .buttonStyle(.borderless)
            }

            TextField("https://… or magnet:?…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .focused($focused)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            focused ? Color.accentColor.opacity(0.6)
                                    : Color.primary.opacity(0.12),
                            lineWidth: focused ? 1.2 : 0.5
                        )
                )
                .onSubmit { submit() }

            HStack(spacing: 8) {
                Button {
                    submit()
                } label: {
                    Label("Start", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    submit(queueOnly: true)
                } label: {
                    Label("Queue", systemImage: "line.3.horizontal.decrease.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("Tip: drag any link onto the menu bar icon.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 340, height: 170)
        .onAppear { focused = true }
    }

    private func submit(queueOnly: Bool = false) {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        if queueOnly, raw.hasPrefix("http") {
            // Mirror the splynek://queue ingest action by routing a
            // specially-marked string. The VM distinguishes by checking
            // the first character — we just pass through for now; the
            // default ingest calls `start()` implicitly for http URLs.
            // Full queue semantics stay on the main UI.
        }
        onIngest(raw)
        text = ""
    }
}
