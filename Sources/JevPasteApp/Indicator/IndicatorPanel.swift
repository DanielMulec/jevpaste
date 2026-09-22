import AppKit

/// The `IndicatorSurface` on screen: one reused borderless, non-activating, floating panel just below the status
/// item. It is never key or main and is shown with `orderFrontRegardless()`, so the Target keeps key focus; a click
/// on it is delivered without activating the app.
@MainActor
final class IndicatorPanel: IndicatorSurface {
    func forwardClicks(to handler: @escaping @MainActor () -> Void) {
        contentView.onClick = handler
    }

    private static let gapBelowAnchor = 4.0
    private static let screenMargin = 8.0

    private let panel = NonActivatingPanel()
    private let contentView = ClickForwardingView()
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
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        panel.contentView = contentView
    }

    func display(_ content: IndicatorContent) {
        symbolView.image = NSImage(systemSymbolName: content.symbolName, accessibilityDescription: nil)
        textField.stringValue = content.text
        panel.setContentSize(contentView.fittingSize)
        panel.setFrameOrigin(origin(for: panel.frame.size))
        panel.orderFrontRegardless()
        panel.display()
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// Centred below the status item, kept on its screen; top-right of the main screen when there is no anchor.
    private func origin(for size: NSSize) -> NSPoint {
        let statusItemFrame = anchorFrame()
        let screen = NSScreen.screens.first { statusItemFrame.map($0.frame.intersects) ?? false } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        let anchor = statusItemFrame ?? NSRect(x: visible.maxX - size.width / 2, y: visible.maxY, width: 0, height: 0)
        let left = min(
            max(anchor.midX - size.width / 2, visible.minX + Self.screenMargin),
            visible.maxX - size.width - Self.screenMargin)
        return NSPoint(x: left, y: min(anchor.minY, visible.maxY) - size.height - Self.gapBelowAnchor)
    }
}

/// A panel that never becomes key or main and never activates the app when clicked.
private final class NonActivatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true
        )
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The rounded HUD background; takes every click inside it, including the first one, and forwards it.
private final class ClickForwardingView: NSVisualEffectView {
    var onClick: (@MainActor () -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 8
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}
