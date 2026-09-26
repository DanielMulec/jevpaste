import Testing

@testable import SmartPasteCore

/// Cutting by character classes only: lines, tokens, characters and edge cuts. Expected values are the spike's
/// `cuts.py` output on the same texts (`spike/narrowing` @ ba32886), except where Swift `Character`s deliberately
/// replace Python's code points.
struct PieceCuttingTests {
    private func texts(_ pieces: [Substring]) -> [String] {
        pieces.map(String.init)
    }

    @Test func linesAreRunsOfNonBlankTextTrimmedOfOuterWhitespaceWithCRLFAsOneBreak() {
        let copy = "  Mira Holzner \r\n\n\tPrankergasse 77\n \n8020 Graz\u{2028}Top 11"

        let lines = PieceCutting.lines(of: copy[...])

        #expect(texts(lines) == ["Mira Holzner", "Prankergasse 77", "8020 Graz", "Top 11"])
    }

    @Test func everyPieceIsASliceOfTheCopyItself() {
        let copy = "Name: Ada\r\nCity: Zu\u{308}rich"

        for line in PieceCutting.lines(of: copy[...]) {
            for token in PieceCutting.tokens(of: line) {
                #expect(copy.utf8[token.startIndex..<token.endIndex].elementsEqual(token.utf8))
                #expect(copy.utf8.distance(from: copy.startIndex, to: token.startIndex) >= 0)
            }
        }
    }

    @Test func aTokenIsARunOfLettersAndNumbersOrOneOtherCharacter() {
        #expect(texts(PieceCutting.tokens(of: "a@b.c d-1"[...])) == ["a", "@", "b", ".", "c", "d", "-", "1"])
        #expect(texts(PieceCutting.tokens(of: "Österreich · 8020²"[...])) == ["Österreich", "·", "8020²"])
    }

    @Test func aTokenNeverSplitsAGraphemeCluster() {
        #expect(texts(PieceCutting.tokens(of: "Zu\u{308}rich"[...])) == ["Zu\u{308}rich"])
        #expect(texts(PieceCutting.tokens(of: "hi👍🏽x"[...])) == ["hi", "👍🏽", "x"])
    }

    @Test func aOneLinePieceHasEveryCutInsideItsFirstAndLastToken() {
        #expect(texts(PieceCutting.edgeCuts(of: "ab-cd ef"[...])) == ["b-cd ef", "ab-cd e"])
        #expect(texts(PieceCutting.edgeCuts(of: "Graz"[...])) == ["raz", "az", "z", "Gra", "Gr", "G"])
    }

    @Test func aMultiLinePieceHasFourUnitEdgeCuts() {
        let cuts = PieceCutting.edgeCuts(of: "ab cd\nef gh"[...])

        #expect(texts(cuts) == ["cd\nef gh", "b cd\nef gh", "ab cd\nef", "ab cd\nef g"])
    }

    @Test func aMultiLineEdgeCutIsTrimmedWhenItsFirstOrLastLineHasOneToken() {
        let cuts = PieceCutting.edgeCuts(of: "Graz\n\n8020 x"[...])

        #expect(texts(cuts) == ["8020 x", "raz\n\n8020 x", "Graz\n\n8020", "Graz\n\n8020"])
    }

    @Test func runsAreInDocumentOrderLongerFirst() {
        let piece = "a b c"[...]

        let runs = PieceCutting.runs(of: PieceCutting.tokens(of: piece), in: piece)

        #expect(texts(runs) == ["a b c", "a b", "a", "b c", "b", "c"])
    }
}
