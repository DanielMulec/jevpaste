import AppKit
import UserNotifications

/// Visible failure states, ranked by how much they disturb the user's focus.
enum Indicator {
    private static var statusItem: NSStatusItem?
    private static var panel: NSPanel?

    static func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "JP·idle"
        item.button?.toolTip = "jevpaste macOS probe (throwaway)"
        statusItem = item
        Log.line("statusItem installed title=\"JP·idle\"")
    }

    /// Cheapest indicator: menu-bar title/colour change. Cannot steal focus by construction.
    static func flashStatus(_ text: String, seconds: Double = 2.5) {
        let before = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        let (_, ms) = Clock.measure {
            statusItem?.button?.attributedTitle = NSAttributedString(
                string: "JP·\(text)",
                attributes: [.foregroundColor: NSColor.systemRed]
            )
        }
        let after = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        Log.line("INDICATOR statusItem text=\"JP·\(text)\" updateMs=\(ms) frontmostBefore=\(before) "
                 + "frontmostAfter=\(after) stoleFocus=\(before != after)")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            statusItem?.button?.attributedTitle = NSAttributedString(string: "JP·idle")
        }
    }

    /// Non-activating floating panel: visible, should not take key focus from the target app.
    static func flashPanel(_ text: String, seconds: Double = 2.5) {
        let before = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        let (_, ms) = Clock.measure {
            let width: CGFloat = 320
            let height: CGFloat = 64
            let screen = NSScreen.main?.visibleFrame ?? .zero
            let frame = NSRect(x: screen.midX - width / 2, y: screen.maxY - height - 24,
                               width: width, height: height)
            let window = NSPanel(contentRect: frame,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
            window.level = .statusBar
            window.isOpaque = false
            window.hasShadow = true
            window.ignoresMouseEvents = true
            window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

            let field = NSTextField(labelWithString: text)
            field.frame = NSRect(x: 16, y: 20, width: width - 32, height: 24)
            field.font = .systemFont(ofSize: 14, weight: .semibold)
            field.textColor = .systemRed
            window.contentView?.addSubview(field)
            window.orderFrontRegardless()
            panel = window
        }
        let after = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        let keyWindowIsOurs = NSApp.keyWindow != nil
        Log.line("INDICATOR panel showMs=\(ms) frontmostBefore=\(before) frontmostAfter=\(after) "
                 + "stoleFocus=\(before != after) probeHasKeyWindow=\(keyWindowIsOurs)")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            panel?.orderOut(nil)
            panel = nil
        }
    }

    /// The disruptive baseline, for comparison only.
    static func modalAlert(_ text: String, autoDismissSeconds: Double = 2.0) {
        let before = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        DispatchQueue.global().asyncAfter(deadline: .now() + autoDismissSeconds) {
            DispatchQueue.main.async { NSApp.abortModal() }
        }
        let alert = NSAlert()
        alert.messageText = "jevpaste probe"
        alert.informativeText = text
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        _ = alert.runModal()
        let after = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        Log.line("INDICATOR NSAlert frontmostBefore=\(before) frontmostAfterDismiss=\(after) "
                 + "stoleFocus=\(before != after) (NSAlert requires activation by design)")
    }

    static func requestNotificationAuthorization() {
        guard Bundle.main.bundleIdentifier != nil else {
            Log.fail("INDICATOR UNUserNotificationCenter needs a bundle; running unbundled")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            Log.line("INDICATOR notification authorization granted=\(granted) "
                     + "error=\(error?.localizedDescription ?? "nil")")
        }
    }

    static func postNotification(_ text: String) {
        let before = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        let content = UNMutableNotificationContent()
        content.title = "jevpaste probe"
        content.body = text
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            let after = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
            Log.line("INDICATOR notification posted error=\(error?.localizedDescription ?? "nil") "
                     + "frontmostBefore=\(before) frontmostAfter=\(after)")
        }
    }
}
