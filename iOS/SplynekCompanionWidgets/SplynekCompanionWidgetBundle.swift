// Copyright © 2026 Splynek. MIT.
//
// SplynekCompanionWidgetBundle — `@main` for the widget extension.
//
// One bundle, one widget for now: the DownloadActivityWidget for
// Live Activities.  Home-screen / lock-screen widgets (showing
// recent downloads) come in phase 3 — Splynek's data is still
// only paired-Mac-derived, and a widget that polls the Mac would
// drain the battery.  Live Activity is the "right tool" for now.

#if canImport(SwiftUI) && canImport(WidgetKit)
import SwiftUI
import WidgetKit

@main
struct SplynekCompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        DownloadActivityWidget()
    }
}
#endif
