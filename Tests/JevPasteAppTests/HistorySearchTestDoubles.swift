import Foundation
import HistoryStore
import SmartPasteCore

@testable import JevPasteApp

/// Records what the History Search panel shows and lets a test type, press keys, hover, click or click away.
@MainActor
final class RecordingHistorySearchSurface: HistorySearchSurface {
    /// The content on screen, or `nil` while the panel is closed.
    private(set) var shown: HistorySearchContent?
    private(set) var highlighted: HistorySearchSelection?
    private(set) var openCount = 0
    private var onEvent: (@MainActor (HistorySearchEvent) -> Void)?

    var rowTitles: [String]? { shown?.rows.map(\.title) }

    func forwardEvents(to handler: @escaping @MainActor (HistorySearchEvent) -> Void) {
        onEvent = handler
    }

    func open(_ content: HistorySearchContent) {
        openCount += 1
        show(content)
    }

    func show(_ content: HistorySearchContent) {
        shown = content
        highlighted = nil
    }

    func highlight(_ selection: HistorySearchSelection?) {
        highlighted = selection
    }

    func close() {
        shown = nil
        highlighted = nil
    }

    func send(_ events: HistorySearchEvent...) {
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

/// Where the panel's item block sent the user.
@MainActor
final class MenuDestinations {
    var settingsOpenedAt: [SettingsSection] = []
    var quitCount = 0
}

/// Real Clipboard History in a scratch SQLite file, removed with the value.
final class ScratchHistory {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jevpaste-app-history-\(UUID().uuidString)", isDirectory: true)
    let repository: any HistoryRepository

    init() throws {
        repository = try SQLiteHistoryRepository(fileURL: directory.appendingPathComponent("history.sqlite"))
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}
