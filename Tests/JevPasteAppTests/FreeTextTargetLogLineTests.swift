import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The outcome log line carries Jev's free-text probability on every attempt that received a decision, so the
/// 0.8 threshold can be tuned from real use. Numbers and fixed names only.
@MainActor
struct FreeTextTargetLogLineTests {
    @Test(arguments: [
        (
            PasteAttemptOutcome.inserted, SmartPastePath.freeTextTarget(probability: 0.93),
            "outcome inserted via=freeTextTarget p=0.93"
        ),
        (.inserted, .freeTextTarget(probability: 0.8), "outcome inserted via=freeTextTarget p=0.80"),
        (.noSuitableMatch, .jev(freeTextProbability: 0.12), "outcome noSuitableMatch via=jev p=0.12"),
        (.inserted, .jev(freeTextProbability: 0.046), "outcome inserted via=jev p=0.05"),
        (.failed(.timedOut), .jev(freeTextProbability: nil), "outcome failed.timedOut via=jev"),
        (.inserted, .directPaste, "outcome inserted via=directPaste"),
    ])
    func theOutcomeLogLineCarriesTheFreeTextProbabilityWithTwoDecimals(
        outcome: PasteAttemptOutcome, path: SmartPastePath, line: String
    ) {
        #expect(IndicatorPresenter.outcomeLogLine(outcome, note: nil, path: path) == line)
    }

    @Test func theNoteFollowsTheProbability() {
        let line = IndicatorPresenter.outcomeLogLine(
            .inserted, note: .surroundingTextWithheld, path: .freeTextTarget(probability: 0.9)
        )
        #expect(line == "outcome inserted via=freeTextTarget p=0.90 note=surroundingTextWithheld")
    }
}
