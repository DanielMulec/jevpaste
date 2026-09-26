import Testing

@testable import SmartPasteCore

/// Every whole-copy paste strips the copy's outer line breaks (and the blank-line whitespace around them) and keeps
/// every other byte.
struct OuterLineBreaksTests {
    @Test(
        arguments: [
            ("JEVPASTE-DP-ONE@example.org", "JEVPASTE-DP-ONE@example.org"),
            ("  x@y.org\n", "  x@y.org"),
            ("x@y.org\r\n", "x@y.org"),
            ("x@y.org\r", "x@y.org"),
            ("x@y.org\n\n \n\t", "x@y.org"),
            ("\r\n  \r\n\tx@y.org", "\tx@y.org"),
            ("\t+41  44 668 18 00 \t\n", "\t+41  44 668 18 00 \t"),
            ("   padded   ", "   padded   "),
            ("\nName: Ada\n\nCity: Z\u{FC}rich\r\n\r\n", "Name: Ada\n\nCity: Z\u{FC}rich"),
        ])
    func outerLineBreaksAreStrippedAndEveryOtherByteKept(copy: String, pasted: String) {
        #expect(Array(OuterLineBreaks.stripped(from: copy).utf8) == Array(pasted.utf8))
    }

    @Test func theStrippedTextIsAByteExactSliceOfTheCopy() {
        let copy = "\r\n \u{00A0}Ada\u{2003}Lovelace \u{00A0}\r\n"

        let stripped = OuterLineBreaks.stripped(from: copy)

        #expect(Array(stripped.utf8) == Array(" \u{00A0}Ada\u{2003}Lovelace \u{00A0}".utf8))
        #expect(copy.utf8.firstRange(of: stripped.utf8) != nil)
    }
}
