import SmartPasteCore
import Testing

@testable import JevPasteApp

/// Settings › Full History: every Clipboard Item newest first with the "Active" tag, per-item deletion and Clear
/// History; the Active Item stays Active through both.
@MainActor
struct FullHistoryListTests {
    private let scratch: ScratchHistory
    private let clipboard = CopyingClipboard()
    private let capture: CopyCapture
    private let list: FullHistoryList

    init() throws {
        scratch = try ScratchHistory()
        capture = CopyCapture(clipboard: clipboard, history: scratch.repository)
        list = FullHistoryList(
            history: scratch.repository, capture: capture, changes: ActiveItemChanges(capture: capture))
        for text in ["JEVPASTE-FULL-ONE\none@example.org", "JEVPASTE-FULL-TWO", "JEVPASTE-FULL-THREE"] {
            clipboard.copy(text)
        }
        list.reload()
    }

    @Test func listsEveryItemNewestFirstWithTheActiveTagAndTheCount() {
        #expect(list.rows.map(\.title) == ["JEVPASTE-FULL-THREE", "JEVPASTE-FULL-TWO", "JEVPASTE-FULL-ONE"])
        #expect(list.rows.map(\.isActive) == [true, false, false])
        #expect(list.rows.last?.detail.hasPrefix("2 lines") == true)
        #expect(list.countText == "3 Clipboard Items")
    }

    @Test func theListFollowsSelectionsAndCopiesAndSaysSo() {
        var redraws = 0
        list.onChange = { redraws += 1 }

        capture.select(ClipboardItem(text: "JEVPASTE-FULL-ONE\none@example.org"))
        #expect(list.rows.map(\.isActive) == [false, false, true])

        clipboard.copy("JEVPASTE-FULL-FOUR")
        #expect(list.rows.map(\.title).first == "JEVPASTE-FULL-FOUR")
        #expect(redraws == 2)
    }

    @Test func deletingARowRemovesThatItemAndTheActiveItemStaysActive() {
        list.delete(row: 0)

        #expect(list.rows.map(\.title) == ["JEVPASTE-FULL-TWO", "JEVPASTE-FULL-ONE"])
        #expect(list.countText == "2 Clipboard Items")
        #expect(capture.activeItem == ClipboardItem(text: "JEVPASTE-FULL-THREE"))
    }

    @Test func clearingEmptiesTheListAndKeepsTheActiveItem() {
        list.clearAll()

        #expect(list.rows.isEmpty)
        #expect(list.countText == "0 Clipboard Items")
        #expect(capture.activeItem == ClipboardItem(text: "JEVPASTE-FULL-THREE"))
    }

    @Test func oneItemIsCountedInTheSingular() {
        list.delete(row: 0)
        list.delete(row: 0)

        #expect(list.countText == "1 Clipboard Item")
    }
}
