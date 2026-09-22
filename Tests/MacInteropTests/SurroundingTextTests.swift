import SmartPasteCore
import Testing

@testable import MacInterop

@MainActor
struct SurroundingTextTests {
    private let reader = TargetContextReader<FakeNode>()

    private func surroundingText(of node: FakeNode, bundleIdentifier: String = "com.google.Chrome") -> String {
        let focused = FocusedElement(processIdentifier: 1, bundleIdentifier: bundleIdentifier, node: node)
        return reader.context(of: focused).surroundingText
    }

    @Test func pageTextIsCollectedBreadthFirstFromTheWebAreaNotTheBrowserChrome() {
        let field = FakeNode("AXTextField", [.title: "Email"])
        let page = FakeNode(
            "AXWebArea",
            children: [
                FakeNode("AXHeading", [.title: "Contact us"]),
                FakeNode("AXGroup", children: [FakeNode("AXStaticText", [.value: "Your email"]), field]),
                FakeNode("AXStaticText", [.value: "We reply within a day"]),
            ]
        )
        _ = FakeNode("AXWindow", children: [FakeNode("AXButton", [.description: "Back"]), page])

        #expect(surroundingText(of: field) == "Contact us\nWe reply within a day\nYour email\nEmail")
    }

    @Test func withoutAPageTheFocusedWindowIsTheScope() {
        let field = FakeNode("AXTextArea", [.placeholder: "Message"])
        _ = FakeNode(
            "AXWindow",
            [.title: "Chat with Jane"],
            children: [FakeNode("AXStaticText", [.value: "See you at 5"]), field]
        )

        #expect(surroundingText(of: field) == "Chat with Jane\nSee you at 5")
    }

    @Test func secureFieldsContributeNothing() {
        let field = FakeNode("AXTextField")
        let password = FakeNode("AXTextField", [.subrole: "AXSecureTextField", .value: "hunter2", .title: "Password"])
        _ = FakeNode("AXWebArea", children: [field, password])

        #expect(surroundingText(of: field) == "")
    }

    @Test func surroundingTextIsCappedAtTwoThousandCharactersFromTheStart() {
        let field = FakeNode("AXTextField")
        let paragraphs = (0..<10).map { FakeNode("AXStaticText", [.value: String(repeating: "\($0)", count: 300)]) }
        _ = FakeNode("AXWebArea", children: paragraphs + [field])

        let text = surroundingText(of: field)

        #expect(text.count == 2_000)
        #expect(text.hasPrefix(String(repeating: "0", count: 300) + "\n" + String(repeating: "1", count: 300)))
    }

    @Test func capNeverSplitsAGraphemeCluster() {
        let field = FakeNode("AXTextField")
        let family = "👩‍👩‍👧"
        let paragraph = FakeNode("AXStaticText", [.value: String(repeating: "a", count: 1_999) + family + "b"])
        _ = FakeNode("AXWebArea", children: [paragraph, field])

        #expect(surroundingText(of: field).hasSuffix("a" + family))
    }

    @Test func walkStopsAtSixHundredNodes() {
        let field = FakeNode("AXTextField")
        let lines = (0..<700).map { _ in FakeNode("AXStaticText", [.value: "x"]) }
        _ = FakeNode("AXWebArea", children: [field] + lines)

        let collectedLines = surroundingText(of: field).split(separator: "\n").count
        #expect(collectedLines > 500 && collectedLines < 600)
    }

    @Test func terminalGetsTheLastTwoThousandCharactersOfItsWindowScrape() {
        let screen = (1...400).map { "line \($0)" }.joined(separator: "\n")
        let terminal = FakeNode("AXTextArea", [.value: screen])
        _ = FakeNode("AXWindow", [.title: "zsh"], children: [FakeNode("AXGroup", children: [terminal])])

        let text = surroundingText(of: terminal, bundleIdentifier: "com.mitchellh.ghostty")

        #expect(text.count == 2_000)
        #expect(screen.hasSuffix(text))
    }
}
