import SmartPasteCore
import Testing

/// Every derived Candidate must pass Core's verbatim check: a byte-exact contiguous substring of the Active Item.
@MainActor
struct CandidateVerbatimTests {
    static let mixedSource =
        [
            "  Ada Lovelace\t",
            "",
            "Email:\tada@example.com ",
            "Website: https://ada.example:8443/profile?tab=1:2",
            " \t ",
            "https://x.com/ada_lovelace",
            "Adresse: Zürich, Straße 5 \u{00A0}",
            "Name: Zu\u{0308}rich",
            "👩🏽‍💻 Engineer 🇦🇹",
            "Time: 10:30",
        ].joined(separator: "\r\n") + "\rLast line\n"

    @Test func everyCandidateOfAMixedSourceIsAcceptedByPasteResultValidation() {
        let candidates = LineAndLabelCandidateExtraction().candidates(in: ClipboardItem(text: Self.mixedSource))
        #expect(candidates.count == 14)

        for candidate in candidates {
            let harness = PasteAttemptHarness(candidates: candidates, sourceText: Self.mixedSource)
            harness.pasteChoosing(candidate.text)
            harness.clock.advance(by: .milliseconds(120))

            #expect(harness.presenter.outcomes == [.inserted], "\(candidate.text)")
            #expect(harness.log.steps.first == .write(candidate.text))
        }
    }

    @Test func everyCandidateOfAThousandLineSourceIsAByteExactSubstring() {
        let source = (1...1000).map { number in
            number.isMultiple(of: 3) ? "\tKey \(number):  https://h.example:\(number)/ü " : "Zeile \(number) – ✓\r"
        }.joined(separator: "\n")

        let candidates = LineAndLabelCandidateExtraction().candidates(in: ClipboardItem(text: source))

        #expect(candidates.count == 254)
        #expect(candidates.allSatisfy { !$0.text.isEmpty && source.utf8.firstRange(of: $0.text.utf8) != nil })
    }

    @Test func derivationIsDeterministic() {
        let extraction = LineAndLabelCandidateExtraction()
        let item = ClipboardItem(text: Self.mixedSource)

        #expect(extraction.candidates(in: item) == extraction.candidates(in: item))
        #expect(
            extraction.candidates(in: item).map { Array($0.text.utf8) }
                == LineAndLabelCandidateExtraction().candidates(in: item).map { Array($0.text.utf8) }
        )
    }
}
