#!/usr/bin/env swift

// v1.4 quality engine: concurrent online URL checker.
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
    }
    let altID: String
    let entry: String
    let kind: String   // "homepage" or "download"
    let url: String
    let status: Status
    let elapsedMs: Int

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
        }
    }
}

// MARK: - HTTP

func checkURL(_ url: URL, timeout: TimeInterval) async -> (Check.Status, Int) {
    let t0 = Date()
    var req = URLRequest(url: url, timeoutInterval: timeout)
    req.httpMethod = "HEAD"
    req.setValue("Splynek-URLChecker/1.4 (+https://splynek.app)", forHTTPHeaderField: "User-Agent")
    req.setValue("*/*", forHTTPHeaderField: "Accept")

    do {
        let (_, response) = try await URLSession.shared.data(for: req)
        let elapsed = Int(Date().timeIntervalSince(t0) * 1000)
        guard let http = response as? HTTPURLResponse else {
            return (.unparseable, elapsed)
        }
        if http.statusCode == 405 || http.statusCode == 403 {
            // Retry with GET — some hosts block HEAD.
            var getReq = req; getReq.httpMethod = "GET"
            let (_, resp2) = try await URLSession.shared.data(for: getReq)
            let el2 = Int(Date().timeIntervalSince(t0) * 1000)
            if let h2 = resp2 as? HTTPURLResponse {
                return (classify(h2, originalURL: url), el2)
            }
            return (.unparseable, el2)
        }
        return (classify(http, originalURL: url), elapsed)
    } catch {
        let elapsed = Int(Date().timeIntervalSince(t0) * 1000)
        let ns = error as NSError
        if ns.code == NSURLErrorTimedOut { return (.timeout, elapsed) }
        return (.networkError(ns.domain + "/" + String(ns.code)), elapsed)
    }
}

func classify(_ http: HTTPURLResponse, originalURL: URL) -> Check.Status {
    let code = http.statusCode
    if (200...299).contains(code) { return .ok(code) }
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

var i = 0
while i < args.count {
    let a = args[i]
    switch a {
    case "--json":         emitJSON = true
    case "--fail-on-rot":  failOnRot = true
    case "--only-download": onlyDownload = true
    case "--only-homepage": onlyHomepage = true
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

        --json              Emit JSON to stdout instead of text.
        --fail-on-rot       Exit non-zero if any URL rots.
        --concurrency N     Parallel workers (default 20).
        --timeout S         Per-request timeout seconds (default 15).
        --only-download     Check only downloadURLs (skip homepages).
        --only-homepage     Check only homepages (skip downloadURLs).
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
                        let (status, elapsed) = await checkURL(t.url, timeout: perRequestTimeout)
                        return (idx, Check(altID: t.altID, entry: t.entryID,
                                           kind: t.kind, url: t.urlStr,
                                           status: status, elapsedMs: elapsed))
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

        if emitJSON {
            struct Out: Encodable {
                let total: Int
                let ok: Int
                let failing: Int
                let rottedCount: Int
                let transientCount: Int
                let rotted: [Item]
                let transient: [Item]
                struct Item: Encodable {
                    let entry, alt, kind, url, status: String; let elapsedMs: Int
                }
            }
            let mapper: (Check) -> Out.Item = {
                .init(entry: $0.entry, alt: $0.altID, kind: $0.kind,
                      url: $0.url, status: $0.shortMessage,
                      elapsedMs: $0.elapsedMs)
            }
            let out = Out(
                total: checks.count,
                ok: checks.count - failing.count,
                failing: failing.count,
                rottedCount: rotted.count,
                transientCount: transient.count,
                rotted: rotted.map(mapper),
                transient: transient.map(mapper)
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
            print("Total: \(checks.count) · OK: \(checks.count - failing.count) · Rotted: \(rotted.count) · Transient: \(transient.count)")
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
