// PROTOTYPE — menu-settings, never merged
import AppKit

/// Menu A: a real `NSMenu` on the status item whose first item's `view` holds the History Search field.
/// Everything that happens to keys and focus is logged with `[proto] A:` so the fact table is observed, not assumed.
@MainActor
final class MenuAController: NSObject, NSMenuDelegate, NSSearchFieldDelegate {
    let menu = NSMenu()
    let field = NSSearchField()
    private let state = ProtoState.shared
    private let actions: ProtoActions
    private var highlighted: NSMenuItem?
    private let rowTag = 100
    private var keyMonitor: Any?

    init(actions: ProtoActions) {
        self.actions = actions
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        let container = FocusOnWindowView(frame: NSRect(x: 0, y: 0, width: 420, height: 34))
        field.frame = NSRect(x: 14, y: 5, width: 392, height: 24)
        field.delegate = self
        field.sendsSearchStringImmediately = true
        container.addSubview(field)
        container.field = field
        let fieldItem = NSMenuItem()
        fieldItem.view = container
        menu.addItem(fieldItem)
        menu.addItem(.separator())
        for item in actions.tailItems() { menu.addItem(item) }
    }

    // MARK: menu lifecycle

    func menuWillOpen(_ menu: NSMenu) {
        field.stringValue = ""
        state.query = ""
        field.placeholderString = state.placeholder
        rebuildRows(query: "")
        state.note("A: menuWillOpen; menu bar visible=\(NSMenu.menuBarVisible())")
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.log(event)
            return event
        }
        ProtoHooks.shared.after(0.05) { [weak self] in
            guard let self, let window = self.field.window else { return }
            let took = window.makeFirstResponder(self.field)
            self.state.note("A: makeFirstResponder(field) in tracking loop → \(took); key=\(window.isKeyWindow)"
                + " window=\(window.windowNumber) \(type(of: window))")
            ProtoHooks.shared.menuWindowOpened(window)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        state.note("A: menuDidClose (field text \"\(field.stringValue)\")")
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        highlighted = item
        NSLog("[proto] A: willHighlight %@", item?.title ?? "nil")
    }

    private func log(_ event: NSEvent) {
        let responder = event.window?.firstResponder.map { String(describing: type(of: $0)) } ?? "nil"
        NSLog("[proto] A: keyDown %@ (code %d) window=%@ firstResponder=%@", event.charactersIgnoringModifiers ?? "",
              event.keyCode, event.window.map { String(describing: type(of: $0)) } ?? "nil", responder)
    }

    // MARK: search field

    func controlTextDidChange(_ notification: Notification) {
        state.query = field.stringValue
        rebuildRows(query: field.stringValue)
        state.note("A: text \"\(field.stringValue)\" → \(state.search(field.stringValue).rows.count) rows,"
            + " menu items=\(menu.numberOfItems)")
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        state.note("A: field got command \(selector)")
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            let rows = menu.items.filter { $0.tag == rowTag && $0.representedObject is Int }
            if let target = (highlighted?.representedObject is Int ? highlighted : nil) ?? rows.first {
                choose(target)
                menu.cancelTracking()
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            menu.cancelTracking()
            return true
        default:
            return false
        }
    }

    /// Screenshot hook: puts `query` into the field as if typed.
    func typeQuery(_ query: String) {
        field.stringValue = query
        controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    }

    // MARK: rows

    private func rebuildRows(query: String) {
        while menu.numberOfItems > 1, menu.item(at: 1)?.tag == rowTag { menu.removeItem(at: 1) }
        let (rows, total) = state.search(query)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let look = RowLook(style: state.rowStyle)
        var index = 1
        func insert(_ item: NSMenuItem) {
            item.tag = rowTag
            menu.insertItem(item, at: index)
            index += 1
        }
        if let header = look.header(shown: rows.count, total: total) {
            insert(NSMenuItem.sectionHeader(title: header))
        }
        if rows.isEmpty {
            let none = NSMenuItem(title: "No matching Clipboard Items", action: nil, keyEquivalent: "")
            none.isEnabled = false
            insert(none)
        }
        for clip in rows {
            let active = clip.id == state.activeID
            let item = NSMenuItem(title: clip.firstLine, action: #selector(rowChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = clip.id
            item.attributedTitle = look.menuTitle(clip, query: query, active: active)
            item.image = look.leadingImage(clip, active: active, highlighted: false)
            if state.rowStyle == 1 { item.state = active ? .on : .off }
            item.toolTip = clip.text
            insert(item)
        }
        let full = NSMenuItem(title: "Full history…", action: #selector(fullHistory), keyEquivalent: "")
        full.target = self
        full.attributedTitle = look.fullHistoryTitle(total: total, all: state.items.count)
        insert(full)
        insert(.separator())
    }

    @objc private func rowChosen(_ sender: NSMenuItem) {
        choose(sender)
    }

    private func choose(_ item: NSMenuItem) {
        guard let id = item.representedObject as? Int else { return }
        state.setActive(id, via: "A: row chosen")
        field.placeholderString = state.placeholder
    }

    @objc private func fullHistory() {
        actions.openSettings(.fullHistory)
    }
}

/// The field's container: when the menu puts it into its window, it tries to make the field first responder.
final class FocusOnWindowView: NSView {
    weak var field: NSSearchField?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, let field else { return }
        let took = window.makeFirstResponder(field)
        NSLog("[proto] A: viewDidMoveToWindow → makeFirstResponder(field) %@", took ? "true" : "false")
    }
}
