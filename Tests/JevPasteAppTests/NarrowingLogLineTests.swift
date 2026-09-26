import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The outcome log line says what Narrowing did: its steps, its calls, Jev's probability of the deciding option, the
/// questions per step, the Candidate Chooser's fill and the full-text requests. Numbers and fixed names only, never
/// text.
@MainActor
struct NarrowingLogLineTests {
    private typealias Step = NarrowingTrace.Step

    private nonisolated static let oneStep = [
        Step(questions: 1, followUpSpeculativeQuestions: nil, isSpeculative: false)
    ]
    /// The 300-line list of the spike (N03): two choices and a follow-up with no speculation, then two choices and a
    /// follow-up with two speculative next steps, then a step decided by one of them.
    private nonisolated static let longList = [
        Step(questions: 2, followUpSpeculativeQuestions: 0, isSpeculative: false),
        Step(questions: 2, followUpSpeculativeQuestions: 2, isSpeculative: false),
        Step(questions: 0, followUpSpeculativeQuestions: nil, isSpeculative: true),
    ]

    @Test(arguments: [
        (
            PasteAttemptOutcome.inserted,
            SmartPastePath(narrowing: NarrowingTrace(steps: oneStep, decidingProbability: 0.93), calls: 1),
            "outcome inserted via=narrowing steps=1 calls=1 p=0.93 questions=1"
        ),
        (
            .inserted,
            SmartPastePath(
                narrowing: NarrowingTrace(steps: longList, fullTextRequests: 2, decidingProbability: 0.046), calls: 4
            ),
            "outcome inserted via=narrowing steps=3 calls=4 p=0.05 questions=2+f0,2+f2,s full=2"
        ),
        (
            .inserted,
            SmartPastePath(
                narrowing: NarrowingTrace(
                    steps: oneStep, fullTextRequests: 4, decidingProbability: 0.71,
                    chooserFill: ChooserFillTrace(calls: 3, end: .nothingFits)),
                calls: 4
            ),
            "outcome inserted via=narrowing steps=1 calls=4 p=0.71 questions=1 fill=3 fillEnd=nothingFits full=4"
        ),
        (
            .cancelled,
            SmartPastePath(
                narrowing: NarrowingTrace(
                    steps: oneStep, decidingProbability: 0.6, chooserFill: ChooserFillTrace(calls: 2, end: .clock)),
                calls: 3
            ),
            "outcome cancelled via=narrowing steps=1 calls=3 p=0.60 questions=1 fill=2 fillEnd=clock"
        ),
        (
            .failed(.timedOut), SmartPastePath(narrowing: NarrowingTrace(steps: oneStep), calls: 2),
            "outcome failed.timedOut via=narrowing steps=1 calls=2 questions=1"
        ),
        (
            .failed(.tooLongForSmartPaste), SmartPastePath(narrowing: NarrowingTrace(steps: oneStep), calls: 1),
            "outcome failed.tooLongForSmartPaste via=narrowing steps=1 calls=1 questions=1"
        ),
    ])
    func theOutcomeLogLineSaysWhatNarrowingDid(outcome: PasteAttemptOutcome, path: SmartPastePath, line: String) {
        #expect(IndicatorPresenter.outcomeLogLine(outcome, note: nil, path: path) == line)
    }

    @Test func theNoteFollowsThePath() {
        let path = SmartPastePath(narrowing: NarrowingTrace(steps: Self.oneStep, decidingProbability: 0.9), calls: 1)

        let line = IndicatorPresenter.outcomeLogLine(.inserted, note: .surroundingTextWithheld, path: path)

        #expect(
            line == "outcome inserted via=narrowing steps=1 calls=1 p=0.90 questions=1 note=surroundingTextWithheld")
    }
}
