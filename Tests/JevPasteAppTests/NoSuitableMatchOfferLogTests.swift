import SmartPasteCore
import Testing

@testable import JevPasteApp

/// How the outcome log line reports the No Suitable Match offer: enums only, never item text.
@MainActor
struct NoSuitableMatchOfferLogTests {
    private nonisolated static let nothingFits = NarrowingTrace(
        steps: [.init(questions: 1, followUpSpeculativeQuestions: nil, isSpeculative: false)], decidingProbability: 0.12
    )

    @Test(
        arguments: [
            (
                PasteAttemptOutcome.inserted, NoSuitableMatchOfferEnd.accepted,
                "outcome inserted via=directPaste reason=enterAfterNoMatch p=0.12"
            ),
            (
                .failed(.targetChanged), .accepted,
                "outcome failed.targetChanged via=directPaste reason=enterAfterNoMatch p=0.12"
            ),
            (
                .noSuitableMatch, .dismissed,
                "outcome noSuitableMatch via=narrowing steps=1 calls=1 p=0.12 questions=1 offer=dismissed"
            ),
            (
                .noSuitableMatch, .timedOut,
                "outcome noSuitableMatch via=narrowing steps=1 calls=1 p=0.12 questions=1 offer=timedOut"
            ),
        ])
    func theOutcomeLogLineNamesHowTheOfferEnded(
        outcome: PasteAttemptOutcome, end: NoSuitableMatchOfferEnd, line: String
    ) {
        let path = SmartPastePath(narrowing: Self.nothingFits, calls: 1, noSuitableMatchOfferEnd: end)
        #expect(IndicatorPresenter.outcomeLogLine(outcome, note: nil, path: path) == line)
    }
}
