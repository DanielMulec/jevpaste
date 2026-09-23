import AppKit

/// The `IndicatorSurface` on screen: one reused borderless, non-activating, floating panel just below the status
/// item. It is never key or main and is shown with `orderFrontRegardless()`, so the Target keeps key focus; a click
/// on it is delivered without activating the app.
@MainActor
final class IndicatorPanel: IndicatorSurface {
    func forwardClicks(to handler: @escaping @MainActor () -> Void) {
        clickView.onClick = handler
    }

    private let panel = StatusItemPanel(becomesKey: false)
    private let clickView = FirstClickView()
    private let symbolView = NSImageView()
    private let textField = NSTextField(labelWithString: "")
    /// The status item button's frame on screen, or `nil` when it is not shown.
    private let anchorFrame: @MainActor () -> NSRect?

    init(anchorFrame: @escaping @MainActor () -> NSRect?) {
        self.anchorFrame = anchorFrame
        let stack = NSStackView(views: [symbolView, textField])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 12)
        clickView.addFillingSubview(stack)
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        panel.contentView = HUDBackgroundView(filledBy: clickView)
    }

    func display(_ content: IndicatorContent) {
        symbolView.image = NSImage(systemSymbolName: content.symbolName, accessibilityDescription: nil)
        textField.stringValue = content.text
        panel.setContentSize(panel.contentView?.fittingSize ?? .zero)
        panel.setFrameOrigin(StatusItemPlacement.origin(for: panel.frame.size, below: anchorFrame()))
        panel.orderFrontRegardless()
        panel.display()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
