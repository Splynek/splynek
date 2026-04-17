import Foundation
import SplynekCore

/// Splynek command-line client. Talks to a locally-running Splynek.app
/// via the documented REST API (see `/splynek/v1/openapi.yaml`).
///
/// Discovery: the app writes `~/Library/Application Support/Splynek/
/// fleet.json` containing `{ port, token, ... }` whenever its HTTP
/// listener binds. This CLI reads that file; no env vars, no config.
///
/// Usage:
///   splynek download <url>   # start
///   splynek queue <url>      # append to queue
///   splynek status           # list active jobs as a table
///   splynek history [N]      # last N completions (default 10)
///   splynek cancel           # cancel every running job
///   splynek version          # CLI + spec versions
///   splynek openapi          # print the OpenAPI YAML to stdout
///
/// Exit codes:
///   0  — success
///   1  — usage error
///   2  — app not running / fleet.json missing
///   3  — HTTP error from local Splynek

@main
struct CLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let cmd = args.first else { usage(); exit(1) }
        let rest = Array(args.dropFirst())
        switch cmd {
        case "download":  runSubmit(rest, action: "download")
        case "queue":     runSubmit(rest, action: "queue")
        case "status":    runStatus()
        case "history":   runHistory(rest)
        case "cancel":    runCancel()
        case "openapi":   runOpenAPI()
        case "version":   runVersion()
        case "-h", "--help", "help":  usage(); exit(0)
        default:          usage(); exit(1)
        }
    }

    // MARK: Commands

    static func runSubmit(_ args: [String], action: String) {
        guard let url = args.first, !url.isEmpty else {
            print("usage: splynek \(action) <url>")
            exit(1)
        }
        let d = requireDescriptor()
        let body: [String: Any] = ["url": url]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
            print("error: could not encode body")
            exit(1)
        }
        let endpoint = "http://127.0.0.1:\(d.port)/splynek/v1/api/\(action)?t=\(d.token)"
        guard let (_, status) = post(endpoint, body: payload) else {
            print("error: request failed")
            exit(3)
        }
        if status == 202 {
            print("✓ \(action): \(url)")
        } else {
            print("✗ \(action) failed with HTTP \(status)")
            exit(3)
        }
    }

    static func runStatus() {
        let d = requireDescriptor()
        guard let (data, status) = get("http://127.0.0.1:\(d.port)/splynek/v1/api/jobs"),
              status == 200 else {
            print("error: could not fetch jobs")
            exit(3)
        }
        struct Job: Decodable {
            let url: String
            let filename: String
            let totalBytes: Int64
            let downloaded: Int64
        }
        guard let jobs = try? JSONDecoder().decode([Job].self, from: data) else {
            print("error: could not decode response")
            exit(3)
        }
        if jobs.isEmpty {
            print("No active downloads.")
            return
        }
        print("ACTIVE  |  %      |  SIZE      |  FILENAME")
        print(String(repeating: "-", count: 64))
        for j in jobs {
            let pct = j.totalBytes > 0
                ? String(format: "%5.1f%%", (Double(j.downloaded) / Double(j.totalBytes)) * 100)
                : "    —"
            print("        |  \(pct) |  \(bytes(j.totalBytes).padding(toLength: 10, withPad: " ", startingAt: 0))|  \(j.filename)")
        }
    }

    static func runHistory(_ args: [String]) {
        let limit = Int(args.first ?? "10") ?? 10
        let d = requireDescriptor()
        guard let (data, status) = get("http://127.0.0.1:\(d.port)/splynek/v1/api/history?limit=\(limit)"),
              status == 200 else {
            print("error: could not fetch history")
            exit(3)
        }
        struct H: Decodable {
            let url: String
            let filename: String
            let totalBytes: Int64
            let finishedAt: String
            let sha256: String?
        }
        guard let entries = try? JSONDecoder().decode([H].self, from: data) else {
            print("error: could not decode response")
            exit(3)
        }
        if entries.isEmpty {
            print("No downloads yet.")
            return
        }
        for e in entries {
            let shaPreview = e.sha256.map { String($0.prefix(12)) } ?? "-"
            print("\(e.finishedAt)  \(bytes(e.totalBytes).padding(toLength: 8, withPad: " ", startingAt: 0))  \(shaPreview)  \(e.filename)")
        }
    }

    static func runCancel() {
        let d = requireDescriptor()
        let endpoint = "http://127.0.0.1:\(d.port)/splynek/v1/api/cancel?t=\(d.token)"
        guard let (_, status) = post(endpoint, body: Data()) else {
            print("error: request failed")
            exit(3)
        }
        if status == 202 {
            print("✓ cancelled all")
        } else {
            print("✗ cancel failed with HTTP \(status)")
            exit(3)
        }
    }

    static func runOpenAPI() {
        let d = requireDescriptor()
        guard let (data, status) = get("http://127.0.0.1:\(d.port)/splynek/v1/openapi.yaml"),
              status == 200 else {
            print("error: could not fetch openapi.yaml")
            exit(3)
        }
        if let s = String(data: data, encoding: .utf8) { print(s) }
    }

    static func runVersion() {
        // CLI version tracks the Splynek release; if we're talking to a
        // running app, show its port + device name too.
        print("splynek-cli 0.27.0")
        if let d = try? loadDescriptor() {
            print("  app: \(d.deviceName) on :\(d.port)")
        } else {
            print("  app: not running (no fleet.json)")
        }
    }

    // MARK: Discovery + HTTP

    static func loadDescriptor() throws -> FleetCoordinator.FleetDescriptor {
        let url = FleetCoordinator.fleetDescriptorURL
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FleetCoordinator.FleetDescriptor.self, from: data)
    }

    static func requireDescriptor() -> FleetCoordinator.FleetDescriptor {
        guard let d = try? loadDescriptor() else {
            let path = FleetCoordinator.fleetDescriptorURL.path
            print("error: Splynek isn't running, or it hasn't written \(path) yet.")
            print("  Launch Splynek.app and retry.")
            exit(2)
        }
        return d
    }

    static func get(_ urlStr: String) -> (Data, Int)? {
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        let sem = DispatchSemaphore(value: 0)
        var result: (Data, Int)?
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            if let data, let http = resp as? HTTPURLResponse {
                result = (data, http.statusCode)
            }
            sem.signal()
        }.resume()
        sem.wait()
        return result
    }

    static func post(_ urlStr: String, body: Data) -> (Data, Int)? {
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 5
        let sem = DispatchSemaphore(value: 0)
        var result: (Data, Int)?
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            if let data, let http = resp as? HTTPURLResponse {
                result = (data, http.statusCode)
            }
            sem.signal()
        }.resume()
        sem.wait()
        return result
    }

    // MARK: Formatting

    static func bytes(_ n: Int64) -> String {
        let u = ["B","KB","MB","GB","TB"]
        var d = Double(n), i = 0
        while d >= 1024, i < u.count - 1 { d /= 1024; i += 1 }
        return String(format: "%.1f %@", d, u[i])
    }

    static func usage() {
        let text = """
        splynek — command-line client for Splynek.app

        Usage:
          splynek download <url>      Start a new download
          splynek queue <url>         Append URL to persistent queue
          splynek status              List active jobs
          splynek history [limit]     Show recent completions (default 10)
          splynek cancel              Cancel all running jobs
          splynek openapi             Print the OpenAPI spec
          splynek version             Print versions + live app status

        Reads ~/Library/Application Support/Splynek/fleet.json to discover
        the app's port and submit token. Launch Splynek.app first.
        """
        print(text)
    }
}
