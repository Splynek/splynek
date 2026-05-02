import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// FleetChunkSwarm is a wire-protocol description for LAN-only
// peer-to-peer chunk sharing.  The peers exchange BYTES (chunks of
// files the user is already downloading) and METADATA (chunk size,
// SHA-256, byte range).  Peers do NOT exchange code, scripts,
// closures, or executable artifacts.  The receiving peer verifies
// every chunk against the publisher's SHA-256 before writing to
// disk; chunks that don't verify are discarded.
//
// LAN-only enforcement: the existing FleetCoordinator already binds
// to RFC1918 / link-local interfaces and rejects connections from
// public addresses.  v1.9 reuses that boundary — no new exposure.
// =====================================================================

/// v1.9: wire types for the in-flight chunk swarm protocol.
///
/// **The story.**  Two Macs in the same household are downloading
/// the same 12 GB game update.  Without Splynek, both Macs pull from
/// the internet — they pay for it twice, the home ISP serves the
/// bytes twice, the publisher serves the bytes twice.  With Splynek
/// Fleet 2.0, the second Mac discovers the first one is already
/// fetching the same content (matched by the digest), joins the
/// swarm, and from that point on:
///
///   - Either Mac can fetch a chunk from the OTHER Mac's local
///     disk via the LAN at gigabit (faster than any home ISP)
///   - The Macs split the *remaining* internet pulls so neither
///     downloads the same byte twice
///   - The publisher serves the bytes once, the household pulls
///     them once across the WAN
///
/// **Trust boundary.**  The protocol is intentionally LAN-only.  The
/// existing fleet token — an HMAC-shared secret the user pairs once
/// via QR code from Settings → Web Dashboard → "Show QR" — gates
/// every swarm RPC.  Without the token, a peer is read-only on the
/// existing fleet REST API; we don't extend that to the swarm.
///
/// **Protocol versioning.**  `protocolVersion` is sent in every
/// announce so a v1.9 peer can refuse to talk to a v1.10 peer (or
/// vice versa) cleanly.  Schema changes bump the version; peers
/// ignore swarm announces for protocol versions they don't speak.
///
/// **Public-repo scope:** this file declares the wire TYPES + the
/// invariants.  The seeder + participant logic ships in v1.9
/// implementation work.
enum FleetChunkSwarm {

    /// Bumped on every schema change.  Peers refuse to swarm with
    /// strangers running a different version.
    static let protocolVersion: UInt32 = 1

    /// One chunk of an in-flight download.  Identical shape to the
    /// existing `SidecarState.completed` chunk identification, except
    /// we expose the SHA-256 here so peers can verify what they
    /// receive without trusting the seeder.
    struct ChunkRef: Codable, Hashable, Sendable {
        /// Index into the seeder's chunk list.  Stable for the
        /// lifetime of the job (chunk size doesn't change mid-flight).
        let index: Int
        /// Byte offset of the chunk's first byte.
        let offset: Int64
        /// Length in bytes.
        let length: Int64
        /// SHA-256 of the chunk's bytes, hex-encoded.  When a peer
        /// receives a chunk it computes the digest and rejects on
        /// mismatch.
        let digest: String
    }

    /// `POST /fleet/swarm/announce` body.  Sent by a seeder when it
    /// starts a download, broadcasted via Bonjour to peers.
    struct Announce: Codable, Hashable, Sendable {
        let protocolVersion: UInt32
        let jobID: UUID
        /// SHA-256 of the COMPLETED file (the publisher's checksum).
        /// Lets peers join an existing swarm if they're downloading
        /// the same content — content-addressed swarming.
        let contentDigest: String
        /// Total expected bytes.
        let totalBytes: Int64
        /// Chunk-list manifest URL — peers fetch it to know which
        /// chunks exist.  Served by the seeder's existing fleet
        /// REST endpoint.
        let manifestURL: URL
        /// Token-authenticated; opaque to non-paired peers.  Same
        /// HMAC shape as the existing fleet token.
        let token: String
    }

    /// `GET /fleet/swarm/{job}/manifest` response.
    struct Manifest: Codable, Hashable, Sendable {
        let protocolVersion: UInt32
        let jobID: UUID
        let chunkSize: Int64
        let chunks: [ChunkRef]
        /// Which chunks the seeder has already completed.  Peers
        /// pick the next chunk to fetch by intersecting:
        ///   - "what does the seeder already have?" (this set)
        ///   - "what do I still need?" (peer's own state)
        ///   - "what would help the swarm finish?"
        let seederCompleted: Set<Int>
    }

    /// `POST /fleet/swarm/{job}/contribute` body.  Peer offers to
    /// fetch a list of chunks on its own ISP path so the seeder
    /// doesn't have to.  Seeder records the contribution and skips
    /// those indices in its own download schedule.
    struct ContributionOffer: Codable, Hashable, Sendable {
        let protocolVersion: UInt32
        let jobID: UUID
        let peerToken: String   // HMAC-paired peer ID
        let chunks: [Int]       // chunk indices the peer will fetch
    }

    /// Per-job swarm state.  The seeder maintains one of these per
    /// active in-flight download; participants maintain a copy of
    /// their slice.  Not persisted across launches — swarm state
    /// rebuilds on each app start when peers re-announce.
    struct State: Sendable {
        let jobID: UUID
        let manifest: Manifest
        /// Map of peer-token → chunks that peer has committed to fetching.
        /// Used by the seeder to schedule its own remaining work
        /// without duplicating effort.
        var contributions: [String: Set<Int>]
        /// Map of peer-token → chunks that peer has confirmed it
        /// already HAS in its local store (so we can fetch from them
        /// rather than the WAN).
        var peerHoldings: [String: Set<Int>]

        /// Pick the next chunk the seeder should fetch — preferring
        /// chunks that no peer has offered to contribute and no peer
        /// is already holding.  Pure: testable without I/O.
        func nextSeederWorkItem() -> Int? {
            let allOffered = contributions.values.reduce(into: Set<Int>()) { $0.formUnion($1) }
            let allHeld = peerHoldings.values.reduce(into: Set<Int>()) { $0.formUnion($1) }
            for chunk in manifest.chunks where !manifest.seederCompleted.contains(chunk.index) {
                if allOffered.contains(chunk.index) { continue }
                if allHeld.contains(chunk.index) { continue }
                return chunk.index
            }
            // Fallback: nothing exclusive remains — pick any incomplete chunk.
            for chunk in manifest.chunks where !manifest.seederCompleted.contains(chunk.index) {
                return chunk.index
            }
            return nil
        }
    }
}
