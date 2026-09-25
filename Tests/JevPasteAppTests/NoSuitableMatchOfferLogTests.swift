import SmartPasteCore
import Testing

@testable import JevPasteApp

/// How the outcome log line reports the No Suitable Match offer: enums only, never item text.
@MainActor
struct NoSuitableMatchOfferLogTests {
    @Test(
        arguments: [
            (
                PasteAttemptOutcome.inserted, NoSuitableMatchOfferEnd.accepted,
                "outcome inserted via=directPaste reason=enterAfterNoMatch"
            ),
            (
                .failed(.targetChanged), .accepted,
                "outcome failed.targetChanged via=directPaste reason=enterAfterNoMatch"
            ),
            (.noSuitableMatch, .dismissed, "outcome noSuitableMatch via=jev offer=dismissed"),
            (.noSuitableMatch, .timedOut, "outcome noSuitableMatch via=jev offer=timedOut"),
        ])
    func theOutcomeLogLineNamesHowTheOfferEnded(
        outcome: PasteAttemptOutcome, end: NoSuitableMatchOfferEnd, line: String
    ) {
        #expect(IndicatorPresenter.outcomeLogLine(outcome, note: nil, path: .jev(offer: end)) == line)
    }

    @Test(
        arguments: [
            (
                PasteAttemptOutcome.noSuitableMatch, NoSuitableMatchOfferEnd?.some(.dismissed),
                "outcome noSuitableMatch via=jev p=0.12 offer=dismissed"
            ),
            (.inserted, .accepted, "outcome inserted via=directPaste reason=enterAfterNoMatch p=0.12"),
            (.inserted, nil, "outcome inserted via=jev p=0.12"),
        ])
    func jevsFreeTextProbabilitySurvivesTheOffer(
        outcome: PasteAttemptOutcome, end: NoSuitableMatchOfferEnd?, line: String
    ) {
        let path = SmartPastePath.jev(freeTextProbability: 0.12, offer: end)
        #expect(IndicatorPresenter.outcomeLogLine(outcome, note: nil, path: path) == line)
    }
}
