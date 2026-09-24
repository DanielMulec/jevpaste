import SmartPasteCore
import Testing

@testable import JevPasteApp

struct HistoryPanelContentTests {
    private static let card = ClipboardItem(
        text: "\n  Maren Holtby  \nmaren.holtby@example.org\n\n+49 30 5550 1234\nBerlin\n")
    private static let email = ClipboardItem(text: "wren.castellan@example.net")
    private static let accented = ClipboardItem(text: "Café Zürich\nBahnhofstrasse 1")

    private static func content(
        _ history: [ClipboardItem], active: ClipboardItem? = nil, query: String = ""
    ) -> HistoryPanelContent {
        HistoryPanelContent(
            matches: HistoryPanelContent.items(in: history, matching: query), activeItem: active, query: query
        )
    }

    @Test func aRowShowsTheFirstNonBlankLineTrimmedAndTheLineCountOfAMultiLineItem() {
        let rows = Self.content([Self.card, Self.email]).rows

        #expect(
            rows == [
                HistoryRow(title: "Maren Holtby", detail: "5 lines", isActive: false),
                HistoryRow(title: "wren.castellan@example.net", detail: nil, isActive: false),
            ]
        )
    }

    @Test func theActiveItemsRowIsMarkedByItsTrimmedTextIdentity() {
        let active = ClipboardItem(text: "  wren.castellan@example.net\n")

        let rows = Self.content([Self.card, Self.email], active: active).rows

        #expect(rows.map(\.isActive) == [false, true])
    }

    @Test func differentlyEncodedTextIsNotTheActiveItem() {
        let composed = ClipboardItem(text: "Caf\u{E9}")
        let decomposed = ClipboardItem(text: "Cafe\u{301}")

        #expect(Self.content([decomposed], active: composed).rows.map(\.isActive) == [false])
    }

    @Test func theQueryMatchesAnywhereInTheTextIgnoringCaseAndDiacritics() {
        let history = [Self.card, Self.email, Self.accented]

        #expect(HistoryPanelContent.items(in: history, matching: "BERLIN") == [Self.card])
        #expect(HistoryPanelContent.items(in: history, matching: "zurich") == [Self.accented])
        #expect(HistoryPanelContent.items(in: history, matching: "  ") == history)
    }

    @Test func emptyHistoryAndAQueryWithoutMatchesSayWhichItIs() {
        #expect(Self.content([]).emptyMessage == "No History Yet")
        #expect(Self.content([Self.email], query: "zzz").emptyMessage == "No Matches")
    }

    @Test func theActiveItemPreviewShowsTheFirstThreeNonBlankLinesAndCountsTheRest() {
        #expect(
            Self.content([], active: Self.card).activeItem
                == .text(lines: ["Maren Holtby", "maren.holtby@example.org", "+49 30 5550 1234"], moreLineCount: 1)
        )
        #expect(Self.content([], active: Self.email).activeItem == .text(lines: [Self.email.text], moreLineCount: 0))
    }

    @Test func aConcealedActiveItemIsNeverShownAndNoActiveItemSaysSo() {
        let password = ClipboardItem(text: "correct horse battery staple", isConcealed: true)

        #expect(Self.content([], active: password).activeItem == .concealed)
        #expect(Self.content([]).activeItem == .nothing)
    }
}
