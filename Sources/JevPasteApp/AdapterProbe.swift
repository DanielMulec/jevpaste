import AppKit
import ApplicationServices
import MacInterop
import SmartPasteCore

/// `JevPaste --probe <log-path>`: proves the MacInterop adapters in the signed bundle, which holds the
/// Accessibility grant. Each ⌘⇧V runs the Paste Attempt's delivery order over the real adapters with synthetic
/// text. The log holds counts, lengths and verdicts only — never clipboard or field contents.
@MainActor
final class AdapterProbe: NSObject, NSApplicationDelegate {
    private static let maximumPresses = 5
    private static let lifetime = Duration.seconds(300)
    private static let restoreDelay = Duration.milliseconds(120)
    private static let readBackDelay = Duration.milliseconds(500)

    private let log: ProbeLog
    private let clipboard = SystemClipboard()
    private let hotkey = GlobalHotkey()
    private let resolver = AccessibilityTargetResolver()
    private let inserter = PasteKeystrokeInserter()
    private var presses = 0

    init(logPath: String) {
        log = ProbeLog(path: logPath)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.write("start accessibilityTrusted=\(AXIsProcessTrusted()) postEventAccess=\(CGPreflightPostEventAccess())")
        let placed = clipboard.restore(Self.syntheticOriginal)
        log.write("placed synthetic original changeCount=\(placed)")
        clipboard.startObservingChanges { [log] change in
            let item = change.item.map { "chars=\($0.text.count) concealed=\($0.isConcealed)" } ?? "none"
            log.write("observed change changeCount=\(change.changeCount) item=\(item)")
        }
        hotkey.startListening { [weak self] in self?.pastePressed() }
        Task { @MainActor in
            try? await Task.sleep(for: Self.lifetime)
            self.quit(reason: "lifetime elapsed")
        }
        log.write("listening for ⌘⇧V")
    }

    private func pastePressed() {
        presses += 1
        let marker = "JEVPASTE-PROBE-\(presses)"
        guard case .resolved(let target) = resolver.resolveFocusedTarget() else {
            log.write("press \(presses): no editable target")
            return
        }
        describe(target)
        guard !target.isSecureField else {
            log.write("press \(presses): secure target refused")
            return
        }
        guard resolver.isStillFocused(target.identity) else {
            log.write("press \(presses): target changed before delivery")
            return
        }
        deliver(marker)
    }

    /// Core's delivery order: snapshot → write → ⌘V → 120 ms → restore unless a foreign copy arrived.
    private func deliver(_ marker: String) {
        let original = clipboard.snapshot()
        let ownCount = clipboard.write(marker)
        let heldModifiers = CGEventSource.flagsState(.hidSystemState).intersection([.maskCommand, .maskShift])
        inserter.postPasteKeystroke()
        log.write(
            "press \(presses): wrote marker chars=\(marker.count) ownChangeCount=\(ownCount), "
                + "posted ⌘V with ⌘/⇧ held=\(!heldModifiers.isEmpty)"
        )
        let press = presses
        Task { @MainActor in
            try? await Task.sleep(for: Self.restoreDelay)
            self.restore(original, ownCount: ownCount, press: press)
            try? await Task.sleep(for: Self.readBackDelay)
            self.log.write("press \(press): readBackContainsMarker=\(Self.focusedValueContains(marker))")
            if press >= Self.maximumPresses { self.quit(reason: "maximum presses") }
        }
    }

    private func restore(_ original: ClipboardSnapshot, ownCount: Int, press: Int) {
        guard clipboard.changeCount == ownCount else {
            log.write("press \(press): foreign copy in restore window, restore skipped")
            return
        }
        let restoredCount = clipboard.restore(original)
        let byteForByte = clipboard.snapshot() == original
        let types = original.items.map(\.count).reduce(0, +)
        let bytes = original.items.flatMap(\.values).map(\.count).reduce(0, +)
        log.write(
            "press \(press): restored changeCount=\(restoredCount) items=\(original.items.count) "
                + "types=\(types) bytes=\(bytes) restoredByteForByte=\(byteForByte) "
                + "originalIsSyntheticSeed=\(original == Self.syntheticOriginal)"
        )
    }

    private func describe(_ target: BoundTarget) {
        let context = target.context
        let bundle = NSRunningApplication(processIdentifier: target.identity.processIdentifier)?.bundleIdentifier
        log.write(
            "press \(presses): target app=\(bundle ?? "unknown") secure=\(target.isSecureField) "
                + "labelChars=\(context.fieldLabel?.count ?? 0) placeholderChars=\(context.placeholder?.count ?? 0) "
                + "headingChars=\(context.sectionHeading?.count ?? 0) siblings=\(context.siblingFieldLabels.count) "
                + "surroundingChars=\(context.surroundingText.count)"
        )
    }

    private func quit(reason: String) {
        log.write("quit: \(reason)")
        NSApplication.shared.terminate(nil)
    }

    /// Read-back is valid on Chrome only (the probe found it lags or lies elsewhere). Returns a verdict, never text.
    private static func focusedValueContains(_ marker: String) -> Bool {
        var focused: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
            let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return false }
        var value: CFTypeRef?
        let element = unsafeDowncast(focused, to: AXUIElement.self)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        return (value as? String)?.contains(marker) == true
    }

    /// Three items of different types, so a restore that drops a type or an item cannot pass.
    private static let syntheticOriginal = ClipboardSnapshot(items: [
        [
            "public.utf8-plain-text": Data("JEVPASTE-ORIGINAL".utf8),
            "public.html": Data("<b>JEVPASTE-ORIGINAL</b>".utf8),
        ],
        ["com.jevpaste.probe-original": Data([0x00, 0x4A, 0x45, 0x56, 0xFF])],
    ])
}

/// Appends timestamped lines to the probe log file.
@MainActor
final class ProbeLog {
    private let url: URL

    init(path: String) {
        url = URL(fileURLWithPath: path)
        FileManager.default.createFile(atPath: path, contents: nil)
    }

    func write(_ line: String) {
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(Data("\(Date().ISO8601Format()) \(line)\n".utf8))
    }
}
