import HistoryStore
import SmartPasteCore
import Testing

@Test func sqliteAdapterFillsTheHistoryRepositorySeam() {
    let repository: any HistoryRepository = SQLiteHistoryRepository()
    #expect(repository is SQLiteHistoryRepository)
}
