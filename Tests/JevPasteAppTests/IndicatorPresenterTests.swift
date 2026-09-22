import SmartPasteCore
import Testing

@testable import JevPasteApp

@MainActor
struct IndicatorPresenterTests {
    private let surface = RecordingIndicatorSurface()
    private let clock = SteppedClock()
    private let presenter: IndicatorPresenter

    init() {
        presenter = IndicatorPresenter(surface: surface, clock: clock)
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
        presenter.showOutcome(.inserted)

        #expect(surface.displayed == OutcomeMessage(.inserted).content)
        clock.step(by: .milliseconds(999))
        #expect(surface.displayed != nil)
        clock.step(by: .milliseconds(1))
        #expect(surface.displayed == nil)
    }

    @Test func aReasonStaysForTwoAndAHalfSecondsThenHides() {
        presenter.showOutcome(.refused(.noEditableTarget))

        clock.step(by: .milliseconds(2499))
        #expect(surface.displayed == OutcomeMessage(.refused(.noEditableTarget)).content)
        clock.step(by: .milliseconds(1))
        #expect(surface.displayed == nil)
    }

    @Test func aNewAttemptKeepsItsIndicatorWhenTheEarlierOutcomeWouldHaveHidden() {
        presenter.showOutcome(.inserted)
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
        presenter.showOutcome(.failed(.timedOut))
        surface.click()
        clock.step(by: .seconds(3))
        surface.click()

        #expect(cancels == 0)
    }
}
