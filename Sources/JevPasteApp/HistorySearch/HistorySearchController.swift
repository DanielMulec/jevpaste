import Foundation
import SmartPasteCore
import os

/// The History Search panel's logic. A status-item click opens it with the Active Item's first line as placeholder;
/// typing lists the newest matching Clipboard Items; a chosen row becomes the Active Item (nothing is pasted), the
/// panel closes, focus goes back to the app that was frontmost at open and the indicator names the new Active Item.
/// One Esc closes and hands focus back; a click elsewhere, or on the status item, just closes. The item block leads
/// to Settings or quits.
@MainActor
final class HistorySearchController {
    private struct OpenPanel {
        /// The app to hand focus back to after a choice or Esc; `nil` when no app was frontmost.
        let returningFocusTo: Int32?
        /// Clipboard History as read at open (and again after a copy): filtered in memory as the user types.
        var history: [HistoryEntry]
        var query = ""
        var highlighted: HistorySearchSelection?
    }

    private static let log = Logger(subsystem: "jevpaste", category: "HistorySearch")

    private let surface: any HistorySearchSurface
    private let history: any HistoryRepository
    private let capture: CopyCapture
    private let focusReturn: TargetAppFocusReturn
    private let activator: any ApplicationActivator
    private let notices: IndicatorNoticeSurface
    private let destinations: HistorySearchDestinations
    private let now: () -> Date
    /// The panel while it is open; `nil` once closed, so late events are ignored.
    private var openPanel: OpenPanel?

    init(
        surface: any HistorySearchSurface, history: any HistoryRepository, capture: CopyCapture,
        changes: ActiveItemChanges, focusReturn: TargetAppFocusReturn, activator: any ApplicationActivator,
        notices: IndicatorNoticeSurface, destinations: HistorySearchDestinations, now: @escaping () -> Date = Date.init
    ) {
        self.surface = surface
        self.history = history
        self.capture = capture
        self.focusReturn = focusReturn
        self.activator = activator
        self.notices = notices
        self.destinations = destinations
        self.now = now
        surface.forwardEvents { [weak self] event in
            self?.handle(event)
        }
        changes.observe { [weak self] change in
            self?.activeItemChanged(change)
        }
    }

    /// The status item was clicked: opens the panel, or closes it (without handing focus back) when it is open.
    func toggle() {
        guard openPanel == nil else {
            Self.log.notice("dismissed (status item)")
            return close(returningFocus: false)
        }
        openPanel = OpenPanel(returningFocusTo: activator.frontmostProcessIdentifier, history: history.entries())
        surface.open(content())
        Self.log.notice("opened over \(self.openPanel?.history.count ?? 0, privacy: .public) items")
    }

    private func handle(_ event: HistorySearchEvent) {
        guard let panel = openPanel else { return }
        switch event {
        case .queryChanged(let query):
            openPanel?.query = query
            openPanel?.highlighted = nil
            surface.show(content())
        case .moveUp: moveHighlight(by: -1)
        case .moveDown: moveHighlight(by: 1)
        case .confirm: panel.highlighted.map(choose) ?? chooseFirstRow()
        case .hover(let selection): highlight(selection)
        case .choose(let selection): choose(selection)
        case .dismiss(let dismissal):
            Self.log.notice("dismissed (\(dismissal.rawValue, privacy: .public))")
            // A click elsewhere put focus where the user wanted it; Esc means "back to where I was".
            close(returningFocus: dismissal == .escape)
        }
    }

    /// Every highlightable line in order: the rows, then the item block. ↓ from nothing goes to the first line and
    /// stops at the last; ↑ from the first line leaves nothing highlighted.
    private func moveHighlight(by step: Int) {
        let lines = selectableLines()
        let current = openPanel?.highlighted.flatMap(lines.firstIndex(of:))
        let next = current.map { $0 + step } ?? (step > 0 ? 0 : -1)
        highlight(lines.indices.contains(next) ? lines[next] : (next < 0 ? nil : lines.last))
    }

    private func highlight(_ selection: HistorySearchSelection?) {
        openPanel?.highlighted = selection
        surface.highlight(selection)
    }

    private func chooseFirstRow() {
        guard !matches().isEmpty else { return }
        choose(.row(0))
    }

    private func choose(_ selection: HistorySearchSelection) {
        switch selection {
        case .row(let row):
            guard let entry = matches().dropFirst(row).first else { return }
            Self.log.notice("selected row \(row, privacy: .public)")
            close(returningFocus: true)
            capture.select(entry.item)
        case .menuItem(let item):
            close(returningFocus: false)
            switch item {
            case .fullHistory: destinations.openSettings(.fullHistory)
            case .settings: destinations.openSettings(.general)
            case .quit: destinations.quit()
            }
        }
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

    /// A selection is confirmed on the indicator; an open panel re-reads history (a copy adds a row) and shows the
    /// new Active Item.
    private func activeItemChanged(_ change: ActiveItemChange) {
        if change.cause == .selected {
            notices.show(IndicatorNotice(activeItemSelected: change.item))
        }
        guard openPanel != nil else { return }
        openPanel?.history = history.entries()
        openPanel?.highlighted = nil
        surface.show(content())
    }

    private func content() -> HistorySearchContent {
        HistorySearchContent(
            query: openPanel?.query ?? "", history: openPanel?.history ?? [], activeItem: capture.activeItem,
            now: now()
        )
    }

    private func matches() -> [HistoryEntry] {
        guard let panel = openPanel else { return [] }
        return HistorySearch.results(for: panel.query, in: panel.history)?.matches ?? []
    }

    private func selectableLines() -> [HistorySearchSelection] {
        let content = content()
        return content.rows.indices.map(HistorySearchSelection.row)
            + content.menuItems.map(HistorySearchSelection.menuItem)
    }
}
