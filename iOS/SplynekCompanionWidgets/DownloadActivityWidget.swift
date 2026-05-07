// Copyright © 2026 Splynek. MIT.
//
// DownloadActivityWidget — Live Activity widget for an in-progress
// Splynek download.  Three surfaces:
//
//   • Lock screen / banner       — full progress card
//   • Dynamic Island compact     — leading icon + trailing throughput
//   • Dynamic Island minimal     — single arrow icon
//   • Dynamic Island expanded    — leading filename, trailing speed,
//                                  bottom progress bar
//
// macOS 26 mirrors the Live Activity into the Mac menu bar
// automatically — no Mac-side widget code required.  The menu bar
// chip uses the compact/minimal Dynamic-Island surfaces.

#if canImport(SwiftUI) && canImport(WidgetKit) && canImport(ActivityKit)
import SwiftUI
import WidgetKit
import ActivityKit

struct DownloadActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            // Lock screen / banner / Mac menu-bar wide.
            LockScreenView(state: context.state, attrs: context.attributes)
                .padding(12)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    leading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailing(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(state: context.state, attrs: context.attributes)
                }
            } compactLeading: {
                Image(systemName: phaseSymbol(state: context.state))
                    .foregroundStyle(.tint)
            } compactTrailing: {
                Text(formatThroughput(context.state.throughputBps))
                    .monospacedDigit()
                    .font(.caption2)
            } minimal: {
                Image(systemName: phaseSymbol(state: context.state))
                    .foregroundStyle(.tint)
            }
        }
    }

    // MARK: Lock screen view

    private struct LockScreenView: View {
        let state: DownloadActivityAttributes.ContentState
        let attrs: DownloadActivityAttributes

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: phaseSymbolStatic(state: state))
                        .foregroundStyle(.tint)
                    Text(attrs.filename)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(attrs.macName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if state.total != nil {
                    ProgressView(value: state.fractionComplete)
                } else if state.phase == .running {
                    ProgressView().progressViewStyle(.linear)
                }
                HStack {
                    Text(formatBytes(state.downloaded))
                        + (state.total.map { Text(" / ") + Text(formatBytes($0)) } ?? Text(""))
                    Spacer()
                    Text(formatThroughput(state.throughputBps))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Dynamic Island regions

    @ViewBuilder
    private func leading(context: ActivityViewContext<DownloadActivityAttributes>) -> some View {
        HStack(spacing: 6) {
            Image(systemName: phaseSymbol(state: context.state))
                .foregroundStyle(.tint)
            Text(context.attributes.filename)
                .font(.subheadline)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func trailing(state: DownloadActivityAttributes.ContentState) -> some View {
        Text(formatThroughput(state.throughputBps))
            .font(.subheadline)
            .monospacedDigit()
    }

    @ViewBuilder
    private func expandedBottom(
        state: DownloadActivityAttributes.ContentState,
        attrs: DownloadActivityAttributes
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.total != nil {
                ProgressView(value: state.fractionComplete)
            }
            HStack {
                Text(formatBytes(state.downloaded))
                    + (state.total.map { Text(" / ") + Text(formatBytes($0)) } ?? Text(""))
                Spacer()
                Text("on \(attrs.macName)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Helpers

    private func phaseSymbol(state: DownloadActivityAttributes.ContentState) -> String {
        DownloadActivityWidget.phaseSymbolStatic(state: state)
    }

    fileprivate static func phaseSymbolStatic(
        state: DownloadActivityAttributes.ContentState
    ) -> String {
        switch state.phase {
        case .queued:   return "tray.full"
        case .running:  return "arrow.down.circle.fill"
        case .paused:   return "pause.circle"
        case .finished: return "checkmark.circle.fill"
        case .failed:   return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Formatting helpers (file-private to the widget)

fileprivate func formatBytes(_ bytes: Int64) -> String {
    let units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var v = Double(bytes)
    var i = 0
    while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
    return String(format: "%.1f %@", v, units[i])
}

fileprivate func formatThroughput(_ bps: Double) -> String {
    if bps <= 0 { return "—" }
    let units = ["B/s", "KiB/s", "MiB/s", "GiB/s"]
    var v = bps
    var i = 0
    while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
    return String(format: "%.1f %@", v, units[i])
}
#endif
