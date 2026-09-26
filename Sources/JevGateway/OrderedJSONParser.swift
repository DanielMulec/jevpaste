import Foundation
import SmartPasteCore

/// Parses a JSON response into an `OrderedJSON` that keeps every object's member order: Jev lists an answer's
/// probabilities in an order of its own, and Core breaks ties between equal probabilities by it. `JSONDecoder` and
/// `JSONSerialization` both lose that order.
struct OrderedJSONParser {
    private let bytes: [UInt8]
    private var position = 0

    /// The value `data` holds, or `nil` when it is not one complete JSON value.
    static func parse(_ data: some Sequence<UInt8>) -> OrderedJSON? {
        var parser = OrderedJSONParser(bytes: Array(data))
        guard let value = parser.value() else { return nil }
        parser.skipWhitespace()
        return parser.position == parser.bytes.count ? value : nil
    }

    private init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    private mutating func value() -> OrderedJSON? {
        skipWhitespace()
        guard let byte = peek() else { return nil }
        switch byte {
        case UInt8(ascii: "{"): return object()
        case UInt8(ascii: "["): return array()
        case UInt8(ascii: "\""): return string().map(OrderedJSON.string)
        case UInt8(ascii: "t"): return literal("true", .bool(true))
        case UInt8(ascii: "f"): return literal("false", .bool(false))
        case UInt8(ascii: "n"): return literal("null", .null)
        default: return number()
        }
    }

    private mutating func object() -> OrderedJSON? {
        position += 1
        var members: [OrderedJSON.Member] = []
        skipWhitespace()
        if consume("}") { return .object(members) }
        repeat {
            skipWhitespace()
            guard let key = string() else { return nil }
            skipWhitespace()
            guard consume(":"), let member = value() else { return nil }
            members.append(.init(key, member))
            skipWhitespace()
        } while consume(",")
        return consume("}") ? .object(members) : nil
    }

    private mutating func array() -> OrderedJSON? {
        position += 1
        var elements: [OrderedJSON] = []
        skipWhitespace()
        if consume("]") { return .array(elements) }
        repeat {
            guard let element = value() else { return nil }
            elements.append(element)
            skipWhitespace()
        } while consume(",")
        return consume("]") ? .array(elements) : nil
    }

    private mutating func string() -> String? {
        guard consume("\"") else { return nil }
        var scalars = String.UnicodeScalarView()
        var run: [UInt8] = []
        while let byte = next() {
            switch byte {
            case UInt8(ascii: "\""):
                guard let text = String(bytes: run, encoding: .utf8) else { return nil }
                scalars.append(contentsOf: text.unicodeScalars)
                return String(scalars)
            case UInt8(ascii: "\\"):
                guard let text = String(bytes: run, encoding: .utf8) else { return nil }
                scalars.append(contentsOf: text.unicodeScalars)
                run = []
                guard let escaped = escape() else { return nil }
                scalars.append(escaped)
            case 0..<0x20:
                return nil
            default:
                run.append(byte)
            }
        }
        return nil
    }

    private mutating func escape() -> Unicode.Scalar? {
        guard let byte = next() else { return nil }
        switch byte {
        case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): return Unicode.Scalar(byte)
        case UInt8(ascii: "b"): return "\u{08}"
        case UInt8(ascii: "f"): return "\u{0C}"
        case UInt8(ascii: "n"): return "\n"
        case UInt8(ascii: "r"): return "\r"
        case UInt8(ascii: "t"): return "\t"
        case UInt8(ascii: "u"): return unicodeEscape()
        default: return nil
        }
    }

    /// `\uXXXX`, or a surrogate pair of two.
    private mutating func unicodeEscape() -> Unicode.Scalar? {
        guard let first = hexQuad() else { return nil }
        guard (0xD800..<0xDC00).contains(first) else { return Unicode.Scalar(first) }
        guard consume("\\"), consume("u"), let second = hexQuad(), (0xDC00..<0xE000).contains(second) else {
            return nil
        }
        return Unicode.Scalar(0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00))
    }

    private mutating func hexQuad() -> UInt32? {
        guard position + 4 <= bytes.count,
            let digits = String(bytes: bytes[position..<position + 4], encoding: .utf8),
            let value = UInt32(digits, radix: 16)
        else { return nil }
        position += 4
        return value
    }

    private mutating func number() -> OrderedJSON? {
        let start = position
        let numberBytes = Set("+-0123456789.eE".utf8)
        while let byte = peek(), numberBytes.contains(byte) { position += 1 }
        return String(bytes: bytes[start..<position], encoding: .utf8).flatMap(Double.init).map(OrderedJSON.number)
    }

    private mutating func literal(_ word: String, _ value: OrderedJSON) -> OrderedJSON? {
        let wordBytes = Array(word.utf8)
        guard bytes[position...].starts(with: wordBytes) else { return nil }
        position += wordBytes.count
        return value
    }

    private mutating func skipWhitespace() {
        while let byte = peek(), [0x20, 0x09, 0x0A, 0x0D].contains(byte) { position += 1 }
    }

    private mutating func consume(_ character: Unicode.Scalar) -> Bool {
        guard peek() == UInt8(ascii: character) else { return false }
        position += 1
        return true
    }

    private func peek() -> UInt8? {
        position < bytes.count ? bytes[position] : nil
    }

    private mutating func next() -> UInt8? {
        defer { position += 1 }
        return peek()
    }
}
