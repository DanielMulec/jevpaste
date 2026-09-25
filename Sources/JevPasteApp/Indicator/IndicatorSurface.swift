/// Where the indicator is drawn: in the app, a non-activating panel below the status item.
@MainActor
protocol IndicatorSurface {
    /// Calls `handler` whenever the user clicks the indicator. The click never makes the app active or the
    /// indicator key.
    func forwardClicks(to handler: @escaping @MainActor () -> Void)
    /// Calls `handler` for Enter, Esc and click-away while the indicator holds key focus (see
    /// `displayTakingKeyFocus`).
    func forwardOfferEvents(to handler: @escaping @MainActor (IndicatorOfferEvent) -> Void)
    /// Shows `content` at once, replacing whatever was shown, without key focus.
    func display(_ content: IndicatorContent)
    /// Shows `content` and takes key focus without activating the app, so Enter and Esc reach the indicator and
    /// never the Target. The next `display` or `hide` gives key focus up.
    func displayTakingKeyFocus(_ content: IndicatorContent)
    func hide()
}

/// What the user did while the indicator offered to paste everything after No Suitable Match.
enum IndicatorOfferEvent: Equatable {
    /// Return or Enter.
    case accept
    case dismiss(KeyPanelDismissal)
}
