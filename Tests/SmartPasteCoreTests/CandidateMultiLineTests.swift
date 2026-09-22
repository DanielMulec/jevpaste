import SmartPasteCore
import Testing

/// The derived Candidates that span a line break: paragraphs, sections and the whole item.
private func derivedMultiLineCandidateTexts(of text: String) -> [String] {
    derivedCandidateTexts(of: text).filter { $0.contains(where: \.isNewline) }
}

struct CandidateParagraphTests {
    @Test func paragraphOfTwoOrMoreLinesSpansItsLineBreaksByteForByte() {
        let paragraph = "221B Baker Street\r\n\tMarylebone\r\n  London NW1 6XE"

        let texts = derivedMultiLineCandidateTexts(of: "Ada Lovelace\n\n  \(paragraph) \n\nEngland")

        #expect(texts.map { Array($0.utf8) }.contains(Array(paragraph.utf8)))
    }

    @Test func singleLineParagraphsAddNothing() {
        #expect(derivedMultiLineCandidateTexts(of: "Ada\n\nLondon\n \nEngland") == ["Ada\n\nLondon\n \nEngland"])
    }

    @Test func singleLineItemHasNoWholeItemCandidate() {
        #expect(derivedCandidateTexts(of: "\n  Ada Lovelace \n\n") == ["Ada Lovelace"])
    }

    @Test func wholeItemSpansBlankLinesAndIsTrimmedOfOuterBlankLines() {
        let texts = derivedCandidateTexts(of: "\r\n \n\tAda\r\n\r\n  London\t\n\n")

        #expect(texts.map { Array($0.utf8) } == ["Ada\r\n\r\n  London", "Ada", "London"].map { Array($0.utf8) })
    }

    @Test func singleParagraphItemIsOfferedOnce() {
        #expect(derivedCandidateTexts(of: "Ada\nLondon\n") == ["Ada\nLondon", "Ada", "London"])
    }
}
