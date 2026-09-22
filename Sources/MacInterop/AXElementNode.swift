import ApplicationServices

/// A live `AXUIElement` read through the Accessibility API. Every read is a synchronous IPC to the owning app,
/// bounded by the messaging timeout set on the system-wide element.
struct AXElementNode: AccessibilityNode {
    let element: AXUIElement

    func text(of attribute: AccessibilityTextAttribute) -> String? {
        copyValue(of: attribute.rawValue) as? String
    }

    var parent: AXElementNode? {
        element(for: kAXParentAttribute)
    }

    var children: [AXElementNode] {
        guard let list = copyValue(of: kAXChildrenAttribute) as? [AXUIElement] else { return [] }
        return list.map(AXElementNode.init)
    }

    var titleElement: AXElementNode? {
        element(for: kAXTitleUIElementAttribute)
    }

    var isSelectedTextRangeSettable: Bool {
        var isSettable: DarwinBoolean = false
        let status = AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &isSettable)
        return status == .success && isSettable.boolValue
    }

    func isSameElement(as other: AXElementNode) -> Bool {
        CFEqual(element, other.element)
    }

    private func copyValue(of attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private func element(for attribute: String) -> AXElementNode? {
        Self.node(from: copyValue(of: attribute))
    }

    /// The value as an element, if it is one. Attribute values are untyped `CFTypeRef`s.
    static func node(from value: CFTypeRef?) -> AXElementNode? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AXElementNode(element: unsafeDowncast(value, to: AXUIElement.self))
    }
}
