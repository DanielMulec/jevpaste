import Foundation
import SmartPasteCore
import Testing

@Suite struct HistoryDeletionTests {
    let file: TemporaryHistoryFile
    let history: any HistoryRepository

    init() throws {
        file = try TemporaryHistoryFile()
        history = try file.openRepository()
        for text in ["Ada Lovelace", "ada@example.org", "London"] {
            history.record(ClipboardItem(text: text))
        }
    }

    @Test func deletingAnItemRemovesOnlyThatItem() {
        history.delete(ClipboardItem(text: "ada@example.org"))

        #expect(history.items().map(\.text) == ["London", "Ada Lovelace"])
    }

    @Test func deletionMatchesByTrimmedText() {
        history.delete(ClipboardItem(text: "\tLondon \n"))

        #expect(history.items().map(\.text) == ["ada@example.org", "Ada Lovelace"])
    }

    @Test func deletingAnItemNotInHistoryChangesNothing() {
        history.delete(ClipboardItem(text: "Paris"))
        history.delete(ClipboardItem(text: "   "))

        #expect(history.items().count == 3)
    }

    @Test func clearAllRemovesEveryItem() {
        history.clearAll()

        #expect(history.items().isEmpty)
    }

    @Test func recordingAfterClearAllStartsAFreshHistory() {
        history.clearAll()
        history.record(ClipboardItem(text: "Paris"))

        #expect(history.items().map(\.text) == ["Paris"])
    }

    @Test func deletedAndClearedTextLeavesNoTraceInTheFile() throws {
        let marker = "deleted-marker-\(UUID().uuidString)"
        history.record(ClipboardItem(text: marker))
        history.delete(ClipboardItem(text: marker))
        let clearedMarker = "cleared-marker-\(UUID().uuidString)"
        history.record(ClipboardItem(text: clearedMarker))
        history.clearAll()
        _ = history.items()

        let fileBytes = try Data(contentsOf: file.fileURL)
        #expect(fileBytes.range(of: Data(marker.utf8)) == nil)
        #expect(fileBytes.range(of: Data(clearedMarker.utf8)) == nil)
    }
}
