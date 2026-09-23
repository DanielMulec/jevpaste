import AppKit

/// Owns the status item (the SF Symbol `doc.on.clipboard` and a menu with "Open at Login" and "Quit") and starts
/// Smart Paste.
@MainActor
final class MenuBarDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    // periphery:ignore - held for the app's lifetime; ⌘⇧V drives it.
    private var smartPaste: SmartPasteApplication?
    // periphery:ignore - held for the app's lifetime: the menu keeps its delegate and item target weakly.
    private var loginItemMenu: LoginItemMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "jevpaste")
        statusItem = item
        let application = SmartPasteApplication(statusItem: item)
        smartPaste = application
        let loginItemMenu = LoginItemMenu(toggle: application.loginItem)
        self.loginItemMenu = loginItemMenu
        // PROTOTYPE — history-probe, never merged: the probe menu replaces the production menu.
        let probeMenu = ProbeMenu(probe: application.historyProbe, loginItem: loginItemMenu)
        self.probeMenu = probeMenu
        item.menu = probeMenu.menu
    }

    private var probeMenu: ProbeMenu?

    private func makeMenu(loginItem: LoginItemMenu) -> NSMenu {
        let menu = NSMenu()
        menu.delegate = loginItem
        menu.addItem(loginItem.item)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        return menu
    }
}
