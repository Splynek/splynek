import SwiftUI

/// v1.7.x: SwiftUI views the `TrustExport` renderer pipes through
/// `ImageRenderer`.  Both views are intentionally typography-heavy
/// + monochrome with one accent — the goal is "research artifact"
/// not "marketing card."  Splynek's brand reinforces credibility by
/// looking restrained, so the export does too.
///
/// Strings here are NOT localized.  Trust exports are shareable
/// artifacts overwhelmingly consumed in English by press / privacy
/// readers / Show HN audiences; mixing locale-of-the-app + locale-
/// of-the-reader is a worse outcome than canonical-English copy.
/// (The in-app TrustView itself stays fully localized; only the
/// shareable export is English-only.)

// =====================================================================
// PDF — multi-app, full citations, US Letter (612×792 @ 72dpi)
// =====================================================================

struct TrustReportPDFView: View {
    /// Apps to render on THIS page (already chunked by
    /// `TrustExport.chunkAppsForPDF`).
    let scored: [TrustExport.ScoredApp]
    let date: Date
    /// True for the first page — show the cover (title +
    /// methodology + summary stats); false for continuation pages
    /// (show "Page X of Y" header).
    var isCoverPage: Bool = true
    var pageNumber: Int = 1
    var totalPages: Int = 1
    /// Full scored list (all apps) — only used on the cover page
    /// for the summary-stats counts.  Nil on continuation pages.
    var allScoredForCoverStats: [TrustExport.ScoredApp]? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isCoverPage {
                coverHeader
                Divider()
                Text(TrustExport.methodologyBlurb)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                summaryStats
                Divider()
            } else {
                continuationHeader
                Divider()
            }

            // Per-app sections (this page's chunk only)
            ForEach(scored, id: \.app.id) { item in
                pdfAppSection(item)
            }

            Spacer()

            // Footer with slogan + page number
            VStack(alignment: .leading, spacing: 2) {
                Divider()
                HStack {
                    Text(TrustExport.slogan)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if totalPages > 1 {
                        Text("Page \(pageNumber) of \(totalPages)")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(36)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(Color.white)
    }

    @ViewBuilder
    private var coverHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trust Scan Report")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(Self.dateFormatter.string(from: date))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var continuationHeader: some View {
        HStack {
            Text("Trust Scan Report (continued)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Page \(pageNumber) of \(totalPages)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var summaryStats: some View {
        // Counts come from the FULL scored list (all pages combined),
        // not just this page's chunk — otherwise the cover would
        // under-count when the catalog spans multiple pages.
        let stats = allScoredForCoverStats ?? scored
        HStack(alignment: .firstTextBaseline, spacing: 24) {
            statBlock(label: "Apps reviewed", value: "\(stats.count)")
            statBlock(label: "Severe", value: "\(stats.filter { $0.score.level == .severe }.count)")
            statBlock(label: "High", value: "\(stats.filter { $0.score.level == .high }.count)")
            statBlock(label: "Moderate", value: "\(stats.filter { $0.score.level == .moderate }.count)")
            statBlock(label: "Low / clean", value: "\(stats.filter { $0.score.level == .low }.count)")
            Spacer()
        }
    }

    @ViewBuilder
    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func pdfAppSection(_ item: TrustExport.ScoredApp) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.app.name)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(item.score.value)/100")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                Text(item.score.level.label)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(
                        Capsule().fill(levelColor(item.score.level).opacity(0.18))
                    )
                    .foregroundStyle(levelColor(item.score.level))
            }
            if item.entry.concerns.isEmpty {
                Text("No public concerns recorded.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(item.entry.concerns) { c in
                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.summary)
                                .font(.system(size: 9))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(c.sourceName) · \(c.evidenceDate)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func levelColor(_ level: TrustScorer.Level) -> Color {
        switch level {
        case .low:       return .green
        case .moderate:  return .yellow
        case .high:      return .orange
        case .severe:    return .red
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()
}

// =====================================================================
// PNG — top-N most concerning, single 1200×1200 image
// =====================================================================

struct TrustReportPNGView: View {
    let scored: [TrustExport.ScoredApp]
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trust scan — top \(scored.count) most concerning")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Local scan • \(Self.dateFormatter.string(from: date))")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // App rows
            VStack(spacing: 10) {
                ForEach(scored, id: \.app.id) { item in
                    pngAppRow(item)
                }
            }

            Spacer()

            // Footer slogan
            VStack(alignment: .leading, spacing: 2) {
                Divider()
                Text(TrustExport.slogan)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(48)
        .frame(width: 1200, height: 1200, alignment: .topLeading)
        .background(Color.white)
    }

    @ViewBuilder
    private func pngAppRow(_ item: TrustExport.ScoredApp) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.app.name)
                    .font(.system(size: 18, weight: .semibold))
                Text(item.entry.concerns.first?.summary ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.score.value)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(item.score.level.label)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(
                        Capsule().fill(levelColor(item.score.level).opacity(0.18))
                    )
                    .foregroundStyle(levelColor(item.score.level))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
    }

    private func levelColor(_ level: TrustScorer.Level) -> Color {
        switch level {
        case .low:       return .green
        case .moderate:  return .yellow
        case .high:      return .orange
        case .severe:    return .red
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM d, yyyy"
        return f
    }()
}
