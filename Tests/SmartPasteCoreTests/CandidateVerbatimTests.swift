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
        let candidates = StructuralCandidateExtraction().candidates(in: ClipboardItem(text: Self.mixedSource))
        #expect(candidates.count == 17)  // 14 lines and values, 2 paragraphs, the whole item

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

        let candidates = StructuralCandidateExtraction().candidates(in: ClipboardItem(text: source))

        #expect(candidates.count == 254)
        #expect(candidates.allSatisfy { !$0.text.isEmpty && source.utf8.firstRange(of: $0.text.utf8) != nil })
    }

    @Test func derivationIsDeterministic() {
        let extraction = StructuralCandidateExtraction()
        let item = ClipboardItem(text: Self.mixedSource)

        #expect(extraction.candidates(in: item) == extraction.candidates(in: item))
        #expect(
            extraction.candidates(in: item).map { Array($0.text.utf8) }
                == StructuralCandidateExtraction().candidates(in: item).map { Array($0.text.utf8) }
        )
    }

    static let addressParagraph = "221B Baker Street\r\n\tMarylebone\r\nLondon NW1 6XE"
    static let resume = [
        "Ada Lovelace", "Email: ada@example.com", "", " \(addressParagraph) ", "", "EXPERIENCE",
        "Lead, Analytical Engines", "Author, Notes on the Engine",
    ].joined(separator: "\r\n")

    static let resumeCandidates = StructuralCandidateExtraction().candidates(in: ClipboardItem(text: resume))

    /// Presses ⌘⇧V over `resume` and lets the fake Jev choose `excerpt`, through the Restore Window.
    private func deliverFromResume(_ excerpt: String) -> PasteAttemptHarness {
        let harness = PasteAttemptHarness(candidates: Self.resumeCandidates, sourceText: Self.resume)
        harness.pasteChoosing(excerpt)
        harness.clock.advance(by: .milliseconds(120))
        return harness
    }

    /// The UTF-8 bytes of the first clipboard write of `harness`'s Paste Attempt.
    private func firstWrittenBytes(of harness: PasteAttemptHarness) -> [UInt8]? {
        guard case .write(let written) = harness.log.steps.first else { return nil }
        return Array(written.utf8)
    }

    @Test func paragraphIsTheAnswerInAMixedDocumentAndIsDeliveredVerbatim() {
        let harness = deliverFromResume(Self.addressParagraph)

        #expect(Self.resumeCandidates.contains { $0.text.utf8.elementsEqual(Self.addressParagraph.utf8) })
        #expect(firstWrittenBytes(of: harness) == Array(Self.addressParagraph.utf8))
        #expect(harness.presenter.outcomes == [.inserted])
    }

    @Test func wholeItemIsTheAnswerInAMixedDocumentAndIsDeliveredVerbatim() {
        let harness = deliverFromResume(Self.resume)

        #expect(Self.resumeCandidates.first?.text.utf8.elementsEqual(Self.resume.utf8) == true)
        #expect(firstWrittenBytes(of: harness) == Array(Self.resume.utf8))
        #expect(harness.presenter.outcomes == [.inserted])
    }
}
