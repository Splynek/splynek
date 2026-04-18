import Foundation
import CryptoKit

/// Offline license validation for Splynek Pro.
///
/// A license key is the hex truncation of `HMAC-SHA256(email_payload,
/// SECRET)`, formatted as `SPLYNEK-XXXX-XXXX-XXXX-XXXX-XXXX`. The
/// entire validation loop runs offline — no server call — which keeps
/// the app usable without a network and dodges the "we took down
/// their licensing server and now the app is bricked" failure mode
/// that plagues subscription apps.
///
/// Threat model (honest):
/// - **Not DRM.** The secret is compiled into the binary. A determined
///   attacker can reverse-engineer it and generate their own keys.
///   For a $29 solo-dev Mac app that's accepted — most customers
///   pay, the few who crack are lost sales we wouldn't have had
///   anyway, and the cost of robust DRM (server-side receipt
///   validation + MAS StoreKit + code-injection defences) vastly
///   exceeds the recovered revenue.
/// - **Per-email keys.** One key = one email. Easy to email in a
///   Stripe success hook; easy to revoke (don't issue again on a
///   refund). Leaked keys are traceable to the buyer.
/// - **No concurrent-seat enforcement.** We don't phone home. A
///   buyer can reuse their key on their own Macs — which is what
///   the ToS permits anyway.
///
/// Production note: rotate `LicenseValidator.secret` once per pricing
/// change (i.e., bump the version line). Existing-customer keys
/// remain valid because a LicenseManager-level receipt file will be
/// added in a future release.
enum LicenseValidator {

    /// HMAC secret. Placeholder — **rotate this** before shipping to
    /// production. The public repo's secret is well-known by design
    /// (this is not security-critical, see threat model above).
    static let secret: [UInt8] = [
        0x53, 0x70, 0x6c, 0x79, 0x6e, 0x65, 0x6b, 0x2d,
        0x50, 0x72, 0x6f, 0x2d, 0x4c, 0x69, 0x63, 0x65,
        0x6e, 0x73, 0x65, 0x2d, 0x53, 0x65, 0x63, 0x72,
        0x65, 0x74, 0x2d, 0x76, 0x30, 0x2e, 0x34, 0x31,
    ]

    /// Deterministic key for `email`. Same input → same output
    /// → `Scripts/gen-license.py` can produce an identical string.
    static func issue(email: String) -> String {
        let normalized = normalize(email)
        let payload = Data("SPLYNEK-PRO-\(normalized)".utf8)
        let key = SymmetricKey(data: Data(secret))
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let hex = Data(mac).prefix(10).map { String(format: "%02X", $0) }.joined()
        // 20 hex chars → five 4-char groups: SPLYNEK-AAAA-BBBB-CCCC-DDDD-EEEE
        let groups: [String] = stride(from: 0, to: hex.count, by: 4).map { start in
            let s = hex.index(hex.startIndex, offsetBy: start)
            let e = hex.index(hex.startIndex, offsetBy: min(start + 4, hex.count))
            return String(hex[s..<e])
        }
        return (["SPLYNEK"] + groups).joined(separator: "-")
    }

    /// Constant-time comparison so a timing attack on a single user's
    /// local UserDefaults can't feasibly probe out the expected key.
    /// In practice a local attacker can read the key from disk
    /// directly; this is belt-and-braces.
    static func validate(email: String, key: String) -> Bool {
        let expected = issue(email: email)
        let provided = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let expectedBytes = Array(expected.utf8)
        let providedBytes = Array(provided.utf8)
        guard expectedBytes.count == providedBytes.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<expectedBytes.count {
            diff |= expectedBytes[i] ^ providedBytes[i]
        }
        return diff == 0
    }

    /// Normalize an email the same way at issue + validate time so a
    /// trailing newline from a copy-paste doesn't cause a rejection.
    static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Thin ObservableObject wrapper so views can react to license
/// changes. Owned by `SplynekViewModel`; gates dispatch through
/// `vm.license.isPro` at the call site.
///
/// Not marked `@MainActor` so the test harness (which runs tests
/// synchronously from `main.swift`, outside any actor) can
/// instantiate and poke it directly. The VM, which IS MainActor,
/// still sees the correct publish-on-main behaviour because all
/// its mutations happen on the main thread.
final class LicenseManager: ObservableObject {

    @Published private(set) var isPro: Bool = false
    @Published private(set) var licensedEmail: String?
    @Published var lastUnlockError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadPersisted()
    }

    /// Try to unlock with the supplied credentials. Returns true on
    /// success; populates `lastUnlockError` on failure so the UI can
    /// surface a specific reason.
    @discardableResult
    func unlock(email: String, key: String) -> Bool {
        let normalizedEmail = LicenseValidator.normalize(email)
        if normalizedEmail.isEmpty {
            lastUnlockError = "Enter the email you used to buy Splynek Pro."
            return false
        }
        guard LicenseValidator.validate(email: normalizedEmail, key: key) else {
            lastUnlockError = "That key doesn't match the email. Double-check for typos."
            return false
        }
        defaults.set(normalizedEmail, forKey: Self.emailKey)
        defaults.set(key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                     forKey: Self.keyKey)
        licensedEmail = normalizedEmail
        isPro = true
        lastUnlockError = nil
        return true
    }

    /// Wipe the stored credentials. Pro features lock back down on
    /// the next view render.
    func deactivate() {
        defaults.removeObject(forKey: Self.emailKey)
        defaults.removeObject(forKey: Self.keyKey)
        licensedEmail = nil
        isPro = false
        lastUnlockError = nil
    }

    private func loadPersisted() {
        guard let email = defaults.string(forKey: Self.emailKey),
              let key = defaults.string(forKey: Self.keyKey),
              LicenseValidator.validate(email: email, key: key)
        else { return }
        licensedEmail = email
        isPro = true
    }

    private static let emailKey = "splynekProEmail"
    private static let keyKey = "splynekProKey"
}
