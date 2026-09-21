import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Focused-target identification and bounded context reads over the Accessibility API.
/// SAFETY: field text is never logged. Only lengths, hashes, roles and timings.
enum AXProbe {
    static let systemWide: AXUIElement = {
        let element = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(element, 2.0)
        return element
    }()

    // MARK: - Low level

    static func copyValue(_ element: AXUIElement, _ attribute: String) -> (CFTypeRef?, AXError, Double) {
        var value: CFTypeRef?
        let (error, ms) = Clock.measure { AXUIElementCopyAttributeValue(element, attribute as CFString, &value) }
        return (value, error, ms)
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        let (value, error, _) = copyValue(element, attribute)
        guard error == .success else { return nil }
        return value as? String
    }

    static func attributeNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyAttributeNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    static func settable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var flag: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, attribute as CFString, &flag) == .success else {
            return false
        }
        return flag.boolValue
    }

    static func selectedRange(_ element: AXUIElement) -> CFRange? {
        let (value, error, _) = copyValue(element, kAXSelectedTextRangeAttribute as String)
        guard error == .success, let raw = value, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(raw as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    // MARK: - Focus

    struct Focus {
        var element: AXUIElement?
        var appElement: AXUIElement?
        var bundleID: String
        var pid: pid_t
        var error: AXError
        var lookupMs: Double
    }

    static func focused() -> Focus {
        let front = NSWorkspace.shared.frontmostApplication
        let pid = front?.processIdentifier ?? 0
        let (value, error, ms) = copyValue(systemWide, kAXFocusedUIElementAttribute as String)
        var appElement: AXUIElement?
        if pid > 0 {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 2.0)
            appElement = app
        }
        var element: AXUIElement?
        if error == .success, let raw = value, CFGetTypeID(raw) == AXUIElementGetTypeID() {
            // swiftlint:disable:next force_cast
            element = (raw as! AXUIElement)
        }
        return Focus(element: element, appElement: appElement,
                     bundleID: front?.bundleIdentifier ?? "unknown",
                     pid: pid, error: error, lookupMs: ms)
    }

    // MARK: - Identification report

    @discardableResult
    static func identify(label: String = "AX") -> Focus {
        let focus = focused()
        Log.line("\(label) frontmost=\(focus.bundleID) pid=\(focus.pid) "
                 + "focusedElementLookup=\(focus.error.probeName) in \(focus.lookupMs)ms "
                 + "secureEventInput=\(IsSecureEventInputEnabled())")
        guard let element = focus.element else {
            Log.fail("\(label) no focused element — AX cannot identify this target")
            return focus
        }

        let role = string(element, kAXRoleAttribute as String) ?? "nil"
        let subrole = string(element, kAXSubroleAttribute as String) ?? "nil"
        let roleDesc = string(element, kAXRoleDescriptionAttribute as String) ?? "nil"
        let title = string(element, kAXTitleAttribute as String)
        let placeholder = string(element, kAXPlaceholderValueAttribute as String)
        let help = string(element, kAXHelpAttribute as String)
        let desc = string(element, kAXDescriptionAttribute as String)

        Log.line("\(label) role=\(role) subrole=\(subrole) roleDescription=\(roleDesc.quoted)")
        // placeholder is an app-authored UI string and a useful secure-field signal, so it stays
        // verbatim. title/description/help can carry a contact name, tab title or conversation
        // title, so they are reduced to presence + length + hash.
        Log.line("\(label) label-ish: title=\(title.redacted) placeholder=\(placeholder.quotedOrNil) "
                 + "description=\(desc.redacted) help=\(help.redacted)")

        let secure = looksSecure(element: element, role: role, subrole: subrole)
        Log.line("\(label) SECURE-FIELD verdict=\(secure.verdict) signals=\(secure.signals.joined(separator: ","))")

        let (valueInfo, valueMs) = Clock.measure { valueSummary(element) }
        Log.line("\(label) AXValue \(valueInfo) readMs=\(valueMs)")

        let (selectionInfo, selectionMs) = Clock.measure { selectionSummary(element) }
        Log.line("\(label) selection \(selectionInfo) readMs=\(selectionMs)")

        let names = attributeNames(element)
        Log.line("\(label) attributeCount=\(names.count) attributes=\(names.joined(separator: ","))")
        let settables = [kAXValueAttribute, kAXSelectedTextAttribute, kAXSelectedTextRangeAttribute]
            .map { "\($0)=\(settable(element, $0 as String))" }
        Log.line("\(label) settable \(settables.joined(separator: " "))")

        ancestry(element, label: label)
        webContext(element, appBundleID: focus.bundleID, label: label)
        return focus
    }

    /// Never reads the value of a suspected secure field; reports length/hash only otherwise.
    static func valueSummary(_ element: AXUIElement) -> String {
        let role = string(element, kAXRoleAttribute as String) ?? ""
        let subrole = string(element, kAXSubroleAttribute as String) ?? ""
        if looksSecure(element: element, role: role, subrole: subrole).verdict != "no" {
            return "SKIPPED (suspected secure field; probe refuses to read)"
        }
        let (value, error, _) = copyValue(element, kAXValueAttribute as String)
        guard error == .success else { return "unavailable(\(error.probeName))" }
        if let text = value as? String {
            return "chars=\(text.count) sha=\(Digest.short(text))"
        }
        if let number = value as? NSNumber { return "non-text NSNumber(\(number.objCType.pointee))" }
        return "non-text type"
    }

    static func selectionSummary(_ element: AXUIElement) -> String {
        var parts: [String] = []
        let (selected, error, _) = copyValue(element, kAXSelectedTextAttribute as String)
        if error == .success, let text = selected as? String {
            parts.append("AXSelectedText chars=\(text.count)")
        } else {
            parts.append("AXSelectedText=\(error.probeName)")
        }
        if let range = selectedRange(element) {
            parts.append("AXSelectedTextRange loc=\(range.location) len=\(range.length)")
        } else {
            parts.append("AXSelectedTextRange=unavailable")
        }
        let (count, countError, _) = copyValue(element, kAXNumberOfCharactersAttribute as String)
        if countError == .success, let number = count as? Int {
            parts.append("AXNumberOfCharacters=\(number)")
        }
        return parts.joined(separator: " ")
    }

    struct SecureVerdict {
        var verdict: String
        var signals: [String]
    }

    static func looksSecure(element: AXUIElement, role: String, subrole: String) -> SecureVerdict {
        var signals: [String] = []
        if subrole == (kAXSecureTextFieldSubrole as String) { signals.append("AXSecureTextFieldSubrole") }
        if role == "AXSecureTextField" { signals.append("role=AXSecureTextField") }
        if IsSecureEventInputEnabled() { signals.append("IsSecureEventInputEnabled(global)") }
        let verdict: String
        if signals.contains(where: { $0.hasPrefix("AXSecure") || $0.hasPrefix("role=") }) {
            verdict = "yes(per-element)"
        } else if signals.isEmpty {
            verdict = "no"
        } else {
            verdict = "suspected(global-signal-only)"
        }
        return SecureVerdict(verdict: verdict, signals: signals)
    }

    /// Walks up the AX parent chain: this is the cheap "surrounding context" ladder.
    static func ancestry(_ element: AXUIElement, label: String, limit: Int = 6) {
        var current: AXUIElement? = element
        var depth = 0
        let (_, ms) = Clock.measure {
            while let node = current, depth < limit {
                if depth > 0 {
                    let role = string(node, kAXRoleAttribute as String) ?? "nil"
                    let title = string(node, kAXTitleAttribute as String)
                    let desc = string(node, kAXDescriptionAttribute as String)
                    Log.line("\(label) ancestor[\(depth)] role=\(role) title=\(title.redacted) "
                             + "description=\(desc.redacted)")
                }
                let (parent, error, _) = copyValue(node, kAXParentAttribute as String)
                guard error == .success, let raw = parent, CFGetTypeID(raw) == AXUIElementGetTypeID() else {
                    current = nil
                    break
                }
                // swiftlint:disable:next force_cast
                current = (raw as! AXUIElement)
                depth += 1
            }
        }
        Log.line("\(label) ancestry depth=\(depth) totalMs=\(ms)")
    }

    static func webContext(_ element: AXUIElement, appBundleID: String, label: String) {
        for attribute in [kAXDocumentAttribute as String, "AXURL"] {
            let (value, error, ms) = copyValue(element, attribute)
            if error == .success {
                let rendered: String
                if let url = value as? URL { rendered = "host=\(url.host ?? "nil") scheme=\(url.scheme ?? "nil")" }
                else if let text = value as? String { rendered = "chars=\(text.count)" }
                else { rendered = "present(non-string)" }
                Log.line("\(label) \(attribute) \(rendered) readMs=\(ms)")
            }
        }
    }

    // MARK: - Browser / Electron AX activation (undocumented attributes)

    static func wake(pid: pid_t, attribute: String) -> String {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 2.0)
        let (error, ms) = Clock.measure {
            AXUIElementSetAttributeValue(app, attribute as CFString, kCFBooleanTrue)
        }
        return "\(attribute) set=\(error.probeName) in \(ms)ms"
    }

    // MARK: - Insertion path B: AX setters

    static func setSelectedText(_ element: AXUIElement, _ text: String) -> (AXError, Double) {
        Clock.measure {
            AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        }
    }

    static func setValue(_ element: AXUIElement, _ text: String) -> (AXError, Double) {
        Clock.measure {
            AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        }
    }
}

extension AXError {
    var probeName: String {
        switch self {
        case .success: return "success"
        case .apiDisabled: return "apiDisabled(no Accessibility grant)"
        case .noValue: return "noValue"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported: return "actionUnsupported"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .invalidUIElement: return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete: return "cannotComplete"
        case .notImplemented: return "notImplemented"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .failure: return "failure"
        case .illegalArgument: return "illegalArgument"
        case .notEnoughPrecision: return "notEnoughPrecision"
        @unknown default: return "unknown(\(rawValue))"
        }
    }
}

extension String {
    /// Label-ish strings are UI chrome, not user content, so they are safe to show — but we still
    /// cap them so a stray value can never spill into the transcript.
    var quoted: String { "\"\(prefix(80))\"" }
}

extension Optional where Wrapped == String {
    var quotedOrNil: String {
        switch self {
        case .none: return "nil"
        case .some(let value): return value.isEmpty ? "\"\"" : value.quoted
        }
    }

    /// Presence + shape only. Used for strings that can carry personal metadata (contact names,
    /// tab titles, conversation titles) so neither the transcript nor RESULTS.md can leak them.
    var redacted: String {
        switch self {
        case .none: return "nil"
        case .some(let value):
            return value.isEmpty ? "empty" : "chars=\(value.count),sha=\(Digest.short(value))"
        }
    }
}
