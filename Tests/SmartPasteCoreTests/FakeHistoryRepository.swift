import Foundation
import SmartPasteCore

/// In-memory Clipboard History that follows the `HistoryRepository` contract (refusals, trimmed-text identity,
/// move-to-top with the latest copy time, retention), and also logs every `record` call in `recordedItems`.
final class FakeHistoryRepository: HistoryRepository {
    private let state: MainActorState

    @MainActor
    private final class MainActorState {
        var recordedItems: [ClipboardItem] = []
        /// Newest first.
        var history: [HistoryEntry] = []
        var retentionLimit: Int

        init(retentionLimit: Int) {
            self.retentionLimit = retentionLimit
        }

        func evictBeyondRetentionLimit() {
            history = Array(history.prefix(retentionLimit))
        }
    }

    /// The copy time `record(_:)` gives the tests that do not care about it.
    static let someCopyTime = Date(timeIntervalSince1970: 1_790_000_000)

    init(retentionLimit: Int = 500) {
        state = MainActor.assumeIsolated { MainActorState(retentionLimit: max(retentionLimit, 1)) }
    }

    /// The contract's identity: the text's UTF-8 bytes after trimming; `nil` for blank text.
    private static func identity(of item: ClipboardItem) -> [UInt8]? {
        let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Array(trimmed.utf8)
    }

    func record(_ item: ClipboardItem, copiedAt: Date) {
        MainActor.assumeIsolated {
            state.recordedItems.append(item)
            guard !item.isConcealed, let identity = Self.identity(of: item) else { return }
            state.history.removeAll { Self.identity(of: $0.item) == identity }
            state.history.insert(HistoryEntry(item: item, copiedAt: copiedAt), at: 0)
            state.evictBeyondRetentionLimit()
        }
    }

    func record(_ item: ClipboardItem) {
        record(item, copiedAt: Self.someCopyTime)
    }

    func entries() -> [HistoryEntry] {
        MainActor.assumeIsolated { state.history }
    }

    /// The entries' items, newest first.
    func items() -> [ClipboardItem] {
        entries().map(\.item)
    }

    func delete(_ item: ClipboardItem) {
        guard let identity = Self.identity(of: item) else { return }
        MainActor.assumeIsolated { state.history.removeAll { Self.identity(of: $0.item) == identity } }
    }

    func clearAll() {
        MainActor.assumeIsolated { state.history.removeAll() }
    }

    func changeRetentionLimit(to limit: Int) {
        MainActor.assumeIsolated {
            state.retentionLimit = max(limit, 1)
            state.evictBeyondRetentionLimit()
        }
    }

    /// Every item passed to `record`, oldest first, including refused ones.
    @MainActor var recordedItems: [ClipboardItem] { state.recordedItems }
}
