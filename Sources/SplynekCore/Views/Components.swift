import SwiftUI

// MARK: Section Card

/// A canonical rounded container with a subtle border and a titled header.
/// Designed to sit on top of the window's default material background so
/// Materials' blur bleeds through at the edges.
struct SectionCard<Header: View, Content: View>: View {
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header()
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            // Stronger border + soft shadow so cards clearly delineate
            // from the window background. Previous 0.08-alpha hairline
            // was too subtle; cards visually ran together.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
    }
}

/// Convenience: a SectionCard with a standard title + SF Symbol header.
struct TitledCard<Content: View>: View {
    let title: String
    let systemImage: String
    var accessory: AnyView? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        SectionCard {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                accessory
            }
        } content: {
            content()
        }
    }
}

// MARK: Status Pill

/// Small capsule badge used for interface flags (v4, v6, $$), protocol
/// states (ENDGAME, RESUMED, DoH), and similar short tags.
struct StatusPill: View {
    enum Style { case info, success, warning, danger, neutral }

    let text: String
    let style: Style

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
    }

    private var color: Color {
        switch style {
        case .info:     return .accentColor
        case .success:  return .green
        case .warning:  return .orange
        case .danger:   return .red
        case .neutral:  return .secondary
        }
    }
}

// MARK: Metric

/// Big-number + caption pair used in the aggregate-throughput header.
struct MetricView: View {
    let value: String
    let caption: String
    var tint: Color = .primary
    var monospaced: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: monospaced ? .monospaced : .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
    }
}

// MARK: Page header

/// Unified title + subtitle block rendered at the top of each detail
/// view's content area. Replaces the disconnected pair of
/// `navigationTitle` (in the window chrome) + a separate explainer
/// row. Title and subtitle share a column with tight vertical spacing
/// + a thin rule below, so they read as one piece of furniture rather
/// than two competing elements.
///
/// Visual: large rounded-display title, one-line secondary subtitle,
/// a 1-pixel divider underneath.
struct PageHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
                    .font(.system(size: 20, weight: .semibold))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 4)
    }
}

/// Back-compat shim — some views still import the old name. Falls back
/// to a minimal row so anything we haven't migrated yet keeps
/// rendering. (v0.30: no remaining call sites.)
struct ViewExplainer: View {
    let systemImage: String
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage).foregroundStyle(.secondary)
            Text(text).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: Empty state

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: Gradient progress

/// Linear progress bar with an accent-gradient fill and capped ends.
struct GradientProgressBar: View {
    let fraction: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.85), .accentColor],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: fraction)
            }
        }
        .frame(height: height)
    }
}

// MARK: Formatting

func formatBytes(_ n: Int64) -> String {
    let fmt = ByteCountFormatter()
    fmt.countStyle = .binary
    fmt.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    fmt.zeroPadsFractionDigits = false
    return fmt.string(fromByteCount: max(n, 0))
}

func formatRate(_ bps: Double) -> String { formatBytes(Int64(bps)) + "/s" }

func formatDuration(_ seconds: Double) -> String {
    if !seconds.isFinite || seconds <= 0 { return "—" }
    let s = Int(seconds)
    if s < 60 { return "\(s)s" }
    if s < 3600 { return "\(s / 60)m \(s % 60)s" }
    return "\(s / 3600)h \((s % 3600) / 60)m"
}
