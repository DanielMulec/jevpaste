import Testing

@testable import SmartPasteCore

/// Which pieces the Candidate Chooser's next fill choice leaves out: a piece overlaps a row when any of its
/// occurrences shares a UTF-8 byte with any occurrence of the row; touching spans do not overlap.
struct RowOverlapTests {
    @Test(arguments: [
        ("abcd", "ab", "cd", false),  // adjacent after the row
        ("abcd", "cd", "ab", false),  // adjacent before the row
        ("abcd", "ab", "bc", true),  // one shared byte
        ("abcd", "bc", "abcd", true),  // contains the row
        ("\u{E9}\u{20AC}x", "\u{20AC}", "\u{E9}", false),  // multibyte, adjacent before (2 + 3 bytes)
        ("\u{E9}\u{20AC}x", "\u{20AC}", "x", false),  // multibyte, adjacent after
        ("\u{E9}\u{20AC}x", "\u{20AC}", "\u{E9}\u{20AC}", true),  // multibyte, overlapping
        ("Zu\u{308}rich Z\u{FC}rich", "Z\u{FC}rich", "Zu\u{308}rich", false),  // canonically equivalent, other bytes
        ("ab ab-x", "b-x", "ab", true),  // the second occurrence overlaps
        ("ab-x ab", "ab-x", " ab", false),  // the text's only occurrence touches the row
        ("abcd", "ab", "", false),  // an empty text never overlaps
    ])
    func aPieceOverlapsWhenAnyOccurrenceSharesAByteWithARow(piece: String, row: String, text: String, overlaps: Bool) {
        #expect(RowOverlap.of([text[...]], withRows: [row[...]], in: piece[...]) == [overlaps])
    }

    @Test func withoutRowsNothingOverlaps() {
        #expect(RowOverlap.of(["ab", "cd"], withRows: [], in: "abcd") == [false, false])
    }
}
