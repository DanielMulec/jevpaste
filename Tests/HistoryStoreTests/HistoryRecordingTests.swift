import SmartPasteCore
import Testing

@Suite struct HistoryRecordingTests {
    let file: TemporaryHistoryFile
    let history: any HistoryRepository

    init() throws {
        file = try TemporaryHistoryFile()
        history = try file.openRepository()
    }

    @Test func recordedItemIsReadBack() {
        history.record(ClipboardItem(text: "Ada Lovelace"))

        #expect(history.items() == [ClipboardItem(text: "Ada Lovelace")])
    }

    @Test func itemsAreNewestFirst() {
        for text in ["first", "second", "third"] {
            history.record(ClipboardItem(text: text))
        }

        #expect(history.items().map(\.text) == ["third", "second", "first"])
    }

    @Test func readRightAfterRecordOnTheSameThreadSeesTheItem() {
        for index in 1...50 {
            history.record(ClipboardItem(text: "item \(index)"))
            #expect(history.items().first?.text == "item \(index)")
        }
    }

    @Test func reCopyMovesTheItemToTheTopAndKeepsTheLatestExactText() {
        history.record(ClipboardItem(text: "ada@example.org"))
        history.record(ClipboardItem(text: "London"))
        history.record(ClipboardItem(text: "  ada@example.org\n"))

        #expect(history.items().map(\.text) == ["  ada@example.org\n", "London"])
    }

    @Test func innerWhitespaceAndCaseKeepItemsDistinct() {
        for text in ["Ada Lovelace", "Ada  Lovelace", "ada lovelace"] {
            history.record(ClipboardItem(text: text))
        }

        #expect(history.items().count == 3)
    }

    @Test func differentlyEncodedEqualTextStaysDistinct() {
        history.record(ClipboardItem(text: "Caf\u{E9}"))
        history.record(ClipboardItem(text: "Cafe\u{301}"))

        #expect(history.items().map { Array($0.text.utf8) } == [Array("Cafe\u{301}".utf8), Array("Caf\u{E9}".utf8)])
    }

    @Test func concealedItemIsRefused() {
        history.record(ClipboardItem(text: "hunter2", isConcealed: true))

        #expect(history.items().isEmpty)
    }

    @Test(arguments: ["", " ", "\n\t  \r\n"])
    func emptyOrWhitespaceOnlyItemIsRefused(text: String) {
        history.record(ClipboardItem(text: text))

        #expect(history.items().isEmpty)
    }

    @Test func multiMegabyteItemRoundTripsByteForByte() {
        let line = "Zeile mit Umlauten äöü, Emoji 🧪 und\tTab\n"
        let largeText = String(repeating: line, count: 4 * 1024 * 1024 / line.utf8.count)

        history.record(ClipboardItem(text: largeText))

        #expect(history.items().map { Array($0.text.utf8) } == [Array(largeText.utf8)])
    }

    @Test func textWithAnEmbeddedNulCharacterRoundTrips() {
        history.record(ClipboardItem(text: "before\u{0}after"))

        #expect(history.items().map(\.text) == ["before\u{0}after"])
    }
}
