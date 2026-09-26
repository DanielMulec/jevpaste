import AppKit
import ApplicationServices
import Darwin
import Dispatch

/// THROWAWAY (branch `cursor-context-probe`, never merged): Gate A of "Read nearby text around the text cursor".
/// `JevPaste --cursor-probe <log-path>`: no hotkey, no clipboard, no paste. `SIGUSR2` measures the focused element;
/// `SIGUSR1` first sets its `AXSelectedTextRange` to the middle of its value (caret only), then measures.
/// The log holds numbers, AX status codes and marker booleans/offsets only — never text.
@MainActor
final class CursorProbe: NSObject, NSApplicationDelegate {
    private static let markers = [
        "JEVPASTE-OLD-51", "JEVPASTE-NEAR-51", "JEVPASTE-BEFORE-51", "JEVPASTE-AFTER-51",
        "JEVPASTE-FARSTART-51", "JEVPASTE-FAREND-51",
    ]
    private let log: ProbeLog
    private let systemWide = AXUIElementCreateSystemWide()
    private var sources: [any DispatchSourceSignal] = []
    private var run = 0
    private var wokenProcesses: Set<Int32> = []

    init(logPath: String) {
        log = ProbeLog(path: logPath)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AXUIElementSetMessagingTimeout(systemWide, 1)
        log.write("cursor probe start accessibilityTrusted=\(AXIsProcessTrusted()) pid=\(getpid())")
        listen(to: SIGUSR2) { $0.measure(placeCaretInMiddle: false) }
        listen(to: SIGUSR1) { $0.measure(placeCaretInMiddle: true) }
    }

    private func listen(to signalNumber: Int32, action: @escaping @MainActor (CursorProbe) -> Void) {
        signal(signalNumber, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        }
        source.resume()
        sources.append(source)
    }

    private func measure(placeCaretInMiddle: Bool) {
        run += 1
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
        guard let element = focusedElement() else {
            log.write("run=\(run) front=\(front) focus=unreadable \(unreadableDiagnosis())")
            wakeAndMeasure(placeCaretInMiddle: placeCaretInMiddle)
            return
        }
        measure(element, front: front, placeCaretInMiddle: placeCaretInMiddle)
    }

    /// AX status codes and roles only: why the system-wide focus read failed.
    private func unreadableDiagnosis() -> String {
        let systemStatus = copy(systemWide, kAXFocusedUIElementAttribute).status.rawValue
        guard let app = NSWorkspace.shared.frontmostApplication else { return "systemStatus=\(systemStatus)" }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let (focusStatus, _) = copy(appElement, kAXFocusedUIElementAttribute)
        let (windowStatus, window) = copy(appElement, kAXFocusedWindowAttribute)
        let (windowsStatus, windows) = copy(appElement, kAXWindowsAttribute)
        var windowRole = "none"
        if let window, CFGetTypeID(window) == AXUIElementGetTypeID() {
            let element = unsafeDowncast(window, to: AXUIElement.self)
            windowRole =
                (string(element, kAXRoleAttribute) ?? "none") + "/" + (string(element, kAXSubroleAttribute) ?? "none")
        }
        let enhanced = copy(appElement, "AXEnhancedUserInterface").value as? Bool
        return "systemStatus=\(systemStatus) appFocusStatus=\(focusStatus.rawValue) "
            + "focusedWindowStatus=\(windowStatus.rawValue) focusedWindowRole=\(windowRole) "
            + "windowsStatus=\(windowsStatus.rawValue) windows=\((windows as? [AXUIElement])?.count ?? -1) "
            + "enhancedUI=\(enhanced.map { "\($0)" } ?? "none")"
    }

    /// Wake Wait, as production does it: set `AXEnhancedUserInterface` once per process, re-read every 50 ms, ≤ 3 s.
    private func wakeAndMeasure(placeCaretInMiddle: Bool) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let before = copy(appElement, "AXEnhancedUserInterface").value as? Bool
        if !wokenProcesses.contains(app.processIdentifier), before != true {
            let status = AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            wokenProcesses.insert(app.processIdentifier)
            log.write("run=\(run) enhancedUIBefore=\(before.map { "\($0)" } ?? "none") set=\(status.rawValue)")
        }
        let run = run
        Task { @MainActor in
            let started = ContinuousClock.now
            while ContinuousClock.now - started < .seconds(3) {
                try? await Task.sleep(for: .milliseconds(50))
                if let element = self.focusedElement() {
                    let waited = Int((ContinuousClock.now - started) / .milliseconds(1))
                    self.log.write("run=\(run) readable after ms=\(waited)")
                    self.measure(element, front: app.bundleIdentifier ?? "none", placeCaretInMiddle: placeCaretInMiddle)
                    return
                }
            }
            self.log.write("run=\(run) still unreadable after 3 s: unmeasured without a click")
        }
    }

    private func measure(_ element: AXUIElement, front: String, placeCaretInMiddle: Bool) {
        let role = string(element, kAXRoleAttribute) ?? "none"
        let value = string(element, kAXValueAttribute)
        let utf16Length = value?.utf16.count ?? 0
        if placeCaretInMiddle { placeCaret(in: element, at: utf16Length / 2) }
        let started = ContinuousClock.now
        let (rangeStatus, range) = selectedRange(element)
        let rangeMicros = Int((ContinuousClock.now - started) / .microseconds(1))
        let numberOfCharacters = number(element, kAXNumberOfCharactersAttribute)
        let insertionLine = number(element, kAXInsertionPointLineNumberAttribute)
        let (visibleStatus, visible) = rangeValue(element, kAXVisibleCharacterRangeAttribute)
        log.write(
            "run=\(run) front=\(front) role=\(role) valueReadable=\(value != nil) ownTextLength=\(value?.count ?? 0) "
                + "ownTextUTF16=\(utf16Length) cursorReported=\(range != nil) rangeStatus=\(rangeStatus.rawValue) "
                + "rangeLocation=\(range.map { "\($0.location)" } ?? "-") "
                + "rangeLength=\(range.map { "\($0.length)" } ?? "-") "
                + "rangeReadMicros=\(rangeMicros) numberOfCharacters=\(numberOfCharacters) "
                + "insertionLine=\(insertionLine) visibleStatus=\(visibleStatus.rawValue) "
                + "visible=\(visible.map { "\($0.location)+\($0.length)" } ?? "-")"
        )
        if let value { logMarkers(in: value, cursor: range?.location ?? utf16Length) }
    }

    /// For each marker: whether it is in the value, and its first and last UTF-16 offsets minus the cursor.
    private func logMarkers(in value: String, cursor: Int) {
        let text = value as NSString
        for marker in Self.markers {
            let first = text.range(of: marker)
            guard first.location != NSNotFound else {
                log.write("run=\(run)   marker=\(marker) inValue=false")
                continue
            }
            let last = text.range(of: marker, options: .backwards)
            log.write(
                "run=\(run)   marker=\(marker) inValue=true firstFromCursor=\(first.location - cursor) "
                    + "lastFromCursor=\(last.location - cursor)"
            )
        }
    }

    private func placeCaret(in element: AXUIElement, at location: Int) {
        var range = CFRange(location: location, length: 0)
        guard let value = AXValueCreate(.cfRange, &range) else { return }
        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
        log.write("run=\(run) placeCaret location=\(location) setStatus=\(status.rawValue)")
    }

    private func focusedElement() -> AXUIElement? {
        guard let value = copy(systemWide, kAXFocusedUIElementAttribute).value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func selectedRange(_ element: AXUIElement) -> (AXError, CFRange?) {
        rangeValue(element, kAXSelectedTextRangeAttribute)
    }

    private func rangeValue(_ element: AXUIElement, _ attribute: String) -> (AXError, CFRange?) {
        let (status, value) = copy(element, attribute)
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return (status, nil) }
        let axValue = unsafeDowncast(value, to: AXValue.self)
        var range = CFRange()
        guard AXValueGetType(axValue) == .cfRange, AXValueGetValue(axValue, .cfRange, &range) else {
            return (status, nil)
        }
        return (status, range)
    }

    private func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute).value as? String
    }

    private func number(_ element: AXUIElement, _ attribute: String) -> String {
        let (status, value) = copy(element, attribute)
        guard let number = value as? NSNumber else { return "none(\(status.rawValue))" }
        return "\(number.intValue)"
    }

    private func copy(_ element: AXUIElement, _ attribute: String) -> (status: AXError, value: CFTypeRef?) {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return (status, value)
    }
}
