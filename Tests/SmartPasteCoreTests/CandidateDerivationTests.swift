import SmartPasteCore
import Testing

/// The Candidates `StructuralCandidateExtraction` derives from `text`, as plain strings.
func derivedCandidateTexts(of text: String) -> [String] {
    StructuralCandidateExtraction().candidates(in: ClipboardItem(text: text)).map(\.text)
}

/// The derived Candidates that hold no line break: lines and `Label: value` values.
func derivedSingleLineCandidateTexts(of text: String) -> [String] {
    derivedCandidateTexts(of: text).filter { !$0.contains(where: \.isNewline) }
}

struct CandidateDerivationTests {
    @Test func eachNonBlankLineIsACandidateInDocumentOrder() {
        #expect(
            derivedSingleLineCandidateTexts(of: "Ada Lovelace\nAnalyst\nLondon") == [
                "Ada Lovelace", "Analyst", "London",
            ])
    }

    @Test func leadingAndTrailingSpacesAndTabsAreTrimmedInnerWhitespaceKept() {
        #expect(
            derivedSingleLineCandidateTexts(of: "  \tAda  \t Lovelace\t \n\u{00A0}London\u{3000}") == [
                "Ada  \t Lovelace", "London",
            ])
    }

    @Test func emptyAndWhitespaceOnlyLinesYieldNothing() {
        #expect(derivedSingleLineCandidateTexts(of: "\n\nAda\n \t \n\n\u{2003}\nLondon\n\n") == ["Ada", "London"])
    }

    @Test func emptySourceYieldsNoCandidates() {
        #expect(derivedSingleLineCandidateTexts(of: "").isEmpty)
        #expect(derivedSingleLineCandidateTexts(of: " \t\r\n ").isEmpty)
    }

    @Test func crlfAndLoneCarriageReturnSplitLinesWithoutLeavingCarriageReturns() {
        let texts = derivedSingleLineCandidateTexts(of: "Ada\r\nLondon\rParis\r\n\r\nRome\u{2028}Oslo")

        #expect(texts == ["Ada", "London", "Paris", "Rome", "Oslo"])
        #expect(texts.allSatisfy { !$0.unicodeScalars.contains("\r") })
    }

    @Test func identicalTextIsOfferedOnce() {
        #expect(
            derivedSingleLineCandidateTexts(of: "London\nCity: London\n  London\t\nCity: London")
                == ["London", "City: London"]
        )
    }

    @Test func differentlyEncodedEqualTextIsKeptAsTwoCandidates() {
        let composed = "Z\u{00FC}rich"
        let decomposed = "Zu\u{0308}rich"

        let texts = derivedSingleLineCandidateTexts(of: "\(composed)\n\(decomposed)")

        #expect(texts.map { Array($0.utf8) } == [Array(composed.utf8), Array(decomposed.utf8)])
    }

    @Test func unicodeAndEmojiLinesAreKeptByteForByte() {
        let lines = ["Name: Zoë Łukasiewicz-O\u{2019}Brien", "東京都渋谷区", "👩🏽‍💻 Engineer 🇦🇹"]

        let texts = derivedSingleLineCandidateTexts(of: lines.joined(separator: "\r\n"))

        #expect(
            texts.map { Array($0.utf8) }
                == [lines[0], "Zoë Łukasiewicz-O\u{2019}Brien", lines[1], lines[2]].map { Array($0.utf8) }
        )
    }
}

struct CandidateLabelValueTests {
    @Test func labelledLineYieldsTheWholeLineAndTheValue() {
        #expect(
            derivedSingleLineCandidateTexts(of: "Email: ada@example.com\nX / Twitter:\t @ada ")
                == ["Email: ada@example.com", "ada@example.com", "X / Twitter:\t @ada", "@ada"]
        )
    }

    @Test func valueContainingAURLKeepsAllItsColons() {
        #expect(
            derivedSingleLineCandidateTexts(of: "Website: https://a.example:8443/x?y=1:2\nTime: 10:30")
                == [
                    "Website: https://a.example:8443/x?y=1:2", "https://a.example:8443/x?y=1:2", "Time: 10:30", "10:30",
                ]
        )
    }

    @Test func urlLineWithoutLabelIsNotSplit() {
        #expect(derivedSingleLineCandidateTexts(of: "https://x.com/ada_lovelace") == ["https://x.com/ada_lovelace"])
    }

    @Test func colonWithoutFollowingSpaceDoesNotSplit() {
        #expect(derivedSingleLineCandidateTexts(of: "Ratio:3:4\nNote:done") == ["Ratio:3:4", "Note:done"])
    }

    @Test func labelLongerThanFortyCharactersDoesNotSplit() {
        let fortyCharacterLabel = String(repeating: "L", count: 40)
        let fortyOneCharacterLabel = String(repeating: "L", count: 41)

        #expect(derivedSingleLineCandidateTexts(of: "\(fortyCharacterLabel): v") == ["\(fortyCharacterLabel): v", "v"])
        #expect(derivedSingleLineCandidateTexts(of: "\(fortyOneCharacterLabel): v") == ["\(fortyOneCharacterLabel): v"])
    }

    @Test func labelContainingAColonDoesNotSplitAtALaterSeparator() {
        #expect(
            derivedSingleLineCandidateTexts(of: "See https://a.example: details") == ["See https://a.example: details"])
    }

    @Test func labelWithEmptyValueYieldsOnlyTheLine() {
        #expect(derivedSingleLineCandidateTexts(of: "Email:   \nPhone:") == ["Email:", "Phone:"])
    }
}
