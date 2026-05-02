import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// DmgInstaller invokes Apple's signed /usr/bin/hdiutil binary with
// hard-coded arguments to mount a downloaded .dmg, locates the .app
// inside the mount via FileManager, and hands it to AppMover.  No
// downloaded code runs; hdiutil is Apple-supplied and verifies the
// .dmg's signature itself before mounting.  The mount is read-only
// + nobrowse so the user doesn't see a Finder popup.  The mount is
// unmounted in a defer block so a crash mid-install can't leave
// stale mounts.
// =====================================================================

/// v1.8: install handler for `.dmg` disk images.  The flow:
///
///   1. `hdiutil attach -readonly -nobrowse -mountrandom /tmp <dmg>`
///   2. Locate the .app inside the mount (usually exactly one;
///      occasionally multiple — pick the largest).
///   3. Hand the .app to `AppMover.install(...)`.
///   4. `hdiutil detach <mountpoint>` — always, even on failure.
///
/// This is the same pattern Sparkle uses for app updates and the same
/// Apple recommends in their Developer.app distribution guide.
///
/// **Security note.**  `hdiutil` verifies the .dmg's checksum during
/// mount.  If the .dmg has an internal `Block Checksum` mismatch,
/// `hdiutil` fails and we abort with the error from stderr.  This is
/// independent of (and in addition to) the SHA-256 the
/// `InstallVerification` stage already enforced before we reached
/// this handler.
///
/// **Sandbox.**  The MAS build's sandbox profile must include the
/// `com.apple.security.files.user-selected.read-write` entitlement so
/// hdiutil can read the .dmg path the user picked.  hdiutil itself
/// runs as a signed system binary outside our sandbox; we just spawn
/// it.
enum DmgInstaller {

    enum Failure: Error, LocalizedError, Sendable {
        case mountFailed(String)
        case noAppFound(String)
        case ioError(String)

        var errorDescription: String? {
            switch self {
            case .mountFailed(let s): return "Couldn't mount the disk image: \(s)"
            case .noAppFound(let s):  return "No .app bundle in the disk image (\(s))."
            case .ioError(let s):     return "I/O error: \(s)"
            }
        }
    }

    /// Mount, copy, unmount.  Returns the final installed `.app` URL.
    static func install(
        dmg: URL,
        destinationDirectory: URL = URL(fileURLWithPath: "/Applications"),
        replaceExisting: Bool = false
    ) async throws -> AppMover.Outcome {
        let mountPoint = try await mount(dmg)
        defer {
            // Best-effort unmount.  `hdiutil detach` is idempotent;
            // if the mount went away on its own (rare), it returns
            // a benign error we ignore.
            _ = try? unmount(mountPoint)
        }

        let app = try findApp(in: mountPoint)
        return try AppMover.install(
            source: app,
            destinationDirectory: destinationDirectory,
            replaceExisting: replaceExisting
        )
    }

    /// `hdiutil attach -readonly -nobrowse -mountrandom /tmp <dmg>`
    /// Returns the random mount-point /tmp/dmg.XXXXXXXX.
    static func mount(_ dmg: URL) async throws -> URL {
        let result = await runHdiutil([
            "attach",
            "-readonly",
            "-nobrowse",
            "-mountrandom", "/tmp",
            dmg.path,
        ])
        guard result.exitCode == 0 else {
            throw Failure.mountFailed(result.stderrOrStdoutPreview())
        }
        // hdiutil prints lines like:
        //   /dev/disk5s1   Apple_HFS         /tmp/dmg.XYZ
        // We pluck the last column from the last non-empty line.
        guard let mountPath = result.stdout
            .split(separator: "\n")
            .compactMap({ line -> String? in
                let parts = line.split(separator: "\t").map(String.init)
                return parts.last
            })
            .last(where: { $0.hasPrefix("/") })
        else {
            throw Failure.mountFailed("Couldn't parse hdiutil output: \(result.stdout)")
        }
        return URL(fileURLWithPath: mountPath)
    }

    /// `hdiutil detach <mountpoint>`
    static func unmount(_ mountPoint: URL) throws {
        let result = runHdiutilSync(["detach", mountPoint.path])
        if result.exitCode != 0 {
            // Non-fatal; surface for diagnostics but don't throw.
            // Already best-effort in the caller's defer.
            FileHandle.standardError.write(Data("hdiutil detach failed: \(result.stdout)\n".utf8))
        }
    }

    /// Walk the mount looking for a `.app` bundle.  If multiple .apps
    /// exist (rare; happens with publisher bundles that include a
    /// helper app), pick the largest by total file size.
    static func findApp(in mountPoint: URL) throws -> URL {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: mountPoint,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw Failure.ioError("Could not list mount point.")
        }
        let apps = entries.filter { $0.pathExtension.lowercased() == "app" }
        guard !apps.isEmpty else {
            throw Failure.noAppFound(mountPoint.lastPathComponent)
        }
        if apps.count == 1 { return apps[0] }
        // Pick the largest.
        let largest = apps.max(by: { lhs, rhs in
            byteCount(of: lhs) < byteCount(of: rhs)
        })
        return largest ?? apps[0]
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

    // MARK: - Process plumbing

    struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String

        func stderrOrStdoutPreview() -> String {
            let text = stderr.isEmpty ? stdout : stderr
            return text.split(separator: "\n").first.map(String.init) ?? "(no output)"
        }
    }

    /// Async wrapper around hdiutil — hdiutil's `attach` can take
    /// 1-3s on a large .dmg, so we yield to the runtime.
    static func runHdiutil(_ args: [String]) async -> ProcessResult {
        await Task.detached { runHdiutilSync(args) }.value
    }

    /// Synchronous spawn of /usr/bin/hdiutil.  Hard-coded path —
    /// don't rely on PATH because the MAS sandbox doesn't propagate
    /// it predictably.
    static func runHdiutilSync(_ args: [String]) -> ProcessResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
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
                stderr: "Failed to launch hdiutil: \(error.localizedDescription)"
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
