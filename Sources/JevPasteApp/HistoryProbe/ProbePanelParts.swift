// PROTOTYPE — history-probe, never merged
import AppKit
import SmartPasteCore

/// Key codes the probe panels react to.
enum ProbeKey {
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
    static let delete: UInt16 = 51
    static let forwardDelete: UInt16 = 117
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}

/// First responder of a probe panel: hands every key down to `onKey`.
final class ProbeKeyView: NSView {
    var onKey: (@MainActor (NSEvent) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) { onKey?(event) }
}

/// A key-capable, non-activating panel below the status item (the chooser's kind), holding one content view.
/// Losing key (click-away) closes it without returning focus: the user clicked where they wanted to be.
@MainActor
final class ProbePanelHost {
    let panel = StatusItemPanel(becomesKey: true)
    let keyView = ProbeKeyView()
    private let anchorFrame: @MainActor () -> NSRect?
    private(set) var isOpen = false
    var onClickAway: (@MainActor () -> Void)?

    init(content: NSView, anchorFrame: @escaping @MainActor () -> NSRect?) {
        self.anchorFrame = anchorFrame
        keyView.addFillingSubview(content)
        panel.contentView = HUDBackgroundView(filledBy: keyView)
        panel.onResignKey = { [weak self] in
            guard let self, self.isOpen else { return }
            self.close()
            self.onClickAway?()
        }
    }

    func show(firstResponder: NSView? = nil) {
        isOpen = true
        relayout()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(firstResponder ?? keyView)
    }

    /// Resizes to the content and keeps the panel's top edge under the status item.
    func relayout() {
        panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
        panel.setFrameOrigin(StatusItemPlacement.origin(for: panel.frame.size, below: anchorFrame()))
    }

    func close() {
        isOpen = false
        panel.orderOut(nil)
    }
}

/// The list of history rows used by B and C: one `ChooserRowView` per item, the Active one marked with ●, one row
/// highlighted as the keyboard selection.
@MainActor
final class HistoryRowsView {
    let stack = NSStackView()
    private var rows: [ChooserRowView] = []
    var onClick: (@MainActor (Int) -> Void)?

    init(width: CGFloat) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    func show(_ items: [ClipboardItem], isActive: (ClipboardItem) -> Bool, highlighted: Int) {
        for row in rows { row.removeFromSuperview() }
        rows = items.enumerated().map { index, item in
            let marker = isActive(item) ? "●  " : "    "
            let row = ChooserRowView(text: marker + HistoryProbe.label(for: item))
            row.onClick = { [weak self] in self?.onClick?(index) }
            return row
        }
        for row in rows {
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        if rows.isEmpty {
            let empty = ChooserRowView(text: "    (no history)")
            rows = [empty]
            stack.addArrangedSubview(empty)
        }
        highlight(highlighted)
    }

    func highlight(_ index: Int) {
        for (rowIndex, row) in rows.enumerated() { row.isSelected = rowIndex == index }
    }
}

extension NSTextField {
    /// A small secondary-coloured one-line label.
    static func probeHint(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .secondaryLabelColor
        return field
    }
}
