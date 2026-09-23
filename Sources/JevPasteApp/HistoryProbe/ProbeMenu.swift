// PROTOTYPE — history-probe, never merged
import AppKit
import SmartPasteCore

/// A menu item that runs a closure.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("not used")
    }

    @objc private func run() {
        handler()
    }
}

/// The status-item menu, rebuilt each time it opens: variant A's history section (or B/C's opener), clear-all, the
/// probe controls (variant switch, fail-next toggle), then the production items (Open at Login, Quit).
@MainActor
final class ProbeMenu: NSObject, NSMenuDelegate {
    private static let menuRows = 15

    let menu = NSMenu()
    private let probe: HistoryProbe
    private let loginItem: LoginItemMenu

    init(probe: HistoryProbe, loginItem: LoginItemMenu) {
        self.probe = probe
        self.loginItem = loginItem
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        menuNeedsUpdate(menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let items = probe.items()
        switch probe.variant {
        case .menu: addHistorySection(items)
        case .panel: menu.addItem(ClosureMenuItem("Show History…") { [probe] in probe.openPanel() })
        case .search: menu.addItem(ClosureMenuItem("Search History…") { [probe] in probe.openPanel() })
        }
        addClearAll(count: items.count)
        menu.addItem(.separator())
        addProbeControls()
        menu.addItem(.separator())
        loginItem.menuNeedsUpdate(menu)
        menu.addItem(loginItem.item)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    /// Variant A: "Active: …" header, then the newest items with ✓ on the Active one; ⌥ turns each into Delete.
    private func addHistorySection(_ items: [ClipboardItem]) {
        let activeLabel = probe.capture.activeItem.map { HistoryProbe.label(for: $0, limit: 50) } ?? "nothing yet"
        let header = NSMenuItem(title: "Active: " + activeLabel, action: nil, keyEquivalent: "")
        header.isEnabled = false
        header.attributedTitle = NSAttributedString(
            string: header.title, attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)]
        )
        menu.addItem(header)
        menu.addItem(.separator())
        for item in items.prefix(Self.menuRows) {
            let label = HistoryProbe.label(for: item, limit: 50)
            let select = ClosureMenuItem(label) { [probe] in probe.select(item, from: "menu") }
            select.state = probe.isActive(item) ? .on : .off
            menu.addItem(select)
            let delete = ClosureMenuItem("Delete  " + label) { [probe] in probe.delete(item) }
            delete.isAlternate = true
            delete.keyEquivalentModifierMask = .option
            menu.addItem(delete)
        }
        if items.isEmpty {
            let empty = NSMenuItem(title: "(no history)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        let hint = NSMenuItem(title: "hold ⌥ to delete", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
    }

    private func addClearAll(count: Int) {
        let clear = NSMenuItem(title: "Clear History", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(ClosureMenuItem("Delete all \(count) items") { [probe] in probe.clearAll() })
        clear.submenu = submenu
        clear.isEnabled = count > 0
        menu.addItem(clear)
    }

    private func addProbeControls() {
        let variants = NSMenuItem(title: "Probe variant", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for variant in ProbeVariant.allCases {
            let item = ClosureMenuItem(variant.rawValue) { [probe] in probe.variant = variant }
            item.state = probe.variant == variant ? .on : .off
            submenu.addItem(item)
        }
        variants.submenu = submenu
        menu.addItem(variants)
        let failNext = ClosureMenuItem("Probe: fail next Jev call") { [probe] in
            probe.failNext.arm(!probe.failNext.isArmed)
        }
        failNext.state = probe.failNext.isArmed ? .on : .off
        menu.addItem(failNext)
    }
}
