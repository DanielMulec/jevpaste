import HistoryStore
import SmartPasteCore
import Testing

@Suite struct HistoryRetentionTests {
    let file: TemporaryHistoryFile

    init() throws {
        file = try TemporaryHistoryFile()
    }

    private func record(_ texts: [String], in history: any HistoryRepository) {
        for text in texts {
            history.record(ClipboardItem(text: text))
        }
    }

    @Test func defaultRetentionKeepsFiveHundredItemsEvictingTheOldest() throws {
        let history = try SQLiteHistoryRepository(fileURL: file.fileURL)

        record((1...501).map { "item \($0)" }, in: history)

        let texts = history.items().map(\.text)
        #expect(texts.count == 500)
        #expect(texts.first == "item 501")
        #expect(texts.last == "item 2")
    }

    @Test func customLimitIsRespected() throws {
        let history = try file.openRepository(retentionLimit: 3)

        record(["a", "b", "c", "d"], in: history)

        #expect(history.items().map(\.text) == ["d", "c", "b"])
    }

    @Test func burstBeyondTheLimitLeavesExactlyTheNewestLimitItems() throws {
        let history = try file.openRepository(retentionLimit: 10)

        record((1...100).map { "burst \($0)" }, in: history)

        #expect(history.items().map(\.text) == (91...100).reversed().map { "burst \($0)" })
    }

    @Test func reCopyOfTheOldestItemSavesItFromEviction() throws {
        let history = try file.openRepository(retentionLimit: 3)
        record(["a", "b", "c"], in: history)

        record(["a", "d"], in: history)

        #expect(history.items().map(\.text) == ["d", "a", "c"])
    }

    @Test func loweringTheLimitEvictsTheOldestAtOnce() throws {
        let history = try file.openRepository(retentionLimit: 5)
        record(["a", "b", "c", "d", "e"], in: history)

        history.changeRetentionLimit(to: 2)

        #expect(history.items().map(\.text) == ["e", "d"])
    }

    @Test func raisingTheLimitKeepsMoreFromThenOn() throws {
        let history = try file.openRepository(retentionLimit: 2)
        record(["a", "b", "c"], in: history)

        history.changeRetentionLimit(to: 3)
        record(["d"], in: history)

        #expect(history.items().map(\.text) == ["d", "c", "b"])
    }

    @Test(arguments: [0, -5])
    func limitBelowOneIsClampedToOne(limit: Int) throws {
        let openedWithLimit = try file.openRepository(retentionLimit: limit)
        record(["a", "b"], in: openedWithLimit)
        #expect(openedWithLimit.items().map(\.text) == ["b"])

        openedWithLimit.changeRetentionLimit(to: limit)
        record(["c"], in: openedWithLimit)
        #expect(openedWithLimit.items().map(\.text) == ["c"])
    }
}
