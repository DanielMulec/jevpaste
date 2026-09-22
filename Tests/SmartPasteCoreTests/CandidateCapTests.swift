import SmartPasteCore
import Testing

/// Jev accepts 255 options and the JevGateway adapter adds `none_of_these`, so at most 254 Candidates.
private let candidateCap = 254

private func numberedLines(_ numbers: ClosedRange<Int>, _ line: (Int) -> String) -> String {
    numbers.map(line).joined(separator: "\n")
}

struct CandidateCapTests {
    @Test func thousandLineSourceIsCappedAt254KeepingTheFirstLinesInDocumentOrder() {
        let texts = derivedCandidateTexts(of: numberedLines(1...1000) { "Line \($0)" })

        #expect(texts == (1...candidateCap).map { "Line \($0)" })
    }

    @Test func exactly254CandidatesAreAllKeptAnd255LoseTheLast() {
        #expect(derivedCandidateTexts(of: numberedLines(1...254) { "Line \($0)" }).count == 254)
        #expect(derivedCandidateTexts(of: numberedLines(1...255) { "Line \($0)" }).last == "Line 254")
    }

    @Test func overCapDropsWholeLabelledLinesBeforeValuesAndPlainLines() {
        let source = "Plain first\n" + numberedLines(1...200) { "Field \($0): value \($0)" } + "\nPlain last"

        let texts = derivedCandidateTexts(of: source)

        // 402 excerpts: 148 whole labelled lines must go, the last ones first; wholes 1…52 stay.
        let keptWholes = (1...52).map { number in ["Field \(number): value \(number)", "value \(number)"] }
        let valuesOnly = (53...200).map { "value \($0)" }
        #expect(texts == ["Plain first"] + keptWholes.flatMap { $0 } + valuesOnly + ["Plain last"])
        #expect(texts.count == candidateCap)
    }

    @Test func whenValuesAndPlainLinesAloneExceedTheCapTheDocumentEndIsDropped() {
        let texts = derivedCandidateTexts(of: numberedLines(1...300) { "Field \($0): value \($0)" })

        #expect(texts == (1...candidateCap).map { "value \($0)" })
    }

    @Test func overCapDropsTheWholeItemFirst() {
        let firstParagraph = numberedLines(1...126) { "Line \($0)" }
        let secondParagraph = numberedLines(127...252) { "Line \($0)" }
        let source = firstParagraph + "\n\n" + secondParagraph

        let texts = derivedCandidateTexts(of: source)

        // 252 lines + 2 paragraphs + the whole item = 255.
        #expect(texts.count == candidateCap)
        #expect(!texts.contains(source))
        #expect(texts.contains(firstParagraph) && texts.contains(secondParagraph))
    }

    @Test func overCapDropsSectionsBeforeParagraphs() {
        let blocks = (1...37).map { number in "H\(number):\nfirst \(number)\nT\(number):\nsecond \(number)" }

        let texts = derivedCandidateTexts(of: blocks.joined(separator: "\n\n"))

        // Per block 4 lines, 1 paragraph, 2 sections; plus the whole item: 260. The whole item and the last 5
        // sections go.
        #expect(texts.count == candidateCap)
        #expect(blocks.allSatisfy(texts.contains))
        #expect(texts.contains("H35:\nfirst 35") && !texts.contains("T35:\nsecond 35"))
        #expect(!texts.contains("H36:\nfirst 36") && !texts.contains("T37:\nsecond 37"))
    }

    @Test func overCapDropsParagraphsBeforeWholeLabelledLines() {
        let blocks = (1...60).map { number in "Key \(number): a\(number)\nLock \(number): b\(number)" }

        let texts = derivedCandidateTexts(of: blocks.joined(separator: "\n\n"))

        // Per block 2 whole labelled lines, 2 values, 1 paragraph; plus the whole item: 301. The whole item and the
        // last 46 paragraphs go; every whole labelled line stays.
        #expect(texts.count == candidateCap)
        #expect(blocks.prefix(14).allSatisfy(texts.contains) && !blocks.dropFirst(14).contains(where: texts.contains))
        #expect((1...60).allSatisfy { texts.contains("Key \($0): a\($0)") && texts.contains("Lock \($0): b\($0)") })
    }
}
