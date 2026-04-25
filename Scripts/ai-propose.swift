#!/usr/bin/env swift

// v1.4 discovery engine — AI-drafted proposals.
//
// Takes Scripts/candidates.json (from discover.swift) and asks a local
// LLM (or any OpenAI-compat endpoint) to draft a Sovereignty-catalog
// entry for each candidate: targetOrigin, suggested category, and 1–3
// European or open-source alternatives.
//
// Output: Scripts/proposals.json — one proposal per candidate, ready
// for human review by `merge-proposals.swift`.
//
// Crucial: the AI is a DRAFTING tool, not an authority.  Every
// proposal must be human-reviewed before merging.  The prompt below
// mirrors the FORBIDDEN PATTERNS block in AIAssistant.swift (v1.4
// AI hardening) to minimise US-leakage, but the deny-list is here in
// belt + suspenders form anyway.
//
// Default endpoint: LM Studio's standard `http://localhost:1234/v1`.
// Override with env `OPENAI_COMPAT_URL` (full base URL).
// Optional API key: env `OPENAI_API_KEY`.
// Default model: `local-model` (LM Studio loads whatever is selected
// in the UI; pass --model to override).
//
// Run from the repo root.  Zero third-party deps.
//
//   swift Scripts/ai-propose.swift
//   swift Scripts/ai-propose.swift --limit 20
//   swift Scripts/ai-propose.swift --model gpt-4o-mini
//   OPENAI_COMPAT_URL=https://api.openai.com/v1 OPENAI_API_KEY=… \
//     swift Scripts/ai-propose.swift

import Foundation

// MARK: - Shapes

struct Candidate: Codable {
    let bundleID: String
    let displayName: String
    let origin: String?
    let category: String?
    let source: String
    let note: String?
}
struct CandidatesFile: Codable {
    let version: Int
    let candidates: [Candidate]
}

struct ProposedAlt: Codable {
    let name: String
    let origin: String      // europe / oss / europeAndOSS / other
    let homepage: String
    let note: String
}
struct Proposal: Codable {
    let bundleID: String
    let displayName: String
    let suggestedOrigin: String
    let suggestedCategory: String
    let confidence: String       // low / medium / high
    let alternatives: [ProposedAlt]
    let source: String
    let modelRationale: String?
}
struct ProposalsFile: Codable {
    let version: Int
    let generatedAt: String
    let model: String
    let proposals: [Proposal]
}

// MARK: - LLM client

let endpointBase = ProcessInfo.processInfo.environment["OPENAI_COMPAT_URL"]
    ?? "http://localhost:1234/v1"
let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]

/// v1.4 audit: redact the endpoint for log output.  Strips userinfo
/// (user:pass@), query string, and fragment so an env value like
/// `https://user:secret@api.example.com/v1?key=…` doesn't leak into
/// stderr / CI logs.
func redactEndpoint(_ s: String) -> String {
    guard let comp = URLComponents(string: s), let host = comp.host else { return "<unparseable>" }
    let scheme = comp.scheme ?? "?"
    let port = comp.port.map { ":\($0)" } ?? ""
    let path = comp.path.isEmpty ? "" : comp.path
    return "\(scheme)://\(host)\(port)\(path)"
}

/// v1.4 audit: refuse `http://` for non-local endpoints.  An
/// unencrypted remote LLM call is a MITM goldmine — the prompt
/// includes the user's app list, and the response shapes the
/// catalog.  Localhost is allowed (LM Studio / Ollama default).
func endpointSchemeIsAcceptable(_ s: String) -> Bool {
    guard let comp = URLComponents(string: s), let scheme = comp.scheme?.lowercased() else { return false }
    if scheme == "https" { return true }
    if scheme == "http" {
        let host = (comp.host ?? "").lowercased()
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }
    return false
}

if !endpointSchemeIsAcceptable(endpointBase) {
    fputs("ai-propose: refusing endpoint '\(redactEndpoint(endpointBase))' — only https:// or localhost http:// are allowed.\n", stderr)
    fputs("            Set OPENAI_COMPAT_URL to an https endpoint, or use LM Studio / Ollama on localhost.\n", stderr)
    exit(4)
}

struct ChatMessage: Encodable { let role: String; let content: String }
struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let response_format: ResponseFormat?
    struct ResponseFormat: Encodable { let type: String }
}
struct ChatResponse: Decodable {
    struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
    let choices: [Choice]
}

func chatComplete(model: String, system: String, user: String, timeout: TimeInterval) async throws -> String {
    guard let url = URL(string: endpointBase + "/chat/completions") else {
        throw NSError(domain: "ai-propose", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad OPENAI_COMPAT_URL"])
    }
    var req = URLRequest(url: url, timeoutInterval: timeout)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let key = apiKey { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
    let body = ChatRequest(
        model: model,
        messages: [
            .init(role: "system", content: system),
            .init(role: "user", content: user),
        ],
        temperature: 0.2,
        response_format: .init(type: "json_object")
    )
    req.httpBody = try JSONEncoder().encode(body)
    let (data, response) = try await URLSession.shared.data(for: req)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
        throw NSError(domain: "ai-propose", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(snippet)"])
    }
    let resp = try JSONDecoder().decode(ChatResponse.self, from: data)
    return resp.choices.first?.message.content ?? ""
}

// MARK: - Prompt

let systemPrompt = """
You are a Sovereignty-catalog drafting assistant for a Mac download
manager called Splynek.  The user gives you the name + bundle ID of an
installed Mac app.  Your job: propose a single JSON object describing
the app's sovereignty stance and 1–3 European or open-source alts.

OUTPUT SHAPE — emit ONE JSON object, nothing else, no markdown fences:

{
  "suggestedOrigin": "unitedStates" | "china" | "russia" | "other" | "europe" | "oss" | "europeAndOSS",
  "suggestedCategory": "<one of the categories below>",
  "confidence": "low" | "medium" | "high",
  "modelRationale": "one short sentence — why this categorisation",
  "alternatives": [
    { "name": "...", "origin": "europe|oss|europeAndOSS|other",
      "homepage": "https://...", "note": "country + license + 1-line summary" }
  ]
}

VALID CATEGORIES:
  chat-personal, chat-team, video-call, storage-personal, storage-business,
  password, vpn, mail, note, browser, office, ai-chat, ai-translate,
  video-edit, photo-edit, photo-raw, vector, pdf, task, code-editor,
  terminal, remote-desktop, screen-recording, music-production, audio-edit,
  map-nav, social-media, video-streaming, music-streaming, finance,
  database, cad-3d, cad-2d, torrent, feed-reader, survey-form, e-sign,
  calendar, scheduling, crm, analytics, monitoring, system-util, antivirus,
  knowledge-base, cloud-cli, mdm-agent, drawing, drawio, ide, git-gui,
  container, api-client, screenshot, clipboard, launcher, window-mgmt,
  file-transfer, bibliography, archive, encryption, backup, calendar,
  reader, notes-pro, kanban, color-picker, docs-collab, password-sso,
  audio-player, video-player, screen-share, dictation, habit-track,
  menu-bar, dotfiles, scientific, stats, ocr, email-marketing, meeting,
  cloud-cli-control, photo-manager, drawing.

If the app's category isn't a perfect match, pick the closest.

FORBIDDEN PATTERNS — DO NOT propose these as alternatives:
  - Streaming (US): Netflix, YouTube, Prime Video, Disney+, Hulu, HBO Max,
    Apple TV+, Peacock, Paramount+, Tubi, Pluto.  Acceptable: Arte.tv (FR),
    BBC iPlayer (UK), MUBI (UK), Jellyfin (OSS).
  - Chat / video (US/CN): Discord, Slack, Teams, Zoom, WhatsApp, Messenger,
    Telegram, Skype, Google Meet, WeChat, QQ, DingTalk, LINE.  Acceptable:
    Signal, Element (UK), Threema (CH), Jitsi Meet, Wire (CH), Mattermost.
  - Storage (US): Dropbox, Google Drive, OneDrive, Box, iCloud.  Acceptable:
    Nextcloud (DE), Proton Drive (CH), Syncthing, pCloud (CH), Tresorit (HU).
  - Passwords (US/CA): 1Password, LastPass, Dashlane.  Acceptable: Bitwarden,
    KeePassXC, Proton Pass.
  - Productivity (US): Notion, Evernote, Airtable, Asana, ClickUp, Trello,
    Jira, Confluence, Monday.  Acceptable: Obsidian, Joplin, Logseq,
    OpenProject (DE), Taiga (ES), BookStack.
  - AI (US): ChatGPT, Claude, Gemini, Copilot, Perplexity.  Acceptable:
    Mistral Le Chat (FR), LM Studio, Ollama, Jan.
  - Browsers: Chrome, Edge, Brave, Arc, Opera (CN-owned).  Acceptable:
    Firefox, LibreWolf, Vivaldi (NO), Mullvad Browser (SE).

QUALITY RULES:
  - 1-3 alternatives.  Quality over quantity.
  - Every `note` should mention country and license/cost when known
    ("Germany. AGPL." or "France. Paid, one-time.").
  - Every `homepage` must be a real, current URL.  When unsure, pick
    the most canonical project URL — never invent.
  - `confidence: low` when you're guessing; `high` when this is
    well-known (e.g. obvious US SaaS).
"""

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())
var limit: Int = .max
var model = "local-model"
var concurrency = 4
var inputPath = "Scripts/candidates.json"
var outputPath = "Scripts/proposals.json"

var i = 0
while i < args.count {
    switch args[i] {
    case "--limit":
        if i + 1 < args.count, let v = Int(args[i+1]) { limit = v; i += 1 }
    case "--model":
        if i + 1 < args.count { model = args[i+1]; i += 1 }
    case "--concurrency":
        if i + 1 < args.count, let v = Int(args[i+1]) { concurrency = v; i += 1 }
    case "--input":
        if i + 1 < args.count { inputPath = args[i+1]; i += 1 }
    case "--output":
        if i + 1 < args.count { outputPath = args[i+1]; i += 1 }
    case "--help", "-h":
        print("""
        ai-propose.swift — draft Sovereignty entries for candidates via local LLM

        Usage:
          swift Scripts/ai-propose.swift [flags]

        --limit N            Stop after N candidates (default: all).
        --model NAME         Model name (default 'local-model' for LM Studio).
        --concurrency N      Parallel workers (default 4 — LLMs can throttle).
        --input PATH         Candidates file (default Scripts/candidates.json).
        --output PATH        Proposals file (default Scripts/proposals.json).

        Env:
          OPENAI_COMPAT_URL  LLM base URL (default http://localhost:1234/v1).
          OPENAI_API_KEY     Optional bearer token.
        """)
        exit(0)
    default:
        fputs("warn: unknown flag '\(args[i])'\n", stderr)
    }
    i += 1
}

func runProposer() async {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: inputPath)),
          let cf = try? JSONDecoder().decode(CandidatesFile.self, from: data) else {
        fputs("error: could not read \(inputPath)\n", stderr)
        exit(1)
    }
    let toProcess = Array(cf.candidates.prefix(limit))
    fputs("ai-propose: \(toProcess.count) candidates · model='\(model)' · endpoint='\(redactEndpoint(endpointBase))'\n", stderr)

    struct DraftJSON: Decodable {
        let suggestedOrigin: String
        let suggestedCategory: String
        let confidence: String
        let modelRationale: String?
        let alternatives: [ProposedAlt]
    }

    var results = [Proposal?](repeating: nil, count: toProcess.count)
    await withTaskGroup(of: (Int, Proposal?).self) { group in
        var inFlight = 0; var nextIdx = 0
        while nextIdx < toProcess.count || inFlight > 0 {
            while inFlight < concurrency && nextIdx < toProcess.count {
                let idx = nextIdx
                let cand = toProcess[idx]
                group.addTask {
                    let userMsg = "App: \"\(cand.displayName)\" (\(cand.bundleID))"
                    do {
                        let raw = try await chatComplete(
                            model: model, system: systemPrompt, user: userMsg,
                            timeout: 60
                        )
                        // Tolerant JSON: strip markdown fences if present.
                        var s = raw
                        if s.contains("```") {
                            s = s.replacingOccurrences(
                                of: #"(?m)^\s*```(?:json)?\s*$"#,
                                with: "", options: .regularExpression)
                            s = s.replacingOccurrences(
                                of: #"(?m)^\s*```\s*$"#,
                                with: "", options: .regularExpression)
                        }
                        guard let d = s.data(using: .utf8),
                              let draft = try? JSONDecoder().decode(DraftJSON.self, from: d) else {
                            fputs("warn: '\(cand.displayName)' — model output not JSON-parseable\n", stderr)
                            return (idx, nil)
                        }
                        let proposal = Proposal(
                            bundleID: cand.bundleID,
                            displayName: cand.displayName,
                            suggestedOrigin: draft.suggestedOrigin,
                            suggestedCategory: draft.suggestedCategory,
                            confidence: draft.confidence,
                            alternatives: draft.alternatives,
                            source: cand.source,
                            modelRationale: draft.modelRationale
                        )
                        return (idx, proposal)
                    } catch {
                        fputs("warn: '\(cand.displayName)' — \(error.localizedDescription)\n", stderr)
                        return (idx, nil)
                    }
                }
                inFlight += 1; nextIdx += 1
            }
            if let (idx, prop) = await group.next() {
                inFlight -= 1
                results[idx] = prop
                if (idx + 1) % 10 == 0 {
                    fputs("  … \(idx + 1) / \(toProcess.count)\n", stderr)
                }
            }
        }
    }

    let proposals = results.compactMap { $0 }
    let iso = ISO8601DateFormatter()
    let out = ProposalsFile(version: 1,
                            generatedAt: iso.string(from: Date()),
                            model: model,
                            proposals: proposals)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    do {
        let data = try encoder.encode(out)
        try data.write(to: URL(fileURLWithPath: outputPath))
        print("✓ drafted \(proposals.count) of \(toProcess.count) proposals → \(outputPath)")
        let highConf = proposals.filter { $0.confidence == "high" }.count
        let lowConf = proposals.filter { $0.confidence == "low" }.count
        print("   confidence: \(highConf) high · \(proposals.count - highConf - lowConf) medium · \(lowConf) low")
        print("")
        print("Next: review with `swift Scripts/merge-proposals.swift`.")
    } catch {
        fputs("error: \(error)\n", stderr)
        exit(2)
    }
}

let __done = DispatchSemaphore(value: 0)
Task {
    await runProposer()
    __done.signal()
}
__done.wait()
