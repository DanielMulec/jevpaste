import SmartPasteCore

/// Reads the Target Context around a focused element: the label contract (field label, placeholder, section
/// heading, sibling field labels), bounded surrounding text, the app's name and the window title. The walks for
/// sibling labels and surrounding text share one time budget, which starts before any ancestor is looked up. The
/// budget bounds walk iterations only: it is checked between elements, so a single synchronous AX call (and the
/// label, placeholder, heading and window-title reads, which ignore it) can overrun it, each up to the AX messaging
/// timeout.
@MainActor
struct TargetContextReader<Node: AccessibilityNode> {
    private let timeLimit: Duration
    /// How far up a section heading is looked for (a fieldset legend sits a few levels above its fields).
    private let headingSearchDepth = 6
    private let maximumSiblingLabels = 10
    private let siblingSearchNodeBudget = 200

    init(timeLimit: Duration = .milliseconds(250)) {
        self.timeLimit = timeLimit
    }

    func context(of focused: FocusedElement<Node>) -> TargetContext {
        let deadline = ContinuousClock.now + timeLimit
        let target = focused.node
        let section = sectionAncestor(of: target)
        return TargetContext(
            fieldLabel: fieldLabel(of: target),
            placeholder: target.firstText(of: [.placeholder]),
            sectionHeading: section?.firstText(of: [.title, .description]),
            siblingFieldLabels: siblingFieldLabels(
                of: target, within: section ?? target.parent?.parent, until: deadline),
            surroundingText: SurroundingTextCollector<Node>().surroundingText(of: focused, until: deadline),
            appName: focused.applicationName,
            windowTitle: target.window?.firstText(of: [.title])
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
    private func siblingFieldLabels(
        of target: Node, within scope: Node?, until deadline: ContinuousClock.Instant
    ) -> [String] {
        guard let scope else { return [] }
        var labels: [String] = []
        var pending = [scope]
        var visited = 0
        let isWithinBudget = {
            visited < siblingSearchNodeBudget && labels.count < maximumSiblingLabels && ContinuousClock.now < deadline
        }
        while isWithinBudget(), let node = pending.popLast() {
            visited += 1
            if node.isEditable {
                let label = fieldLabel(of: node) ?? node.firstText(of: [.placeholder])
                if let label, !node.isSameElement(as: target) { labels.append(label) }
                continue
            }
            pending.append(contentsOf: node.children(upTo: AccessibilityWalkLimits.childrenPerElement).reversed())
        }
        return labels
    }

    static func isPageOrWindow(_ node: Node) -> Bool {
        node.role == "AXWebArea" || node.role == "AXWindow"
    }
}
