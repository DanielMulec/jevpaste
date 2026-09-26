/// Every paste of the whole Active Item — Jev keeping the whole copy, and Enter after No Suitable Match — strips the
/// copy's outer line breaks, so ⌘⇧V never injects a bare line break at a prompt; every other byte, spaces and tabs
/// included, stays as copied.
enum OuterLineBreaks {
    /// `text` cut after the last line break of its leading whitespace run and at the first line break of its
    /// trailing one: `"\r\n  \r\n\tx \r\n\n"` → `"\tx "`.
    static func stripped(from text: String) -> String {
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
