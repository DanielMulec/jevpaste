import SmartPasteCore
import Testing

@Test func idleAndInProgressAreNotFinished() {
    #expect(!PasteAttemptState.idle.isFinished)
    #expect(!PasteAttemptState.inProgress.isFinished)
}

@Test(arguments: [
    PasteAttemptState.inserted, .noSuitableMatch, .refused, .cancelled, .failed,
])
func visibleOutcomesAreFinished(state: PasteAttemptState) {
    #expect(state.isFinished)
}
