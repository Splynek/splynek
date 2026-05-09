import Foundation
import CryptoKit

/// **Trust Watcher** — daily-diff engine for app policies + privacy
/// labels.  Marquee Pro feature per `STRATEGY-2026-PRO-PLUS-IPHONE.md`.
///
/// ## What it does
///
/// For each app in the watch catalog, periodically fetch the public
/// Privacy Policy URL, ToS URL, and (when available) the App Store
/// privacy-label snapshot.  Hash the *normalised* body content.
/// Compare to the last recorded baseline.  Emit an alert when the
/// hash changes — meaning the vendor altered the document materially.
///
/// ## Why this is defensible Pro value
///
/// Apple Intelligence won't audit ToS changes for you.  ChatGPT
/// can summarise a single ToS but doesn't track changes over time.
/// Splynek already has the catalog of installed apps + the catalog
/// of policy URLs — the Trust Watcher is the only feature that
/// closes the loop into "you'll know when something changed."
///
/// ## Privacy posture
///
/// - Every URL fetched is **already public** (privacy policies are
///   published to be read).  We make ordinary HTTPS GETs with no
///   user identifiers, no cookies, no analytics.
/// - User-Agent is the standard `SplynekVersion.current` Splynek UA.
/// - Hashes are computed locally; never transmitted off-device
///   except (in Sprint 1) to the user's *own* private CloudKit
///   database to push the alert to their iPhone.
/// - The watch catalog (`trust-watch-catalog.json`) ships in the
///   bundle; users don't subscribe to a remote feed.
///
/// ## MAS-2.5.2 posture
///
/// No LLM is involved in detecting changes.  Hash equality is a
/// pure deterministic comparison.  Aligns with the existing
/// MAS-2.5.2 invariant boundary already established for Concierge.
///
/// ## Pipeline
///
/// 1. `TrustWatchCatalog.entries` — what to watch (per-app URLs).
/// 2. `TrustWatchService.runOnce(...)` — fetches each entry,
///    normalises body, hashes, diffs vs. baseline.
/// 3. `TrustWatchAlertStore` — persists baselines + emitted alerts
///    to `~/Library/Application Support/Splynek/trust-watcher.json`.
/// 4. UI surfaces the alert log in `TrustView` (top section,
///    above scan results when alerts > 0).
/// 5. CloudKit publisher (`TrustWatchCloudKitNotifier`) writes the
///    alert to the user's private database; the iPhone Companion's
///    push subscription fires a notification.
///
/// 2026-05-09: created as part of Sprint 1 of the
/// PRO-PLUS-IPHONE strategy.  See
/// `STRATEGY-2026-PRO-PLUS-IPHONE.md` § "Aposta A".

// MARK: - Watched URL kinds

/// What kind of policy document is at a given URL.  Not severity —
/// this is just the type of source so the UI can label "Privacy
/// Policy changed" vs. "Terms of Service changed" precisely.
public enum TrustWatchKind: String, Codable, CaseIterable, Sendable {
    /// The vendor's published privacy policy.
    case privacyPolicy
    /// The vendor's terms of service / EULA.
    case termsOfService
    /// Apple's App Store privacy-label snapshot (when scrapeable
    /// — for now this is `.appStorePrivacyLabel` but the Sprint 1
    /// catalog only seeds `privacyPolicy` + `termsOfService`).
    case appStorePrivacyLabel

    public var label: String {
        switch self {
        case .privacyPolicy:        return "Privacy Policy"
        case .termsOfService:       return "Terms of Service"
        case .appStorePrivacyLabel: return "Privacy label"
        }
    }
}

// MARK: - A single watched URL

/// One URL the Trust Watcher tracks for a single app.  An app can
/// have multiple watched URLs (e.g. one for Privacy Policy, one for
/// ToS, one for the App Store label scrape).
public struct TrustWatchTarget: Codable, Hashable, Sendable {
    /// The app this target belongs to (matches Sovereignty/Trust
    /// catalog `bundleID`).
    public let bundleID: String
    /// The kind of policy at this URL.
    public let kind: TrustWatchKind
    /// The URL itself.  Validated to be `https` at catalog-load time.
    public let url: URL
    /// Friendly app name shown in alerts ("Spotify", "Adobe Photoshop").
    public let displayName: String

    public init(bundleID: String, kind: TrustWatchKind, url: URL, displayName: String) {
        self.bundleID = bundleID
        self.kind = kind
        self.url = url
        self.displayName = displayName
    }
}

// MARK: - Snapshot (a fingerprint at a point in time)

/// One observation: "as of `observedAt`, the body of `target.url`
/// hashed to `bodyHash`".  The catalog accumulates one snapshot
/// per target; the next run compares the freshly-fetched hash to
/// the prior snapshot's hash.
public struct TrustWatchSnapshot: Codable, Hashable, Sendable {
    public let target: TrustWatchTarget
    /// SHA-256 hex of the *normalised* body content.  Normalisation
    /// is whitespace collapsing + script/style removal — see
    /// `TrustWatcher.normalize(_:)`.
    public let bodyHash: String
    /// Body length post-normalisation (bytes).  Stored so the UI
    /// can show "+12 KB", "-5%" deltas without re-fetching.
    public let bodyLength: Int
    /// ISO-8601 timestamp.  String form (not Date) to keep the
    /// JSON file human-diffable.
    public let observedAt: String
    /// HTTP status of the fetch.  Snapshots from non-200 responses
    /// are kept (so the UI can show "site is down") but **never
    /// trigger an alert** — see `TrustWatcher.diff(...)`.
    public let httpStatus: Int

    public init(target: TrustWatchTarget,
                bodyHash: String,
                bodyLength: Int,
                observedAt: String,
                httpStatus: Int) {
        self.target = target
        self.bodyHash = bodyHash
        self.bodyLength = bodyLength
        self.observedAt = observedAt
        self.httpStatus = httpStatus
    }
}

// MARK: - Alert (emitted on change)

/// Severity hint for an alert.  Heuristic — based on the size of
/// the diff and which kind of document changed.  The user can
/// always click through to see the change themselves; this is
/// just for sorting + colour-coding the UI.
public enum TrustWatchAlertSeverity: String, Codable, Sendable {
    case info       // small changes (< 5% body delta)
    case notice     // medium changes (5-20% body delta)
    case material   // large changes (> 20% body delta)

    public var label: String {
        switch self {
        case .info:     return "Minor change"
        case .notice:   return "Notable change"
        case .material: return "Material change"
        }
    }
}

/// One emitted alert: a target's content changed materially.
public struct TrustWatchAlert: Codable, Identifiable, Hashable, Sendable {
    /// `bundleID + kind + observedAt` — stable across re-renders.
    public let id: String
    public let target: TrustWatchTarget
    public let previousHash: String
    public let newHash: String
    public let previousLength: Int
    public let newLength: Int
    public let observedAt: String
    public let severity: TrustWatchAlertSeverity
    /// Has the user dismissed this from the alert badge?  Persisted
    /// so dismissing on the Mac doesn't re-pop on iPhone.
    public var acknowledged: Bool

    /// Body-length delta as a fraction of the previous length.
    /// Positive = grew; negative = shrank.  Used by the UI's
    /// "+12% / -5%" labels.
    public var lengthDeltaFraction: Double {
        guard previousLength > 0 else { return 0 }
        return Double(newLength - previousLength) / Double(previousLength)
    }

    public init(target: TrustWatchTarget,
                previousHash: String,
                newHash: String,
                previousLength: Int,
                newLength: Int,
                observedAt: String,
                severity: TrustWatchAlertSeverity,
                acknowledged: Bool = false) {
        self.id = "\(target.bundleID)|\(target.kind.rawValue)|\(observedAt)"
        self.target = target
        self.previousHash = previousHash
        self.newHash = newHash
        self.previousLength = previousLength
        self.newLength = newLength
        self.observedAt = observedAt
        self.severity = severity
        self.acknowledged = acknowledged
    }
}

// MARK: - Pure logic (no I/O)

/// Pure functions used by both `TrustWatchService` and the test
/// suite.  Keeps the I/O-free logic auditable + 100% testable.
public enum TrustWatcher {

    // MARK: Body normalisation

    /// Normalise raw HTML/text body content for stable hashing.
    /// Removes runs of whitespace + `<script>` and `<style>` blocks
    /// (which often contain timestamps, A/B test IDs, CDN session
    /// tokens — pure noise for our purposes).  Returns lowercase
    /// ASCII text only.
    ///
    /// Why not strip all HTML?  Because policy *structure* matters
    /// — a vendor reordering sections of their policy is meaningful
    /// even if the words don't change.  Stripping `<script>` +
    /// `<style>` removes noise without stripping signal.
    public static func normalize(_ body: String) -> String {
        var s = body
        // Strip <script>...</script> + <style>...</style> blocks.
        s = stripBlock(in: s, tag: "script")
        s = stripBlock(in: s, tag: "style")
        // Lowercase + collapse all whitespace runs to single space.
        s = s.lowercased()
        let scalars = s.unicodeScalars
        var out = String.UnicodeScalarView()
        out.reserveCapacity(scalars.count)
        var prevWasSpace = false
        for sc in scalars {
            // Treat anything in CharacterSet.whitespacesAndNewlines
            // OR control chars OR tabs as whitespace.
            let isWS = CharacterSet.whitespacesAndNewlines.contains(sc)
                || sc.value < 0x20
            if isWS {
                if !prevWasSpace {
                    out.append(" ")
                    prevWasSpace = true
                }
            } else {
                out.append(sc)
                prevWasSpace = false
            }
        }
        return String(out).trimmingCharacters(in: .whitespaces)
    }

    /// Remove every `<TAG>...</TAG>` block (case-insensitive) from
    /// the input string.  Used by `normalize(_:)`.
    private static func stripBlock(in input: String, tag: String) -> String {
        let openPattern = "<\(tag)"
        let closePattern = "</\(tag)>"
        var s = input
        var done = false
        while !done {
            guard let openRange = s.range(of: openPattern,
                                          options: .caseInsensitive) else {
                done = true; break
            }
            // Find the closing > of the open tag (i.e. <script ...>).
            guard let openTagEnd = s[openRange.upperBound...].firstIndex(of: ">") else {
                done = true; break
            }
            // Find the corresponding </tag>.
            guard let closeRange = s.range(of: closePattern,
                                           options: .caseInsensitive,
                                           range: openTagEnd..<s.endIndex)
            else {
                done = true; break
            }
            s.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
        }
        return s
    }

    /// SHA-256 hex of UTF-8 bytes.
    public static func sha256Hex(_ s: String) -> String {
        let data = Data(s.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Diff (snapshot vs. snapshot)

    /// Compare a freshly-observed snapshot against the prior
    /// baseline for the same target.  Returns `nil` when no alert
    /// should fire (no change, or fetch failed).
    public static func diff(previous: TrustWatchSnapshot,
                            current: TrustWatchSnapshot) -> TrustWatchAlert? {
        // Never emit alerts for non-200 fetches — the site might
        // be down, behind a region block, or returning a soft 404
        // page.  Storing the snapshot keeps the audit trail; the
        // user just won't see a noise alert.
        guard current.httpStatus == 200, previous.httpStatus == 200 else {
            return nil
        }
        guard previous.bodyHash != current.bodyHash else {
            return nil
        }
        // Compute severity based on body-length delta as fraction
        // of previous.  Same hash but different length is impossible
        // (already short-circuited).
        let delta: Double = {
            guard previous.bodyLength > 0 else { return 1.0 }
            return abs(Double(current.bodyLength - previous.bodyLength))
                / Double(previous.bodyLength)
        }()
        let severity: TrustWatchAlertSeverity
        switch delta {
        case ..<0.05:  severity = .info
        case ..<0.20:  severity = .notice
        default:       severity = .material
        }
        return TrustWatchAlert(
            target: current.target,
            previousHash: previous.bodyHash,
            newHash: current.bodyHash,
            previousLength: previous.bodyLength,
            newLength: current.bodyLength,
            observedAt: current.observedAt,
            severity: severity
        )
    }

    /// ISO-8601 (YYYY-MM-DDThh:mm:ssZ) for a given Date in UTC.
    /// Stable across locales — used as `observedAt` everywhere.
    public static func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
