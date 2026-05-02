import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// PDFSummarizer reads PDF text using PDFKit's public PDFDocument /
// PDFPage APIs.  No JavaScript form actions are evaluated.  The
// extracted text is passed BACK to the caller as a String — never
// executed, never used to modify the running app.  The downstream
// LLM call (in splynek-pro/AIAssistant.swift) treats the string as
// untrusted data and responds with a structured summary that goes
// through the same Codable decode boundary as every other AI call.
// =====================================================================

/// v1.7: PDF text extraction + LLM-ready preparation.  The Concierge
/// "summarize this PDF" tool wraps a `PDFSummarizer.prepare(...)` call
/// to the local LLM, then renders the response inline as a chat card.
///
/// Why a separate type instead of doing it all inline in the AI
/// dispatcher?  Three reasons:
///   1. **Testability.** The text-extraction logic can be exercised
///      against fixture PDFs without spinning up a model.
///   2. **Cancellability.** Long PDFs need progress + interrupt;
///      keeping that machinery in a dedicated type avoids polluting
///      the dispatcher.
///   3. **Free-tier degradation.** A future free-tier feature could
///      use `PDFSummarizer` to extract text into the search index
///      without invoking the AI at all.
enum PDFSummarizer {

    /// Extracted, cleaned, bounded text from a PDF.  Bounded because
    /// LLM context windows are finite — Foundation Models on iOS 26 /
    /// macOS 26 caps at a few thousand tokens depending on hardware.
    /// We aim for ≤ 8000 characters of post-cleanup text, which fits
    /// comfortably even on small models.
    struct Extract: Hashable, Sendable {
        let source: URL
        let pageCount: Int
        let text: String
        let truncated: Bool
        /// Approximate token estimate (chars ÷ 4).  Useful for the
        /// caller to pick an appropriately-sized prompt template.
        var approximateTokens: Int { text.count / 4 }
    }

    enum Failure: Error, LocalizedError {
        case unreadable
        case empty
        case sandboxDenied

        var errorDescription: String? {
            switch self {
            case .unreadable:    return "Could not open the PDF."
            case .empty:         return "The PDF contains no extractable text."
            case .sandboxDenied: return "Splynek doesn't have permission to read this file. Pick it again via the file picker."
            }
        }
    }

    /// Read up to `charLimit` characters of text from the PDF at
    /// `url`.  The caller is responsible for ensuring `url` is a
    /// security-scoped path the user picked via NSOpenPanel — under
    /// MAS sandboxing the only legal entry point.
    static func extract(
        _ url: URL,
        charLimit: Int = 8_000
    ) throws -> Extract {
        #if canImport(PDFKit)
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw Failure.sandboxDenied
        }
        guard let doc = PDFDocument(url: url) else {
            throw Failure.unreadable
        }

        var assembled = ""
        var truncated = false
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let raw = page.string ?? ""
            let cleaned = clean(raw)
            if assembled.count + cleaned.count > charLimit {
                let remaining = charLimit - assembled.count
                if remaining > 0 {
                    let endIdx = cleaned.index(cleaned.startIndex, offsetBy: remaining)
                    assembled += cleaned[..<endIdx]
                }
                truncated = true
                break
            }
            assembled += cleaned
            if i < doc.pageCount - 1 { assembled += "\n\n" }
        }

        let trimmed = assembled.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw Failure.empty }

        return Extract(
            source: url,
            pageCount: doc.pageCount,
            text: trimmed,
            truncated: truncated
        )
        #else
        // Linux / non-Apple build: PDFKit unavailable.  Throw so callers
        // surface a reasonable message rather than hand back empty text.
        throw Failure.unreadable
        #endif
    }

    /// Build a prompt the local LLM can answer in one shot.  The
    /// instruction template asks for a structured answer (3-bullet
    /// summary) so the result fits the same `{summary, bullets[]}`
    /// `Codable` decode shape the dispatcher already uses.
    static func prompt(for extract: Extract) -> String {
        """
        You are summarizing a PDF the user just opened.  Return a JSON
        object with two keys:

          "summary": one-sentence high-level description (≤ 30 words)
          "bullets": an array of 3 short bullet points, each ≤ 20 words,
                    capturing the document's main claims or findings

        Do not invent details that aren't in the text.  Do not output
        anything except the JSON object.

        --- BEGIN DOCUMENT TEXT ---
        \(extract.text)
        --- END DOCUMENT TEXT ---
        """
    }

    // MARK: - Internals (exposed for tests)

    /// Collapse runs of whitespace, drop control characters, drop
    /// the noisy header/footer lines PDFKit returns from many
    /// documents (page numbers, journal-name banners, ...).
    static func clean(_ raw: String) -> String {
        // Strip control characters (except \n) — PDFKit sometimes
        // returns ligature glyphs as PUA codepoints that LLMs choke on.
        let allowed = CharacterSet.controlCharacters.subtracting(.newlines).inverted
        let filtered = String(raw.unicodeScalars.filter { allowed.contains($0) })

        // Collapse runs of whitespace within a line, but preserve
        // paragraph breaks.
        let lines = filtered.split(separator: "\n", omittingEmptySubsequences: false)
        let collapsed = lines.map { line -> String in
            line.split(separator: " ", omittingEmptySubsequences: true)
                .joined(separator: " ")
        }

        // Drop very short lines that look like page-number cruft.
        let kept = collapsed.filter { line in
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !(t.count < 4 && t.allSatisfy { $0.isNumber || $0.isPunctuation })
        }

        return kept.joined(separator: "\n")
    }
}
