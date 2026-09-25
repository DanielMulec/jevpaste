import SmartPasteCore
import Testing

@testable import JevPasteApp

@MainActor
struct IndicatorPresenterTests {
    private let surface = RecordingIndicatorSurface()
    private let clock = SteppedClock()
    private let presenter: IndicatorPresenter

    init() {
        presenter = IndicatorPresenter(
            surface: surface, clock: clock,
            focusReturn: TargetAppFocusReturn(activator: FakeApplicationActivator(), clock: clock))
    }

    @Test func processingIsDisplayedAtOnce() {
        presenter.showProcessing {}

        #expect(surface.displayed == .processing(cancellable: true))
    }

    @Test func retryingReplacesProcessing() {
        presenter.showProcessing {}
        presenter.showRetrying()

        #expect(surface.displayed == .retrying(cancellable: true))
    }

    @Test func retryingBeforeProcessingOffersNoCancel() {
        presenter.showRetrying()
        surface.click()

        #expect(surface.displayed == .retrying(cancellable: false))
    }

    @Test func processingAfterAnEarlyRetryKeepsRetryingAndOffersCancel() {
        var cancels = 0
        presenter.showRetrying()
        presenter.showProcessing { cancels += 1 }
        surface.click()

        #expect(surface.displayed == .retrying(cancellable: true))
        #expect(cancels == 1)
    }

    @Test func insertedShowsTheCheckmarkForOneSecondThenHides() {
        presenter.showProcessing {}
        presenter.showOutcome(.inserted, note: nil, path: .jev())

        #expect(surface.displayed == OutcomeMessage(.inserted).content)
        clock.step(by: .milliseconds(999))
        #expect(surface.displayed != nil)
        clock.step(by: .milliseconds(1))
        #expect(surface.displayed == nil)
    }

    @Test func aReasonStaysForTwoAndAHalfSecondsThenHides() {
        presenter.showOutcome(.refused(.noEditableTarget), note: nil, path: nil)

        clock.step(by: .milliseconds(2499))
        #expect(surface.displayed == OutcomeMessage(.refused(.noEditableTarget)).content)
        clock.step(by: .milliseconds(1))
        #expect(surface.displayed == nil)
    }

    @Test func aNotedSuccessShowsItsNoteForTwoAndAHalfSeconds() {
        presenter.showOutcome(.inserted, note: .surroundingTextWithheld, path: .jev())

        clock.step(by: .milliseconds(2499))
        #expect(surface.displayed == OutcomeMessage(.inserted, note: .surroundingTextWithheld).content)
        clock.step(by: .milliseconds(1))
        #expect(surface.displayed == nil)
    }

    @Test func aNewAttemptKeepsItsIndicatorWhenTheEarlierOutcomeWouldHaveHidden() {
        presenter.showOutcome(.inserted, note: nil, path: .jev())
        clock.step(by: .milliseconds(500))
        presenter.showProcessing {}

        clock.step(by: .seconds(1))

        #expect(surface.displayed == .processing(cancellable: true))
    }

    @Test func clickingProcessingOrRetryingCancels() {
        var cancels = 0
        presenter.showProcessing { cancels += 1 }
        surface.click()
        presenter.showRetrying()
        surface.click()

        #expect(cancels == 2)
    }

    @Test func clickingAnOutcomeOrTheHiddenIndicatorDoesNothing() {
        var cancels = 0
        presenter.showProcessing { cancels += 1 }
        presenter.showOutcome(.failed(.timedOut), note: nil, path: .jev())
        surface.click()
        clock.step(by: .seconds(3))
        surface.click()

        #expect(cancels == 0)
    }

    @Test func hidingWhileChoosingRemovesTheIndicatorAndItsCancelUntilTheOutcome() {
        var cancels = 0
        presenter.showProcessing { cancels += 1 }
        presenter.hideWhileChoosing()
        surface.click()

        #expect(surface.displayed == nil)
        #expect(cancels == 0)
        presenter.showOutcome(.cancelled, note: nil, path: .jev())
        #expect(surface.displayed == OutcomeMessage(.cancelled).content)
    }

    @Test func hidingWhileChoosingCancelsAnArmedAutoHideSoTheLaterOutcomeStays() {
        presenter.showOutcome(.refused(.noEditableTarget), note: nil, path: nil)
        clock.step(by: .seconds(2))
        presenter.hideWhileChoosing()
        presenter.showOutcome(.inserted, note: nil, path: .jev())

        clock.step(by: .milliseconds(600))

        #expect(surface.displayed == OutcomeMessage(.inserted).content)
    }

    @Test(arguments: [false, true])
    func deliveryReplacesProcessingOrRetryingWithPastingThatNoClickCancels(afterRetrying: Bool) {
        var cancels = 0
        presenter.showProcessing { cancels += 1 }
        if afterRetrying { presenter.showRetrying() }
        presenter.showDelivering()
        surface.click()

        #expect(surface.displayed == .delivering)
        #expect(surface.displayed?.text.contains("cancel") == false)
        #expect(cancels == 0)
    }

    @Test func deliveryBeforeTheProcessingIndicatorOrAfterChoosingStaysHidden() {
        presenter.showDelivering()
        #expect(surface.displayed == nil)

        presenter.showProcessing {}
        presenter.hideWhileChoosing()
        presenter.showDelivering()
        #expect(surface.displayed == nil)
    }

    @Test func deliveryLeavesAnEarlierOutcomeAndItsAutoHideAlone() {
        presenter.showOutcome(.refused(.noEditableTarget), note: nil, path: nil)
        presenter.showDelivering()
        #expect(surface.displayed == OutcomeMessage(.refused(.noEditableTarget)).content)

        clock.step(by: .milliseconds(2500))
        #expect(surface.displayed == nil)
    }

    @Test func aDirectPasteShowsTheSameCheckmarkAsAJevPaste() {
        presenter.showOutcome(.inserted, note: nil, path: .directPaste)

        #expect(surface.displayed == OutcomeMessage(.inserted).content)
    }

    @Test(arguments: [
        (
            PasteAttemptOutcome.inserted, PasteAttemptNote?.none, SmartPastePath.directPaste,
            "outcome inserted via=directPaste"
        ),
        (.insertedWithoutRestore, nil, .directPaste, "outcome insertedWithoutRestore via=directPaste"),
        (.inserted, nil, .jev(), "outcome inserted via=jev"),
        (
            .noSuitableMatch, .surroundingTextWithheld, .jev(),
            "outcome noSuitableMatch via=jev note=surroundingTextWithheld"
        ),
    ])
    func theOutcomeLogLineNamesThePath(
        outcome: PasteAttemptOutcome, note: PasteAttemptNote?, path: SmartPastePath, line: String
    ) {
        #expect(IndicatorPresenter.outcomeLogLine(outcome, note: note, path: path) == line)
    }

    @Test func anOutcomeReachedBeforeAnyPathLogsNoPath() {
        #expect(
            IndicatorPresenter.outcomeLogLine(.refused(.secureField), note: nil, path: nil)
                == "outcome refused.secureField")
    }
}
