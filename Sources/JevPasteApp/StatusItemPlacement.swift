import AppKit

/// Where jevpaste's panels appear: just below the status item and kept on its screen, or at the top right of the main
/// screen when the status item is not shown. The indicator and the Candidate Chooser are centred under the item; the
/// History Search panel hangs from its left edge, as a menu does.
enum StatusItemPlacement {
    enum Alignment {
        case centred
        /// The panel's left edge a little left of the item's, like a menu's.
        case menu
    }

    private static let gapBelowAnchor = 4.0
    private static let screenMargin = 8.0
    private static let menuLeftOverhang = 6.0

    /// The origin for a panel of `size`, given the status item button's frame on screen (`nil` when not shown).
    @MainActor
    static func origin(
        for size: NSSize, below statusItemFrame: NSRect?, aligned alignment: Alignment = .centred
    ) -> NSPoint {
        let screen = NSScreen.screens.first { statusItemFrame.map($0.frame.intersects) ?? false } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        return origin(for: size, below: statusItemFrame, within: visible, aligned: alignment)
    }

    /// The origin within the screen's `visible` frame.
    static func origin(
        for size: NSSize, below statusItemFrame: NSRect?, within visible: NSRect,
        aligned alignment: Alignment = .centred
    ) -> NSPoint {
        let anchor = statusItemFrame ?? NSRect(x: visible.maxX - size.width / 2, y: visible.maxY, width: 0, height: 0)
        let preferredLeft =
            switch alignment {
            case .centred: anchor.midX - size.width / 2
            case .menu: anchor.minX - menuLeftOverhang
            }
        let left = min(max(preferredLeft, visible.minX + screenMargin), visible.maxX - size.width - screenMargin)
        return NSPoint(x: left, y: min(anchor.minY, visible.maxY) - size.height - gapBelowAnchor)
    }
}
