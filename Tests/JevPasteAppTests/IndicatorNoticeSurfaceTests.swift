import HistoryStore
import Testing

@testable import JevPasteApp

/// A history notice shares the one indicator with the Paste Attempt without ever disturbing it.
@MainActor
struct IndicatorNoticeSurfaceTests {
    private let screen = RecordingIndicatorSurface()
    private let clock = SteppedClock()
    private let notices: IndicatorNoticeSurface
    private let presenter: IndicatorPresenter

    private let writeFailed = IndicatorNotice(historyRuntimeFailure: .sqlite(operation: "record", resultCode: 8))
    private let readFailed = IndicatorNotice(historyRuntimeFailure: .sqlite(operation: "items", resultCode: 26))
    private let unavailable = IndicatorNotice(historyUnavailable: .fileNotCreated)

    init() {
        notices = IndicatorNoticeSurface(wrapping: screen, clock: clock)
        presenter = IndicatorPresenter(surface: notices, clock: clock)
    }

    @Test func noticeOnAnIdleIndicatorShowsAtOnceForItsDuration() {
        notices.show(writeFailed)

        #expect(screen.displayed == writeFailed.content)
        clock.step(by: .milliseconds(2499))
        #expect(screen.displayed == writeFailed.content)
        clock.step(by: .milliseconds(1))
        #expect(screen.displayed == nil)
    }

    @Test func unavailableNoticeAtLaunchStaysForFiveSeconds() {
        notices.show(unavailable)

        clock.step(by: .milliseconds(4999))
        #expect(screen.displayed == unavailable.content)
        clock.step(by: .milliseconds(1))
        #expect(screen.displayed == nil)
    }

    @Test func noticeDuringProcessingWaitsUntilTheOutcomeHasHidden() {
        presenter.showProcessing {}
        notices.show(writeFailed)
        #expect(screen.displayed == .processing(cancellable: true))

        presenter.showOutcome(.inserted, note: nil)
        #expect(screen.displayed == OutcomeMessage(.inserted).content)

        clock.step(by: .seconds(1))
        #expect(screen.displayed == writeFailed.content)
        clock.step(by: .milliseconds(2500))
        #expect(screen.displayed == nil)
    }

    @Test func noticeDuringRetryingOrAnOutcomeWaitsToo() {
        presenter.showRetrying()
        notices.show(writeFailed)
        #expect(screen.displayed == .retrying(cancellable: false))

        presenter.showOutcome(.noSuitableMatch, note: nil)
        notices.show(readFailed)
        #expect(screen.displayed == OutcomeMessage(.noSuitableMatch).content)

        clock.step(by: .milliseconds(2500))
        #expect(screen.displayed == readFailed.content)
    }

    @Test func aNewAttemptReplacesTheNoticeAndItsTimerNeverHidesTheAttempt() {
        notices.show(writeFailed)
        clock.step(by: .seconds(1))

        presenter.showProcessing {}
        #expect(screen.displayed == .processing(cancellable: true))

        clock.step(by: .seconds(5))
        #expect(screen.displayed == .processing(cancellable: true))
    }

    @Test func aStalePresenterHideLeavesAShowingNoticeForItsFullDuration() {
        notices.show(writeFailed)

        notices.hide()
        #expect(screen.displayed == writeFailed.content)

        clock.step(by: .milliseconds(2500))
        #expect(screen.displayed == nil)
    }

    @Test func clickingProcessingThroughTheNoticeSurfaceStillCancels() {
        var cancels = 0
        presenter.showProcessing { cancels += 1 }

        screen.click()

        #expect(cancels == 1)
    }
}
