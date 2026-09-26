/// A piece of text compared and hashed by its UTF-8 bytes. `String` equality treats canonically equivalent encodings
/// as equal ("ü" and "u" + ◌̈), which would merge two different excerpts; Narrowing never does.
struct ExactText: Hashable {
    let text: Substring

    init(_ text: Substring) {
        self.text = text
    }

    static func == (left: ExactText, right: ExactText) -> Bool {
        left.text.utf8.count == right.text.utf8.count && left.text.utf8.elementsEqual(right.text.utf8)
    }

    /// The length and the first and last bytes: cheap for long pieces, and pieces rarely share all three; equality
    /// still compares every byte.
    func hash(into hasher: inout Hasher) {
        let bytes = text.utf8
        hasher.combine(bytes.count)
        for byte in bytes.prefix(Self.hashedEdgeLength) { hasher.combine(byte) }
        for byte in bytes.suffix(Self.hashedEdgeLength) { hasher.combine(byte) }
    }

    private static let hashedEdgeLength = 32
}

extension Array where Element == Substring {
    /// These pieces without empty ones, without any whose bytes equal `parent`'s, and without repeats — the first
    /// of equal texts stays, in order.
    func deduplicated(excluding parent: Substring) -> [Substring] {
        var seen: Set<ExactText> = [ExactText(parent)]
        return filter { !$0.isEmpty && seen.insert(ExactText($0)).inserted }
    }

    /// These pieces without empty ones, without any whose bytes equal one of `known`, and without repeats, in order;
    /// `nil` as soon as more than `limit` remain — when there are too many, they are not all needed.
    func newTexts(besides known: [Substring], atMost limit: Int) -> [Substring]? {
        var seen = Set(known.map(ExactText.init))
        var kept: [Substring] = []
        for text in self where !text.isEmpty && seen.insert(ExactText(text)).inserted {
            guard kept.count < limit else { return nil }
            kept.append(text)
        }
        return kept
    }
}
