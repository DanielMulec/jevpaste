import SmartPasteCore

@testable import JevPasteApp

/// Records what the history panel shows and lets a test type, press keys, click rows or click away.
@MainActor
final class RecordingHistoryPanelSurface: HistoryPanelSurface {
    /// The content on screen, or `nil` while the panel is closed.
    private(set) var shown: HistoryPanelContent?
    private(set) var highlighted: Int?
    private(set) var openCount = 0
    /// The item count in the clear-all question while it is asked, else `nil`.
    private(set) var clearAllQuestion: Int?
    private var onEvent: (@MainActor (HistoryPanelEvent) -> Void)?

    var rowTitles: [String]? { shown?.rows.map(\.title) }

    func forwardEvents(to handler: @escaping @MainActor (HistoryPanelEvent) -> Void) {
        onEvent = handler
    }

    func open(_ content: HistoryPanelContent, highlighting row: Int?) {
        openCount += 1
        show(content, highlighting: row)
    }

    func show(_ content: HistoryPanelContent, highlighting row: Int?) {
        shown = content
        highlighted = row
    }

    func highlight(_ row: Int?) {
        highlighted = row
    }

    func askToConfirmClearAll(itemCount: Int) {
        clearAllQuestion = itemCount
    }

    func endClearAllConfirmation() {
        clearAllQuestion = nil
    }

    func close() {
        shown = nil
        highlighted = nil
        clearAllQuestion = nil
    }

    func send(_ events: HistoryPanelEvent...) {
        for event in events {
            onEvent?(event)
        }
    }
}

/// A clipboard that only reports copies a test makes; enough for `CopyCapture` outside a Paste Attempt.
@MainActor
final class CopyingClipboard: Clipboard {
    private(set) var changeCount = 0
    private var onChange: (@MainActor (ClipboardChange) -> Void)?

    func snapshot() -> ClipboardSnapshot {
        ClipboardSnapshot(items: [])
    }

    func write(_ text: String) -> Int {
        nextChangeCount()
    }

    func restore(_ snapshot: ClipboardSnapshot) -> Int {
        nextChangeCount()
    }

    func startObservingChanges(_ onChange: @escaping @MainActor (ClipboardChange) -> Void) {
        self.onChange = onChange
    }

    /// Another app copies `text`.
    func copy(_ text: String) {
        onChange?(ClipboardChange(changeCount: nextChangeCount(), item: ClipboardItem(text: text)))
    }

    private func nextChangeCount() -> Int {
        changeCount += 1
        return changeCount
    }
}
