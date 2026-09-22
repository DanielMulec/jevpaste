import SmartPasteCore

/// Reads the Target Context around a focused element: the label contract (field label, placeholder, section
/// heading, sibling field labels) plus bounded surrounding text.
@MainActor
struct TargetContextReader<Node: AccessibilityNode> {
    /// How far up a section heading is looked for (a fieldset legend sits a few levels above its fields).
    private let headingSearchDepth = 6
    private let maximumSiblingLabels = 10
    private let siblingSearchNodeBudget = 200

    func context(of focused: FocusedElement<Node>) -> TargetContext {
        let target = focused.node
        let section = sectionAncestor(of: target)
        return TargetContext(
            fieldLabel: fieldLabel(of: target),
            placeholder: target.firstText(of: [.placeholder]),
            sectionHeading: section?.firstText(of: [.title, .description]),
            siblingFieldLabels: siblingFieldLabels(of: target, within: section ?? target.parent?.parent),
            surroundingText: SurroundingTextCollector<Node>().surroundingText(of: focused)
        )
    }

    private func fieldLabel(of node: Node) -> String? {
        node.firstText(of: [.title])
            ?? node.titleElement?.firstText(of: [.value, .title])
            ?? node.firstText(of: [.description])
    }

    /// The nearest titled or described group above the Target, below the page.
    private func sectionAncestor(of target: Node) -> Node? {
        var ancestor = target.parent
        for _ in 0..<headingSearchDepth {
            guard let node = ancestor, !Self.isPageOrWindow(node) else { return nil }
            if node.role == "AXGroup", node.firstText(of: [.title, .description]) != nil { return node }
            ancestor = node.parent
        }
        return nil
    }

    /// Labels of the other editable fields in `scope`, in document order.
    private func siblingFieldLabels(of target: Node, within scope: Node?) -> [String] {
        guard let scope else { return [] }
        var labels: [String] = []
        var pending = [scope]
        var visited = 0
        while let node = pending.popLast(), visited < siblingSearchNodeBudget, labels.count < maximumSiblingLabels {
            visited += 1
            if node.isEditable {
                let label = fieldLabel(of: node) ?? node.firstText(of: [.placeholder])
                if let label, !node.isSameElement(as: target) { labels.append(label) }
                continue
            }
            pending.append(contentsOf: node.children.reversed())
        }
        return labels
    }

    static func isPageOrWindow(_ node: Node) -> Bool {
        node.role == "AXWebArea" || node.role == "AXWindow"
    }
}
