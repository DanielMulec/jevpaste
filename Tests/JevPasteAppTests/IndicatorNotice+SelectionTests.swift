import SmartPasteCore
import Testing

@testable import JevPasteApp

struct IndicatorNoticeSelectionTests {
    @Test func aSelectionNamesTheNewActiveItemByItsFirstLineForTwoAndAHalfSeconds() {
        let notice = IndicatorNotice(
            activeItemSelected: ClipboardItem(text: "  JEVPASTE-HIST-ONE\nalpha.one@example.org"))

        #expect(notice.content == IndicatorContent(symbolName: "pin.fill", text: "Active: JEVPASTE-HIST-ONE"))
        #expect(notice.displayDuration == .milliseconds(2500))
    }

    @Test func aFirstLineLongerThanFortyCharactersIsCutWithAnEllipsis() {
        let item = ClipboardItem(text: String(repeating: "a", count: 41))

        #expect(
            IndicatorNotice(activeItemSelected: item).content.text == "Active: " + String(repeating: "a", count: 39)
                + "…")
        #expect(
            IndicatorNotice(activeItemSelected: ClipboardItem(text: String(repeating: "b", count: 40))).content.text
                == "Active: " + String(repeating: "b", count: 40)
        )
    }
}
