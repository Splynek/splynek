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
    /// v1.5.1: when the parent row is selected (in a List with
    /// selection), the row's background becomes the system accent
    /// colour and the regular `color.opacity(0.14)` pill blends
    /// almost invisibly into it.  Callers in selectable lists
    /// (Sidebar) pass `inverted: true` so the pill flips to a
    /// white-on-translucent-white style that stays readable on
    /// any accent.
    var inverted: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(inverted ? Color.white : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(inverted ? Color.white.opacity(0.20) : color.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        inverted ? Color.white.opacity(0.45) : color.opacity(0.25),
                        lineWidth: 0.5
                    )
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
/// **v1.5.3 — ContextCard.** Replaces `PageHeader` as the standard
/// "what is this tab" affordance.  Why the change:
///
///   • The window title bar already shows the tab name via
///     `.navigationTitle(_:)`.  Repeating the title inside the
///     content area wasted vertical real-estate and read as noise.
///   • The card sits ABOVE the scroll area, not inside it, so it
///     stays visible as the user scrolls — sticky-by-position.
///   • Each tab gets a **tint** that becomes its visual signature:
///     leading accent bar + icon colour + subtle outer glow.  Across
///     the app this creates per-tab personality without a heavy
///     theming framework.
///   • Background is `.ultraThinMaterial` for the macOS-26 vibrancy
///     feel — translucent over whatever's behind, dynamic with light
///     and dark mode for free.
///   • The SF Symbol is rendered `.hierarchical` so it has natural
///     light-and-mass depth instead of the flat single-tone look.
///
/// Usage:
///
///     ContextCard(
///         systemImage: "shield.lefthalf.filled",
///         subtitle: "See where your Mac's software comes from…",
///         tint: .blue
///     )
///     .padding(.horizontal, 16)
///     .padding(.top, 12)
///
/// Place it OUTSIDE the `ScrollView`, before the scrolling content,
/// so it stays pinned at the top.
struct ContextCard: View {
    let systemImage: String
    let subtitle: LocalizedStringKey
    var tint: Color = .accentColor

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Leading accent bar: per-tab signature.  Vertical gradient
            // so the bar has a subtle highlight rather than reading as
            // a flat strip of colour.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 3)

            // Icon.  Hierarchical rendering gives SF Symbols natural
            // light/dark mass; combined with the tint it reads as a
            // confident focal point without dominating.
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 28, alignment: .top)
                .padding(.top, 1)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 0.6)
        )
        // Faint outer glow in the tab's tint.  Extremely subtle — just
        // enough to separate the card from the window background.
        .shadow(color: tint.opacity(0.10), radius: 12, y: 3)
        // Card decoration is purely visual; the subtitle text carries
        // all semantic content for VoiceOver.
        .accessibilityElement(children: .contain)
    }
}

struct PageHeader: View {
    let systemImage: String
    // v1.4: LocalizedStringKey so Sovereignty (and future localised
    // views) auto-translate via Localizable.xcstrings.  Existing
    // callers pass string literals which are ExpressibleByStringLiteral
    // into LocalizedStringKey — no behavioural change for the other
    // tabs because their strings aren't in the xcstrings catalog and
    // fall through to the source English.
    //
    // **v1.5.3 deprecation note:** new tabs should use `ContextCard`
    // instead — the tab name now lives in the window title bar
    // (`.navigationTitle(_:)`) and PageHeader's inline title duplicated
    // it.  Existing PageHeader call sites are being migrated tab by tab.
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

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

/// App-wide "X ago" formatter. QA P2 #7 + #8 (v0.43):
/// - Clamps sub-minute intervals so a 2-second delta doesn't render
///   as "-2 min" — `RelativeDateTimeFormatter` can produce negative
///   strings around its floor. We show "just now" instead.
/// - Forces `en_US_POSIX` locale so the abbreviated units don't mix
///   with the system locale's connector (previously "3 min e 14 seg"
///   on Portuguese-set Macs; now "3 min 14 sec" consistently).
func formatRelative(_ date: Date, now: Date = Date()) -> String {
    let delta = now.timeIntervalSince(date)
    if delta < 60 { return "just now" }
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.localizedString(for: date, relativeTo: now)
}
