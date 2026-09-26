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
        guard let node = focusedNode() else { return nil }
        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(node.element, &processIdentifier) == .success else { return nil }
        let application = NSRunningApplication(processIdentifier: processIdentifier)
        return FocusedElement(
            processIdentifier: processIdentifier, node: node, applicationName: application?.localizedName)
    }

    private func focusedNode() -> AXElementNode? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value)
        return status == .success ? AXElementNode.node(from: value) : nil
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

    func wakeAccessibility(in processIdentifier: Int32) {
        let status = AXUIElementSetAttributeValue(
            applicationElement(processIdentifier), Self.enhancedUserInterfaceAttribute, kCFBooleanTrue)
        let isAwake = enhancedUserInterfaceIsOn(in: processIdentifier)
        let app = Self.bundleIdentifier(of: processIdentifier)
        let code = status.rawValue
        Self.log.notice("wake requested app=\(app, privacy: .public) set=\(code) readBack=\(isAwake, privacy: .public)")
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
