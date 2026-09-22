import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// The system's keyboard focus, read through the system-wide Accessibility element. Needs the Accessibility
/// grant; without it every lookup fails and no Target is found.
@MainActor
final class AXFocusSource: FocusSource {
    /// Longest wait for an unresponsive app on any one Accessibility read (applies to all elements).
    private static let messagingTimeoutSeconds: Float = 1
    /// Chromium's tree sleeps until walked; one ordinary walk of this many elements wakes it (probe).
    private static let wakeWalkNodeLimit = 300

    private let systemWide = AXUIElementCreateSystemWide()

    init() {
        AXUIElementSetMessagingTimeout(systemWide, Self.messagingTimeoutSeconds)
    }

    var isSecureEventInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }

    func focusedElement() -> FocusedElement<AXElementNode>? {
        guard let node = focusedNode() ?? wakeFrontmostAppAndRetry() else { return nil }
        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(node.element, &processIdentifier) == .success else { return nil }
        return FocusedElement(
            processIdentifier: processIdentifier,
            bundleIdentifier: NSRunningApplication(processIdentifier: processIdentifier)?.bundleIdentifier,
            node: node
        )
    }

    private func focusedNode() -> AXElementNode? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value)
        return status == .success ? AXElementNode.node(from: value) : nil
    }

    /// Chromium answers `noValue` for the focused element until its tree has been walked once.
    private func wakeFrontmostAppAndRetry() -> AXElementNode? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var window: CFTypeRef?
        AXUIElementCopyAttributeValue(applicationElement, kAXFocusedWindowAttribute as CFString, &window)
        guard let root = AXElementNode.node(from: window) else { return nil }
        var queue = [root]
        var next = 0
        while next < queue.count, next < Self.wakeWalkNodeLimit {
            queue.append(contentsOf: queue[next].children(upTo: AccessibilityWalkLimits.childrenPerElement))
            next += 1
        }
        return focusedNode()
    }
}
