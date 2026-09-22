/// Turns clipboard changes into Clipboard Items: the newest foreign copy becomes the Active Item and is recorded
/// in Clipboard History unless it is concealed. Changes produced by our own pasteboard writes are invisible.
@MainActor
public final class CopyCapture {
    public private(set) var activeItem: ClipboardItem?
    private let history: any HistoryRepository
    /// Change counts produced by the Paste Attempt's own writes that have not been observed yet.
    private var ownChangeCounts: Set<Int> = []

    public init(clipboard: any Clipboard, history: any HistoryRepository) {
        self.history = history
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
        activeItem = item
        if !item.isConcealed {
            history.record(item)
        }
    }
}
