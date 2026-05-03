import Foundation
import CryptoKit

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// SwarmParticipant is an HTTP client speaking the swarm protocol
// declared in FleetChunkSwarm.swift.  It fetches manifests + chunk
// bytes via standard URLSession requests, verifies every chunk
// against the seeder's published SHA-256 BEFORE writing to disk,
// and delivers verified bytes to the caller's `ChunkSink` closure.
// No code execution: chunks are bytes, the verifier is deterministic
// hashing, and a chunk that doesn't match its digest is discarded
// + retried (or surfaces as an error, never silently kept).
// =====================================================================

/// v1.9.3: peer-side state machine for joining someone else's swarm.
///
/// The flow:
///
///   1. Caller hands the participant an `Announce` (typically
///      received via Bonjour TXT-record broadcast or a direct
///      announce POST in a v1.9.x extension).
///   2. Participant `joins(announce:)` — fetches the manifest from
///      `announce.manifestURL` via GET.  Decodes through
///      `FleetChunkSwarm.Manifest` to validate.
///   3. Caller picks a subset of chunks to fetch (`pickChunks` is the
///      decision; SwarmParticipant doesn't decide, the caller does
///      — typically the integration layer matches the participant's
///      "what do I still need?" against the seeder's "what does the
///      seeder already have?").
///   4. Participant POSTs `ContributionOffer` so the seeder skips
///      those chunks in its own scheduling.
///   5. Participant fetches each chunk via GET, computes SHA-256,
///      compares to the manifest's `ChunkRef.digest`, hands the
///      bytes to `chunkSink` on success.
///   6. Participant POSTs `leave` on completion or error.
///
/// **Cancellation.**  The orchestrating method `pull(...)` runs in
/// a Task; cancelling it sends a leave + returns.
///
/// **Error handling.**  Per-chunk errors aren't fatal — the
/// participant collects them and continues with the next chunk.
/// A summary `Result` lets the caller decide what to do (typically:
/// retry the failed chunks against another seeder, or fall back to
/// WAN).
///
/// **Sandbox.**  No new entitlements.  HTTP client uses
/// `URLSession.shared` over the LAN.  The fleet token gates every
/// request.
final class SwarmParticipant: @unchecked Sendable {

    /// Closure called for each successfully-verified chunk.  The
    /// caller writes the bytes to the in-progress download file (or
    /// wherever its application logic dictates).  Returns true to
    /// continue, false to stop (orchestrator sends a leave).
    typealias ChunkSink = @Sendable (
        _ chunkIndex: Int,
        _ chunk: FleetChunkSwarm.ChunkRef,
        _ bytes: Data
    ) -> Bool

    /// Closure that picks which chunks to claim from the seeder.
    /// Receives the manifest + the seeder's already-completed set.
    /// Defaults to "all chunks the seeder has and we haven't already
    /// pulled."  Caller can substitute with smarter logic (e.g. pull
    /// chunks far from the seeder's WAN-fetch frontier first).
    typealias ChunkPicker = @Sendable (
        _ manifest: FleetChunkSwarm.Manifest,
        _ alreadyHave: Set<Int>
    ) -> [Int]

    /// Endpoint base — derived from the announce's `manifestURL`
    /// (we use its scheme + host + port).  The participant builds
    /// other paths off this.
    let endpointBase: URL

    /// Token authenticating every swarm request.  Sourced from the
    /// announce body (peers pair via QR-shared fleet token outside
    /// this protocol — same trust model as the rest of fleet).
    let token: String

    /// Our identifier in the swarm.  Random per-session; ephemeral.
    let peerToken: String

    /// HTTP client used for all requests.  `URLSession.shared` with
    /// a tight per-request timeout (10s for control RPCs, 60s for
    /// chunk fetches).
    private let session: URLSession

    init(
        manifestURL: URL,
        token: String,
        peerToken: String = "peer-\(UUID().uuidString.prefix(8))",
        session: URLSession = .shared
    ) {
        // Strip the manifest path component to get the base.
        var components = URLComponents(url: manifestURL, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        self.endpointBase = components?.url ?? manifestURL
        self.token = token
        self.peerToken = String(peerToken)
        self.session = session
    }

    // MARK: - Top-level flow

    /// Join the swarm, claim chunks per `picker`, fetch + verify
    /// each, deliver to `sink`, leave when done.  Returns a
    /// `Summary` of what happened.
    func pull(
        jobID: UUID,
        alreadyHave: Set<Int> = [],
        picker: ChunkPicker? = nil,
        sink: @escaping ChunkSink
    ) async -> Summary {
        let picker = picker ?? SwarmParticipant.defaultPicker
        var summary = Summary()

        // 1. Fetch the manifest.
        let manifest: FleetChunkSwarm.Manifest
        do {
            manifest = try await fetchManifest(jobID: jobID)
        } catch {
            summary.fatalError = "manifest fetch: \(error.localizedDescription)"
            return summary
        }
        summary.manifest = manifest

        // 2. Pick chunks.
        let claimed = picker(manifest, alreadyHave)
        if claimed.isEmpty {
            summary.fatalError = "Nothing to claim — seeder has no chunks we need."
            return summary
        }

        // 3. Send contribution offer.
        do {
            try await sendContribution(jobID: jobID, chunks: claimed)
        } catch {
            summary.fatalError = "contribute: \(error.localizedDescription)"
            return summary
        }

        // 4. Fetch + verify + deliver each chunk.
        defer {
            // Best-effort leave.  Never fail the summary on a leave error.
            Task.detached { [weak self] in
                _ = try? await self?.sendLeave(jobID: jobID)
            }
        }

        for index in claimed {
            if Task.isCancelled {
                summary.cancelled = true
                break
            }
            // Find the chunk ref.
            guard let ref = manifest.chunks.first(where: { $0.index == index }) else {
                summary.errors.append((index: index, message: "Chunk \(index) not in manifest."))
                continue
            }
            // Fetch.
            do {
                let bytes = try await fetchChunk(jobID: jobID, chunk: ref)
                // Verify against the manifest digest.
                if !verify(bytes: bytes, expectedDigest: ref.digest) {
                    summary.errors.append((index: index, message: "Digest mismatch for chunk \(index)."))
                    continue
                }
                // Deliver.
                let keepGoing = sink(index, ref, bytes)
                summary.delivered.append(index)
                if !keepGoing {
                    break
                }
            } catch {
                summary.errors.append((index: index, message: "fetch: \(error.localizedDescription)"))
            }
        }

        return summary
    }

    /// Default picker: every chunk the seeder has + we don't.
    static let defaultPicker: ChunkPicker = { manifest, alreadyHave in
        manifest.seederCompleted.subtracting(alreadyHave).sorted()
    }

    // MARK: - Summary type

    struct Summary: Sendable {
        var manifest: FleetChunkSwarm.Manifest?
        /// Chunk indices successfully fetched + verified + delivered.
        var delivered: [Int] = []
        /// Per-chunk errors that didn't abort the pull.
        var errors: [(index: Int, message: String)] = []
        /// Set when the pull was cancelled mid-flight.
        var cancelled: Bool = false
        /// Set on a fatal error before any chunk fetched (manifest
        /// failure, no chunks to claim, contribution rejected).
        var fatalError: String?
    }

    // MARK: - Wire helpers

    func fetchManifest(jobID: UUID) async throws -> FleetChunkSwarm.Manifest {
        let url = swarmURL(suffix: "\(jobID)/manifest")
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        try assertOK(response, body: data, what: "manifest")
        return try JSONDecoder().decode(FleetChunkSwarm.Manifest.self, from: data)
    }

    func sendContribution(jobID: UUID, chunks: [Int]) async throws {
        let url = swarmURL(suffix: "\(jobID)/contribute")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let offer = FleetChunkSwarm.ContributionOffer(
            protocolVersion: FleetChunkSwarm.protocolVersion,
            jobID: jobID,
            peerToken: peerToken,
            chunks: chunks
        )
        request.httpBody = try JSONEncoder().encode(offer)
        let (data, response) = try await session.data(for: request)
        try assertOK(response, body: data, what: "contribute")
    }

    func sendLeave(jobID: UUID) async throws {
        let url = swarmURL(suffix: "\(jobID)/leave")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable { let peerToken: String }
        request.httpBody = try JSONEncoder().encode(Body(peerToken: peerToken))
        let (data, response) = try await session.data(for: request)
        try assertOK(response, body: data, what: "leave")
    }

    func fetchChunk(jobID: UUID, chunk: FleetChunkSwarm.ChunkRef) async throws -> Data {
        let url = swarmURL(suffix: "\(jobID)/chunks/\(chunk.index)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (data, response) = try await session.data(for: request)
        try assertOK(response, body: data, what: "chunk \(chunk.index)")
        return data
    }

    /// SHA-256 verification against the manifest's published digest.
    /// Pure — testable without any wire calls.
    static func verify(bytes: Data, expectedDigest: String) -> Bool {
        let actual = SHA256.hash(data: bytes)
            .map { String(format: "%02x", $0) }
            .joined()
        return actual.lowercased() == expectedDigest.lowercased()
    }

    /// Instance wrapper so `pull(...)` doesn't have to mention the type.
    func verify(bytes: Data, expectedDigest: String) -> Bool {
        Self.verify(bytes: bytes, expectedDigest: expectedDigest)
    }

    private func swarmURL(suffix: String) -> URL {
        var components = URLComponents(
            url: endpointBase, resolvingAgainstBaseURL: false
        ) ?? URLComponents()
        components.path = "/splynek/v1/swarm/\(suffix)"
        components.queryItems = [URLQueryItem(name: "t", value: token)]
        return components.url ?? endpointBase
    }

    private func assertOK(
        _ response: URLResponse, body: Data, what: String
    ) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetError(message: "non-HTTP response from \(what)")
        }
        guard (200..<300).contains(http.statusCode) else {
            let preview = String(data: body, encoding: .utf8)?.prefix(120) ?? ""
            throw NetError(message: "\(what) returned \(http.statusCode): \(preview)")
        }
    }

    struct NetError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
