/// A short, informational line on the indicator that is not part of a Paste Attempt — a history failure, a missing
/// grant, an unavailable shortcut, a new Active Item. `IndicatorNoticeSurface` shows it without disturbing a Paste
/// Attempt.
struct IndicatorNotice: Equatable {
    let content: IndicatorContent
    let displayDuration: Duration

    static let warningSymbolName = "exclamationmark.triangle"

    /// A warning: the triangle symbol and one line of text.
    init(warning text: String, for displayDuration: Duration) {
        self.init(symbolName: Self.warningSymbolName, text: text, for: displayDuration)
    }

    /// Any SF Symbol and one line of text.
    init(symbolName: String, text: String, for displayDuration: Duration) {
        content = IndicatorContent(symbolName: symbolName, text: text)
        self.displayDuration = displayDuration
    }
}
