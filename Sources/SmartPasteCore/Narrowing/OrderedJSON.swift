/// A JSON value whose object members keep their order, and its one compact rendering.
///
/// The only JSON rendering of a Narrowing request: the size model estimates tokens over it and the Gateway sends it,
/// so what is counted is what Jev reads. Order matters because Jev reads the options in the order they are written
/// (the spike's order: the unchanged option, the pieces in document order, `nothing_fits`, `ask_user`).
public indirect enum OrderedJSON: Equatable, Sendable {
    case string(String)
    case null
    /// Only in Jev's answers (probabilities); a request never holds a number.
    case number(Double)
    case bool(Bool)
    case array([OrderedJSON])
    case object([Member])

    public struct Member: Equatable, Sendable {
        public let key: String
        public let value: OrderedJSON

        public init(_ key: String, _ value: OrderedJSON) {
            self.key = key
            self.value = value
        }
    }

    /// Compact JSON, escaped exactly as Python's `json.dumps(ensure_ascii=False, separators=(",", ":"))`: `"`, `\`
    /// and the control characters U+0000–U+001F; every other character is written as is (UTF-8).
    public var rendered: String {
        var output = ""
        write(to: &output)
        return output
    }

    private func write(to output: inout String) {
        switch self {
        case .string(let text): Self.writeString(text, to: &output)
        case .null: output += "null"
        case .number(let value): output += String(value)
        case .bool(let value): output += value ? "true" : "false"
        case .array(let elements):
            output += "["
            for (position, element) in elements.enumerated() {
                if position > 0 { output += "," }
                element.write(to: &output)
            }
            output += "]"
        case .object(let members):
            output += "{"
            for (position, member) in members.enumerated() {
                if position > 0 { output += "," }
                Self.writeString(member.key, to: &output)
                output += ":"
                member.value.write(to: &output)
            }
            output += "}"
        }
    }

    private static func writeString(_ text: String, to output: inout String) {
        output += "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": output += "\\\""
            case "\\": output += "\\\\"
            case "\n": output += "\\n"
            case "\r": output += "\\r"
            case "\t": output += "\\t"
            case "\u{08}": output += "\\b"
            case "\u{0C}": output += "\\f"
            case "\u{00}"..."\u{1F}": output += "\\u00" + hexDigits(of: scalar.value)
            default: output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
    }

    /// Two lowercase hex digits, as Python writes them.
    private static func hexDigits(of value: UInt32) -> String {
        let digits = Array("0123456789abcdef")
        return String([digits[Int(value >> 4)], digits[Int(value & 0xF)]])
    }
}
