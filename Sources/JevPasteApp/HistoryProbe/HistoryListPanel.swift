// PROTOTYPE — history-probe, never merged
import AppKit
import SmartPasteCore

/// Variant B: a chooser-style panel. A pinned ACTIVE block (first three lines of the Active Item) on top, the
/// newest items below. ↑/↓ move, Enter or a click selects, ⌫ deletes the highlighted row, footer "Clear all"
/// (click twice), Esc or click-away closes.
@MainActor
final class HistoryListPanel {
    private static let visibleRows = 12
    private static let width: CGFloat = 420

    private unowned let probe: HistoryProbe
    private let activeTitle = NSTextField(labelWithString: "ACTIVE — the next ⌘⇧V uses this")
    private let activeBody = NSTextField(wrappingLabelWithString: "")
    private let rows = HistoryRowsView(width: width)
    private let clearButton = NSButton(title: "Clear all…", target: nil, action: nil)
    private var host: ProbePanelHost?
    private var items: [ClipboardItem] = []
    private var highlighted = 0
    private var clearArmed = false
    private var focusTarget: Int32?

    init(probe: HistoryProbe, anchorFrame: @escaping @MainActor () -> NSRect?) {
        self.probe = probe
        activeTitle.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        activeTitle.textColor = .controlAccentColor
        activeBody.font = .systemFont(ofSize: NSFont.systemFontSize + 1, weight: .semibold)
        activeBody.maximumNumberOfLines = 3
        activeBody.lineBreakMode = .byTruncatingTail
        activeBody.preferredMaxLayoutWidth = Self.width
        clearButton.bezelStyle = .inline
        clearButton.target = self
        clearButton.action = #selector(clearClicked)
        let divider = NSBox()
        divider.boxType = .separator
        let footer = NSStackView(views: [
            NSTextField.probeHint("↑↓ move · Enter selects · ⌫ deletes · Esc closes"), clearButton,
        ])
        footer.orientation = .horizontal
        footer.spacing = 12
        let stack = NSStackView(views: [activeTitle, activeBody, divider, rows.stack, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        divider.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        activeBody.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        let host = ProbePanelHost(content: stack, anchorFrame: anchorFrame)
        host.keyView.onKey = { [weak self] event in self?.key(event) }
        self.host = host
        rows.onClick = { [weak self] index in self?.choose(index) }
    }

    func open(returningFocusTo target: Int32?) {
        focusTarget = target
        highlighted = 0
        reload()
        host?.show()
    }

    private func reload() {
        items = Array(probe.items().prefix(Self.visibleRows))
        highlighted = min(highlighted, max(items.count - 1, 0))
        clearArmed = false
        clearButton.title = "Clear all…"
        activeBody.stringValue = activeText()
        rows.show(items, isActive: probe.isActive, highlighted: highlighted)
        host?.relayout()
    }

    private func activeText() -> String {
        guard let active = probe.capture.activeItem else { return "(nothing copied yet)" }
        if active.isConcealed { return "(concealed item)" }
        let lines = active.text.split(whereSeparator: \.isNewline).prefix(3).map(String.init)
        return lines.joined(separator: "\n")
    }

    private func key(_ event: NSEvent) {
        switch event.keyCode {
        case ProbeKey.upArrow: move(by: -1)
        case ProbeKey.downArrow: move(by: 1)
        case ProbeKey.returnKey, ProbeKey.keypadEnter: choose(highlighted)
        case ProbeKey.delete, ProbeKey.forwardDelete: deleteHighlighted()
        case ProbeKey.escape: closeReturningFocus()
        default: break
        }
    }

    private func move(by step: Int) {
        guard !items.isEmpty else { return }
        highlighted = min(max(highlighted + step, 0), items.count - 1)
        rows.highlight(highlighted)
    }

    private func choose(_ index: Int) {
        guard items.indices.contains(index) else { return }
        probe.select(items[index], from: "panel")
        closeReturningFocus()
    }

    private func deleteHighlighted() {
        guard items.indices.contains(highlighted) else { return }
        probe.delete(items[highlighted])
        reload()
    }

    @objc private func clearClicked() {
        guard clearArmed else {
            clearArmed = true
            clearButton.title = "Click again to delete all"
            return
        }
        probe.clearAll()
        reload()
    }

    private func closeReturningFocus() {
        host?.close()
        probe.returnFocus(to: focusTarget)
    }
}
