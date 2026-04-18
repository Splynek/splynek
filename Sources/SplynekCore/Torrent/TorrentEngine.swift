import Foundation
import Network
import CryptoKit

@MainActor
final class TorrentProgress: ObservableObject {
    @Published var name: String = ""
    @Published var totalBytes: Int64 = 0
    @Published var downloaded: Int64 = 0
    @Published var pieces: Int = 0
    @Published var piecesDone: Int = 0
    @Published var peers: Int = 0
    @Published var activePeers: Int = 0
    @Published var errorMessage: String? = nil
    @Published var finished: Bool = false
    @Published var phase: String = ""   // human-readable status
    @Published var endgame: Bool = false
    @Published var seeding: SeedingProgress?

    var fraction: Double { totalBytes > 0 ? Double(downloaded) / Double(totalBytes) : 0 }
}

/// Multi-peer BitTorrent download coordinator.
///
/// Strategy:
///   - Announce to every tracker we're given (HTTP and UDP, on the chosen interface where supported).
///   - Optionally run DHT to scoop up additional peers.
///   - Spawn up to `maxConcurrentPeers` PeerWire sessions; each peer pulls
///     pieces using rarest-first from the shared piece picker.
///   - Each completed piece is SHA-1 verified then written via TorrentWriter
///     (handles multi-file splicing).
final class TorrentEngine {

    static let maxConcurrentPeers = 8

    var info: TorrentInfo           // mutable so we can swap after BEP 9 metadata arrives
    let rootDirectory: URL
    let interface: DiscoveredInterface
    let progress: TorrentProgress
    /// Extra magnet trackers not already in info.announceURLs.
    var extraTrackers: [URL]
    /// Optional bootstrap magnet — if set, the engine will first fetch the
    /// info dict via BEP 9 from whatever peers the trackers yield.
    var magnetInfoHash: Data?
    /// When true, run SeedingService after download completes and keep
    /// re-announcing to trackers until `cancel()` is called.
    var seedAfterCompletion: Bool = false
    /// When true, stand up the SeedingService at the start of the run so
    /// completed pieces are served to other peers while we're still
    /// leeching. Turns Splynek into a real swarm citizen.
    var seedWhileLeeching: Bool = false

    private let cancelFlag = CancelFlag()
    private let ourPeerID: Data
    private let picker: PiecePicker
    private var writer: TorrentWriter?
    private var seedingService: SeedingService?

    init(info: TorrentInfo, rootDirectory: URL,
         interface: DiscoveredInterface, progress: TorrentProgress,
         extraTrackers: [URL] = [], magnetInfoHash: Data? = nil) {
        self.info = info
        self.rootDirectory = rootDirectory
        self.interface = interface
        self.progress = progress
        self.extraTrackers = extraTrackers
        self.magnetInfoHash = magnetInfoHash
        self.picker = PiecePicker(numPieces: info.numPieces)
        // Peer-ID prefix bumped for v0.19 (BEP 52 + fleet orchestration).
        var id = Data("-SP0019-".utf8)
        for _ in 0..<12 { id.append(UInt8.random(in: 0...255)) }
        self.ourPeerID = id
    }

    /// The 20-byte info hash we hand to peers + trackers. For pure-v2
    /// torrents this is the first 20 bytes of the SHA-256 info hash; for
    /// v1 / hybrid swarms it's the classic v1 SHA-1.
    private var handshakeInfoHash: Data {
        if info.metaVersion == .v2, let short = info.infoHashV2Short {
            return short
        }
        return info.infoHash
    }

    func cancel() {
        cancelFlag.cancel()
        seedingService?.stop()
    }

    // MARK: Main run

    func run() async {
        guard let nw = interface.nwInterface else {
            await report("Selected interface has no NWInterface.")
            return
        }
        await MainActor.run {
            progress.name = info.name
            progress.totalBytes = info.totalLength
            progress.pieces = info.numPieces
            progress.phase = "Announcing to trackers…"
        }

        let peers = await gatherPeers(interface: nw)
        if peers.isEmpty {
            await report("No peers from any source (HTTP trackers, UDP trackers, DHT). Swarm may be offline.")
            return
        }

        // If this came from a magnet, fetch the info dict first.
        if magnetInfoHash != nil, info.pieceHashes.isEmpty {
            await MainActor.run { progress.phase = "Fetching metadata (BEP 9)…" }
            guard let fetched = await fetchMetadata(peers: peers, interface: nw) else {
                await report("Could not fetch torrent metadata from any peer. Magnet likely needs DHT/PEX.")
                return
            }
            do {
                let rebuilt = try TorrentFile.fromInfoDict(fetched, trackers: info.announceURLs + extraTrackers)
                self.info = rebuilt
                picker.resize(numPieces: rebuilt.numPieces)
                await MainActor.run {
                    progress.name = rebuilt.name
                    progress.totalBytes = rebuilt.totalLength
                    progress.pieces = rebuilt.numPieces
                }
            } catch {
                await report("Metadata dict parse failed: \(error.localizedDescription)")
                return
            }
        }

        let haveV1 = !info.pieceHashes.isEmpty
        let haveV2 = info.metaVersion != .v1 && !info.pieceLayers.isEmpty
        guard haveV1 || haveV2 || info.metaVersion == .v2 else {
            await report("No piece verification data — cannot proceed.")
            return
        }
        if info.numPieces == 0 {
            await report("No pieces defined — cannot proceed.")
            return
        }

        // Preallocate files
        let writer = TorrentWriter(info: info, rootDirectory: rootDirectory)
        do { try writer.preallocate() } catch {
            await report("File preallocation failed: \(error.localizedDescription)")
            return
        }
        self.writer = writer
        defer { writer.close() }

        // Session-restore scan. Verifies every piece against the
        // bytes already on disk (v0.40+) and feeds verified indices
        // into the picker so we don't re-download them. Skipped for
        // v2 magnets that haven't yet received their piece layers —
        // `PieceVerifier` refuses in that state because the bytes
        // can't be authenticated, and the verifier itself short-
        // circuits if piece-hash data isn't available.
        if haveV1 || haveV2 {
            await MainActor.run { progress.phase = "Verifying existing pieces…" }
            let resumeRoot = self.rootDirectory
            let resume = await withCheckedContinuation { (cont: CheckedContinuation<TorrentResume.Result, Never>) in
                DispatchQueue.global(qos: .userInitiated).async { [cancelFlag, info] in
                    let result = TorrentResume.scan(
                        info: info, rootDirectory: resumeRoot,
                        progressInterval: 32,
                        onProgress: nil,
                        isCancelled: { cancelFlag.isCancelled }
                    )
                    cont.resume(returning: result)
                }
            }
            if !resume.verifiedPieces.isEmpty {
                for idx in resume.verifiedPieces {
                    picker.markDone(idx)
                    seedingService?.markPieceComplete(idx)
                }
                await MainActor.run {
                    progress.piecesDone = resume.verifiedPieces.count
                    progress.downloaded = resume.bytesRecovered
                    progress.phase = "Restored \(resume.verifiedPieces.count)/\(info.numPieces) pieces from disk."
                }
            }
        }

        // If the resume scan already completed the torrent, skip the
        // swarm entirely and jump to the completion branch.
        if picker.allDone() {
            for f in info.files {
                let url = rootDirectory.appendingPathComponent(info.relativePath(for: f))
                Quarantine.mark(url)
            }
            await MainActor.run {
                progress.finished = true
                progress.phase = "Done (fully restored)."
            }
            await MainActor.run { DockBadge.set(nil) }
            Notifier.post(
                title: "Torrent complete",
                body: info.name,
                subtitle: ByteCountFormatter.string(fromByteCount: info.totalLength,
                                                    countStyle: .binary)
            )
            if seedAfterCompletion {
                await startSeeding()
            }
            return
        }

        // Optionally stand up the seeder now so completed pieces are
        // served to other peers as they arrive (partial-seed-while-leech).
        if seedWhileLeeching {
            await startPartialSeeder()
        }

        await MainActor.run { progress.phase = "Connecting to peers…" }
        await runSwarm(peers: peers, interface: nw)

        if picker.allDone() {
            // Mark root(s)
            for f in info.files {
                let url = rootDirectory.appendingPathComponent(info.relativePath(for: f))
                Quarantine.mark(url)
            }
            await MainActor.run {
                progress.finished = true
                progress.phase = "Done."
            }
            await MainActor.run { DockBadge.set(nil) }
            Notifier.post(
                title: "Torrent complete",
                body: info.name,
                subtitle: ByteCountFormatter.string(fromByteCount: info.totalLength,
                                                    countStyle: .binary)
            )
            if seedAfterCompletion {
                if seedingService != nil {
                    // Partial-seed mode already produced a live listener; we
                    // just need to ensure every piece is marked as ours and
                    // announce as a complete seed.
                    for idx in 0..<info.numPieces {
                        seedingService?.markPieceComplete(idx)
                    }
                    await reannounceAsCompleteSeed()
                } else {
                    await startSeeding()
                }
            }
        } else if cancelFlag.isCancelled {
            await report("Cancelled.")
        } else {
            await report("Swarm incomplete: missing \(info.numPieces - picker.doneCount) pieces.")
        }
    }

    // MARK: Seeding

    /// Stand up a SeedingService at the start of the run with an empty
    /// bitfield so pieces we've already verified are served to peers in
    /// flight. Silent if binding fails (just logs a phase message).
    private func startPartialSeeder() async {
        guard let writer else { return }
        let seedProgress = await MainActor.run { () -> SeedingProgress in
            let s = SeedingProgress()
            self.progress.seeding = s
            return s
        }
        let service = SeedingService(
            info: info, storage: writer, ourPeerID: ourPeerID,
            interface: interface.nwInterface, progress: seedProgress,
            initiallyComplete: false
        )
        do { try service.start() } catch {
            await MainActor.run { progress.phase = "Seed listener failed: \(error.localizedDescription)" }
            return
        }
        self.seedingService = service
    }

    /// For partial-seed-while-leech: when the download finally completes,
    /// we already have a listener running. Just re-announce as a full seed
    /// and keep re-announcing every 15 minutes until cancel.
    private func reannounceAsCompleteSeed() async {
        guard let service = seedingService else { return }
        let port = service.boundPort
        guard port > 0 else { return }
        await MainActor.run { progress.phase = "Seeding." }
        await performAnnounces(port: port, event: "completed")
        while !cancelFlag.isCancelled {
            try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
            if cancelFlag.isCancelled { break }
            await performAnnounces(port: port, event: nil)
        }
        service.stop()
        await MainActor.run { progress.phase = "Seeding stopped." }
    }

    private func performAnnounces(port: UInt16, event: String?) async {
        let trackers = info.announceURLs + extraTrackers
        for tracker in trackers {
            switch tracker.scheme?.lowercased() {
            case "http", "https":
                let ann = TrackerClient.AnnounceParams(
                    announceURL: tracker, infoHash: handshakeInfoHash,
                    peerID: ourPeerID, port: port,
                    uploaded: 0, downloaded: info.totalLength, left: 0,
                    event: event
                )
                _ = try? await HTTPTrackerOverNW.announce(ann, interface: interface.nwInterface)
            case "udp":
                let udpEvent: UDPTracker.Event = event == "completed" ? .completed : .none
                let ann = UDPTracker.AnnounceParams(
                    announceURL: tracker, infoHash: handshakeInfoHash,
                    peerID: ourPeerID, port: port,
                    uploaded: 0, downloaded: info.totalLength, left: 0, event: udpEvent
                )
                _ = try? await UDPTracker.announce(ann, interface: interface.nwInterface)
            default: continue
            }
        }
    }

    private func startSeeding() async {
        guard let writer else { return }
        let seedProgress = await MainActor.run { () -> SeedingProgress in
            let s = SeedingProgress()
            self.progress.seeding = s
            self.progress.phase = "Seeding."
            return s
        }
        let service = SeedingService(
            info: info, storage: writer, ourPeerID: ourPeerID,
            interface: interface.nwInterface, progress: seedProgress
        )
        self.seedingService = service
        do { try service.start() } catch {
            await MainActor.run { progress.phase = "Seed listener failed: \(error.localizedDescription)" }
            return
        }
        // Give the listener a beat to bind.
        try? await Task.sleep(nanoseconds: 200_000_000)
        let port = service.boundPort
        guard port > 0 else {
            await MainActor.run { progress.phase = "Seed listener unbound." }
            return
        }

        // Re-announce as a complete seed to every tracker. Prefer our
        // interface-aware HTTP and UDP tracker clients.
        let trackers = info.announceURLs + extraTrackers
        for tracker in trackers {
            switch tracker.scheme?.lowercased() {
            case "http", "https":
                let ann = TrackerClient.AnnounceParams(
                    announceURL: tracker, infoHash: handshakeInfoHash,
                    peerID: ourPeerID, port: port,
                    uploaded: 0, downloaded: info.totalLength, left: 0,
                    event: "completed"
                )
                _ = try? await HTTPTrackerOverNW.announce(ann, interface: interface.nwInterface)
            case "udp":
                let ann = UDPTracker.AnnounceParams(
                    announceURL: tracker, infoHash: handshakeInfoHash,
                    peerID: ourPeerID, port: port,
                    uploaded: 0, downloaded: info.totalLength, left: 0, event: .completed
                )
                _ = try? await UDPTracker.announce(ann, interface: interface.nwInterface)
            default: continue
            }
        }

        // DHT announce_peer so peers without the tracker find us too.
        // `run()` returned earlier if nwInterface was nil, but be defensive
        // rather than trusting the implicit precondition.
        if let nw = interface.nwInterface {
            let dht = DHT(infoHash: handshakeInfoHash, interface: nw)
            _ = try? await dht.getPeers(timeout: 5)      // populate tokens
            await dht.announcePeerToKnownNodes(port: port)
        }

        // Keep the service alive until cancelled. Periodically re-announce
        // to tracker(s) every 15 minutes.
        while !cancelFlag.isCancelled {
            try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
            if cancelFlag.isCancelled { break }
            for tracker in trackers {
                if tracker.scheme?.lowercased().hasPrefix("http") == true {
                    let ann = TrackerClient.AnnounceParams(
                        announceURL: tracker, infoHash: handshakeInfoHash,
                        peerID: ourPeerID, port: port,
                        uploaded: 0, downloaded: info.totalLength, left: 0,
                        event: nil
                    )
                    _ = try? await HTTPTrackerOverNW.announce(ann, interface: interface.nwInterface)
                }
            }
        }
        service.stop()
        await MainActor.run { progress.phase = "Seeding stopped." }
    }

    // MARK: Peer gathering

    private func gatherPeers(interface: NWInterface) async -> [TorrentPeer] {
        var all: Set<TorrentPeer> = []
        let trackers = info.announceURLs + extraTrackers

        // HTTP/HTTPS trackers — use NWConnection so DNS obeys the interface.
        for t in trackers where t.scheme?.lowercased().hasPrefix("http") == true {
            let ann = TrackerClient.AnnounceParams(
                announceURL: t, infoHash: magnetInfoHash ?? handshakeInfoHash,
                peerID: ourPeerID, port: 6881,
                uploaded: 0, downloaded: 0, left: info.totalLength,
                event: "started"
            )
            if let resp = try? await HTTPTrackerOverNW.announce(ann, interface: interface) {
                all.formUnion(resp.peers)
            }
        }
        // UDP trackers
        for t in trackers where t.scheme?.lowercased() == "udp" {
            let ann = UDPTracker.AnnounceParams(
                announceURL: t, infoHash: magnetInfoHash ?? handshakeInfoHash,
                peerID: ourPeerID, port: 6881,
                uploaded: 0, downloaded: 0, left: info.totalLength, event: .started
            )
            if let resp = try? await UDPTracker.announce(ann, interface: interface) {
                all.formUnion(resp.peers)
            }
        }
        // DHT bootstrap — only makes sense when we have an info hash (which
        // is always true at this stage, magnets included).
        await MainActor.run { progress.phase = "Probing DHT…" }
        let dht = DHT(infoHash: magnetInfoHash ?? handshakeInfoHash, interface: interface)
        if let dhtPeers = try? await dht.getPeers(timeout: 10) {
            all.formUnion(dhtPeers)
        }

        let peersList = Array(all)
        let peerCount = peersList.count
        await MainActor.run { progress.peers = peerCount }
        return peersList
    }

    // MARK: BEP 9 metadata bootstrap

    private func fetchMetadata(peers: [TorrentPeer], interface: NWInterface) async -> Data? {
        guard let infoHash = magnetInfoHash else { return nil }
        for peer in peers.shuffled().prefix(20) {
            if cancelFlag.isCancelled { return nil }
            let wire = PeerWire(
                peer: peer, infoHash: infoHash, ourPeerID: ourPeerID,
                interface: interface, cancelFlag: cancelFlag
            )
            defer { wire.close() }
            do {
                try await wire.connectAndHandshake(numPieces: 0)
                if !wire.peerSupportsExtended { continue }
                // Wait a beat for the peer's extended handshake to arrive.
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let bytes = try? await wire.fetchMetadata() {
                    // Verify info hash
                    let got = Data(Insecure.SHA1.hash(data: bytes))
                    if got == infoHash { return bytes }
                }
            } catch {
                continue
            }
        }
        return nil
    }

    // MARK: Swarm

    private func runSwarm(peers: [TorrentPeer], interface: NWInterface) async {
        // `run()` wires writer before calling us, but bail defensively.
        guard let writer = self.writer else { return }
        let coordinator = PeerCoordinator(
            picker: picker,
            writer: writer,
            info: info,
            progress: progress,
            cancelFlag: cancelFlag,
            seedingService: seedingService
        )
        await withTaskGroup(of: Void.self) { group in
            let shuffled = peers.shuffled()
            var iterator = shuffled.makeIterator()
            // Spin up the initial batch
            for _ in 0..<min(Self.maxConcurrentPeers, shuffled.count) {
                if let peer = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await coordinator.work(peer: peer, infoHash: self.handshakeInfoHash,
                                               ourPeerID: self.ourPeerID, interface: interface)
                    }
                }
            }
            // As each peer slot finishes, pull in another until we exhaust or
            // the picker reports completion. Each slot also drains PEX peers
            // the retired session may have learned about.
            while await group.next() != nil {
                if cancelFlag.isCancelled { break }
                if picker.allDone() { break }
                let pexNew = await coordinator.drainPexPeers()
                for p in pexNew { await coordinator.markPeerSeen(p) }
                // Prefer original tracker/DHT peers, fall back to PEX.
                let nextPeer = iterator.next() ?? pexNew.first
                if let peer = nextPeer {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await coordinator.work(peer: peer, infoHash: self.handshakeInfoHash,
                                               ourPeerID: self.ourPeerID, interface: interface)
                    }
                }
            }
        }
    }

    // MARK: Status

    private func report(_ message: String) async {
        await MainActor.run { progress.errorMessage = message }
    }
}

// MARK: - Piece picker (rarest-first)

/// Thread-safe piece picker. Holds availability counts and in-progress flags;
/// vends pieces in ascending availability order, break ties with random.
final class PiecePicker: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var numPieces: Int
    private var done: [Bool]
    private var inFlight: Set<Int> = []
    /// availability[i] = number of connected peers claiming to have piece i.
    private var availability: [Int]
    /// When fewer than this many pieces remain outstanding, allow
    /// multiple peers to race on the same piece. This is BEP 3 "endgame".
    static let endgameThreshold = 4

    init(numPieces: Int) {
        self.numPieces = numPieces
        self.done = Array(repeating: false, count: numPieces)
        self.availability = Array(repeating: 0, count: numPieces)
    }

    func resize(numPieces: Int) {
        lock.lock(); defer { lock.unlock() }
        self.numPieces = numPieces
        self.done = Array(repeating: false, count: numPieces)
        self.availability = Array(repeating: 0, count: numPieces)
        self.inFlight.removeAll()
    }

    /// Update availability from a peer's bitfield when it first connects.
    func observe(bitfield: BitSet) {
        lock.lock(); defer { lock.unlock() }
        for i in 0..<numPieces where bitfield.isSet(i) {
            availability[i] += 1
        }
    }

    /// True iff the number of pieces still to fetch is below the endgame
    /// threshold — in which case `pickFor` will hand out the same piece to
    /// multiple peers.
    var inEndgame: Bool {
        lock.lock(); defer { lock.unlock() }
        let remaining = done.filter { !$0 }.count
        return remaining > 0 && remaining <= Self.endgameThreshold
    }

    /// Pick the rarest piece that a given peer has and that we don't.
    /// Returns nil if there's nothing to do. In endgame mode, ignores
    /// `inFlight` so a piece can be requested from several peers at once.
    func pickFor(bitfield: BitSet) -> Int? {
        lock.lock(); defer { lock.unlock() }
        let remaining = done.filter { !$0 }.count
        let endgame = remaining > 0 && remaining <= Self.endgameThreshold
        var best: (Int, Int)? = nil
        for i in 0..<numPieces
            where !done[i]
               && (endgame || !inFlight.contains(i))
               && bitfield.isSet(i) {
            let avail = availability[i]
            if best == nil || avail < best!.0 || (avail == best!.0 && Bool.random()) {
                best = (avail, i)
            }
        }
        guard let (_, idx) = best else { return nil }
        inFlight.insert(idx)
        return idx
    }

    func markDone(_ idx: Int) {
        lock.lock()
        done[idx] = true
        inFlight.remove(idx)
        lock.unlock()
    }

    func release(_ idx: Int) {
        lock.lock(); inFlight.remove(idx); lock.unlock()
    }

    func allDone() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return done.allSatisfy { $0 }
    }

    var doneCount: Int {
        lock.lock(); defer { lock.unlock() }
        return done.filter { $0 }.count
    }
}

// MARK: - Peer coordinator

actor PeerCoordinator {
    let picker: PiecePicker
    let writer: TorrentWriter
    let info: TorrentInfo
    let progress: TorrentProgress
    let cancelFlag: CancelFlag
    /// Optional seeder that should be notified when a piece verifies — used
    /// for partial-seed-while-leech so already-downloaded pieces get served.
    let seedingService: SeedingService?

    /// Peers learned via BEP 11 PEX that the engine should try on new slots.
    private(set) var pexDiscovered: [TorrentPeer] = []
    private var seenPeerKeys: Set<String> = []

    init(picker: PiecePicker, writer: TorrentWriter,
         info: TorrentInfo, progress: TorrentProgress, cancelFlag: CancelFlag,
         seedingService: SeedingService? = nil) {
        self.picker = picker
        self.writer = writer
        self.info = info
        self.progress = progress
        self.cancelFlag = cancelFlag
        self.seedingService = seedingService
    }

    /// Called (from within a peer's actor-isolated path) when a PEX message
    /// arrives. De-dupes and stashes for `drainPexPeers()` to hand back.
    func addPexPeers(_ peers: [TorrentPeer]) {
        for p in peers {
            let key = "\(p.ip):\(p.port)"
            if seenPeerKeys.insert(key).inserted {
                pexDiscovered.append(p)
            }
        }
    }

    func drainPexPeers() -> [TorrentPeer] {
        let out = pexDiscovered
        pexDiscovered.removeAll()
        return out
    }

    func markPeerSeen(_ p: TorrentPeer) {
        seenPeerKeys.insert("\(p.ip):\(p.port)")
    }

    /// Decide whether a just-received piece is valid, trying v1 SHA-1 and
    /// v2 Merkle verification in whichever order the torrent supports.
    /// For hybrid torrents, both checks must pass. For v2-only torrents
    /// without shipped piece layers (e.g. magnet that only yielded an info
    /// dict), we can't verify — we accept tentatively and hope the swarm's
    /// v1 fallback (hybrid peers) corrects us later.
    fileprivate nonisolated func acceptPiece(
        data: Data, index: Int, info: TorrentInfo
    ) -> Bool {
        // Live-swarm path — stays lenient on v2 magnets without
        // layers (`resumeMode: false`), unlike the resume scanner.
        return PieceVerifier.verify(
            data: data, index: index, info: info, resumeMode: false
        )
    }

    func work(peer: TorrentPeer, infoHash: Data, ourPeerID: Data, interface: NWInterface) async {
        let wire = PeerWire(peer: peer, infoHash: infoHash, ourPeerID: ourPeerID,
                            interface: interface, cancelFlag: cancelFlag)
        // Route PEX announcements from this peer back to the coordinator.
        wire.onPexPeers = { [weak self] peers in
            guard let self else { return }
            Task { await self.addPexPeers(peers) }
        }
        await MainActor.run { self.progress.activePeers += 1 }
        defer {
            wire.close()
            Task { @MainActor in self.progress.activePeers = max(0, self.progress.activePeers - 1) }
        }
        do {
            try await wire.connectAndHandshake(numPieces: info.numPieces)
            try await wire.waitForUnchoke()
            if let bf = wire.peerHas { picker.observe(bitfield: bf) }

            while !cancelFlag.isCancelled, !picker.allDone() {
                guard let bf = wire.peerHas else { break }
                guard let idx = picker.pickFor(bitfield: bf) else { break }
                let range = TorrentFile.pieceByteRange(info: info, index: idx)
                let pieceLen = Int64(range.count)
                do {
                    let data = try await wire.downloadPiece(index: idx, pieceLength: pieceLen)
                    if acceptPiece(data: data, index: idx, info: info) {
                        try writer.writeAt(virtualOffset: range.lowerBound, data: data)
                        picker.markDone(idx)
                        seedingService?.markPieceComplete(idx)
                        let got = Int64(data.count)
                        let inEndgame = picker.inEndgame
                        await MainActor.run {
                            self.progress.downloaded += got
                            self.progress.piecesDone += 1
                            self.progress.endgame = inEndgame
                            DockBadge.showProgress(self.progress.fraction)
                        }
                    } else {
                        // Bad piece — give it back and move on from this peer.
                        picker.release(idx)
                        return
                    }
                } catch {
                    picker.release(idx)
                    return
                }
            }
        } catch {
            return
        }
    }
}
