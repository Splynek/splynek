import Foundation

/// Bencoding — the serialization format used by BitTorrent (BEP 3).
///
/// Four types:
///   - byte-string:  `<length>:<bytes>`
///   - integer:      `i<decimal>e`   (no leading zeros, no -0)
///   - list:         `l<items...>e`
///   - dictionary:   `d<key-value pairs>e`  (keys are byte-strings, lex-sorted)
///
/// We keep byte-strings as `Data` (not String) because the info-hash calc and
/// lots of BitTorrent fields are binary.
enum Bencode {

    indirect enum Value: Equatable {
        case bytes(Data)
        case integer(Int64)
        case list([Value])
        case dict([Data: Value])   // keys are byte-strings
    }

    // MARK: Decode

    enum DecodeError: Error, LocalizedError {
        case unexpectedEOF
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .unexpectedEOF:    return "bencode: unexpected end of input"
            case .invalid(let s):   return "bencode: \(s)"
            }
        }
    }

    static func decode(_ data: Data) throws -> Value {
        var cursor = data.startIndex
        let v = try decodeValue(data, &cursor)
        guard cursor == data.endIndex else {
            throw DecodeError.invalid("trailing bytes after root value")
        }
        return v
    }

    /// Decode a root dict and also return the byte range of the info subdict
    /// so the caller can SHA-1-hash the *raw* info bytes for the info hash.
    static func decodeWithInfoRange(_ data: Data) throws -> (Value, Range<Int>?) {
        var cursor = data.startIndex
        var infoRange: Range<Int>?
        let v = try decodeValue(data, &cursor, infoRangeOut: &infoRange)
        return (v, infoRange)
    }

    private static func decodeValue(
        _ data: Data,
        _ c: inout Data.Index,
        infoRangeOut: UnsafeMutablePointer<Range<Int>?>? = nil
    ) throws -> Value {
        guard c < data.endIndex else { throw DecodeError.unexpectedEOF }
        let b = data[c]
        switch b {
        case 0x69:  // 'i'
            c = data.index(after: c)
            guard let end = data[c..<data.endIndex].firstIndex(of: 0x65) else {
                throw DecodeError.unexpectedEOF
            }
            let s = String(data: data[c..<end], encoding: .ascii) ?? ""
            guard let n = Int64(s) else { throw DecodeError.invalid("bad integer: \(s)") }
            c = data.index(after: end)
            return .integer(n)
        case 0x6c:  // 'l'
            c = data.index(after: c)
            var items: [Value] = []
            while c < data.endIndex, data[c] != 0x65 {
                items.append(try decodeValue(data, &c, infoRangeOut: infoRangeOut))
            }
            guard c < data.endIndex else { throw DecodeError.unexpectedEOF }
            c = data.index(after: c)
            return .list(items)
        case 0x64:  // 'd'
            c = data.index(after: c)
            var dict: [Data: Value] = [:]
            while c < data.endIndex, data[c] != 0x65 {
                let key = try decodeBytes(data, &c)
                if key == Data("info".utf8), let ptr = infoRangeOut {
                    let valueStart = c
                    let value = try decodeValue(data, &c, infoRangeOut: nil)
                    ptr.pointee = valueStart..<c
                    dict[key] = value
                } else {
                    dict[key] = try decodeValue(data, &c, infoRangeOut: infoRangeOut)
                }
            }
            guard c < data.endIndex else { throw DecodeError.unexpectedEOF }
            c = data.index(after: c)
            return .dict(dict)
        case 0x30...0x39:  // '0'..'9'
            let bytes = try decodeBytes(data, &c)
            return .bytes(bytes)
        default:
            throw DecodeError.invalid("unexpected byte \(b)")
        }
    }

    private static func decodeBytes(_ data: Data, _ c: inout Data.Index) throws -> Data {
        guard let colon = data[c..<data.endIndex].firstIndex(of: 0x3a) else {
            throw DecodeError.invalid("missing ':' in byte-string")
        }
        let lenStr = String(data: data[c..<colon], encoding: .ascii) ?? ""
        guard let len = Int(lenStr), len >= 0 else {
            throw DecodeError.invalid("bad byte-string length: \(lenStr)")
        }
        c = data.index(after: colon)
        let end = data.index(c, offsetBy: len)
        guard end <= data.endIndex else { throw DecodeError.unexpectedEOF }
        let slice = Data(data[c..<end])
        c = end
        return slice
    }

    // MARK: Encode

    static func encode(_ value: Value) -> Data {
        var out = Data()
        encode(value, into: &out)
        return out
    }

    private static func encode(_ value: Value, into out: inout Data) {
        switch value {
        case .bytes(let d):
            out.append(Data(String(d.count).utf8))
            out.append(0x3a)
            out.append(d)
        case .integer(let n):
            out.append(0x69)
            out.append(Data(String(n).utf8))
            out.append(0x65)
        case .list(let items):
            out.append(0x6c)
            for i in items { encode(i, into: &out) }
            out.append(0x65)
        case .dict(let d):
            out.append(0x64)
            for k in d.keys.sorted(by: { $0.lexicographicallyPrecedes($1) }) {
                encode(.bytes(k), into: &out)
                encode(d[k]!, into: &out)
            }
            out.append(0x65)
        }
    }

    // MARK: Accessors

    static func asInt(_ v: Value?) -> Int64? {
        if case .integer(let n)? = v { return n } else { return nil }
    }
    static func asBytes(_ v: Value?) -> Data? {
        if case .bytes(let d)? = v { return d } else { return nil }
    }
    static func asString(_ v: Value?) -> String? {
        asBytes(v).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func asList(_ v: Value?) -> [Value]? {
        if case .list(let l)? = v { return l } else { return nil }
    }
    static func asDict(_ v: Value?) -> [Data: Value]? {
        if case .dict(let d)? = v { return d } else { return nil }
    }
    static func lookup(_ d: [Data: Value], _ key: String) -> Value? {
        d[Data(key.utf8)]
    }
}
