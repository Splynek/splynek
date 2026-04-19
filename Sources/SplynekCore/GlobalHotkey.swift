import AppKit
#if !MAS_BUILD
import Carbon.HIToolbox
#endif

/// Register a global macOS hot key via the legacy Carbon API. Works without
/// accessibility permissions (unlike `CGEvent` tap approaches); hot key
/// fires only while Splynek is running, which is what we want.
///
/// Only one hot key is supported per process; enough for "show Splynek".
///
/// **Not available in the MAS build.** Global hotkeys require the
/// Carbon `RegisterEventHotKey` / AXTrustedCheck flow which App Store
/// review rejects for sandboxed apps. The MAS build exposes `shared`
/// with no-op `install()` / `uninstall()` methods so callers don't
/// need `#if`-guards; the functionality just silently doesn't
/// activate.
#if MAS_BUILD

final class GlobalHotkey {
    static let shared = GlobalHotkey()
    private init() {}
    func install(callback: @escaping () -> Void) { /* MAS: not available */ }
    func uninstall() { /* MAS: not available */ }
}

#else

final class GlobalHotkey {

    static let shared = GlobalHotkey()
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var callback: (() -> Void)?

    /// Install a hot key. Default is ⌘⇧D — ANSI 'D' with command + shift.
    func install(callback: @escaping () -> Void) {
        self.callback = callback
        installHandler()
        register(keyCode: UInt32(kVK_ANSI_D),
                 modifiers: UInt32(cmdKey | shiftKey))
    }

    private func installHandler() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hk = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { hk.callback?() }
                return noErr
            },
            1, &spec, selfPtr, &handlerRef
        )
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }
        let id = EventHotKeyID(signature: OSType(0x53504C4E), id: 1) // 'SPLN'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref
        )
        if status == noErr { hotKeyRef = ref }
    }

    func uninstall() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let h = handlerRef { RemoveEventHandler(h); handlerRef = nil }
        callback = nil
    }
}

#endif
