import Foundation
import SmartPasteCore
import Testing

/// The copy time behind "N lines · 12 min ago": stamped by the caller at `record`, read back with every entry, and
/// absent — never invented — for items that a version-1 file (before copy times) already held.
@Suite struct HistoryCopyTimeTests {
    private let firstCopy = Date(timeIntervalSince1970: 1_790_000_000)
    private let laterCopy = Date(timeIntervalSince1970: 1_790_000_600)

    @Test func theCopyTimeIsReadBackWithTheItem() throws {
        let file = try TemporaryHistoryFile()
        let history = try file.openRepository()

        history.record(ClipboardItem(text: "ada@example.org"), copiedAt: firstCopy)

        #expect(history.entries() == [HistoryEntry(item: ClipboardItem(text: "ada@example.org"), copiedAt: firstCopy)])
    }

    @Test func aReCopyKeepsTheLatestCopyTime() throws {
        let file = try TemporaryHistoryFile()
        let history = try file.openRepository()

        history.record(ClipboardItem(text: "ada@example.org"), copiedAt: firstCopy)
        history.record(ClipboardItem(text: "London"), copiedAt: firstCopy)
        history.record(ClipboardItem(text: " ada@example.org\n"), copiedAt: laterCopy)

        #expect(history.entries().map(\.copiedAt) == [laterCopy, firstCopy])
    }

    @Test func aVersionOneFileKeepsItsItemsInOrderWithoutACopyTime() throws {
        let file = try TemporaryHistoryFile()
        try file.copyFixture(named: "history-v1.sqlite")

        let entries = try file.openRepository().entries()

        #expect(
            entries.map(\.item.text) == [
                "JEVPASTE-V1-NEWER newer.v1@example.org", "JEVPASTE-V1-OLDER\nolder.v1@example.org",
            ])
        #expect(entries.map(\.copiedAt) == [nil, nil])
    }

    @Test func aMigratedFileTakesNewCopiesWithTheirTimeAndOpensAgain() throws {
        let file = try TemporaryHistoryFile()
        try file.copyFixture(named: "history-v1.sqlite")
        let migrated = try file.openRepository()
        migrated.record(ClipboardItem(text: "JEVPASTE-V2-NEW"), copiedAt: laterCopy)
        _ = migrated.entries()  // waits for the write on the repository's queue

        let entries = try file.openRepository().entries()

        #expect(entries.map(\.item.text).first == "JEVPASTE-V2-NEW")
        #expect(entries.map(\.copiedAt) == [laterCopy, nil, nil])
    }
}
