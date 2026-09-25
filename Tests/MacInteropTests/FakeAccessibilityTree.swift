import SmartPasteCore

@testable import MacInterop

/// An in-memory Accessibility element: a role plus text attributes, linked into a tree like AX exposes it.
@MainActor
final class FakeNode: AccessibilityNode {
    private var texts: [AccessibilityTextAttribute: String]
    private var childNodes: [FakeNode] = []
    /// Strong on purpose: tests build a tree and keep only the leaf. The cycle is released with the test process.
    private(set) var parent: FakeNode?
    var titleElement: FakeNode?
    var window: FakeNode?
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

/// A `FocusSource` whose focused element, secure-input state and frontmost app the test sets.
@MainActor
final class FakeFocusSource: FocusSource {
    var focused: FocusedElement<FakeNode>?
    var isSecureEventInputEnabled = false
    var frontmost: FrontmostApplication?
    /// Processes whose Accessibility reads as fully on.
    var awakeProcesses: Set<Int32> = []
    /// Whether a wake request takes (reads back as on); an app that ignores the attribute does not.
    var wakeRequestsTake = true
    private(set) var wakeRequests: [Int32] = []

    func focus(
        _ node: FakeNode, processIdentifier: Int32 = 42, applicationName: String? = "Google Chrome",
        bundleIdentifier: String = "com.google.Chrome"
    ) {
        focused = FocusedElement(
            processIdentifier: processIdentifier, bundleIdentifier: bundleIdentifier, node: node,
            applicationName: applicationName
        )
    }

    func focusedElement() -> FocusedElement<FakeNode>? {
        focused
    }

    func frontmostApplication() -> FrontmostApplication? {
        frontmost
    }

    func isAccessibilityAwake(in processIdentifier: Int32) -> Bool {
        awakeProcesses.contains(processIdentifier)
    }

    func wakeAccessibility(in processIdentifier: Int32) -> Bool {
        wakeRequests.append(processIdentifier)
        if wakeRequestsTake { awakeProcesses.insert(processIdentifier) }
        return wakeRequestsTake
    }
}

extension TargetResolution {
    var boundTarget: BoundTarget? {
        if case .resolved(let target) = self { return target }
        return nil
    }
}
