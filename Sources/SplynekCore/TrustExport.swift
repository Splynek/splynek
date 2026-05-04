import Foundation
import SwiftUI

/// v1.7.x: shareable Trust-scan exports — full PDF (all apps) +
/// top-N PNG (most-concerning, social-shareable).  Both branded with
/// the credibility-anchored slogan ("local-first scan, primary
/// sources cited") because Trust is the credibility-anchored product
/// surface — the export should look like a research artifact, not a
/// marketing brochure.
///
/// Scope split:
/// - PDF: every scored app, full concerns + citations.  The
///   research-grade artifact (press references, audit trails).
/// - PNG: top-N most-concerning apps, single image at 1200×1200.
///   The social-shareable punchline.
///
/// Two-layer design: this file is pure data shaping (ranking,
/// methodology copy, slogan) plus the `render*` entry points that
/// drive `ImageRenderer`.  The SwiftUI views the renderer consumes
/// live in `Views/TrustReportViews.swift` so the view layer is
/// reviewable independently.
enum TrustExport {

    // MARK: - Data shapes

    /// One installed app with its computed Trust score + the
    /// catalog entry it scored against.  Sorted descending by
    /// score (most concerning first) when handed to the renderers.
    struct ScoredApp: Sendable {
        let app: SovereigntyScanner.InstalledApp
        let entry: TrustCatalog.Entry
        let score: TrustScorer.Score
    }

    // MARK: - Methodology + branding

    /// One-line credibility-anchored slogan rendered in the export
    /// footer (PDF every page, PNG bottom).  Deliberately understated
    /// — the export *is* the marketing; the slogan reinforces what
    /// the data already shows.
    static let slogan = "Local-first scan. Every claim links to its primary source. splynek.app"

    /// Methodology blurb shown on the PDF cover page.  Anchors the
    /// reader's trust by listing the source allowlist Splynek's
    /// catalog actually uses — it's not opinion, it's a curated
    /// re-statement of what regulators / breach trackers / Apple's
    /// own privacy labels say.  See `TRUST-CONTRIBUTING.md` for the
    /// editorial rules.
    static let methodologyBlurb = """
        Trust scores are derived from primary-source-cited concerns: \
        Apple App Store privacy labels, NVD CVEs, HIBP breach records, \
        FTC / SEC / EU DPA rulings, vendor security advisories, and \
        vendors' own privacy policies. Editorial words ("spies", \
        "untrustworthy", "you are the product") are rejected by the \
        catalog regenerator. Each cited concern below links back to \
        its primary source so you can verify every claim.
        """

    // MARK: - Ranking

    /// Walk the installed apps + score every one that has a
    /// `TrustCatalog.Entry`.  Returns an array sorted descending by
    /// score (most concerning first); apps with no catalog entry are
    /// excluded.  Pure function — input → output, no side effects,
    /// no `@MainActor` dependency, fully testable.
    static func rankedScored(
        installedApps: [SovereigntyScanner.InstalledApp],
        weights: TrustScorer.Weights = .default
    ) -> [ScoredApp] {
        var scored: [ScoredApp] = []
        for app in installedApps {
            guard let entry = TrustCatalog.profile(for: app.id) else { continue }
            let score = TrustScorer.score(entry, weights: weights)
            scored.append(ScoredApp(app: app, entry: entry, score: score))
        }
        // Most-concerning first.  Tiebreak on display name so the
        // ordering is stable across runs (the export shouldn't shift
        // app order when nothing material changed).
        return scored.sorted { lhs, rhs in
            if lhs.score.value != rhs.score.value {
                return lhs.score.value > rhs.score.value
            }
            return lhs.app.name < rhs.app.name
        }
    }

    /// Top-N selection for the PNG export.  Caps at the 10 most
    /// concerning + filters out the no-concerns rows (Trust shows
    /// "no public concerns recorded" for those, which doesn't belong
    /// in a top-N-most-concerning shareable).  Returns whatever's
    /// available if fewer than `n` apps meet the bar.
    static func topNMostConcerning(
        from ranked: [ScoredApp],
        n: Int = 10
    ) -> [ScoredApp] {
        ranked.filter { $0.score.hasConcerns }.prefix(n).map { $0 }
    }

    /// v1.7.x: split the scored-apps list into per-page chunks for
    /// the PDF renderer.  The first chunk holds fewer apps because
    /// the cover page also carries the title + date + methodology
    /// blurb + summary stats; continuation pages are pure app lists
    /// so they fit more.
    ///
    /// Defaults sized empirically from the v1.5+ catalog: 5 apps fit
    /// comfortably below the cover content on US Letter; 8 apps fit
    /// per continuation page.  Apps with concerns lists longer than
    /// average might still extend slightly past the cap — acceptable
    /// because the *next* page picks up the next app cleanly; the
    /// only failure mode at the limits is a ~1pt of bleed at the
    /// page boundary, which is invisible on screen.
    ///
    /// Pure function — fully testable with synthetic input.
    static func chunkAppsForPDF(
        _ scored: [ScoredApp],
        firstPage: Int = 5,
        continuationPage: Int = 8
    ) -> [[ScoredApp]] {
        guard !scored.isEmpty else { return [[]] }  // single empty cover
        var chunks: [[ScoredApp]] = []
        let firstCount = min(firstPage, scored.count)
        chunks.append(Array(scored.prefix(firstCount)))
        var idx = firstCount
        while idx < scored.count {
            let end = min(idx + continuationPage, scored.count)
            chunks.append(Array(scored[idx..<end]))
            idx = end
        }
        return chunks
    }

    // MARK: - Render entry points
    //
    // Both renderers go through `ImageRenderer` (macOS 13+).  PDF uses
    // a CGContext with PDF backing so the multi-page report renders
    // as a real PDF rather than a flattened image.  PNG renders at
    // 2× scale for retina displays.  Both write atomically to disk.

    /// Render the full Trust scan as a multi-page PDF.  Each app
    /// becomes its own section with the score + level + per-concern
    /// citations.  Branded footer on every page.
    ///
    /// v1.7.x: true multi-page pagination — first page carries the
    /// cover (title + methodology + summary stats + first ~5 apps),
    /// subsequent pages each carry ~8 apps with a "X of Y" header.
    /// Each chunk renders into its own CGContext PDF page so a Mac
    /// with many catalog hits no longer clips at the bottom of US
    /// Letter.  See `chunkAppsForPDF(_:)` for chunk sizing.
    @MainActor
    static func renderPDF(
        _ scored: [ScoredApp],
        to outputURL: URL,
        date: Date = Date()
    ) throws {
        // US Letter at 72 dpi — the canonical PDF page size for
        // unbranded research artifacts.  Letter beats A4 here because
        // the audience is overwhelmingly North American press +
        // technical readers; A4 readers can still print to fit.
        let pageSize = CGSize(width: 612, height: 792)

        guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
            throw NSError(domain: "TrustExport", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Couldn't open the output URL for writing.",
            ])
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "TrustExport", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Couldn't create the PDF context.",
            ])
        }

        let pages = chunkAppsForPDF(scored)
        let totalPages = pages.count

        for (idx, pageApps) in pages.enumerated() {
            let view = TrustReportPDFView(
                scored: pageApps,
                date: date,
                isCoverPage: idx == 0,
                pageNumber: idx + 1,
                totalPages: totalPages,
                allScoredForCoverStats: idx == 0 ? scored : nil
            )
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, render in
                pdfContext.beginPDFPage(nil)
                render(pdfContext)
                pdfContext.endPDFPage()
            }
        }
        pdfContext.closePDF()
    }

    /// Render the top-N most-concerning apps as a single 1200×1200
    /// PNG suitable for Twitter / Mastodon / Bluesky inline images.
    /// 2× scale for retina; clamps to top-10 by default.
    @MainActor
    static func renderPNG(
        _ scored: [ScoredApp],
        topN: Int = 10,
        to outputURL: URL,
        date: Date = Date()
    ) throws {
        let top = topNMostConcerning(from: scored, n: topN)
        let view = TrustReportPNGView(scored: top, date: date)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: 1200, height: 1200)
        renderer.scale = 2.0

        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "TrustExport", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Couldn't render the PNG image.",
            ])
        }
        try pngData.write(to: outputURL, options: .atomic)
    }
}
