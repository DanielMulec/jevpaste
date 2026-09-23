// PROTOTYPE — history-probe, never merged
import AppKit
import SmartPasteCore

/// Variant C: a search field first. Typing filters history (substring, case-insensitive); an empty query shows the
/// newest items. ↑/↓ move, Enter selects, ⌘⌫ deletes the highlighted result, Esc or click-away closes. The Active
/// Item itself lives in the menu bar next to the status icon, not in this panel.
@MainActor
final class HistorySearchPanel: NSObject, NSSearchFieldDelegate {
    private static let visibleRows = 8
    private static let width: CGFloat = 420

    private unowned let probe: HistoryProbe
    private let field = NSSearchField()
    private let rows = HistoryRowsView(width: width)
    private var host: ProbePanelHost?
    private var results: [ClipboardItem] = []
    private var highlighted = 0
    private var focusTarget: Int32?

    init(probe: HistoryProbe, anchorFrame: @escaping @MainActor () -> NSRect?) {
        self.probe = probe
        super.init()
        field.placeholderString = "Search clipboard history"
        field.font = .systemFont(ofSize: NSFont.systemFontSize + 2)
        field.delegate = self
        field.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        let stack = NSStackView(views: [
            field, rows.stack, NSTextField.probeHint("type to filter · ↑↓ · Enter selects · ⌘⌫ deletes · Esc closes"),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        let host = ProbePanelHost(content: stack, anchorFrame: anchorFrame)
        self.host = host
        rows.onClick = { [weak self] index in self?.choose(index) }
    }

    func open(returningFocusTo target: Int32?) {
        focusTarget = target
        field.stringValue = ""
        highlighted = 0
        filter()
        host?.show(firstResponder: field)
    }

    func controlTextDidChange(_ notification: Notification) {
        highlighted = 0
        filter()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)): move(by: -1)
        case #selector(NSResponder.moveDown(_:)): move(by: 1)
        case #selector(NSResponder.insertNewline(_:)): choose(highlighted)
        case #selector(NSResponder.cancelOperation(_:)): closeReturningFocus()
        case #selector(NSResponder.deleteToBeginningOfLine(_:)): deleteHighlighted()
        default: return false
        }
        return true
    }

    private func filter() {
        let query = field.stringValue.trimmingCharacters(in: .whitespaces)
        let all = probe.items()
        let matching = query.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(query) }
        results = Array(matching.prefix(Self.visibleRows))
        highlighted = min(highlighted, max(results.count - 1, 0))
        rows.show(results, isActive: probe.isActive, highlighted: highlighted)
        host?.relayout()
    }

    private func move(by step: Int) {
        guard !results.isEmpty else { return }
        highlighted = min(max(highlighted + step, 0), results.count - 1)
        rows.highlight(highlighted)
    }

    private func choose(_ index: Int) {
        guard results.indices.contains(index) else { return }
        probe.select(results[index], from: "search")
        closeReturningFocus()
    }

    private func deleteHighlighted() {
        guard results.indices.contains(highlighted) else { return }
        probe.delete(results[highlighted])
        filter()
    }

    private func closeReturningFocus() {
        host?.close()
        probe.returnFocus(to: focusTarget)
    }
}
