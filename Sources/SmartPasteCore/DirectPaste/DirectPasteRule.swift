/// Decides whether a Paste Attempt is a Direct Paste, and what it inserts.
///
/// From "Skip Jev for a single line, and skip Jev when there is nothing to reason about" (Rule 1): an Active Item
/// that is a single line — no line break between its first and last non-whitespace character — is inserted whole,
/// without Jev. Its outer line breaks are stripped so ⌘⇧V never injects a bare line break at a prompt; every other
/// byte, spaces and tabs included, stays as copied.
enum DirectPasteRule {
    /// The text a Direct Paste of `item` inserts, or `nil` when `item` is not a single line (Jev decides) or holds
    /// nothing but whitespace (nothing to insert).
    static func text(for item: ClipboardItem) -> String? {
        let scalars = item.text.unicodeScalars
        guard let firstVisible = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
            let lastVisible = scalars.lastIndex(where: { !$0.properties.isWhitespace }),
            !scalars[firstVisible...lastVisible].contains(where: isLineBreak)
        else { return nil }
        let leadingRun = scalars[..<firstVisible]
        let trailingRun = scalars[scalars.index(after: lastVisible)...]
        let start = leadingRun.lastIndex(where: isLineBreak).map(scalars.index(after:)) ?? scalars.startIndex
        let end = trailingRun.firstIndex(where: isLineBreak) ?? scalars.endIndex
        return String(Substring(scalars[start..<end]))
    }

    /// `\n` and `\r`, which together also cover `\r\n`.
    private static func isLineBreak(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "\n" || scalar == "\r"
    }
}
