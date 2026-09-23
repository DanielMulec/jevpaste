/// What the user did in the open Candidate Chooser.
enum ChooserEvent: Equatable {
    case moveUp
    case moveDown
    /// Return or Enter on the selected row.
    case chooseSelected
    /// A click on a row.
    case choose(row: Int)
    case cancel(ChooserCancellation)
}

/// How the user dismissed the chooser without choosing.
enum ChooserCancellation: String, Equatable {
    case escape = "esc"
    /// The chooser stopped being key: the user clicked another window or app.
    case clickAway = "click-away"
}

/// Where the Candidate Chooser is drawn: in the app, a key-capable, non-activating panel below the status item.
@MainActor
protocol ChooserSurface {
    /// Calls `handler` for every key, row click and click-away while the chooser is open.
    func forwardEvents(to handler: @escaping @MainActor (ChooserEvent) -> Void)
    /// Shows `content` with `row` selected and takes key focus, so keys reach the chooser.
    func open(_ content: ChooserContent, selecting row: Int)
    func select(_ row: Int)
    /// Hides the chooser and gives up key focus.
    func close()
}
