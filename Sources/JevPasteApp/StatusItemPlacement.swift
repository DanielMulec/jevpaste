import AppKit

/// Where jevpaste's panels appear: centred just below the status item and kept on its screen, or at the top
/// right of the main screen when the status item is not shown. Shared by the indicator and the Candidate Chooser.
enum StatusItemPlacement {
    private static let gapBelowAnchor = 4.0
    private static let screenMargin = 8.0

    /// The origin for a panel of `size`, given the status item button's frame on screen (`nil` when not shown).
    @MainActor
    static func origin(for size: NSSize, below statusItemFrame: NSRect?) -> NSPoint {
        let screen = NSScreen.screens.first { statusItemFrame.map($0.frame.intersects) ?? false } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        return origin(for: size, below: statusItemFrame, within: visible)
    }

    /// The origin within the screen's `visible` frame.
    static func origin(for size: NSSize, below statusItemFrame: NSRect?, within visible: NSRect) -> NSPoint {
        let anchor = statusItemFrame ?? NSRect(x: visible.maxX - size.width / 2, y: visible.maxY, width: 0, height: 0)
        let left = min(
            max(anchor.midX - size.width / 2, visible.minX + screenMargin),
            visible.maxX - size.width - screenMargin)
        return NSPoint(x: left, y: min(anchor.minY, visible.maxY) - size.height - gapBelowAnchor)
    }
}
