import AppKit

/// The `IndicatorSurface` on screen: one reused borderless, non-activating, floating panel just below the status
/// item. Normally it is never key and is shown with `orderFrontRegardless()`, so the Target keeps key focus; a click
/// on it is delivered without activating the app. Only while it offers to paste everything after No Suitable Match
/// does it take key focus — like the Candidate Chooser, without activating the app — so Enter and Esc reach it.
@MainActor
final class IndicatorPanel: IndicatorSurface {
    func forwardClicks(to handler: @escaping @MainActor () -> Void) {
        clickView.onClick = handler
    }

    func forwardOfferEvents(to handler: @escaping @MainActor (IndicatorOfferEvent) -> Void) {
        onOfferEvent = handler
    }

    private let panel = StatusItemPanel(becomesKey: false)
    private let keyView = PanelKeyView()
    private let clickView = FirstClickView()
    private let symbolView = NSImageView()
    private let textField = NSTextField(labelWithString: "")
    private var onOfferEvent: (@MainActor (IndicatorOfferEvent) -> Void)?
    /// The status item button's frame on screen, or `nil` when it is not shown.
    private let anchorFrame: @MainActor () -> NSRect?

    init(anchorFrame: @escaping @MainActor () -> NSRect?) {
        self.anchorFrame = anchorFrame
        let stack = NSStackView(views: [symbolView, textField])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 12)
        clickView.addFillingSubview(stack)
        keyView.addFillingSubview(clickView)
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        panel.contentView = HUDBackgroundView(filledBy: keyView)
        keyView.onKey = { [weak self] key in self?.keyPressed(key) }
        panel.onResignKey = { [weak self] in self?.onOfferEvent?(.dismiss(.clickAway)) }
    }

    func display(_ content: IndicatorContent) {
        giveUpKeyFocus()
        show(content)
        panel.orderFrontRegardless()
        panel.display()
    }

    func displayTakingKeyFocus(_ content: IndicatorContent) {
        panel.becomesKey = true
        show(content)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(keyView)
        panel.display()
    }

    func hide() {
        panel.orderOut(nil)
        panel.becomesKey = false
    }

    private func show(_ content: IndicatorContent) {
        symbolView.image = NSImage(systemSymbolName: content.symbolName, accessibilityDescription: nil)
        textField.stringValue = content.text
        panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
        panel.setFrameOrigin(StatusItemPlacement.origin(for: panel.frame.size, below: anchorFrame()))
    }

    /// Ordering the panel out is what hands key focus back; it is ordered front again, non-key, right after.
    private func giveUpKeyFocus() {
        if panel.isKeyWindow { panel.orderOut(nil) }
        panel.becomesKey = false
    }

    private func keyPressed(_ key: PanelKey) {
        switch key {
        case .confirm: onOfferEvent?(.accept)
        case .escape: onOfferEvent?(.dismiss(.escape))
        case .moveUp, .moveDown: break
        }
    }
}
