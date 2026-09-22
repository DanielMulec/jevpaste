import SmartPasteCore
import Testing

@testable import MacInterop

@MainActor
struct TargetContextReaderTests {
    private let reader = TargetContextReader<FakeNode>()

    private func context(of node: FakeNode, bundleIdentifier: String = "com.google.Chrome") -> TargetContext {
        reader.context(of: FocusedElement(processIdentifier: 1, bundleIdentifier: bundleIdentifier, node: node))
    }

    @Test func fieldLabelIsTheTitle() {
        let field = FakeNode("AXTextField", [.title: "Email", .description: "ignored"])
        #expect(context(of: field).fieldLabel == "Email")
    }

    @Test func fieldLabelFallsBackToTheLabellingElement() {
        let field = FakeNode("AXTextField", [.title: ""])
        field.titleElement = FakeNode("AXStaticText", [.value: "Work email"])
        #expect(context(of: field).fieldLabel == "Work email")
    }

    @Test func fieldLabelFallsBackToTheDescription() {
        let field = FakeNode("AXTextArea", [.description: "Message"])
        #expect(context(of: field).fieldLabel == "Message")
    }

    @Test func unlabelledFieldHasNoLabel() {
        #expect(context(of: FakeNode("AXTextArea")).fieldLabel == nil)
    }

    @Test func placeholderIsThePlaceholderValue() {
        let field = FakeNode("AXTextField", [.placeholder: "name@example.com"])
        #expect(context(of: field).placeholder == "name@example.com")
    }

    @Test func sectionHeadingIsTheNearestTitledGroupAbove() {
        let field = FakeNode("AXTextField")
        let untitled = FakeNode("AXGroup", children: [field])
        let fieldset = FakeNode("AXGroup", [.title: "Billing address"], children: [untitled])
        _ = FakeNode("AXGroup", [.title: "Checkout"], children: [fieldset])

        #expect(context(of: field).sectionHeading == "Billing address")
    }

    @Test func sectionHeadingStopsAtThePage() {
        let field = FakeNode("AXTextField")
        _ = FakeNode("AXWebArea", [.title: "Page title"], children: [FakeNode("AXGroup", children: [field])])

        #expect(context(of: field).sectionHeading == nil)
    }

    @Test func siblingFieldLabelsAreTheOtherFieldsOfTheSectionInOrder() {
        let field = FakeNode("AXTextField", [.title: "Email"])
        let name = FakeNode("AXTextField", [.title: "Full name"])
        let phone = FakeNode("AXTextField", [.placeholder: "Phone"])
        let unlabelled = FakeNode("AXTextField")
        let button = FakeNode("AXButton", [.title: "Submit"])
        _ = FakeNode(
            "AXGroup",
            [.title: "Contact"],
            children: [
                FakeNode("AXGroup", children: [name]), FakeNode("AXGroup", children: [field]), phone, unlabelled,
                button,
            ]
        )

        #expect(context(of: field).siblingFieldLabels == ["Full name", "Phone"])
    }

    @Test func siblingFieldLabelsAreCappedAtTen() {
        let field = FakeNode("AXTextField")
        let others = (1...12).map { FakeNode("AXTextField", [.title: "Field \($0)"]) }
        _ = FakeNode("AXGroup", [.title: "Form"], children: [field] + others)

        #expect(context(of: field).siblingFieldLabels == (1...10).map { "Field \($0)" })
    }
}
