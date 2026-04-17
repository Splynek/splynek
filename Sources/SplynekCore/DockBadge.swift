import AppKit

/// Progress text overlaid on the Dock icon. `set(nil)` clears it.
///
/// This is low-tech — `NSDockTile.badgeLabel` renders a small red badge at
/// the corner of the icon. For a percentage we set e.g. "42%". Clearing on
/// completion (or after a brief "Done" moment) keeps the Dock uncluttered.
@MainActor
enum DockBadge {
    static func set(_ text: String?) {
        NSApp.dockTile.badgeLabel = text
    }

    /// Convenience: given a 0…1 fraction, sets a whole-number percent
    /// badge. Returns `nil` (and clears the badge) when fraction == 0 or
    /// >= 1 since neither case is useful to the user.
    static func showProgress(_ fraction: Double) {
        guard fraction > 0, fraction < 1 else { set(nil); return }
        set("\(Int(fraction * 100))%")
    }
}
