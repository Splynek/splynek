import Foundation
import Network

// =====================================================================
// Bet S2 — Unbreakable Resume (component 2 of 3)
// =====================================================================
//
// `PathMonitorObserver` wraps a long-lived `NWPathMonitor` and
// translates its raw `pathUpdateHandler` callbacks into a typed,
// equatable event stream the rest of Splynek can subscribe to.
//
// The motivation: when Wi-Fi drops, Ethernet flips, or a VPN tunnel
// disconnects mid-download, every in-flight HTTP connection silently
// fails its read.  The download engine has no way to tell whether the
// failure is a transient packet loss (retry the chunk) or a structural
// path change (cancel, re-resolve, restart from the sidecar over the
// new interface).  This observer makes the structural changes
// observable so the engine can react deterministically.
//
// Components 1 (HTTP Range resume) and 3 (curated mirror failover)
// are tracked separately — see `STRATEGY-2026.md`.
//
// What this file doesn't do: subscribe the engine.  That integration
// is intentionally a follow-up commit so the observer's behaviour can
// be reviewed in isolation.
// =====================================================================

/// Typed event emitted whenever the OS-reported network path changes
/// in a way that's meaningful to a download engine.  The interface
/// name set lets downstream consumers detect "Wi-Fi → Ethernet" flips
/// (different members in the set) versus brief flaps (same members).
public enum PathEvent: Equatable, Sendable {

    /// At least one interface is `.satisfied` and routing is possible.
    /// `interfaceNames` are BSD names (`en0`, `en1`, `pdp_ip0`, …) —
    /// matched on by `InterfaceDiscovery` for lane selection.
    case online(interfaceNames: Set<String>)

    /// Path is `.unsatisfied` or `.requiresConnection`.  Treat as
    /// "no internet right now" — pause in-flight requests, keep the
    /// download's sidecar resumable, wait for the next `.online`.
    case offline

    /// Did this transition warrant the engine restarting in-flight
    /// connections?  Returns false for `nil` (first observation —
    /// the engine hasn't emitted yet) and for repeated events with
    /// identical state (no-op flap).  Returns true when going
    /// online ↔ offline OR when the online interface set changes.
    ///
    /// The engine should treat a `true` here as: cancel current
    /// `LaneConnection`s, re-probe, restart from the sidecar.  The
    /// HTTP Range resume path already exists; this just hands the
    /// engine the trigger.
    public static func warrantsRestart(from previous: PathEvent?, to next: PathEvent) -> Bool {
        guard let previous else { return false }
        if previous == next { return false }
        return true
    }
}

/// Namespace for the long-lived NWPathMonitor wrapper + the pure
/// translation function the tests exercise.  Not a class because the
/// only state worth holding is the current event, which downstream
/// consumers (the engine, the UI) prefer to track themselves on
/// whatever actor they live on.
public enum PathMonitorObserver {

    /// Pure translation: `(NWPath.Status, available interfaces) →
    /// PathEvent`.  Factored out so tests don't need to construct an
    /// `NWPath` (which has no public initialiser).  Production routes
    /// through the `NWPath`-overload below.
    public static func translate(
        status: NWPath.Status,
        interfaceNames: Set<String>
    ) -> PathEvent {
        switch status {
        case .satisfied:
            // `.satisfied` with an empty interface set shouldn't happen
            // in practice — NWPathMonitor only reports satisfied when
            // there's at least one usable interface.  Treat the
            // degenerate case as offline so a downstream restart
            // doesn't fire against an empty lane list.
            if interfaceNames.isEmpty { return .offline }
            return .online(interfaceNames: interfaceNames)
        case .unsatisfied, .requiresConnection:
            return .offline
        @unknown default:
            return .offline
        }
    }

    /// NWPath-overload used by `liveStream`.  Pulls the BSD names off
    /// `availableInterfaces` so the test-friendly translate can do
    /// the case analysis without depending on Network framework
    /// types being constructable.
    static func translate(path: NWPath) -> PathEvent {
        translate(
            status: path.status,
            interfaceNames: Set(path.availableInterfaces.map { $0.name })
        )
    }

    /// Vends an `AsyncStream` of `PathEvent`s sourced from a
    /// long-lived `NWPathMonitor`.  The monitor is owned by the
    /// stream — it's started when the consumer begins iterating and
    /// cancelled automatically on stream termination (consumer drops,
    /// task cancel, finishes).  Safe to call multiple times; each
    /// caller gets its own monitor instance (NWPathMonitor is cheap).
    ///
    /// Events are duplicates-suppressed: if NWPathMonitor reports the
    /// same status + interface set twice in a row, only the first
    /// becomes a yielded event.  This shields downstream from the
    /// occasional handler "noise" the framework emits during boot.
    public static func liveStream() -> AsyncStream<PathEvent> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "splynek.path-monitor")

            // Last yielded event — used to suppress duplicates.  Held
            // in a class so the closure can mutate it without
            // capturing semantics-fighting.
            let lastYielded = LastYielded()

            monitor.pathUpdateHandler = { path in
                let event = translate(path: path)
                if lastYielded.value == event { return }
                lastYielded.value = event
                continuation.yield(event)
            }
            continuation.onTermination = { _ in
                monitor.cancel()
            }
            monitor.start(queue: queue)
        }
    }

    /// Mutable holder for the last-yielded event.  Used inside
    /// `liveStream`'s closure for duplicate suppression.  A `class`
    /// because the path-update handler closure is `@Sendable` and we
    /// need by-reference mutation across handler firings.
    private final class LastYielded: @unchecked Sendable {
        var value: PathEvent?
    }
}
