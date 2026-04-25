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

        if emitJSON {
            struct Out: Encodable {
                let total: Int; let ok: Int; let failing: Int; let rotted: [Item]
                struct Item: Encodable {
                    let entry, alt, kind, url, status: String; let elapsedMs: Int
                }
            }
            let out = Out(
                total: checks.count,
                ok: checks.count - failing.count,
                failing: failing.count,
                rotted: failing.map { .init(entry: $0.entry, alt: $0.altID,
                                            kind: $0.kind, url: $0.url,
                                            status: $0.shortMessage,
                                            elapsedMs: $0.elapsedMs) }
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
                print("")
                print("Rotted URLs (\(failing.count) of \(checks.count)):")
                print("")
                for c in failing.sorted(by: { $0.entry < $1.entry }) {
                    print("  [\(c.shortMessage)]  \(c.entry)  \(c.kind)  \(c.altID)")
                    print("     → \(c.url)")
                }
            }
            print("")
            print("Total: \(checks.count) · OK: \(checks.count - failing.count) · Rotted: \(failing.count)")
        }

        if failOnRot && !failing.isEmpty {
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
