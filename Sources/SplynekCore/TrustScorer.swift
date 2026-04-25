import Foundation

/// v1.5: pure scoring for `TrustCatalog.Entry` → 0–100 score + level.
///
/// Design principles:
///
///   1. **Pure.**  No I/O, no actor isolation, no shared state.
///      Same input → same output, always.  Trivial to unit test.
///   2. **Deterministic.**  No randomness, no time-of-day effects.
///   3. **Auditable.**  Anyone can read this file and see exactly
///      how a score was computed.  No "machine learning", no
///      hidden weights, no black-box magic.
///   4. **User-weighted.**  Default weights are public + documented;
///      users override per-axis in Settings (planned v1.6).  A user
///      who cares mostly about privacy can dial security down —
///      the underlying concerns don't change, only the summary.
///   5. **Bounded.**  Output is clamped to 0…100.  A pathological
///      catalog with 50 concerns can't blow past the cap.
///
/// **Score is a SUMMARY.** The UI must always show:
///   • The numeric score AND the categorical level.
///   • The individual concern labels with citations.
///   • Never the score alone.  Score-without-evidence is the path
///     to false-precision arguments and defamation risk.
enum TrustScorer {

    // MARK: - Weights

    /// Per-axis multiplier.  Default weights err on the side of
    /// **security > privacy > trust > business model** because:
    ///   • A CVE is concrete + actionable (patch or stop using).
    ///   • Privacy concerns are what the App Store privacy label
    ///     programme is built around — surface them.
    ///   • Regulatory fines lag harm; weight slightly less than
    ///     primary security/privacy.
    ///   • Business model (e.g. ad-supported) is informational — the
    ///     user may genuinely not mind ads in exchange for a free
    ///     app.  Lowest default weight.
    ///
    /// All weights ∈ (0, 3].  Zero would silently hide an axis;
    /// >3 would let one axis dominate the score.
    struct Weights: Codable, Sendable, Equatable {
        var privacy: Double
        var security: Double
        var trust: Double
        var businessModel: Double

        init(privacy: Double = 1.0,
             security: Double = 1.5,
             trust: Double = 1.0,
             businessModel: Double = 0.6) {
            self.privacy = privacy
            self.security = security
            self.trust = trust
            self.businessModel = businessModel
        }

        static let `default` = Weights()

        /// Clamp every weight to (0, 3] so a malformed user-saved
        /// preference can't break the score.
        var sanitised: Weights {
            Weights(
                privacy:        clampWeight(privacy),
                security:       clampWeight(security),
                trust:          clampWeight(trust),
                businessModel:  clampWeight(businessModel)
            )
        }

        private func clampWeight(_ v: Double) -> Double {
            if !v.isFinite || v <= 0 { return 0.1 }
            return min(3.0, v)
        }
    }

    // MARK: - Level

    /// Categorical risk level.  Always paired with the score in UI.
    /// The thresholds are deliberately wide so small catalog
    /// changes don't bounce an app between levels.
    enum Level: String, Codable, CaseIterable, Sendable {
        case low        // 0–19
        case moderate   // 20–49
        case high       // 50–79
        case severe     // 80–100

        var label: String {
            switch self {
            case .low:       return "Low"
            case .moderate:  return "Moderate"
            case .high:      return "High"
            case .severe:    return "Severe"
            }
        }
    }

    // MARK: - Score

    /// The result of scoring an entry.  Carries both the numeric
    /// score and its categorical level so callers don't recompute
    /// the bucket independently.  `breakdown` shows per-axis
    /// contribution — required by the UI to never show a number
    /// without its supporting math.
    struct Score: Sendable, Equatable {
        let value: Int          // 0…100
        let level: Level
        let breakdown: [TrustCatalog.Axis: Int]   // per-axis points

        /// True when the entry has no concerns at all.  The UI
        /// renders this as a green "no public concerns recorded"
        /// row rather than "0/100 — Low" which could read as
        /// "we tested it, it's fine" (which we did NOT verify).
        let hasConcerns: Bool
    }

    // MARK: - Severity points

    /// Points contributed by a single concern at each severity.
    /// These are intentionally non-linear: a severe concern is
    /// >5× a low concern, because in practice severe means
    /// regulatory action / catastrophic breach.
    private static func points(for severity: TrustCatalog.Severity) -> Double {
        switch severity {
        case .low:       return 5
        case .moderate:  return 12
        case .high:      return 25
        case .severe:    return 40
        }
    }

    private static func axisWeight(_ axis: TrustCatalog.Axis, _ w: Weights) -> Double {
        switch axis {
        case .privacy:        return w.privacy
        case .security:       return w.security
        case .trust:          return w.trust
        case .businessModel:  return w.businessModel
        }
    }

    // MARK: - Public API

    /// Compute the score for a single entry under the given weights.
    /// Default weights match the public, documented `Weights.default`.
    static func score(_ entry: TrustCatalog.Entry,
                      weights: Weights = .default) -> Score {
        let w = weights.sanitised
        var byAxis: [TrustCatalog.Axis: Double] = [:]
        for c in entry.concerns {
            let raw = points(for: c.severity) * axisWeight(c.axis, w)
            byAxis[c.axis, default: 0] += raw
        }
        let total = byAxis.values.reduce(0, +)
        let value = max(0, min(100, Int(total.rounded())))
        let level: Level
        switch value {
        case 0..<20:  level = .low
        case 20..<50: level = .moderate
        case 50..<80: level = .high
        default:      level = .severe
        }
        // Per-axis breakdown for UI; clamp each to 0…100 for display
        // even though the unclamped sum is what determined the level.
        var breakdown: [TrustCatalog.Axis: Int] = [:]
        for (axis, raw) in byAxis {
            breakdown[axis] = max(0, min(100, Int(raw.rounded())))
        }
        return Score(
            value: value,
            level: level,
            breakdown: breakdown,
            hasConcerns: !entry.concerns.isEmpty
        )
    }
}
