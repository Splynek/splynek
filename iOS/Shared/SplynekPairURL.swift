// Copyright © 2026 Splynek. MIT.
//
// SplynekPairURL — the canonical pairing URL format used in QR codes.
//
//   splynek://pair?host=<host>&port=<port>&token=<token>&name=<displayName>
//
// The Mac generates this string + encodes it as a QR via Core Image's
// CIQRCodeGenerator (no third-party deps).  iOS scans QR via
// AVFoundation, parses through `decode(from:)` here, and pre-fills the
// PairingSheet fields.
//
// Token note: yes, the token rides in plaintext through a QR code that
// could in principle be photographed off-screen.  This is a deliberate
// scope choice — Splynek's threat model assumes you trust your local
// network (the LAN tokens are per-installation and rotate when the
// user resets them in Settings → Sharing).  The QR content is no more
// sensitive than what's already visible to anyone who can see the
// Mac's screen during pairing.

import Foundation

public enum SplynekPairURL {

    public struct Components: Equatable, Hashable, Sendable {
        public let host: String
        public let port: Int
        public let token: String
        /// Optional friendly name for the Mac.  iOS pairing sheet
        /// pre-fills this if present; falls back to "My Mac" otherwise.
        public let name: String?

        public init(host: String, port: Int, token: String, name: String?) {
            self.host = host
            self.port = port
            self.token = token
            self.name = name
        }
    }

    /// Encode → string.  Mac side calls this, then renders the
    /// returned string as a QR code.
    public static func encode(_ c: Components) -> String {
        var comps = URLComponents()
        comps.scheme = "splynek"
        comps.host = "pair"
        var qs: [URLQueryItem] = [
            URLQueryItem(name: "host",  value: c.host),
            URLQueryItem(name: "port",  value: String(c.port)),
            URLQueryItem(name: "token", value: c.token),
        ]
        if let n = c.name, !n.isEmpty {
            qs.append(URLQueryItem(name: "name", value: n))
        }
        comps.queryItems = qs
        // URLComponents emits "splynek://pair?..."; pure-string
        // fallback if something pathological happens with the
        // host name (it can't, given we control all 3 fields, but
        // defensive).
        return comps.url?.absoluteString ?? "splynek://pair"
    }

    /// Parse a candidate string from a QR scan.  Returns nil when:
    ///   - scheme is not "splynek"
    ///   - host is not "pair"
    ///   - any of host / port / token query-items are missing
    ///   - port is not a positive integer
    public static func decode(from raw: String) -> Components? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "splynek",
              url.host?.lowercased() == "pair",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems
        else { return nil }
        let dict = Dictionary(uniqueKeysWithValues:
            items.map { ($0.name.lowercased(), $0.value ?? "") })
        guard let host = dict["host"], !host.isEmpty,
              let portStr = dict["port"], let port = Int(portStr), port > 0,
              let token = dict["token"], !token.isEmpty
        else { return nil }
        let name = dict["name"]?.isEmpty == false ? dict["name"] : nil
        return Components(host: host, port: port, token: token, name: name)
    }
}
