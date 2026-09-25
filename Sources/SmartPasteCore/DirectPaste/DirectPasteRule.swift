/// Decides whether a Paste Attempt is a Direct Paste, and what a Direct Paste inserts.
///
/// From "Skip Jev for a single line, and skip Jev when there is nothing to reason about" (Rule 1): an Active Item
/// that is a single line — no line break between its first and last non-whitespace character — is inserted whole,
/// without Jev. Every Direct Paste (also into a Free-text Target) strips the outer line breaks so ⌘⇧V never injects
/// a bare line break at a prompt; every other byte, spaces and tabs included, stays as copied.
enum DirectPasteRule {
    /// The text a Direct Paste of `item` inserts, or `nil` when `item` is not a single line (Jev decides) or holds
    /// nothing but whitespace (nothing to insert).
    static func text(for item: ClipboardItem) -> String? {
        let scalars = item.text.unicodeScalars
        guard let firstVisible = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
            let lastVisible = scalars.lastIndex(where: { !$0.properties.isWhitespace }),
            !scalars[firstVisible...lastVisible].contains(where: isLineBreak)
        else { return nil }
        return withoutOuterLineBreaks(item.text)
    }

    /// `text` cut after the last line break of its leading whitespace run and at the first line break of its
    /// trailing one: `"\r\n  \r\n\tx \r\n\n"` → `"\tx "`. Pure stripping: whether there is anything to insert is
    /// `text(for:)`'s question.
    static func withoutOuterLineBreaks(_ text: String) -> String {
        let scalars = text.unicodeScalars
        let firstVisible = scalars.firstIndex { !$0.properties.isWhitespace } ?? scalars.endIndex
        let afterLastVisible = scalars.lastIndex { !$0.properties.isWhitespace }.map(scalars.index(after:))
        let leadingRun = scalars[..<firstVisible]
        let trailingRun = scalars[(afterLastVisible ?? firstVisible)...]
        let start = leadingRun.lastIndex(where: isLineBreak).map(scalars.index(after:)) ?? scalars.startIndex
        let end = trailingRun.firstIndex(where: isLineBreak) ?? scalars.endIndex
        return String(Substring(scalars[start..<end]))
    }

    /// `\n` and `\r`, which together also cover `\r\n`.
    private static func isLineBreak(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "\n" || scalar == "\r"
    }
}
