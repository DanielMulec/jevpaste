import SmartPasteCore
import Testing

@testable import MacInterop

/// One rule for every app: a focused field whose own text is longer than the 2 000-character limit (a terminal's
/// window, a long document or textarea) gives the text around its text cursor, else its last 2 000 characters; the
/// page is not walked. Cursor ranges are UTF-16 offsets, reported unvalidated as an app would.
@MainActor
struct LongOwnTextTests {
    private let lines = (1...400).map { "line \($0)" }.joined(separator: "\n")

    private func surroundingText(of node: FakeNode, reader: TargetContextReader<FakeNode> = .init()) -> String {
        reader.context(of: FocusedElement(processIdentifier: 1, node: node)).surroundingText
    }

    /// A text area inside a page, so a page walk would show up as the page's heading.
    private func textArea(_ value: String, cursor: SelectedTextRange?) -> FakeNode {
        let field = FakeNode("AXTextArea", [.value: value])
        field.reportedSelectedTextRange = cursor
        _ = FakeNode("AXWebArea", children: [FakeNode("AXHeading", [.title: "Page heading"]), field])
        return field
    }

    private func cursor(before marker: String, in text: String) -> SelectedTextRange? {
        text.range(of: marker).map { SelectedTextRange(location: $0.lowerBound.utf16Offset(in: text), length: 0) }
    }

    @Test func aLongOwnTextGivesTheTwoThousandCharactersAroundTheCursorAndNoPageText() {
        let document =
            String(repeating: "far ", count: 1_000) + "BEFORE|AFTER" + String(repeating: " far", count: 1_000)
        let field = textArea(document, cursor: cursor(before: "|", in: document))

        let text = surroundingText(of: field)

        #expect(text.count == 2_000)
        #expect(text.hasSuffix("|AFTER" + String(repeating: " far", count: 123) + " f"))
        #expect(text.hasPrefix("r " + String(repeating: "far ", count: 373) + "BEFORE"))
        #expect(!text.contains("Page heading"))
    }

    @Test func aTerminalScrapeWithTheCursorAtThePromptGivesTheLinesAboveIt() {
        let screen = lines + "\n$ "
        let terminal = textArea(screen, cursor: SelectedTextRange(location: screen.utf16.count, length: 0))

        let text = surroundingText(of: terminal)

        #expect(text.count == 2_000)
        #expect(screen.hasSuffix(text))
    }

    @Test(arguments: [
        nil, SelectedTextRange(location: 0, length: 0), SelectedTextRange(location: 5_000, length: 0),
        SelectedTextRange(location: 10, length: -1),
    ])
    func aLongOwnTextWithoutAUsableCursorGivesItsLastTwoThousandCharacters(cursor: SelectedTextRange?) {
        let terminal = textArea(lines, cursor: cursor)

        let text = surroundingText(of: terminal)

        #expect(text.count == 2_000)
        #expect(lines.hasSuffix(text))
    }

    @Test func anOwnTextOfExactlyTheLimitIsReadWithThePageAndNeverAsksForTheCursor() {
        let field = textArea(String(repeating: "x", count: 2_000), cursor: SelectedTextRange(location: 5, length: 0))

        let text = surroundingText(of: field)

        #expect(text.hasPrefix("Page heading"))
        #expect(field.selectedTextRangeReads == 0)
    }

    @Test func theCursorIsReadOnce() {
        let field = textArea(lines, cursor: SelectedTextRange(location: 100, length: 0))

        _ = surroundingText(of: field)

        #expect(field.selectedTextRangeReads == 1)
    }

    @Test func anExpiredTimeBudgetSkipsTheCursorReadAndGivesTheLastTwoThousandCharacters() {
        let field = textArea(lines, cursor: SelectedTextRange(location: 100, length: 0))

        let text = surroundingText(of: field, reader: TargetContextReader(timeLimit: .zero))

        #expect(lines.hasSuffix(text) && text.count == 2_000)
        #expect(field.selectedTextRangeReads == 0)
    }

    @Test func aSecureFocusedFieldsOwnTextIsNeverRead() {
        let password = FakeNode("AXTextField", [.subrole: "AXSecureTextField", .value: lines])
        _ = FakeNode("AXWebArea", children: [FakeNode("AXHeading", [.title: "Sign in"]), password])

        #expect(surroundingText(of: password) == "Sign in")
    }
}
