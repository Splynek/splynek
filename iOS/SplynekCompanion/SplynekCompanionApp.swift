// Copyright © 2026 Splynek. MIT.
//
// SplynekCompanionApp — `@main` entry point for the iOS companion.
//
// This is the foundation skeleton (Strategy Bet S4 phase 1).  It
// proves the core thesis: Splynek Macs on the LAN appear here, you
// pair one with a token, and you can submit URLs + see job status.
//
// What this version does NOT include yet (planned for phase 2):
//   - Live Activity (ActivityKit) for download progress on the lock
//     screen + Dynamic Island + macOS 26 menu-bar mirror.
//   - QR-code scanner for pairing (manual paste only for now).
//   - CloudKit relay for over-cellular submission.
//
// What it DOES include:
//   - Bonjour discovery via `_splynek-fleet._tcp`.
//   - Token-paste pairing flow.
//   - Manual URL submission to a paired Mac.
//   - Active-jobs polling + display.
//   - Share Extension hooks (the extension is a separate target).

#if canImport(SwiftUI)
import SwiftUI

@main
struct SplynekCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#endif
