import Testing

@testable import MacInterop

/// The window of a long field's own text around its text cursor. A limit of 8 keeps the arithmetic visible: 6
/// characters before the cursor, 2 after. Offsets are UTF-16, as the Accessibility API reports them.
struct CursorTextWindowTests {
    private let window = CursorTextWindow(characterLimit: 8)
    private let alphabet = "abcdefghijklmnopqrstuvwxyz"

    private func cursor(at location: Int, length: Int = 0) -> SelectedTextRange {
        SelectedTextRange(location: location, length: length)
    }

    @Test func theDefaultWindowIsTwoThousandCharactersFifteenHundredOfThemBeforeTheCursor() {
        let text = String(repeating: "b", count: 3_000) + "|" + String(repeating: "a", count: 3_000)

        let nearby = CursorTextWindow(characterLimit: 2_000).text(of: text, cursor: cursor(at: 3_000))

        #expect(nearby.count == 2_000)
        #expect(nearby.firstIndex(of: "|").map { nearby.distance(from: nearby.startIndex, to: $0) } == 1_500)
    }

    @Test func aCursorInTheMiddleGetsThreeQuartersBeforeAndAQuarterAfter() {
        #expect(window.text(of: alphabet, cursor: cursor(at: 10)) == "efghijkl")
    }

    @Test func aCursorNearTheStartHandsTheUnusedShareToTheTextAfterIt() {
        #expect(window.text(of: alphabet, cursor: cursor(at: 2)) == "abcdefgh")
    }

    @Test func aCursorAtTheEndGetsTheLastCharactersLikeAPrompt() {
        #expect(window.text(of: alphabet, cursor: cursor(at: 26)) == "stuvwxyz")
    }

    @Test func aCursorOneBeforeTheEndHandsTheUnusedShareToTheTextBeforeIt() {
        #expect(window.text(of: alphabet, cursor: cursor(at: 25)) == "stuvwxyz")
    }

    @Test func noReportedCursorGetsTheLastCharacters() {
        #expect(window.text(of: alphabet, cursor: nil) == "stuvwxyz")
    }

    /// Gate A: Ghostty reports (0,0) whatever its cursor; a caret truly at the start is rare.
    @Test func anEmptyRangeAtTheVeryStartCountsAsNoCursor() {
        #expect(window.text(of: alphabet, cursor: cursor(at: 0)) == "stuvwxyz")
    }

    @Test func aSelectionAtTheVeryStartIsACursor() {
        #expect(window.text(of: alphabet, cursor: cursor(at: 0, length: 3)) == "abcdefgh")
    }

    @Test(arguments: [(27, 0), (26, 1), (20, 7), (-1, 0), (5, -1), (Int.max, 1)])
    func aRangeOutsideTheTextCountsAsNoCursor(location: Int, length: Int) {
        #expect(window.text(of: alphabet, cursor: cursor(at: location, length: length)) == "stuvwxyz")
    }

    @Test func aSelectionAnchorsTheWindowAtItsStart() {
        #expect(window.text(of: alphabet, cursor: cursor(at: 10, length: 5)) == "efghijkl")
    }

    @Test func utf16OffsetsBecomeCharacterCounts() {
        let text = String(repeating: "😀", count: 10) + "abcdefghij"

        #expect(window.text(of: text, cursor: cursor(at: 20)) == "😀😀😀😀😀😀ab")
    }

    @Test func aCursorInsideASurrogatePairStartsAtTheWholeCharacter() {
        let text = "abcdefghij😀klmnopqrst"

        #expect(window.text(of: text, cursor: cursor(at: 11)) == "efghij😀k")
    }

    @Test func aCursorInsideACombiningSequenceStartsAtTheWholeCharacter() {
        let text = "abcdefghije\u{301}klmnopqrst"

        #expect(window.text(of: text, cursor: cursor(at: 11)) == "efghije\u{301}k")
    }

    @Test func theWindowsStartEdgeKeepsAWholeCharacter() {
        let text = "abcd👩‍👩‍👧fghijklmnop"
        let cursorAfterJ = "abcd👩‍👩‍👧fghij".utf16.count

        #expect(window.text(of: text, cursor: cursor(at: cursorAfterJ)) == "👩‍👩‍👧fghijkl")
    }

    @Test func theWindowsEndEdgeKeepsAWholeCharacter() {
        let text = "abcdefghij" + "e\u{301}" + "🇦🇹" + "klmnop"

        #expect(window.text(of: text, cursor: cursor(at: 10)) == "efghije\u{301}🇦🇹")
    }

    @Test func aFlagIsNeverSplitAtTheCursor() {
        let text = "abcdefgh🇦🇹🇩🇪ijklmnop"

        #expect(window.text(of: text, cursor: cursor(at: 10)) == "cdefgh🇦🇹🇩🇪")
    }

    @Test func textWithinTheLimitIsReturnedWhole() {
        #expect(window.text(of: "abcdefgh", cursor: cursor(at: 4)) == "abcdefgh")
    }
}
