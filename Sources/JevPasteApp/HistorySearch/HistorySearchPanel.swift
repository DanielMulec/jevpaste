import AppKit

/// The `HistorySearchSurface` on screen: a menu-shaped panel under the status item — the shared `StatusItemPanel`
/// at the menu level, key-capable and non-activating, so the search field shows its caret and takes typing while
/// the frontmost app stays active. A text field inside a real `NSMenu` never gets key and goes deaf after one arrow
/// key (#37). Keys arrive as the field's editing commands; losing key is reported as click-away.
@MainActor
final class HistorySearchPanel: NSObject, HistorySearchSurface, NSSearchFieldDelegate {
    private static let width = 420.0

    private let panel = StatusItemPanel(becomesKey: true, level: .popUpMenu)
    private let field = EditingSearchField()
    private let stack = NSStackView()
    private var lines: [(selection: HistorySearchSelection, view: MenuLineView)] = []
    private var onEvent: (@MainActor (HistorySearchEvent) -> Void)?
    /// The status item button's frame on screen, or `nil` when it is not shown.
    private let anchorFrame: @MainActor () -> NSRect?

    init(anchorFrame: @escaping @MainActor () -> NSRect?) {
        self.anchorFrame = anchorFrame
        super.init()
        field.delegate = self
        field.sendsSearchStringImmediately = true
        panel.onResignKey = { [weak self] in self?.onEvent?(.dismiss(.clickAway)) }
        layOut()
    }

    func forwardEvents(to handler: @escaping @MainActor (HistorySearchEvent) -> Void) {
        onEvent = handler
    }

    func open(_ content: HistorySearchContent) {
        field.stringValue = ""
        show(content)
        panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
        panel.setFrameOrigin(
            StatusItemPlacement.origin(for: panel.frame.size, below: anchorFrame(), aligned: .menu)
        )
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    /// Rebuilds only the lines under the field: re-adding the field itself drops its field editor mid-typing.
    func show(_ content: HistorySearchContent) {
        field.placeholderString = content.placeholder
        for view in stack.arrangedSubviews.dropFirst(2) {
            view.removeFromSuperview()
        }
        lines = []
        if let summary = content.matchSummary { add(MenuHeaderView(summary)) }
        if content.saysNothingMatches { add(MenuHeaderView("No matching Clipboard Items")) }
        for (index, row) in content.rows.enumerated() {
            addLine(MenuLineView(row: row), as: .row(index))
        }
        if !content.rows.isEmpty || content.saysNothingMatches { add(MenuSeparatorView()) }
        for item in content.menuItems {
            addLine(Self.view(for: item), as: .menuItem(item))
        }
        panel.resizeKeepingTopEdge()
    }

    func highlight(_ selection: HistorySearchSelection?) {
        for line in lines {
            line.view.isHighlighted = line.selection == selection
        }
    }

    func close() {
        panel.orderOut(nil)
    }

    func controlTextDidChange(_ notification: Notification) {
        onEvent?(.queryChanged(field.stringValue))
    }

    /// The field keeps first responder; the panel's keys arrive here and are not passed on to the field editor.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        let event: HistorySearchEvent? =
            switch selector {
            case #selector(NSResponder.moveUp(_:)): .moveUp
            case #selector(NSResponder.moveDown(_:)): .moveDown
            case #selector(NSResponder.insertNewline(_:)): .confirm
            case #selector(NSResponder.cancelOperation(_:)): .dismiss(.escape)
            default: nil
            }
        guard let event else { return false }
        onEvent?(event)
        return true
    }

    private static func view(for item: HistorySearchMenuItem) -> MenuLineView {
        switch item {
        case .fullHistory(let itemCount): MenuLineView(title: "Full history…", trailing: "(\(itemCount))")
        case .settings: MenuLineView(title: "Settings…")
        case .quit: MenuLineView(title: "Quit")
        }
    }

    private func addLine(_ view: MenuLineView, as selection: HistorySearchSelection) {
        view.onClick = { [weak self] in self?.onEvent?(.choose(selection)) }
        view.onHover = { [weak self] in self?.onEvent?(.hover(selection)) }
        lines.append((selection, view))
        add(view)
    }

    private func add(_ view: NSView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -2 * MenuMetrics.lineInset).isActive = true
    }

    private func layOut() {
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        stack.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        let fieldBox = NSView()
        field.translatesAutoresizingMaskIntoConstraints = false
        fieldBox.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: fieldBox.leadingAnchor, constant: 4),
            field.trailingAnchor.constraint(equalTo: fieldBox.trailingAnchor, constant: -4),
            field.topAnchor.constraint(equalTo: fieldBox.topAnchor, constant: 3),
            field.bottomAnchor.constraint(equalTo: fieldBox.bottomAnchor, constant: -5),
        ])
        add(fieldBox)
        add(MenuSeparatorView())
        panel.contentView = HUDBackgroundView(filledBy: stack, material: .menu, cornerRadius: 10, tint: .menuPanelTint)
    }
}
