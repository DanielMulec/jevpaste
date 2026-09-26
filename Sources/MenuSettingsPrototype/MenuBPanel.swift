// PROTOTYPE — menu-settings, never merged
import AppKit

/// Menu B: a borderless, key-capable, non-activating panel under the status item that looks like a menu.
/// All keys are ours: ↑/↓ move the highlight, Enter chooses, Esc and a click outside close.
@MainActor
final class MenuBPanel: NSObject, NSSearchFieldDelegate {
    private let panel = ProtoPanel()
    private let field = NSSearchField()
    private let stack = NSStackView()
    private let state = ProtoState.shared
    private let actions: ProtoActions
    private let anchor: () -> NSRect?
    private var rows: [PanelRow] = []
    private var highlightedIndex: Int?
    private let width = 420.0

    var isOpen: Bool { panel.isVisible }
    var window: NSWindow { panel }

    init(actions: ProtoActions, anchor: @escaping () -> NSRect?) {
        self.actions = actions
        self.anchor = anchor
        super.init()
        field.delegate = self
        field.sendsSearchStringImmediately = true
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 5, bottom: 6, right: 5)
        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: width),
        ])
        panel.contentView = background
        let fieldBox = NSView()
        field.translatesAutoresizingMaskIntoConstraints = false
        fieldBox.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: fieldBox.leadingAnchor, constant: 9),
            field.trailingAnchor.constraint(equalTo: fieldBox.trailingAnchor, constant: -9),
            field.topAnchor.constraint(equalTo: fieldBox.topAnchor, constant: 3),
            field.bottomAnchor.constraint(equalTo: fieldBox.bottomAnchor, constant: -5),
        ])
        add(fieldBox)
        add(MenuSeparator())
        panel.onResignKey = { [weak self] in self?.close(reason: "click outside (resignKey)") }
    }

    func toggle() {
        isOpen ? close(reason: "status item clicked again") : open()
    }

    func open(query: String = "") {
        field.stringValue = query
        state.query = query
        field.placeholderString = state.placeholder
        rebuild()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        state.note("B: open; key=\(panel.isKeyWindow) firstResponder=field; menu bar visible=\(NSMenu.menuBarVisible())")
    }

    func close(reason: String) {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        state.note("B: closed — \(reason)")
    }

    // MARK: keys

    func controlTextDidChange(_ notification: Notification) {
        state.query = field.stringValue
        rebuild()
        state.note("B: text \"\(field.stringValue)\" → \(rows.filter { $0.clipID != nil }.count) rows")
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        let selectable = rows.indices
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            guard !selectable.isEmpty else { return true }
            highlight(highlightedIndex.map { min($0 + 1, selectable.upperBound - 1) } ?? 0)
        case #selector(NSResponder.moveUp(_:)):
            guard let index = highlightedIndex else { return true }
            highlight(index == 0 ? nil : index - 1)
        case #selector(NSResponder.insertNewline(_:)):
            if let index = highlightedIndex ?? rows.firstIndex(where: { $0.clipID != nil }) { rows[index].onClick?() }
        case #selector(NSResponder.cancelOperation(_:)):
            if field.stringValue.isEmpty { close(reason: "Esc") } else {
                field.stringValue = ""
                state.query = ""
                rebuild()
                state.note("B: Esc cleared the field")
            }
        default:
            return false
        }
        state.note("B: key \(selector) handled; highlighted=\(highlightedIndex.map(String.init) ?? "none")")
        return true
    }

    // MARK: layout

    private func highlight(_ index: Int?) {
        highlightedIndex = index
        for (position, row) in rows.enumerated() { row.isHighlighted = position == index }
    }

    private func rebuild() {
        for view in stack.arrangedSubviews.dropFirst(2) { view.removeFromSuperview() }
        rows = []
        highlightedIndex = nil
        let look = RowLook(style: state.rowStyle)
        let query = field.stringValue
        let (matches, total) = state.search(query)
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            if let header = look.header(shown: matches.count, total: total) { add(MenuHeader(header)) }
            if matches.isEmpty { add(MenuHeader("No matching Clipboard Items")) }
            for clip in matches {
                let row = PanelRow(clip: clip, query: query, look: look, active: clip.id == state.activeID)
                row.onClick = { [weak self] in self?.choose(clip.id) }
                addRow(row)
            }
            let full = PanelRow(title: { look.fullHistoryTitle(total: total, all: self.state.items.count,
                                                               highlighted: $0) })
            full.onClick = { [weak self] in
                self?.close(reason: "Full history…")
                self?.actions.openSettings(.fullHistory)
            }
            addRow(full)
            add(MenuSeparator())
        }
        for (title, action) in [("Settings…", { self.actions.openSettings(.general) }),
                                ("Quit", { NSApp.terminate(nil) })] {
            let row = PanelRow(title: { NSAttributedString(string: title, attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: $0 ? NSColor.selectedMenuItemTextColor : NSColor.labelColor,
            ]) })
            row.onClick = { [weak self] in
                self?.close(reason: title)
                action()
            }
            addRow(row)
        }
        add(MenuSeparator())
        let variant = PanelRow(title: { NSAttributedString(string: "Variant ▸", attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: $0 ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor,
        ]) })
        variant.onClick = { [weak self, weak variant] in
            guard let self, let variant else { return }
            self.actions.variantMenu().popUp(positioning: nil, at: NSPoint(x: variant.bounds.maxX - 40, y: 0),
                                              in: variant)
        }
        addRow(variant)
        add(MenuHeader(state.label, small: true))
        resize()
    }

    private func add(_ view: NSView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -10).isActive = true
    }

    private func addRow(_ row: PanelRow) {
        let index = rows.count
        row.onHover = { [weak self] in self?.highlight(index) }
        rows.append(row)
        add(row)
    }

    private func resize() {
        stack.layoutSubtreeIfNeeded()
        let size = panel.contentView?.fittingSize ?? .zero
        let origin = protoOrigin(for: size, below: anchor())
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func choose(_ id: Int) {
        state.setActive(id, via: "B: row chosen")
        close(reason: "row chosen")
    }
}

/// Under the status item, kept on screen (copied shape of `StatusItemPlacement`).
@MainActor
func protoOrigin(for size: NSSize, below anchor: NSRect?) -> NSPoint {
    let screen = NSScreen.screens.first { anchor.map($0.frame.intersects) ?? false } ?? NSScreen.main
    let frame = screen?.frame ?? .zero
    let top = min(anchor?.minY ?? frame.maxY - 24, frame.maxY - 24)
    let preferred = anchor.map { $0.minX - 6 } ?? frame.maxX - size.width - 8
    let left = min(max(preferred, frame.minX + 8), frame.maxX - size.width - 8)
    return NSPoint(x: left, y: top - size.height - 2)
}

final class ProtoPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}
