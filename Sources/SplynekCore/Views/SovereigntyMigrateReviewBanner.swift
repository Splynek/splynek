import SwiftUI

/// **Sovereignty Migrate review banner** — Sprint 3 (2026-05-10).
///
/// Surfaces above the Sovereignty matched-rows when the user has
/// apps in their `SovereigntyMigrateReviewList` whose `markedAt`
/// is at least `reviewThresholdDays` (7) old.  The point: most
/// users start a migration and forget about it.  This banner asks
/// "you committed to switching from N apps; have you?" so the
/// Migrate Wizard's mark-for-review actually closes the loop.
///
/// **Why a banner, not a notification:** notifications would feel
/// nag-y for what is fundamentally a "did you finish a thing you
/// started?" prompt.  In-app banner is discoverable on the
/// Sovereignty surface where the user goes when they want to
/// think about migrating, ignored when they don't.
///
/// **Pro-gating:** the banner shows for Pro users who have used
/// the Migrate Wizard.  Free users have no entry point to mark
/// apps for review, so the banner is moot.

struct SovereigntyMigrateReviewBanner: View {

    /// Days an entry must be in the list before the banner notices
    /// it.  7 = a week — long enough for the user to genuinely
    /// have migrated; short enough that the prompt isn't stale.
    static let reviewThresholdDays = 7

    let staleEntries: [SovereigntyMigrateReviewEntry]
    /// Called when the user clicks "Forget this" on a row.  Maps
    /// to `SovereigntyMigrateReviewStore.mutate { $0.remove(id:) }`.
    let onForget: (String) -> Void
    /// Called when the user clicks the alternative's name to
    /// re-open its homepage in Safari.
    let onOpenHomepage: (URL) -> Void

    @State private var expanded: Bool = false

    var body: some View {
        if staleEntries.isEmpty {
            EmptyView()
        } else {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(staleEntries) { entry in
                        row(entry)
                    }
                }
                .padding(.top, 8)
            } label: {
                header
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.30), lineWidth: 0.6)
            )
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Still on your migration list")
                    .font(.callout.weight(.semibold))
                Text(headerSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var headerSummary: String {
        switch staleEntries.count {
        case 1:
            return "1 app marked over a week ago. Did you make the switch?"
        default:
            return "\(staleEntries.count) apps marked over a week ago. Did you make the switch?"
        }
    }

    @ViewBuilder
    private func row(_ entry: SovereigntyMigrateReviewEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.right.arrow.left")
                .foregroundStyle(.tint)
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.originalDisplayName)
                        .font(.callout.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Button {
                        onOpenHomepage(entry.alternativeHomepage)
                    } label: {
                        Text(entry.alternativeName)
                            .font(.callout.weight(.semibold))
                            .underline()
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Text("Marked \(prettyMarkedAt(entry.markedAt)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button {
                        onOpenHomepage(entry.alternativeHomepage)
                    } label: {
                        Label("Open \(entry.alternativeName)", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button {
                        onForget(entry.id)
                    } label: {
                        Label("I'm done; forget this",
                              systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Remove this app from your migration list. The original app stays installed; we just stop reminding.")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func prettyMarkedAt(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        guard let date = f.date(from: iso) else { return "earlier" }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .full
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
