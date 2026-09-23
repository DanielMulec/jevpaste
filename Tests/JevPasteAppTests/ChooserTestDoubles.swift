@testable import JevPasteApp

/// Records what the chooser shows and lets a test press keys, click rows or click away.
@MainActor
final class RecordingChooserSurface: ChooserSurface {
    /// The content on screen, or `nil` while the chooser is closed.
    private(set) var shown: ChooserContent?
    private(set) var selectedRow: Int?
    private var onEvent: (@MainActor (ChooserEvent) -> Void)?

    func forwardEvents(to handler: @escaping @MainActor (ChooserEvent) -> Void) {
        onEvent = handler
    }

    func open(_ content: ChooserContent, selecting row: Int) {
        shown = content
        selectedRow = row
    }

    func select(_ row: Int) {
        selectedRow = row
    }

    func close() {
        shown = nil
        selectedRow = nil
    }

    func send(_ event: ChooserEvent) {
        onEvent?(event)
    }
}
