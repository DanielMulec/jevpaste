import SmartPasteCore
import os

/// Puts notices (history failures, a missing grant, an unavailable shortcut) on the one indicator without disturbing
/// a Paste Attempt. It sits between the `IndicatorPresenter` and the panel: whatever the presenter displays passes
/// straight through and wins; a notice is shown only while the presenter shows nothing, otherwise it waits until the
/// presenter hides (only the newest waiting notice is kept; each was logged when it happened).
@MainActor
final class IndicatorNoticeSurface: IndicatorSurface {
    private static let log = Logger(subsystem: "jevpaste", category: "Indicator")

    private let surface: any IndicatorSurface
    private let clock: any PasteAttemptClock
    private var presenterIsShowing = false
    private var waitingNotice: IndicatorNotice?
    private var pendingNoticeHide: (any ScheduledAction)?

    init(wrapping surface: any IndicatorSurface, clock: any PasteAttemptClock) {
        self.surface = surface
        self.clock = clock
    }

    /// Shows `notice` now if the indicator is free, otherwise as soon as the presenter hides.
    func show(_ notice: IndicatorNotice) {
        guard !presenterIsShowing else {
            Self.log.notice("notice waits for the Paste Attempt's indicator")
            waitingNotice = notice
            return
        }
        display(notice)
    }

    func forwardClicks(to handler: @escaping @MainActor () -> Void) {
        surface.forwardClicks(to: handler)
    }

    func forwardOfferEvents(to handler: @escaping @MainActor (IndicatorOfferEvent) -> Void) {
        surface.forwardOfferEvents(to: handler)
    }

    func display(_ content: IndicatorContent) {
        cancelNoticeHide()
        presenterIsShowing = true
        surface.display(content)
    }

    func displayTakingKeyFocus(_ content: IndicatorContent) {
        cancelNoticeHide()
        presenterIsShowing = true
        surface.displayTakingKeyFocus(content)
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

    private func display(_ notice: IndicatorNotice) {
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
