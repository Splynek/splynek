import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// HistorySearch reads only from `DownloadHistory.load()`, which reads
// only from the user's own history.json under Application Support.
// No network calls.  No `Process(...)`, no `eval`, no dynamic dispatch.
// The "ranking" is a pure function of fields already in the
// `HistoryEntry` Codable struct, executed entirely in Swift.
// =====================================================================

/// v1.7: ranked, tokenized search over `DownloadHistory`.  The Concierge
/// assistant uses this to answer "what did I download about X last
/// month?" without sending the user's history to a cloud LLM.  It's
/// also exposed as an App Intent so Shortcuts can query it.
///
/// Ranking is a deterministic, dependency-free formula:
///
///     score(entry) = relevance × recency
///
///     relevance = sum_{q in query_tokens} match_weight(entry, q)
///     recency   = decay(now − entry.finishedAt, half_life: 60 days)
///
/// where `match_weight` rewards matches in `filename` (×3), in `url`
/// (×2), and in the URL host (×1).  Ties broken by `finishedAt` desc.
///
/// Why a hand-rolled ranker instead of full-text + TF-IDF?  The catalog
/// is small (capped at 500 entries by `DownloadHistory.record`), so a
/// linear scan is fast and the ranking can be reasoned about
/// statically.  Pulls in zero dependencies.
enum HistorySearch {

    /// One ranked match.  The `score` is opaque — useful only for
    /// sort ordering and debug printing.
    struct Match: Hashable, Sendable {
        let entry: HistoryEntry
        let score: Double
        let matchedFields: Set<MatchField>

        enum MatchField: String, Hashable, Sendable {
            case filename
            case url
            case host
        }
    }

    /// Search the user's history for entries matching the query.  An
    /// empty query returns the most-recent N entries (recency only).
    /// `now` is injected so tests can pin recency math.
    static func search(
        _ query: String,
        in entries: [HistoryEntry] = DownloadHistory.load(),
        limit: Int = 25,
        now: Date = Date()
    ) -> [Match] {
        let tokens = tokenize(query)

        let scored: [Match] = entries.compactMap { entry in
            let recency = recencyScore(entry.finishedAt, now: now)
            // Empty query → score = recency only, no field requirements.
            if tokens.isEmpty {
                return Match(entry: entry, score: recency, matchedFields: [])
            }
            let (relevance, fields) = relevanceScore(entry, tokens: tokens)
            // Drop entries that didn't match any token.
            if relevance == 0 { return nil }
            return Match(entry: entry, score: relevance * recency, matchedFields: fields)
        }

        return scored
            .sorted { (a, b) in
                if a.score != b.score { return a.score > b.score }
                return a.entry.finishedAt > b.entry.finishedAt
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Internals (exposed for tests)

    /// Lowercase, split on whitespace + punctuation, drop singletons
    /// and the most common stopwords ("the", "a", "of", …) so a query
    /// like "the latest macOS update" weights "latest", "macos",
    /// "update".
    static func tokenize(_ s: String) -> [String] {
        let lowered = s.lowercased()
        let separators = CharacterSet.alphanumerics.inverted
        return lowered
            .components(separatedBy: separators)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    /// Per-field match weight, summed.  Returns 0 if no token hit.
    static func relevanceScore(
        _ entry: HistoryEntry,
        tokens: [String]
    ) -> (Double, Set<Match.MatchField>) {
        let filename = entry.filename.lowercased()
        let url = entry.url.lowercased()
        let host = URL(string: entry.url)?.host?.lowercased() ?? ""

        var score = 0.0
        var hits = Set<Match.MatchField>()
        for t in tokens {
            if filename.contains(t) { score += 3.0; hits.insert(.filename) }
            if url.contains(t)      { score += 2.0; hits.insert(.url) }
            if host.contains(t)     { score += 1.0; hits.insert(.host) }
        }
        return (score, hits)
    }

    /// Exponential decay: 1.0 at t=0, 0.5 at t=halfLife, 0.25 at 2×, …
    /// Bounded to ≥ 0.05 so very old entries can still surface for a
    /// rare-keyword match.
    static func recencyScore(
        _ finishedAt: Date,
        now: Date,
        halfLife: TimeInterval = 60 * 24 * 3600  // 60 days
    ) -> Double {
        let dt = max(0, now.timeIntervalSince(finishedAt))
        let decayed = pow(0.5, dt / halfLife)
        return max(0.05, decayed)
    }

    /// Trimmed English stopword list.  Not exhaustive — just the
    /// noise words that recur in download-history queries.  pt-PT /
    /// fr / de etc. have their own stopword lists if we ever want
    /// query-language detection; currently English-only because the
    /// LLM normalises the user's input through the prompt template.
    static let stopwords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "what",
        "find", "show", "search", "any", "some", "about", "have",
        "had", "all", "you", "your", "ago", "last", "this", "today",
        "yesterday",
    ]
}
