import Foundation
import AppKit

/// Shareable benchmark-result PNG. Speedtest.net's "share your result"
/// image, ported to Splynek: the user hits *Save image* on the
/// benchmark panel and gets a 1200×630 PNG (OG-image aspect) with
/// device name, URL, a bar chart of each interface's throughput, and
/// the N× speedup headline. Zero network, zero external deps.
enum BenchmarkImage {

    static let size = NSSize(width: 1200, height: 630)

    /// Render the image. Returns nil if AppKit refuses to lock a
    /// graphics context (shouldn't happen on a real Mac, but the
    /// caller should handle it).
    static func render(
        url: URL,
        probes: [BenchmarkRunner.Probe],
        device: String
    ) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocusFlipped(false)
        defer { image.unlockFocus() }

        // Background — gradient from deep indigo to black, same palette
        // the rest of the app uses.
        let rect = NSRect(origin: .zero, size: size)
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.09, alpha: 1).setFill()
        rect.fill()
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.0, alpha: 0.20),
            NSColor.clear
        ])
        gradient?.draw(in: rect, angle: 135)

        // Header — Splynek wordmark + device line
        let titleStyle: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        "Splynek benchmark".draw(at: NSPoint(x: 60, y: size.height - 100),
                                 withAttributes: titleStyle)
        let subStyle: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor(white: 1, alpha: 0.6)
        ]
        "\(device) · \(url.host ?? "—")".draw(
            at: NSPoint(x: 60, y: size.height - 135),
            withAttributes: subStyle
        )

        // Headline — "N.Nx faster than single-path"
        let headline = speedupHeadline(probes: probes)
        let headlineStyle: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 72, weight: .black),
            .foregroundColor: NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.35, alpha: 1)
        ]
        headline.draw(at: NSPoint(x: 60, y: 360), withAttributes: headlineStyle)
        let headlineSub: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor(white: 1, alpha: 0.65)
        ]
        "faster than the best single-path lane".draw(
            at: NSPoint(x: 60, y: 320), withAttributes: headlineSub
        )

        // Bar chart — one row per probe
        drawChart(probes: probes, in: NSRect(x: 60, y: 40, width: size.width - 120, height: 260))

        // Footer watermark
        let footStyle: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor(white: 1, alpha: 0.4)
        ]
        let stamp = ISO8601DateFormatter().string(from: Date())
        "splynek.app · \(stamp)".draw(
            at: NSPoint(x: size.width - 360, y: 20),
            withAttributes: footStyle
        )

        return image
    }

    /// PNG data from an `NSImage`. Useful when the caller wants to
    /// write directly without going through an `NSSavePanel`.
    static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: Drawing helpers

    private static func speedupHeadline(probes: [BenchmarkRunner.Probe]) -> String {
        let multi = probes.first { $0.label.hasPrefix("Multi") }
        let singles = probes.filter { !$0.label.hasPrefix("Multi") }
        guard let multi, let bestSingle = singles.map(\.throughputBps).max(),
              bestSingle > 0 else {
            return "—"
        }
        let factor = multi.throughputBps / bestSingle
        return String(format: "%.1f×", factor)
    }

    private static func drawChart(probes: [BenchmarkRunner.Probe], in rect: NSRect) {
        guard !probes.isEmpty else { return }
        let maxBps = probes.map(\.throughputBps).max() ?? 1
        let rowH: CGFloat = min(40, rect.height / CGFloat(probes.count))
        let rowGap: CGFloat = 8
        let labelW: CGFloat = 180
        let numW: CGFloat = 150
        let barX = rect.minX + labelW
        let barMax = rect.width - labelW - numW

        for (i, probe) in probes.enumerated() {
            let y = rect.maxY - CGFloat(i + 1) * (rowH + rowGap)
            let labelStyle: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor(white: 1, alpha: 0.85)
            ]
            probe.label.draw(
                at: NSPoint(x: rect.minX, y: y + (rowH - 16) / 2),
                withAttributes: labelStyle
            )
            let width = barMax * CGFloat(probe.throughputBps / maxBps)
            let barRect = NSRect(x: barX, y: y, width: max(4, width), height: rowH - 4)
            let barColor = probe.label.hasPrefix("Multi")
                ? NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.35, alpha: 1)
                : NSColor(calibratedRed: 0.4, green: 0.6, blue: 1, alpha: 1)
            barColor.setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 6, yRadius: 6).fill()
            let rate = humanRate(probe.throughputBps)
            let rateStyle: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
            rate.draw(
                at: NSPoint(x: barX + barMax + 12, y: y + (rowH - 18) / 2),
                withAttributes: rateStyle
            )
        }
    }

    private static func humanRate(_ bps: Double) -> String {
        let units: [(Double, String)] = [
            (1_000_000_000, "GB/s"), (1_000_000, "MB/s"), (1_000, "KB/s")
        ]
        for (threshold, unit) in units where bps >= threshold {
            return String(format: "%.1f %@", bps / threshold, unit)
        }
        return String(format: "%.0f B/s", bps)
    }
}
