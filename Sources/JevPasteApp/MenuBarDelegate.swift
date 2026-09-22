import AppKit

/// Owns the status item (the SF Symbol `doc.on.clipboard` and a menu with only "Quit") and starts Smart Paste.
@MainActor
final class MenuBarDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    // periphery:ignore - held for the app's lifetime; ⌘⇧V drives it.
    private var smartPaste: SmartPasteApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "jevpaste")
        item.menu = makeMenu()
        statusItem = item
        smartPaste = SmartPasteApplication(statusItem: item)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        return menu
    }
}
