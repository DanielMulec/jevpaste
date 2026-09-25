import AppKit

/// The `ChooserSurface` on screen: one reused borderless panel below the status item. It is `.nonactivatingPanel`
/// yet may become key, so it receives ↑/↓/Enter/Esc while the Target's app stays the active app; losing key
/// (a click into another window or app) is reported as click-away.
@MainActor
final class ChooserPanel: ChooserSurface {
    private static let maximumWidth = 420.0
    private static let minimumWidth = 240.0

    private let panel = StatusItemPanel(becomesKey: true)
    private let keyView = PanelKeyView()
    private let titleField = NSTextField(labelWithString: "")
    private let rowStack = NSStackView()
    private let hintField = NSTextField(labelWithString: "↑↓ choose · Enter pastes · Esc cancels")
    private var rowViews: [ChooserRowView] = []
    private var onEvent: (@MainActor (ChooserEvent) -> Void)?
    /// The status item button's frame on screen, or `nil` when it is not shown.
    private let anchorFrame: @MainActor () -> NSRect?

    init(anchorFrame: @escaping @MainActor () -> NSRect?) {
        self.anchorFrame = anchorFrame
        titleField.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        hintField.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hintField.textColor = .secondaryLabelColor
        for field in [titleField, hintField] {
            field.lineBreakMode = .byTruncatingTail
            field.maximumNumberOfLines = 1
        }
        rowStack.orientation = .vertical
        rowStack.alignment = .leading
        rowStack.spacing = 2
        layOut()
        keyView.onKey = { [weak self] key in self?.onEvent?(ChooserEvent(key)) }
        panel.onResignKey = { [weak self] in self?.onEvent?(.cancel(.clickAway)) }
    }

    func forwardEvents(to handler: @escaping @MainActor (ChooserEvent) -> Void) {
        onEvent = handler
    }

    func open(_ content: ChooserContent, selecting row: Int) {
        titleField.stringValue = content.title
        for view in rowViews { view.removeFromSuperview() }
        rowViews = content.rows.enumerated().map { index, text in
            let view = ChooserRowView(text: text)
            view.onClick = { [weak self] in self?.onEvent?(.choose(row: index)) }
            return view
        }
        for view in rowViews {
            rowStack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: rowStack.widthAnchor).isActive = true
        }
        select(row)
        panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
        panel.setFrameOrigin(StatusItemPlacement.origin(for: panel.frame.size, below: anchorFrame()))
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(keyView)
    }

    func select(_ row: Int) {
        for (index, view) in rowViews.enumerated() {
            view.isSelected = index == row
        }
    }

    func close() {
        panel.orderOut(nil)
    }

    private func layOut() {
        let stack = NSStackView(views: [titleField, rowStack, hintField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        keyView.addFillingSubview(stack)
        NSLayoutConstraint.activate([
            rowStack.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumWidth),
            rowStack.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maximumWidth),
            titleField.widthAnchor.constraint(lessThanOrEqualTo: rowStack.widthAnchor),
            hintField.widthAnchor.constraint(lessThanOrEqualTo: rowStack.widthAnchor),
        ])
        panel.contentView = HUDBackgroundView(filledBy: keyView)
    }
}
