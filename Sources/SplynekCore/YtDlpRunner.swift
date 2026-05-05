import Foundation

/// Strategy Bet S3 (yt-dlp swallow) — dispatch wire-up.
///
/// Invokes a user-installed yt-dlp binary to fetch a URL that
/// Splynek's direct-HTTP engine wouldn't handle (YouTube / Twitch /
/// Instagram / TikTok / X / Vimeo / Bilibili / etc.) and records the
/// result in the standard download history.
///
/// Architecture:
/// - Pre-flight by `YtDlpProbe`: confirms yt-dlp is installed +
///   discovers its absolute path.
/// - Subprocess invocation via `Process` (DMG build only — MAS
///   sandbox blocks Process; the UI surfaces "yt-dlp dispatch
///   unavailable in Mac App Store build, use the DMG").
/// - Output template fixes the filename to a Splynek-safe form:
///   `<title>-<id>.<ext>` (no path components from yt-dlp's
///   defaults that could write outside the user's chosen directory).
/// - Progress is parsed from yt-dlp's `--newline` output ("[download]
///   N% of M.MB at S.SMB/s ETA T:T") via a streaming line reader.
/// - On completion, records the output file in DownloadHistory so
///   it shows up in the Histórico tab + Spotlight + (eventually)
///   gets a File Witness receipt minted for it.
///
/// Threat model: yt-dlp itself fetches network resources and parses
/// site-specific HTML/JSON.  Splynek treats yt-dlp's exit code +
/// final-output-file as the only trusted outputs; we don't parse
/// JSON metadata from yt-dlp into anything that can execute.  The
/// `--no-update`, `--no-call-home`, `--no-cache-dir` flags ensure
/// yt-dlp doesn't phone Mozilla / GitHub for self-updates inside
/// our process.
public enum YtDlpRunner {

    public enum DispatchError: Error, CustomStringConvertible {
        case notInstalled
        case sandboxed
        case invocationFailed(String)
        case nonZeroExit(Int32, stderrTail: String)
        case outputMissing

        public var description: String {
            switch self {
            case .notInstalled:
                return "yt-dlp is not installed.  Install with `brew install yt-dlp`."
            case .sandboxed:
                return "yt-dlp dispatch is unavailable in the sandboxed Mac App Store build.  Use the DMG build for streaming-site downloads."
            case .invocationFailed(let m):
                return "Couldn't launch yt-dlp: \(m)"
            case .nonZeroExit(let code, let tail):
                return "yt-dlp exited with code \(code).  Last stderr: \(tail.suffix(400))"
            case .outputMissing:
                return "yt-dlp reported success but the output file isn't where expected."
            }
        }
    }

    /// Result of a successful dispatch.  `outputFile` is the actual
    /// on-disk path yt-dlp wrote (yt-dlp may shave the extension on
    /// us depending on the format; we discover it from the directory
    /// listing rather than trust the template).
    public struct DispatchResult: Sendable {
        public let outputFile: URL
        public let bytesDownloaded: Int64
        public let durationSeconds: Double
        public let title: String?
    }

    /// Run yt-dlp synchronously (well, async-wrapped — the subprocess
    /// itself is sync).  `state` MUST be `.installed` (caller
    /// responsibility — checked here as a defensive fallback).
    ///
    /// `outputDirectory` is where the file will land.  yt-dlp's `-o`
    /// template uses `%(title)s-%(id)s.%(ext)s` so filenames are
    /// stable + collision-resistant.
    ///
    /// `onProgress` fires on every parsed `[download] N%` line.  It's
    /// `@Sendable` because the line reader runs on a background queue.
    public static func dispatch(
        url: URL,
        outputDirectory: URL,
        state: YtDlpProbe.State,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async -> Result<DispatchResult, DispatchError> {
        guard case .installed(_, let path) = state else {
            return .failure(.notInstalled)
        }
        // Defensive sandbox check — Process inside MAS sandbox raises
        // an error on .run(); detect early so we surface a clear message.
        if !YtDlpProbe.canRunProcess { return .failure(.sandboxed) }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        let template = outputDirectory.appendingPathComponent(
            "%(title)s-%(id)s.%(ext)s"
        ).path
        p.arguments = [
            "--no-update",
            "--no-call-home",
            "--no-cache-dir",
            "--no-playlist",
            "--newline",                  // forces line-buffered progress
            "-o", template,
            "--print", "after_move:filepath",
            url.absoluteString,
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        p.standardOutput = stdout
        p.standardError = stderr

        // Stream stdout line-by-line so we can parse progress without
        // waiting for the process to finish.
        var lastBytes: Int64 = 0
        var titleHint: String?
        var capturedFilepath: String?
        let stdoutHandle = stdout.fileHandleForReading
        let progressTask = Task.detached(priority: .utility) {
            var buffer = Data()
            while let chunk = try? stdoutHandle.read(upToCount: 4096), !chunk.isEmpty {
                buffer.append(chunk)
                while let nlRange = buffer.firstRange(of: Data([0x0A])) {
                    let lineData = buffer.prefix(upTo: nlRange.lowerBound)
                    buffer.removeSubrange(buffer.startIndex..<nlRange.upperBound)
                    let line = String(decoding: lineData, as: UTF8.self)
                    if let pct = parseProgressLine(line) {
                        onProgress?(pct)
                    }
                    if let bytes = parseDownloadedBytes(line) {
                        lastBytes = bytes
                    }
                    if let t = parseTitle(line) {
                        titleHint = t
                    }
                    // Captured "after_move:filepath" → the absolute path
                    // yt-dlp wrote.  Prefer this over guessing from template.
                    if line.hasPrefix("/") && line.count < 1024,
                       FileManager.default.fileExists(atPath: line) {
                        capturedFilepath = line
                    }
                }
            }
        }

        let started = Date()
        do {
            try p.run()
        } catch {
            return .failure(.invocationFailed(error.localizedDescription))
        }
        p.waitUntilExit()
        progressTask.cancel()

        let dur = Date().timeIntervalSince(started)
        guard p.terminationStatus == 0 else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let tail = String(decoding: errData, as: UTF8.self)
            return .failure(.nonZeroExit(p.terminationStatus, stderrTail: tail))
        }
        // Resolve the output file.  Prefer captured `filepath` from
        // --print.  Fall back to listing the output dir for files
        // newer than start-time.
        let outURL: URL
        if let captured = capturedFilepath {
            outURL = URL(fileURLWithPath: captured)
        } else if let resolved = mostRecentFile(in: outputDirectory, after: started) {
            outURL = resolved
        } else {
            return .failure(.outputMissing)
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: outURL.path)
        let bytes = (attrs?[.size] as? NSNumber)?.int64Value ?? lastBytes
        return .success(.init(
            outputFile: outURL,
            bytesDownloaded: bytes,
            durationSeconds: dur,
            title: titleHint
        ))
    }

    // MARK: - Parsers (testable)

    /// Parse "[download]  47.3% of   12.34MiB at  2.34MiB/s ETA 00:05"
    /// → 0.473.  Returns nil if the line isn't a progress line.
    static func parseProgressLine(_ line: String) -> Double? {
        // Looking for "[download]" prefix + a percent token.
        guard line.hasPrefix("[download]") else { return nil }
        // Find "<num>%" anywhere in the line.
        var inNum = false
        var numStart: String.Index?
        for idx in line.indices {
            let c = line[idx]
            if c.isNumber || c == "." {
                if !inNum { numStart = idx; inNum = true }
            } else if c == "%" {
                guard let s = numStart else { continue }
                let token = line[s..<idx]
                if let v = Double(token), v >= 0, v <= 100 { return v / 100.0 }
                inNum = false
                numStart = nil
            } else {
                inNum = false
                numStart = nil
            }
        }
        return nil
    }

    /// Parse the bytes-downloaded value (the "of M.MMB" part) from a
    /// progress line.  Used to record final-bytes when yt-dlp doesn't
    /// emit a clean "Destination" line we can stat.
    static func parseDownloadedBytes(_ line: String) -> Int64? {
        guard line.hasPrefix("[download]") else { return nil }
        // Match "of <num><unit>" where unit is KiB/MiB/GiB/B/etc.
        let pattern = #"of\s+([\d.]+)(B|KiB|MiB|GiB|TiB)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        guard let m = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)),
              m.numberOfRanges >= 3 else { return nil }
        let val = Double(nsLine.substring(with: m.range(at: 1))) ?? 0
        let unit = nsLine.substring(with: m.range(at: 2))
        let mult: Double
        switch unit {
        case "B":   mult = 1
        case "KiB": mult = 1024
        case "MiB": mult = 1024 * 1024
        case "GiB": mult = 1024 * 1024 * 1024
        case "TiB": mult = 1024 * 1024 * 1024 * 1024
        default:    return nil
        }
        return Int64(val * mult)
    }

    /// Look for `[<extractor>] <id>: <title>` and pull the title.
    /// yt-dlp emits this once per video at the start.
    static func parseTitle(_ line: String) -> String? {
        // "[youtube] dQw4w9WgXcQ: Rick Astley - Never Gonna Give You Up..."
        guard line.hasPrefix("[") else { return nil }
        guard let colon = line.range(of: ": ") else { return nil }
        let after = line[colon.upperBound...]
        let trimmed = after.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count < 512 else { return nil }
        // Reject obvious progress lines (they have a percent sign).
        if trimmed.contains("%") { return nil }
        return trimmed
    }

    /// Last-resort: find the most-recently-modified file in `dir`
    /// that was modified after `after`.  Used when yt-dlp's
    /// `--print after_move:filepath` doesn't emit (rare).
    static func mostRecentFile(in dir: URL, after: Date) -> URL? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }
        return entries
            .compactMap { url -> (URL, Date)? in
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let mod = attrs?[.modificationDate] as? Date ?? .distantPast
                return mod >= after ? (url, mod) : nil
            }
            .max(by: { $0.1 < $1.1 })?.0
    }
}
