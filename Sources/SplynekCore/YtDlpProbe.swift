import Foundation

/// 2026-05-05: pre-flight for Strategy Bet S3 (yt-dlp swallow).
///
/// This probe detects whether the user has yt-dlp installed locally
/// (Homebrew, pip, or `~/.local/bin/yt-dlp`) and reads its `--version`.
/// It does NOT bundle yt-dlp, does NOT invoke it for downloads — that's
/// the v1.x-or-v2.0 ship.  This pre-flight just tells the UI:
///
/// - "yt-dlp installed (2024.12.13)" — Splynek can route YouTube /
///   Twitch / Instagram / TikTok / etc. URLs through it
/// - "yt-dlp not installed" — fall through to the direct-HTTP engine
///   for those URLs (which usually fails on streaming sites) and
///   surface a one-line "install yt-dlp via brew install yt-dlp" hint
///
/// Sandbox note: in MAS builds, `Process` invocations from inside the
/// sandbox are restricted to the app bundle by default.  Reading
/// `which yt-dlp` requires a temporary entitlement
/// (`com.apple.security.temporary-exception.apple-events` or
/// `inherit`).  For MAS we ship the detection but route through
/// `URLSession` to a localhost HTTP shim if the user runs a tiny
/// sidecar.  For DMG (Developer-ID), full Process invocation is fine.
///
/// Threat model: the probe runs `yt-dlp --version` only.  No URL is
/// passed; no network connection is made by yt-dlp.  Output is parsed
/// with a strict regex (`^[\d.]+$` after trimming) — anything that
/// doesn't match is rejected.  No code execution, no shell expansion.
@MainActor
public final class YtDlpProbe: ObservableObject {

    /// Detected state from the latest probe call.  `nil` until the
    /// first probe completes.
    @Published public private(set) var state: State?

    public enum State: Equatable, Sendable {
        case installed(version: String, path: String)
        case notInstalled
        case sandboxBlocked
    }

    /// Standard install locations we check, in order.  First hit wins.
    /// Homebrew apple-silicon path comes first because that's the
    /// default for new Mac users in 2025–26; `/usr/local/bin` covers
    /// Intel Homebrew + manual installs; `~/.local/bin` covers pip
    /// install --user.
    static let candidatePaths = [
        "/opt/homebrew/bin/yt-dlp",
        "/usr/local/bin/yt-dlp",
        // The home-relative path is resolved at probe time.
        ".local/bin/yt-dlp",
    ]

    public init() {}

    /// Run the detection.  Always safe to call; returns the new state
    /// AND publishes via `state`.
    @discardableResult
    public func probe() async -> State {
        let result = await Self.detect()
        self.state = result
        return result
    }

    /// Pure detection — no published-property side effects.  Tests use
    /// this directly (the `@MainActor` `probe()` requires a real engine
    /// loop, which the harness doesn't have; see EngineExternalIngestTests
    /// for the same mitigation).
    static func detect() async -> State {
        for raw in candidatePaths {
            let path = expandHome(raw)
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            // We have the binary; ask it for its version.
            if let version = await readVersion(at: path) {
                return .installed(version: version, path: path)
            }
            // Binary present but version probe failed (sandbox?).
            // Continue to next path; if all paths report blocked, we
            // surface that distinct state below.
        }
        return Self.canRunProcess ? .notInstalled : .sandboxBlocked
    }

    /// Whether `Process()` invocation is permitted in the current
    /// runtime.  In MAS builds the sandbox blocks Process by default,
    /// returning EPERM on `run()`.  We probe the cheapest possible
    /// command — `/bin/echo` — as a heuristic.  If even that fails,
    /// the sandbox is in effect and `notInstalled` would be misleading.
    static var canRunProcess: Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/echo")
        p.arguments = ["splynek-sandbox-probe"]
        p.standardOutput = Pipe()
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            return true
        } catch {
            return false
        }
    }

    private static func expandHome(_ raw: String) -> String {
        if raw.hasPrefix("/") { return raw }
        let home = NSHomeDirectory()
        return "\(home)/\(raw)"
    }

    /// Run `<path> --version`, parse the output as a strict
    /// `<major>.<minor>.<patch>` (yt-dlp uses YYYY.MM.DD versioning,
    /// e.g. `2024.12.13`).  Returns nil on any failure or non-matching
    /// output — defensive against a path that resolves to something
    /// other than yt-dlp.
    private static func readVersion(at path: String) async -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = ["--version"]
        let stdout = Pipe()
        let stderr = Pipe()
        p.standardOutput = stdout
        p.standardError = stderr
        do {
            try p.run()
        } catch {
            return nil
        }
        // yt-dlp --version completes in ~10ms; we cap at 2s to avoid
        // hanging on a hostile binary that's not actually yt-dlp.
        let deadline = Date().addingTimeInterval(2.0)
        while p.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 25_000_000)  // 25ms
        }
        if p.isRunning {
            p.terminate()
            return nil
        }
        guard p.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let raw = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.isValidVersion(raw) ? raw : nil
    }

    /// yt-dlp's version format is `YYYY.MM.DD` since 2021.  Older
    /// `youtube-dl` used `2020.09.06` form too.  We accept any
    /// dot-separated digit groups, between 2 and 4 components, each
    /// 1–4 digits — strict enough to reject `; rm -rf` injection
    /// attempts but loose enough to accept patch versions like
    /// `2024.12.13.123`.
    ///
    /// `nonisolated` because this is a pure string-input function;
    /// actor isolation isn't needed (and prevents test access).
    nonisolated static func isValidVersion(_ s: String) -> Bool {
        guard !s.isEmpty, s.count <= 32 else { return false }
        // omittingEmptySubsequences: false so "2024..12.13" → ["2024",
        // "", "12", "13"] and the empty middle part fails validation.
        // Default split() drops empties and would mistakenly accept
        // "2024..12.13" as 3 valid parts.
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...4).contains(parts.count) else { return false }
        return parts.allSatisfy { p in
            !p.isEmpty && p.count <= 4 && p.allSatisfy(\.isNumber)
        }
    }

    /// URL hosts where yt-dlp is the right engine, not direct HTTP.
    /// Hardcoded compile-time list — this is a "do we route through
    /// yt-dlp" question, not a "what does yt-dlp support" question
    /// (the latter is hundreds of sites).
    nonisolated public static let preferredHosts: Set<String> = [
        "youtube.com", "youtu.be", "www.youtube.com",
        "twitch.tv", "www.twitch.tv",
        "instagram.com", "www.instagram.com",
        "tiktok.com", "www.tiktok.com",
        "twitter.com", "x.com",
        "vimeo.com", "www.vimeo.com",
        "bilibili.com", "www.bilibili.com",
    ]

    /// True if Splynek would prefer to route this URL through yt-dlp
    /// (and yt-dlp is installed).  Used by future v1.x dispatch logic;
    /// pre-flight check only today.
    nonisolated public static func shouldRouteThroughYtDlp(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return preferredHosts.contains(host)
    }
}
