import AppKit
import ApplicationServices
import OSLog

/// TEMPORARY diagnostic for [Restore Smart Paste in the ChatGPT desktop app](#33): the staged focus reads of one
/// ⌘⇧V in the frontmost app. Logs AXError codes, roles and counts only — never values, titles or descriptions.
@MainActor
struct FocusProbe {
    static let log = Logger(subsystem: "jevpaste", category: "FocusDiagnostic")
    private static let messagingTimeoutSeconds: Float = 1
    private static let productionWalkLimit = 300
    private static let childrenPerElement = 100
    private static let checkpointsMilliseconds = [0, 1_000, 3_000]
    private static let wakeAttributes = ["AXManualAccessibility", "AXEnhancedUserInterface"]

    let press: Int
    private let application: NSRunningApplication
    private let applicationElement: AXUIElement
    private let systemWide = AXUIElementCreateSystemWide()

    init(press: Int, application: NSRunningApplication) {
        self.press = press
        self.application = application
        applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, Self.messagingTimeoutSeconds)
        AXUIElementSetMessagingTimeout(systemWide, Self.messagingTimeoutSeconds)
    }

    /// Runs S0 → S3 until the system-wide focused element resolves; returns the stage label that resolved it.
    func run() async -> String? {
        write("S0 app=\(application.bundleIdentifier ?? "unknown") \(attributeStates())")
        if read("S0") { return "S0" }
        walk("S1")
        if read("S1+0") { return "S1+0" }
        try? await Task.sleep(for: .milliseconds(500))
        if read("S1+500") { return "S1+500" }
        for (index, attribute) in Self.wakeAttributes.enumerated() {
            let stage = "S\(index + 2)"
            write("\(stage) set \(attribute) status=\(setTrue(attribute)) \(attributeStates())")
            if let resolved = await checkpoints(stage) { return resolved }
        }
        return nil
    }

    /// At each checkpoint after a set: read, walk, read again — separates "needs time" from "needs a walk".
    private func checkpoints(_ stage: String) async -> String? {
        var elapsed = 0
        for checkpoint in Self.checkpointsMilliseconds {
            try? await Task.sleep(for: .milliseconds(checkpoint - elapsed))
            elapsed = checkpoint
            if read("\(stage)+\(checkpoint) pre-walk") { return "\(stage)+\(checkpoint)pre" }
            walk("\(stage)+\(checkpoint)")
            if read("\(stage)+\(checkpoint) post-walk") { return "\(stage)+\(checkpoint)post" }
        }
        return nil
    }

    /// System-wide, application-level and focused-window reads. True when the system-wide read resolves.
    private func read(_ label: String) -> Bool {
        let systemWideRead = copyElement(systemWide, kAXFocusedUIElementAttribute)
        let applicationRead = copyElement(applicationElement, kAXFocusedUIElementAttribute)
        let windowRead = copyElement(applicationElement, kAXFocusedWindowAttribute)
        let found = systemWideRead.element ?? applicationRead.element
        write(
            "\(label) sw=\(systemWideRead.status.rawValue) app=\(applicationRead.status.rawValue) "
                + "win=\(windowRead.status.rawValue) \(found.map(describe) ?? "found=none")"
        )
        return systemWideRead.element != nil
    }

    /// The production wake walk (breadth-first, 300 elements, 100 children each) with its shape.
    private func walk(_ label: String) {
        guard let window = copyElement(applicationElement, kAXFocusedWindowAttribute).element else {
            write("\(label) walk skipped: no focused window")
            return
        }
        var queue = [window]
        var next = 0
        var roleCounts: [String: Int] = [:]
        while next < queue.count, next < Self.productionWalkLimit {
            roleCounts[string(queue[next], kAXRoleAttribute) ?? "nil", default: 0] += 1
            queue.append(contentsOf: children(of: queue[next]))
            next += 1
        }
        let topRoles = roleCounts.sorted { $0.value > $1.value }.prefix(5).map { "\($0.key)x\($0.value)" }
        write(
            "\(label) walk visited=\(next) queueLeft=\(queue.count - next) "
                + "webAreas=\(roleCounts["AXWebArea"] ?? 0) roles=\(topRoles.joined(separator: ","))"
        )
    }

    private func describe(_ element: AXUIElement) -> String {
        var isSettable: DarwinBoolean = false
        let settableStatus = AXUIElementIsAttributeSettable(
            element, kAXSelectedTextRangeAttribute as CFString, &isSettable)
        let role = string(element, kAXRoleAttribute) ?? "nil"
        let subrole = string(element, kAXSubroleAttribute) ?? "nil"
        return "role=\(role) subrole=\(subrole) "
            + "selectedTextRangeSettable=\(isSettable.boolValue)/\(settableStatus.rawValue)"
    }

    /// Read-back of both wake attributes on the application element: `status/value`.
    private func attributeStates() -> String {
        Self.wakeAttributes.map { attribute in
            var value: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(applicationElement, attribute as CFString, &value)
            let flag = (value as? Bool).map(String.init) ?? "nil"
            return "\(attribute)=\(status.rawValue)/\(flag)"
        }.joined(separator: " ")
    }

    private func setTrue(_ attribute: String) -> Int32 {
        AXUIElementSetAttributeValue(applicationElement, attribute as CFString, kCFBooleanTrue).rawValue
    }

    private func copyElement(_ element: AXUIElement, _ attribute: String) -> (status: AXError, element: AXUIElement?) {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return (status, nil) }
        return (status, unsafeDowncast(value, to: AXUIElement.self))
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var values: CFArray?
        let status = AXUIElementCopyAttributeValues(
            element, kAXChildrenAttribute as CFString, 0, Self.childrenPerElement, &values)
        guard status == .success, let list = values as? [AXUIElement] else { return [] }
        return list
    }

    /// Only for role and subrole, which are app-authored constants, never user text.
    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func write(_ line: String) {
        Self.log.info("press \(press, privacy: .public): \(line, privacy: .public)")
    }
}
