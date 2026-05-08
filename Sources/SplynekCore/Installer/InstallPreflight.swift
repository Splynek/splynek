// Copyright © 2026 Splynek. MIT.
//
// InstallPreflight — fast format sanity checks for downloaded
// installer payloads.  Two surfaces:
//
//   - `validateBeforeRun(payload:expectedKind:)` — sniff the first
//     bytes of an on-disk file to confirm it MATCHES the spec's
//     declared kind.  Used by InstallerEngine.run() right before
//     handing off to hdiutil / installer(8) / unzip so a publisher
//     that served an HTML 404 page or a delta-update artefact fails
//     fast with a human-readable reason instead of an opaque
//     `hdiutil: attach failed - imagem não reconhecida`.
//
//   - `previewURL(_:expectedKind:)` — issue a HEAD request, then
//     a short Range GET, and report whether the URL is likely to
//     yield a valid file.  Used by UpdatesView.checkAll() to
//     downgrade a row to "Manual" (with a reason) when the source
//     URL is misbehaving — before the user clicks Update.
//
// Both are pure-Swift; no external dependencies; failures degrade
// to `.unknown` rather than throwing.

import Foundation

// All callers live inside SplynekCore (InstallerEngine + UpdatesView).
// Keep this internal because it references InstallSpec.Kind which is
// itself internal — making this public would force InstallSpec public
// for no observable benefit.
enum InstallPreflight {

    /// What the byte sniff thinks the file is.  Mapped against the
    /// caller's declared `InstallSpec.Kind` to decide accept / reject.
    enum DetectedFormat: Equatable, Sendable {
        case dmg            // UDIF; signature is the "koly" trailer
        case pkg            // xar archive; "xar!" magic at byte 0
        case zip            // PK\x03\x04
        case xml            // looks like HTML / XML / appcast — not a binary
        case appBundle      // a directory; sniffing here is best-effort
        case unknown
    }

    /// Result of a preflight check.  `.ok` means proceed without
    /// fanfare.  `.warning` means proceed but flag (e.g. unknown
    /// content-type but right magic bytes).  `.fatal` means the file
    /// almost-certainly won't install — caller should NOT invoke the
    /// installer pipeline.
    enum Verdict: Equatable, Sendable {
        case ok
        case warning(reason: String)
        case fatal(reason: String)
    }

    /// Sniff the first 4 KiB of `payload` and return the detected
    /// format.  `.unknown` when nothing matches — callers treat that
    /// as a soft signal, not an automatic fail.
    static func detectFormat(payload: URL) -> DetectedFormat {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: payload.path, isDirectory: &isDir) else {
            return .unknown
        }
        if isDir.boolValue {
            return payload.pathExtension.lowercased() == "app" ? .appBundle : .unknown
        }
        guard let handle = try? FileHandle(forReadingFrom: payload) else { return .unknown }
        defer { try? handle.close() }
        let head: Data = (try? handle.read(upToCount: 4096)) ?? Data()
        if head.isEmpty { return .unknown }
        let asAscii = String(data: head.prefix(256), encoding: .ascii)?.lowercased() ?? ""
        if asAscii.contains("<!doctype") || asAscii.contains("<html") || asAscii.hasPrefix("<?xml") {
            return .xml
        }
        if head.starts(with: [0x78, 0x61, 0x72, 0x21]) {  // 'xar!'
            return .pkg
        }
        if head.starts(with: [0x50, 0x4B, 0x03, 0x04]) ||
            head.starts(with: [0x50, 0x4B, 0x05, 0x06]) ||
            head.starts(with: [0x50, 0x4B, 0x07, 0x08]) {
            return .zip
        }
        // UDIF DMG: the canonical magic 'koly' lives in the LAST 512
        // bytes (the trailer).  Read it directly.
        if let total = (try? FileManager.default.attributesOfItem(atPath: payload.path))?[.size] as? Int64,
           total > 512,
           let trailer = (try? FileHandle(forReadingFrom: payload)).flatMap({ h -> Data? in
               defer { try? h.close() }
               try? h.seek(toOffset: UInt64(total - 512))
               return try? h.read(upToCount: 512)
           }),
           trailer.range(of: Data([0x6B, 0x6F, 0x6C, 0x79])) != nil {  // 'koly'
            return .dmg
        }
        return .unknown
    }

    /// Pre-run check against an on-disk installer payload.  Fails
    /// fast when the bytes obviously don't match the declared kind.
    /// Used by `InstallerEngine.run` so a server returning an HTML
    /// 404 page produces a clean "the source URL didn't return a
    /// disk image" error instead of a downstream `hdiutil: attach
    /// failed - image not recognized`.
    static func validateBeforeRun(payload: URL, expectedKind: InstallSpec.Kind) -> Verdict {
        let detected = detectFormat(payload: payload)
        switch (expectedKind, detected) {
        case (.dmg, .dmg),
             (.pkg, .pkg),
             (.appArchive, .zip),
             (.appBundle, .appBundle):
            return .ok
        case (_, .xml):
            return .fatal(reason: "The source URL returned an HTML or XML page, not a binary. The publisher's download link may have moved or expired.")
        case (.dmg, .pkg), (.dmg, .zip),
             (.pkg, .dmg), (.pkg, .zip),
             (.appArchive, .dmg), (.appArchive, .pkg):
            return .fatal(reason: "The downloaded file is a different format than expected. The publisher may have changed their distribution.")
        case (_, .unknown):
            // Couldn't classify — let the installer try anyway, but
            // tell the caller something might be off.
            return .warning(reason: "Couldn't recognise the file's format; proceeding may fail.")
        default:
            return .ok
        }
    }

    /// Verdict from a remote URL check.  Used by the Updates tab to
    /// downgrade rows to "Manual" with a reason BEFORE the user
    /// clicks Update.
    struct URLPreview: Equatable, Sendable {
        var verdict: Verdict
        var contentType: String?
        var contentLength: Int64?
    }

    /// Probe a URL without downloading the whole file.  Issues a HEAD
    /// request first, falls back to a small Range GET when HEAD
    /// returns a non-success status (some publishers reject HEAD).
    /// Caller is responsible for offloading to a background task
    /// — this method awaits URLSession.
    static func previewURL(_ url: URL, expectedKind: InstallSpec.Kind) async -> URLPreview {
        var headReq = URLRequest(url: url)
        headReq.httpMethod = "HEAD"
        headReq.timeoutInterval = 10

        var status: Int = 0
        var contentType: String?
        var contentLength: Int64?
        if let (_, resp) = try? await URLSession.shared.data(for: headReq),
           let http = resp as? HTTPURLResponse {
            status = http.statusCode
            contentType = http.value(forHTTPHeaderField: "Content-Type")
            if let lenStr = http.value(forHTTPHeaderField: "Content-Length"),
               let len = Int64(lenStr) {
                contentLength = len
            }
        }

        if status >= 400 || status == 0 {
            // Fall back to a tiny Range GET — some servers reject HEAD.
            var rangeReq = URLRequest(url: url)
            rangeReq.timeoutInterval = 10
            rangeReq.setValue("bytes=0-4095", forHTTPHeaderField: "Range")
            if let (_, resp) = try? await URLSession.shared.data(for: rangeReq),
               let http = resp as? HTTPURLResponse {
                status = http.statusCode
                contentType = contentType ?? http.value(forHTTPHeaderField: "Content-Type")
                if contentLength == nil,
                   let lenStr = http.value(forHTTPHeaderField: "Content-Length"),
                   let len = Int64(lenStr) {
                    contentLength = len
                }
            }
        }

        if status >= 400 {
            return URLPreview(
                verdict: .fatal(reason: "The publisher's download URL returned HTTP \(status). Use the publisher's site to update manually."),
                contentType: contentType,
                contentLength: contentLength
            )
        }
        if status == 0 {
            return URLPreview(
                verdict: .warning(reason: "Couldn't reach the source URL."),
                contentType: contentType,
                contentLength: contentLength
            )
        }

        // Plausible content-type for each kind.  We're permissive —
        // many publishers serve `application/octet-stream` for any
        // binary, which is fine.
        if let ct = contentType?.lowercased() {
            if ct.contains("text/html") || ct.contains("text/plain") {
                return URLPreview(
                    verdict: .fatal(reason: "The source URL serves an HTML page, not a binary. The publisher's download link may have moved."),
                    contentType: contentType,
                    contentLength: contentLength
                )
            }
        }

        // Content-length sanity: anything under 64 KiB is almost
        // certainly a stub or error page for a real installer.  Be
        // strict here — .pkg / .dmg / .zip installers in the wild are
        // always larger.
        if let len = contentLength, len > 0, len < 64 * 1024 {
            return URLPreview(
                verdict: .warning(reason: "The source URL returned a tiny file (\(len) bytes) — may be a stub or error page."),
                contentType: contentType,
                contentLength: contentLength
            )
        }

        return URLPreview(
            verdict: .ok,
            contentType: contentType,
            contentLength: contentLength
        )
    }
}
