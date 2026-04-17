import Foundation
import AppKit
@testable import SplynekCore

/// QR generator should produce a non-empty image at roughly the
/// requested size for a realistic input.
enum QRCodeTests {

    static func run() {
        TestHarness.suite("QRCode") {

            TestHarness.test("Generates a non-nil image for a typical LAN URL") {
                let url = "http://192.168.1.42:53711/splynek/v1/ui?t=abc123"
                let img = QRCode.image(for: url, size: 220)
                guard let img else {
                    throw Expectation(message: "image was nil", file: #file, line: #line)
                }
                // Size doesn't have to be exact — CIQRCodeGenerator rounds
                // to module boundaries — but it must be reasonable.
                try expect(img.size.width >= 180 && img.size.width <= 260,
                           "width \(img.size.width) outside expected band")
                try expect(img.size.height >= 180 && img.size.height <= 260,
                           "height \(img.size.height) outside expected band")
            }

            TestHarness.test("Empty string still produces an image or fails cleanly") {
                // The contract: either we get an image (QR of empty) or
                // nil. Either is fine — the UI treats nil as "don't show
                // the QR." What MUST NOT happen is a crash.
                _ = QRCode.image(for: "", size: 100)
            }
        }
    }
}
