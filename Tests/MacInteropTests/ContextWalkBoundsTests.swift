import SmartPasteCore
import Testing

@testable import MacInterop

/// Accessibility trees come from other apps: they can be deep, cyclic or enormous. Reading Target Context must
/// end quickly regardless.
@MainActor
struct ContextWalkBoundsTests {
    private func context(of node: FakeNode, reader: TargetContextReader<FakeNode> = .init()) -> TargetContext {
        reader.context(of: FocusedElement(processIdentifier: 1, bundleIdentifier: "com.example", node: node))
    }

    @Test func climbingTowardsThePageStopsAfterThirtyTwoAncestors() {
        let field = FakeNode("AXTextField")
        var top = FakeNode("AXGroup", children: [field])
        for _ in 1..<100 { top = FakeNode("AXGroup", children: [top]) }
        _ = FakeNode("AXWindow", [.title: "Far away"], children: [top])

        #expect(!context(of: field).surroundingText.contains("Far away"))
    }

    @Test func cyclicAncestryEnds() {
        let field = FakeNode("AXTextField", [.title: "Email"])
        let outer = FakeNode("AXGroup", [.description: "loop"])
        let inner = FakeNode("AXGroup", children: [field])
        outer.adopt(inner)
        inner.adopt(outer)

        let context = context(of: field)

        #expect(context.fieldLabel == "Email")
        #expect(context.surroundingText.split(separator: "\n").count <= 600)
    }

    @Test func onlyTheFirstHundredChildrenOfAnElementAreRead() {
        let field = FakeNode("AXTextField")
        let lines = (0..<10_000).map { _ in FakeNode("AXStaticText", [.value: "x"]) }
        _ = FakeNode("AXWebArea", children: [field] + lines)

        #expect(context(of: field).surroundingText.split(separator: "\n").count == 99)
    }

    @Test func expiredTimeBudgetLeavesSiblingsAndSurroundingTextEmptyButKeepsTheLabels() {
        let field = FakeNode("AXTextField", [.title: "Email", .placeholder: "you@example.com"])
        let name = FakeNode("AXTextField", [.title: "Name"])
        _ = FakeNode(
            "AXWebArea",
            children: [FakeNode("AXGroup", [.title: "Contact"], children: [name, field, FakeNode("AXStaticText")])]
        )

        let context = context(of: field, reader: TargetContextReader(timeLimit: .zero))

        #expect(context.fieldLabel == "Email")
        #expect(context.placeholder == "you@example.com")
        #expect(context.sectionHeading == "Contact")
        #expect(context.siblingFieldLabels.isEmpty)
        #expect(context.surroundingText.isEmpty)
    }
}
