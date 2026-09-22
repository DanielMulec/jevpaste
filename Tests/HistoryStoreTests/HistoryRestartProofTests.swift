import Foundation
import HistoryStore
import SmartPasteCore
import Testing

/// Leaves a history file behind for the second-process restart check in the slice report: with
/// `JEVPASTE_HISTORY_PROOF_FILE=/path/history.sqlite`, records 505 distinct copies plus one re-copy there, then
/// another process (the `sqlite3` CLI) counts the rows. Skipped otherwise, so `make check` writes nothing outside
/// temporary directories.
@Suite struct HistoryRestartProofTests {
    static let proofFilePath = ProcessInfo.processInfo.environment["JEVPASTE_HISTORY_PROOF_FILE"]

    @Test(.enabled(if: proofFilePath != nil, "set JEVPASTE_HISTORY_PROOF_FILE to keep a history file"))
    func recordsIntoAKeptFileForASecondProcessToRead() throws {
        let fileURL = URL(fileURLWithPath: try #require(Self.proofFilePath))
        try? FileManager.default.removeItem(at: fileURL)
        let history = try SQLiteHistoryRepository(fileURL: fileURL)

        for index in 1...505 {
            history.record(ClipboardItem(text: "proof item \(index)"))
        }
        history.record(ClipboardItem(text: " proof item 6 "))

        let texts = history.items().map(\.text)
        #expect(texts.count == 500)
        #expect(texts.first == " proof item 6 ")
    }
}
