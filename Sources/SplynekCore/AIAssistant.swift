import Foundation

/// Local-AI download assistant.
///
/// Talks to Ollama on `localhost:11434` when it's running. No API key,
/// no cloud round-trip, no third-party data exposure — the user's LLM
/// on the user's machine answers the user's prompt. If Ollama isn't
/// installed the assistant quietly reports `.unavailable` and the UI
/// hides every AI affordance.
///
/// Scope for v0.25: **natural-language URL resolution**. The user types
/// something like "the latest Ubuntu desktop ISO" and the model emits a
/// direct download URL. Splynek puts that URL in the form, shows the
/// model's rationale as a badge, and lets the user hit Start — it
/// never auto-downloads without explicit confirmation, because LLMs
/// hallucinate URLs and we want the human in the loop.
actor AIAssistant {

    /// Detection + readiness state, mirrored to the VM so the UI can
    /// disable the AI row when Ollama is missing / idle.
    enum State: Sendable {
        case unknown
        case unavailable(String)
        case ready(model: String)
    }

    private(set) var state: State = .unknown
    private(set) var model: String?
    /// Overridden by the user via a future dropdown; defaults to the
    /// first model whose name starts with one of the preferred families.
    /// Heuristic: smaller instruct-tuned models are fine for URL-
    /// resolution prompts and much faster than 7B+ variants.
    var preferredFamilies = ["llama3", "llama3.2", "gemma3", "gemma", "qwen", "mistral", "phi"]

    /// Where Ollama typically listens. Not configurable yet — if a user
    /// has Ollama on a non-default port, that's a follow-up.
    static let endpoint = URL(string: "http://localhost:11434")!

    enum AIError: LocalizedError {
        case unavailable
        case modelRefused(String)
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "No local LLM detected. Install Ollama (ollama.ai) + a small model to enable AI URL resolution."
            case .modelRefused(let s):
                return "Local LLM couldn't resolve that: \(s)"
            case .badResponse(let s):
                return "Local LLM returned something unexpected: \(s)"
            }
        }
    }

    /// Probe `/api/tags` and pick a model. 3-second timeout so a stuck
    /// Ollama doesn't block the UI. Called at app launch + retriable
    /// via a Refresh button in the AboutView card.
    func detect() async -> State {
        var req = URLRequest(url: Self.endpoint.appendingPathComponent("api/tags"))
        req.timeoutInterval = 3
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                state = .unavailable("Ollama not responding on localhost:11434")
                return state
            }
            struct Tags: Decodable {
                struct Model: Decodable { let name: String }
                let models: [Model]
            }
            let tags = try JSONDecoder().decode(Tags.self, from: data)
            guard !tags.models.isEmpty else {
                state = .unavailable("Ollama is running but no models are installed. Try `ollama pull llama3.2:3b`.")
                return state
            }
            // Pick the smallest-named model matching our preferred
            // families, else the first model listed. Ollama returns
            // tags roughly in modification order; either is fine for
            // the "just work on the first try" experience.
            let picked: String = {
                for fam in preferredFamilies {
                    if let m = tags.models.first(where: { $0.name.hasPrefix(fam) }) {
                        return m.name
                    }
                }
                return tags.models[0].name
            }()
            self.model = picked
            state = .ready(model: picked)
            return state
        } catch {
            state = .unavailable(error.localizedDescription)
            return state
        }
    }

    /// Ask the local LLM to turn `query` into a direct download URL.
    /// Uses Ollama's `format: "json"` mode so the response is a valid
    /// JSON object; we parse it, validate the URL, and return both the
    /// URL and the model's one-sentence rationale for the UI.
    ///
    /// The model is told explicitly to return `{"error": "..."}` when
    /// it can't confidently resolve, which keeps hallucinated URLs from
    /// reaching the download engine.
    func resolveURL(_ query: String, timeout: TimeInterval = 25) async throws -> (url: URL, rationale: String) {
        guard case .ready(let modelName) = state else {
            throw AIError.unavailable
        }
        let system = """
        You are a URL resolver for a download manager. Given a user's
        request, respond with a single JSON object and nothing else:
          { "url": "https://…", "rationale": "one short sentence" }
        Rules:
          - The URL MUST be a direct download (HTTP or HTTPS), not a
            landing page.
          - Prefer official upstream mirrors (e.g. releases.ubuntu.com,
            cdn.kernel.org, github.com/<owner>/<repo>/releases/download).
          - If you are NOT reasonably confident a specific file URL
            matches the request, respond with:
              { "error": "one short sentence explaining why" }
          - Do not wrap your output in markdown. Raw JSON only.
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
            }
        }
        let req = Req(
            model: modelName,
            prompt: query,
            system: system,
            stream: false,
            format: "json",
            options: .init(temperature: 0.1)
        )
        var urlReq = URLRequest(url: Self.endpoint.appendingPathComponent("api/generate"))
        urlReq.httpMethod = "POST"
        urlReq.timeoutInterval = timeout
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.httpBody = try JSONEncoder().encode(req)
        let (data, resp) = try await URLSession.shared.data(for: urlReq)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            throw AIError.badResponse("HTTP \(status) from Ollama")
        }
        struct OllamaResp: Decodable { let response: String }
        let outer = try JSONDecoder().decode(OllamaResp.self, from: data)
        // The model's JSON sits inside `response` as a string.
        guard let inner = outer.response.data(using: .utf8) else {
            throw AIError.badResponse("model response not decodable")
        }
        struct Answer: Decodable {
            let url: String?
            let rationale: String?
            let error: String?
        }
        guard let answer = try? JSONDecoder().decode(Answer.self, from: inner) else {
            throw AIError.badResponse(String(outer.response.prefix(200)))
        }
        if let err = answer.error {
            throw AIError.modelRefused(err)
        }
        guard let urlStr = answer.url?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: urlStr),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            throw AIError.modelRefused("model did not return a valid http(s) URL")
        }
        return (url, answer.rationale ?? "AI-suggested URL")
    }

    /// Natural-language history search. Second act of the v0.25 local-AI
    /// story: the user types "that docker image from last Tuesday" and
    /// the LLM picks matching rows out of the cached history. Entirely
    /// local — no embedding index, no vector store, just a ~6 KB JSON
    /// payload handed to the same Ollama instance Splynek already uses.
    ///
    /// Returns indices into `entries` (ranked best first), never
    /// fabricated. Hallucinated indices are filtered out before return.
    func searchHistory(
        query: String,
        entries: [HistoryEntry],
        timeout: TimeInterval = 25
    ) async throws -> [Int] {
        guard case .ready(let modelName) = state else { throw AIError.unavailable }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let capped = entries.suffix(200)
        let base = entries.count - capped.count
        struct Row: Encodable {
            let i: Int
            let name: String
            let host: String
            let bytes: Int64
            let when: String
        }
        let iso = ISO8601DateFormatter()
        let rows = capped.enumerated().map { offset, e in
            Row(
                i: base + offset,
                name: e.filename,
                host: URL(string: e.url)?.host ?? "?",
                bytes: e.totalBytes,
                when: iso.string(from: e.finishedAt)
            )
        }
        let corpus = (try? String(
            data: JSONEncoder().encode(rows), encoding: .utf8
        )) ?? "[]"

        let system = """
        You are searching a user's download history. Given a query and
        a JSON array of history rows (each with i, name, host, bytes,
        when), respond with a single JSON object and nothing else:
          { "indices": [<i>, <i>, ...] }
        Rules:
          - Return at most 10 indices, best match first.
          - Use ONLY the integer values from the "i" field of the input.
          - If nothing matches, return { "indices": [] }.
          - Raw JSON only; no markdown.
        """
        let prompt = "Query: \(trimmed)\n\nHistory:\n\(corpus)"

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
            prompt: prompt,
            system: system,
            stream: false,
            format: "json",
            options: .init(temperature: 0.1, num_predict: 256)
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
            throw AIError.badResponse("not utf-8")
        }
        struct Answer: Decodable { let indices: [Int] }
        let answer = try JSONDecoder().decode(Answer.self, from: inner)
        return answer.indices.filter { $0 >= 0 && $0 < entries.count }
    }
}
