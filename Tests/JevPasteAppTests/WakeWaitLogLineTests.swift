import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The outcome log line says how long the attempt waited for a readable focus, in whole milliseconds, and only when
/// it waited. Numbers and fixed names only.
@MainActor
struct WakeWaitLogLineTests {
    private nonisolated static let kept = SmartPastePath(
        narrowing: NarrowingTrace(
            steps: [.init(questions: 1, followUpSpeculativeQuestions: nil, isSpeculative: false)],
            decidingProbability: 0.2
        ),
        calls: 1
    )

    @Test(arguments: [
        (
            PasteAttemptOutcome.inserted, SmartPastePath?.some(kept), Duration?.some(.milliseconds(312)),
            "outcome inserted via=narrowing steps=1 calls=1 p=0.20 questions=1 wakeWait=312"
        ),
        (
            .refused(.targetNotReady(applicationName: "ChatGPT")), nil, .seconds(3),
            "outcome refused.targetNotReady wakeWait=3000"
        ),
        (
            .inserted, kept, .microseconds(45_900),
            "outcome inserted via=narrowing steps=1 calls=1 p=0.20 questions=1 wakeWait=45"
        ),
        (.inserted, kept, nil, "outcome inserted via=narrowing steps=1 calls=1 p=0.20 questions=1"),
    ])
    func theOutcomeLineCarriesTheWakeWaitInWholeMillisecondsOnlyWhenTheAttemptWaited(
        outcome: PasteAttemptOutcome, path: SmartPastePath?, wakeWait: Duration?, line: String
    ) {
        #expect(IndicatorPresenter.outcomeLogLine(outcome, note: nil, path: path, wakeWait: wakeWait) == line)
    }

    @Test func theWakeWaitComesBeforeTheNote() {
        let line = IndicatorPresenter.outcomeLogLine(
            .inserted, note: .surroundingTextWithheld, path: Self.kept, wakeWait: .milliseconds(50)
        )

        let expected = "outcome inserted via=narrowing steps=1 calls=1 p=0.20 questions=1 wakeWait=50"
        #expect(line == expected + " note=surroundingTextWithheld")
    }
}
