// PROTOTYPE — menu-settings, never merged
import AppKit

/// The Settings 2 sidebar: a source list of sections with symbols, System Settings shape.
@MainActor
final class SidebarList: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let view: NSView
    var onSelect: ((Int) -> Void)?
    private let table = NSTableView()
    private let entries: [(String, String)]
    private var selecting = false

    init(entries: [(String, String)]) {
        self.entries = entries
        let effect = NSVisualEffectView()
        effect.material = .sidebar
        effect.blendingMode = .behindWindow
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.documentView = table
        scroll.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: effect.topAnchor, constant: 44),
            scroll.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        view = effect
        super.init()
        table.addTableColumn(NSTableColumn(identifier: .init("section")))
        table.headerView = nil
        table.style = .sourceList
        table.backgroundColor = .clear
        table.rowHeight = 28
        table.dataSource = self
        table.delegate = self
    }

    func select(_ index: Int) {
        selecting = true
        table.selectRowIndexes([index], byExtendingSelection: false)
        selecting = false
    }

    func numberOfRows(in tableView: NSTableView) -> Int { entries.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let (title, symbol) = entries[row]
        let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage())
        let label = NSTextField(labelWithString: title)
        let stack = NSStackView(views: [image, label])
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        return stack
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !selecting, table.selectedRow >= 0 else { return }
        onSelect?(table.selectedRow)
    }
}
