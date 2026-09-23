import SmartPasteCore
import Testing

@testable import JevPasteApp

struct ChooserContentTests {
    @Test func singleLineCandidatesAreShownVerbatimInTheGivenOrder() {
        let content = ChooserContent(
            candidates: [Candidate(text: "maren.holtby@example.org"), Candidate(text: "  maren.h@example.net\t")],
            context: TargetContext()
        )

        #expect(content.rows == ["maren.holtby@example.org", "  maren.h@example.net\t"])
    }

    @Test func multiLineCandidateShowsItsFirstLineAndItsLineCount() {
        let content = ChooserContent(
            candidates: [Candidate(text: "Maren Holtby\nHoltby & Partner\n\nBerlin")], context: TargetContext()
        )

        #expect(content.rows == ["Maren Holtby … 4 lines"])
    }

    @Test func crlfLineBreaksCountAsOneLineBreakEach() {
        let content = ChooserContent(
            candidates: [Candidate(text: "Street 1\r\n10115 Berlin")], context: TargetContext())

        #expect(content.rows == ["Street 1 … 2 lines"])
    }

    @Test func titleNamesTheFieldLabel() {
        let content = ChooserContent(
            candidates: [], context: TargetContext(fieldLabel: "Email address", placeholder: "you@example.org")
        )

        #expect(content.title == "Which one for “Email address”?")
    }

    @Test func titleFallsBackToThePlaceholder() {
        let content = ChooserContent(candidates: [], context: TargetContext(placeholder: "Your email"))

        #expect(content.title == "Which one for “Your email”?")
    }

    @Test func titleWithoutLabelOrPlaceholderAsksPlainly() {
        let content = ChooserContent(candidates: [], context: TargetContext(fieldLabel: "  ", placeholder: ""))

        #expect(content.title == "Which one?")
    }
}
