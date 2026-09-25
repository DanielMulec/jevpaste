import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The outcome log line says how long the attempt waited for a readable focus, in whole milliseconds, and only when
/// it waited. Numbers and fixed names only.
@MainActor
struct WakeWaitLogLineTests {
    @Test(arguments: [
        (
            PasteAttemptOutcome.inserted, SmartPastePath?.some(.directPaste), Duration?.some(.milliseconds(312)),
            "outcome inserted via=directPaste wakeWait=312"
        ),
        (
            .refused(.targetNotReady(applicationName: "ChatGPT")), nil, .seconds(3),
            "outcome refused.targetNotReady wakeWait=3000"
        ),
        (
            .inserted, .jev(freeTextProbability: 0.2), .microseconds(45_900),
            "outcome inserted via=jev p=0.20 wakeWait=45"
        ),
        (.inserted, .directPaste, nil, "outcome inserted via=directPaste"),
    ])
    func theOutcomeLineCarriesTheWakeWaitInWholeMillisecondsOnlyWhenTheAttemptWaited(
        outcome: PasteAttemptOutcome, path: SmartPastePath?, wakeWait: Duration?, line: String
    ) {
        #expect(IndicatorPresenter.outcomeLogLine(outcome, note: nil, path: path, wakeWait: wakeWait) == line)
    }

    @Test func theWakeWaitComesBeforeTheNote() {
        let line = IndicatorPresenter.outcomeLogLine(
            .inserted, note: .surroundingTextWithheld, path: .jev(freeTextProbability: 0.2), wakeWait: .milliseconds(50)
        )

        #expect(line == "outcome inserted via=jev p=0.20 wakeWait=50 note=surroundingTextWithheld")
    }
}
