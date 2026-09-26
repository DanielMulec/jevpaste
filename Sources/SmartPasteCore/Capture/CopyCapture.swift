import Foundation

/// Turns clipboard changes into Clipboard Items: the newest foreign copy becomes the Active Item and is recorded
/// in Clipboard History unless it is concealed. Changes produced by our own pasteboard writes are invisible.
/// An explicit selection from Clipboard History also makes an item Active, until the next copy or selection.
@MainActor
public final class CopyCapture {
    public private(set) var activeItem: ClipboardItem?
    private let history: any HistoryRepository
    /// The wall-clock time a copy is recorded with; it only describes the entry ("12 min ago").
    private let now: @MainActor () -> Date
    private var onActiveItemChange: (@MainActor (ActiveItemChange) -> Void)?
    /// Change counts produced by the Paste Attempt's own writes that have not been observed yet.
    private var ownChangeCounts: Set<Int> = []

    /// - Parameter contentsAtLaunch: Reads the text already on the clipboard when the app starts, as the
    ///   `Clipboard` adapter sees it (markers first); `nil` when it holds no text. It counts as a copy: it becomes
    ///   the Active Item and is recorded unless concealed. It is called once, *after* observation has started, so
    ///   a copy landing in between is adopted at launch rather than lost; the observer may report that copy once more,
    ///   which history treats as a re-copy of the same item.
    /// - Parameter now: The time each copy — the launch contents included — is recorded with.
    public init(
        clipboard: any Clipboard,
        history: any HistoryRepository,
        contentsAtLaunch: @MainActor () -> ClipboardItem? = { nil },
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.history = history
        self.now = now
        clipboard.startObservingChanges { [weak self] change in
            self?.clipboardChanged(change)
        }
        if let launchContents = contentsAtLaunch() {
            adopt(launchContents)
        }
    }

    /// Rejev-paste: an older Clipboard Item chosen inside the app becomes the Active Item until the next copy or
    /// selection. Clipboard History and the clipboard stay untouched, so the item keeps its place and ordinary ⌘V
    /// still pastes the clipboard. A Paste Attempt already running keeps the item it pinned.
    public func select(_ item: ClipboardItem) {
        activate(item, cause: .selected)
    }

    /// Calls `onChange` on the main actor after every later Active Item change: each foreign copy and each
    /// selection. One observer (the shell); Launch Adoption happens before anyone observes and is not reported.
    public func observeActiveItemChanges(_ onChange: @escaping @MainActor (ActiveItemChange) -> Void) {
        onActiveItemChange = onChange
    }

    /// Declares that `changeCount` came from our own write, so observing it produces no Clipboard Item.
    func markOwnWrite(_ changeCount: Int) {
        ownChangeCounts.insert(changeCount)
    }

    private func clipboardChanged(_ change: ClipboardChange) {
        guard ownChangeCounts.remove(change.changeCount) == nil, let item = change.item else { return }
        adopt(item)
    }

    /// Adoption: a copy (live, or the launch contents — Launch Adoption) becomes the Active Item and, unless
    /// concealed, enters Clipboard History.
    private func adopt(_ item: ClipboardItem) {
        if !item.isConcealed {
            history.record(item, copiedAt: now())
        }
        activate(item, cause: .copied)
    }

    private func activate(_ item: ClipboardItem, cause: ActiveItemChange.Cause) {
        activeItem = item
        onActiveItemChange?(ActiveItemChange(item: item, cause: cause))
    }
}
