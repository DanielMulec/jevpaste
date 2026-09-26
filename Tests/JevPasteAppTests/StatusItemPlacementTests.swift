import AppKit
import Testing

@testable import JevPasteApp

struct StatusItemPlacementTests {
    private static let visible = NSRect(x: 0, y: 0, width: 1000, height: 700)
    private static let size = NSSize(width: 200, height: 50)

    @Test func centresBelowTheStatusItemWithAGap() {
        let statusItem = NSRect(x: 490, y: 700, width: 20, height: 24)

        let origin = StatusItemPlacement.origin(for: Self.size, below: statusItem, within: Self.visible)

        #expect(origin == NSPoint(x: 400, y: 646))
    }

    @Test func staysAMarginInsideTheRightEdgeOfTheScreen() {
        let statusItem = NSRect(x: 980, y: 700, width: 20, height: 24)

        let origin = StatusItemPlacement.origin(for: Self.size, below: statusItem, within: Self.visible)

        #expect(origin == NSPoint(x: 792, y: 646))
    }

    @Test func withoutAStatusItemItSitsAtTheTopRightOfTheScreen() {
        let origin = StatusItemPlacement.origin(for: Self.size, below: nil, within: Self.visible)

        #expect(origin == NSPoint(x: 792, y: 646))
    }

    @Test func aMenuHangsFromTheStatusItemsLeftEdge() {
        let statusItem = NSRect(x: 490, y: 700, width: 20, height: 24)

        let origin = StatusItemPlacement.origin(for: Self.size, below: statusItem, within: Self.visible, aligned: .menu)

        #expect(origin == NSPoint(x: 484, y: 646))
    }

    @Test func aMenuNearTheRightEdgeStaysAMarginInside() {
        let statusItem = NSRect(x: 900, y: 700, width: 20, height: 24)

        let origin = StatusItemPlacement.origin(for: Self.size, below: statusItem, within: Self.visible, aligned: .menu)

        #expect(origin == NSPoint(x: 792, y: 646))
    }
}
