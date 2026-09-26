import Foundation
import SmartPasteCore
import Testing

/// History Search: typing filters Clipboard History; the menu lists the newest five matches and says how many
/// matched out of how many items.
@Suite struct HistorySearchTests {
    private static func history(_ texts: [String]) -> [HistoryEntry] {
        texts.map { HistoryEntry(item: ClipboardItem(text: $0), copiedAt: nil) }
    }

    @Test func theNewestFiveMatchesAreListedWithTheMatchAndHistoryCounts() throws {
        let history = Self.history([
            "ada7@example.org", "London", "ada6@example.org", "ada5@example.org", "ada4@example.org",
            "ada3@example.org", "ada2@example.org", "ada1@example.org",
        ])

        let results = try #require(HistorySearch.results(for: "ada", in: history))

        #expect(
            results.matches.map(\.item.text) == [
                "ada7@example.org", "ada6@example.org", "ada5@example.org", "ada4@example.org", "ada3@example.org",
            ])
        #expect(results.matchCount == 7)
        #expect(results.historyCount == 8)
    }

    @Test(arguments: ["ZURICH", "zürich", "Zurich"])
    func caseAndDiacriticsAreIgnored(query: String) throws {
        let history = Self.history(["Mira Holzner\nZürich", "Graz"])

        let results = try #require(HistorySearch.results(for: query, in: history))

        #expect(results.matches.map(\.item.text) == ["Mira Holzner\nZürich"])
    }

    @Test func theQueryIsTrimmedButMatchesAcrossLinesAnywhereInTheText() throws {
        let history = Self.history(["Name: Ada\nCity: Graz", "Graz"])

        let results = try #require(HistorySearch.results(for: "  ada\nCity \n", in: history))

        #expect(results.matches.map(\.item.text) == ["Name: Ada\nCity: Graz"])
    }

    @Test(arguments: ["", "   ", "\n\t "])
    func aBlankQueryIsNoSearch(query: String) {
        #expect(HistorySearch.results(for: query, in: Self.history(["ada@example.org"])) == nil)
    }

    @Test func noMatchListsNothingAndStillCountsTheHistory() throws {
        let results = try #require(HistorySearch.results(for: "berlin", in: Self.history(["London", "Graz"])))

        #expect(results.matches.isEmpty)
        #expect(results.matchCount == 0)
        #expect(results.historyCount == 2)
    }
}
