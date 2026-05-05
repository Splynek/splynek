#!/usr/bin/env swift
// Splynek File Witness — standalone receipt verifier.
//
// Usage:
//     swift Scripts/verify-splynek-receipt.swift <receipt.json>
//     swift Scripts/verify-splynek-receipt.swift <receipt.json> <file>
//
// First form verifies the receipt's INTERNAL consistency: the
// signature was produced by the device pubkey embedded in the
// receipt, over the canonical-JSON of the unsigned fields.
//
// Second form ALSO computes the SHA-256 of <file> and asserts it
// matches the receipt's `sha256` — i.e. the file you have on disk
// is the exact bytes the receipt attests to.
//
// Exit code 0 = valid, non-zero = failed (with a single-line message
// to stderr).  Suitable for shell scripting.
//
// No third-party deps; uses Foundation + CryptoKit.  Runs on any
// macOS 13+ with Swift toolchain installed.

import Foundation
import CryptoKit

// MARK: - Receipt model (mirrors DownloadReceipt schema 1)

struct VerifierReceipt: Codable {
    let splynek_receipt_schema: Int
    let url: String
    let sha256: String
    let size_bytes: Int64
    let finished_at: String
    let device_pubkey: String
    let signature: String
}

enum VerifyError: Error, CustomStringConvertible {
    case unsupportedSchema(Int)
    case invalidBase64
    case signatureMismatch
    case fileNotReadable(String)

    var description: String {
        switch self {
        case .unsupportedSchema(let v):
            return "Unsupported receipt schema v\(v) (this verifier supports v1)."
        case .invalidBase64:
            return "Receipt fields aren't valid base64 — file is corrupt."
        case .signatureMismatch:
            return "Signature does NOT verify against the receipt's pubkey."
        case .fileNotReadable(let p):
            return "Cannot read file: \(p)"
        }
    }
}

func usage() {
    fputs("""
    Usage:
      swift Scripts/verify-splynek-receipt.swift <receipt.json>
      swift Scripts/verify-splynek-receipt.swift <receipt.json> <file>

    First form: verify the receipt's signature is internally consistent.
    Second form: also verify the file's SHA-256 matches the receipt.

    """, stderr)
}

func loadReceipt(at path: String) throws -> VerifierReceipt {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let r = try JSONDecoder().decode(VerifierReceipt.self, from: data)
    guard r.splynek_receipt_schema == 1 else {
        throw VerifyError.unsupportedSchema(r.splynek_receipt_schema)
    }
    return r
}

func verifyInternalConsistency(_ r: VerifierReceipt) throws {
    guard let pubkeyData = Data(base64Encoded: r.device_pubkey),
          let sigData = Data(base64Encoded: r.signature)
    else {
        throw VerifyError.invalidBase64
    }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: pubkeyData)
    // Reconstruct the canonical-JSON of unsigned fields.  Must match
    // what `DownloadReceipt.canonicalUnsignedJSON` emits in the Swift
    // main app: sorted keys, no extra whitespace, no escaped slashes.
    let dict: [String: Any] = [
        "splynek_receipt_schema": r.splynek_receipt_schema,
        "url": r.url,
        "sha256": r.sha256,
        "size_bytes": NSNumber(value: r.size_bytes),
        "finished_at": r.finished_at,
        "device_pubkey": r.device_pubkey,
    ]
    let unsigned = try JSONSerialization.data(
        withJSONObject: dict,
        options: [.sortedKeys, .withoutEscapingSlashes]
    )
    guard key.isValidSignature(sigData, for: unsigned) else {
        throw VerifyError.signatureMismatch
    }
}

func sha256Hex(of path: String) throws -> String {
    let url = URL(fileURLWithPath: path)
    let h = FileHandle(forReadingAtPath: url.path)
    guard let h else { throw VerifyError.fileNotReadable(path) }
    defer { try? h.close() }
    var hasher = SHA256()
    let chunkSize = 1 << 20  // 1 MiB
    while autoreleasepool(invoking: { () -> Bool in
        let chunk = h.readData(ofLength: chunkSize)
        guard !chunk.isEmpty else { return false }
        hasher.update(data: chunk)
        return true
    }) {}
    let digest = hasher.finalize()
    return digest.map { String(format: "%02x", $0) }.joined()
}

// MARK: - Entry point

let args = CommandLine.arguments
guard args.count >= 2 else {
    usage()
    exit(2)
}
let receiptPath = args[1]
let fileToCheck: String? = args.count >= 3 ? args[2] : nil

do {
    let receipt = try loadReceipt(at: receiptPath)
    try verifyInternalConsistency(receipt)
    print("✓ Receipt signature valid.")
    print("  url:          \(receipt.url)")
    print("  sha256:       \(receipt.sha256)")
    print("  size_bytes:   \(receipt.size_bytes)")
    print("  finished_at:  \(receipt.finished_at)")
    print("  device_pubkey: \(receipt.device_pubkey.prefix(32))…")

    if let path = fileToCheck {
        let actualSha = try sha256Hex(of: path)
        guard actualSha == receipt.sha256.lowercased() else {
            fputs("✗ File hash MISMATCH.\n", stderr)
            fputs("  expected: \(receipt.sha256)\n", stderr)
            fputs("  actual:   \(actualSha)\n", stderr)
            exit(3)
        }
        print("✓ File hash matches receipt.")
    }
    exit(0)
} catch {
    fputs("✗ \(error)\n", stderr)
    exit(1)
}
