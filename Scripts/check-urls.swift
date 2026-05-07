#!/usr/bin/env swift

// v1.5.7 quality engine: concurrent online URL checker + Content-Type
// validator + auto-pruner.
//
// Hits every homepage + downloadURL in Scripts/sovereignty-catalog.json
// with a HEAD (falling back to GET if HEAD isn't allowed) and reports
// which URLs rot.  Over a 1000+ entry catalog this is the thing that
// silently decays fastest — domains expire, projects migrate, redirects
// change.
//
// Concurrent.  Default 20 workers.  ~1 min for a 2000-URL sweep on a
// decent connection.  Output: text summary + a JSON diff file so CI
// can compare week-over-week.
//
// Run from the repo root:
//
//   swift Scripts/check-urls.swift                # text report
//   swift Scripts/check-urls.swift --json         # JSON report on stdout
//   swift Scripts/check-urls.swift --fail-on-rot  # exit non-zero if any URL rots
//
// Zero third-party deps.  Only uses URLSession which is always
// available on Apple platforms + Linux via swift-corelibs-foundation.

import Foundation

// MARK: - JSON shape

struct RawAlt: Decodable {
    let id: String
    let homepage: String
    let downloadURL: String?
}
struct RawEntry: Decodable {
    let targetBundleID: String
    let targetDisplayName: String
    let alternatives: [RawAlt]
}
struct RawCatalog: Decodable {
    let version: Int
    let entries: [RawEntry]
}

// MARK: - Check result

struct Check {
    enum Status {
        case ok(Int)           // 2xx
        case redirect(Int, String)  // 3xx landing final URL
        case clientError(Int)  // 4xx
        case serverError(Int)  // 5xx
        case networkError(String)
        case timeout
        case unparseable
        // v1.5.7: returned 2xx/3xx but Content-Type proves the response is a
        // landing page, not the binary installer the catalog promised.  This
        // is the "78% manual-verification failure mode" — GitHub releases/latest
        // patterns where the artifact filename embedded a version number, so
        // `releases/latest/download/Foo.dmg` 404'd silently into Foo's HTML 404
        // page (which still status-200s with a friendly browser message).
        case wrongContentType(Int, String)  // (statusCode, contentTypeReturned)
    }
    let altID: String
    let entry: String
    let kind: String   // "homepage" or "download"
    let url: String
    let status: Status
    let elapsedMs: Int
    let contentType: String?  // captured for diagnostics + downstream Content-Type checks

    var isOK: Bool {
        switch status {
        case .ok, .redirect: return true
        default: return false
        }
    }

    /// v1.5.6: classify *failures* — true rot vs transient.  The 2026-04-27
    /// weekly run flagged 115 URLs but ~95 were transient: 429 rate-limits
    /// (mubi.com, chat.mistral.ai hit dozens of times across the catalog),
    /// 403 from CDN bot-blocks (clamxav.com), and -1003/-1004/-1005 network
    /// blips from the runner.  Real rot is a small minority — separating
    /// the two so the weekly issue isn't drowned in noise.
    var isTransient: Bool {
        switch status {
        case .ok, .redirect: return false
        case .clientError(let code):
            // 429 = rate limit; 403 = often CDN bot-block (Cloudflare,
            // AWS WAF, etc.); 405 after the HEAD→GET retry usually means
            // the host is rejecting our UA on principle (mubi.com does
            // this).  None of these prove the URL itself is rotted.
            return code == 429 || code == 403 || code == 405
        case .serverError(let code):
            // 5xx is almost always transient — bad gateway, CF timeout,
            // overloaded origin.  Worth re-checking next week, not
            // worth a maintainer ping today.
            return (500...599).contains(code)
        case .networkError(let m):
            // NSURLErrorDomain codes for transient: -1001 timed out,
            // -1003 cannot find host (DNS hiccup), -1004 cannot connect,
            // -1005 connection lost, -1009 not connected to internet.
            // -1002 (unsupported URL) IS rot.
            return m.contains("/-1001") || m.contains("/-1003")
                || m.contains("/-1004") || m.contains("/-1005")
                || m.contains("/-1009")
        case .timeout:
            return true
        case .unparseable:
            return false  // genuine — URL is malformed
        case .wrongContentType:
            // Catalog lied about what's at this URL — not transient,
            // it's a maintainer error.
            return false
        }
    }

    var shortMessage: String {
        switch status {
        case .ok(let code):              return "\(code)"
        case .redirect(let code, _):     return "\(code)→"
        case .clientError(let code):     return "\(code)"
        case .serverError(let code):     return "\(code)"
        case .networkError(let m):       return "net:\(m)"
        case .timeout:                   return "timeout"
        case .unparseable:               return "unparseable"
        case .wrongContentType(let code, let ct): return "\(code) html(\(ct))"
        }
    }
}

// MARK: - Content-Type heuristics
//
// What a *real* downloadURL must return.  Apple platforms commonly serve:
//   application/x-apple-diskimage   (DMG)
//   application/x-iso9660-image     (ISO/DMG sometimes)
//   application/octet-stream        (everything else — CDNs default to this)
//   application/zip                 (Ollama, iTerm2)
//   application/x-xar               (PKG)
//   application/x-newton-compatible-pkg (PKG variant)
//   application/x-msdownload        (rare — installers signed as MSI/EXE wrappers)
//
// HTML / text returns — even with status 200 — are landing pages.  This is
// the exact failure mode the manual 2026-05-06 verification round caught:
// `releases/latest/download/Foo.dmg` patterns whose artifact filename
// embedded a version number 404'd silently into a friendly HTML 404 page.
//
// Returns true if the Content-Type is acceptable for a binary download.
func isBinaryContentType(_ ct: String?) -> Bool {
    guard let raw = ct?.lowercased() else { return false }
    // Strip parameters: "application/zip; charset=binary" → "application/zip"
    let mime = raw.split(separator: ";").first.map(String.init)?
        .trimmingCharacters(in: .whitespaces) ?? raw
    if mime.hasPrefix("application/") {
        // Reject application/json, application/xml, application/javascript,
        // application/xhtml+xml — those are all "the server is talking to
        // you", not "here's your installer".
        if mime == "application/json" || mime == "application/xml"
            || mime == "application/xhtml+xml" || mime == "application/javascript"
            || mime == "application/ld+json" {
            return false
        }
        return true
    }
    // text/*, image/*, video/* — not an installer.
    return false
}

// MARK: - HTTP

/// Returns (status, elapsedMs, capturedContentType).  The Content-Type is the
/// raw value of the response's `Content-Type` header (or nil if absent), used
/// downstream by `classifyDownload` to flag HTML-landing-pages-on-2xx.
func checkURL(_ url: URL, timeout: TimeInterval, kind: String)
    async -> (Check.Status, Int, String?)
{
    let t0 = Date()
    var req = URLRequest(url: url, timeoutInterval: timeout)
    req.httpMethod = "HEAD"
    req.setValue("Splynek-URLChecker/1.5 (+https://splynek.app)", forHTTPHeaderField: "User-Agent")
    req.setValue("*/*", forHTTPHeaderField: "Accept")

    func extractCT(_ http: HTTPURLResponse) -> String? {
        // Header lookup is case-insensitive per RFC 7230, but
        // HTTPURLResponse.allHeaderFields is a plain dictionary.  Try a few
        // common casings.
        for key in ["Content-Type", "content-type", "Content-type"] {
            if let v = http.value(forHTTPHeaderField: key) { return v }
        }
        return nil
    }

    do {
        let (_, response) = try await URLSession.shared.data(for: req)
        let elapsed = Int(Date().timeIntervalSince(t0) * 1000)
        guard let http = response as? HTTPURLResponse else {
            return (.unparseable, elapsed, nil)
        }
        if http.statusCode == 405 || http.statusCode == 403 {
            // Retry with GET — some hosts block HEAD.  Some hosts also
            // serve different Content-Type on HEAD vs GET (returning
            // text/html for HEAD even when GET would yield octet-stream),
            // so the GET retry also gives us a more accurate content type.
            var getReq = req; getReq.httpMethod = "GET"
            // Limit body reads on the GET retry — we only need headers.
            // URLSession doesn't expose a built-in cap, but in practice
            // most CDNs respect Range; harmless if ignored.
            getReq.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            let (_, resp2) = try await URLSession.shared.data(for: getReq)
            let el2 = Int(Date().timeIntervalSince(t0) * 1000)
            if let h2 = resp2 as? HTTPURLResponse {
                let ct = extractCT(h2)
                return (classify(h2, contentType: ct, kind: kind), el2, ct)
            }
            return (.unparseable, el2, nil)
        }
        let ct = extractCT(http)
        return (classify(http, contentType: ct, kind: kind), elapsed, ct)
    } catch {
        let elapsed = Int(Date().timeIntervalSince(t0) * 1000)
        let ns = error as NSError
        if ns.code == NSURLErrorTimedOut { return (.timeout, elapsed, nil) }
        return (.networkError(ns.domain + "/" + String(ns.code)), elapsed, nil)
    }
}

func classify(_ http: HTTPURLResponse, contentType: String?, kind: String) -> Check.Status {
    let code = http.statusCode
    if (200...299).contains(code) {
        // For downloadURLs, a 2xx alone isn't enough — the response body must
        // actually be a binary, not a "we couldn't find that page but here's
        // a 200 anyway" landing page.  Homepages legitimately return text/html.
        if kind == "download" && !isBinaryContentType(contentType) {
            return .wrongContentType(code, contentType ?? "(none)")
        }
        return .ok(code)
    }
    if (300...399).contains(code) {
        let landing = http.url?.absoluteString ?? ""
        return .redirect(code, landing)
    }
    if (400...499).contains(code) { return .clientError(code) }
    if (500...599).contains(code) { return .serverError(code) }
    return .unparseable
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())
var emitJSON = false
var failOnRot = false
var concurrency = 20
var perRequestTimeout: TimeInterval = 15
var onlyDownload = false
var onlyHomepage = false
// v1.5.7: --prune-broken-downloads removes downloadURLs from the catalog
// that fail verification (true rot only — transient failures are skipped so
// a flaky run doesn't strip working URLs).  The alternative entry stays;
// only its downloadURL field is dropped, falling back to homepage-only.
// Used by the weekly cron to open an auto-PR rather than a tracking issue.
var pruneBroken = false

var i = 0
while i < args.count {
    let a = args[i]
    switch a {
    case "--json":         emitJSON = true
    case "--fail-on-rot":  failOnRot = true
    case "--only-download": onlyDownload = true
    case "--only-homepage": onlyHomepage = true
    case "--prune-broken-downloads":
        pruneBroken = true
        // Pruning implies download-only verification.  No reason to spend
        // time checking homepages when we're not going to act on them.
        onlyDownload = true
    case "--concurrency":
        if i + 1 < args.count, let v = Int(args[i+1]) {
            concurrency = v; i += 1
        }
    case "--timeout":
        if i + 1 < args.count, let v = TimeInterval(args[i+1]) {
            perRequestTimeout = v; i += 1
        }
    case "--help", "-h":
        print("""
        check-urls.swift — online URL liveness check for sovereignty-catalog.json

        Usage:
          swift Scripts/check-urls.swift [flags]

        --json                       Emit JSON to stdout instead of text.
        --fail-on-rot                Exit non-zero if any URL rots.
        --concurrency N              Parallel workers (default 20).
        --timeout S                  Per-request timeout seconds (default 15).
        --only-download              Check only downloadURLs (skip homepages).
        --only-homepage              Check only homepages (skip downloadURLs).
        --prune-broken-downloads     Verify all downloadURLs and rewrite
                                     Scripts/sovereignty-catalog.json with broken
                                     ones removed.  Only true rot is pruned;
                                     transient failures (429 / 5xx / DNS blips)
                                     are left alone.  Implies --only-download.
                                     This includes Content-Type validation:
                                     a 200 OK that returns text/html on a
                                     downloadURL is treated as broken (it's
                                     a landing page, not a binary installer).
        """)
        exit(0)
    default:
        fputs("warn: unknown flag '\(a)'\n", stderr)
    }
    i += 1
}

func run() async {
        let jsonURL = URL(fileURLWithPath: "Scripts/sovereignty-catalog.json")
        guard let data = try? Data(contentsOf: jsonURL),
              let cat = try? JSONDecoder().decode(RawCatalog.self, from: data) else {
            fputs("error: could not read Scripts/sovereignty-catalog.json\n", stderr)
            exit(1)
        }

        // Build task list.
        struct URLTask { let altID, entryID, kind, urlStr: String; let url: URL }
        var tasks: [URLTask] = []
        for entry in cat.entries {
            for alt in entry.alternatives {
                if !onlyDownload, let u = URL(string: alt.homepage) {
                    tasks.append(.init(altID: alt.id, entryID: entry.targetBundleID,
                                       kind: "homepage", urlStr: alt.homepage, url: u))
                }
                if !onlyHomepage, let dl = alt.downloadURL, let u = URL(string: dl) {
                    tasks.append(.init(altID: alt.id, entryID: entry.targetBundleID,
                                       kind: "download", urlStr: dl, url: u))
                }
            }
        }

        if !emitJSON {
            fputs("Checking \(tasks.count) URLs with \(concurrency) workers (\(Int(perRequestTimeout))s timeout)…\n", stderr)
        }

        // Concurrent worker pool.
        var results = [Check?](repeating: nil, count: tasks.count)
        await withTaskGroup(of: (Int, Check).self) { group in
            var inFlight = 0
            var nextIdx = 0
            while nextIdx < tasks.count || inFlight > 0 {
                while inFlight < concurrency && nextIdx < tasks.count {
                    let idx = nextIdx
                    let t = tasks[idx]
                    group.addTask {
                        let (status, elapsed, ct) = await checkURL(
                            t.url, timeout: perRequestTimeout, kind: t.kind)
                        return (idx, Check(altID: t.altID, entry: t.entryID,
                                           kind: t.kind, url: t.urlStr,
                                           status: status, elapsedMs: elapsed,
                                           contentType: ct))
                    }
                    inFlight += 1
                    nextIdx += 1
                }
                if let (idx, check) = await group.next() {
                    inFlight -= 1
                    results[idx] = check
                    if !emitJSON && results.compactMap({ $0 }).count % 50 == 0 {
                        fputs("  … \(results.compactMap { $0 }.count) / \(tasks.count)\n", stderr)
                    }
                }
            }
        }

        let checks = results.compactMap { $0 }
        let failing = checks.filter { !$0.isOK }
        // v1.5.6: split failures into transient (429 / 403 / 5xx /
        // network blips) vs true rot.  Only true rot blocks `--fail-on-rot`
        // and lands at the top of the report.  Transient flows into a
        // secondary list so the maintainer can scan it but isn't paged.
        let rotted    = failing.filter { !$0.isTransient }
        let transient = failing.filter {  $0.isTransient }

        // v1.5.7: --prune-broken-downloads — rewrite the catalog in place,
        // dropping downloadURL fields whose verification failed (true rot
        // only, never transient).  Done with JSONSerialization so we
        // preserve everything else (notes, origin, ordering) byte-for-byte.
        var prunedCount = 0
        if pruneBroken {
            // Build the set of (entryBundleID, altID) tuples whose download
            // failed for real.  Only `kind == "download"` makes it in; we
            // already restricted tasks to download-only via onlyDownload.
            let toPrune: Set<String> = Set(rotted
                .filter { $0.kind == "download" }
                .map { "\($0.entry)\u{0001}\($0.altID)" })

            if !toPrune.isEmpty {
                guard
                    let raw = try? Data(contentsOf: jsonURL),
                    var root = try? JSONSerialization.jsonObject(with: raw, options: []) as? [String: Any],
                    var entries = root["entries"] as? [[String: Any]]
                else {
                    fputs("error: --prune-broken-downloads couldn't reparse catalog\n", stderr)
                    exit(1)
                }
                for ei in 0..<entries.count {
                    guard
                        let bid = entries[ei]["targetBundleID"] as? String,
                        var alts = entries[ei]["alternatives"] as? [[String: Any]]
                    else { continue }
                    for ai in 0..<alts.count {
                        guard let aid = alts[ai]["id"] as? String else { continue }
                        let key = "\(bid)\u{0001}\(aid)"
                        if toPrune.contains(key) && alts[ai]["downloadURL"] != nil {
                            alts[ai].removeValue(forKey: "downloadURL")
                            prunedCount += 1
                        }
                    }
                    entries[ei]["alternatives"] = alts
                }
                root["entries"] = entries
                // Match the existing catalog's formatting: 2-space indent,
                // sorted keys, no escaped slashes.  This minimizes diff
                // noise so the auto-PR is a clean read.
                let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                if let outData = try? JSONSerialization.data(withJSONObject: root, options: opts) {
                    do {
                        try outData.write(to: jsonURL)
                        // JSONSerialization uses 2-space indent already on
                        // macOS; appending a trailing newline to match Git
                        // / POSIX file convention.
                        if let fh = try? FileHandle(forWritingTo: jsonURL) {
                            try fh.seekToEnd()
                            fh.write(Data([0x0A]))
                            try fh.close()
                        }
                    } catch {
                        fputs("error: failed to write pruned catalog: \(error)\n", stderr)
                        exit(1)
                    }
                } else {
                    fputs("error: failed to encode pruned catalog\n", stderr)
                    exit(1)
                }
            }
            if !emitJSON {
                fputs("Pruned \(prunedCount) broken downloadURL(s) from the catalog.\n", stderr)
            }
        }

        if emitJSON {
            struct Out: Encodable {
                let total: Int
                let ok: Int
                let failing: Int
                let rottedCount: Int
                let transientCount: Int
                let rotted: [Item]
                let transient: [Item]
                let prunedCount: Int  // 0 if not in --prune-broken-downloads mode
                struct Item: Encodable {
                    let entry, alt, kind, url, status: String
                    let contentType: String?
                    let elapsedMs: Int
                }
            }
            let mapper: (Check) -> Out.Item = {
                .init(entry: $0.entry, alt: $0.altID, kind: $0.kind,
                      url: $0.url, status: $0.shortMessage,
                      contentType: $0.contentType,
                      elapsedMs: $0.elapsedMs)
            }
            let out = Out(
                total: checks.count,
                ok: checks.count - failing.count,
                failing: failing.count,
                rottedCount: rotted.count,
                transientCount: transient.count,
                rotted: rotted.map(mapper),
                transient: transient.map(mapper),
                prunedCount: prunedCount
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            if let d = try? encoder.encode(out),
               let s = String(data: d, encoding: .utf8) {
                print(s)
            }
        } else {
            if failing.isEmpty {
                print("✓ All \(checks.count) URLs respond with 2xx or 3xx.")
            } else {
                if !rotted.isEmpty {
                    print("")
                    print("Rotted URLs — likely real (\(rotted.count) of \(checks.count)):")
                    print("")
                    for c in rotted.sorted(by: { $0.entry < $1.entry }) {
                        print("  [\(c.shortMessage)]  \(c.entry)  \(c.kind)  \(c.altID)")
                        print("     → \(c.url)")
                    }
                }
                if !transient.isEmpty {
                    print("")
                    print("Transient (rate-limit / CDN block / network blip) — re-check next run (\(transient.count)):")
                    print("")
                    for c in transient.sorted(by: { $0.entry < $1.entry }) {
                        print("  [\(c.shortMessage)]  \(c.entry)  \(c.kind)  \(c.altID)")
                        print("     → \(c.url)")
                    }
                }
            }
            print("")
            var summary = "Total: \(checks.count) · OK: \(checks.count - failing.count) · Rotted: \(rotted.count) · Transient: \(transient.count)"
            if pruneBroken { summary += " · Pruned: \(prunedCount)" }
            print(summary)
        }

        // v1.5.6: only true rot fails the run — transient noise (rate
        // limits, CDN bot-blocks, intermittent DNS / connection-reset)
        // gets reported but doesn't page the maintainer.
        if failOnRot && !rotted.isEmpty {
            exit(2)
        }
}

// Swift script top-level async entry: spin a Task, wait on a semaphore.
let __done = DispatchSemaphore(value: 0)
Task {
    await run()
    __done.signal()
}
__done.wait()
