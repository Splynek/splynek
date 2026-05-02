import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// ZipInstaller spawns Apple's signed /usr/bin/ditto with hard-coded
// arguments to extract a .zip archive into a temporary directory.
// The extracted contents are then handed to AppMover, which copies
// the .app bundle into the destination.  No code execution; ditto
// is signed system tooling, the .app payload is not run, and we
// auto-clean the staging directory after handoff.
// =====================================================================

/// v1.8.1: install handler for `.zip` / `.appArchive` payloads — the
/// pattern Sparkle uses for app-update zips and Apple uses for some
/// dev-tool downloads.
///
/// The flow:
///   1. Stage = /tmp/splynek-install-zip-{UUID}/
///   2. /usr/bin/ditto -x -k <archive>.zip <stage>
///   3. Walk <stage> for the .app bundle (handles archives that
///      wrap the .app in a sub-directory).
///   4. Hand the .app to AppMover.install(...).
///   5. Always remove the stage dir on exit.
///
/// Why ditto and not Foundation's NSData / NSFileManager unzip?
/// Two reasons:
///   1. ditto preserves resource forks, extended attributes, and
///      the codesign quarantine bits.  Apple recommends it for any
///      .app extraction.  Native Foundation paths drop xattrs.
///   2. ditto is signed system tooling.  Going through it keeps
///      the trust chain cleanly outside our process.
enum ZipInstaller {

    enum Failure: Error, LocalizedError, Sendable {
        case extractFailed(String)
        case noAppFound(String)
        case ioError(String)

        var errorDescription: String? {
            switch self {
            case .extractFailed(let s): return "Couldn't extract the archive: \(s)"
            case .noAppFound(let s):    return "No .app bundle in the archive (\(s))."
            case .ioError(let s):       return "I/O error: \(s)"
            }
        }
    }

    /// Extract the archive, locate the .app inside, install it.
    /// Returns the AppMover.Outcome on success.
    static func install(
        archive: URL,
        destinationDirectory: URL = URL(fileURLWithPath: "/Applications"),
        replaceExisting: Bool = false
    ) async throws -> AppMover.Outcome {
        let stage = stagingDirectory()
        defer {
            // Best-effort cleanup.  Even if AppMover.install threw,
            // we don't want a stale /tmp dir polluting subsequent runs.
            try? FileManager.default.removeItem(at: stage)
        }
        do {
            try FileManager.default.createDirectory(
                at: stage,
                withIntermediateDirectories: true
            )
        } catch {
            throw Failure.ioError("Couldn't create staging directory: \(error.localizedDescription)")
        }

        let result = await runDitto(["-x", "-k", archive.path, stage.path])
        guard result.exitCode == 0 else {
            throw Failure.extractFailed(result.stderr.isEmpty ? result.stdout : result.stderr)
        }

        let app = try findApp(in: stage)
        return try AppMover.install(
            source: app,
            destinationDirectory: destinationDirectory,
            replaceExisting: replaceExisting
        )
    }

    /// Walk the staging directory looking for the first `.app`
    /// bundle.  Handles both flat archives (`Foo.app/`) and nested
    /// archives (`Foo/Foo.app/`).  Returns the largest .app when
    /// multiple exist (rare — same logic as DmgInstaller).
    static func findApp(in stage: URL) throws -> URL {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: stage,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw Failure.ioError("Could not enumerate staging directory.")
        }

        var apps: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "app" {
                apps.append(url)
                // Don't descend into the .app bundle.
                enumerator.skipDescendants()
            }
        }

        guard !apps.isEmpty else {
            throw Failure.noAppFound(archive(stage))
        }
        if apps.count == 1 { return apps[0] }
        // Pick the largest (matches DmgInstaller behaviour).
        return apps.max(by: { byteCount(of: $0) < byteCount(of: $1) }) ?? apps[0]
    }

    private static func archive(_ url: URL) -> String {
        url.lastPathComponent  // for diagnostics only
    }

    private static func byteCount(of url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        var total: Int64 = 0
        for case let u as URL in enumerator {
            let v = try? u.resourceValues(forKeys: [.totalFileSizeKey])
            total += Int64(v?.totalFileSize ?? 0)
        }
        return total
    }

    static func stagingDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("splynek-install-zip-\(UUID().uuidString)")
    }

    // MARK: - Process plumbing

    struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    static func runDitto(_ args: [String]) async -> ProcessResult {
        await Task.detached { runDittoSync(args) }.value
    }

    static func runDittoSync(_ args: [String]) -> ProcessResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return ProcessResult(
                exitCode: -1,
                stdout: "",
                stderr: "Failed to launch ditto: \(error.localizedDescription)"
            )
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return ProcessResult(
            exitCode: proc.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
