import AppKit

/// Owns the status item (the SF Symbol `doc.on.clipboard` and a short menu: "Clipboard History…", "Open at Login",
/// "Quit") and starts Smart Paste.
@MainActor
final class MenuBarDelegate: NSObject, NSApplicationDelegate {
    private let options: LaunchOptions
    private var statusItem: NSStatusItem?
    private var smartPaste: SmartPasteApplication?
    // periphery:ignore - held for the app's lifetime: the menu keeps its delegate and item target weakly.
    private var loginItemMenu: LoginItemMenu?

    init(options: LaunchOptions) {
        self.options = options
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "jevpaste")
        statusItem = item
        let application = SmartPasteApplication(statusItem: item, options: options)
        smartPaste = application
        let loginItemMenu = LoginItemMenu(toggle: application.loginItem)
        self.loginItemMenu = loginItemMenu
        item.menu = makeMenu(loginItem: loginItemMenu)
    }

    private func makeMenu(loginItem: LoginItemMenu) -> NSMenu {
        let menu = NSMenu()
        menu.delegate = loginItem
        let history = NSMenuItem(title: "Clipboard History…", action: #selector(openHistory), keyEquivalent: "")
        history.target = self
        menu.addItem(history)
        menu.addItem(.separator())
        menu.addItem(loginItem.item)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        return menu
    }

    /// Opens the history panel once the menu has closed, so the menu's own tracking end does not take its key focus.
    @objc private func openHistory() {
        Task { @MainActor [weak self] in
            self?.smartPaste?.historyPanel.open()
        }
    }
}
