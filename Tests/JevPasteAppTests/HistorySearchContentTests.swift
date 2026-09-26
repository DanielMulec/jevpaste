import Foundation
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// What the History Search panel shows for a query: the placeholder, "N of M matches", two-line rows and the item
/// block. Display only; choosing acts on the untouched entry.
@MainActor
struct HistorySearchContentTests {
    private static let now = Date(timeIntervalSince1970: 1_790_000_000)
    private static let card = ClipboardItem(text: "  Mira Holzner\n\nmira@example.org\n8020 Graz\n")

    private static func entry(_ text: String, minutesAgo: Double?) -> HistoryEntry {
        HistoryEntry(item: ClipboardItem(text: text), copiedAt: minutesAgo.map { now.addingTimeInterval(-60 * $0) })
    }

    @Test func aBlankQueryShowsOnlySettingsAndQuitUnderTheField() {
        let content = HistorySearchContent(
            query: " ", history: [Self.entry("Graz", minutesAgo: 1)], activeItem: nil,
            now: Self.now)

        #expect(content.rows.isEmpty)
        #expect(content.matchSummary == nil)
        #expect(content.menuItems == [.settings, .quit])
    }

    @Test func aQueryListsTheMatchesWithTheirCountsAndTheFullHistoryCount() {
        let history =
            (1...7).map { Self.entry("ada\($0)@example.org", minutesAgo: Double($0)) }
            + [Self.entry("Graz", minutesAgo: 30)]

        let content = HistorySearchContent(query: "ada", history: history, activeItem: nil, now: Self.now)

        #expect(content.matchSummary == "5 of 7 matches")
        #expect(content.rows.map(\.title) == (1...5).map { "ada\($0)@example.org" })
        #expect(content.menuItems == [.fullHistory(itemCount: 8), .settings, .quit])
        #expect(!content.saysNothingMatches)
    }

    @Test func aRowShowsTheFirstLineAndHowLongAndHowOldTheItemIs() {
        let history = [
            HistoryEntry(item: Self.card, copiedAt: Self.now.addingTimeInterval(-12 * 60)),
            Self.entry("mira.h@example.net", minutesAgo: 3 * 60),
            Self.entry("Mira", minutesAgo: 2 * 24 * 60),
            Self.entry("mira", minutesAgo: 0.5),
            Self.entry("Mira v1", minutesAgo: nil),
        ]

        let content = HistorySearchContent(query: "mira", history: history, activeItem: nil, now: Self.now)

        #expect(content.rows.map(\.title) == ["Mira Holzner", "mira.h@example.net", "Mira", "mira", "Mira v1"])
        #expect(
            content.rows.map(\.detail) == [
                "4 lines · 12 min ago", "18 chars · 3 h ago", "4 chars · 2 d ago", "4 chars · just now", "7 chars",
            ])
    }

    @Test func theActiveItemsRowIsMarkedByItsTrimmedText() {
        let history = [Self.entry("Graz", minutesAgo: 1), Self.entry("8020 Graz", minutesAgo: 2)]

        let content = HistorySearchContent(
            query: "graz", history: history, activeItem: ClipboardItem(text: "8020 Graz\n"), now: Self.now
        )

        #expect(content.rows.map(\.isActive) == [false, true])
    }

    @Test func noMatchSaysSoAndStillOffersTheFullHistory() {
        let content = HistorySearchContent(
            query: "berlin", history: [Self.entry("Graz", minutesAgo: 1)], activeItem: nil, now: Self.now
        )

        #expect(content.saysNothingMatches)
        #expect(content.matchSummary == nil)
        #expect(content.menuItems == [.fullHistory(itemCount: 1), .settings, .quit])
    }

    @Test(arguments: [
        (ClipboardItem?.some(ClipboardItem(text: "  Mira Holzner\nmira@example.org")), "Mira Holzner"),
        (ClipboardItem(text: "hunter2", isConcealed: true), "Search Clipboard History"),
        (nil, "Search Clipboard History"),
    ])
    func thePlaceholderIsTheActiveItemsFirstLineButNeverAConcealedOne(active: ClipboardItem?, placeholder: String) {
        let content = HistorySearchContent(query: "", history: [], activeItem: active, now: Self.now)

        #expect(content.placeholder == placeholder)
    }
}
