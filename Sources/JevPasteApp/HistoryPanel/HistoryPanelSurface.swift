/// What the user did in the open history panel.
enum HistoryPanelEvent: Equatable {
    /// The search field's text changed.
    case queryChanged(String)
    case moveUp
    case moveDown
    /// Return or Enter on the highlighted row.
    case chooseHighlighted
    /// A click on a row.
    case choose(row: Int)
    /// ⌘⌫, or ⌫ while the search field is empty.
    case deleteHighlighted
    /// A click on a row's ✕.
    case delete(row: Int)
    /// "Clear History…" in the footer; asks for confirmation first.
    case clearAllRequested
    case clearAllConfirmed
    case clearAllCancelled
    case dismiss(HistoryPanelDismissal)
}

/// How the user closed the history panel without choosing.
enum HistoryPanelDismissal: String, Equatable {
    case escape = "esc"
    /// The panel stopped being key: the user clicked another window or app.
    case clickAway = "click-away"
}

/// Where the history panel is drawn: in the app, a key-capable, non-activating panel below the status item.
@MainActor
protocol HistoryPanelSurface {
    /// Calls `handler` for every key, click, query change and click-away while the panel is open.
    func forwardEvents(to handler: @escaping @MainActor (HistoryPanelEvent) -> Void)
    /// Shows `content` with an empty search field and takes key focus, so typing reaches the search field.
    func open(_ content: HistoryPanelContent, highlighting row: Int?)
    /// Replaces the Active Item block and the rows in place (after a query change, a delete or a copy).
    func show(_ content: HistoryPanelContent, highlighting row: Int?)
    func highlight(_ row: Int?)
    /// Swaps the footer for "Delete all N items?" with Cancel and a destructive Clear button.
    func askToConfirmClearAll(itemCount: Int)
    /// Brings the footer back after the confirmation was answered.
    func endClearAllConfirmation()
    /// Hides the panel and gives up key focus.
    func close()
}
