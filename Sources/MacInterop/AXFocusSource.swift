import AppKit
import ApplicationServices
import Carbon.HIToolbox
import os

/// The system's keyboard focus, read through the system-wide Accessibility element. Needs the Accessibility
/// grant; without it every lookup fails and no Target is found.
@MainActor
final class AXFocusSource: FocusSource {
    /// Longest wait for an unresponsive app on any one Accessibility read (applies to all elements).
    private static let messagingTimeoutSeconds: Float = 1
    /// Chromium's tree sleeps until walked; one ordinary walk of this many elements wakes it (probe).
    private static let wakeWalkNodeLimit = 300
    /// Chromium's "an assistive technology is present" switch; Electron apps keep their web tree off without it.
    private static let enhancedUserInterfaceAttribute = "AXEnhancedUserInterface" as CFString

    private static let log = Logger(subsystem: "jevpaste", category: "TargetResolver")

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
        var window: CFTypeRef?
        AXUIElementCopyAttributeValue(
            applicationElement(application.processIdentifier), kAXFocusedWindowAttribute as CFString, &window)
        guard let root = AXElementNode.node(from: window) else { return nil }
        var queue = [root]
        var next = 0
        while next < queue.count, next < Self.wakeWalkNodeLimit {
            queue.append(contentsOf: queue[next].children(upTo: AccessibilityWalkLimits.childrenPerElement))
            next += 1
        }
        return focusedNode()
    }

    func frontmostApplication() -> FrontmostApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        return FrontmostApplication(
            processIdentifier: application.processIdentifier,
            name: application.localizedName ?? application.bundleIdentifier ?? "the app"
        )
    }

    /// Logged: the unreadable-focus app's bundle id and the attribute's status and value — never content.
    func isAccessibilityAwake(in processIdentifier: Int32) -> Bool {
        let isAwake = enhancedUserInterfaceIsOn(in: processIdentifier)
        let app = Self.bundleIdentifier(of: processIdentifier)
        Self.log.notice("focus unreadable app=\(app, privacy: .public) enhancedUI=\(isAwake, privacy: .public)")
        return isAwake
    }

    func wakeAccessibility(in processIdentifier: Int32) -> Bool {
        let status = AXUIElementSetAttributeValue(
            applicationElement(processIdentifier), Self.enhancedUserInterfaceAttribute, kCFBooleanTrue)
        let isAwake = enhancedUserInterfaceIsOn(in: processIdentifier)
        let app = Self.bundleIdentifier(of: processIdentifier)
        let code = status.rawValue
        Self.log.notice("wake requested app=\(app, privacy: .public) set=\(code) readBack=\(isAwake, privacy: .public)")
        return isAwake
    }

    private func enhancedUserInterfaceIsOn(in processIdentifier: Int32) -> Bool {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            applicationElement(processIdentifier), Self.enhancedUserInterfaceAttribute, &value)
        return status == .success && (value as? Bool) == true
    }

    private static func bundleIdentifier(of processIdentifier: Int32) -> String {
        NSRunningApplication(processIdentifier: processIdentifier)?.bundleIdentifier ?? "unknown"
    }

    private func applicationElement(_ processIdentifier: Int32) -> AXUIElement {
        AXUIElementCreateApplication(processIdentifier)
    }
}
