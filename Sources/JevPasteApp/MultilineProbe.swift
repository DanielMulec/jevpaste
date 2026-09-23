import AppKit
import ApplicationServices
import MacInterop
import SmartPasteCore

/// PROTOTYPE (issue #14, branch `multiline-probe`, never merged).
/// `JevPaste --multiline-probe <log-path>`: each ⌘⇧V delivers a synthetic multi-line payload to the focused target
/// with Core's delivery order (snapshot → write → ⌘V → 120 ms → restore). Variants cycle per delivery: LF, CRLF,
/// LF + trailing newline. Daniel's real clipboard is snapshotted and restored; no synthetic seed.
/// The log holds counts and verdicts only — never clipboard or field contents.
@MainActor
final class MultilineProbe: NSObject, NSApplicationDelegate {
    private static let maximumPresses = 40
    private static let lifetime = Duration.seconds(3600)
    private static let restoreDelay = Duration.milliseconds(120)
    private static let readBackDelay = Duration.milliseconds(500)
    private static let markers = (1...3).map { "JEVPASTE-ML-LINE-\($0)" }
    private static let variants: [(name: String, payload: String)] = [
        ("LF", lines(joinedBy: "\n")),
        ("CRLF", lines(joinedBy: "\r\n")),
        ("LF-TRAIL", lines(joinedBy: "\n") + "\n"),
    ]

    private let log: ProbeLog
    private let clipboard = SystemClipboard()
    private let hotkey = GlobalHotkey()
    private let resolver = AccessibilityTargetResolver()
    private let inserter = PasteKeystrokeInserter()
    private var presses = 0
    private var deliveries = 0
    private var signalSource: (any DispatchSourceSignal)?

    init(logPath: String) {
        log = ProbeLog(path: logPath)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.write("start accessibilityTrusted=\(AXIsProcessTrusted()) postEventAccess=\(CGPreflightPostEventAccess())")
        hotkey.startListening { [weak self] in self?.pastePressed() }
        // Terminal runs without Daniel: `kill -USR1 <pid>` runs the same press path; only the hotkey is bypassed.
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.log.write("SIGUSR1 trigger")
                self?.pastePressed()
            }
        }
        source.resume()
        signalSource = source
        Task { @MainActor in
            try? await Task.sleep(for: Self.lifetime)
            self.quit(reason: "lifetime elapsed")
        }
        log.write("listening for ⌘⇧V (multiline)")
    }

    private func pastePressed() {
        presses += 1
        guard let target = resolver.resolveFocusedTarget() else {
            let diagnostic = Self.refusalDiagnostic()
            log.write("press \(presses): no editable target \(diagnostic)")
            // Probe-only fallback (approved): the resolver cannot see com.openai.codex's focus; measure anyway.
            if diagnostic.hasPrefix("front=com.openai.codex focusedElement=no status=-25212") {
                log.write("press \(presses): unresolved-delivery")
                deliverNext(readBack: false)
            }
            return
        }
        let bundle = NSRunningApplication(processIdentifier: target.identity.processIdentifier)?.bundleIdentifier
        log.write("press \(presses): target app=\(bundle ?? "unknown") secure=\(target.isSecureField)")
        guard !target.isSecureField else {
            log.write("press \(presses): secure target refused")
            return
        }
        guard resolver.isStillFocused(target.identity) else {
            log.write("press \(presses): target changed before delivery")
            return
        }
        deliverNext(readBack: bundle == "com.google.Chrome")
    }

    private func deliverNext(readBack: Bool) {
        let variant = Self.variants[deliveries % Self.variants.count]
        deliveries += 1
        deliver(variant, readBack: readBack)
    }

    private func deliver(_ variant: (name: String, payload: String), readBack: Bool) {
        let original = clipboard.snapshot()
        let ownCount = clipboard.write(variant.payload)
        inserter.postPasteKeystroke()
        log.write("press \(presses): delivered variant=\(variant.name) \(Self.counts(of: variant.payload))")
        let press = presses
        Task { @MainActor in
            try? await Task.sleep(for: Self.restoreDelay)
            self.restore(original, ownCount: ownCount, press: press)
            try? await Task.sleep(for: Self.readBackDelay)
            if readBack { self.log.write("press \(press): readBack \(Self.focusedValueVerdict())") }
            if press >= Self.maximumPresses { self.quit(reason: "maximum presses") }
        }
    }

    private func restore(_ original: ClipboardSnapshot, ownCount: Int, press: Int) {
        guard clipboard.changeCount == ownCount else {
            log.write("press \(press): foreign copy in restore window, restore skipped")
            return
        }
        _ = clipboard.restore(original)
        log.write(
            "press \(press): restored items=\(original.items.count) "
                + "restoredByteForByte=\(clipboard.snapshot() == original)"
        )
    }

    private func quit(reason: String) {
        log.write("quit: \(reason)")
        NSApplication.shared.terminate(nil)
    }

    private static func lines(joinedBy separator: String) -> String {
        markers.map { "# \($0)" }.joined(separator: separator)
    }

    /// Counts only: characters, LF, CR, lines (split on any newline). Never the text.
    private static func counts(of text: String) -> String {
        let scalars = text.unicodeScalars
        let lineFeeds = scalars.filter { $0 == "\n" }.count
        let carriageReturns = scalars.filter { $0 == "\r" }.count
        let lineCount = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
        return "chars=\(text.count) lf=\(lineFeeds) cr=\(carriageReturns) lines=\(lineCount)"
    }

    /// Why the resolver refused: frontmost app, and the focused element's role facts. Never text.
    private static func refusalDiagnostic() -> String {
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused)
        guard status == .success, let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return "front=\(front) focusedElement=no status=\(status.rawValue)"
        }
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let owner = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "unknown"
        var settable: DarwinBoolean = false
        let settableStatus = AXUIElementIsAttributeSettable(
            element, kAXSelectedTextRangeAttribute as CFString, &settable)
        return "front=\(front) focusedElement=yes owner=\(owner) role=\(attribute(kAXRoleAttribute, of: element)) "
            + "subrole=\(attribute(kAXSubroleAttribute, of: element)) "
            + "selectedTextRangeSettable=\(settable.boolValue) settableStatus=\(settableStatus.rawValue)"
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> String {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return (value as? String) ?? "none"
    }

    /// Read-back is valid on Chrome only. Returns marker verdicts and newline counts of the focused value.
    private static func focusedValueVerdict() -> String {
        var focused: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
            let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return "unavailable (no focused element)" }
        var value: CFTypeRef?
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        guard let text = value as? String else { return "unavailable (no string value)" }
        let present = markers.map { text.contains($0) }
        return "markersPresent=\(present) \(counts(of: text))"
    }
}
