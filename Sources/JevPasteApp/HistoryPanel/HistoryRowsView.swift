import AppKit

/// The history rows: a scrolling, inset-style table with a fixed height of nine rows, so the panel keeps its
/// size while the query changes. The highlighted row uses the accent selection; hovering a row reveals its ✕.
/// It never takes first responder — the search field keeps the keys.
@MainActor
final class HistoryRowsView: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    static let visibleRowCount = 9
    private static let rowHeight = 34.0

    let view = NSScrollView()
    var onChoose: (@MainActor (Int) -> Void)?
    var onDelete: (@MainActor (Int) -> Void)?

    private let table = NonFocusingTableView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private var rows: [HistoryRow] = []

    override init() {
        super.init()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .inset
        table.rowHeight = Self.rowHeight
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.action = #selector(rowClicked)
        view.documentView = table
        view.drawsBackground = false
        view.hasVerticalScroller = true
        view.autohidesScrollers = true
        view.scrollerStyle = .overlay
        let height = Double(Self.visibleRowCount) * (Self.rowHeight + 2) + 10
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        emptyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func show(_ rows: [HistoryRow], emptyMessage: String, highlighting row: Int?) {
        self.rows = rows
        table.reloadData()
        emptyLabel.stringValue = emptyMessage
        emptyLabel.isHidden = !rows.isEmpty
        highlight(row)
    }

    func highlight(_ row: Int?) {
        guard let row, rows.indices.contains(row) else { return table.deselectAll(nil) }
        table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        HistoryTableRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = HistoryRowCell(row: rows[row])
        cell.onDelete = { [weak self] in self?.onDelete?(row) }
        return cell
    }

    @objc private func rowClicked() {
        let row = table.clickedRow
        guard rows.indices.contains(row) else { return }
        onChoose?(row)
    }
}

/// A table that never becomes first responder, so the search field keeps typing, arrows and Enter.
private final class NonFocusingTableView: NSTableView {
    override var acceptsFirstResponder: Bool { false }
}

/// A row that always draws the emphasized (accent) selection — the panel's search field, not the table, is first
/// responder — and tells its cell when the pointer is over it, even though jevpaste is not the active app.
private final class HistoryTableRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { true }
        set {}  // Always emphasized; AppKit's updates are ignored.
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(
            NSTrackingArea(
                rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        cell?.isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        cell?.isHovered = false
    }

    private var cell: HistoryRowCell? {
        subviews.lazy.compactMap { $0 as? HistoryRowCell }.first
    }
}
