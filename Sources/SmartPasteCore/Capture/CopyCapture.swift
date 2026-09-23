/// Turns clipboard changes into Clipboard Items: the newest foreign copy becomes the Active Item and is recorded
/// in Clipboard History unless it is concealed. Changes produced by our own pasteboard writes are invisible.
@MainActor
public final class CopyCapture {
    public private(set) var activeItem: ClipboardItem?
    private let history: any HistoryRepository
    /// Change counts produced by the Paste Attempt's own writes that have not been observed yet.
    private var ownChangeCounts: Set<Int> = []

    /// - Parameter contentsAtLaunch: The text already on the clipboard when the app starts, as the `Clipboard`
    ///   adapter reads it (markers first). It counts as a copy: it becomes the Active Item and is recorded unless
    ///   concealed. `nil` when the clipboard holds no text.
    public init(clipboard: any Clipboard, history: any HistoryRepository, contentsAtLaunch: ClipboardItem? = nil) {
        self.history = history
        if let contentsAtLaunch {
            adopt(contentsAtLaunch)
        }
        clipboard.startObservingChanges { [weak self] change in
            self?.clipboardChanged(change)
        }
    }

    /// Declares that `changeCount` came from our own write, so observing it produces no Clipboard Item.
    func markOwnWrite(_ changeCount: Int) {
        ownChangeCounts.insert(changeCount)
    }

    private func clipboardChanged(_ change: ClipboardChange) {
        guard ownChangeCounts.remove(change.changeCount) == nil, let item = change.item else { return }
        adopt(item)
    }

    /// A copy becomes the Active Item and, unless concealed, enters Clipboard History.
    private func adopt(_ item: ClipboardItem) {
        activeItem = item
        if !item.isConcealed {
            history.record(item)
        }
    }
}
