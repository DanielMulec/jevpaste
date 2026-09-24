import SmartPasteCore
import os

/// The history panel's logic: shows Clipboard History with the pinned Active Item, filters it as the user types,
/// makes the chosen item Active (Rejev-paste), deletes items and — after a confirmation — clears it all.
/// Choosing or Esc closes the panel and hands focus back to the app that was frontmost when it opened; a click
/// elsewhere just closes it. After a selection the indicator briefly names the new Active Item.
@MainActor
final class HistoryPanelController {
    private struct OpenPanel {
        /// The app to hand focus back to on Enter or Esc; `nil` when no app was frontmost.
        let returningFocusTo: Int32?
        var query = ""
        var matches: [ClipboardItem] = []
        var highlighted: Int?
        var isAskingToClearAll = false
    }

    private static let log = Logger(subsystem: "jevpaste", category: "HistoryPanel")

    private let surface: any HistoryPanelSurface
    private let history: any HistoryRepository
    private let capture: CopyCapture
    private let focusReturn: TargetAppFocusReturn
    private let activator: any ApplicationActivator
    private let notices: IndicatorNoticeSurface
    /// The panel while it is open; `nil` once closed, so late events are ignored.
    private var openPanel: OpenPanel?

    init(
        surface: any HistoryPanelSurface, history: any HistoryRepository, capture: CopyCapture,
        focusReturn: TargetAppFocusReturn, activator: any ApplicationActivator, notices: IndicatorNoticeSurface
    ) {
        self.surface = surface
        self.history = history
        self.capture = capture
        self.focusReturn = focusReturn
        self.activator = activator
        self.notices = notices
        surface.forwardEvents { [weak self] event in
            self?.handle(event)
        }
        capture.observeActiveItemChanges { [weak self] change in
            self?.activeItemChanged(change)
        }
    }

    /// Opens the panel with an empty query and the newest item highlighted; does nothing while it is open.
    func open() {
        guard openPanel == nil else { return }
        openPanel = OpenPanel(returningFocusTo: activator.frontmostProcessIdentifier)
        let content = refreshedContent(highlighting: 0)
        surface.open(content, highlighting: openPanel?.highlighted)
        Self.log.notice("opened with \(content.rows.count, privacy: .public) rows")
    }

    private func handle(_ event: HistoryPanelEvent) {
        guard let panel = openPanel else { return }
        switch event {
        case .queryChanged(let query):
            openPanel?.query = query
            show(highlighting: 0)
        case .moveUp: moveHighlight(by: -1)
        case .moveDown: moveHighlight(by: 1)
        case .chooseHighlighted: chooseHighlighted(in: panel)
        case .choose(let row): choose(row: row)
        case .deleteHighlighted: panel.highlighted.map(delete(row:))
        case .delete(let row): delete(row: row)
        case .clearAllRequested, .clearAllConfirmed, .clearAllCancelled:
            handleClearAll(event, asking: panel.isAskingToClearAll)
        case .dismiss(let dismissal): dismiss(dismissal, asking: panel.isAskingToClearAll)
        }
    }

    /// Clear-all needs two steps: the request asks, and only a confirmation of that question clears.
    private func handleClearAll(_ event: HistoryPanelEvent, asking isAsking: Bool) {
        switch event {
        case .clearAllRequested: askToClearAll()
        case .clearAllConfirmed where isAsking: clearAll()
        case .clearAllCancelled: endAskingToClearAll()
        default: break
        }
    }

    private func moveHighlight(by step: Int) {
        guard let panel = openPanel, let highlighted = panel.highlighted else { return }
        let moved = min(max(highlighted + step, 0), panel.matches.count - 1)
        openPanel?.highlighted = moved
        surface.highlight(moved)
    }

    /// Enter never answers the clear-all question — only its buttons do, and Esc withdraws it — and it does not
    /// select the row behind the question either: while asking, Enter is ignored.
    private func chooseHighlighted(in panel: OpenPanel) {
        guard !panel.isAskingToClearAll, let row = panel.highlighted else { return }
        choose(row: row)
    }

    private func choose(row: Int) {
        guard let panel = openPanel, panel.matches.indices.contains(row) else { return }
        Self.log.notice("selected row \(row, privacy: .public)")
        close(returningFocus: true)
        capture.select(panel.matches[row])
    }

    private func delete(row: Int) {
        guard let panel = openPanel, panel.matches.indices.contains(row) else { return }
        history.delete(panel.matches[row])
        Self.log.notice("deleted one item")
        show(highlighting: row)
    }

    private func askToClearAll() {
        let count = history.items().count
        guard count > 0 else { return }
        openPanel?.isAskingToClearAll = true
        surface.askToConfirmClearAll(itemCount: count)
    }

    private func endAskingToClearAll() {
        openPanel?.isAskingToClearAll = false
        surface.endClearAllConfirmation()
    }

    private func clearAll() {
        history.clearAll()
        Self.log.notice("cleared all")
        endAskingToClearAll()
        show(highlighting: 0)
    }

    /// Esc first withdraws an open clear-all question; otherwise it closes, like a click elsewhere.
    private func dismiss(_ dismissal: HistoryPanelDismissal, asking isAsking: Bool) {
        if dismissal == .escape && isAsking { return endAskingToClearAll() }
        Self.log.notice("dismissed (\(dismissal.rawValue, privacy: .public))")
        // A click elsewhere put focus where the user wanted it; Esc means "back to where I was".
        close(returningFocus: dismissal == .escape)
    }

    private func close(returningFocus: Bool) {
        guard let panel = openPanel else { return }
        openPanel = nil
        surface.close()
        guard returningFocus, let processIdentifier = panel.returningFocusTo else { return }
        focusReturn.returnFocus(to: processIdentifier) { result in
            Self.log.notice("focus return \(String(describing: result), privacy: .public)")
        }
    }

    private func activeItemChanged(_ change: ActiveItemChange) {
        if change.cause == .selected {
            notices.show(IndicatorNotice(activeItemSelected: change.item))
        }
        guard let panel = openPanel else { return }
        // Keep the highlight on the same item, not the same index: a copy inserts a row above it.
        let highlightedItem = panel.highlighted.map { panel.matches[$0] }
        let content = refreshedContent(highlighting: panel.highlighted ?? 0)
        if let highlightedItem, let row = openPanel?.matches.firstIndex(of: highlightedItem) {
            openPanel?.highlighted = row
        }
        surface.show(content, highlighting: openPanel?.highlighted)
    }

    /// Re-reads history for the current query and shows it, keeping the highlight at `row` or the last row.
    private func show(highlighting row: Int) {
        let content = refreshedContent(highlighting: row)
        surface.show(content, highlighting: openPanel?.highlighted)
    }

    private func refreshedContent(highlighting row: Int) -> HistoryPanelContent {
        let query = openPanel?.query ?? ""
        let matches = HistoryPanelContent.items(in: history.items(), matching: query)
        openPanel?.matches = matches
        openPanel?.highlighted = matches.isEmpty ? nil : min(row, matches.count - 1)
        return HistoryPanelContent(matches: matches, activeItem: capture.activeItem, query: query)
    }
}
