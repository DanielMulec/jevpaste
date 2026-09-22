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
}
