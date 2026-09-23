/// A short, informational line on the indicator that is not part of a Paste Attempt — a history failure, a missing
/// grant, an unavailable shortcut. `IndicatorNoticeSurface` shows it without disturbing a Paste Attempt.
struct IndicatorNotice: Equatable {
    let content: IndicatorContent
    let displayDuration: Duration

    static let warningSymbolName = "exclamationmark.triangle"

    /// A warning: the triangle symbol and one line of text.
    init(warning text: String, for displayDuration: Duration) {
        content = IndicatorContent(symbolName: Self.warningSymbolName, text: text)
        self.displayDuration = displayDuration
    }
}
