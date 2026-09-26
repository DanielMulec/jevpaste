/// `pieces` by where each text first occurs in `piece`, the longer first at the same place (the spike's `doc_order`,
/// over Python's `str.find`). Two texts first occurring at one place are one the prefix of the other, so the longer by
/// bytes is the longer by characters too.
func documentOrder(_ pieces: [Substring], in piece: Substring) -> [Substring] {
    let starts = FirstOccurrences.of(pieces, in: piece)
    let keyed = pieces.indices.map { (text: pieces[$0], start: starts[$0] ?? Int.max, length: pieces[$0].utf8.count) }
    return keyed.sorted { $0.start != $1.start ? $0.start < $1.start : $0.length > $1.length }.map(\.text)
}

extension Substring {
    /// Whether `text` occurs in this text, byte for byte in UTF-8 (`String` comparison would accept a canonically
    /// equivalent encoding).
    func containsExactly(_ text: Substring) -> Bool {
        FirstOccurrences.of([text], in: self)[0] != nil
    }
}

/// Where texts first occur in a piece, in UTF-8 bytes from its start: one rolling-hash pass over the piece per
/// distinct text length, which stops once every text of that length is found — instead of one search per text.
/// A byte offset is a character offset's order too: a UTF-8 text only matches at a character boundary.
enum FirstOccurrences {
    static func of(_ texts: [Substring], in piece: Substring) -> [Int?] {
        let haystack = Array(piece.utf8)
        var starts = [Int?](repeating: nil, count: texts.count)
        let byLength = Dictionary(grouping: texts.indices) { texts[$0].utf8.count }
        for (length, indices) in byLength {
            let found = firstOccurrences(of: indices.map { Array(texts[$0].utf8) }, length: length, in: haystack)
            for (position, index) in indices.enumerated() { starts[index] = found[position] }
        }
        return starts
    }

    /// The first offset of each of `needles` (all `length` bytes long) in `haystack`.
    private static func firstOccurrences(of needles: [[UInt8]], length: Int, in haystack: [UInt8]) -> [Int?] {
        guard length > 0 else { return needles.map { _ in 0 } }
        guard length <= haystack.count else { return needles.map { _ in nil } }
        let waiting = RollingHash.table(of: needles)
        var starts = [Int?](repeating: nil, count: needles.count)
        var unfound = needles.count
        RollingHash.windows(of: length, in: haystack, starting: 0...(haystack.count - length)) { offset, hash in
            for position in waiting[hash] ?? [] where starts[position] == nil {
                if haystack[offset..<offset + length].elementsEqual(needles[position]) {
                    starts[position] = offset
                    unfound -= 1
                }
            }
            return unfound > 0
        }
        return starts
    }
}

/// A polynomial rolling hash over byte windows: one pass finds every window equal to one of many texts of a length.
enum RollingHash {
    /// The texts' positions by their hash.
    static func table(of texts: [[UInt8]]) -> [UInt64: [Int]] {
        var table: [UInt64: [Int]] = [:]
        for (position, text) in texts.enumerated() { table[of(text[...]), default: []].append(position) }
        return table
    }

    static func of(_ bytes: ArraySlice<UInt8>) -> UInt64 {
        bytes.reduce(0) { $0 &* base &+ UInt64($1) }
    }

    /// Calls `visit` with the start and hash of every `length`-byte window of `bytes` that starts in `starts`, in
    /// order, until `visit` returns `false`. Every window must lie inside `bytes`.
    static func windows(
        of length: Int, in bytes: [UInt8], starting starts: ClosedRange<Int>, _ visit: (Int, UInt64) -> Bool
    ) {
        let dropFactor = (1..<length).reduce(UInt64(1)) { power, _ in power &* base }
        var offset = starts.lowerBound
        var rolling = of(bytes[offset..<offset + length])
        while visit(offset, rolling), offset < starts.upperBound {
            rolling = (rolling &- UInt64(bytes[offset]) &* dropFactor) &* base &+ UInt64(bytes[offset + length])
            offset += 1
        }
    }

    private static let base: UInt64 = 1_099_511_628_211
}
