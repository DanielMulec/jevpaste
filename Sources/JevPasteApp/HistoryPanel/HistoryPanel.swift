import AppKit

/// The `HistoryPanelSurface` on screen: one reused borderless panel below the status item, Spotlight-style — a
/// large search field, the pinned Active Item, nine history rows, and a footer with key hints and clear-all.
/// `.nonactivatingPanel` yet key-capable, so the search field takes typing while the frontmost app stays active;
/// losing key (a click into another window or app) is reported as click-away.
@MainActor
final class HistoryPanel: NSObject, HistoryPanelSurface, NSTextFieldDelegate {
    private static let width = 520.0

    private let panel = StatusItemPanel(becomesKey: true)
    private let searchField = EditingShortcutsTextField()
    private let activeItemView = ActiveItemView()
    private let rows = HistoryRowsView()
    private let footer = HistoryPanelFooter()
    private var onEvent: (@MainActor (HistoryPanelEvent) -> Void)?
    /// The status item button's frame on screen, or `nil` when it is not shown.
    private let anchorFrame: @MainActor () -> NSRect?

    init(anchorFrame: @escaping @MainActor () -> NSRect?) {
        self.anchorFrame = anchorFrame
        super.init()
        configureSearchField()
        rows.onChoose = { [weak self] row in self?.onEvent?(.choose(row: row)) }
        rows.onDelete = { [weak self] row in self?.onEvent?(.delete(row: row)) }
        footer.onClearAllRequested = { [weak self] in self?.onEvent?(.clearAllRequested) }
        footer.onClearAllConfirmed = { [weak self] in self?.onEvent?(.clearAllConfirmed) }
        footer.onClearAllCancelled = { [weak self] in self?.onEvent?(.clearAllCancelled) }
        panel.onResignKey = { [weak self] in self?.onEvent?(.dismiss(.clickAway)) }
        layOut()
    }

    func forwardEvents(to handler: @escaping @MainActor (HistoryPanelEvent) -> Void) {
        onEvent = handler
    }

    func open(_ content: HistoryPanelContent, highlighting row: Int?) {
        searchField.stringValue = ""
        footer.showNormal()
        show(content, highlighting: row)
        panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
        panel.setFrameOrigin(StatusItemPlacement.origin(for: panel.frame.size, below: anchorFrame()))
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func show(_ content: HistoryPanelContent, highlighting row: Int?) {
        activeItemView.show(content.activeItem)
        rows.show(content.rows, emptyMessage: content.emptyMessage, highlighting: row)
        resizeKeepingTopEdge()
    }

    func highlight(_ row: Int?) {
        rows.highlight(row)
    }

    func askToConfirmClearAll(itemCount: Int) {
        footer.askToConfirmClearAll(itemCount: itemCount)
    }

    func endClearAllConfirmation() {
        footer.showNormal()
    }

    func close() {
        panel.orderOut(nil)
    }

    func controlTextDidChange(_ notification: Notification) {
        onEvent?(.queryChanged(searchField.stringValue))
    }

    /// The search field keeps first responder; the keys the panel needs arrive here as editing commands.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard let event = event(for: selector) else { return false }
        onEvent?(event)
        return true
    }

    private func event(for selector: Selector) -> HistoryPanelEvent? {
        switch selector {
        case #selector(NSResponder.moveUp(_:)): .moveUp
        case #selector(NSResponder.moveDown(_:)): .moveDown
        case #selector(NSResponder.insertNewline(_:)): .chooseHighlighted
        case #selector(NSResponder.cancelOperation(_:)): .dismiss(.escape)
        case #selector(NSResponder.deleteToBeginningOfLine(_:)): .deleteHighlighted
        // Plain ⌫ deletes a row only with nothing left to erase, and never by auto-repeat — holding ⌫ to clear
        // the query must not run on into the history.
        case #selector(NSResponder.deleteBackward(_:)):
            searchField.stringValue.isEmpty && NSApp.currentEvent?.isARepeat == false ? .deleteHighlighted : nil
        default: nil
        }
    }

    private func configureSearchField() {
        searchField.placeholderString = "Search Clipboard History"
        searchField.font = .systemFont(ofSize: 20, weight: .light)
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.cell?.usesSingleLineMode = true
        searchField.cell?.isScrollable = true
        searchField.delegate = self
    }

    private func layOut() {
        let magnifier = NSImageView(
            image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 18, weight: .regular)) ?? NSImage()
        )
        magnifier.contentTintColor = .secondaryLabelColor
        let searchRow = NSStackView(views: [magnifier, searchField])
        searchRow.spacing = 10
        searchRow.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 12, right: 16)
        let activeRow = NSView()
        activeItemView.translatesAutoresizingMaskIntoConstraints = false
        activeRow.addSubview(activeItemView)
        NSLayoutConstraint.activate([
            activeItemView.leadingAnchor.constraint(equalTo: activeRow.leadingAnchor, constant: 10),
            activeItemView.trailingAnchor.constraint(equalTo: activeRow.trailingAnchor, constant: -10),
            activeItemView.topAnchor.constraint(equalTo: activeRow.topAnchor, constant: 10),
            activeItemView.bottomAnchor.constraint(equalTo: activeRow.bottomAnchor, constant: -4),
        ])
        let stack = NSStackView(views: [
            searchRow, Self.separator(), activeRow, rows.view, Self.separator(), footer.view,
        ])
        stack.orientation = .vertical
        stack.spacing = 0
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        stack.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        panel.contentView = HUDBackgroundView(filledBy: stack, material: .popover, cornerRadius: 14)
    }

    private func resizeKeepingTopEdge() {
        guard panel.isVisible, let contentView = panel.contentView else { return }
        let top = panel.frame.maxY
        panel.setContentSize(contentView.fittingSize)
        panel.setFrameTopLeftPoint(NSPoint(x: panel.frame.minX, y: top))
    }

    private static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

/// A text field that handles ⌘X/⌘C/⌘V/⌘A/⌘Z itself: jevpaste is an accessory app without an Edit menu, which
/// is where these shortcuts normally live.
private final class EditingShortcutsTextField: NSTextField {
    private static let actions: [String: Selector] = [
        "x": #selector(NSText.cut(_:)), "c": #selector(NSText.copy(_:)), "v": #selector(NSText.paste(_:)),
        "a": #selector(NSText.selectAll(_:)), "z": Selector(("undo:")),
    ]

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
            let key = event.charactersIgnoringModifiers, let action = Self.actions[key]
        else { return super.performKeyEquivalent(with: event) }
        return NSApp.sendAction(action, to: nil, from: self)
    }
}
