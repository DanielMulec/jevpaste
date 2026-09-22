/// Where the indicator is drawn: in the app, a non-activating panel below the status item.
@MainActor
protocol IndicatorSurface {
    /// Calls `handler` whenever the user clicks the indicator. The click never makes the app active or the
    /// indicator key.
    func forwardClicks(to handler: @escaping @MainActor () -> Void)
    /// Shows `content` at once, replacing whatever was shown.
    func display(_ content: IndicatorContent)
    func hide()
}
