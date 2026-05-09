// Copyright © 2026 Splynek. MIT.
//
// PairedMacClient — HTTP client for the Splynek Mac REST API.
//
// The Mac side is FleetCoordinator (see
// `Sources/SplynekCore/FleetCoordinator.swift`).  All endpoints we
// hit here are token-gated via `?t=<webToken>`; the token is part of
// the PairedMac record (held in the keychain — never logged, never
// included in URL paths sent to telemetry).
//
// Endpoints used:
//   GET  /splynek/v1/status                      — pairing health probe
//   GET  /splynek/v1/api/jobs?t=<token>          — current active jobs
//   GET  /splynek/v1/api/history?t=<token>       — recent finished jobs
//   POST /splynek/v1/api/queue?t=<token>         — submit URL { "url": "..." }
//
// All calls have a short-by-default timeout (5s) so the Share Extension
// returns to the host app quickly even when the Mac is asleep / off the
// LAN.  Caller can extend via `URLSession.configuration` if needed.

import Foundation

public actor PairedMacClient {
    private let session: URLSession
    private let mac: PairedMac

    public init(mac: PairedMac, session: URLSession? = nil) {
        self.mac = mac
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.timeoutIntervalForRequest = 5
            cfg.timeoutIntervalForResource = 10
            cfg.waitsForConnectivity = false
            // Splynek's LAN server doesn't terminate TLS; allow http://.
            cfg.httpAdditionalHeaders = ["User-Agent": "Splynek-iOS/0.1"]
            self.session = URLSession(configuration: cfg)
        }
    }

    public enum ClientError: Error, Equatable {
        case notReachable
        case unauthorised
        case http(Int)
        case decode
        /// S4 phase 3 (2026-05-07): the URLSession `data(for:)` call
        /// timed out before any response.  Distinct from `notReachable`
        /// (DNS / connect-refused) so the relay-policy layer can
        /// decide whether to fall back to CloudKit.
        case timeout
    }

    /// Map a thrown error from `submit(...)` / `jobs()` into the
    /// `RelayPolicy.LANOutcome` shape.  Used by CloudKitRelaySubmitter
    /// callers to drive the LAN-first / CloudKit-fallback policy.
    public static func relayOutcome(for error: Error?) -> RelayPolicy.LANOutcome {
        guard let error else { return .success }
        if let ce = error as? ClientError {
            switch ce {
            case .notReachable: return .notReachable
            case .timeout:      return .timeout
            case .unauthorised: return .unauthorised
            case .http(let code): return .other(httpStatus: code)
            case .decode:       return .other(httpStatus: -2)
            }
        }
        let ns = error as NSError
        if ns.code == NSURLErrorTimedOut { return .timeout }
        if ns.code == NSURLErrorCannotConnectToHost
            || ns.code == NSURLErrorCannotFindHost
            || ns.code == NSURLErrorNetworkConnectionLost
            || ns.code == NSURLErrorNotConnectedToInternet {
            return .notReachable
        }
        return .other(httpStatus: -1)
    }

    /// `GET /splynek/v1/status` — confirms reachability + auth (the
    /// status endpoint is open, but we use the 200 reply to update
    /// `lastSeen` in the keychain).  Returns the raw body so callers
    /// can show the device name + version if they want.
    public func ping() async throws -> Data {
        let url = mac.baseURL!.appendingPathComponent("splynek/v1/status")
        let (data, resp) = try await session.data(from: url)
        try check(resp)
        return data
    }

    /// `POST /splynek/v1/api/queue?t=<token>` — submit a URL for the
    /// Mac to download.  Returns 202 Accepted.  The Share Extension
    /// calls this from `ShareViewController.didSelectPost`.
    public func queue(url: URL) async throws {
        try await submit(url: url, action: "queue")
    }

    /// `POST /splynek/v1/api/download?t=<token>` — same shape, but
    /// asks the Mac to start the download immediately rather than
    /// queueing.  We default to `queue` from the share sheet because
    /// the user might be on cellular and want to defer until home Wi-Fi.
    public func download(url: URL) async throws {
        try await submit(url: url, action: "download")
    }

    private func submit(url: URL, action: String) async throws {
        guard let endpoint = mac.baseURL?
            .appendingPathComponent("splynek/v1/api/\(action)")
        else { throw ClientError.notReachable }
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: mac.token)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable { let url: String }
        req.httpBody = try JSONEncoder().encode(Body(url: url.absoluteString))
        let (_, resp) = try await session.data(for: req)
        try check(resp)
    }

    /// `GET /splynek/v1/api/jobs?t=<token>` — the current active
    /// job list, decoded as a typed model.  The Mac returns a
    /// `WebDashboard.State`-shaped JSON; we only decode the subset
    /// the iOS UI needs.
    public func jobs() async throws -> [JobSummary] {
        guard let base = mac.baseURL?
            .appendingPathComponent("splynek/v1/api/jobs")
        else { throw ClientError.notReachable }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: mac.token)]
        let (data, resp) = try await session.data(from: comps.url!)
        try check(resp)
        struct Wire: Decodable {
            let jobs: [JobSummary]?
        }
        // Some endpoints return a top-level [JobSummary], others wrap
        // it as `{"jobs": [...]}`.  Handle both.
        if let wrapper = try? JSONDecoder().decode(Wire.self, from: data),
           let inner = wrapper.jobs {
            return inner
        }
        if let bare = try? JSONDecoder().decode([JobSummary].self, from: data) {
            return bare
        }
        throw ClientError.decode
    }

    private func check(_ resp: URLResponse) throws {
        guard let http = resp as? HTTPURLResponse else { throw ClientError.notReachable }
        if http.statusCode == 401 { throw ClientError.unauthorised }
        if !(200...299).contains(http.statusCode) {
            throw ClientError.http(http.statusCode)
        }
    }

    // MARK: - Sprint 1 PRO-PLUS-IPHONE — remote control + summary fetches
    //
    // These power the iOS App Intents (Hey Siri, pause Splynek
    // downloads), the Apple Watch quick actions, the Widget refresh,
    // and the Pro-on-iPhone Sovereignty / Trust / History views.
    //
    // All fail safely on free-tier Macs: 404 from
    // /api/trust-watcher/summary becomes a clean
    // `ClientError.http(404)` the caller can surface as "ask the Mac
    // owner to upgrade".

    /// `POST /splynek/v1/api/pause-all?t=<token>`.  Pauses every
    /// running download on the paired Mac.  Idempotent on the Mac
    /// side — already-paused jobs are untouched.
    public func pauseAll() async throws {
        try await postEmpty(action: "pause-all")
    }

    /// `POST /splynek/v1/api/resume-all?t=<token>`.
    public func resumeAll() async throws {
        try await postEmpty(action: "resume-all")
    }

    /// `GET /splynek/v1/api/sovereignty/summary?t=<token>`.
    /// Returns a small Codable snapshot suitable for a Widget
    /// render or a Sovereignty-on-iPhone view.
    public func sovereigntySummary() async throws -> RelaySummary.Sovereignty {
        try await getJSON(path: "splynek/v1/api/sovereignty/summary",
                          as: RelaySummary.Sovereignty.self)
    }

    /// `GET /splynek/v1/api/trust/summary?t=<token>`.
    public func trustSummary() async throws -> RelaySummary.Trust {
        try await getJSON(path: "splynek/v1/api/trust/summary",
                          as: RelaySummary.Trust.self)
    }

    /// `GET /splynek/v1/api/trust-watcher/summary?t=<token>`.
    /// Pro-only on the Mac side — throws `ClientError.http(404)` for
    /// free-tier Macs.  Callers (the iPhone Trust-Watcher view, the
    /// CloudKit subscription wiring) catch that specifically.
    public func trustWatcherSummary() async throws -> RelaySummary.TrustWatcher {
        try await getJSON(path: "splynek/v1/api/trust-watcher/summary",
                          as: RelaySummary.TrustWatcher.self)
    }

    /// `GET /splynek/v1/api/history/summary?t=<token>`.
    public func historySummary() async throws -> RelaySummary.History {
        try await getJSON(path: "splynek/v1/api/history/summary",
                          as: RelaySummary.History.self)
    }

    // MARK: - Internal generic helpers

    private func postEmpty(action: String) async throws {
        guard let endpoint = mac.baseURL?
            .appendingPathComponent("splynek/v1/api/\(action)")
        else { throw ClientError.notReachable }
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: mac.token)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, resp) = try await session.data(for: req)
        try check(resp)
    }

    private func getJSON<T: Decodable>(path: String, as: T.Type) async throws -> T {
        guard let base = mac.baseURL?.appendingPathComponent(path)
        else { throw ClientError.notReachable }
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "t", value: mac.token)]
        let (data, resp) = try await session.data(from: comps.url!)
        try check(resp)
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            throw ClientError.decode
        }
        return decoded
    }

    /// S4 phase 3 (2026-05-07): LAN-first submission with optional
    /// CloudKit-relay fallback.  Used by the Share Extension and
    /// the main app's SubmitURLView.
    ///
    /// Returns the outcome the UI should render — `.lan`, `.relayed`,
    /// or `.failed`.  The caller doesn't need to know whether the
    /// path went over LAN or CloudKit; it only cares about the
    /// user-visible result.
    public func submitWithRelay(
        url: URL,
        senderDevice: String,
        cloudKitRelayEnabled: Bool
    ) async -> SubmitResult {
        do {
            try await self.queue(url: url)
            return .lan
        } catch {
            let decision = RelayPolicy.decide(
                lanOutcome: Self.relayOutcome(for: error),
                cloudKitRelayEnabled: cloudKitRelayEnabled)

            switch decision {
            case .done:
                // Unreachable: relayOutcome only returns .success
                // when error == nil, and we're inside catch.
                return .lan
            case .surfaceError(let msg):
                return .failed(msg)
            case .fallbackToCloudKit:
                #if canImport(CloudKit)
                do {
                    let submitter = CloudKitRelaySubmitter()
                    let recordID = try await submitter.submit(
                        url: url,
                        senderDevice: senderDevice,
                        targetMacUUID: mac.uuid)
                    return .relayed(recordID: recordID)
                } catch CloudKitRelaySubmitter.SubmitError.noICloudAccount {
                    return .failed("No iCloud account on this device. Sign in to iCloud in Settings to use over-cellular relay.")
                } catch CloudKitRelaySubmitter.SubmitError.quotaExceeded {
                    return .failed("Your iCloud storage is full. Free up space or upgrade in Settings → iCloud.")
                } catch {
                    return .failed("CloudKit relay failed: \(error.localizedDescription)")
                }
                #else
                return .failed("CloudKit relay isn't available on this platform.")
                #endif
            }
        }
    }

    public enum SubmitResult: Equatable {
        case lan
        case relayed(recordID: String)
        case failed(String)
    }
}

/// Mirrors the subset of `WebDashboard.State.Job` that the iOS UI
/// renders.  Decoded with permissive defaulting so server-side schema
/// drift (a new field) doesn't break the iOS app.
public struct JobSummary: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let url: String
    public let filename: String?
    public let phase: String?       // "running", "queued", "paused", "finished", "failed"
    public let downloaded: Int64?
    public let total: Int64?
    public let throughputBps: Double?

    public var displayName: String { filename ?? url }
    public var fractionComplete: Double? {
        guard let total, total > 0, let downloaded else { return nil }
        return Double(downloaded) / Double(total)
    }
}
