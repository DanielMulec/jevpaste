import SmartPasteCore
import os

/// Puts history notices on the one indicator without disturbing a Paste Attempt. It sits between the
/// `IndicatorPresenter` and the panel: whatever the presenter displays passes straight through and wins; a notice is
/// shown only while the presenter shows nothing, otherwise it waits until the presenter hides (only the newest
/// waiting notice is kept; each was logged when it happened).
@MainActor
final class HistoryNoticeSurface: IndicatorSurface {
    private static let log = Logger(subsystem: "jevpaste", category: "History")

    private let surface: any IndicatorSurface
    private let clock: any PasteAttemptClock
    private var presenterIsShowing = false
    private var waitingNotice: HistoryNotice?
    private var pendingNoticeHide: (any ScheduledAction)?

    init(wrapping surface: any IndicatorSurface, clock: any PasteAttemptClock) {
        self.surface = surface
        self.clock = clock
    }

    /// Shows `notice` now if the indicator is free, otherwise as soon as the presenter hides.
    func show(_ notice: HistoryNotice) {
        guard !presenterIsShowing else {
            Self.log.notice("history notice waits for the Paste Attempt's indicator")
            waitingNotice = notice
            return
        }
        display(notice)
    }

    func forwardClicks(to handler: @escaping @MainActor () -> Void) {
        surface.forwardClicks(to: handler)
    }

    func display(_ content: IndicatorContent) {
        cancelNoticeHide()
        presenterIsShowing = true
        surface.display(content)
    }

    /// Ends the presenter's display. A hide while the presenter shows nothing is stale (its display was already
    /// replaced) and is ignored, so it can never cut a notice short.
    func hide() {
        guard presenterIsShowing else { return }
        presenterIsShowing = false
        if let waitingNotice {
            self.waitingNotice = nil
            display(waitingNotice)
        } else {
            surface.hide()
        }
    }

    private func display(_ notice: HistoryNotice) {
        cancelNoticeHide()
        surface.display(notice.content)
        pendingNoticeHide = clock.schedule(after: notice.displayDuration) { [weak self] in
            self?.pendingNoticeHide = nil
            self?.surface.hide()
        }
    }

    private func cancelNoticeHide() {
        pendingNoticeHide?.cancel()
        pendingNoticeHide = nil
    }
}
