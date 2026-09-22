@testable import MacInterop

/// An in-memory Accessibility element: a role plus text attributes, linked into a tree like AX exposes it.
@MainActor
final class FakeNode: AccessibilityNode {
    private var texts: [AccessibilityTextAttribute: String]
    private var childNodes: [FakeNode] = []
    /// Strong on purpose: tests build a tree and keep only the leaf. The cycle is released with the test process.
    private(set) var parent: FakeNode?
    var titleElement: FakeNode?
    var isSelectedTextRangeSettable = false

    init(_ role: String, _ texts: [AccessibilityTextAttribute: String] = [:], children: [FakeNode] = []) {
        self.texts = texts
        self.texts[.role] = role
        for child in children { adopt(child) }
    }

    func adopt(_ child: FakeNode) {
        child.parent = self
        childNodes.append(child)
    }

    func children(upTo limit: Int) -> [FakeNode] {
        Array(childNodes.prefix(limit))
    }

    func text(of attribute: AccessibilityTextAttribute) -> String? {
        texts[attribute]
    }

    func isSameElement(as other: FakeNode) -> Bool {
        self === other
    }
}

/// A `FocusSource` whose focused element and secure-input state the test sets.
@MainActor
final class FakeFocusSource: FocusSource {
    var focused: FocusedElement<FakeNode>?
    var isSecureEventInputEnabled = false

    func focus(_ node: FakeNode, processIdentifier: Int32 = 42, bundleIdentifier: String = "com.google.Chrome") {
        focused = FocusedElement(processIdentifier: processIdentifier, bundleIdentifier: bundleIdentifier, node: node)
    }

    func focusedElement() -> FocusedElement<FakeNode>? {
        focused
    }
}
