import Testing

@testable import SmartPasteCore

struct DirectPasteRuleTests {
    /// A single line once outer whitespace and line breaks are ignored → its Direct Paste text: outer line breaks
    /// (and blank-line whitespace around them) stripped, every other byte kept.
    @Test(
        arguments: [
            ("JEVPASTE-DP-ONE@example.org", "JEVPASTE-DP-ONE@example.org"),
            ("  x@y.org\n", "  x@y.org"),
            ("x@y.org\r\n", "x@y.org"),
            ("x@y.org\r", "x@y.org"),
            ("x@y.org\n\n \n\t", "x@y.org"),
            ("x@y.org\r\n\r\n", "x@y.org"),
            ("\n\nx@y.org", "x@y.org"),
            ("\r\n  \r\n\tx@y.org", "\tx@y.org"),
            ("\t+41  44 668 18 00 \t\n", "\t+41  44 668 18 00 \t"),
            ("  a b\t\r\n\n", "  a b\t"),
            ("   padded   ", "   padded   "),
            ("Z\u{FC}rich / Zu\u{308}rich\n", "Z\u{FC}rich / Zu\u{308}rich"),
        ])
    func aSingleLineItemIsDirectPastedWithOuterLineBreaksStripped(item: String, directPasteText: String) {
        #expect(DirectPasteRule.text(for: ClipboardItem(text: item)) == directPasteText)
    }

    /// A line break between the first and the last non-whitespace character → not a Direct Paste; Jev decides.
    @Test(arguments: ["a\n\nb", "a\nb", "a\r\nb", "a\rb", "\n  a\n b \n", "Name: Ada\nEmail: ada@example.com"])
    func aMultiLineItemIsNotADirectPaste(item: String) {
        #expect(DirectPasteRule.text(for: ClipboardItem(text: item)) == nil)
    }

    /// Nothing to insert: the existing path ends in No Suitable Match without asking Jev.
    @Test(arguments: ["", " ", "\n", "\r\n\t \r", " \t\n\n"])
    func anEmptyOrWhitespaceOnlyItemIsNotADirectPaste(item: String) {
        #expect(DirectPasteRule.text(for: ClipboardItem(text: item)) == nil)
    }

    @Test func theDirectPasteTextIsAByteExactSliceOfTheItem() {
        let item = "\r\n \u{00A0}Ada\u{2003}Lovelace \u{00A0}\r\n"
        let text = DirectPasteRule.text(for: ClipboardItem(text: item))

        #expect(text == " \u{00A0}Ada\u{2003}Lovelace \u{00A0}")
        #expect(text.map { Array(item.utf8).containsSlice(Array($0.utf8)) } == true)
    }
}

extension Array where Element == UInt8 {
    fileprivate func containsSlice(_ slice: [UInt8]) -> Bool {
        guard slice.count <= count else { return false }
        return (0...(count - slice.count)).contains { Array(self[$0..<($0 + slice.count)]) == slice }
    }
}
