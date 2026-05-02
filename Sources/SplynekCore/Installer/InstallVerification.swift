import Foundation
import CryptoKit

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// InstallVerification reads file bytes, computes SHA-256, and asks
// the OS (via GatekeeperVerify, which calls Apple's signed
// /usr/sbin/spctl + /usr/bin/codesign) what it thinks of the
// signature.  No code is executed against the verified file — we
// just inspect it.  A failed verification aborts the install
// pipeline; we never quarantine-bypass.
// =====================================================================

/// v1.8: hard-fail verification stage for the installer pipeline.
/// Two checks:
///
///   1. SHA-256 digest matches the spec's `expectedDigest` (if any).
///      Optional but strongly recommended — it's how we detect a
///      compromised mirror serving a different binary than the
///      publisher's checksum.
///   2. Gatekeeper accepts the binary (Developer ID + notarised, or
///      App Store-signed).  Required for unattended install — we
///      refuse to install anything Gatekeeper would block at launch.
///
/// Both checks are read-only.  Neither launches, executes, or
/// modifies the verified file.
enum InstallVerification {

    enum Verdict: Sendable {
        case ok
        case digestMismatch(expected: String, actual: String)
        case gatekeeperRejected(reason: String)
        case ioError(String)
    }

    /// Tagged hashing failure so we can carry it through `Result` —
    /// `Result.Failure` requires conformance to `Error`, which raw
    /// `String` doesn't have.
    struct HashError: Error, Sendable {
        let message: String
    }

    /// Run both checks against the file at `payload`.  Returns the
    /// first failing verdict, or `.ok` if everything passes.
    static func verify(
        payload: URL,
        expectedDigest: String?
    ) async -> Verdict {
        // Stage 1 — SHA-256 (if expected digest provided).
        if let expected = expectedDigest {
            switch sha256(of: payload) {
            case .success(let actual):
                let normExpected = expected.lowercased().replacingOccurrences(of: " ", with: "")
                let normActual = actual.lowercased()
                if normExpected != normActual {
                    return .digestMismatch(expected: normExpected, actual: normActual)
                }
            case .failure(let err):
                return .ioError(err.message)
            }
        }

        // Stage 2 — Gatekeeper.  This is async because spctl can
        // take a few seconds on a large notarised binary.
        let verdict = await GatekeeperVerify.evaluate(payload)
        switch verdict {
        case .accepted:
            return .ok
        case .rejected(let reason):
            return .gatekeeperRejected(reason: reason)
        case .unavailable(let reason):
            // spctl/codesign aren't available — be conservative and
            // refuse the install.  Better to ask the user to retry
            // than silently install an unverified binary.
            return .gatekeeperRejected(reason: "Gatekeeper unavailable: \(reason)")
        case .notApplicable, .pending:
            // For .pkg / .dmg / .zip we hand to a kind-specific verifier
            // before spctl; reaching .notApplicable here means the file
            // type wasn't checkable — accept and let the install handler
            // do its own validation (e.g. installer(8)'s own signature
            // check for .pkg).
            return .ok
        }
    }

    /// Compute hex SHA-256 of a file by streaming — never loads the
    /// whole file into memory.  Returns hex-encoded string on success.
    static func sha256(of url: URL) -> Result<String, HashError> {
        // Explicit existence check — `InputStream(url:)` returns a
        // valid stream for missing files on macOS (read just yields
        // 0 bytes), which would silently produce an "empty file"
        // hash.  We want the failure surfaced.
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(HashError(message: "File not found: \(url.path)"))
        }
        guard let stream = InputStream(url: url) else {
            return .failure(HashError(message: "Could not open file for hashing."))
        }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let bufSize = 64 * 1024
        var buf = [UInt8](repeating: 0, count: bufSize)
        while stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: bufSize)
            if n < 0 {
                return .failure(HashError(
                    message: "Read error: \(stream.streamError?.localizedDescription ?? "unknown")"
                ))
            }
            if n == 0 { break }
            hasher.update(data: Data(bytes: buf, count: n))
        }
        let digest = hasher.finalize()
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return .success(hex)
    }
}
