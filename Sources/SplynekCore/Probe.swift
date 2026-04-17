import Foundation

enum ProbeError: Error, LocalizedError {
    case invalidURL
    case noContentLength
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "Invalid URL."
        case .noContentLength:  return "Server didn't report Content-Length."
        case .httpStatus(let s): return "HTTP \(s)."
        }
    }
}

/// Probe a URL with HEAD (falling back to a 1-byte ranged GET) to determine
/// content length, Range support, suggested filename, and cache-validator
/// headers (ETag / Last-Modified) used for resume.
enum Probe {

    static func run(_ url: URL, extraHeaders: [String: String] = [:]) async throws -> ProbeResult {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpShouldUsePipelining = false
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: cfg)
        defer { session.invalidateAndCancel() }

        var head = URLRequest(url: url)
        head.httpMethod = "HEAD"
        head.setValue("Splynek/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
        Self.applyAuth(from: url, to: &head, extras: extraHeaders)
        if let (_, headResp) = try? await session.data(for: head),
           let http = headResp as? HTTPURLResponse,
           (200..<400).contains(http.statusCode),
           let length = http.expectedContentLengthOrHeader, length > 0 {
            let accepts = (http.value(forHTTPHeaderField: "Accept-Ranges") ?? "")
                .lowercased().contains("bytes")
            return ProbeResult(
                totalBytes: length,
                supportsRange: accepts,
                suggestedFilename: filename(from: http, url: http.url ?? url),
                finalURL: http.url ?? url,
                etag: http.value(forHTTPHeaderField: "ETag"),
                lastModified: http.value(forHTTPHeaderField: "Last-Modified")
            )
        }

        var ranged = URLRequest(url: url)
        ranged.httpMethod = "GET"
        ranged.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        ranged.setValue("Splynek/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
        Self.applyAuth(from: url, to: &ranged, extras: extraHeaders)
        let (_, resp) = try await session.data(for: ranged)
        guard let http = resp as? HTTPURLResponse else {
            throw ProbeError.httpStatus(0)
        }
        if http.statusCode == 206 {
            let total = parseTotalFromContentRange(http.value(forHTTPHeaderField: "Content-Range"))
            guard total > 0 else { throw ProbeError.noContentLength }
            return ProbeResult(
                totalBytes: total,
                supportsRange: true,
                suggestedFilename: filename(from: http, url: http.url ?? url),
                finalURL: http.url ?? url,
                etag: http.value(forHTTPHeaderField: "ETag"),
                lastModified: http.value(forHTTPHeaderField: "Last-Modified")
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProbeError.httpStatus(http.statusCode)
        }
        guard let length = http.expectedContentLengthOrHeader, length > 0 else {
            throw ProbeError.noContentLength
        }
        return ProbeResult(
            totalBytes: length,
            supportsRange: false,
            suggestedFilename: filename(from: http, url: http.url ?? url),
            finalURL: http.url ?? url,
            etag: http.value(forHTTPHeaderField: "ETag"),
            lastModified: http.value(forHTTPHeaderField: "Last-Modified")
        )
    }

    /// Set `Authorization: Basic <b64>` from URL userinfo (if present) and
    /// apply any caller-supplied extra headers. Extras win over auto-auth.
    static func applyAuth(from url: URL, to req: inout URLRequest,
                          extras: [String: String]) {
        if let user = url.user, let pass = url.password {
            let token = "\(user):\(pass)".data(using: .utf8)?.base64EncodedString() ?? ""
            req.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in extras {
            req.setValue(v, forHTTPHeaderField: k)
        }
    }

    private static func parseTotalFromContentRange(_ value: String?) -> Int64 {
        guard let v = value else { return 0 }
        if let slash = v.lastIndex(of: "/") {
            let tail = v[v.index(after: slash)...]
            return Int64(tail) ?? 0
        }
        return 0
    }

    private static func filename(from http: HTTPURLResponse, url: URL) -> String {
        if let disp = http.value(forHTTPHeaderField: "Content-Disposition"),
           let range = disp.range(of: "filename=") {
            var name = String(disp[range.upperBound...])
            if let semi = name.firstIndex(of: ";") { name = String(name[..<semi]) }
            name = name.trimmingCharacters(in: .whitespaces)
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !name.isEmpty { return Sanitize.filename(name) }
        }
        return Sanitize.filename(url.lastPathComponent)
    }
}

private extension HTTPURLResponse {
    var expectedContentLengthOrHeader: Int64? {
        if expectedContentLength > 0 { return expectedContentLength }
        if let s = value(forHTTPHeaderField: "Content-Length"), let n = Int64(s), n > 0 {
            return n
        }
        return nil
    }
}
