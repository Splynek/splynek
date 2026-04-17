import Foundation

/// Next-level AI for Splynek: a single chat-like entry point that
/// understands *what the user wants* and dispatches to the right
/// action. v0.25 added URL resolution; v0.27 added history search;
/// v0.28 unifies both + app actions under one conversation.
///
/// The concierge distinguishes intents locally by asking Ollama to
/// classify the user's message into one of:
///   - download  : resolve a URL and hand it to the download engine
///   - queue     : resolve + append to queue (don't start)
///   - search    : natural-language history search
///   - cancelAll : abort every running job
///   - pauseAll  : pause every running job
///   - unclear   : ask a short follow-up
///
/// Then it dispatches. One prompt, one round-trip, no framework /
/// cloud deps.
extension AIAssistant {

    /// High-level output of the concierge: what action Splynek should
    /// take, plus a short rationale for the chat log.
    enum ConciergeAction: Sendable, Equatable {
        case download(url: URL, rationale: String)
        case queue(url: URL, rationale: String)
        case search(query: String)
        case cancelAll
        case pauseAll
        case unclear(followUp: String)
    }

    /// Take any user utterance and decide what to do. Honors the same
    /// "never hallucinate" discipline as `resolveURL`: if the model is
    /// uncertain, it returns `.unclear(followUp:)` with a short
    /// clarifying question rather than guessing.
    func concierge(
        _ utterance: String, timeout: TimeInterval = 25
    ) async throws -> ConciergeAction {
        guard case .ready(let modelName) = state else { throw AIError.unavailable }
        let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .unclear(followUp: "What would you like to download?")
        }
        let system = """
        You are the action router for a macOS download manager called
        Splynek. Classify the user's message and return a single JSON
        object — no markdown, no prose around it.

        Shapes:
          { "action": "download", "url": "https://…",
            "rationale": "one short sentence" }
          { "action": "queue", "url": "https://…",
            "rationale": "one short sentence" }
          { "action": "search", "query": "short query" }
          { "action": "cancelAll" }
          { "action": "pauseAll" }
          { "action": "unclear", "followUp": "short clarifying question" }

        Rules:
          - For "download"/"queue", "url" MUST be a direct download URL
            (HTTP/HTTPS or magnet:). Prefer official upstream mirrors.
            Do NOT invent URLs.
          - Use "queue" when the user says "later", "queue", "add to queue".
          - Use "cancelAll" when they say stop/cancel/abort all.
          - Use "pauseAll" when they say pause/suspend all.
          - Use "search" when they're asking about previous downloads
            ("what did I download…", "find that iso…").
          - If unsure which action, return "unclear" with a short
            question that will disambiguate.
        """
        struct Req: Encodable {
            let model: String
            let prompt: String
            let system: String
            let stream: Bool
            let format: String
            let options: Options
            struct Options: Encodable {
                let temperature: Double
                let num_predict: Int
            }
        }
        let req = Req(
            model: modelName,
            prompt: trimmed,
            system: system,
            stream: false,
            format: "json",
            options: .init(temperature: 0.1, num_predict: 400)
        )
        var urlReq = URLRequest(url: Self.endpoint.appendingPathComponent("api/generate"))
        urlReq.httpMethod = "POST"
        urlReq.timeoutInterval = timeout
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.httpBody = try JSONEncoder().encode(req)
        let (data, resp) = try await URLSession.shared.data(for: urlReq)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.badResponse("HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        struct OllamaResp: Decodable { let response: String }
        let outer = try JSONDecoder().decode(OllamaResp.self, from: data)
        guard let inner = outer.response.data(using: .utf8) else {
            throw AIError.badResponse("model response not utf-8")
        }
        struct Answer: Decodable {
            let action: String?
            let url: String?
            let rationale: String?
            let query: String?
            let followUp: String?
        }
        guard let answer = try? JSONDecoder().decode(Answer.self, from: inner) else {
            return .unclear(followUp: "I didn't understand that — could you rephrase?")
        }
        switch (answer.action ?? "").lowercased() {
        case "download":
            guard let raw = answer.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: raw),
                  validURL(url) else {
                return .unclear(followUp: "I couldn't find a direct URL — can you paste one?")
            }
            return .download(url: url, rationale: answer.rationale ?? "AI-suggested URL")
        case "queue":
            guard let raw = answer.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: raw),
                  validURL(url) else {
                return .unclear(followUp: "I couldn't find a direct URL to queue — can you paste one?")
            }
            return .queue(url: url, rationale: answer.rationale ?? "AI-suggested URL")
        case "search":
            return .search(query: answer.query ?? trimmed)
        case "cancelall":
            return .cancelAll
        case "pauseall":
            return .pauseAll
        default:
            return .unclear(followUp: answer.followUp ?? "Can you clarify what you'd like?")
        }
    }

    private func validURL(_ url: URL) -> Bool {
        if let scheme = url.scheme?.lowercased() {
            if scheme == "magnet" { return true }
            if (scheme == "http" || scheme == "https"), let host = url.host, !host.isEmpty {
                return true
            }
        }
        return false
    }
}
