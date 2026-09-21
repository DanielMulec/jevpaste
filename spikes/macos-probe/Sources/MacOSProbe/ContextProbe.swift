import AppKit
import ApplicationServices

/// "Bounded surrounding context": how much text can we actually harvest around the caret,
/// and how fast, per target. Counts and timings only — never the text itself.
enum ContextProbe {
    struct Budget {
        var maxNodes = 600
        var maxDepth = 14
        var maxMilliseconds = 1500.0
        var targetChars = 2000 // the window size issue #7 assumes
    }

    static func focusedWindow(_ focus: AXProbe.Focus) -> AXUIElement? {
        if let app = focus.appElement {
            let (value, error, _) = AXProbe.copyValue(app, kAXFocusedWindowAttribute as String)
            if error == .success, let raw = value, CFGetTypeID(raw) == AXUIElementGetTypeID() {
                // swiftlint:disable:next force_cast
                return (raw as! AXUIElement)
            }
        }
        // Fall back to walking up from the focused element.
        var current = focus.element
        var depth = 0
        while let node = current, depth < 20 {
            if AXProbe.string(node, kAXRoleAttribute as String) == (kAXWindowRole as String) { return node }
            let (parent, error, _) = AXProbe.copyValue(node, kAXParentAttribute as String)
            guard error == .success, let raw = parent, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
            // swiftlint:disable:next force_cast
            current = (raw as! AXUIElement)
            depth += 1
        }
        return nil
    }

    static func harvest(budget: Budget = Budget(), label: String = "CTX") {
        let focus = AXProbe.focused()
        Log.line("\(label) target=\(focus.bundleID) budget nodes=\(budget.maxNodes) depth=\(budget.maxDepth) "
                 + "ms=\(budget.maxMilliseconds)")
        guard let root = focusedWindow(focus) else {
            Log.fail("\(label) no focused window reachable — no surrounding context available")
            return
        }
        // A window title is personal metadata (contact, tab, conversation), so presence only.
        let windowTitle = AXProbe.string(root, kAXTitleAttribute as String)
        Log.line("\(label) windowTitle=\(windowTitle.redacted)")

        let began = DispatchTime.now().uptimeNanoseconds
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var visited = 0
        var totalChars = 0
        var textNodes = 0
        var roleCounts: [String: Int] = [:]
        var truncatedBy = "budget-not-hit"
        var reachedTargetAtMs: Double?

        while !queue.isEmpty {
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000.0
            if visited >= budget.maxNodes { truncatedBy = "maxNodes"; break }
            if elapsed >= budget.maxMilliseconds { truncatedBy = "maxMilliseconds"; break }

            let (node, depth) = queue.removeFirst()
            visited += 1
            let role = AXProbe.string(node, kAXRoleAttribute as String) ?? "nil"
            roleCounts[role, default: 0] += 1

            // Only harvest from roles that carry readable text, and never from secure fields.
            let subrole = AXProbe.string(node, kAXSubroleAttribute as String) ?? ""
            if subrole != (kAXSecureTextFieldSubrole as String) {
                for attribute in [kAXValueAttribute as String, kAXTitleAttribute as String,
                                  kAXDescriptionAttribute as String] {
                    let (value, error, _) = AXProbe.copyValue(node, attribute)
                    if error == .success, let text = value as? String, !text.isEmpty {
                        totalChars += text.count
                        textNodes += 1
                        if reachedTargetAtMs == nil, totalChars >= budget.targetChars {
                            reachedTargetAtMs = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000.0
                        }
                        break
                    }
                }
            }

            guard depth < budget.maxDepth else { continue }
            let (children, error, _) = AXProbe.copyValue(node, kAXChildrenAttribute as String)
            if error == .success, let list = children as? [AXUIElement] {
                for child in list { queue.append((child, depth + 1)) }
            }
        }

        let totalMs = Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000.0
        let topRoles = roleCounts.sorted { $0.value > $1.value }.prefix(8)
            .map { "\($0.key)x\($0.value)" }.joined(separator: ",")
        Log.line("\(label) visited=\(visited) textNodes=\(textNodes) totalChars=\(totalChars) "
                 + "queueRemaining=\(queue.count) stoppedBy=\(truncatedBy)")
        Log.line("\(label) timing totalMs=\((totalMs * 100).rounded() / 100) "
                 + "msTo\(budget.targetChars)chars=\(reachedTargetAtMs.map { String((($0 * 100).rounded() / 100)) } ?? "never")")
        Log.line("\(label) roles \(topRoles)")
        if totalChars == 0 {
            Log.fail("\(label) ZERO characters of context — this target gives the model nothing to work with")
        }
    }
}
