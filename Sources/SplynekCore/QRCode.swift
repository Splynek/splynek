import Foundation
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// One-shot QR-code generator backed by CoreImage's `CIQRCodeGenerator`.
/// Produces an `NSImage` at roughly the requested point size, scaled
/// with nearest-neighbour so the modules stay crisp.
enum QRCode {
    static func image(for text: String, size: CGFloat = 220) -> NSImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let extent = output.extent
        let scale = max(1, size / max(1, extent.width))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
    }
}
