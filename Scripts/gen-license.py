#!/usr/bin/env python3
"""Issue a Splynek Pro license key for an email address.

The key format + HMAC secret mirror `LicenseValidator.issue` in
`Sources/SplynekCore/LicenseManager.swift`. Matching this script
against the Swift implementation is test coverage in both directions
— if either drifts, `LicenseValidatorTests` fails.

Usage:
    python3 Scripts/gen-license.py user@example.com
    # → SPLYNEK-AAAA-BBBB-CCCC-DDDD-EEEE

In production, this script (or its Swift equivalent) runs in the
Stripe-success webhook on the server that issued the $29 purchase;
the resulting key is emailed to the buyer via Postmark/Resend.
"""
import hashlib
import hmac
import sys

# Mirror of LicenseValidator.secret. Rotate both here and in Swift
# on each pricing-change release.
SECRET = bytes([
    0x53, 0x70, 0x6c, 0x79, 0x6e, 0x65, 0x6b, 0x2d,
    0x50, 0x72, 0x6f, 0x2d, 0x4c, 0x69, 0x63, 0x65,
    0x6e, 0x73, 0x65, 0x2d, 0x53, 0x65, 0x63, 0x72,
    0x65, 0x74, 0x2d, 0x76, 0x30, 0x2e, 0x34, 0x31,
])


def issue(email: str) -> str:
    normalized = email.strip().lower()
    payload = f"SPLYNEK-PRO-{normalized}".encode("utf-8")
    mac = hmac.new(SECRET, payload, hashlib.sha256).digest()
    hex20 = mac[:10].hex().upper()
    groups = [hex20[i:i + 4] for i in range(0, len(hex20), 4)]
    return "SPLYNEK-" + "-".join(groups)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: gen-license.py <email>", file=sys.stderr)
        return 2
    print(issue(sys.argv[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
