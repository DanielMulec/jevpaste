import SmartPasteCore
import Testing

/// The Core fake follows the `HistoryRepository` contract, so Core tests that read history see what the SQLite
/// adapter would return.
@MainActor
@Suite struct FakeHistoryRepositoryTests {
    @Test func reCopyByTrimmedTextMovesToTopWithTheLatestExactText() {
        let fake = FakeHistoryRepository()
        for text in ["ada@example.org", "London", " ada@example.org\n"] {
            fake.record(ClipboardItem(text: text))
        }

        #expect(fake.items().map(\.text) == [" ada@example.org\n", "London"])
    }

    @Test func concealedAndBlankItemsAreRefused() {
        let fake = FakeHistoryRepository()
        fake.record(ClipboardItem(text: "hunter2", isConcealed: true))
        fake.record(ClipboardItem(text: " \n"))

        #expect(fake.items().isEmpty)
    }

    @Test func differentlyEncodedTextStaysDistinct() {
        let fake = FakeHistoryRepository()
        fake.record(ClipboardItem(text: "Caf\u{E9}"))
        fake.record(ClipboardItem(text: "Cafe\u{301}"))

        #expect(fake.items().count == 2)
    }

    @Test func retentionLimitEvictsTheOldest() {
        let fake = FakeHistoryRepository(retentionLimit: 2)
        for text in ["a", "b", "c"] {
            fake.record(ClipboardItem(text: text))
        }
        #expect(fake.items().map(\.text) == ["c", "b"])

        fake.changeRetentionLimit(to: 0)
        #expect(fake.items().map(\.text) == ["c"])
    }

    @Test func deleteMatchesByTrimmedTextAndClearAllEmpties() {
        let fake = FakeHistoryRepository()
        fake.record(ClipboardItem(text: "London"))
        fake.record(ClipboardItem(text: "Paris"))

        fake.delete(ClipboardItem(text: "\tLondon "))
        #expect(fake.items().map(\.text) == ["Paris"])

        fake.clearAll()
        #expect(fake.items().isEmpty)
    }
}
