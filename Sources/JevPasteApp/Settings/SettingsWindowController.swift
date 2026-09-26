import AppKit
import JevGateway
import os

/// The Settings window: one instance, standard toolbar tabs — General, Jev Provider, Full History. Its height
/// follows the selected tab with the top edge fixed. ⌘W closes it; closing hides the app, so focus returns to the
/// app that was in front. It keeps nothing of its own: every tab edits what it shows as it is edited.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private static let log = Logger(subsystem: "jevpaste", category: "Settings")
    private static let width = 620.0

    private let general: NSViewController
    private let jevProvider: JevProviderSettingsViewController
    private let fullHistory: NSViewController
    private var window: NSWindow?
    private var tabs: SettingsTabViewController?

    init(general: NSViewController, jevProvider: JevProviderSettingsViewController, fullHistory: NSViewController) {
        self.general = general
        self.jevProvider = jevProvider
        self.fullHistory = fullHistory
    }

    /// Brings Settings to the front at `section`; `.key` also focuses that provider's key field.
    func open(_ section: SettingsSection) {
        let (window, tabs) = shownOrBuilt()
        switch section {
        case .general: tabs.selectedTabViewItemIndex = 0
        case .jevProvider, .key: tabs.selectedTabViewItemIndex = 1
        case .fullHistory: tabs.selectedTabViewItemIndex = 2
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        if case .key(let provider) = section { jevProvider.focusKey(of: provider) }
        Self.log.notice("opened at \(String(describing: section), privacy: .public)")
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.hide(nil)
    }

    private func shownOrBuilt() -> (NSWindow, SettingsTabViewController) {
        if let window, let tabs { return (window, tabs) }
        return build()
    }

    private func build() -> (NSWindow, SettingsTabViewController) {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTab(general, title: "General", symbol: "gearshape")
        tabs.addTab(jevProvider, title: "Jev Provider", symbol: "bolt.horizontal")
        tabs.addTab(fullHistory, title: "Full History", symbol: "clock.arrow.circlepath")
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 300), styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.contentViewController = tabs
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        self.tabs = tabs
        return (window, tabs)
    }
}

/// Resizes the window to the selected tab's fitting height, keeping its top edge where it is.
final class SettingsTabViewController: NSTabViewController {
    func addTab(_ controller: NSViewController, title: String, symbol: String) {
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        addTabViewItem(item)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let window = view.window, let content = tabViewItem?.viewController?.view else { return }
        content.layoutSubtreeIfNeeded()
        let size = NSSize(width: window.contentLayoutRect.width, height: content.fittingSize.height)
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}

/// The Settings window takes ⌘W and the editing shortcuts itself: an accessory app has no menu bar holding them.
final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isCommandW =
            event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            && event.charactersIgnoringModifiers == "w"
        if isCommandW {
            performClose(nil)
            return true
        }
        return EditingShortcuts.perform(event, from: self) || super.performKeyEquivalent(with: event)
    }
}

extension SettingsWindowController {
    /// The Settings window over the app's real parts; built once at launch, its window on first open.
    static func assemble(
        loginItem: LoginItemToggle, keys: any JevKeyStore, choice: JevProviderChoice, jevAccess: JevGatewayAccess,
        fullHistory: FullHistoryList
    ) -> SettingsWindowController {
        let keySettings = ProviderKeySettings(keys: keys) { provider, reply in
            jevAccess.testConnection(of: provider, reply: reply)
        }
        return SettingsWindowController(
            general: GeneralSettingsViewController(loginItem: loginItem),
            jevProvider: JevProviderSettingsViewController(choice: choice, settings: keySettings),
            fullHistory: FullHistorySettingsViewController(list: fullHistory)
        )
    }
}
