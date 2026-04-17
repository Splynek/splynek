import Foundation
@testable import SplynekCore

/// Load-bearing claim: Bencode codec handles every primitive in BEP 3.
/// Breaking the decoder silently corrupts torrent files; breaking the
/// encoder breaks v0.9 magnet fetches and the info-hash computation
/// downstream.
enum BencodeTests {

    static func run() {
        TestHarness.suite("Bencode") {

            TestHarness.test("Round-trip: integer") {
                for n: Int64 in [0, 1, -1, 42, -42, Int64.max, Int64.min] {
                    let encoded = Bencode.encode(.integer(n))
                    let decoded = try Bencode.decode(encoded)
                    guard case .integer(let m) = decoded else {
                        throw Expectation(message: "not an integer", file: #file, line: #line)
                    }
                    try expectEqual(m, n, "integer round-trip \(n)")
                }
            }

            TestHarness.test("Round-trip: byte string") {
                let inputs: [Data] = [
                    Data(),
                    Data("hello".utf8),
                    Data([0x00, 0x01, 0xFF, 0xAB, 0xCD]),
                    Data(repeating: 0x42, count: 200)
                ]
                for input in inputs {
                    let encoded = Bencode.encode(.bytes(input))
                    let decoded = try Bencode.decode(encoded)
                    guard case .bytes(let out) = decoded else {
                        throw Expectation(message: "not bytes", file: #file, line: #line)
                    }
                    try expectEqual(out, input, "bytes round-trip len=\(input.count)")
                }
            }

            TestHarness.test("Round-trip: list + dict") {
                let v: Bencode.Value = .dict([
                    Data("a".utf8): .integer(7),
                    Data("ls".utf8): .list([
                        .bytes(Data("x".utf8)),
                        .integer(-2)
                    ])
                ])
                let encoded = Bencode.encode(v)
                let decoded = try Bencode.decode(encoded)
                try expect(decoded == v, "decoded != original")
            }

            TestHarness.test("Integer wire format matches BEP 3 literal") {
                // BEP 3: integers are `i<decimal>e`.
                let encoded = Bencode.encode(.integer(3))
                try expectEqual(encoded, Data("i3e".utf8))
            }

            TestHarness.test("Byte-string wire format matches BEP 3 literal") {
                // BEP 3: byte strings are `<length>:<bytes>`.
                let encoded = Bencode.encode(.bytes(Data("cow".utf8)))
                try expectEqual(encoded, Data("3:cow".utf8))
            }

            TestHarness.test("Dictionary keys are lexicographically sorted") {
                // BEP 3 mandates sorted keys. Encoder must enforce it.
                let v: Bencode.Value = .dict([
                    Data("b".utf8): .integer(2),
                    Data("a".utf8): .integer(1)
                ])
                let encoded = Bencode.encode(v)
                // "a" (0x61) sorts before "b" (0x62).
                try expectEqual(encoded, Data("d1:ai1e1:bi2ee".utf8))
            }

            TestHarness.test("Decoder rejects trailing garbage") {
                // A valid bencode value followed by junk should fail at
                // the top level — we must refuse ambiguous inputs.
                let bytes = Data("i3egarbage".utf8)
                do {
                    _ = try Bencode.decode(bytes)
                    throw Expectation(message: "expected decode to throw", file: #file, line: #line)
                } catch is Bencode.DecodeError {
                    // ok
                }
            }

            TestHarness.test("decodeWithInfoRange returns info-dict byte range") {
                // Synthesize a minimal "torrent root" dict and verify the
                // returned range exactly spans the info value's bytes.
                let info: Bencode.Value = .dict([
                    Data("name".utf8): .bytes(Data("x".utf8)),
                    Data("piece length".utf8): .integer(16384)
                ])
                let root: Bencode.Value = .dict([
                    Data("info".utf8): info,
                    Data("announce".utf8): .bytes(Data("http://t/".utf8))
                ])
                let outer = Bencode.encode(root)
                let (_, range) = try Bencode.decodeWithInfoRange(outer)
                guard let r = range else {
                    throw Expectation(message: "info range was nil", file: #file, line: #line)
                }
                let infoBytes = outer.subdata(in: r)
                let reEncodedInfo = Bencode.encode(info)
                try expectEqual(infoBytes, reEncodedInfo, "info range byte-mismatch")
            }
        }
    }
}
