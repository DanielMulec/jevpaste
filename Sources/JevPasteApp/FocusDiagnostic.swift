import AppKit
import ApplicationServices
import MacInterop

/// TEMPORARY `JevPaste --diagnose-focus` for [Restore Smart Paste in the ChatGPT desktop app](#33): each ⌘⇧V runs
/// the staged `FocusProbe` in the frontmost app instead of a Paste Attempt. Nothing is inserted and the clipboard
/// is never touched. The status item shows `D<press>:<stage that resolved>` or `D<press>:none`.
@MainActor
final class FocusDiagnostic: NSObject, NSApplicationDelegate {
    private let hotkey = GlobalHotkey()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var presses = 0
    private var isRunning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.title = "D:ready"
        FocusProbe.log.info("start accessibilityTrusted=\(AXIsProcessTrusted(), privacy: .public)")
        hotkey.startListening { [weak self] in self?.pressed() }
    }

    private func pressed() {
        guard !isRunning, let application = NSWorkspace.shared.frontmostApplication else { return }
        presses += 1
        isRunning = true
        let probe = FocusProbe(press: presses, application: application)
        statusItem.button?.title = "D\(presses):…"
        Task { @MainActor in
            let resolvedAt = await probe.run()
            FocusProbe.log.info(
                "press \(probe.press, privacy: .public): verdict resolvedAt=\(resolvedAt ?? "none", privacy: .public)")
            self.statusItem.button?.title = "D\(probe.press):\(resolvedAt ?? "none")"
            self.isRunning = false
        }
    }
}
