/// A highlightable line of the History Search panel: a matching row, or an item of the block under the rows.
enum HistorySearchSelection: Equatable {
    case row(Int)
    case menuItem(HistorySearchMenuItem)
}

/// What the user did in the open History Search panel.
enum HistorySearchEvent: Equatable {
    /// The search field's text changed.
    case queryChanged(String)
    case moveUp
    case moveDown
    /// Return or Enter: the highlighted line, else the first row.
    case confirm
    /// The pointer entered a line.
    case hover(HistorySearchSelection)
    /// A click on a line.
    case choose(HistorySearchSelection)
    case dismiss(KeyPanelDismissal)
}

/// Where the History Search panel is drawn: in the app, a menu-shaped, key-capable, non-activating panel under the
/// status item.
@MainActor
protocol HistorySearchSurface {
    /// Calls `handler` for every key, query change, hover, click and click-away while the panel is open.
    func forwardEvents(to handler: @escaping @MainActor (HistorySearchEvent) -> Void)
    /// Shows `content` with an empty search field and takes key focus, so typing reaches the field.
    func open(_ content: HistorySearchContent)
    /// Replaces everything under the field (after typing or a copy), with nothing highlighted; the field stays.
    func show(_ content: HistorySearchContent)
    func highlight(_ selection: HistorySearchSelection?)
    /// Hides the panel and gives up key focus.
    func close()
}

/// Where the panel's item block leads: Settings (at a tab) and quitting the app.
struct HistorySearchDestinations {
    let openSettings: @MainActor (SettingsSection) -> Void
    let quit: @MainActor () -> Void
}
