#!/usr/bin/env swift
//
// generate-launch-keypair.swift — Ed25519 keypair generator for the
// 2026-06 Splynek direct-sale launch.  Produces two artifacts:
//
//   1. The PUBLIC key (base64-encoded raw 32 bytes) — printed to
//      stdout.  This goes into:
//         - Sources/SplynekCore/ProStubs.swift  (for `licence` kind)
//         - Resources/Info.plist as SUPublicEDKey  (for `sparkle` kind)
//
//   2. The PRIVATE key (base64-encoded raw 32 bytes) — written to a
//      file under `.secrets/` with rwx------ permissions.  This is
//      the key the maintainer puts into:
//         - Cloudflare Worker secret LICENSE_SIGNING_PRIVATE_KEY
//           (for `licence` kind)
//         - sign_update's local keychain — Sparkle's tool handles
//           this when run on the same Mac (for `sparkle` kind)
//
// Usage:
//   swift Scripts/generate-launch-keypair.swift licence
//   swift Scripts/generate-launch-keypair.swift sparkle
//
// The `.secrets/` directory is gitignored.  The private key file
// has a giant DO-NOT-COMMIT header + clear move-to-1Password
// instructions.  Maintainer responsibility:
//
//   1. Move the private key from `.secrets/<kind>-private.txt` to
//      1Password (or hardware key backup).
//   2. Wipe the local file: `rm .secrets/<kind>-private.txt`.
//   3. Paste the public key (from stdout) into the right file
//      (this script prints the canonical destination).
//
// See MAINTAINER-LAUNCH-CHECKLIST.md § B1 + B2.

import Foundation
import CryptoKit

guard CommandLine.arguments.count == 2,
      let kind = CommandLine.arguments.dropFirst().first,
      ["licence", "sparkle"].contains(kind) else {
    FileHandle.standardError.write(Data("""
        Usage: swift Scripts/generate-launch-keypair.swift {licence|sparkle}

          licence — for the .splynekkey signing key (Cloudflare Worker)
          sparkle — for the appcast.xml EdDSA signature

        """.utf8))
    exit(2)
}

let privateKey = Curve25519.Signing.PrivateKey()
let publicB64  = privateKey.publicKey.rawRepresentation.base64EncodedString()
let privateB64 = privateKey.rawRepresentation.base64EncodedString()

// Resolve the repo root + secrets dir.
let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0])
let scriptsDir = scriptPath.deletingLastPathComponent()
let repoRoot   = scriptsDir.deletingLastPathComponent()
let secretsDir = repoRoot.appendingPathComponent(".secrets", isDirectory: true)

try? FileManager.default.createDirectory(
    at: secretsDir,
    withIntermediateDirectories: true,
    attributes: [.posixPermissions: 0o700]
)

let outFile = secretsDir.appendingPathComponent("\(kind)-private.txt")

let warning = """
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║   PRIVATE KEY — DO NOT COMMIT — DO NOT SHARE                 ║
    ║                                                              ║
    ║   This file contains the Ed25519 private signing key for     ║
    ║   the Splynek launch.  If anyone else gets this key, they    ║
    ║   can mint counterfeit licence files / Sparkle updates.      ║
    ║                                                              ║
    ║   MAINTAINER ACTION REQUIRED:                                ║
    ║     1. Move the value below into 1Password under             ║
    ║          "Splynek Pro — \(kind == "licence" ? "Licence" : "Sparkle update") signing private key" ║
    ║     2. Wipe this file: rm .secrets/\(kind)-private.txt   ║
    ║     3. Verify the public key was pasted correctly (see       ║
    ║        the matching MAINTAINER-LAUNCH-CHECKLIST.md step).    ║
    ║                                                              ║
    ║   This kind of key:  \(kind == "licence" ? "LICENCE-SIGNING (.splynekkey envelope)" : "SPARKLE EdDSA (DMG appcast)              ") ║
    ║   Generated at:      \(ISO8601DateFormatter().string(from: Date())) ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝

    Base64 private key (32 raw bytes):

    \(privateB64)

    Matching public key (already printed to stdout, safe to paste):

    \(publicB64)

    """

try warning.write(to: outFile, atomically: true, encoding: .utf8)
try FileManager.default.setAttributes(
    [.posixPermissions: 0o600],
    ofItemAtPath: outFile.path
)

// stdout: ONLY the public key (so callers can pipe / capture).
print(publicB64)

// stderr: human-readable summary + paste destination.
let destination: String
switch kind {
case "licence":
    destination = "Sources/SplynekCore/ProStubs.swift — replace REPLACE_ME_WITH_LAUNCH_PUBLIC_KEY"
case "sparkle":
    destination = "Resources/Info.plist <key>SUPublicEDKey</key> — replace REPLACE_ME_WITH_SPARKLE_EDDSA_PUBLIC_KEY"
default:
    destination = "(unknown)"
}

FileHandle.standardError.write(Data("""

    ✓ Generated \(kind) keypair.
      • PUBLIC  → \(publicB64)
      • PRIVATE → \(outFile.path) (rwx------, gitignored)

      Next:
        1. Move the PRIVATE value from the file above into 1Password.
        2. Wipe the file: rm \(outFile.path)
        3. Paste the PUBLIC value into:
             \(destination)

    """.utf8))
