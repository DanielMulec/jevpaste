// PROTOTYPE — menu-settings, never merged
import AppKit

enum SettingsSection: Equatable {
    case general, provider, fullHistory
    /// Where "No key for <provider> — open Settings" lands: that provider's key field, focused.
    case key(JevProvider)
}

@MainActor
protocol ProtoActions: AnyObject {
    func tailItems() -> [NSMenuItem]
    func variantMenu() -> NSMenu
    func openSettings(_ section: SettingsSection)
}

/// The prototype app: its own status item (SF Symbol `sparkle`), Menu A or Menu B, the Variant ▸ submenu.
@MainActor
final class ProtoAppDelegate: NSObject, NSApplicationDelegate, ProtoActions {
    private let state = ProtoState.shared
    private var statusItem: NSStatusItem!
    private var menuA: MenuAController!
    private var menuB: MenuBPanel!
    private let labelItem = NSMenuItem()
    private let settings = SettingsWindows()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let environment = ProcessInfo.processInfo.environment
        if let menu = environment["PROTO_MENU"] { state.menuVariant = menu }
        if let rows = environment["PROTO_ROWS"].flatMap(Int.init) { state.rowStyle = rows }
        if let take = environment["PROTO_FULL"].flatMap(Int.init) { state.fullTake = take }
        if let layout = environment["PROTO_SETTINGS"].flatMap(Int.init) { state.settingsVariant = layout }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "JevPaste prototype")
        labelItem.isEnabled = false
        menuA = MenuAController(actions: self)
        menuB = MenuBPanel(actions: self) { [weak self] in
            guard let button = self?.statusItem.button, let window = button.window else { return nil }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }
        state.observe { [weak self] in self?.stateChanged() }
        applyMenuVariant()
        stateChanged()
        ProtoHooks.shared.start(app: self)
    }

    private var appliedVariant = ""

    private func stateChanged() {
        labelItem.attributedTitle = NSAttributedString(string: state.label, attributes: [
            .font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.tertiaryLabelColor,
        ])
        if appliedVariant != state.menuVariant { applyMenuVariant() }
        settings.stateChanged()
    }

    private func applyMenuVariant() {
        appliedVariant = state.menuVariant
        guard let button = statusItem.button else { return }
        if state.menuVariant == "A" {
            menuB.close(reason: "variant switch")
            statusItem.menu = menuA.menu
            button.action = nil
        } else {
            statusItem.menu = nil
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: .leftMouseDown)
        }
    }

    @objc private func statusItemClicked() {
        menuB.toggle()
    }

    /// Opens whichever menu variant is current, as a click on the status item would.
    func openMenu(query: String?) {
        if state.menuVariant == "A" {
            if let query { ProtoHooks.shared.after(0.6) { self.menuA.typeQuery(query) } }
            statusItem.button?.performClick(nil)  // blocks in menu tracking until the menu closes
        } else {
            menuB.open(query: query ?? "")
            ProtoHooks.shared.windowReady(menuB.window, name: "menu")
        }
    }

    // MARK: ProtoActions

    func tailItems() -> [NSMenuItem] {
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsItem), keyEquivalent: ",")
        settingsItem.target = self
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let variant = NSMenuItem(title: "Variant", action: nil, keyEquivalent: "")
        variant.submenu = variantMenu()
        return [settingsItem, quit, .separator(), variant, labelItem]
    }

    func variantMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        func add(_ title: String, _ on: Bool, _ apply: @escaping () -> Void) {
            let item = ClosureMenuItem(title: title, run: apply)
            item.state = on ? .on : .off
            menu.addItem(item)
        }
        add("Menu A — real NSMenu", state.menuVariant == "A") { self.state.menuVariant = "A" }
        add("Menu B — menu-shaped panel", state.menuVariant == "B") { self.state.menuVariant = "B" }
        menu.addItem(.separator())
        for (style, name) in [(1, "plain line + ✓"), (2, "two lines + dot"), (3, "symbol + Active tag")] {
            add("Rows \(style) — \(name)", state.rowStyle == style) { self.state.rowStyle = style }
        }
        menu.addItem(.separator())
        for (take, name) in [(1, "own block"), (2, "in Settings/Quit block")] {
            add("Full history take \(take) — \(name)", state.fullTake == take) { self.state.fullTake = take }
        }
        menu.addItem(.separator())
        for (layout, name) in [(1, "toolbar tabs"), (2, "sidebar"), (3, "one page")] {
            add("Settings \(layout) — \(name)", state.settingsVariant == layout) {
                self.state.settingsVariant = layout
            }
        }
        menu.addItem(.separator())
        for provider in JevProvider.allCases {
            add("Demo: “No key for \(provider.rawValue) — open Settings”", false) {
                self.openSettings(.key(provider))
            }
        }
        menu.delegate = VariantMenuRefresher.shared
        return menu
    }

    @objc private func openSettingsItem() {
        openSettings(.general)
    }

    func openSettings(_ section: SettingsSection) {
        // After the menu has closed, so its tracking end does not take the window's key focus.
        DispatchQueue.main.async { self.settings.open(section) }
    }
}

/// Rebuilds the Variant ▸ checkmarks each time the submenu opens.
@MainActor
final class VariantMenuRefresher: NSObject, NSMenuDelegate {
    static let shared = VariantMenuRefresher()
    weak var app: ProtoAppDelegate?

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let fresh = app?.variantMenu() else { return }
        menu.removeAllItems()
        for item in fresh.items {
            fresh.removeItem(item)
            menu.addItem(item)
        }
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void

    init(title: String, run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { run() }
}
