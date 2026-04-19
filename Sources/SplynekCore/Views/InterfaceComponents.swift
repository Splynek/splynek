import SwiftUI

// MARK: Interface row

/// A single row in the interface picker. Left: checkbox + name + IP.
/// Right: tags (v4/v6/expensive), optional historical-throughput hint,
/// and a small MB/s cap editor that drives the shared TokenBucket.
struct InterfaceRow: View {
    let interface: DiscoveredInterface
    @Binding var selected: Bool
    var historicalBps: Double?
    /// True when this interface was the historical top performer for the
    /// current host — surfaced as a star pill so Splynek's recommendation
    /// is visible without being pushy.
    var isHistoricalBest: Bool = false
    var disabled: Bool
    /// Current cap in bytes/sec, 0 = unlimited. Edited via a TextField
    /// that converts MB/s to bps.
    @Binding var capBps: Int64
    @State private var capMBps: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $selected)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(disabled)

            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(kindTint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(interface.name)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text(interface.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(interface.primaryIP)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                if interface.ipv4 != nil { StatusPill(text: "v4", style: .info) }
                if interface.ipv6 != nil { StatusPill(text: "v6", style: .info) }
                if interface.isExpensive { StatusPill(text: "$$", style: .warning) }
                if interface.nwInterface == nil {
                    StatusPill(text: "NO NW", style: .danger)
                }
            }

            if let bps = historicalBps, bps > 0 {
                HStack(spacing: 3) {
                    if isHistoricalBest {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .help("Best historical throughput for this host.")
                    }
                    Text("≈\(formatRate(bps))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("∞", value: $capMBps,
                          format: .number.precision(.fractionLength(1)))
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: capMBps) { new in
                        capBps = Int64(new * 1024 * 1024)
                    }
                Text("MB/s").font(.caption2).foregroundStyle(.secondary)
            }
            .help("Per-interface bandwidth cap (applies across all concurrent downloads).")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .opacity(disabled ? 0.5 : 1)
        .onAppear { capMBps = Double(capBps) / (1024 * 1024) }
    }

    private var iconName: String {
        switch interface.kind {
        case .wifi:      return "wifi"
        case .ethernet:  return "cable.connector"
        case .cellular:  return "antenna.radiowaves.left.and.right"
        case .iPhoneUSB: return "iphone"
        case .other:     return "network"
        }
    }

    // v0.46: Wi-Fi was tinted .yellow which users read as a warning
    // signal (low signal? captive portal?). Switched to .blue to match
    // the rest of macOS's Wi-Fi styling and remove the false-alarm vibe.
    // iPhone USB gets its own blue-ish tint so it's visually distinct
    // from a generic Ethernet row.
    private var kindTint: Color {
        switch interface.kind {
        case .wifi:      return .blue
        case .ethernet:  return .green
        case .cellular:  return .pink
        case .iPhoneUSB: return .cyan
        case .other:     return .secondary
        }
    }
}

// MARK: Lane card

/// One per-interface stats card in the active download view. Shows
/// throughput numeral + details. Bandwidth cap lives on the InterfaceRow
/// in the main interface picker, not here, since it's a per-interface
/// (not per-job) setting.
struct LaneCard: View {
    @ObservedObject var lane: LaneStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: iconName)
                    .foregroundStyle(kindTint)
                    .font(.system(size: 12, weight: .medium))
                Text(lane.interface.name)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                Text(lane.interface.label)
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if lane.failedOver {
                    StatusPill(text: "FAILED OVER", style: .danger)
                }
                if lane.errors > 0 {
                    StatusPill(text: "\(lane.errors) err", style: .danger)
                }
                if lane.activeChunks > 0 {
                    StatusPill(text: "\(lane.activeChunks) live", style: .success)
                }
                healthPill
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(formatRate(lane.throughputBps))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("throughput")
                    .font(.caption2).foregroundStyle(.secondary)
                    .textCase(.uppercase).tracking(0.6)
            }

            HStack(spacing: 16) {
                detailsColumn(label: "Total", value: formatBytes(lane.bytesTotal))
                detailsColumn(label: "Chunks", value: "\(lane.chunksDone)")
                if lane.medianRTT > 0 {
                    detailsColumn(label: "RTT", value: Self.formatRTT(lane.medianRTT))
                }
                if !lane.connectedTo.isEmpty {
                    detailsColumn(label: "Peer", value: lane.connectedTo)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func detailsColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.callout, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(0.5)
        }
    }

    private var iconName: String {
        switch lane.interface.kind {
        case .wifi:      return "wifi"
        case .ethernet:  return "cable.connector"
        case .cellular:  return "antenna.radiowaves.left.and.right"
        case .iPhoneUSB: return "iphone"
        case .other:     return "network"
        }
    }

    private var kindTint: Color {
        switch lane.interface.kind {
        case .wifi:      return .blue
        case .ethernet:  return .green
        case .cellular:  return .pink
        case .iPhoneUSB: return .cyan
        case .other:     return .secondary
        }
    }

    @ViewBuilder
    private var healthPill: some View {
        let score = Int(lane.healthScore)
        let style: StatusPill.Style =
            score >= 80 ? .success :
            Double(score) >= LaneStats.unhealthyThreshold ? .warning : .danger
        StatusPill(text: "♥ \(score)", style: style)
    }

    /// Format a TimeInterval RTT in whatever unit reads best:
    /// sub-millisecond → "0.4 ms", otherwise nearest millisecond.
    static func formatRTT(_ s: TimeInterval) -> String {
        let ms = s * 1000
        if ms < 1 {
            return String(format: "%.1fms", ms)
        } else if ms < 1000 {
            return "\(Int(ms.rounded()))ms"
        } else {
            return String(format: "%.1fs", s)
        }
    }
}
